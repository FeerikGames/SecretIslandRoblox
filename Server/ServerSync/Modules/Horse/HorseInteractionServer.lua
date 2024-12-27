local HorseInteractionServer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local Assets = ReplicatedStorage.SharedSync:WaitForChild("Assets")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GetRemoteEvent = require("GetRemoteEvent")
local HorseDataModule = require("HorsesDataModule")
local HorseStatusHandler = require("HorseStatusHandler")
local HorseLoader = require("HorseLoader")
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")

local InteractionEvent = GetRemoteEvent("InteractionEvent")

local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

--[[
    Launch Popup for show Player don't have enought Harvest and who get it or buy it
]]
local function ShowPopupHarvestEmpty(player:Player)
    -- Function callback for yes button from popup
	local function CallbackYES()
		RemoteEvent.ShowShopUIForItem:FireClient(player, "Ressource_100_TotalHarvests//:57")
	end

	-- Setup popup with 2 methods for No button and YEs button of popup (confirm and cancel delete animals)
	BindableEvent.ShowPopupAlert:Fire(
		player,
		"Empty Food",
		"<font color=\"rgb(255,0,0)\">You are out of food!</font>\nHarvest from your farm or buy some in the store.",
		ToolsModule.AlertPriority.Annoucement,
		"GO SHOP",
		ToolsModule.AlertTypeButton.OK,
		CallbackYES,
		{},
		nil, nil
	)
end

--[[
    This local function allow to increase maintenance of type selected by player action with horse, expected Fed who are particular (see local function FeedInteractionMaintenance)
    Here we check Maintenance type, search data value and max and setup progress bar and increase if not at the max.
]]
local function BaseTypeMaintenanceIncrease(Player, Data, MaintenanceType, by)
    local CreatureData = PlayerDataModule:Get(Player,"CreaturesCollection."..Data.CreatureID)
    local maintenanceData = CreatureData["Maintenance"][MaintenanceType]
    local originProgress = maintenanceData.Value
    --check if horse maintenance value is max or not
    if maintenanceData.Value < maintenanceData.Max then
        HorseStatusHandler.IncreaseMaintenanceValuesOfHorse(Player, CreatureData, Data.CreatureID, MaintenanceType, by)
    else
        warn("HORSE "..MaintenanceType.." IS ALREADY FULL !")
    end
    --show the progress bar with data of maintenance type
    InteractionEvent:FireClient(Player, false, MaintenanceType, Data.HorseTarget.PrimaryPart, maintenanceData.Value, maintenanceData.Max, originProgress, Data.CreatureID)
end

--[[
    This function are (for the moment) just for FED maintenance horse. We check quantity and disponibility of ressources used for feed horse in player data
    and check min value, max value, diff beteewen all value for calculate the good quantity to give or not.
    We setup a progress bar with maintenance value and max for show status Fed horse to player.
    (If we want to make the same things for another maintenance value with consumable refactor this function, if no consumable use local function BaseTypeMaintenanceIncrease)
]]
local function FeedInteractionMaintenance(Player, Data)
    local TotalHarvests = PlayerDataModule:Get(Player, "TotalHarvests")
    local CreatureData = PlayerDataModule:Get(Player, "CreaturesCollection."..Data.CreatureID)
    local HorseDataFed = CreatureData.Maintenance.Fed
    local originFed = HorseDataFed.Value
    local fedDefaultValue = 10
    
    local fedDiffLow = 0 --for check if stock have not the same or more of default fed value
    local fedDiffMax = 0
    
    --setup data player to decrease total of harvests value
    local TotalHarvestAfter = TotalHarvests - fedDefaultValue
    if Data.IsFull then
        local harvestNeeded = HorseDataFed.Max - originFed
        fedDefaultValue = harvestNeeded
        if TotalHarvests - harvestNeeded < 0 then
            fedDefaultValue = TotalHarvests
            TotalHarvestAfter = 0
        end
    else
        if TotalHarvestAfter < 0 then
            print("TOTAL IS NEGATIVE", TotalHarvestAfter)
            fedDiffLow = TotalHarvestAfter
            TotalHarvestAfter = 0

            ShowPopupHarvestEmpty(Player)
            --RemoteEvent.ShowShopUIForItem:FireClient(Player, "Ressource_100_TotalHarvests//:57")
        end
    end
    
    --check if player have fed stock for horse
    if TotalHarvestAfter > 0 or fedDiffLow ~= -fedDefaultValue then
        --check if horse fed value is max or not
        if HorseDataFed.Value < HorseDataFed.Max then
            fedDiffMax = HorseDataFed.Max - HorseDataFed.Value
            if fedDiffMax <= fedDefaultValue and fedDiffLow == 0 then
                TotalHarvests -= fedDiffMax
                fedDiffMax = fedDefaultValue - fedDiffMax
            else
                TotalHarvests = TotalHarvestAfter
                fedDiffMax = 0
            end

            PlayerDataModule:Set(Player, TotalHarvests, "TotalHarvests")
            --Increase value of fed for horse after check we can fed it
            HorseStatusHandler.IncreaseMaintenanceValuesOfHorse(Player, CreatureData, Data.CreatureID, "Fed", fedDefaultValue + fedDiffLow - fedDiffMax)
            --BaseTypeMaintenanceIncrease(Player, Data, "Happyness", (fedDefaultValue + fedDiffLow - fedDiffMax) > 5 and (fedDefaultValue + fedDiffLow - fedDiffMax)/2 or 5)
        else
            warn("HORSE FED IS ALREADY FULL !")
        end
    else
        warn("TOTAL HARVESTS IS EMPTY, GO FARM MORE FED !")
    end

    InteractionEvent:FireClient(Player, false, "Fed", Data.HorseTarget.PrimaryPart, HorseDataFed.Value, HorseDataFed.Max, originFed, Data.CreatureID)
end



local function UpdateHorseMaintenanceRateValue(Player, Data, typeChanging, typeChanged)
    local HorseMaintenanceType = PlayerDataModule:Get(Player, "CreaturesCollection."..Data.CreatureID..".Maintenance")
    local rateValue = HorseMaintenanceType[typeChanging].Value / HorseMaintenanceType[typeChanging].Max -0.5
    HorseDataModule.ChangeRateDecreaseOfMaintenanceValue(Player, Data.HorseTarget.CreatureID.Value, "Happyness", 5 - rateValue*3)
end

--[[
    Init function to setup the beahvior of interaction event when is call
]]
function HorseInteractionServer:Init()
    InteractionEvent.OnServerEvent:Connect(function(Player, Reason, Data)
        if Data.HorseTarget:FindFirstChild("CreatureID") and Data.HorseTarget.CreatureID.Value == Data.CreatureID then
            if Reason == "Fed" then
                FeedInteractionMaintenance(Player, Data)
                --UpdateHorseMaintenanceRateValue(Player, Data, Reason, "Happyness")
            elseif Reason == "Happyness" then
                --[[ BaseTypeMaintenanceIncrease(Player, Data, Reason, 10) ]]
            elseif Reason == "Care" then
                --[[ BaseTypeMaintenanceIncrease(Player, Data, Reason, 10)
                BaseTypeMaintenanceIncrease(Player, Data, "Happyness", 5)
                UpdateHorseMaintenanceRateValue(Player, Data, Reason, "Happyness") ]]
            elseif Reason == "Cleanness" then
                --[[ BaseTypeMaintenanceIncrease(Player, Data, Reason, 10)
                BaseTypeMaintenanceIncrease(Player, Data, "Happyness", 5)
                UpdateHorseMaintenanceRateValue(Player, Data, Reason, "Happyness") ]]
            elseif Reason == "Scrape" then
                BaseTypeMaintenanceIncrease(Player, Data, Reason, 10)
            elseif Reason == "Brushed" then
                BaseTypeMaintenanceIncrease(Player, Data, Reason, 10)
            end
        end
    end)
end

--When creature is mounted check status Health to decide show or not maintenance status interaction
HorseLoader.PlayerMountedHorse:Connect(function(Player,CreatureData)
    task.wait(.1)
    HorseStatusHandler.CheckHealthStatus(Player, CreatureData.ID, nil, 0)
end)

return HorseInteractionServer