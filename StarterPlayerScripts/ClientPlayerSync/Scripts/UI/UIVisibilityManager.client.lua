local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local UIProviderModule = require("UIProviderModule")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

local BreedingGui = UIProviderModule:GetUI("BreedingGui")
local GenesCollectionGui = UIProviderModule:GetUI("GenesCollectionGui")
local HorsesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
local FilterGui = UIProviderModule:GetUI("FilterGui")
local PlayerInfosGui = UIProviderModule:GetUI("PlayerInfosGui")
local PlayerProfilUI = PlayerInfosGui:WaitForChild("PlayerProfile")
local PlayersGameGui = UIProviderModule:GetUI("PlayersGameGui")
local ClubsGui = UIProviderModule:GetUI("ClubsGui")
local AchievementsGui = UIProviderModule:GetUI("AchievementsGui")
local MapsGui = UIProviderModule:GetUI("MapsGui")
local PositionningGui = UIProviderModule:GetUI("PositionningGui")
local ShopItemsGui = UIProviderModule:GetUI("ShopItemsGui")

BreedingGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if BreedingGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
	PlayerInfosGui.PreviewPlayer.Visible = not BreedingGui.Background.Visible
end)

GenesCollectionGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if GenesCollectionGui.Background.Visible then
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

HorsesCollectionGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if HorsesCollectionGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

PlayerProfilUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if PlayerProfilUI.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayersGameGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

PlayersGameGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if PlayersGameGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		AchievementsGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

ClubsGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if ClubsGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

AchievementsGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if AchievementsGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

MapsGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if MapsGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
	end
end)

PositionningGui.Background:GetPropertyChangedSignal("Visible"):Connect(function()
	if PositionningGui.Background.Visible then
		GenesCollectionGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		ShopItemsGui.ShopFrame.Visible = false
	end
end)

ShopItemsGui.ShopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if ShopItemsGui.ShopFrame.Visible then
		GenesCollectionGui.Background.Visible = false
		HorsesCollectionGui.Background.Visible = false
		BreedingGui.Background.Visible = false
		PlayerProfilUI.Visible = false
		PlayersGameGui.Background.Visible = false
		ClubsGui.Background.Visible = false
		AchievementsGui.Background.Visible = false
		MapsGui.Background.Visible = false
		PositionningGui.Background.Visible = false
	end
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not ShopItemsGui.ShopFrame.Visible)
end)

PositionningGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	
end)

RemoteEvent.EnabledPositionningGui.OnClientEvent:Connect(function(enabledPositionning, enableMapAdmin)
	PositionningGui.Enabled = enabledPositionning
	MapsGui.Background.AdminMapBtn.Visible = enableMapAdmin
end)