local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	local TweenService = game:GetService("TweenService")
	
	--Require
	local ToolsModule = require("ToolsModule")
	local UIProviderModule = require("UIProviderModule")
	local WalkSpeedModule = require("WalkSpeedModule")
	local GameDataModule = require("GameDataModule")
	local UIAnimationModule = require("UIAnimationModule")
	local SoundControllerModule = require("SoundControllerModule")
	
	--Variables
	local DailyRewardUI = UIProviderModule:GetUI("DailyReward")
	local Background = DailyRewardUI.Background
	local RewardsListUI = Background.RewardsList
	local RewardItemTemplate = DailyRewardUI.Template.RewardItem
	local ClaimButton = Background:WaitForChild("ClaimBtn")
	local CloseButton = Background:WaitForChild("CloseBtn")
	local LeftButton = Background:WaitForChild("LeftBtn")
	local RightButton = Background:WaitForChild("RightBtn")
	local NextRewardTxt = Background:WaitForChild("NextReward")
	
	local Player = game.Players.LocalPlayer
	local timerExist = Player:WaitForChild("TimerExist")
	local localLanguage = game:GetService("LocalizationService").RobloxLocaleId
	local NextItemReward
	
	--Remote
	local RemoteEvent = ReplicatedStorage.RemoteEvent.DailyReward
	
	--[[
		This method converts the text to a language specific and hour, minute, second format
		format to provide the player with information on the time remaining before collecting the 
		to collect the reward.
	]]
	local function toHMS(s)
		if localLanguage == "fr-fr" then
			return ("Prochaine récompense: %02ih %02im %02is"):format(s/60^2, s/60%60, s%60)
		else
			return ("Next Reward in: %02ih %02im %02is"):format(s/60^2, s/60%60, s%60)
		end
	end

	local function AnimClaim(item)
		local tweenInfo1 = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)

		item.Locked.Img.UIGradient.Offset = Vector2.new(-1,0)

		local t1 = TweenService:Create(item.Locked.Img.UIGradient, tweenInfo1, {Offset = Vector2.new(1,0)})
		t1:Play()
		SoundControllerModule:CreateSound("DailyRewardClaim")
		UIAnimationModule.BouncyCurrencyBarFeedback(item):Play()
	end
	
	--[[ 
	
	 ]]
	 local function AutomaticFocusOnLastReward(NextItem:GuiObject)
		if NextItem then
			NextItemReward = NextItem
			local maxElem = #RewardsListUI:GetChildren() - 1
            local nbElementPerLine = 5
            local nbLine = math.round((maxElem/nbElementPerLine)+0.5)
            local lineToShow = math.floor(((NextItem.LayoutOrder * nbLine)/maxElem)+0.5)
			local itemFocusLayoutOrder = ((lineToShow*nbElementPerLine)-nbElementPerLine) + 1
			local itemFocus:GuiObject
			for _, child in pairs(RewardsListUI:GetChildren()) do
				if child:IsA("Frame") then
					if child.LayoutOrder == itemFocusLayoutOrder then
						itemFocus = child
						break
					end
				end
			end

			if itemFocus then
				if RewardsListUI.CanvasPosition == Vector2.new(0, 0) then
					local newPosX = itemFocus.AbsolutePosition.X - (RewardsListUI.AbsolutePosition.X)
					local tweenInfo = TweenInfo.new(
						0.5, -- Time
						Enum.EasingStyle.Linear, -- EasingStyle
						Enum.EasingDirection.Out, -- EasingDirection
						0, -- RepeatCount (when less than zero the tween will loop indefinitely)
						false, -- Reverses
						0 -- DelayTime
					)
				
					local tween = TweenService:Create(RewardsListUI, tweenInfo, {CanvasPosition = Vector2.new(newPosX, 0)})
					
					tween:Play()
				end
			end
		end
	 end

	 local function ApplyGoodImage(typeValue, quantity)
		if quantity >= 0 and quantity <= 50 then
			return GameDataModule.DailyRewardImage[typeValue].Simple
		elseif quantity > 50 and quantity <= 150 then
			return GameDataModule.DailyRewardImage[typeValue].LittleStack
		elseif quantity > 150 and quantity <= 350 then
			return GameDataModule.DailyRewardImage[typeValue].BasicStack
		elseif quantity > 350 and quantity <= 650 then
			return GameDataModule.DailyRewardImage[typeValue].LargeStack
		elseif quantity > 650 and quantity <= 1000 then
			return GameDataModule.DailyRewardImage[typeValue].BasicStack
		elseif quantity > 1000 and quantity <= 2500 then
			return GameDataModule.DailyRewardImage[typeValue].BigBagStack
		elseif quantity > 2500 then
			return GameDataModule.DailyRewardImage[typeValue].ChestStack
		end
	 end
	
	--[[
		This method allows you to fill the interface with items that represent the
		Daily Reward. We retrieve the data managed by the server in the Player and use it to initialise the
		initialize the interface with it.
	]]
	local function PopulateRewardsList()
		ToolsModule.DepopulateTypeOfItemFrom("Frame", RewardsListUI)
		for i, data in pairs(Player.Days:GetChildren()) do
			local clone = RewardItemTemplate:Clone()
			clone.Visible = true
			clone.Name = data.Name
			clone.Day.Text = Player.DayActual.Value == data.Name and "Today" or data.Name
			clone.RewardValue.Text = tostring(data["QuantityValue"].Value)
			
			--Make a layout order with delete Day of name for use the number of day for the position on ui table
			--in good order. Not use name order because Day10 are placed after Day1 and not after Day9.
			clone.LayoutOrder = string.gsub(data.Name, "Day", "")
			
			clone.Background.Image = data["BackgroundValue"].Value
			clone.Background.IconReward.Image = ApplyGoodImage(data["TypeValue"].Value, data["QuantityValue"].Value)
			clone.IconImg.Image = GameDataModule.DropCollectables[data["TypeValue"].Value]
			
			if data["Claimed"].Value then
				clone.Locked.Visible = true
			end
			
			clone.Parent = RewardsListUI
		end
	end
	
	--[[
		This method allows the player interface to be updated with the right information,
		the right visual indication of whether a reward is available or not,
		whether it has already been collected or not.
	]]
	local function UpdateUI()
		local NextChildReward = nil
		--Check if the reward are not the last reward for show next ui infos
		if Player:FindFirstChild("Days") then
			local days = Player.Days:GetChildren()
			if #days ~= 0 then
				local day = Player.Days:FindFirstChild("Day"..#days)
				if day.Claimed.Value then
					ClaimButton.Visible = false
					CloseButton.Visible = true
					NextRewardTxt.Visible = true
					NextRewardTxt.Text = "All reward have been claimed..."
				end
			end
		end
		
		for _, data in pairs(Player.Days:GetChildren()) do
			local item = RewardsListUI:FindFirstChild(data.Name)
			if item then
				item.Day.Text = Player.DayActual.Value == data.Name and "Today" or data.Name
				if data["Claimed"].Value then
					if item then
						item.Locked.Visible = true
					end
				else
					if item then
						if NextChildReward then
							if item.LayoutOrder < NextChildReward.LayoutOrder then
								NextChildReward = item
							end
						else
							NextChildReward = item
						end
					end
				end
			end
		end
		
		AutomaticFocusOnLastReward(NextChildReward)
	end
	
	--This method allows you to change the visibility of the button and the timer to ready to take the award
	local function NextRewardReady()
		Background.Visible = true
		ClaimButton.Visible = true
		NextRewardTxt.Visible = false
		CloseButton.Visible = false
	
		UpdateUI()
	end
	
	--[[
		This method runs a small local timer on the player's client to allow the player to check when the
		reward will be collected. When the player will be able to collect the reward.
		Once the timer is complete it initializes the interface for the reward pickup and sends a
		message to the server to set the timer variable.
	]]
	local function LaunchTimer()
		if not timerExist.Value then
			RemoteEvent.GiveTimerReward:FireServer()
			task.wait(0.1)
			local s = Player.WaitTimerReward.Value
			while s > 0 do
				CloseButton.Visible = true
				timerExist.Value = true
				NextRewardTxt.Text = toHMS(s)
				s = s-1
				task.wait(1)
			end
			timerExist.Value = false
			NextRewardReady()
			RemoteEvent.GiveTimerReward:FireServer()
		end
	end
	
	Background:GetPropertyChangedSignal("Visible"):Connect(function()
		WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
		PopulateRewardsList()
	end)
	
	RemoteEvent.ClaimDailyReward.OnClientEvent:Connect(function()
		NextRewardReady()
	end)
	
	RemoteEvent.UpdateUI.OnClientEvent:Connect(function(showBackground)
		UpdateUI()
	end)
	
	--[[
		When the player clicks on the button to collect the reward, this event is triggered.
		The server is informed that the player wants to take the reward, it changes the interface and starts the timer for the next
		the timer for the next reward.
		It is on the server side that the checks are made to validate or not the reward request.
	]]
	ClaimButton.Activated:Connect(function()
		ClaimButton.Visible = false
        NextRewardTxt.Visible = true
        CloseButton.Visible = true

		-- Make here animation of claim reward
		AnimClaim(NextItemReward)

		RemoteEvent.ClickOnClaimReward:FireServer()
		
		--Check if the reward are not the last reward for lauch timer to check availablility of next reward
		local days = Player.Days:GetChildren()
		if Player.DayActual.Value ~= "Day"..#days then
			pcall(LaunchTimer)
		end
	end)

	--Button left allow to move and scroll list of daily reward
	LeftButton.Activated:Connect(function()
		local t = math.clamp(RewardsListUI.CanvasPosition.X - (RewardsListUI.AbsoluteSize.X + (RewardsListUI.AbsoluteSize.X * RewardsListUI.UIListLayout.Padding.Scale)), 0, RewardsListUI.AbsoluteCanvasSize.X)
		if t == 0 then
			LeftButton.Visible = false
		end

		RightButton.Visible = true
		RewardsListUI.CanvasPosition = Vector2.new(t,0)
	end)

	--Button right allow to move and scroll list of daily reward
	RightButton.Activated:Connect(function()
		local t = math.clamp(RewardsListUI.CanvasPosition.X + (RewardsListUI.AbsoluteSize.X + (RewardsListUI.AbsoluteSize.X * RewardsListUI.UIListLayout.Padding.Scale)), 0, RewardsListUI.AbsoluteCanvasSize.X)
		if t == RewardsListUI.AbsoluteCanvasSize.X then
			RightButton.Visible = false
		end
		LeftButton.Visible = true
		RewardsListUI.CanvasPosition = Vector2.new(t,0)
	end)
	
	RemoteEvent.GiveTimerReward:FireServer()
	PopulateRewardsList()
	Background.Visible = true
	UpdateUI()
	
	task.wait(0.5)
	pcall(LaunchTimer)
end
