local QuestsDataModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerService = game:GetService("Players")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local ServerStorage = game.ServerStorage.ServerStorageSync
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

--Ressources

local rewardParticle1 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle1
local rewardParticle2 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle2
local rewardParticle3 = ReplicatedStorage.SharedSync.Assets.Quests.RewardParticle3

--Require Modules
local PlayerDataModule = require("PlayerDataModule")
local DataManagerModule = require("DataManagerModule")
local ToolsModule = require("ToolsModule")
local TimeManager = require("TimeManager")

--Event
local RE_QuestFollow = RemoteEvent.Quest.QuestFollow
local RE_QuestRefreshUI = RemoteEvent.Quest.QuestRefreshUI
local RE_ShowUiPanel = RemoteEvent.ShowUiPanel
local RE_QuestGenerate = RemoteEvent.Quest.QuestGenerate
local RE_Notif = RemoteEvent.ShowNotification
local RE_QuestFailed = RemoteEvent.Quest.QuestFailed
local RE_UpdateDailyQuestNumber = RemoteEvent.Quest.UpdateDailyQuestNumber
local RE_QuestProgress = RemoteEvent.Quest.QuestProgress
local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert
local BE_QuestProgress = BindableEvent.QuestProgress
local RF_QuestSetup = RemoteFunction.QuestSetup
local RF_GenerateQuestName = RemoteFunction.GenerateQuestName
local RF_GetGlobalQuestTimeInfo = RemoteFunction.GetGlobalQuestTimeInfo

-- Parameter

local dailyQuestTimeMaxInMin = 2
local timeBeforeNotifInHour = 0.01
local dailyQuestNumberRetrieveTimeInHour = 0.03

RF_GetGlobalQuestTimeInfo.OnServerInvoke = function()
	return dailyQuestTimeMaxInMin, timeBeforeNotifInHour, dailyQuestNumberRetrieveTimeInHour
end


local QuestStruct = {
	Title = "Quest:";
	Description = "";
	Goal = 5;
	Progress = 0;
	EcusReward = 0;
	FeezReward = 0;
	SparksReward = 0;
	Active = false;
	QuestTime = 0;
	QuestTimeAllowedInMin = dailyQuestTimeMaxInMin;
    TimeWarningRatio = 0.5;
	QuestRequirements = {};
	QuestType = {};
	Following = false;
	Done = false;
}

local questObjects = {"All", "Rabbit", "Apple"}

local questColorObject = {nil, BrickColor.new("Bright red"), BrickColor.new("Lime green"), BrickColor.new("Electric blue"), BrickColor.new("Bright yellow")}

local questNameType = {NameType1 = "Where are my ";
NameType2 = " collection time !";
NameType3 = "Cleaning waste 🗑️";
Descrisption = "Find ";}

local questType = {
	searchObjectInZone = {
		Object = "";
		Color = nil;
		ZoneOrigin = {};
		ZoneSize = 0;
		ZoneType = {};
	},
	feedAnimal={},
	plantCrops={}
}

CreaturesTypes = {
	"Horse";
	"Cat";
	"Any";
}
CreaturesRaces = {
	Horse = {
		"Any";
		"Normal";
		"Fire";
		"Water";
		"Light";
		"Ground";
		"Celestial";
		"Ice";
	};
	Cat = {
		"Any";
		"Normal";
		"Fire";
		"Water";
		"Light";
		"Ground";
		"Celestial";
		"Ice";
	};
	Any = {
		"Any";
		"Normal";
		"Fire";
		"Water";
		"Light";
		"Ground";
		"Celestial";
		"Ice";
	}
};

local questRequirements = {
	CreatureType = "";
	CreatureRace = "";
}


local function ShowUi(player)
	RE_ShowUiPanel:FireClient(player, "Quests")
end


--[[
	This method allow to set a specific value of stat in Quest structure.
	Example : Change a Quest done status to true, we call this method with the index
	of Quest to done, the questStat is Done and value is true.
]]
function QuestsDataModule.SetQuestValueOfStat(player, questIndex, questStat, value)
	PlayerDataModule:Set(player, value, "Quests."..questIndex..".".. questStat)
end

function QuestsDataModule.FollowFirstQuest(player, QuestsPlayer)
	local minQuestTime = math.huge
	local chosedQuestIndex = nil
	for achievIndex, Quest in pairs(QuestsPlayer) do
		if Quest and Quest.Progress < Quest.Goal then
			if Quest.QuestTime <= minQuestTime then
				minQuestTime = Quest.QuestTime
				chosedQuestIndex = achievIndex
			end
		end
	end
	if chosedQuestIndex then
		QuestsDataModule.FollowQuest(player, chosedQuestIndex)
	end
end

local function GetQuestCount(QuestsPlayer, isDoneCounted)
	local questCount = 0
	for index, quest in pairs(QuestsPlayer) do
		questCount += 1
		if not isDoneCounted and quest.Done then
			questCount -= 1
		end
	end
	return questCount
end

local function instanciateRewardParticle(player)
	local posMod = {Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,0,1),Vector3.new(0,0,-1)}
	for _, pos in pairs(posMod) do
		local particlePart = Instance.new("Part", workspace.Quests)
		particlePart.Position = player.Character.PrimaryPart.Position + pos * 5
		particlePart.Size = Vector3.new(1,1,1)
		particlePart.Anchored = true
		particlePart.CanCollide = false
		particlePart.CanTouch = false
		particlePart.CanQuery = false
		particlePart.Transparency = 1
		local rewardEffect1 = rewardParticle1:Clone()
		local rewardEffect2 = rewardParticle2:Clone()
		local rewardEffect3 = rewardParticle3:Clone()
		rewardEffect1.Parent = particlePart
		rewardEffect2.Parent = particlePart
		rewardEffect3.Parent = particlePart
		task.delay(0.3, function()
			rewardEffect1.Enabled = false
			rewardEffect2.Enabled = false
			rewardEffect3.Enabled = false
			task.delay(10, function()
				particlePart:Destroy()
			end)
		end)
	end
end

--[[
	This method increment by number passed in parameter "increment" the progress value of Quest
	given with the index "questIndex"
]]
function QuestsDataModule.IncrementProgress(player, questIndex, increment)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	if not QuestsPlayer or not QuestsPlayer[questIndex].Active then
		return
	end
	
    RE_QuestProgress:FireClient(player, QuestsPlayer[questIndex].Title,  tostring(QuestsPlayer[questIndex].Progress + increment) .. " / " .. tostring(QuestsPlayer[questIndex].Goal))
    if QuestsPlayer[questIndex].Progress < QuestsPlayer[questIndex].Goal then
        
        QuestsPlayer[questIndex].Progress += increment
        
        --Check if with the increment Progress do not higher to Goal
        --if it is, make Progress equal Goal because goal are reach and can't be higher
        if QuestsPlayer[questIndex].Progress > QuestsPlayer[questIndex].Goal then
            QuestsPlayer[questIndex].Progress = QuestsPlayer[questIndex].Goal
        end
        if QuestsPlayer[questIndex].Progress == QuestsPlayer[questIndex].Goal then
            RE_Notif:FireClient(
                player,
                "Quest Done",
                QuestsPlayer[questIndex].Title.."\n\nDon't forget to collect your reward."
            )
			local TextParams = {
				TitleColor = Color3.fromRGB(0, 255, 42),
				MessageColor = Color3.fromRGB(0, 255, 42),
			}
            ShowPopupBindableEvent:Fire(player, "Quest Done", QuestsPlayer[questIndex].Title.."\n\nDon't forget to collect your reward.", ToolsModule.AlertPriority.Annoucement, "ok", "Check Quest",
            nil,nil,ShowUi,{player}, TextParams)
			QuestsPlayer[questIndex].Following = false
            instanciateRewardParticle(player)
        end
    end
    PlayerDataModule:Set(player, QuestsPlayer, "Quests")
    RE_QuestRefreshUI:FireClient(player, questIndex, nil, QuestsPlayer[questIndex].Progress, QuestsPlayer[questIndex].Goal)
end

function QuestsDataModule.FollowQuest(player, questIndex)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	if not QuestsPlayer[questIndex] or not QuestsPlayer[questIndex].Active or QuestsPlayer[questIndex].Done or QuestsPlayer[questIndex].Progress == QuestsPlayer[questIndex].Goal then
		return
	end
	QuestsPlayer[questIndex].Following = not QuestsPlayer[questIndex].Following
	if QuestsPlayer[questIndex].Following then
		for _, quest in pairs(QuestsPlayer) do
			if quest ~= QuestsPlayer[questIndex] then
				quest.Following = false
			end
		end
	end
	PlayerDataModule:Set(player, QuestsPlayer, "Quests")
	RE_QuestRefreshUI:FireClient(player, questIndex, QuestsPlayer[questIndex].Following)
	RE_QuestFollow:FireClient(player, QuestsPlayer[questIndex])
end

--[[
	Debug function for delete data quest
]]
local function DeleteQuests(player)
	local Quests = PlayerDataModule:Get(player, "Quests")
	for index, quest in pairs(Quests) do
        PlayerDataModule:Set(player, nil, "Quests."..index)
	end
end


--[[
	Called to set to nil quests which completion time has passed.
	called from opening Quest menu and from TimeManager periodically
]]
function QuestsDataModule.SendNotifOnFailedQuest(player, QuestIndex)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	local quest = QuestsPlayer[QuestIndex]
	if quest.Done or quest.Progress == quest.Goal then
		return
	end
	quest.Following = false
	ShowPopupBindableEvent:Fire(player, "Quest timeout !", quest.Title.." quest completion time is out !", ToolsModule.AlertPriority.Annoucement, "ok", "Check Quests",
	nil,nil,ShowUi,{player})
	RE_Notif:FireClient(
		player,
		"Quest timeout !",
		quest.Title.." quest completion time is out! "
	)
	QuestsPlayer["failed"..QuestIndex] = quest
	QuestsPlayer[QuestIndex] = nil
	PlayerDataModule:Set(player, QuestsPlayer, "Quests")
	local dailyQuestAvailable = PlayerDataModule:Get(player, "DailyQuestAvailable")
	local maxDailyQuests = PlayerDataModule:Get(player, "DailyMaxQuest")
	local questAvailable = math.clamp(dailyQuestAvailable + 1, 0, ToolsModule.LengthOfDic(maxDailyQuests))
	PlayerDataModule:Set(player, questAvailable, "DailyQuestAvailable")
	PlayerDataModule:Set(player, 0, "DailyMaxQuest.".. QuestIndex)
	RE_QuestFailed:FireClient(player, QuestIndex)
end

RE_QuestFailed.OnServerEvent:Connect(function(player, questIndex)
	if not string.match(questIndex, "failed") then
		questIndex = "failed"..questIndex
	end
    local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
    QuestsPlayer[questIndex].Active = false
    PlayerDataModule:Set(player, QuestsPlayer, "Quests")
end)

function QuestsDataModule.SendNotifOnShortTimeQuest(player, QuestIndex)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	local quest = QuestsPlayer[QuestIndex]
    if quest.Done or quest.Progress == quest.Goal then
        return
    end
    ShowPopupBindableEvent:Fire(player, "Quest time almost out", quest.Title.." quest completion time is almost out !", ToolsModule.AlertPriority.Annoucement, "ok", "Check Quests",
    nil,nil,ShowUi,{player})
    RE_Notif:FireClient(
        player,
        "Quest time almost out",
        quest.Title.." quest completion time is almost out!"
    )
end

function QuestsDataModule.UpdateDailyQuestAvailableNumber(player)
	local dailyQuestTimer = PlayerDataModule:Get(player, "DailyMaxQuest")
	local questCount = 0
	for index, Timer in pairs(dailyQuestTimer) do
		if Timer + dailyQuestNumberRetrieveTimeInHour * 3600 <= os.time() or Timer == 0 then
			if Timer == nil then
				continue
			end
			questCount += 1
		end
	end
	RE_QuestRefreshUI:FireClient(player, nil, nil, nil, nil)
	PlayerDataModule:Set(player, questCount,"DailyQuestAvailable")
end

local function GeneratePreviewQuestTitleAndDescription(player, quest)
	local title, description
	local objectName = quest.QuestType.SearchObjectInZone.ObjectSearched
	if objectName == "All" then
		objectName = "object"
	end
	title = questNameType.NameType1 .. objectName.."s"
	local goal = ""
	if typeof(quest.Goal) ~= "table" then
    	goal = quest.Goal
    else
        goal = quest.Goal.min .. " - ".. quest.Goal.max
    end
	if quest.QuestType.SearchObjectInZone.ObjectColor ~= nil then
		description = questNameType.Descrisption .. goal .. " " .. quest.QuestType.SearchObjectInZone.ObjectColor .." " .. objectName.."s"
	else
		description = questNameType.Descrisption .. goal .." " .. objectName.."s"
	end
	return title, description
end

local function ApplyDataIfExist(data, randomObj, dataInfluence)
	if data == nil or data == "" or data == -1 or data == "Random" then
		return randomObj
	elseif typeof(data) == "table" and data.min and data.max then
		return math.round(math.random(data.min, data.max))
	elseif typeof(data) == "table" and data.ratio ~= nil then
		return dataInfluence*data.ratio
	else
		return data
	end
end

local function SetSearchObjectInZoneData(QuestData, quest)
	local randomObject = math.round(math.random(1,#questObjects))
	local randomColor = math.random(1,#questColorObject)
	quest.QuestType.searchObjectInZone = DataManagerModule.RecursiveCopy(questType.searchObjectInZone) -- When other type are implemented change '1' by a randint of the types
	quest.QuestType.searchObjectInZone.Object = ApplyDataIfExist(QuestData.QuestType.SearchObjectInZone.ObjectSearched, questObjects[randomObject])
	if questColorObject[randomColor] == nil then
		quest.QuestType.searchObjectInZone.Color = ApplyDataIfExist(QuestData.QuestType.SearchObjectInZone.ObjectColor, questColorObject[randomColor])
	else
		quest.QuestType.searchObjectInZone.Color = ApplyDataIfExist(QuestData.QuestType.SearchObjectInZone.ObjectColor, questColorObject[randomColor].Name)
	end
	local originPoint  = {
		X = QuestData.QuestType.SearchObjectInZone.ZoneOrigin.X,
		Y = QuestData.QuestType.SearchObjectInZone.ZoneOrigin.Y,
		Z = QuestData.QuestType.SearchObjectInZone.ZoneOrigin.Z,
	}
	quest.QuestType.searchObjectInZone.ZoneOrigin.X = ApplyDataIfExist(originPoint.X, 0)
	quest.QuestType.searchObjectInZone.ZoneOrigin.Y = ApplyDataIfExist(originPoint.Y, 0)
	quest.QuestType.searchObjectInZone.ZoneOrigin.Z = ApplyDataIfExist(originPoint.Z, 0)
	quest.QuestType.searchObjectInZone.ZoneSize = ApplyDataIfExist(QuestData.QuestType.SearchObjectInZone.ZoneSize, math.round(math.random(500,1000)))

	--TITLE / DESCRIPTION
	local objectName = quest.QuestType.searchObjectInZone.Object
	local description = ""
	if objectName == "All" then
		objectName = "object"
	end
	quest.Title = ApplyDataIfExist(QuestData.Title, questNameType.NameType1 .. objectName.."s")
	if quest.QuestType.searchObjectInZone.Color ~= nil then
		description = questNameType.Descrisption .. quest.Goal .. " " .. quest.QuestType.searchObjectInZone.Color .." " .. objectName.."s"
	else
		description = questNameType.Descrisption .. quest.Goal .." " .. objectName.."s"
	end
	quest.Description = ApplyDataIfExist(QuestData.Description, description)
end

local function SetQuestData(QuestData, QuestsPlayer)
	local questsGenerated = {}
	local questCount = GetQuestCount(QuestsPlayer, true)
	for i = 1, QuestData.NumbOfQuestsGiven, 1 do
		local quest = DataManagerModule.RecursiveCopy(QuestStruct)
		quest.Active = false
		quest.QuestTime = os.time()
		quest.Goal = ApplyDataIfExist(QuestData.Goal, math.round(math.random(3,6)))
		quest.EcusReward = ApplyDataIfExist(QuestData.EcusReward, quest.Goal, quest.Goal)
		quest.FeezReward = ApplyDataIfExist(QuestData.FeezReward, quest.Goal, quest.Goal)
		quest.SparksReward = ApplyDataIfExist(QuestData.SparksReward,  quest.Goal, quest.Goal)
		quest.QuestTimeAllowedInMin = ApplyDataIfExist(QuestData.TimeAllowedInMin, quest.Goal, quest.Goal)
		quest.TimeWarningRatio = ApplyDataIfExist(QuestData.TimeWarnRatio, 0.5)
		quest.Title = QuestData.Title
		quest.Description = QuestData.Description
		if QuestData.QuestType.SearchObjectInZone.Enabled == true then
			SetSearchObjectInZoneData(QuestData, quest)
		else
			warn("No quest type chosen")
		end
		quest.QuestRequirements = DataManagerModule.RecursiveCopy(questRequirements)
		quest.QuestRequirements.CreatureType = ApplyDataIfExist(QuestData.Requirements.Type, CreaturesTypes[math.random(1,#CreaturesTypes)])
		quest.QuestRequirements.CreatureRace = ApplyDataIfExist(QuestData.Requirements.Race, CreaturesRaces[quest.QuestRequirements.CreatureType][math.random(1,#CreaturesRaces[quest.QuestRequirements.CreatureType])])
		if QuestData.QuestType.SearchObjectInZone.ZoneType == nil or QuestData.QuestType.SearchObjectInZone.ZoneType == "" then
			local ZoneType
			local race = quest.QuestRequirements.CreatureRace
			if race == "Fire" then
				ZoneType = "CrackedLava"
			elseif race == "Water" then
				ZoneType = "Water"
			elseif race == "Ground" then
				ZoneType = "Ground"
			end
			quest.QuestType.searchObjectInZone.ZoneType = ZoneType
		else
			quest.QuestType.searchObjectInZone.ZoneType = QuestData.QuestType.SearchObjectInZone.ZoneType
		end
		questsGenerated[i] = quest
	end
	return questsGenerated
end

local function GetOldestDailyQuestTime(player)
	local questTimes = PlayerDataModule:Get(player, "DailyMaxQuest")
	local questReplacedIndex
	local questReplacedTime = math.huge
	for index, questTime in pairs(questTimes) do
		if questTime < questReplacedTime then
			questReplacedTime = questTime
			questReplacedIndex = index
		end
	end
	print(questReplacedIndex)
	if questReplacedTime + dailyQuestNumberRetrieveTimeInHour * 3600 >= os.time() then
		return
	end
	return questReplacedIndex
end

local function SetOldestDailyQuestTime(player, questTime)
	local questTimes = PlayerDataModule:Get(player, "DailyMaxQuest")
	local questReplacedIndex
	local questReplacedTime = math.huge
	for index, questTime in pairs(questTimes) do
		if questTime < questReplacedTime then
			questReplacedTime = questTime
			questReplacedIndex = index
		end
	end
	if questReplacedTime + dailyQuestNumberRetrieveTimeInHour * 3600 >= os.time() then
		return
	end
	PlayerDataModule:Set(player, questTime, "DailyMaxQuest."..questReplacedIndex, true)
	return questReplacedIndex
end

local function SetDailyQuestTime(player, questIndex, questTime)
	TimeManager.SetDailyQuestRetrieveTime(player, questIndex, questTime, dailyQuestNumberRetrieveTimeInHour, QuestsDataModule.UpdateDailyQuestAvailableNumber)
	PlayerDataModule:Set(player, questTime, "DailyMaxQuest."..questIndex, true)
	local questTimes = PlayerDataModule:Get(player, "DailyMaxQuest")
	if ToolsModule.LengthOfDic(questTimes) > 3 then
		local questErasedIndex
		local questErasedTime = math.huge
		for index, questTime in pairs(questTimes) do
			if questTime < questErasedTime then
				questErasedTime = questTime
				questErasedIndex = index
			end
		end
		TimeManager.DeleteDailyQuestRetrieveTime(player, questErasedIndex)
		PlayerDataModule:Set(player, nil, "DailyMaxQuest.".. questErasedIndex)
	end
end

function QuestsDataModule.GenerateQuests(player, QuestData, QuestsPlayer)
	-- first called for preview then fire it back with quest data generated (to display it) then 2nd call to active it.
	local quest = SetQuestData(QuestData, QuestsPlayer)
	local questGivenNumber = ToolsModule.LengthOfDic(quest)
	local dailyQuestAvailable = PlayerDataModule:Get(player, "DailyQuestAvailable")
	if dailyQuestAvailable < questGivenNumber then
		return
	end
	local index = GetOldestDailyQuestTime(player)
	for key, value in pairs(quest) do
		QuestsPlayer[index] = value
	end

	PlayerDataModule:Set(player, QuestsPlayer, "Quests")
	PlayerDataModule:Set(player, dailyQuestAvailable - questGivenNumber, "DailyQuestAvailable")
	RE_QuestGenerate:FireClient(player, quest)
end

local function ApplyOrDeleteQuest(player, QuestData, isAccepted, QuestsPlayer)
	-- 2nd call to apply or delete quest
	local questTime = os.time()
	local numQuestTaken = ToolsModule.LengthOfDic(QuestData)
	local index = {}
	for i = 1, numQuestTaken, 1 do
		index[i] = SetOldestDailyQuestTime(player, questTime+i)
	end
	
	for questIndex, questData in pairs(QuestData) do
		-- is daily quest available
		local dailyQuestAvailable = PlayerDataModule:Get(player, "DailyQuestAvailable")
		print(dailyQuestAvailable)
		if dailyQuestAvailable < 0 then
			QuestsPlayer[index[questIndex]] = nil
			PlayerDataModule:Set(player, QuestsPlayer, "Quests")
			warn("No more daily quest available.")
			return
		end
		if not isAccepted then
			local dailyMaxQuest = PlayerDataModule:Get(player, "DailyMaxQuest")
			QuestsPlayer[index[questIndex]] = nil
			PlayerDataModule:Set(player, QuestsPlayer, "Quests")
			PlayerDataModule:Set(player, dailyQuestAvailable + 1, "DailyQuestAvailable")

			PlayerDataModule:Set(player, 0, "DailyMaxQuest.".. index[questIndex])
			return
		end
		QuestsDataModule.UpdateDailyQuestAvailableNumber(player)
		--Applying quest
		print(QuestsPlayer, " ", index)
		QuestsPlayer[index[questIndex]].Active = true
		QuestsPlayer[index[questIndex]].QuestTime = questTime
		PlayerDataModule:Set(player, QuestsPlayer, "Quests")
	end
	local UpdatedQuestsPlayer = PlayerDataModule:Get(player, "Quests")
    for questIndex, quest in pairs(QuestData) do
		local questUpdData= UpdatedQuestsPlayer[index[questIndex]]
		if not questUpdData.Active or questUpdData.Done then
			continue
		end
		SetDailyQuestTime(player, index[questIndex], questUpdData.QuestTime)
        TimeManager.SetQuestTimeStamp(player, index[questIndex], questUpdData, QuestsDataModule.SendNotifOnShortTimeQuest, QuestsDataModule.SendNotifOnFailedQuest)
        RF_QuestSetup:InvokeClient(player, index[questIndex], PlayerDataModule:Get(player, "DailyMaxQuest"))
        QuestsDataModule.FollowQuest(player, index[questIndex])
    end
end

local function GenerateAndSetQuest(player, QuestData, isPreview, isAccepted)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	-- if quest deleter then delete all quests
	if QuestData.DeleteQuests == true then
		DeleteQuests(player, QuestsPlayer)
		return
	end
	if isPreview then
		QuestsDataModule.GenerateQuests(player, QuestData, QuestsPlayer)
	else
		ApplyOrDeleteQuest(player, QuestData, isAccepted, QuestsPlayer)
	end
end

local function SetupQuestStamps(player)
	local QuestsPlayer = PlayerDataModule:Get(player, "Quests")
	for questIndex, quest in pairs(QuestsPlayer) do
        TimeManager.SetQuestTimeStamp(player, questIndex, quest, QuestsDataModule.SendNotifOnShortTimeQuest, QuestsDataModule.SendNotifOnFailedQuest)
		TimeManager.SetDailyQuestRetrieveTime(player, questIndex, quest.QuestTime, dailyQuestNumberRetrieveTimeInHour, QuestsDataModule.UpdateDailyQuestAvailableNumber)
        QuestsDataModule.FollowQuest(player, questIndex)
    end
end

playerService.PlayerAdded:Connect(function(player)
    task.wait(1)
    SetupQuestStamps(player)
end)

for _, player in pairs(playerService:GetPlayers()) do
	SetupQuestStamps(player)
end

RE_QuestProgress.OnServerEvent:Connect(QuestsDataModule.IncrementProgress)
BE_QuestProgress.Event:Connect(QuestsDataModule.IncrementProgress)

RE_QuestGenerate.OnServerEvent:Connect(GenerateAndSetQuest)
RE_QuestFollow.OnServerEvent:Connect(QuestsDataModule.FollowQuest)
RE_UpdateDailyQuestNumber.OnServerEvent:Connect(QuestsDataModule.UpdateDailyQuestAvailableNumber)
RF_GenerateQuestName.OnServerInvoke = function(player, quest)
	return GeneratePreviewQuestTitleAndDescription(player, quest)
end

return QuestsDataModule
