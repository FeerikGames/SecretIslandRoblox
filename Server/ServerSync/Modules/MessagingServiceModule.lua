local MessagingServiceModule = {}
local MS = game:GetService("MessagingService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

--Events
local RE_FriendInvitToJoin = RemoteEvent.FriendInvitToJoin
local RE_RequestToJoinClub = RemoteEvent.RequestToJoinClub

--Require Module
local PlayerDataModule = require("PlayerDataModule")
local ClubDataModule = require("ClubsDataModule")
local EnvironmentModule = require("EnvironmentModule")

--Subscribe function topics for receive friend invitation
MS:SubscribeAsync("FriendInvitToJoin", function(message)
	local playerInvited = game.Players:GetPlayerByUserId(message.Data.PlayerInvitedID)
	if playerInvited then
		print("player invited", playerInvited)
		print("player caller", message.Data.PlayerCallerName)
		
		RE_FriendInvitToJoin:FireClient(
			playerInvited,
			"Invitation",
			message.Data.PlayerCallerName.." vous invite à rejoindre son serveur !",
			message.Data.ServerToJoinID,
			message.Data.ServerPlaceID,
			message.Data.IsPrivate,
			message.Data.Code
		)
	end
end)

--[[
	Subscribe function topics for receive club join request asked by player to owner of club or admin
	if owner is not connected (if nobody is connected, admin or owner, do nothing)
	2 type of caller :
		- Type is Accepted : So the subscribe function go to setup add new member because accepted by
		owner of club
		- Type is Request : One player send request to owner of club for join there club.
	The message table avec a data "Type" allow to determine what is the behaviour of this event.
]]
MS:SubscribeAsync("RequestToJoinClub", function(message)
	--add a new member to club name sended by request join club
	if message.Data.Type == "Accepted" then
		--check if player are in this server for add it
		local player = game.Players:GetPlayerByUserId(message.Data.PlayerID)
		if player then
			ClubDataModule.AddNewMember(player, message.Data.ClubName)
		end
		
	--A player send request to owner of club to join
	elseif message.Data.Type == "Request" then
		local playerOwner = game.Players:GetPlayerByUserId(message.Data.PlayerOwnerID)
		if playerOwner then
			--owner found on this server
			print("player owner", playerOwner)
			print("player request to join", message.Data.PlayerRequestJoinName)
			
			--Send notification popup to owner to make decision
			RE_RequestToJoinClub:FireClient(
				playerOwner,
				"Club Notification",
				message.Data.PlayerRequestJoinName.." souhaite rejoindre votre club !",
				message.Data.PlayerRequestJoinID,
				message.Data.ClubName
			)
		else
			--If owner not found on this server, try to send the notification to first admin founded
			for _, adminID in pairs(message.Data.ListOfAdminClub) do
				local connectedAdminPlayer = game.Players:GetPlayerByUserId(adminID)
				--get and check if admin player found in the server and send to the first found admin
				if connectedAdminPlayer then
					--Send notification popup
					RE_RequestToJoinClub:FireClient(
						connectedAdminPlayer,
						"Club Notification",
						message.Data.PlayerRequestJoinName.." souhaite rejoindre votre club !",
						message.Data.PlayerRequestJoinID,
						message.Data.ClubName
					)
					break
				end
			end
		end
	end
end)

--Subscribe function topics for club updated data and check if deleted member
MS:SubscribeAsync("ClubUpdated", function(message)
	if message.Data.ServerID ~= game.JobId then
		print("TESTCLUB Club "..message.Data.ClubName.." Updated on this server !")
		
		--Make check type of update and change the serveur session data by info given in message
		ClubDataModule.UpdateSessionDataFromMessaging(message)
		ClubDataModule.RefreshPlayersUIOfClub(message.Data.ClubName)
	end
end)

--Subscribe function topics when new club is create and all clubs tables is updated
MS:SubscribeAsync("AllClubsUpdated", function(message)
	if message.Data.ServerID ~= game.JobId then
		ClubDataModule.setupListClubs()
		ClubDataModule.setupClubData(message.Data.ClubName)
		ClubDataModule.RefreshAllPlayersUI()
	end
end)

--[[
	This event listener allow to send a publish message to other server to find the player invited
	to join the private server of player caller.
	Message contain information for make a teleportation properly to the player invited.
	The function subscribe to this event is MS:SubscribeAsync("FriendInvitToJoin") into MessagingServiceModule
]]
RE_FriendInvitToJoin.OnServerEvent:Connect(function(playerCaller, playerInvitedId, serverToJoinId, serverPlaceId)
	--check if the player caller are in private server
	local isPrivate = false
	if game.PrivateServerId ~= "" then
		isPrivate = true
		serverToJoinId = game.PrivateServerId
	end

	local ClubData = ClubDataModule.GetDataClub(PlayerDataModule:Get(playerCaller, "Club"))
	
	local message = {
		PlayerCallerName = playerCaller.Name;
		PlayerInvitedID = playerInvitedId;
		ServerToJoinID = serverToJoinId;
		ServerPlaceID = serverPlaceId;
		IsPrivate = isPrivate;
		Code = serverPlaceId == EnvironmentModule.GetPlaceId("ClubMap") and ClubData.CodePrivateServer or false --check to give code server access only if it's a Club Map PlaceID
	}
	MS:PublishAsync("FriendInvitToJoin", message)
end)

return MessagingServiceModule
