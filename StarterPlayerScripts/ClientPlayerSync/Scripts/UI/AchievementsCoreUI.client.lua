local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TweenService = game:GetService("TweenService")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")
local GameDataModule = require("GameDataModule")

--Event
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")
local BindableEvent = ReplicatedStorage:FindFirstChild("BindableEvent")


local RE_AchievementRefreshUI = RemoteEvent.AchievementRefreshUI
local RE_ShowUiPanel = RemoteEvent.ShowUiPanel
local RF_GetAchievementsDataStruct = RemoteFunction.GetAchievementsDataStruct

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local AchievementsGui = UIProviderModule:GetUI("AchievementsGui")
local Background = AchievementsGui.Background
local AchievementsListUI = Background.AchievementsList
local AchievementsDoneListUI = Background.AchievementsDoneList
local AchievementItem = AchievementsGui.Template.AchievementsItem



local ShowUi = AllButtonsMainMenusGui.SubMenu.AchievementsGuiBtn
local LockedBtn = Background.LockedBtn
local CompletedBtn = Background.CompletedBtn

local currentList = 0


--Initialize the visibility of club frame by default
local function InitVisibility(currentList)
	Background.Visible = true
	if currentList == 0 then
		AchievementsDoneListUI.Visible = false
		AchievementsListUI.Visible = true
		CompletedBtn.BackgroundTransparency = 0.4
		LockedBtn.BackgroundTransparency = 0
	elseif currentList == 1 then
		AchievementsDoneListUI.Visible = true
		AchievementsListUI.Visible = false
		CompletedBtn.BackgroundTransparency = 0
		LockedBtn.BackgroundTransparency = 0.4
	end
end



--[[
	This method called for update the value and ui of progress bar
	and call a CheckDoneStatus() function to verify if achievement is done or not
]]
function UpdateProgressBar(item, progress, goal, done)
	-- Set the progress of the bar
	-- valueIncrement is a number between 0 and 1
	local valueIncrement = progress/goal
	local oneOverProgress
	if valueIncrement == 0 then
		--can't do 1/0, just make oneOverProgress = 0
		oneOverProgress = 0
	else
		oneOverProgress = 1/valueIncrement
	end

	item.QuestInfo.Progress.ProgressBar.Info.Text = progress.." / "..goal

	item.QuestInfo.Progress.ProgressBar.Clipping.Size = UDim2.new(valueIncrement, 0, 1, 0) -- set Clipping size to {progress, 0, 1, 0}
	item.QuestInfo.Progress.ProgressBar.Clipping.Top.Size = UDim2.new(oneOverProgress, 0, 1, 0) -- set Top size to {1/progress, 0, 1, 0}
	CheckDoneStatus(item, progress, goal, done)
end


local function FillRewards(Item, Rewards : table)
	local rewardTemplate = Item.QuestReward.RewardTemplate
	local isReward = false
	for type, reward in pairs(Rewards) do
		if reward <= 0 then
			continue
		end
		isReward = true
		local RewardItem = rewardTemplate:Clone()
		RewardItem.Parent = Item.QuestReward
		RewardItem.Num.Text = reward
		RewardItem.CurrencyImg.Image = GameDataModule.DropCollectables[type]
		RewardItem.Visible = true
	end
	if not isReward then
		Item.Separation.Visible = false
	end
end


--[[
	This method is called for check if achievement is done after updated a progress bar value
	and set the button UI to get reward of achievement. The behaviour of button is set on Activated
	in PopulateUI function
]]
function CheckDoneStatus(item, progress, goal, done)
	--if progress is equal to goal, the achievement is finish, hide progressbar and show
	--button to claim reward player
	if progress == goal then
		item.QuestInfo.Progress.ProgressBar.Visible = false
		item.QuestInfo.DownButton.Visible = true
		item.QuestInfo.DownButton.Active = true
		
		--Check if the achievement is marked as done
		if done then
			--change button ui if is a done achievement
			local btn = item.QuestInfo.DownButton
			btn.Text = "Achievement completed !"
			btn.BackgroundTransparency = 1
			btn.TextColor3 = Color3.fromRGB(0,0,0)
			btn.TextStrokeTransparency = 1
		end
	end
end

--[[
	Main function for populate data in list UI for display all data achievements of player
]]
local function PopulateAchievementsList()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", AchievementsListUI)
	ToolsModule.DepopulateTypeOfItemFrom("Frame", AchievementsDoneListUI)
	--We get all achievement for a player
	local Achievements = RemoteFunction:WaitForChild("GetAchievements"):InvokeServer()
	local achievementsDataStruct = RF_GetAchievementsDataStruct:InvokeServer()
	
	if not Achievements then
		return
	end
	--For all achievement we setup a clone of item to show in list Achievements and set data of ui elements
	for index, achiev in pairs(Achievements) do
		if not achiev.Active and not achiev.Done or achiev.Quest then
			continue
		end
		local feezReward
		local ecusReward
		local sparksReward
		local clone
		
		clone = AchievementItem:Clone()
		clone.Name = index
		clone.QuestInfo.Title.Text = achievementsDataStruct[index].Title
		clone.QuestInfo.Desc.Text = achievementsDataStruct[index].Description
		clone.QuestInfo.Progress.ProgressBar.Goal.Value = achievementsDataStruct[index].Goal
		clone.QuestInfo.Progress.ProgressBar.Progress.Value = achiev.Progress

		-- Rewards:
		local rewards = {
			Ecus = achievementsDataStruct[index].EcusReward,
			Feez = achievementsDataStruct[index].FeezReward,
			Sparks = achievementsDataStruct[index].SparksReward,
			TotalHarvestsFrame = 0,
		}
		FillRewards(clone, rewards)
		feezReward = achievementsDataStruct[index].FeezReward and achievementsDataStruct[index].FeezReward or 0
		ecusReward = achievementsDataStruct[index].EcusReward and achievementsDataStruct[index].EcusReward or 0
		sparksReward = achievementsDataStruct[index].SparksReward and achievementsDataStruct[index].SparksReward or 0
		UpdateProgressBar(clone, achiev.Progress, achievementsDataStruct[index].Goal, achiev.Done)
		clone.Visible = true
		

		--This button allow to claim reward and move thie achievement to the down list
		clone.QuestInfo.DownButton.Activated:Connect(function()
			local btn = clone.QuestInfo.DownButton
			btn.Text = "Achievement completed !"
			btn.BackgroundTransparency = 1
			btn.TextColor3 = Color3.fromRGB(0,0,0)
			btn.TextStrokeTransparency = 1
			achiev.Done = true
			
			--Set updated data of achievement player to synchro action with server datas
			RemoteFunction:WaitForChild("SetAchievementValueOfStat"):InvokeServer(index, "Done", true)
			
			clone.Parent = AchievementsDoneListUI
			--Give reward to player with called function server only can change value of this
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Feez", feezReward)
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Ecus", ecusReward)
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Sparks", sparksReward)
		end)
		
		
		
		--Check if the achievement is done by player or not and choose the good list parent
		if achiev.Done then
			clone.Parent = AchievementsDoneListUI
		else
			clone.Parent = AchievementsListUI
		end
	end
end

local function activateUiPanel()
	Background.Visible = not Background.Visible
	if Background.Visible then
		PopulateAchievementsList()
		InitVisibility(currentList)
	end
end

Background:GetPropertyChangedSignal("Visible"):Connect(function()
	WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
	ToolsModule.EnableOtherUI(not Background.Visible, {"AchievementsGui"})
end)

--Button to show or hide the Achievement UI
ShowUi.Activated:Connect(activateUiPanel)


RE_ShowUiPanel.OnClientEvent:Connect(function(UiPanel)
	if UiPanel == "Achievements" then
		activateUiPanel()
	end
end)


local function ChangeList(isDone)
	if isDone then
		AchievementsDoneListUI.Visible = true
		AchievementsListUI.Visible = false
	else
		AchievementsListUI.Visible = true
		AchievementsDoneListUI.Visible = false
	end
end


--Button to show frame with achievement not finished and setup ui appearance for other UI not selected
LockedBtn.Activated:Connect(function()
	CompletedBtn.BackgroundTransparency = 0.4
	LockedBtn.BackgroundTransparency = 0
	currentList = 0
	ChangeList(false)
end)

--Button to show frame with achievement done and setup ui appearance for other UI not selected
CompletedBtn.Activated:Connect(function()	
	LockedBtn.BackgroundTransparency = 0.4
	CompletedBtn.BackgroundTransparency = 0
	currentList = 1
	ChangeList(true)
end)



--Event listener to wait receive event from AchievementsDataModule for say a achievement is updated
--so refresh ui progress bar and check in UpdateProgressBar() if done or not
RE_AchievementRefreshUI.OnClientEvent:Connect(function(achievementIndex, Following, progress, goal, done)
	local item = AchievementsListUI:FindFirstChild(achievementIndex)
	if item then
		if progress ~= nil then
			UpdateProgressBar(item, progress, goal, done)
		end
	end
end)


