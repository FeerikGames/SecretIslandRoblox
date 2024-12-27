local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TweenService = game:GetService("TweenService")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local GameDataModule = require("GameDataModule")
local UIAnimationModule = require("UIAnimationModule")

--Event
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")


local RE_QuestProgress = RemoteEvent.Quest.QuestProgress
local RE_QuestRefreshUI = RemoteEvent.Quest.QuestRefreshUI
local RE_QuestFollow = RemoteEvent.Quest.QuestFollow
local RE_ShowUiPanel = RemoteEvent.ShowUiPanel
local RE_QuestFailed = RemoteEvent.Quest.QuestFailed
local RE_UpdateDailyQuestNumber = RemoteEvent.Quest.UpdateDailyQuestNumber
local RF_GetGlobalQuestTimeInfo = RemoteFunction.GetGlobalQuestTimeInfo
local RE_QuestGenerate = RemoteEvent.Quest.QuestGenerate

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local QuestsGui = UIProviderModule:GetUI("QuestsGui")
local Background = QuestsGui.Background
local LockedBtn = Background.LockedBtn
local CompletedBtn = Background.CompletedBtn
local QuestsFrameUI = Background.QuestFrame
local QuestsListUI = QuestsFrameUI.QuestList
local QuestsDoneListUI = Background.QuestDoneList
local QuestItem = QuestsGui.Template.QuestsItem
local DailyQuestAvailableNumber = QuestsFrameUI.DailyQuestAvailableNumber

local QuestPreviewTemplate = QuestsGui.Template.QuestPreviewPanel
local QuestPreviewItem = QuestsGui.Template.QuestsPreview


local QuestProgress = QuestsGui.QuestProgress

local ShowUi = AllButtonsMainMenusGui.SubMenu.QuestsGuiBtn
local infoNotif = ShowUi.Notif

--Params

local questPreviewActiveNumber = 0

-- fade Tween
local tweenInfo = TweenInfo.new(6,Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0)
local textGoal = {}
textGoal.TextTransparency = 1
local bckGoal = {}
bckGoal.BackgroundTransparency = 1
local textTween = TweenService:Create(QuestProgress.CurrentProgress, tweenInfo, textGoal)
local backTween = TweenService:Create(QuestProgress, tweenInfo, bckGoal)
local StrokeTween = TweenService:Create(QuestProgress.UIStroke, tweenInfo, {Transparency=1})
textTween.Completed:Connect(function(playbackState)
    QuestProgress.Visible = false
    QuestProgress.CurrentProgress.TextTransparency = 0
    QuestProgress.BackgroundTransparency = 0
    QuestProgress.CurrentProgress.Text = ""
end)


--Initialize the visibility of club frame by default
local function InitVisibility()
	Background.Visible = true
	QuestsDoneListUI.Visible = false
	QuestsFrameUI.Visible = true
	DailyQuestAvailableNumber.Visible = true
	CompletedBtn.BackgroundTransparency = 0.4
	LockedBtn.BackgroundTransparency = 0
end



--[[
	This method called for update the value and ui of progress bar
	and call a CheckDoneStatus() function to verify if Quest is done or not
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

function UpdateFollowButton(item, Following)
	if Following then
		item.QuestInfo.Follow.Check.Text = "☑"
		for _, questNotFollowed in pairs(QuestsListUI:GetChildren()) do
			if questNotFollowed:IsA("Frame") and questNotFollowed ~= item then
				questNotFollowed.QuestInfo.Follow.Check.Text = "☐"
			end
		end
	else
		item.QuestInfo.Follow.Check.Text = "☐"
	end
	updateInfoNotifImage()
end

function updateInfoNotifImage()
	task.wait(0.1)
	local Quests = PlayerDataModule.LocalData.Quests
	local following = false
	for _, quest in pairs(Quests) do
		if quest.Active and quest.Following and quest.Progress < quest.Goal and not quest.Done then
			following = true
		end
	end
	infoNotif.Visible = false
	if following then
		infoNotif.Visible = true
	end
end

--[[
	This method is called for check if Quest is done after updated a progress bar value
	and set the button UI to get reward of Quest. The behaviour of button is set on Activated
	in PopulateUI function
]]
function CheckDoneStatus(item, progress, goal, done)
	--if progress is equal to goal, the Quest is finish, hide progressbar and show
	--button to claim reward player
	if progress == goal then
		item.QuestInfo.Progress.Visible = false
		item.QuestInfo.Follow.Visible = false
		item.QuestInfo.DownButton.Visible = true
		item.QuestInfo.DownButton.Active = true
		item.QuestInfo.Requirements.Visible = false
		item.QuestInfo.Require.Visible = false
		updateInfoNotifImage()
		
		--Check if the Quest is marked as done
		if done then
			item.QuestInfo.Require.Visible = true
			item.QuestInfo.Requirements.Visible = true
			item.QuestInfo.DownButton.Visible = false
			item.QuestInfo.DownButton.Active = false
		end
	end
end

function UpdateDailyQuestNum()
	task.wait(0.1)
	local dailyQuestNumber = PlayerDataModule.LocalData.DailyQuestAvailable
	local maxQuestPerDay =  PlayerDataModule.LocalData.DailyMaxQuest
	DailyQuestAvailableNumber.Text = dailyQuestNumber .."/".. ToolsModule.LengthOfDic(maxQuestPerDay)
end

local function QuestItemFailedDisplay(questItem)
	if not questItem:FindFirstChild("QuestInfo") then
		return
	end
	questItem.QuestInfo.Progress.Visible = false
	questItem.QuestInfo.Follow.Visible = false
	questItem.QuestInfo.Requirements.Visible = false
	questItem.QuestInfo.Require.Visible = false
	
	local btn = questItem.QuestInfo.DownButton
	btn.Visible = true
	btn.ZIndex = 10
	btn.Active = true
	btn.Text = "Quest Failed..."
	btn.BackgroundColor3 = Color3.fromRGB(255, 0, 4)
end

local function failedQuest(item, index, completeConnection, failedConnection)
	updateInfoNotifImage()
	if not item:FindFirstChild("QuestInfo") then
		return
	end
	QuestItemFailedDisplay(item)
	completeConnection:Disconnect()
	item.QuestInfo.DownButton.Activated:Connect(function()
		updateInfoNotifImage()
		item:Destroy()
		RE_QuestFailed:FireServer(index)
	end)
end


local function FillRequirements(RequirementFrame, Requirements : table)
	local requireTemplate = RequirementFrame.RequireTemplate
	for index, requirement in pairs(Requirements) do
		local RequireText = requireTemplate:Clone()
		RequireText.Parent = RequirementFrame
		RequireText.Text = "-"..requirement
		RequireText.LayoutOrder = index
		RequireText.Visible = true
	end
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

local function GetLayoutOrderOfQuests(quests)
	local questsOrdered = {}
	for index, quest in pairs(quests) do
		table.insert(questsOrdered, {
			timeleft = (quest.QuestTime + quest.QuestTimeAllowedInMin * 60 ) - os.time(),
			index = index
		})
	end
	table.sort(questsOrdered, function(a,b)
		return a.timeleft<b.timeleft
	end)
	local OrderReturned = {}
	for _, quest in pairs(questsOrdered) do
		OrderReturned[quest.index] = _
	end
	return OrderReturned
end

--[[
	Main function for populate data in list UI for display all data Quests of player
]]
local function PopulateQuestsList()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", QuestsListUI)
	ToolsModule.DepopulateTypeOfItemFrom("Frame", QuestsDoneListUI)
	--We get all Quest for a player
	local Quests = PlayerDataModule.LocalData.Quests

	if not Quests then
		return
	end
	local questsLayoutOrder = GetLayoutOrderOfQuests(Quests)
	--For all Quest we setup a clone of item to show in list Quests and set data of ui elements
	for index, quest in pairs(Quests) do
		if not quest.Active then
			continue
		end
		local feezReward
		local ecusReward
		local sparksReward
		local failed = false
		local clone
		clone = QuestItem:Clone()
		clone.LayoutOrder = questsLayoutOrder[index]
		clone.Name = index
		clone.QuestInfo.Title.Text = quest.Title
		clone.QuestInfo.Desc.Text = quest.Description
		clone.QuestInfo.Progress.ProgressBar.Goal.Value = quest.Goal
		clone.QuestInfo.Progress.ProgressBar.Progress.Value = quest.Progress
		clone.Visible = true

		-- Timer:
		if not quest.Done and quest.Progress < quest.Goal then
			task.spawn(function()
				while Background.Visible and clone:FindFirstChild("QuestInfo") do
					if quest.Progress == quest.Goal then
						clone.QuestInfo.Time.Text = ""
						break
					end
					local timeRemainingInSec = (quest.QuestTime + quest.QuestTimeAllowedInMin * 60 ) - os.time()
					local hour,min,sec = ToolsModule.ConvertSecToHour(timeRemainingInSec)
					clone.QuestInfo.Time.Text = "Time left : " .. hour .. ":" ..min .. ":" .. sec
					if timeRemainingInSec <=0 then
						failed = true
						break
					end
					task.wait(1)
				end
				if not clone:FindFirstChild("QuestInfo") then
					return
				end
				if quest.Progress ~= quest.Goal then
					clone.QuestInfo.Time.Text = "Out of time !"
				else
					clone.QuestInfo.Time.Text = ""
				end
			end)
		else
			local hour,min,sec = ToolsModule.ConvertSecToHour(quest.QuestTimeAllowedInMin * 60)
			clone.QuestInfo.Time.Text = "Quest Time : " .. hour .. ":" ..min .. ":" .. sec
		end

		-- Rewards:
		local rewards = {
			Ecus = quest.EcusReward,
			Feez = quest.FeezReward,
			Sparks = quest.SparksReward,
			TotalHarvestsFrame = 0,
		}
		FillRewards(clone, rewards)
		feezReward = quest.FeezReward
		ecusReward = quest.EcusReward
		sparksReward = quest.SparksReward

		-- Requirements:
		local typeText = quest.QuestRequirements.CreatureType == "Any" and "creature" or quest.QuestRequirements.CreatureType
		local objText = quest.QuestType.searchObjectInZone.Object == "All" and "Object" or quest.QuestType.searchObjectInZone.Object
        local requirements = {
			quest.QuestRequirements.CreatureRace.. " " .. typeText,
			quest.Goal .. " " .. objText .. (tonumber(quest.Goal)>1 and "s" or ""),
		}
        if quest.QuestRequirements.CreatureRace == "any" and typeText == "creature" then
            requirements[1] = "any creature or player"
        end
		FillRequirements(clone.QuestInfo.Requirements, requirements)

		-- Following:
		if quest.Following then
			clone.QuestInfo.Follow.Check.Text = "☑"
		else
			clone.QuestInfo.Follow.Check.Text = "☐"
		end
		--Button to set if tracker is on for the Quest
		clone.QuestInfo.Follow.FollowButton.Activated:Connect(function()
			RE_QuestFollow:FireServer(index)
			task.wait(0.1)
			local Quests = PlayerDataModule.LocalData.Quests
			if Quests[index].Following then
				UpdateFollowButton(clone, true)
			else
				UpdateFollowButton(clone, false)
			end
		end)
		UpdateProgressBar(clone, quest.Progress, quest.Goal, quest.Done)
		
		
		
		--This button allow to claim reward and move thie Quest to the down list
		local completeConnection =  clone.QuestInfo.DownButton.Activated:Connect(function()
			clone.QuestInfo.DownButton.Visible = false
			clone.QuestInfo.Require.Visible = true
			clone.QuestInfo.Requirements.Visible = true
			quest.Done = true
			updateInfoNotifImage()
			
			--Set updated data of Quest player to synchro action with server datas
			RemoteFunction:WaitForChild("SetQuestValueOfStat"):InvokeServer(index, "Done", true)
			
			clone.Parent = QuestsDoneListUI
			
			--Give reward to player with called function server only can change value of this
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Feez", feezReward)
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Ecus", ecusReward)
			RemoteFunction:WaitForChild("IncrementValueOf"):InvokeServer("Sparks", sparksReward)
		end)

		if failed then
			failedQuest(clone, index, completeConnection)
		end
		
		RE_QuestFailed.OnClientEvent:Connect(function(questIndex)
			if questIndex == index then
				failedQuest(clone, index, completeConnection)
			end
		end)
		
		if not Background.Visible then
			clone:Destroy()
			return
		end
		--Check if the Quest is done by player or not and choose the good list parent
		if quest.Done then
			clone.QuestInfo.DownButton.Visible = false
			clone.Parent = QuestsDoneListUI
		else
			clone.Parent = QuestsListUI
		end
	end
	local maxQuestPerDay =  RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("DailyMaxQuest")
	local dailyQuestAvailable = RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("DailyQuestAvailable")
	DailyQuestAvailableNumber.Text = dailyQuestAvailable .."/".. ToolsModule.LengthOfDic(maxQuestPerDay)
end

local function activateUiPanel()
	Background.Visible = not Background.Visible
	if Background.Visible then
		RE_UpdateDailyQuestNumber:FireServer()
		local dailyQuestNumber = RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("DailyQuestAvailable")
		local maxQuestPerDay =  RemoteFunction:WaitForChild("GetValueOf"):InvokeServer("DailyMaxQuest")
		DailyQuestAvailableNumber.Text = dailyQuestNumber .."/".. ToolsModule.LengthOfDic(maxQuestPerDay)
		task.spawn(function()
			PopulateQuestsList()
		end)
		InitVisibility()
	end
end

Background:GetPropertyChangedSignal("Visible"):Connect(function()
	WalkSpeedModule.SetControlsPlayerAndCreature(not Background.Visible)
	ToolsModule.EnableOtherUI(not Background.Visible, {"QuestsGui"})
	QuestsDoneListUI.Visible = false
	QuestsFrameUI.Visible = true
	DailyQuestAvailableNumber.Visible = true
	CompletedBtn.BackgroundTransparency = 0.4
	LockedBtn.BackgroundTransparency = 0
	ToolsModule.DepopulateTypeOfItemFrom("Frame", QuestsListUI)
	ToolsModule.DepopulateTypeOfItemFrom("Frame", QuestsDoneListUI)
end)

--Button to show or hide the Quest UI
ShowUi.Activated:Connect(activateUiPanel)


RE_ShowUiPanel.OnClientEvent:Connect(function(UiPanel)
	if UiPanel == "Quests" then
		activateUiPanel()
	end
end)


function UpdateTimer()
	local questsTiming =  PlayerDataModule.LocalData.DailyMaxQuest
	local dailyQuestTimeMax, timeBeforeNotif, dailyQuestNumberRetrieveTime = RF_GetGlobalQuestTimeInfo:InvokeServer()
	local LatestQuestTiming = math.huge
	for _, timing in pairs(questsTiming) do
		if timing < LatestQuestTiming and (timing + dailyQuestNumberRetrieveTime * 3600 ) > os.time()  then
			LatestQuestTiming = timing
		end
	end
	local firstFrameTimeFinish = true
	while QuestsFrameUI.Visible and Background.Visible do
		
		local maxQuestPerDay =  PlayerDataModule.LocalData.DailyMaxQuest
		local DailyQuestAvailable = PlayerDataModule.LocalData.DailyQuestAvailable
		local timeRemainingInSec = (LatestQuestTiming + dailyQuestNumberRetrieveTime * 3600 ) - os.time()
		local hour,min,sec = ToolsModule.ConvertSecToHour(timeRemainingInSec)
		if DailyQuestAvailable == ToolsModule.LengthOfDic(maxQuestPerDay) or LatestQuestTiming == 0 or LatestQuestTiming == math.huge or timeRemainingInSec <= 0 then
			QuestsFrameUI.MoreIn.Visible = false
			QuestsFrameUI.CountDown.Visible = false
		else
			QuestsFrameUI.MoreIn.Visible = true
			QuestsFrameUI.CountDown.Visible = true
			QuestsFrameUI.CountDown.Text = hour .. ":" ..min .. ":" .. math.round(sec)
			firstFrameTimeFinish = true
		end
		if timeRemainingInSec <= 0 and firstFrameTimeFinish then
			task.spawn(function()
				UpdateTimer()
			end)
			return
		end
		task.wait(1)
	end
end
Background:GetPropertyChangedSignal("Visible"):Connect(function()
	UpdateTimer()
end)
QuestsFrameUI:GetPropertyChangedSignal("Visible"):Connect(function()
	UpdateTimer()
end)

local function ChangeList(isDone)
	if isDone then
        QuestsDoneListUI.Visible = true
		QuestsFrameUI.Visible = false
		DailyQuestAvailableNumber.Visible = false
	else
        QuestsFrameUI.Visible = true
		QuestsDoneListUI.Visible = false
		DailyQuestAvailableNumber.Visible = true
		UpdateDailyQuestNum()
	end
end


--Button to show frame with Quest not finished and setup ui appearance for other UI not selected
LockedBtn.Activated:Connect(function()
	CompletedBtn.BackgroundTransparency = 0.4
	LockedBtn.BackgroundTransparency = 0
	ChangeList(false)
end)

--Button to show frame with Quest done and setup ui appearance for other UI not selected
CompletedBtn.Activated:Connect(function()
	LockedBtn.BackgroundTransparency = 0.4
	CompletedBtn.BackgroundTransparency = 0
	print("complete")
	ChangeList(true)
end)


local function showQuestProgress(QuestTitle, currentProgress)
    textTween:Cancel()
	backTween:Cancel()
	StrokeTween:Cancel()
    QuestProgress.Visible = true
    QuestProgress.CurrentProgress.Text = QuestTitle .." : "..currentProgress
    textTween:Play()
	backTween:Play()
	StrokeTween:Play()
end

--#region Quest PREVIEW

local function ShowQuestPreview(Quests)
    local QuestPreview = QuestPreviewTemplate:Clone()
    QuestPreview.Parent = QuestsGui
    QuestPreview.ZIndex = questPreviewActiveNumber + 1
    QuestPreview.Visible = true
    for _, quest in pairs(QuestPreview.Scroll:GetChildren()) do
        if quest:IsA("Frame") then
            quest:Destroy()
        end
    end
    for _, Quest in pairs(Quests) do
        local clone = QuestPreviewItem:Clone()
        clone.Parent = QuestPreview.Scroll
        clone.Name = Quest.Title
		-- Quest Info :
        clone.QuestInfo.Title.Text = Quest.Title
        clone.QuestInfo.Scroll.Desc.Text = Quest.Description
		local hour,min,sec = ToolsModule.ConvertSecToHour(Quest.QuestTimeAllowedInMin*60)
		clone.QuestInfo.Time.Text = "Time allowed : " .. hour .. ":" ..min .. ":" .. sec

		-- Quest Requrements :
        local typeText = Quest.QuestRequirements.CreatureType == "Any" and "creature" or Quest.QuestRequirements.CreatureType
		local objText = Quest.QuestType.searchObjectInZone.Object == "All" and "Object" or Quest.QuestType.searchObjectInZone.Object
        local requirements = {
			Quest.QuestRequirements.CreatureRace.. " " .. typeText,
			Quest.Goal .. " " .. objText .. (tonumber(Quest.Goal)>1 and "s" or ""),
		}
        if Quest.QuestRequirements.CreatureRace == "any" and typeText == "creature" then
            requirements[1] = "any creature or player"
        end
		FillRequirements(clone.QuestInfo.Scroll.Requirements, requirements)
		if #requirements > 0 then
			clone.QuestInfo.Scroll.Require.Visible = true
		end
		
		-- Quest Rewards :
		local rewards = {
			Ecus = Quest.EcusReward,
			Feez = Quest.FeezReward,
			Sparks = Quest.SparksReward,
			TotalHarvestsFrame = 0,
		}
		FillRewards(clone, rewards)

        clone.Visible = true
    end

	--[[ QuestPreview.Scroll.CanvasSize = UDim2.new(0, 0, 0, QuestPreview.Scroll.UIListLayout.AbsoluteContentSize.Y + (QuestPreview.Scroll.UIListLayout.Padding.Offset * (#QuestPreview.Scroll:GetChildren()-1)))
    QuestPreview.Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y ]]
    
    local Hide = false
    local Accepted = false
	QuestPreview.Buttons.AcceptQuestButton.Activated:Connect(function()
		Hide = true
		Accepted = true
	end)
	QuestPreview.Buttons.DeclineQuestButton.Activated:Connect(function()
		Hide = true
	end)
	QuestPreview.Title.CloseUI.Activated:Connect(function()
		Hide = true
	end)
	while Hide == false do
        if QuestPreview.Visible == false then
            Hide = true
        end
		task.wait()
	end

    QuestPreview.Visible = false
    QuestPreview:Destroy()
    questPreviewActiveNumber -= 1
	return Accepted
end

RE_QuestGenerate.OnClientEvent:Connect(function(QuestData)
    local Quests = PlayerDataModule.LocalData.Quests
    local QuestsActive = 0
    
    local accepted = ShowQuestPreview(QuestData)
    RE_QuestGenerate:FireServer(QuestData, false,accepted)
end)

--#endregion

RE_QuestProgress.OnClientEvent:Connect(showQuestProgress)


--Event listener to wait receive event from QuestsDataModule for say a Quest is updated
--so refresh ui progress bar and check in UpdateProgressBar() if done or not
RE_QuestRefreshUI.OnClientEvent:Connect(function(questIndex, Following, progress, goal, done)
	if questIndex == nil then
		UpdateDailyQuestNum()
		return
	end
	local item = QuestsListUI:FindFirstChild(questIndex)
	if item then
		if progress ~= nil then
			UpdateProgressBar(item, progress, goal, done)
		end
		if Following ~= nil then
			UpdateFollowButton(item, Following)
		end
	end
	updateInfoNotifImage()
	UpdateDailyQuestNum()
end)

RE_QuestFailed.OnClientEvent:Connect(function(questIndex)
	updateInfoNotifImage()
	UpdateDailyQuestNum()
end)

-- Check when receive Popup if it's Quest Done popup or not
UIProviderModule:GetUI("PopupAlertGui").ChildAdded:Connect(function(child)
	if child.Title.Text == "Quest Done" then
		UIAnimationModule.ParticleExplosionUI(QuestsGui.Template.StarsParticle, child)
	end
end)