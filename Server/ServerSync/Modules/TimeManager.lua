local TimeManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

--Require Module
local PlayerDataModule = require("PlayerDataModule")
local HorsesDataModule = require("HorsesDataModule")
local HorseStatusHandler = require("HorseStatusHandler")
local GameDataModule = require("GameDataModule")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
--Event
local StartBreedingEvent = BindableEvent.StartBreeding
local StartGrowthFoal = BindableEvent.StartGrowthFoal
local TimerMaintenanceEvent = RemoteEvent.TimerMaintenance

--params/data
TimeManager.QuestsTimeStamp = {}
TimeManager.DailyQuestsTimeStamp = {}

--[[
	This method allow to check where is the timer of breeding horse ID given in paramter.
	This check method is only call when player connect to the game and check if breeding is down or not.
	If is down : Call remove method horse from nursery
	If not down : Calculate the time before breeding down and launch the breeding timer for the horse given
	in parameter with the time passed begin last connexion.
]]
function TimeManager.CheckBreedingTimer(player, creatureID)
	print("CHECKING BREEDING PLAYER")
	local TimeBreedingValue = HorsesDataModule.GetTimeBreedingValueOfCreatureID(player, creatureID)
	print("TimeBreedingValue", TimeBreedingValue)
	if TimeBreedingValue > 0 then
		--Calculates the time since the last connection
		local TimePassed = TimeManager.ManyTimeAfterLastConnexionPlayer(player)
		print("Time passed", TimePassed)
		
		--Check if time saved before last connection and time passed < or > the breeding timing goal
		if TimeBreedingValue + TimePassed < GameDataModule.TimeBreedingGoal then
			--If inferior, breeding it's not finish and launch the timer breeding with the time already passed
			print("REPRISE DU BREEDING")
			TimeManager.LaunchBreedingTimer(player, creatureID, TimePassed)
		else
			--If superior, breeding already down when player not connected, remove horse from nursery and baby is born
			HorsesDataModule.RemoveHorsesFromNursery(player, creatureID)
			print("Breeding ended when u not here, you have a new poney !")
		end
	end
end

--[[
	This method create a timer counter thread for the breeding of horse ID given in parameters.
	Method contain a event listener on player remove connection allow to prevent a player
	disconnection and record where the timer was for the next connection.
]]
function TimeManager.LaunchBreedingTimer(player, creatureID, time_passed)
	task.spawn(function()
		print("Breeding starting !")
		local TimeBreedingValue = HorsesDataModule.GetTimeBreedingValueOfCreatureID(player, creatureID) + time_passed
		local connectRemove
		--Listen the event remove player from game for save the TimeBreedingValue when is disconnected
		connectRemove = game.Players.PlayerRemoving:Connect(function(playerRemove)
			if playerRemove == player then
				print("Time Breeding on remove player", TimeBreedingValue)
				HorsesDataModule.SetTimeBreedingValueOfCreatureID(player, creatureID, TimeBreedingValue)
			end
		end)
		
		--Timing to increase value of time passed on the thread life
		--while the thread exist the value is increase and check if breeding is down or not
		while TimeBreedingValue < GameDataModule.TimeBreedingGoal do
			TimeBreedingValue += 1
			task.wait(1)
		end
		
		--if while is down and the next of code thread is executed : Breeding is finish, so Disconnect the event listener
		if connectRemove then
			connectRemove:Disconnect()
		end
		
		--And here remove horse from the nursery and the baby is born
		HorsesDataModule.RemoveHorsesFromNursery(player, creatureID)
		print("Breeding ended, you have a new poney !")
	end)
end

--[[
	Create and spawn a timer counter thread for the growth of foal ID given.
	Method contain a event listener on player remove connection allow to prevent a player
	disconnection and record where the timer was for the next connection.
	If player never disconnected during the timer growth of foal and the timer is done,
	we call function to set up foal growth to horse and remove the listener disconnect player.
]]
function TimeManager.LaunchGrowthTimer(player, creatureID, time_passed)
	task.spawn(function()
		print("Growth starting !")
		HorsesDataModule.SetTimeGrowthValueOfCreatureID(player, creatureID, HorsesDataModule.GetTimeGrowthValueOfCreatureID(player, creatureID) + time_passed)

		-- Check if player are VIP and apply time /2 if yes
		local TimeGrowthVIP = BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.VIP.ProductID) and GameDataModule.TimeGrowthHorseGoal/2 or GameDataModule.TimeGrowthHorseGoal

		--Timing to increase value of time passed on the thread life
		--while the thread exist the value is increase and check if growth is done or not
		while HorsesDataModule.GetTimeGrowthValueOfCreatureID(player, creatureID) < TimeGrowthVIP do
			local TimeGrowthValue = HorsesDataModule.GetTimeGrowthValueOfCreatureID(player, creatureID) + 1
			HorsesDataModule.SetTimeGrowthValueOfCreatureID(player, creatureID, TimeGrowthValue)
			task.wait(1)
		end

		--And here change the foal to horse
		HorsesDataModule.SetFoalToHorse(player, creatureID)
		print("Growth of Foal ended, Your foal has grown into a horse !")
	end)
end

--[[
	This method allow to check where is the timer of growth foal ID given in paramter.
	This check method is only call when player connect to the game and check if growth is finish or not.
	Finish : Call method to set growth type of foal to horse
	Not Finish : Calculate the time before growth done and launch the timer for the horse (foal) given
	in parameter with the time passed begin last connexion.
]]
function TimeManager.CheckGrowthTimer(player, creatureID)
	print("CHECKING GROWTH PLAYER")
	local TimeGrowthValue = HorsesDataModule.GetTimeGrowthValueOfCreatureID(player, creatureID)
	if TimeGrowthValue > 0 then
		--Calculates the time since the last connection
		local TimePassed = TimeManager.ManyTimeAfterLastConnexionPlayer(player)
		print("Time passed", TimePassed)

		-- Check if player are VIP and apply time /2 if yes
		local TimeGrowthVIP = BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.VIP.ProductID) and GameDataModule.TimeGrowthHorseGoal/2 or GameDataModule.TimeGrowthHorseGoal

		--Check if time saved before last connection and time passed < or > the growth timing goal
		if TimeGrowthValue + TimePassed < TimeGrowthVIP then
			--If inferior, growth it's not finish and launch the timer growth with the time already passed
			print("REPRISE DU GROWTH")
			TimeManager.LaunchGrowthTimer(player, creatureID, TimePassed)
		else
			--If superior, growth is done when player not connected, change growth statut of foal to horse
			HorsesDataModule.SetFoalToHorse(player, creatureID)
			print("Growth of Foal ended, Your foal has grown into a horse !")
		end
	end
end

--[[
	This method calculate and return the difference time after last connection player in seconds.
]]
function TimeManager.ManyTimeAfterLastConnexionPlayer(player)
	local LastTime = PlayerDataModule:Get(player, "LastDateConnexion")
	if LastTime then
		if LastTime == 0 then
			print("No last connexion")
			return
		end
		
		local ActualTime = os.time()
		--print(LastTime, ActualTime)
		
		local diffTime = os.difftime(ActualTime, LastTime)
		return diffTime
		--[[
		if diffTime < 60 then
			print(diffTime, "Secondes")
		elseif diffTime > 60 then
			diffTime = diffTime/60
			print(diffTime, "Minutes")
		elseif diffTime > 3600 then
			diffTime = diffTime/3600
			print(diffTime, "Heures")
		end
		]]
	end
end

--[[
	Function check and initialize timerBased infos
]]
local function playerInitialization(player)
	--Wait data is initalize
	--game.ServerStorage.ServerStorageSync.PlayerData:WaitForChild(player.UserId):WaitForChild("NurseryCollection")
	
	--Check for all horses in nursery where their breeding is at
	local nursery = PlayerDataModule:Get(player, "NurseryCollection")
	for index, data in pairs(nursery) do
		TimeManager.CheckBreedingTimer(player, index)
	end
	
	--Check ine horse collection the foal growth need
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	for index, data in pairs(creaturesCollection) do
		if data.Growth == HorsesDataModule.GrowthType.Baby then
			TimeManager.CheckGrowthTimer(player, index)
		end
	end
	
	--Fire event to player added for launch the local timer for decrease maintenance values horses
	TimerMaintenanceEvent:FireClient(player, GameDataModule.CreatureMaintenance_Interval)
	print("DECREASE MAINTENANCE")
	--At the player connection, check many time is passed for horses maintenance and decrease values needed
	HorseStatusHandler.DecreaseMaintenanceValuesOfCreatures(player, GameDataModule.CreatureMaintenance_Interval, os.time())
end

for _, playerInstance in pairs(PlayerService:GetPlayers()) do
	playerInitialization(playerInstance)
end


function TimeManager.SetQuestTimeStamp(player, QuestIndex, QuestData, OnWarnCallBack, OnFailedCallBack)
	if not QuestData.Active then
		return
	end
	if TimeManager.QuestsTimeStamp[player.UserId] == nil then
		TimeManager.QuestsTimeStamp[player.UserId] = {}
	end
	local MinToSecond = 60
	TimeManager.QuestsTimeStamp[player.UserId][QuestIndex] = {
		QuestTimeInSec = QuestData.QuestTime,
		QuestTimeAllowedInSec = QuestData.QuestTimeAllowedInMin * MinToSecond,
		TimeWarningRatio = QuestData.TimeWarningRatio,
	}
	local questStamps = TimeManager.QuestsTimeStamp[player.UserId][QuestIndex]


	local questTimeEnd = questStamps.QuestTimeInSec + questStamps.QuestTimeAllowedInSec
	if os.time() < questTimeEnd then
		local timeBeforeQuestTimeEndInSec = questTimeEnd - os.time()
		task.delay(timeBeforeQuestTimeEndInSec,function()
			--Send notif quest Failed
			OnFailedCallBack(player, QuestIndex)
		end)
	else
		OnFailedCallBack(player, QuestIndex)
		return
	end

	local timeWarn = questStamps.QuestTimeInSec + (questStamps.QuestTimeAllowedInSec*questStamps.TimeWarningRatio)
	if os.time() < timeWarn then
		local timeBeforeWarnInSec = timeWarn - os.time()
		task.delay(timeBeforeWarnInSec,function()
			--Send notif quest Warn
			OnWarnCallBack(player, QuestIndex)
		end)
	else
		OnWarnCallBack(player, QuestIndex)
	end
end

function TimeManager.SetDailyQuestRetrieveTime(player, QuestIndex, timeQuest, RetrieveTime, OnRetrieveDailyQuest)
	if TimeManager.DailyQuestsTimeStamp[player.UserId] == nil then
		TimeManager.DailyQuestsTimeStamp[player.UserId] = {}
	end
	TimeManager.DailyQuestsTimeStamp[player.UserId][QuestIndex] = {
		Timing = timeQuest,
		RetrieveTime = RetrieveTime,
		Active = true,
	}
	local dailyQuestStamp = TimeManager.DailyQuestsTimeStamp[player.UserId][QuestIndex]
	local HourToSecond = 3600
	local TimeRetrieve = dailyQuestStamp.Timing + dailyQuestStamp.RetrieveTime * HourToSecond
	if os.time() < TimeRetrieve then
		local timeBeforeUpdateInSec = TimeRetrieve - os.time()
		task.delay(timeBeforeUpdateInSec,function()
			if TimeManager.DailyQuestsTimeStamp[player.UserId][QuestIndex].Active then
				OnRetrieveDailyQuest(player, QuestIndex)
			end
			TimeManager.DailyQuestsTimeStamp[player.UserId][QuestIndex] = nil
		end)
	else
		OnRetrieveDailyQuest(player, QuestIndex)
		TimeManager.DailyQuestsTimeStamp[player.UserId][QuestIndex] = nil
	end
end

function TimeManager.DeleteDailyQuestRetrieveTime(player, questErasedIndex)
	if TimeManager.DailyQuestsTimeStamp[player.UserId][questErasedIndex] then
		TimeManager.DailyQuestsTimeStamp[player.UserId][questErasedIndex].Active = false
	end
end

--Events Function
--[[
	This is a event listener on Player added in game (connection player)
	if can not work in studio, it's because the studio load some pile of work before load player.
]]
PlayerService.PlayerAdded:Connect(function(player)
	playerInitialization(player)
end)

--[[
	This is a event listener on StartBreeding event send for launch the method breeding timer
]]
StartBreedingEvent.Event:Connect(function(player, horseMotherID)
	TimeManager.LaunchBreedingTimer(player, horseMotherID, 0)
end)

--[[
	This is a event listener on StartGrowthFoal event send for launch the method growth timer
]]
StartGrowthFoal.Event:Connect(function(player, creatureID)
	TimeManager.LaunchGrowthTimer(player, creatureID, 0)
end)

--[[
	This event listen when client need to the server to update decrease value maintenance for all horses's player
]]
TimerMaintenanceEvent.OnServerEvent:Connect(function(player)
	print("EVENT TIMER CALLED ON SERVER BY CLIENT")
	HorseStatusHandler.DecreaseMaintenanceValuesOfCreatures(player, GameDataModule.CreatureMaintenance_Interval, os.time())
end)

return TimeManager
