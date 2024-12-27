local MapsManagerModule = {}

--To determine the type of data to work on
local dataType = "Test3"

local HTTPService = game:GetService("HttpService")
local MS = game:GetService("MessagingService")
local PhysicsService = game:GetService("PhysicsService")
local AUTOSAVE_INTERVAL = 180 --3min

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local PositionningEvent = ReplicatedStorage.SharedSync.PositionningEvent
local PositionningObjects = ReplicatedStorage.SharedSync:WaitForChild("PositionningObjects")
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction.MapsManagerModule
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

local RE_ChangeVisibilityServerAdmin = RemoteEvent.ChangeVisibilityServerAdmin
local RE_ChangeAutorisedPositionningServerAdmin = RemoteEvent.ChangeAutorisedPositionningServerAdmin
local RE_EnableBeam = PositionningEvent.EnableBeam
local GetOwnerServer = ReplicatedStorage.SharedSync.BindableFunction:WaitForChild("GetOwnerServer")
local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert

--Require Modules
local ToolsModule = require("ToolsModule")
local RaceHandler = require("RaceHandler")
local PlayerDataModule = require("PlayerDataModule")
local EnvironmentModule = require("EnvironmentModule")
local GameDataModule = require("GameDataModule")

--Setup variables datastore of game
local DataStoreService = game:GetService("DataStoreService")
local MapsDatastore = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.Player.MapsData.Name..GameDataModule.DatastoreVariables.Player.MapsData.Version)

--[[
	This is for stock in dictionnary all positionning object for player and the list of their maps,
	looks like :
		PlayerId = {
			MapsId={--placeId of map
				MapName = {
					CFrameObj = {
						NameObj = "NameObj",
						Size = Size,
						Anchored = false,
						--if its Race Object we have
						CheckpointNumber = 0,
						RaceLink = Id of race
						RaceCreator = playerId
					}
				};
			};
		};
]]
local positionningObjects = {}
--This is for stock in dictionnary all public server open in game
local publicServersList = {}

--///////////////// DETECTION OF LIST PUBLIC SERVER \\\\\\\\\\\\\\\\\\\\\\
--Setup the first player connected to the server as the owner of private server (reserved) only
local OwnerPlayer = nil
local RunService = game:GetService("RunService")
local IsPublicServer = RunService:IsStudio() --default value false, for test true
local IsAutorisedPositionningServer = RunService:IsStudio() --default value false, for test true
local AuthorisedPositionningPlayers = {}
local ServerName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name

--this part allow to MapsManagerModule to know if server are setup has club server or not
local DataClubMap
function MapsManagerModule.SetDataClubMap(value)
	DataClubMap = value
	BindableEvent.ClubUpdate.Event:Connect(function(clubName, data, deleteMember, addMember)
		if DataClubMap then
			if DataClubMap.ClubName == clubName then
				DataClubMap = data

				if deleteMember then
					local t = table.find(AuthorisedPositionningPlayers, deleteMember.UserId)
					if t then
						table.remove(AuthorisedPositionningPlayers, t)
						RE_ChangeAutorisedPositionningServerAdmin:FireClient(deleteMember, false)
					end
				end

				if addMember then
					table.insert(AuthorisedPositionningPlayers, addMember.UserId)
					RemoteEvent.EnabledPositionningGui:FireClient(addMember, true, false)
					RE_ChangeAutorisedPositionningServerAdmin:FireClient(addMember, true)
				end
			end
		end
	end)
end

PhysicsService:CollisionGroupSetCollidable("HorseAI", "IgnorePlacementObjects", false)
PhysicsService:CollisionGroupSetCollidable("IgnorePlacementObjects", "Horses", false)
--[[
	Listen Event when player connect to the game.
]]
function playerAdded(player)
	repeat task.wait() until player.Character

	--Set owner of server if not exist again
	if not OwnerPlayer then
		if DataClubMap then
			if player.UserId == DataClubMap.Owner then
				print("TEST SET OWNER CLUB AS MAP OWNER")
				OwnerPlayer = player
			end
		else
			print("SET OWNER OF SERVER")
			OwnerPlayer = player
		end
	end
	
	--Check the initiatlise UI Visibility for Admin Panel and Positionning UI
	if game.PrivateServerId ~= "" then
		--if server is not a public server (private or reserved)
		--check when player connected if player allow to place object or not
		if not IsAutorisedPositionningServer then
			if DataClubMap then
				if DataClubMap.ListOfMembers[tostring(player.UserId)] and OwnerPlayer ~= player then
					table.insert(AuthorisedPositionningPlayers, player.UserId)
					print("TEST PLAYER ARE MEMBER OF CLUB CAN PLACE OBJET")
					RemoteEvent.EnabledPositionningGui:FireClient(player, true, false)
				end
			end

			--if not autorised to place check player if is the owner to show UI
			if player == OwnerPlayer then
				RemoteEvent.EnabledPositionningGui:FireClient(player, true, true)
			end

			--check if player are ine the authorised positionning list to show placing UI
			if table.find(AuthorisedPositionningPlayers, player.UserId) then
				if DataClubMap then
					if DataClubMap.ListOfMembers[tostring(player.UserId)] then
						if DataClubMap.ListOfMembers[tostring(player.UserId)].Admin then
							print("TEST UI POSITIONNING SETUP ADMIN")
							RemoteEvent.EnabledPositionningGui:FireClient(player, true, true)
						end
					end
				else
					print("TEST UI POSITIONNING SETUP OTHER")
					RemoteEvent.EnabledPositionningGui:FireClient(player, true, false)
				end
			end
		end
	end

	task.spawn(function()
		if not positionningObjects[player] then
			--Allow to init data player when is connected to add data on the local data server
			MapsManagerModule.DatastorePositionning(player, false, false, "", "")

			if RunService:IsStudio() then
				if game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") then
					MapsManagerModule.LoadMap(player, EnvironmentModule.GetPlaceId("MyFarm"), "MyFarmHouse")
				end
			end
		end
	end)
end

game.Players.PlayerRemoving:Connect(function(player)
	if DataClubMap then
		if player == OwnerPlayer then
			OwnerPlayer = nil
		end
	end
end)

--[[
	This little function allow to set UI Name Server for all player, set by data know by server and not client
]]
function SetUiNameServer()
	for _, player in pairs(game.Players:GetChildren()) do
		local playerGui = player:WaitForChild("PlayerGui"):WaitForChild("StarterGuiSync")
		local MapsGui = playerGui:WaitForChild("MapsGui")
		MapsGui.NameServer.Title.Text = ServerName
	end
end

--[[
	This method allow to publish the status of server, open or not open to other server for
	refresh list of available server access
]]
function PublishServerStatus(isPublic)
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		local message = {
			ServerSpeakerJobId = game.JobId;
			IsPublic = isPublic;
			ServerId = game.PrivateServerId;
			PlaceId = game.PlaceId;
			PlayerOwnerId = OwnerPlayer.UserId;
		}
		print("PUBLISH SERVER STATUS")
		MS:PublishAsync("ServerStatus", message)
	end
end

--Receive message of server status to informe and update a table of server open
MS:SubscribeAsync("ServerStatus", function(message)
	--if the serverspeaker are the server sender, do nothing
	if message.Data.ServerSpeakerJobId == game.JobId then
		print("CEST MON MESSAGE ALORS RETURN", message.Data.ServerSpeakerJobId)
		return
	end
	print("CEST PAS MON MESSAGE ALORS ECOUTONS", message.Data.ServerSpeakerJobId)
	if message.Data.Ask then
		print("ASK", message.Data.ServerSpeakerJobId)
		--if here so the server speaker need to know all server open
		if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 and OwnerPlayer then
			local msg = {
				ServerSpeakerJobId = game.JobId;
				IsPublic = IsPublicServer;
				ServerId = game.PrivateServerId;
				PlaceId = game.PlaceId;
				PlayerOwnerId = OwnerPlayer.UserId;
			}
			print("SEND MY STATUS TO OTHER SERVERS", msg.ServerSpeakerJobId)
			MS:PublishAsync("ServerStatus", msg)
		end
	else
		print("RECEIVE SERVER STATUS", message.Data.ServerSpeakerJobId)
		MapsManagerModule.SetPublicServers(message.Data.PlayerOwnerId, message.Data.ServerId, message.Data.PlaceId, message.Data.IsPublic)
	end
end)

local function AutoSaveMyFarmHouseServerOnly()
	print("AUTO SAVE FARM CHECK")
	--we check if actual server is a place id server for player farm house
	if game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") then
		print("PLACE ID OK")
		print("OWNER IS", OwnerPlayer)
		if OwnerPlayer then
			--make here save of positionning map object only for farm player
			MapsManagerModule.DatastorePositionning(OwnerPlayer, true, true, tostring(EnvironmentModule.GetPlaceId("MyFarm")), "MyFarmHouse")
			print("Auto save for only owner and only for farm house")
		end
	end
end


--when server go to close, send message to say this server is not open
game:BindToClose(function()
	AutoSaveMyFarmHouseServerOnly()
	PublishServerStatus(false)
	task.wait(2)
	print("Server Close")
end)

--[[
	This is a link to the client side to change on the server, if the player are owner of server
	the visibility information of server.
	The method PublishServerStatus is launch and allow to send a messaging service to other
	server for update list public server's.
	This Remote Event is call by client Admin Panel.
]]
RE_ChangeVisibilityServerAdmin.OnServerEvent:Connect(function(player, isPublic)
	if OwnerPlayer then
		if player.UserId == OwnerPlayer.UserId then
			print("Owner have change visibility of server")
			PublishServerStatus(isPublic)
			IsPublicServer = isPublic
		end
	end
end)

--[[
	This is a event listener when client call server for change in panel admin
	the permission of players to place object or not in the server.
	This method enable or not the variable of server and change the GUI Positionning visibility.
	The server variable IsAutorisedPositionningServer is there to protect if the client activates
	this positionning GUI by any way.
	If the last parameter is present, it's a single authorisation for one player to place object, in this
	case we only activate UI for the player authorised.
]]
RE_ChangeAutorisedPositionningServerAdmin.OnServerEvent:Connect(function(player, isAutorised, playerAuthorised)
	if OwnerPlayer then
		if player.UserId == OwnerPlayer.UserId then
			--check if it authorisation player or all players in server
			if not playerAuthorised then
				print("Owner have change autorised positionning of server")
				IsAutorisedPositionningServer = isAutorised
				AuthorisedPositionningPlayers = {}
				--check all players in server and set visibility of positionning gui
				for _, plr in pairs(game.Players:GetChildren()) do
					if plr.UserId ~= OwnerPlayer.UserId then
						local playerGui = plr:WaitForChild("PlayerGui").StarterGuiSync
						playerGui.PositionningGui.Enabled = isAutorised
					end
				end
				RE_ChangeAutorisedPositionningServerAdmin:FireAllClients(isAutorised)
			else
				print("Owner have change authorised positionning for "..playerAuthorised.Name)
				if isAutorised then
					table.insert(AuthorisedPositionningPlayers, playerAuthorised.UserId)
				else
					local t = table.find(AuthorisedPositionningPlayers, playerAuthorised.UserId)
					table.remove(AuthorisedPositionningPlayers, t)
				end
				local playerGui = playerAuthorised:WaitForChild("PlayerGui").StarterGuiSync
				playerGui.PositionningGui.Enabled = isAutorised
				RE_ChangeAutorisedPositionningServerAdmin:FireClient(playerAuthorised, isAutorised)
			end
		end
	end
end)

--[[
	This method return the list of public server know by this active server
]]
function MapsManagerModule.GetPublicServers()
	return publicServersList
end

--[[
	This method set the list of public server active know by this active server.
	For this, the method complet a dictionnary who list all active public server in game.
	The dictionnary looks like :
		publicServersList = {
			ServerId = {
				PlayerId = PlaceId;
			};
		}
	If the variable isPublic is true we add it and if it's false we delete it from the dictionnary
	with nil
]]
function MapsManagerModule.SetPublicServers(playerId, serverId, placeId, isPublic)
	local data = {}
	if isPublic then
		--create data and add it to the server id in public list
		data[playerId] = placeId
		publicServersList[serverId] = data
	else
		--delete data from server id in the public list
		publicServersList[serverId] = nil
	end
	
	--Say to all player refresh their public list ui data with new data
	RemoteEvent.RefreshPublicServersUI:FireAllClients(MapsManagerModule.GetPublicServers())
end

--[[
	This method allow to a server to call messaging service for ask all other servers their status.
	All server who follow the "ServerStatus" topic execut the method SubscribeAsync("ServerStatus") l.115
]]
function MapsManagerModule.CheckServersOpen()
	local message = {
		ServerSpeakerJobId = game.JobId;
		Ask = true;
	}
	print("CHECK ALL SERVERS OPEN")
	game:GetService("MessagingService"):PublishAsync("ServerStatus", message)
end

--///////////////// ---------------------------------- \\\\\\\\\\\\\\\\\\\\\\
function UpdateSizeOfModelObject(clone, SizeObject, CFrameObject)
	local PrimaryPart = clone.PrimaryPart
	local PrimaryPartCFrame = clone:GetPrimaryPartCFrame()
	
	--If actual size object on server is not the same as the client object, make a resize complex object
	if PrimaryPart.Size ~= SizeObject then
		local scale = PrimaryPart.Size.X/SizeObject.X	
		--Scale BaseParts of clone
		for _,object in pairs(clone:GetDescendants()) do
			if object:IsA('BasePart') then
				object.Size = object.Size/scale
				local distance = (object.Position - PrimaryPartCFrame.p)
				local rotation = (object.CFrame - object.Position)
				object.CFrame = (CFrame.new(PrimaryPartCFrame.p + distance/scale) * rotation)
			end
		end
	end
	
	ToolsModule.WeldModelToPrimary(clone)
	clone.PrimaryPart.Anchored = true
	clone:SetPrimaryPartCFrame(CFrameObject)
	clone.PrimaryPart.Size = SizeObject
end

--[[
	This method allow to make a dictionnary of player for saved data in datastore. The datas
	make a dictionnary who is placed into the global variable
	for MapsManager behavior : positionningObject[player]
	Actually data save for a object are :
		- CFrame as Index
		- Name as NameObj
		- Size as Size
		- Anchored as Anchored
	If we need more saved details, we just add in the table objDetail setup into the CFrame index of object
]]
function AddObjectsPlayer(player, objs, mapId, mapName)
	local objDetail = {}
	local dataMap = {}
	local objMap = {}
	
	--convert all objects to save into dictionnary
	if objs then
		for _, obj in pairs(objs) do
			local model
			--If obj is a model, set with primarypart the saved value of object		
			if obj:IsA("Model") then
				model = obj.PrimaryPart
				objDetail["NameObj"] = obj.Name
			else
				model = obj
				objDetail["NameObj"] = model.Name
			end

			
			objDetail["Size"] = tostring(model.Size)
			objDetail["Anchored"] = model.Anchored

			if model:GetAttribute("ObjectType") == "RaceObject" then
				local nb = model:GetAttribute("NumberCheckpoint") 
				if nb then
					objDetail["CheckpointNumber"] = nb
				end
				objDetail["RaceCreator"] = model:GetAttribute("RaceCreator")
				objDetail["RaceLink"] = model:GetAttribute("RaceLink")
				if obj.Name == "Start" then
					objDetail["playerNeeded"] = model:GetAttribute("playerNeeded")
				end
			end

			objMap[tostring(model.CFrame)] = objDetail

			--Reset table of obj details for set the next obj details
			objDetail = {}
		end
	end

	--get all maps name already exist
	if positionningObjects[player][mapId] then
		for i, v in pairs(positionningObjects[player][mapId]) do
			dataMap[i] = v
		end
	end
	
	--update data of mapname choosen to save
	dataMap[mapName] = objMap

	--save all data mapname into the mapid choosen
	positionningObjects[player][mapId] = dataMap
	
	print("POSTITIONNING OBJECTS",positionningObjects[player])
end

--[[
	This method let the server to load all object save in the slot given by mapName corresponding to the
	given mapId linked to the player.
	When this method is called, we check player caller are the owner because only owner
	of map and this content can load it actually.
	This method is linked to a event caller for let client side call load map data if player use
	UI.
]]
function MapsManagerModule.LoadMap(player, mapId, mapName, ClubDataMaps)
	if not RunService:IsStudio() then
		if not ClubDataMaps then
			--we check if owner exist, if before encounter prblm to setup it, we can force here the first player to become set as owner
			if not OwnerPlayer then
				OwnerPlayer = player
			end

			--Only owner of map can load map
			if player.UserId ~= OwnerPlayer.UserId then
				warn("Only Owner can load map here")
				return
			end
		end
	end
	
	if not positionningObjects[player] then
		--if ClubDataMaps exist we don't have to check player data positionning, but just setup the data club map and player become the maps id
		if ClubDataMaps then
			positionningObjects[player] = ClubDataMaps
		else
			--load data if not already loaded, exemple, after teleporting
			MapsManagerModule.DatastorePositionning(player, false, false, mapId, mapName)
		end
	end
	print("Loading objects !")
	--After load, destroy all last world object
	for _, obj in pairs(game.Workspace.ObjectsPositionningOfMap:GetChildren()) do
		obj:Destroy()
	end
	for _, obj in pairs(game.Workspace.Races:GetChildren()) do
		obj:Destroy()
	end
	
	--Load all object to world
	for index, maps in pairs(positionningObjects[player]) do
		if index == tostring(mapId) then
			for i, objs in pairs(maps) do
				if i == mapName then
					for cf, objDetail in pairs(objs) do
						--check if we found object to clone into PositionningObjects Folder or into ShopItemStorage
						local exist = PositionningObjects:FindFirstChild(objDetail["NameObj"])
						if not exist then
							exist = game.ServerStorage.ServerStorageSync.ShopItemsStorage:FindFirstChild(objDetail["NameObj"])
						end

						if exist then
							local clone = exist:Clone()
							clone:SetAttribute("Modeller", 0) --set attribute Modeller for allow player interact with him

							-- convert the string CFrame to a real CFrame
							local components = {}
							for num in string.gmatch(cf, "[^%s,]+") do
								components[#components+1] = tonumber(num)
							end
							--convert the string Size to a vector3
							local tab = {}
							for s in string.gmatch(objDetail.Size,"[^,]+") do
								table.insert(tab,tonumber(s))
							end
							if clone:IsA("Model") then
								UpdateSizeOfModelObject(clone, Vector3.new(unpack(tab)), CFrame.new(unpack(components)))
								-----------------------------
								--clone:PivotTo(CFrame.new(unpack(components)))
								--clone.PrimaryPart.Size = Vector3.new(unpack(tab))
								clone.PrimaryPart.Anchored = objDetail.Anchored
							else
								clone.CFrame = CFrame.new(unpack(components))
								clone.Size = Vector3.new(unpack(tab))
								clone.Anchored = objDetail.Anchored

								--Set attributes if clone object is a RaceObject for saving Races
								if clone:GetAttribute("ObjectType") == "RaceObject" then								
									if clone:GetAttribute("RaceCreator") then
										clone:SetAttribute("RaceCreator", objDetail.RaceCreator)
									end
									if clone:GetAttribute("RaceLink") then
										clone:SetAttribute("RaceLink", objDetail.RaceLink)
									end
									local nb = clone:GetAttribute("NumberCheckpoint")
									if nb then
										clone:SetAttribute("NumberCheckpoint", objDetail.CheckpointNumber)
									end
									if clone.Name == "Start" then
										clone:SetAttribute("playerNeeded", objDetail.playerNeeded)
									end
								end
							end
							clone.Parent = game.Workspace.ObjectsPositionningOfMap
						end
					end
				end
			end
		end
	end

	--If we have Races object, setup races data with races objects loaded and reset data when loaded map for no conflict
	RaceHandler:ResetRaces()
	--Clear IA folder
	local folder = game.Workspace:FindFirstChild("AI_Holder")
	if folder then
		folder:ClearAllChildren()
	end
	local racesObj = {}
	for _, obj in pairs(game.Workspace.ObjectsPositionningOfMap:GetChildren()) do
		if obj:GetAttribute("ObjectType") == "RaceObject" then
			table.insert(racesObj, obj)
		end
	end
	--Setup first the Start object
	for _, obj in pairs(racesObj) do
		if obj.Name == "Start" then
			RaceHandler:MakeStart(obj:GetAttribute("RaceCreator"), obj, obj:GetAttribute("playerNeeded"))
			obj.CanQuery = true
			obj.CollisionGroup = "CameraCollision"
		end
	end
	--When all start object are setup, setup all checkpoints object
	--ordering checkpoint
	local checkpoint = {}
	for _, obj in pairs(racesObj) do
		if obj.Name == "Checkpoint" then
			table.insert(checkpoint, obj)
		end
	end
	table.sort(checkpoint, function(A, B)
		local NumberA = tonumber(A:GetAttribute("NumberCheckpoint"))
		local NumberB = tonumber(B:GetAttribute("NumberCheckpoint"))
		return NumberA < NumberB
	end)
	--set checkpoint ordering
	for _, obj in pairs(checkpoint) do
		RaceHandler:SetCheckpoint(obj:GetAttribute("RaceCreator"), obj)
		obj.CheckpointUI.TxtNumber.Text = obj:GetAttribute("NumberCheckpoint")
		obj.CheckpointUI.TxtRace.Text = obj:GetAttribute("RaceLink")
	end
	for _, obj in pairs(checkpoint) do
		RaceHandler:SetRaceEnd(obj:GetAttribute("RaceCreator"))
	end

	--setup the name of server with information server know about it
	ServerName = tostring(game.PrivateServerId.."/"..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name.."/"..mapName)
	SetUiNameServer()
end

--[[
	Principal method to the MapsManagerModule who allow manage datastore player for custom maps.
	This method have multiple call type depending on the need.
	- If "saving" is true and "useData" false : Reset data of player given
	- If "saving" is true and "useData" true : search all object in the map and make a save.
	- If "saving" is false : the method load the data from datastore to init the global
	variable positionningObjects for player given and avoird numerous calls to the database.
]]
function MapsManagerModule.DatastorePositionning(player, saving, useData, mapId, mapName, isClub)
	if (saving) then
		if tostring(game.PlaceId) ~= mapId then
			warn("Cannot save map slot selected if is not the map modified")
			return false
		end

		if (useData) then
			--Check if we are a race in progress if true can't save
			local canSave = true
			local races = RaceHandler:GetRaces()
			for _, race in pairs(races) do
				if race.Ongoing then
					canSave = "No saving possible with a race in progress!"
				end
			end

			--check if object are editing on the map, if true can't save
			for _, obj in pairs(game.Workspace.ObjectsPositionningOfMap:GetChildren()) do
				if obj:GetAttribute("Modeller") then
					if obj:GetAttribute("Modeller") ~= 0 then
						canSave = "No saving possible with objects being edited!"
					end
				end
			end

			if canSave == true then
				--Find all object added by player in the map
				local data = {}
				for _, obj in pairs(game.Workspace.ObjectsPositionningOfMap:GetChildren()) do
					local exist = PositionningObjects:FindFirstChild(obj.Name)
					if exist then
						table.insert(data, obj)
					end
				end
				for _, race in pairs(game.Workspace.Races:GetChildren()) do
					table.insert(data, race.Start)
					for _, checkPoint in pairs(race.Checkpoints:GetChildren()) do
						table.insert(data, checkPoint)
					end
				end
				if data then
					AddObjectsPlayer(player, data, mapId, mapName)
				end
				if isClub then
					return HTTPService:JSONEncode(positionningObjects[player])
				else
					local data_encoded = HTTPService:JSONEncode(positionningObjects[player])
					-- save the data
					MapsDatastore:SetAsync(player.UserId, data_encoded)
					return true
				end
			else
				return canSave
			end
		else
			-- clear the data
			MapsDatastore:SetAsync(player.UserId, {})
		end
	elseif (not saving) then

		-- load the data
		local data_encoded = MapsDatastore:GetAsync(player.UserId)
		if data_encoded then
			positionningObjects[player] = HTTPService:JSONDecode(data_encoded)
			print(positionningObjects[player])
		else
			--first time connected player so init positionningObjects[player] because the player in this
			--dictionnary does not exist. For the next time to exist so we can use positionningObjects[player][mapId] 
			local obj = {}
			local maps = {}
			local dataMaps = {}
			for i=1, 3, 1 do
				maps["Slot"..i] = obj
			end
			dataMaps[mapId] = maps
			positionningObjects[player] = dataMaps
		end


		if positionningObjects[player][mapId] == nil then
			if mapId ~= "" then
				print("FIRST TIME MAPS", mapId)
				--Create 3 datas slots for this maps
				local obj = {}
				local maps = {}
				local dataMaps = {}
				for i=1, 3, 1 do
					maps["Slot"..i] = obj
				end

				positionningObjects[player][mapId] = maps

				local data_encoded = HTTPService:JSONEncode(positionningObjects[player])
				-- save the data
				MapsDatastore:SetAsync(player.UserId, data_encoded)
			end
		end

		return positionningObjects[player]
	end
end

--#region Positionning Object

local function SetupCheckpoint(clone, player, raceCreator, raceLink)
	--check before place checkpoint, we have a least one start object, if not cancel operation positionning
	clone.Anchored = true
	local races = RaceHandler:GetRaces()
	if ToolsModule.LengthOfDic(races) == 0 then
		clone:Destroy()
		return false
	end
	local plr
	if raceCreator and raceCreator ~= 0 then
		plr = game.Players:GetPlayerByUserId(raceCreator)
	else
		plr = player
	end
	clone:SetAttribute("RaceCreator", plr.UserId)
	if raceLink == "" then
		local playerRaces = RaceHandler:CheckIfPlayerHaveRaces(plr.UserId)
		if #playerRaces == 0 then
			print("123456 no owned races ")
			clone:Destroy()
			return false
		end
		raceLink = playerRaces[1].RaceLink
	end
	clone:SetAttribute("RaceLink", raceLink)
	clone:SetAttribute("NumberCheckpoint", #races[raceLink].Checkpoints)
	UpdateCheckpointNumber(plr.UserId, clone)
	
	RaceHandler:SetCheckpoint(plr.UserId,clone)
end

--[[
	This method is use for place object in the server world sended by the client. We check
	if player caller have all authorisation for place an object in the map and use position and name of
	object placed by player for instanciate it in the world.
	If isDelete parameter is call, the method destroy the object selected and not instantiate it.
]]
PositionningEvent:WaitForChild("PositionningObject").OnServerInvoke = function(player, NameObject, CFrameObject, SizeObject, Anchored, isDeleted, raceCreator, raceLink)
	--Check if is autorised to place object, if not just owner can put new object on map
	if not IsAutorisedPositionningServer then
		if player ~= OwnerPlayer then
			--with the "not" word dont work so we check if player is authorised and if yes, do nothing and can
			--put object in map else just make a return player can't put object
			if table.find(AuthorisedPositionningPlayers, player.UserId) then
			else
				return
			end
		end
	end
	
	if isDeleted then
		if isDeleted.Name == "Checkpoint" then
			local raceCreatorPlayer = isDeleted:GetAttribute("RaceCreator")
			RaceHandler:RemoveCheckpoint(raceCreatorPlayer, isDeleted)
			DestroyCheckpoint(raceCreatorPlayer, isDeleted)
		end

		if isDeleted:GetAttribute("Price") then
			PlayerDataModule:Increment(player, isDeleted:GetAttribute("Price"), isDeleted:GetAttribute("CurrencyType"))
		end

		isDeleted:Destroy()
		return
	end

	local crafted
	local clone

	local exist = PositionningObjects:FindFirstChild(NameObject)

	--check if item have price and if player can buy it (new behavior come with adding price on positionning objects)
	if exist:GetAttribute("Price") then
		local result = PlayerDataModule:Decrement(player, exist:GetAttribute("Price"), exist:GetAttribute("CurrencyType"))
		if not result then
			--if error with payout, it's because player don't have money so we make a popup who redirect player on the Purchase Ecus
			ShowPopupBindableEvent:Fire(
				player,
				"Fail Payout",
				"You don't have enough Ecus ...",
				ToolsModule.AlertPriority.Annoucement,
				nil,
				ToolsModule.AlertTypeButton.OK,
				nil,
				nil,
				ToolsModule.OpenEcusGui,
				{player}
			)
			
			return
		end
	end

	clone = exist:Clone()
	if clone and game.Workspace:FindFirstChild("ObjectsPositionningOfMap") then
		if clone:IsA("Model") then
			UpdateSizeOfModelObject(clone, SizeObject, CFrameObject)
			clone.Parent = game.Workspace.ObjectsPositionningOfMap
			task.wait(0.05)
			clone.PrimaryPart.Anchored = Anchored
		else
			clone.Anchored = true
			clone.CFrame = CFrameObject
			clone.Size = SizeObject
			clone.Parent = game.Workspace.ObjectsPositionningOfMap
			task.wait(0.05)
			clone.Anchored = Anchored
		end		
		if NameObject == "Checkpoint" then
			SetupCheckpoint(clone, player, raceCreator, raceLink)
			
		elseif NameObject == "Start" then
			clone.Anchored = true
			clone:SetAttribute("RaceCreator", player.UserId)
			RaceHandler:MakeStart(player.UserId,clone)
			clone.CanQuery = true
			clone.CollisionGroup = "CameraCollision"
		end
		crafted = true
	else
		crafted = false
	end
	
	--return if crafted object is success and the object crafted
	return crafted, clone
end

PositionningEvent:WaitForChild("DatastorePositionning").OnServerInvoke = MapsManagerModule.DatastorePositionning

--#endregion

--[[
	This Remote Function allow to client say at the server to update the value of modeller who use object give in
	paramter. isFree parameter are a boolean for say yes is free to modify or not free to modify by another player.
]]
PositionningEvent.ModellerObject.OnServerInvoke = function(player, obj, isFree)
	if obj then		
		if obj:GetAttribute("Modeller") then		
			if isFree then
				obj:SetAttribute("Modeller", 0)
			else
				obj:SetAttribute("Modeller", player.UserId)
			end
			return true
		else
			return false
		end
	end
	return false
end

--[[
	This function is call when checkpoint is destroy or change course.
	We setup all new number checkpoint value for the current Race to prevent a lose of good order checkpoints.
]]
function DestroyCheckpoint(playerId, model)
	local checkpoints = RaceHandler:GetAllCheckpoints(playerId, model:GetAttribute("RaceLink"))
	for _, checkpoint in pairs(checkpoints) do
		if checkpoint:GetAttribute("NumberCheckpoint") > model:GetAttribute("NumberCheckpoint") then
			checkpoint:SetAttribute("NumberCheckpoint", checkpoint:GetAttribute("NumberCheckpoint")-1)
			checkpoint.CheckpointUI.TxtNumber.Text = checkpoint:GetAttribute("NumberCheckpoint")
		end
	end
	RaceHandler:UpdateCheckpoints(playerId)
end

local function UpdateBeam(model, checkpoints, checkpoint, index)
	checkpoint.Beam.Attachment0 = checkpoint.AttachmentMiddle
	if index == 1 then
		checkpoint.Beam.Attachment1 = model.Start.AttachmentMiddle
	else
		checkpoint.Beam.Attachment1 = checkpoints[index-1].AttachmentMiddle
	end
end

function EnableBeam(checkpointPart, enabled)
	local checkpoints = RaceHandler:GetAllCheckpoints(checkpointPart:GetAttribute("RaceCreator"), checkpointPart:GetAttribute("RaceLink"))
	for index, checkpoint in pairs(checkpoints) do
		UpdateBeam(checkpointPart.Parent.Parent, checkpoints, checkpoint, index)
		print("123456 enabled : ", enabled)
		checkpoint.Beam.Enabled = enabled
	end
end

RE_EnableBeam.OnServerEvent:Connect(function(player, checkpointPart, enabled)
	EnableBeam(checkpointPart, enabled)
end)


--[[
	This method allow to update on the server side, the number checkpoint of model given in parameter.
	When number is not given, it because function was call by adding a new checkpoint, so just set the number checkpoint
	in relation to checkpoints existing and set it.
	If number parameter is given it's a player change number of checkpoint, so find if exist a actual checkpoint
	with this number and invert the values of the both.
]]
function UpdateCheckpointNumber(player, model, number)
	--Change checkpoint number if one already number exist and no accept increment if no existing superior checkpoint number
	local checkpoints = RaceHandler:GetAllCheckpoints(model:GetAttribute("RaceCreator"), model:GetAttribute("RaceLink"))
	--if number is nil it's a new checkpoint so just set the number
	if number == nil then
		print("New Checkpoint")
		number = #checkpoints+1
		model:SetAttribute("NumberCheckpoint", number)
		model.CheckpointUI.TxtNumber.Text = number
		model.CheckpointUI.TxtRace.Text = model:GetAttribute("RaceLink")
		return
	end

	for index, checkpoint in pairs(checkpoints) do
		if checkpoint:GetAttribute("NumberCheckpoint") == number and checkpoint ~= model then
			checkpoint:SetAttribute("NumberCheckpoint", model:GetAttribute("NumberCheckpoint"))
			model:SetAttribute("NumberCheckpoint", number)
			RaceHandler:UpdateCheckpoints(model:GetAttribute("RaceCreator"))
			EnableBeam(model, true)
			checkpoint.CheckpointUI.TxtNumber.Text = checkpoint:GetAttribute("NumberCheckpoint")
			model.CheckpointUI.TxtNumber.Text = number
		end
	end
	for index, chck in pairs(checkpoints) do
		UpdateBeam(model, checkpoints, chck, index)
	end
end
PositionningEvent.UpdateCheckpointNumber.OnServerInvoke = UpdateCheckpointNumber

--[[
	This remote function assigns the checkpoint (model) to another race present on the map.
]]
PositionningEvent.UpdateCheckpointRaceLink.OnServerInvoke = function(player, model, isIncrement)
	local ActualRaceLink = model:GetAttribute("RaceLink")
	local ActualRaceCreator = model:GetAttribute("RaceCreator")

	local NewRaceCreator
	local NewRaceLink

	--Get actual Race on map
	local Races = RaceHandler:GetRaces()
	local RacesPlayer = {}
	--Keep only race make by player
	for _, race in pairs(Races) do		
		if race.Owner then	
			table.insert(RacesPlayer, race)
		end
	end

	--work only if many races exist
	if #RacesPlayer > 1 then
		for index, race in pairs(RacesPlayer) do
			--we take a reference for set the good next or previous index to change Race Link of Checkpoint
			if race.RaceLink == ActualRaceLink then
				--check if player press previous or next button and set the new value for attribute on the checkpoint
				if isIncrement then
					if index+1 <= #RacesPlayer then	
						NewRaceLink = RacesPlayer[index+1].RaceLink
						NewRaceCreator = RacesPlayer[index+1].Owner
					else
						NewRaceLink = RacesPlayer[1].RaceLink
						NewRaceCreator = RacesPlayer[1].Owner
					end
				else
					if index-1 > 0 then
						NewRaceLink = RacesPlayer[index-1].RaceLink
						NewRaceCreator = RacesPlayer[index-1].Owner
					else
						NewRaceLink = RacesPlayer[1].RaceLink
						NewRaceCreator = RacesPlayer[1].Owner
					end
				end
			end
		end
		
		--Make change update before change new value of model to setup the correctly the first race modified
		RaceHandler:RemoveCheckpoint(ActualRaceCreator, model)
		DestroyCheckpoint(ActualRaceCreator, model)
		RaceHandler:UpdateCheckpoints(ActualRaceCreator)

		--Apply new value for model to update the second race
		model:SetAttribute("RaceCreator", NewRaceCreator)
		model:SetAttribute("RaceLink", NewRaceLink)

		--We make, in the good order, the big update of second race for change checkpoint owner, race number checkpoint etc
		UpdateCheckpointNumber(NewRaceCreator, model)
		RaceHandler:SetCheckpoint(NewRaceCreator, model)
		RaceHandler:UpdateCheckpoints(NewRaceCreator)

		--update the RaceLink UI for identify more easily checkpoint owner
		model.CheckpointUI.TxtRace.Text = model:GetAttribute("RaceLink")
	end

	return model:GetAttribute("RaceCreator")
end

PositionningEvent.UpdatePositionningObject.OnServerEvent:Connect(function(player, obj, size, cframe, anchor, dis)
	for _, object in pairs(game.Workspace.ObjectsPositionningOfMap:GetChildren()) do
		if obj == object then
			PositionningEvent.UpdatePartBuildingTool:InvokeClient(player, obj) --Allow to update the actual PartBuildingTool object modified into PositionningHandler client script
			if object:IsA("Model") then
				if dis then
					ToolsModule.SetWeldModelObject(object.PrimaryPart, false)
					ToolsModule.ScaleModel(object, dis)
					ToolsModule.SetWeldModelObject(object.PrimaryPart, true)
				end
				object:SetPrimaryPartCFrame(cframe)
				object.PrimaryPart.Anchored = anchor
				return
			else
				object.Size = size
				object.CFrame = cframe
				object.Anchored = anchor
				return
			end
		end
	end
	for _, race in pairs(game.Workspace.Races:GetChildren()) do
		if obj == race then
			if dis then
				ToolsModule.SetWeldModelObject(race.PrimaryPart, false)
				ToolsModule.ScaleModel(race, dis)
				ToolsModule.SetWeldModelObject(race.PrimaryPart, true)
			end
			race:SetPrimaryPartCFrame(cframe)
			return
		end
		if obj == race.PrimaryPart then
			race:SetPrimaryPartCFrame(cframe)
			race.PrimaryPart.Size = size
			return
		end
		for _, checkPoint in pairs(race.Checkpoints:GetChildren()) do
			if obj == checkPoint then
				checkPoint.Size = size
				checkPoint.CFrame = cframe
				--get player by RaceCreator to be sure to get the good player (it's not necessarily the owner who's moving it)
				RaceHandler:UpdateCheckpoints(checkPoint:GetAttribute("RaceCreator"))
			end
		end
	end
end)

function DeleteRace(player, model)
	local RaceLink = model:GetAttribute("RaceLink")
	local RaceCreator = model:GetAttribute("RaceCreator")
	RaceHandler:DeleteRace(RaceCreator, RaceLink, model)
end
PositionningEvent.DeleteRace.OnServerInvoke = DeleteRace

--This is the client event caller for LoadMap method
PositionningEvent.LoadMap.OnServerEvent:Connect(function(player, mapId, mapName)
	MapsManagerModule.LoadMap(player, mapId, mapName)
end)

--This remote function return the name of server for the client side
RemoteFunction.GetInfosServer.OnServerInvoke = function(player)
	return ServerName, IsPublicServer, IsAutorisedPositionningServer, game.PrivateServerId
end

RemoteFunction.GetPublicServers.OnServerInvoke = function()
	return MapsManagerModule.GetPublicServers()
end

RemoteFunction.GetOwnerServer.OnServerInvoke = function()
	return OwnerPlayer and OwnerPlayer.UserId or 0
end

GetOwnerServer.OnInvoke = function()
	return OwnerPlayer and OwnerPlayer.UserId or 0
end

RemoteFunction.GetAuthorisedPositionningPlayers.OnServerInvoke = function()
	return AuthorisedPositionningPlayers
end

RemoteEvent.RefreshPublicServersUI.OnServerEvent:Connect(MapsManagerModule.CheckServersOpen)

--Check on the first time start server, the opened server to public list
MapsManagerModule.CheckServersOpen()
--Check all 60s the list of server open, it's for try to respect quota of request Messaging service
task.spawn(function()
	while task.wait(60) do
		MapsManagerModule.CheckServersOpen()
	end
end)

local function autoSave()
	while task.wait(AUTOSAVE_INTERVAL) do
		print("Auto-saving farm constructions")
		AutoSaveMyFarmHouseServerOnly()
	end
end

--Initialize autosave loop
task.spawn(autoSave)

game.Players.PlayerAdded:Connect(playerAdded)
--here we add a little spawn function with 1s to check player after have setup server side (about check if its club server)
task.spawn(function()
	task.wait(1)
	for _, player in ipairs(game.Players:GetPlayers()) do
		playerAdded(player)
	end
end)

return MapsManagerModule
