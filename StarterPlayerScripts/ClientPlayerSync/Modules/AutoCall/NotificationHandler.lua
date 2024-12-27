local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local RemoteEvent = ReplicatedStorage.RemoteEvent

local RE_Notif = RemoteEvent.ShowNotification
local RE_FriendInvitToJoin = RemoteEvent.FriendInvitToJoin
local RE_FriendInvitToPrivateServer = RemoteEvent.FriendInvitToPrivateServer
local RE_RequestToJoinClub = RemoteEvent.RequestToJoinClub

local TS = game:GetService("TeleportService")

local Player = game.Players.LocalPlayer

local function CallbackNotif(text)
	print(text)
end

--Event listener to create a simple popup notification
RE_Notif.OnClientEvent:Connect(function(title, message)
	local NotificationBindable = Instance.new("BindableFunction")
	NotificationBindable.OnInvoke = CallbackNotif
	
	game.StarterGui:SetCore("SendNotification", {
		Title = title;
		Text = message;
		Icon = "";
		Duration = 7;
		Button1 = "OK";
		Callback = NotificationBindable;
	})
end)

--[[
	Event listener to make a functionnal popup notification for player who invited to join private server
	of friend.
	Create popup and use BindableFunction for make the behaviour of button clicked in popup notification.
	WARN : Teleportation does not work with Roblox Studio, publish and try it directly in game.
]]
RE_FriendInvitToJoin.OnClientEvent:Connect(function(title, message, serverToJoinID, serverPlaceID, isPrivate, code)
	local NotificationBindable = Instance.new("BindableFunction")
	--The behaviour of button when clicked in popup notification
	NotificationBindable.OnInvoke = function(text)
		print("Server to join ID :",serverToJoinID)
		--Check if the server where player is invited is a private or public server
		if isPrivate then
			--if it's private server send event to call server to make a private teleportation
			--teleportation in private server can't be make by localscript
			RE_FriendInvitToPrivateServer:FireServer(serverToJoinID, serverPlaceID, code)
		else
			--If it's public serveur, localscript can do it and make here the player teleportation with
			--server destination
			TS:TeleportToPlaceInstance(serverPlaceID, serverToJoinID, Player)
		end
	end
	
	--Make a popup notification with one button and set behaviour of button
	game.StarterGui:SetCore("SendNotification", {
		Title = title;
		Text = message;
		Icon = "";
		Duration = 10;
		Button1 = "Rejoindre";
		Callback = NotificationBindable;
	})
end)

--[[
	Event listener to make a functionnal popup notification for player who receive a request add into the
	club of player called (player can be a admin or owner of club).
	Create popup and use BindableFunction for make the behaviour of button clicked in popup notification.
]]
RE_RequestToJoinClub.OnClientEvent:Connect(function(title, message, playerRequestJoinID, clubName)
	local NotificationBindable = Instance.new("BindableFunction")
	--Behaviour of buttons
	NotificationBindable.OnInvoke = function(text)
		--If player accept the request, send to the event of server the same event with a
		--adtionnal parameter who is the player request ID (See reception event into ClubDataModule)
		if text == "Accept" then
			RE_RequestToJoinClub:FireServer(clubName, playerRequestJoinID)
		end
	end
	
	--Make popup notification with 2 buttons and set the behavior of button "Accept"
	game.StarterGui:SetCore("SendNotification", {
		Title = title;
		Text = message;
		Icon = "";
		Duration = 20;
		Button1 = "Accept";
		Button2 = "Decline";
		Callback = NotificationBindable;
	})
end)

return module
