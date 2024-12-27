local TeleportService = game:GetService("TeleportService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

local HTTPService = game:GetService("HttpService")

local TeleportModule = {}

local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ServerAccessCodes = DataStoreService:GetDataStore("ReservedServerAccessCodesTest5")
local ReservedServerOwner = DataStoreService:GetDataStore("ReservedServerOwnerTest5")

local RETRY_DELAY = 2
local MAX_WAIT = 10

--Requires
local MapsManagerModule = require("MapsManagerModule")
local PlayerDataModule = require("PlayerDataModule")
local EnvironmentModule = require("EnvironmentModule")

--Events
local RE_FriendInvitToPrivateServer = RemoteEvent.FriendInvitToPrivateServer
local RE_TeleportToPrivatePlace = RemoteEvent.TeleportToPrivatePlace
local RE_TeleportToMap = RemoteEvent.TeleportToMap
local BE_AchievementProgress = BindableEvent.AchievementProgress
local GetOwnerServer = ReplicatedStorage.SharedSync.BindableFunction:WaitForChild("GetOwnerServer")

-- Create remote event instance
local teleportEvent = Instance.new("RemoteEvent")
teleportEvent.Name = "TeleportEvent"
teleportEvent.Parent = RemoteEvent

--[[
	Allow to get code linked to a private server into datastore storage.
]]
function TeleportModule.GetCodeForPrivateServer(privateServerId)
	print("TRY GET CODE")
	local accessCode
	local success, err = pcall(function()
		accessCode = ServerAccessCodes:GetAsync(privateServerId)
	end)
	
	if err then
		print(err)
	end
	
	if not success then
		print("not geted code, retry")
		accessCode = TeleportModule.GetCodeForPrivateServer(privateServerId)
	end
	
	return accessCode
end

--[[
	Allow to get the ID of private server linked to a player ID in the datastore.
]]
function TeleportModule.GetPrivateServerOwner(ownerId, placeId)
	print("TRY GET PRIVATE SERVER")
	local privateServerId
	local success, err = pcall(function()
		local data_encoded = ReservedServerOwner:GetAsync(ownerId)
		if data_encoded then
			local data = HTTPService:JSONDecode(data_encoded)
			privateServerId = data[placeId]
		end
	end)

	if err then
		print(err)
	end

	if not success then
		print("not geted code, retry")
		privateServerId = TeleportModule.GetPrivateServerOwner(ownerId, placeId)
	end

	return privateServerId
end

--[[
	This method allow to make save in datastore code of server and server of player.
	We save in datastore ServerAccessCodes the list of servers ID with there code access.
	We save in other datastore ReservedServerOwner the list of server created for game and the player
	owner of server.
]]
function TeleportModule.SetCodeForPrivateServer(serverId, placeId, code, players)
	print("TRY SET CODE")
	local success, err = pcall(function()
		ServerAccessCodes:SetAsync(serverId, code)
		for _, plr in pairs(players) do
			local data_encoded = ReservedServerOwner:GetAsync(plr.UserId)
			local data
			if data_encoded then
				data = HTTPService:JSONDecode(data_encoded)
			else
				data = {}
			end
			data[placeId] = serverId
			data_encoded = HTTPService:JSONEncode(data)
			ReservedServerOwner:SetAsync(plr.UserId, data_encoded)
		end
	end)

	if success then
		print("code is saved!")
	else
		TeleportModule.SetCodeForPrivateServer(serverId, code)
	end
end


--[[
	This method have some behaviour, but the principal characteristics it's to make ateleportation player
	to a server given (private or public). This function check and retry if it fail or encounter
	somes errors.
	The playerstable allow to teleport more one player, but if u wan't teleport one player
	simply put juste player in the table.
]]
function TeleportModule.teleportWithRetry(targetPlaceID, playersTable, privateServer, codeExist, teleportOptions)
	local currentWait = 0

	-- Show custom teleport screen to valid players if client event is connected
	teleportEvent:FireAllClients(playersTable, true)
	
	--Teleport player according to the given parameters
	local function doTeleport(players, options, private)
		if currentWait < MAX_WAIT then
			local success, errorMessage = pcall(function()
				if private then
					if not teleportOptions then
						teleportOptions = Instance.new("TeleportOptions")
					end
					if codeExist then
						--if its a private server and code given in the teleport request, launch the teleportation
						teleportOptions.ReservedServerAccessCode = codeExist

						for _, player in pairs(players) do
							PlayerDataModule:Save(player, "FROM REMOVING")
						end
						
						TeleportService:TeleportAsync(targetPlaceID, players, teleportOptions)
					end
					
					--if code not exist but its a private server check if the player have a private server setup
					--in datastore or if the first time
					for _, plr in pairs(players) do
						local privateServerID = TeleportModule.GetPrivateServerOwner(plr.UserId, targetPlaceID)
						if privateServerID then
							--if have already a private server setup, get code and make teleportation
							local code = TeleportModule.GetCodeForPrivateServer(privateServerID)
							if code then
								print("TELEPORT OWNER TO THIS PRIVATE SERVER")
								BE_AchievementProgress:Fire(plr, "Achievement4", 1)
								teleportOptions.ReservedServerAccessCode = code

								for _, player in pairs(players) do
									PlayerDataModule:Save(player, "FROM REMOVING")
								end

								TeleportService:TeleportAsync(targetPlaceID, players, teleportOptions)
							end
						else
							--if not have already a private server, we use ReserveServer of private
							--place for create and obtain a unique code and unique private server for player
							print("RSERVE SERVER")
							local code, serverId = TeleportService:ReserveServer(targetPlaceID)
							if game.PrivateServerOwnerId == 0 then
								print("SERVER ID CREATED", serverId)
								print("CODE", code)
								--Save data information about private server and code for player
								TeleportModule.SetCodeForPrivateServer(serverId, targetPlaceID, code, players)
							end
							print("TELEPORT TO PRIVATE SERVER")
							--And now private server is configured, make teleportation
							BE_AchievementProgress:Fire(plr, "Achievement4", 1)
							teleportOptions.ReservedServerAccessCode = tostring(code)

							for _, player in pairs(players) do
								PlayerDataModule:Save(player, "FROM REMOVING")
							end

							TeleportService:TeleportAsync(targetPlaceID, players, teleportOptions)
						end
					end
				else
					--if not a private server, lets teleport player to the target place id (public server)
					print("TELEPORT TO PUBLIC SERVER")

					for _, player in pairs(players) do
						PlayerDataModule:Save(player, "FROM REMOVING")
					end

					TeleportService:TeleportAsync(targetPlaceID, players, options)
				end
			end)
			if not success then
				warn(errorMessage)
				-- Retry teleport after defined delay
				task.wait(RETRY_DELAY)
				currentWait = currentWait + RETRY_DELAY
				doTeleport(players, teleportOptions, privateServer)
			end
		else
			-- On failure, hide custom teleport screen for remaining valid players
			teleportEvent:FireAllClients(players, false)
			return true
		end
	end
	
	--Event listener connected to listen if teleport fail and make a delay with retry to doTeleport
	TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
		if teleportResult ~= Enum.TeleportResult.Success then
			warn(errorMessage)
			-- Retry teleport after defined delay
			task.wait(RETRY_DELAY)
			currentWait = currentWait + RETRY_DELAY
			doTeleport({player}, teleportOptions)
		end
	end)

	-- Fire initial teleport
	doTeleport(playersTable, teleportOptions, privateServer)
end

--Event Private Server invitation behaviour because client can't do that, only server can make a private teleport
--called by NotificationHandler
RE_FriendInvitToPrivateServer.OnServerEvent:Connect(function(player, privateServer, serverPlaceID, code)
	if not code then
		code = TeleportModule.GetCodeForPrivateServer(privateServer)
	end
	TeleportModule.teleportWithRetry(serverPlaceID, {player}, true, code)
end)

--Event called by the button of club to join the private server of club
--Called by client with ClubsCoreUI
RE_TeleportToPrivatePlace.OnServerEvent:Connect(function(player, code)
	TeleportModule.teleportWithRetry(EnvironmentModule.GetPlaceId("ClubMap"), {player}, true, code)
end)

RE_TeleportToMap.OnServerEvent:Connect(function(player, mapId, mapName, owner)
	if RunService:IsStudio() then
		MapsManagerModule.LoadMap(player, mapId, mapName)
		return
	end
	if player == owner and tostring(game.PlaceId) == mapId then
		MapsManagerModule.LoadMap(player, mapId, mapName)
	else
		-- Define teleport options
		local teleportOptions = Instance.new("TeleportOptions")
		local teleportData = {
			mapId = mapId,
			mapName = mapName
		}
		teleportOptions:SetTeleportData(teleportData)
		TeleportModule.teleportWithRetry(mapId, {player}, true, false, teleportOptions)
	end
end)

RemoteEvent.KickPlayer.OnServerEvent:Connect(function(player, playerToKick)
	if player.UserId == GetOwnerServer:Invoke() then
		TeleportModule.teleportWithRetry(EnvironmentModule.GetPlaceId("MainPlace"), {playerToKick}, false)
	end
end)

return TeleportModule