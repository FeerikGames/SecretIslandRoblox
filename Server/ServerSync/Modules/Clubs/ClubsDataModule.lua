--To determine the type of data to work on
local dataType = "Test7"

local Players = game:GetService("Players")
local dataService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local MS = game:GetService("MessagingService")
local TextService = game:GetService("TextService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

local store = dataService:GetDataStore("ClubsData"..dataType)

local sessionClubData = {}

local keyAllClubs = "AllClubs"
local ListAllClubs = {}
local filterResults = {}

local ClubDataModule = {
	UpdateInProgress = false;
}

local AUTOSAVE_INTERVAL = 120

--Require Module
local PlayerDataModule = require("PlayerDataModule")
local TeleportModule = require("TeleportModule")
local EnvironmentModule = require("EnvironmentModule")

--Events
local RE_ClubUpdatedRefreshPlayersUI = RemoteEvent.ClubUpdatedRefreshPlayersUI
local RE_RequestToJoinClub = RemoteEvent.RequestToJoinClub
local BE_AchievementProgress = BindableEvent.AchievementProgress

local ClubDataStruct = {
	--Club Name is unique ID -> name string to upper -> used as key in datastore
	ClubName = "";
	ClubImage = "";
	ClubDescription = ""; --Limit description to 200 caracters
	NbMembers = 0;
	NbHorses = 0;
	Owner = 0; --Player ID owner of this club
	ListOfMembers = {
		--playerID = {PlayerName, Ranking, Reputation, NbHorses, Owner, Admin}
	};
	ListOfBannedMembers = {
		--playerID = Time of ban	
	};
	CodePrivateServer = ""; --Access code to specific server of club
	MapsDataPositionning = {};
}

--[[
	This method is used for filter a message text sended by a player and return a TextFilterResult who can
	be used to distribute the correctly filtered text to other players.
]]
local function getTextFilter(txt, fromPlayerId)
	local textObject
	local success, errorMessage = pcall(function()
		textObject = TextService:FilterStringAsync(txt, fromPlayerId)
	end)
	if success then
		--print("SUCESS TEXT FILTER")
		return textObject
	elseif errorMessage then
		warn("Error generating TextFilterResult:", errorMessage)
	else
		--print("NOT SUCESS TEXT FILTER")
	end
	return false
end

--[[
	This method returns the text in a properly filtered manner for all users. The parameter is the return
	of getTextFilter function (TextFilterResult type) and the function who allow this is a function of
	TextFilterResult : GetNonChatStringForBroadcastAsync()
]]
local function getFilteredMessage(textFilter)
	local filteredMessage
	local success, errorMessage = pcall(function()
		filteredMessage = textFilter:GetNonChatStringForBroadcastAsync()
	end)
	if success then
		--print("SUCESS FILTERED MESSAGE")
		return filteredMessage
	elseif errorMessage then
		warn("Error filtering message:", errorMessage)
	else
		--print("NOT SUCESS FILTERED MESSAGE")
	end
	return false
end

--[[
	This method create a messaging service data to send a message to other servers of game
	allow to say to other servers the club given in parameters have new datas or updated data.
	- See into MessagingServiceModule for the reception of message by others servers when this
	method send a PublishAsync.
]]
local function SendUpdateClubToOtherServer(clubName, memberData)
	local message = {
		ClubName = clubName;
		ServerID = game.JobId;
		MemberData = {
			Info = memberData[1],
			PlayerID = memberData[2],
			Data = memberData[3]
		};
	}
	print("TESTCLUB SEND UPDATE TO OTHER SERVER")
	MS:PublishAsync("ClubUpdated", message)
end

--[[
	This function allow to update the session data of server who receive a message update from other server who have modified data of one club give in message data.
	All specific case are indicate in message data and we make the change according to them.
]]
function ClubDataModule.UpdateSessionDataFromMessaging(message)
	local clubName = message.Data.ClubName
	local plrID = message.Data.MemberData.PlayerID
	local plrData = message.Data.MemberData.Data

	if message.Data.MemberData.Info == "ADD" then
		if not sessionClubData[clubName].ListOfMembers[plrID] then
			sessionClubData[clubName].ListOfMembers[plrID] = plrData
			sessionClubData[clubName].NbMembers += 1
			sessionClubData[clubName].NbHorses += plrData.NbHorses

			print("TESTCLUB PLAYER ADD HAS BEEN UPDATED ON THIS SERVEUR")
		end
	elseif message.Data.MemberData.Info == "DELETE" then
		if sessionClubData[clubName].ListOfMembers[plrID] then
			sessionClubData[clubName].NbMembers -= 1
			sessionClubData[clubName].NbHorses -= sessionClubData[clubName].ListOfMembers[plrID].NbHorses
			sessionClubData[clubName].ListOfMembers[plrID] = nil

			local playerDeleted = game.Players:GetPlayerByUserId(plrID)
			if playerDeleted then
				print("TESTCLUB Player deleted member found in this server, go refresh is UI")
				ClubDataModule.RefreshPlayerUI(playerDeleted)
			else
				print("TESTCLUB Player delete member not found in this server")
			end
			print("TESTCLUB PLAYER DELETE HAS BEEN UPDATED ON THIS SERVEUR")
		end
	elseif message.Data.MemberData.Info == "ChangeOwner" then
		local newOwnerId = tostring(plrID)
		if sessionClubData[clubName].ListOfMembers[newOwnerId] then
			sessionClubData[clubName].Owner = plrID
			sessionClubData[clubName].ListOfMembers[newOwnerId].Owner = true
			sessionClubData[clubName].ListOfMembers[newOwnerId].Admin = false
			sessionClubData[clubName].ListOfMembers[plrData].Owner = false

			print("TESTCLUB CHANGE OWNER HAS BEEN UPDATED ON THIS SERVEUR")
		end
	elseif message.Data.MemberData.Info == "ChangeAdmin" then
		if sessionClubData[clubName].ListOfMembers[plrID] then
			sessionClubData[clubName].ListOfMembers[plrID].Admin = plrData
			print("TESTCLUB CHANGE OWNER HAS BEEN UPDATED ON THIS SERVEUR")
		end
	elseif message.Data.MemberData.Info == "ChangeDesc" then
		sessionClubData[clubName].ClubDescription = plrData
	end
end

--[[
	Send a event to player match with members of club for refresh UI data
]]
function ClubDataModule.RefreshPlayersUIOfClub(clubName)
	for _, player in pairs(Players:GetPlayers()) do
		for playerID, data in pairs(sessionClubData[clubName].ListOfMembers) do
			if tostring(player.UserId) == playerID then
				RE_ClubUpdatedRefreshPlayersUI:FireClient(player)
				break
			end
		end
	end
end

--Send event for all client in the server to refresh club ui
function ClubDataModule.RefreshAllPlayersUI()
	RE_ClubUpdatedRefreshPlayersUI:FireAllClients()
end

--Send event to the player given in parameter to refresh this club ui
function ClubDataModule.RefreshPlayerUI(player)
	print("TESTCLUB REFRESH UI PLAYER")
	RE_ClubUpdatedRefreshPlayersUI:FireClient(player)
end

--Method to copy a dictionnary of data properly
ClubDataModule.recursiveCopy = function(dataTable)
	local tableCopy = {}
	for index, value in pairs(dataTable) do
		if type(value) == "table" then
			value = ClubDataModule.recursiveCopy(value)
		end
		tableCopy[index] = value
	end

	return tableCopy
end

--[[
	This method is used for create a new club, the player who create club is get by the caller
	method in RemoteFunctionHandler, same for datas needed to create club. The player who create club
	is the owner of club.
	
	CARFUL : This method can't assigne a private code for private server of club if it's executed
	in Studio play. ONLY WORK in game.
]]
function ClubDataModule.CreateNewClub(player, clubImg, clubName, clubDesc)
	local fromUserId = player.UserId
	local clubNameFiltered
	
	-- Filter the incoming text value and get the good textFilter for get the filtered name club
	clubNameFiltered = getFilteredMessage(getTextFilter(clubName, player.UserId))
	
	--check if filtered message are return success or not
	if not clubNameFiltered then
		return "ERROR"
	end
	
	--Check if string name are moderate, if yes interupt creation club
	if string.match(clubNameFiltered, "#") then
		return "MODERATED"
	end
	
	if sessionClubData[clubName] then
		print("TESTCLUB Club name already exist")
		return nil
	else
		print("TESTCLUB Club name not exist, can creating it")
		
		if PlayerDataModule:Get(player, "Club") ~= "" then
			print("TESTCLUB Player have already a club assigned, can't creating")
			return false
		else
		--if true then
			print("TESTCLUB Player don't have a club, creating it")
			sessionClubData[clubName] = ClubDataModule.recursiveCopy(ClubDataStruct)
			
			local nbHorses = PlayerDataModule:Get(player, "TotalNumberOfCreatures")
			
			sessionClubData[clubName].ClubName = clubName
			sessionClubData[clubName].ClubImage = clubImg
			sessionClubData[clubName].ClubDescription = clubDesc
			sessionClubData[clubName].NbMembers = 1
			sessionClubData[clubName].NbHorses = nbHorses
			sessionClubData[clubName].Owner = player.UserId
			sessionClubData[clubName].ListOfMembers[tostring(player.UserId)] = {
				PlayerName = player.Name;
				Ranking = PlayerDataModule:Get(player, "Ranking");
				Reputation= PlayerDataModule:Get(player, "Reputation");
				NbHorses = nbHorses;
				Owner = true;
				Admin = false;
			}
			
			pcall(function()
				--if club is create with studio, teleport service not work, so use pcall for no interupt exec
				--and if club is create in game, code is created
				sessionClubData[clubName].CodePrivateServer = TeleportService:ReserveServer(EnvironmentModule.GetPlaceId("ClubMap"))
			end)
			print("TESTCLUB dataclub",sessionClubData[clubName])
			PlayerDataModule:Set(player, clubName, "Club")
			table.insert(ListAllClubs, clubName)
			ClubDataModule.UpdateAllClubsList()
			ClubDataModule.saveClub(clubName)
			local message = {
				ClubName = clubName;
				ServerID = game.JobId;
			}
			
			BE_AchievementProgress:Fire(player, "Achievement6", 1)
			
			--Send information to other server for say, new club is created, so let's time to update
			--there list clubs name datas
			MS:PublishAsync("AllClubsUpdated", message)
			ClubDataModule.RefreshAllPlayersUI()
			return true
		end
	end
end

--[[
	This method allow to add a new member into a club after check if player added not have already a club.
	If its okay, we increment data for club with the player data new member and send messaging service
	to other server for make update of this club datas.
]]
function ClubDataModule.AddNewMember(player, clubName)
	if PlayerDataModule:Get(player, "Club") ~= "" then
		print("TESTCLUB Player have already a club assigned, can't adding in club")
		return false
	else
		print("TESTCLUB Player don't have club, adding...")
		local nbHorses = PlayerDataModule:Get(player, "TotalNumberOfCreatures")
		local newDataMember = {
			PlayerName = player.Name;
			Ranking = PlayerDataModule:Get(player, "Ranking");
			Reputation= PlayerDataModule:Get(player, "Reputation");
			NbHorses = nbHorses;
			Owner = false;
			Admin = false;
		}
		
		--try here to check with updateasync if we can add player
		local success, updatedData = pcall(function()
			--Use updateasync to prevent multiple server access to this data
			return store:UpdateAsync(clubName, function(data)
				ClubDataModule.UpdateInProgress = true
				print("TESTCLUB UPDATE CLUB ADDING MEMBER")
				if data then
					if not data.ListOfMembers[tostring(player.UserId)] then
						data.ListOfMembers[tostring(player.UserId)] = newDataMember
						data.NbMembers += 1
						data.NbHorses += nbHorses
					end
				end
	
				return data
			end)
		end)
		if success then
			if updatedData then
				print("TESTCLUB SUCCES UPDATE CLUB ADDING MEMBER")
				sessionClubData[clubName] = updatedData
				PlayerDataModule:Set(player, clubName, "Club")
				ClubDataModule.UpdateInProgress = false
			end
		end
		
		BE_AchievementProgress:Fire(player, "Achievement6", 1)
		
		SendUpdateClubToOtherServer(clubName, {"ADD", tostring(player.UserId), sessionClubData[clubName].ListOfMembers[tostring(player.UserId)]})
		ClubDataModule.RefreshPlayersUIOfClub(clubName)
		BindableEvent.ClubUpdate:Fire(clubName, sessionClubData[clubName], false, player)
	end
	
	return true
end

--[[
	This method allow to Delete member of club given, send updated data to other server and refresh interface
	for member of club. Send other server check if they have a deleted player for refresh ui.
	Else player is disconnected, and this ui and data refresh when is back and try to access on club where is
	not in member list of club (see ClubsCoreUI localscript L.62)
]]
function ClubDataModule.DeleteMember(player, playerId, clubName, banValue, typeBan)
	if sessionClubData[clubName].ListOfMembers[playerId] then
		--Check if player are banned from club if banValue is not 0
		--and check the type for duration chose by the owner or admin who ban player
		--The banValue is converted in seconds because os.time() return seconds and its more
		--easy to calculate the deadline to deban player
		if banValue ~= 0 then
			local banTimer = 0
			if typeBan == "Days" then
				print("BAN DAYS")
				banTimer = os.time() + ((banValue*24)*3600)
			elseif typeBan == "Minutes" then
				print("BAN Minutes")
				banTimer = os.time() + (banValue*60)
			elseif typeBan == "Seconds" then
				print("BAN Seconds")
				banTimer = os.time() + banValue
			end
			--adding player in the banned list of club with the time of ban
			sessionClubData[clubName].ListOfBannedMembers[playerId] = banTimer
			print("PlayerID", playerId)
			print("TEMPS DE BAN RESTANT EN SECONDE",os.difftime(sessionClubData[clubName].ListOfBannedMembers[playerId], os.time()))
		end
		
		--try here to check with updateasync if we can delete player
		local success, updatedData = pcall(function()
			--Use updateasync to prevent multiple server access to this data
			return store:UpdateAsync(clubName, function(data)
				ClubDataModule.UpdateInProgress = true
				print("TESTCLUB UPDATE CLUB DELETE MEMBER")
				if data then
					if data.ListOfMembers[playerId] then
						data.NbMembers -= 1
						data.NbHorses -= sessionClubData[clubName].ListOfMembers[playerId].NbHorses
						data.ListOfMembers[playerId] = nil
					end
				end
	
				return data
			end)
		end)
		if success then
			if updatedData then
				print("TESTCLUB UPDATE CLUB SUCCESS DELETE MEMBER")
				sessionClubData[clubName] = updatedData
				for index, v in pairs(sessionClubData[clubName].ListOfMembers) do
					print("TESTCLUB MEMBER : ", v.PlayerName)
				end
				ClubDataModule.UpdateInProgress = false
			end
		end

		SendUpdateClubToOtherServer(clubName, {"DELETE", playerId, nil})
		ClubDataModule.RefreshAllPlayersUI()

		BindableEvent.ClubUpdate:Fire(clubName, sessionClubData[clubName], game.Players:GetPlayerByUserId(playerId))
		if game.PlaceId == EnvironmentModule.GetPlaceId("ClubMap") then
			local p = game.Players:GetPlayerByUserId(playerId)
			if p then
				TeleportModule.teleportWithRetry(EnvironmentModule.GetPlaceId("MainPlace"), {p}, false) --if delete from club teleport him to public place
			end
		end
		return true
	end
end

function ClubDataModule.ChangeOwnerClub(clubName, newOwnerID, lastOwnerID)
	local newOwnerId = tostring(newOwnerID)
	--try here to check with updateasync
	local success, updatedData = pcall(function()
		--Use updateasync to prevent multiple server access to this data
		return store:UpdateAsync(clubName, function(data)
			ClubDataModule.UpdateInProgress = true
			if data then
				if data.ListOfMembers[newOwnerId] then
					data.Owner = newOwnerID
					data.ListOfMembers[newOwnerId].Owner = true
					data.ListOfMembers[newOwnerId].Admin = false
					data.ListOfMembers[lastOwnerID].Owner = false
				end
			end

			return data
		end)
	end)
	if success then
		if updatedData then
			print("TESTCLUB UPDATE DATA CLUB SUCCESS")
			sessionClubData[clubName] = updatedData
			ClubDataModule.UpdateInProgress = false
		end
	end

	SendUpdateClubToOtherServer(clubName, {"ChangeOwner", newOwnerID, lastOwnerID})
	ClubDataModule.RefreshPlayersUIOfClub(clubName)
end

function ClubDataModule.ChangeAdminClub(clubName, playerID, isAdmin)
	--try here to check with updateasync
	local success, updatedData = pcall(function()
		--Use updateasync to prevent multiple server access to this data
		return store:UpdateAsync(clubName, function(data)
			ClubDataModule.UpdateInProgress = true
			if data then
				if data.ListOfMembers[playerID] then
					data.ListOfMembers[playerID].Admin = isAdmin
				end
			end

			return data
		end)
	end)
	if success then
		if updatedData then
			print("TESTCLUB UPDATE DATA CLUB SUCCESS")
			sessionClubData[clubName] = updatedData
			ClubDataModule.UpdateInProgress = false
		end
	end

	SendUpdateClubToOtherServer(clubName, {"ChangeAdmin", playerID, isAdmin})
	ClubDataModule.RefreshPlayersUIOfClub(clubName)
end

function ClubDataModule.ChangeDescClub(clubName, text)
	--try here to check with updateasync
	local success, updatedData = pcall(function()
		--Use updateasync to prevent multiple server access to this data
		return store:UpdateAsync(clubName, function(data)
			ClubDataModule.UpdateInProgress = true
			if data then
				data.ClubDescription = text
			end

			return data
		end)
	end)
	if success then
		if updatedData then
			print("TESTCLUB UPDATE DATA CLUB SUCCESS")
			sessionClubData[clubName] = updatedData
			ClubDataModule.UpdateInProgress = false
		end
	end

	SendUpdateClubToOtherServer(clubName, {"ChangeDesc", nil, text})
	ClubDataModule.RefreshPlayersUIOfClub(clubName)
end

--[[
	This method is call when a player obtain a new horse /foal or loose one and need
	to update nb horse of player in club list and for all horses of on club.
	The parameter isAdd is a boolean true for adding horse and false for loosing horse.
]]
function ClubDataModule.UpdateHorsesOfClub(player, isAdd)
	local PlayerClub = PlayerDataModule:Get(player, "Club")
	--check player have club
	if sessionClubData[PlayerClub] then
		local ListMembers = sessionClubData[PlayerClub].ListOfMembers

		if isAdd then
			ListMembers[tostring(player.UserId)].NbHorses += 1
			sessionClubData[PlayerClub].NbHorses += 1
		else
			ListMembers[tostring(player.UserId)].NbHorses -= 1
			sessionClubData[PlayerClub].NbHorses -= 1
		end
	end
end

function ClubDataModule.GetDataClub(ClubName)
	return sessionClubData[ClubName]
end

function ClubDataModule.SetMapDataClub(ClubName, data)
	sessionClubData[ClubName].MapsDataPositionning = data
end

--[[
	This event have 2 type of caller
	- Called without playerRequestJoinID :
		Event is call first time when player want to join club with player parameter is the player caller
		and club name he want to join. Event get the owner of club and send a publish message
		to other server for found the owner and notify owner with popup (See in MessagingServiceModule the
		RequestToJoinClub subscribe event).
	- Called with the playerRequestJoinID :
		This Event is call a second time by notification button "Accept" with the player id accepted
		to join the club, sended by the owner of club. We check if player accepted is in this server
		and use AddNewMember() function for add it in club. If not found on this server, we send a
		messaging service to other server for found it and add it in club. (See MessagingServiceModule
		the subscribe event AddNewMemberRequest)
]]
RE_RequestToJoinClub.OnServerEvent:Connect(function(player, clubName, playerRequestJoinID)
	--if playerRequestJoinID exist this event is call by the owner with notification system
	--also we can check if the player id request exist on server and add it, if not, send message
	--to other server for find it and add it
	if playerRequestJoinID then
		--Check if player are in this server
		local playerRequest = game.Players:GetPlayerByUserId(playerRequestJoinID)
		if playerRequest then
			--Founded so adding it
			ClubDataModule.AddNewMember(playerRequest, clubName)
		else
			--Not found so send message other server to found player and add it
			local message = {
				Type = "Accepted";
				ClubName = clubName;
				PlayerID = playerRequestJoinID;
			}
			MS:PublishAsync("RequestToJoinClub", message)
		end
	else
		--check if player have already a club
		if PlayerDataModule:Get(player, "Club") ~= "" then
			print("TESTCLUB Player have already a club assigned, can't adding in club")
			return false
		end
		
		--check if player are banned from this club
		local TimeBanLimit = sessionClubData[clubName].ListOfBannedMembers[tostring(player.UserId)]
		if TimeBanLimit then
			--use difftime return seconds for check if diif between the time ban and actual time is equal
			--or under zero, if yes, player is no longer banned
			--if false, player alaway banned and return false for not notify owner or admin the request to join club
			if os.difftime(TimeBanLimit, os.time()) <= 0 then
				print("This player is DEBANNED of this club")
			else
				print("THIS PLAYER IS BANNED FROM THIS CLUB for", os.difftime(TimeBanLimit, os.time()))
				return false
			end
		end
		
		local ownerClubId = sessionClubData[clubName].Owner
		
		--make list of admin player id for approuve request join if owner not connected
		local listOfAdminClub = {}
		for index, value in pairs(sessionClubData[clubName].ListOfMembers) do
			if value.Admin then
				table.insert(listOfAdminClub, tonumber(index))
			end
		end
		
		local message = {
			Type = "Request";
			ClubName = clubName;
			PlayerRequestJoinName = player.Name;
			PlayerRequestJoinID = player.UserId;
			PlayerOwnerID = ownerClubId;
			ListOfAdminClub = listOfAdminClub;
		}
		MS:PublishAsync("RequestToJoinClub", message)
	end
end)

--This method is for setup the table session data of one club
ClubDataModule.setupClubData = function(clubName)
	if not ClubDataModule.UpdateInProgress then
		local data = ClubDataModule.loadClub(clubName)
	
		if data then
			sessionClubData[clubName] = data
			print("TESTCLUB SETUP CLUB DATA : ", clubName.. " data has been loaded!", sessionClubData[clubName])
			BindableEvent.ClubUpdate:Fire(clubName, sessionClubData[clubName])
		end
	end
end

--This method is to setup all datas for clubs, set the list of club exist in game and setup session data for all club existed
ClubDataModule.setupAllDatasClubs = function()
	local data = ClubDataModule.loadListAllClub()
	
	--reset all clubs
	ListAllClubs = {}

	if data then
		for index, value in pairs(data) do
			ClubDataModule.setupClubData(value)
			table.insert(ListAllClubs, value)
		end

		print("TESTCLUB All club data has been loaded!", ListAllClubs)
	end
end

--Thie method allow to setup the session list of club exist in game
ClubDataModule.setupListClubs = function()
	local data = ClubDataModule.loadListAllClub()

	--reset all clubs list
	ListAllClubs = {}

	if data then
		for index, value in pairs(data) do
			table.insert(ListAllClubs, value)
		end

		print("TESTCLUB List of clubs has been loaded!", ListAllClubs)
	end
end

--This method allow to get data from a club name given in paramters. return a dictionnary of club datas
ClubDataModule.loadClub = function(clubName)
	local key = clubName
	local data 
	local success, err = pcall(function()
		data = store:GetAsync(key)
	end)

	if not success then
		data = ClubDataModule.loadClub(clubName)
	end

	return data
end

--This method return a list of club name exist in game from datastore
ClubDataModule.loadListAllClub = function()
	local data 
	local success, err = pcall(function()
		data = store:GetAsync(keyAllClubs)
	end)

	if not success then
		data = ClubDataModule.loadListAllClub()
	end
	
	return data
end

--Getter of session club datas, return dictionnary with all clubs datas in this server
ClubDataModule.getAllClub = function()
	return sessionClubData
end

ClubDataModule.GetSessionClubData = function()
	return sessionClubData
end

--Get datas of club given with a system filtering message for check display of name and desc club
ClubDataModule.GetClub = function(player, clubName)
	local sessionClubDataFiltered = ClubDataModule.recursiveCopy(sessionClubData[clubName])
	local clubNameFiltered
	local clubDescFiltered

	-- Filter the incoming text value and get the good textFilter for get the filtered name and desc club properly
	clubNameFiltered = getFilteredMessage(getTextFilter(sessionClubData[clubName].ClubName, player.UserId))
	clubDescFiltered = getFilteredMessage(getTextFilter(sessionClubData[clubName].ClubDescription, player.UserId))

	--check if filtered message are return success or not
	if not clubNameFiltered or not clubDescFiltered then
		error("Error club name or club desc getted are not filtered successful...")
		return
	end
	
	--set the filtered text to the return session club for player display properly the text filtered
	sessionClubDataFiltered.ClubName = clubNameFiltered
	sessionClubDataFiltered.ClubDescription = clubDescFiltered
		
	return sessionClubDataFiltered
end

--This method save in datastore the list of all club name existed in game
function ClubDataModule.UpdateAllClubsList()
	local success, updatedData = pcall(function()
        --Use updateasync to prevent multiple server access to this data
        return store:UpdateAsync(keyAllClubs, function(data)
            local newData = {}
            if data then
                for _, v in pairs(data) do
                    table.insert(newData, v)
                end
            end
            
            for _, v in pairs(ListAllClubs) do
                if not table.find(newData, v) then
                    table.insert(newData, v)
                end
            end

            return newData
        end)
    end)
	if success then
        print("TESTCLUB","Data Clubs ListAllClubs Updated")
        ListAllClubs = updatedData
    end
end

--This method save in datastore the club datas of club given in parameters
ClubDataModule.saveClub = function(clubName)
	local key = clubName
	local data = ClubDataModule.recursiveCopy(sessionClubData[key])

	local success, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if success then
		print("TESTCLUB",clubName.. " data has been saved!")
	else
		ClubDataModule.saveClub(clubName)
	end
end

ClubDataModule.removeSessionClubData = function(player)
	local key = player.UserId
	sessionClubData[key] = nil
end

game:BindToClose(function()
	
end)

ClubDataModule.setupAllDatasClubs()

return ClubDataModule