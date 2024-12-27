local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TweenService = game:GetService("TweenService")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game.Players.LocalPlayer

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local UIAnimationModule = require("UIAnimationModule")
local WalkSpeedModule = require("WalkSpeedModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

--Remotes
local RemoteFunction = ReplicatedStorage.RemoteFunction
local RemoteEvent = ReplicatedStorage.RemoteEvent
local RE_AchievementProgress = ReplicatedStorage.RemoteEvent.AchievementProgress

--Params
local gainAnimDurationInFrame = 30
local UIFarmIsOpen = false

--UI
local PlayerInfosGui = UIProviderModule:GetUI("PlayerInfosGui")
local PreviewPlayerUI = PlayerInfosGui:WaitForChild("PreviewPlayer")
local CreatureInteractionGui = UIProviderModule:GetUI("CreatureInteractionGui")
local PlayerProfileUI = PlayerInfosGui:WaitForChild("PlayerProfile")
local HorseFavTemplate = PlayerInfosGui.Template.HorseFavTemplate
local ItemEachRace = PlayerInfosGui.Template.ItemEachRace
local PopupAlertGui = UIProviderModule:GetUI("PopupAlertGui")
local NbAlert = PopupAlertGui:WaitForChild("AlertFeed"):WaitForChild("NbAlert")
local CrystalsCurrencyFrame = PlayerInfosGui.CrystalsCurrencyFrame

local PlayerIcon = game.Players:GetUserThumbnailAsync(
	Player.UserId,
	Enum.ThumbnailType.HeadShot,
	Enum.ThumbnailSize.Size420x420
)

local function SetNbAlert(val)
	if val > 99 then
		PreviewPlayerUI.ShowAlertFeed.NbAlert.Text = "99+"
	else
		PreviewPlayerUI.ShowAlertFeed.NbAlert.Text = val
	end
end

local function ApplyEcusAchievement(OldValue, NewValue)
	if NewValue > OldValue then
		RE_AchievementProgress:FireServer("Achievement3", NewValue-OldValue)
		RE_AchievementProgress:FireServer("Achievement7", NewValue-OldValue)
	end
end

--Disable jauge sparks not used, dont delete because we can use it later
local function ApplyCurrencyChangeToSparkUi(currencyType, tween, barTween)
	local initValue = CreatureInteractionGui.SparksFrame.ValueTxt.Text:match("^%d+")
	local currentValue = PlayerDataModule.LocalData[currencyType]
	local maxValue = PlayerDataModule.LocalData["Max"..currencyType]
	local valueChangeAbsolute = math.abs(currentValue - tonumber(initValue))
	if currentValue <= 30 then
		CreatureInteractionGui.SparksFrame.Bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	elseif currentValue <= 40 then
		CreatureInteractionGui.SparksFrame.Bar.BackgroundColor3 = Color3.fromRGB(255, 187, 0)
	else
		CreatureInteractionGui.SparksFrame.Bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	end
	if currentValue <= 0 then
		CreatureInteractionGui.SparksFrame.Bar.Visible = false
	else
		CreatureInteractionGui.SparksFrame.Bar.Visible = true
	end
	if valueChangeAbsolute > 2 then
		local from = tonumber(initValue)
		local to = currentValue
		tween:Cancel()
		tween:Play()
		UIAnimationModule.StartTextNumberIncrementAnimation(CreatureInteractionGui.SparksFrame.ValueTxt, from, to, gainAnimDurationInFrame)
		if valueChangeAbsolute > 10 then
			local currentBarValue = currentValue
			if currentValue > maxValue then
				currentBarValue = maxValue
			end
			local barTween = UIAnimationModule.InitTweenParamBarAnimation(CreatureInteractionGui.SparksFrame.Bar, currentBarValue, maxValue)
			barTween:Cancel()
			barTween:Play()
		end
	end
	local barSize = math.clamp(currentValue/maxValue, 0, 1)
	CreatureInteractionGui.SparksFrame.Bar.Size = UDim2.fromScale(barSize, CreatureInteractionGui.SparksFrame.Bar.Size.Y.Scale)
	CreatureInteractionGui.SparksFrame.ValueTxt.Text = math.round(currentValue)
end

local function ApplyCurrencyChangeToUi(currencyType, OldValue, NewValue)
	local valueChangeAbsolute = math.abs(OldValue - NewValue)
	if valueChangeAbsolute > 1 then
		UIAnimationModule.StartTextNumberIncrementAnimation(PreviewPlayerUI[currencyType.."Frame"].ValueTxt, OldValue, NewValue, gainAnimDurationInFrame)
	end
	PreviewPlayerUI[currencyType.."Frame"].ValueTxt.Text = ToolsModule.AbbreviateNumber(PlayerDataModule.LocalData[currencyType])--ToolsModule.DotNumber(PlayerDataModule.LocalData[currencyType])
end

local function Init()
	-- Setup UI for Crystals Frame
	for _, child in pairs(CrystalsCurrencyFrame.Crystals:GetChildren()) do
		if child:IsA("Frame") then
			child.IconImg.Image = GameDataModule.DropCollectablesWithBorders[child.Name]
			local button = child:FindFirstChild("ShowPurchase")
			if button then
				button.Activated:Connect(function()
					print('Clicked')
				end)
			end
		end
	end

	repeat
		task.wait(.2)
	until PlayerDataModule.LocalData.Ecus
	
	local EcusFrameTween = UIAnimationModule.BouncyCurrencyBarFeedback(PreviewPlayerUI.EcusFrame)
	PreviewPlayerUI.EcusFrame.ValueTxt.Text = ToolsModule.AbbreviateNumber(PlayerDataModule.LocalData.Ecus)--ToolsModule.DotNumber(PlayerDataModule.LocalData.Ecus)
	PlayerDataModule:Changed("Ecus", function(OldValue,Value)
		if Value - OldValue > 0 then
			if EcusFrameTween.PlaybackState ~= Enum.PlaybackState.Playing then
				EcusFrameTween:Play()
			end
		end

		task.spawn(function()
			UIAnimationModule.FeedbackCurrencyDrop("Ecus", OldValue, Value)
		end)

		task.spawn(function()
			ApplyCurrencyChangeToUi("Ecus", OldValue, Value)
		end)

		ApplyEcusAchievement(OldValue, Value)
	end)
	
	local FeezFrameTween = UIAnimationModule.BouncyCurrencyBarFeedback(PreviewPlayerUI.FeezFrame)
	PreviewPlayerUI.FeezFrame.ValueTxt.Text = ToolsModule.AbbreviateNumber(PlayerDataModule.LocalData.Feez)--ToolsModule.DotNumber(PlayerDataModule.LocalData.Feez)
	PlayerDataModule:Changed("Feez", function(OldValue, Value)
		if Value - OldValue > 0 then
			if FeezFrameTween.PlaybackState ~= Enum.PlaybackState.Playing then
				FeezFrameTween:Play()
			end
		end

		task.spawn(function()
			UIAnimationModule.FeedbackCurrencyDrop("Feez", OldValue, Value)
		end)

		task.spawn(function()
			ApplyCurrencyChangeToUi("Feez", OldValue, Value)
		end)
	end)


	PreviewPlayerUI.SparksFrame.ValueTxt.Text = ToolsModule.AbbreviateNumber(PlayerDataModule.LocalData.Sparks)--ToolsModule.DotNumber(PlayerDataModule.LocalData.Sparks)
	PlayerDataModule:Changed("Sparks", function(OldValue, Value)
		task.spawn(function()
			ApplyCurrencyChangeToUi("Sparks", OldValue, Value)
		end)
		if Value - OldValue > 0 then
			UIAnimationModule.FeedbackCurrencyDrop("Sparks", OldValue, Value)
		end
	end)

	local HarvestFrameTween = UIAnimationModule.BouncyCurrencyBarFeedback(PreviewPlayerUI.TotalHarvestsFrame)
	PreviewPlayerUI.TotalHarvestsFrame.ValueTxt.Text = ToolsModule.AbbreviateNumber(PlayerDataModule.LocalData.TotalHarvests)--ToolsModule.DotNumber(PlayerDataModule.LocalData.TotalHarvests)
	PlayerDataModule:Changed("TotalHarvests", function(OldValue, Value)
		if Value - OldValue > 0 then
			if HarvestFrameTween.PlaybackState ~= Enum.PlaybackState.Playing then
				HarvestFrameTween:Play()
			end
		end

		if Value - OldValue > 0 then
			if not UIFarmIsOpen then
				task.spawn(function()
					UIAnimationModule.FeedbackCurrencyDrop("TotalHarvests", OldValue, Value)
				end)
			end
		end

		task.spawn(function()
			ApplyCurrencyChangeToUi("TotalHarvests", OldValue, Value)
		end)
	end)

	-- Behavior for Crystals currency
	for id, value in pairs(PlayerDataModule.LocalData.Crystals) do
		CrystalsCurrencyFrame.Crystals[id].ValueTxt.Text = ToolsModule.DotNumber(value)
		PlayerDataModule:Changed("Crystals."..id, function(OldValue, Value)
			CrystalsCurrencyFrame.Crystals[id].ValueTxt.Text = ToolsModule.DotNumber(Value)
			task.spawn(function()
				UIAnimationModule.FeedbackCurrencyDrop(id, OldValue, Value)
			end)
		end)
	end
	
	if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
		UIProviderModule:GetUI("AllButtonsMainMenusGui").SubMenu.PlayerProfil.Activated:Connect(function()
			PlayerProfileUI.Visible = not PlayerProfileUI.Visible
		end)
	end
	
	SetNbAlert(NbAlert.Value)
end

local function DepopulateUIProfil()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", PlayerProfileUI.CreaturesTypes.Grid)
	ToolsModule.DepopulateTypeOfItemFrom("ImageButton", PlayerProfileUI.FavouritesHorses.Grid)
end

local function PopulateCreatureTypeNumber(creatureType)
	ToolsModule.DepopulateTypeOfItemFrom("Frame", PlayerProfileUI.CreaturesRaces.Grid)
	for index, data in pairs(creatureType) do
		if GameDataModule.RaceIcons[index] then
			local clone = ItemEachRace:Clone()
			clone.Visible = true
			clone.Name = index
			clone.Total.Text = tostring(data)
			clone.Race.Image = GameDataModule.RaceIcons[index]
			clone.Race:SetAttribute("TextHover", index)
			clone.Parent = PlayerProfileUI.CreaturesRaces.Grid
		end
	end
	PlayerProfileUI.CreaturesRaces.Visible = true
end

local function PopulateDataUIProfile()
	DepopulateUIProfil()
	
	PlayerProfileUI.Infos.PlayerIcon.Image = PlayerIcon
	PlayerProfileUI.Infos.DateSignedUp.Text = "Inscrit le : "..PlayerDataModule.LocalData.DateSignedUp
	PlayerProfileUI.Infos.TotalNumberOfHorses.Text = "Possède : "..PlayerDataModule.LocalData.TotalNumberOfCreatures.." Supras"
	PlayerProfileUI.Infos.ReputationFrame.ValueTxt.Text = PlayerDataModule.LocalData.Reputation
	PlayerProfileUI.Infos.RankingFrame.ValueTxt.Text = PlayerDataModule.LocalData.Ranking
	
	for type, creatureType in pairs(PlayerDataModule.LocalData.TotalNumberOfCreaturesType) do
		local clone = PlayerInfosGui.Template.ItemEachType:Clone()
		clone.Visible = true
		clone.Name = type
		clone.Total.Text = ""
		clone.Type.Image = GameDataModule.CreatureTypeIcons[type]
		clone.Type:SetAttribute("TextHover", type)
		clone.Parent = PlayerProfileUI.CreaturesTypes.Grid

		clone.Type.MouseEnter:Connect(function()
			PopulateCreatureTypeNumber(creatureType)
		end)
		clone.Type.MouseLeave:Connect(function()
			PlayerProfileUI.CreaturesRaces.Visible = false
		end)
	end

	--depopulate favorites creatures
	for _, v in pairs(PlayerProfileUI.FavouritesHorses.Grid:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
	
	--setup visual of favorites creatures with viewport model
	for index, creatureID in pairs(PlayerDataModule.LocalData.FavouritesCreatures) do
		if creatureID ~= "" then
			local data = PlayerDataModule.LocalData.CreaturesCollection[creatureID]
			--Make horse item for list based on template ui
			local cloneItem = HorseFavTemplate:Clone()
			cloneItem.Visible = true
			cloneItem.Name = data["CreatureName"]
			cloneItem.Parent = PlayerProfileUI.FavouritesHorses.Grid
			cloneItem.ItemName.Text = data["CreatureName"]

			--Update rarity of creature
			cloneItem.Rarity.Image = GameDataModule.RarityIconsBorderless[data.Rating]

			local ViewportFrame = cloneItem.ViewportFrame
			ViewportFrame.Name = index

			ToolsModule.MakeCreatureModelForRender(data, PlayerDataModule.LocalData.GenesCollection, ViewportFrame)

			cloneItem.ItemImgBtn.Activated:Connect(function()
				RemoteEvent.ShowHorseUI:FireServer(creatureID)
			end)
		end
	end
end

Init()
PopulateDataUIProfile()

PlayerProfileUI:GetPropertyChangedSignal("Visible"):Connect(function()
	WalkSpeedModule.SetControlsPlayerAndCreature(not PlayerProfileUI.Visible)
	PopulateDataUIProfile()
end)

PreviewPlayerUI.ShowAlertFeed.Activated:Connect(function()
	PopupAlertGui.AlertFeed.Visible = not PopupAlertGui.AlertFeed.Visible
end)

UIProviderModule:GetUI("AllButtonsMainMenusGui").CrystalsGuiBtn.Activated:Connect(function()
	CrystalsCurrencyFrame.Visible = not CrystalsCurrencyFrame.Visible
end)

PopupAlertGui.AlertFeed.NbAlert.Changed:Connect(SetNbAlert)

RemoteEvent.UIFarmOpen.OnClientEvent:Connect(function(isOpen)
	UIFarmIsOpen = isOpen
end)