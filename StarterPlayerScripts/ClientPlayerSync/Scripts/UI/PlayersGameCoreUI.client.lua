local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

local StarterGui = game:GetService("StarterGui")
local SocialService = game:GetService("SocialService")
local Player = game.Players.LocalPlayer

local ListPlaceIDofGame = {
	EnvironmentModule.GetPlaceId("MainPlace"),
	EnvironmentModule.GetPlaceId("MyFarm"),
	EnvironmentModule.GetPlaceId("FashionShow"),
	EnvironmentModule.GetPlaceId("MapA"),
	EnvironmentModule.GetPlaceId("MapB"),
	EnvironmentModule.GetPlaceId("ClubMap"),
}

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local WalkSpeedModule = require("WalkSpeedModule")

--Remotes
local RemoteFunction = ReplicatedStorage.RemoteFunction
local RE_FriendInvit = ReplicatedStorage.RemoteEvent.FriendInvitToJoin

local GetDataOfPlayer = RemoteFunction:WaitForChild("GetDataOfPlayer")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local PlayersGameGui = UIProviderModule:GetUI("PlayersGameGui")
local GiftTradeGui:ScreenGui = UIProviderModule:GetUI("GiftTradeGui")
local Background = PlayersGameGui:WaitForChild("Background")
local PlayersList = Background.PlayersList
local FriendsList = Background.FriendsList
local PlayersListBtn = Background.PlayersListBtn
local FriendsListBtn = Background.FriendsListBtn
local TemplateItemPlayer = PlayersGameGui.Template.ItemPlayer
local ShowUiBtn = AllButtonsMainMenusGui.SubMenu.PlayersGameGuiBtn
local InvitFriendsBtn = Background.InvitFriendBtn

local function InitPlayersList()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", PlayersList)
	
	local players = game.Players:GetPlayers()
	for _, plr in pairs(players) do
		local IsFriend = plr:IsFriendsWith(Player.UserId)

		local cloneItem = TemplateItemPlayer:Clone()
		cloneItem.Visible = true
		cloneItem.Name = plr.Name
		
		if plr == Player then
			cloneItem.LayoutOrder = 0
			cloneItem.ActionButton.Visible = false
			local TotalCreatures = PlayerDataModule.LocalData.TotalNumberOfCreatures
			cloneItem.NbHorses.Text = "Creatures : "..TotalCreatures
		else
			if not IsFriend then
				cloneItem.ActionButton.Activated:Connect(function()
					StarterGui:SetCore("PromptSendFriendRequest", plr)
					Background.Visible = false
				end)
			else
				cloneItem.ActionButton.Active = false
				cloneItem.ActionButton.ActionTxt.Text = "Friend"
			end

			local TotalCreatures = GetDataOfPlayer:InvokeServer(plr, "TotalNumberOfCreatures")
			if TotalCreatures then
				cloneItem.NbHorses.Text = "Creatures : "..TotalCreatures
			end
		end

		cloneItem.PlayerIcon.Image = game.Players:GetUserThumbnailAsync(
			plr.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		cloneItem.PlayerName.Text = plr.Name

		-- If player click on button to send gift or trade with player we open UI GiftTrade ScreenGui
		cloneItem.GiftTradeButton.Activated:Connect(function()
			Background.Visible = false
			GiftTradeGui.SelectAction.Visible = true

			GiftTradeGui.SelectAction.GiftButton.Activated:Connect(function()
				GiftTradeGui.GiftBackground.Visible = true
				GiftTradeGui.SelectAction.Visible = false
			end)

			GiftTradeGui.SelectAction.TradeButton.Activated:Connect(function()
				GiftTradeGui.TradeBackground.Visible = true
				GiftTradeGui.SelectAction.Visible = false

				GiftTradeGui.TradeBackground.OtherPlayerInfos.PlrName.Text = plr.Name
				GiftTradeGui.TradeBackground.OtherPlayerInfos.ImageLabel.Image = game.Players:GetUserThumbnailAsync(
					plr.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)
		end)
		
		cloneItem.Parent = PlayersList
	end
end

local function InitFriendsList()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", FriendsList)

	local onlineFriends = Player:GetFriendsOnline()
	
	for _, plr in pairs(onlineFriends) do
		local cloneItem = TemplateItemPlayer:Clone()
		cloneItem.Visible = true
		cloneItem.Name = plr.UserName

		cloneItem.PlayerIcon.Image = game.Players:GetUserThumbnailAsync(
			plr.VisitorId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		cloneItem.PlayerName.Text = plr.UserName
		
		--Check if actually in the game or not
		if table.find(ListPlaceIDofGame, plr.PlaceId) then
			cloneItem.LayoutOrder = 0
			cloneItem.NbHorses.Text = "In game"
			cloneItem.NbHorses.TextColor3 = Color3.fromRGB(0, 255, 0)
			
			cloneItem.ActionButton.ActionTxt.Text = "Invit to joins"
			cloneItem.ActionButton.Activated:Connect(function()
				--in the same game, can try to send invitation
				RE_FriendInvit:FireServer(plr.VisitorId, game.JobId, game.PlaceId)
				Background.Visible = false
			end)
		else
			cloneItem.LayoutOrder = 2
			cloneItem.NbHorses.Text = "Not in the game"
			cloneItem.NbHorses.TextColor3 = Color3.fromRGB(255, 0, 0)
			cloneItem.ActionButton.Visible = false
		end
		
		cloneItem.Parent = FriendsList
	end
end

Background:GetPropertyChangedSignal("Visible"):Connect(function()
	WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
	ToolsModule.EnableOtherUI(not Background.Visible, {"PlayersGameGui"})
	if Background.Visible then
		PlayersList.Visible = true
		FriendsList.Visible = false
		InitPlayersList()
		InitFriendsList()
	end
end)

FriendsList:GetPropertyChangedSignal("Visible"):Connect(function()
	InitFriendsList()
end)

InvitFriendsBtn.Activated:Connect(function()
	local res, canInvite = pcall(SocialService.PromptGameInvite, SocialService, Player)
	if res then
		Background.Visible = false
	end
end)

--Button Event Switch
FriendsListBtn.Activated:Connect(function()
	if not FriendsList.Visible then
		FriendsList.Visible = true
		PlayersList.Visible = false
	end
end)

PlayersListBtn.Activated:Connect(function()
	if not PlayersList.Visible then
		PlayersList.Visible = true
		FriendsList.Visible = false
	end
end)

ShowUiBtn.Activated:Connect(function()	
	Background.Visible = not Background.Visible
end)

--InitPlayersList()
--InitFriendsList()


