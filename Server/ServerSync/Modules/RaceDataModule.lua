local RaceDataModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local PlayerDataModule = require("PlayerDataModule")
local GameDataModule = require("GameDataModule")

local HTTPService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local dataType = "Test2"
local RaceDataStore = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.GameSystem.RaceData.Name..GameDataModule.DatastoreVariables.GameSystem.RaceData.Version)


local RaceDataStructure = {
    RaceName = "";
    PlayerClassement = {};
}

local playerRaceStructure = {
    Placement = 0;
    Timing = math.huge;
}
local sessionRaceData = {};

function Round(Number: number, Precision: number?) : number
	local Places = (Precision) and (10^Precision) or 1
	return (((Number * Places) + 0.5 - ((Number * Places) + 0.5) % 1)/Places)
end

function RecursiveCopy(dataTable)
	local tableCopy = {}
	for index, value in pairs(dataTable) do
		if type(value) == "table" then
			value = RecursiveCopy(value)
		end
		tableCopy[index] = value
	end

	return tableCopy
end


function RaceDataModule.UpdatePlayerRaceData(raceInfo, players)
    -- ALGO DE TRI A FAIRE
    local RaceData = sessionRaceData[raceInfo.DisplayName].PlayerClassement
    for userID, player in pairs(players) do
        local playerkey = tostring(userID)
        if not RaceData[playerkey] then
            RaceData[playerkey] = RecursiveCopy(playerRaceStructure)
        end
        RaceData[playerkey].Placement = player.Placement
        RaceData[playerkey].Player = {
            name = player.player.Name;
            userId = player.player.UserId;
        }
        if RaceData[playerkey].Timing > Round(player.Timing, 3) then
            RaceData[playerkey].Timing = Round(player.Timing, 3)
        end
    end
end

function RaceDataModule.SortPlayerRankingInRace(raceInfo)
    local RaceData = sessionRaceData[raceInfo.DisplayName]
    for _, player in pairs(RaceData.PlayerClassement) do
        local up = 1
        for _, playerCompared in pairs(RaceData.PlayerClassement) do
            if player.Timing > playerCompared.Timing then
                up += 1
            end
        end
        player.Placement = up
    end
end

function RaceDataModule.SetRaceDataPlayers(raceInfo, players)
   RaceDataModule.SetupRaceData(raceInfo.DisplayName)
   RaceDataModule.UpdatePlayerRaceData(raceInfo, players)
   RaceDataModule.SortPlayerRankingInRace(raceInfo)
   RaceDataModule.SaveRace(raceInfo.DisplayName)
end

function RaceDataModule.GetRaceData(raceInfo)
    RaceDataModule.SetupRaceData(raceInfo.DisplayName)
    return sessionRaceData[raceInfo.DisplayName]
end

function RaceDataModule.LoadRace(RaceId)
    task.wait()
	local key = tostring(RaceId)
	local data
	local success, err = pcall(function()
		data = RaceDataStore:GetAsync(key)
	end)
	if not success then
		data = RaceDataModule.LoadRace(RaceId)
	end

	return data
end

function RaceDataModule.SaveRace(RaceId)
    task.wait()
	local key = tostring(RaceId)
	if not sessionRaceData[key] then
		print(key .." no data to save.")
		return
	end
	local data = RecursiveCopy(sessionRaceData[key])
	

	local success, err = pcall(function()
		RaceDataStore:SetAsync(key, data)
	end)
	if success then
		print(key.. "'s data has been saved!")
	else
		RaceDataModule.SaveRace(key)
	end
end

function RaceDataModule.SetupRaceData(RaceId)
    local raceData = RaceDataModule.LoadRace(RaceId)
    if raceData then
        local baseRaceData = RecursiveCopy(RaceDataStructure)
        for dataName, data in pairs(baseRaceData) do
            if not raceData[dataName] then
                raceData[dataName] = data
            end
        end
        sessionRaceData[RaceId] = raceData
    else
        local initRaceData = RecursiveCopy(RaceDataStructure)
        initRaceData.RaceName = RaceId
        sessionRaceData[RaceId] = initRaceData
    end
end

return RaceDataModule