local MinigamesEventLauncher = {}

-- Depedencies

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local StartingZoneModule = require("StartingZoneModule")
local RaceHandler = require("RaceHandler")
local MinigameModule = require("MinigamesRuntime")
local ToolsModule = require("ToolsModule")

local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_ZoneUiState = RemoteEventFolder.ZoneUiState
local RE_ActivateGame = RemoteEventFolder.ActivateGame


local function GetAllGames()
    local allGames = {}
    local races = RaceHandler:GetRaces()
    local miniGames = {} -- MinigameModule:GetMinigamesData()
    for index, miniGame in pairs(miniGames) do
        allGames[index] = miniGame
    end
    for index, race in pairs(races) do
        allGames[index] = race
    end
    return allGames
end

local function GetRandomGame(games)
    local randomGameNum = math.random(ToolsModule.LengthOfDic(games))
    local randomGame = nil
    local count = 1
    for index, Game in pairs(games) do
        if count == randomGameNum then
            if Game.Ongoing or Game.WaitingForMorePlayers then
                games[index] = nil
                return GetRandomGame(games)
            end
            randomGame = Game
            break
        end
        count += 1
    end
    return randomGame
end

local function LaunchGame(Game)
    StartingZoneModule:HideLightRay(Game)
    Game.isEventRunning = false
    local playerCount = ToolsModule.LengthOfDic(Game.Players)
    if playerCount < Game.playerNeeded then
        return
    end
    if Game.GameName == "Race" then
        RaceHandler:LaunchGame(Game)
    elseif Game.GameName == "Tag" or Game.GameName == "HotPotato" then
        MinigameModule:LaunchGame(Game)
    end
end

local function CallWaitingUi(Game)
    for competitor, competitorInfo in pairs(Game.Players) do
        RE_ZoneUiState:FireClient(competitorInfo.player, Game, "EventWaiting", nil, Game.EventCurrentTime)
    end
end

local function EventStartUi(Game)
    for competitor, competitorInfo in pairs(Game.Players) do
        RE_ZoneUiState:FireClient(competitorInfo.player, Game, "Out")
    end
end

local function CallOutUi(Game)
    for _, player in pairs(PlayerService:GetPlayers()) do
        local currentGame = StartingZoneModule:GetPlayerCurrentGame(player)
        if not currentGame then
            continue
        end
        local gameName = Game.DisplayName or Game.GameName
        if Game.Model.Allowed:FindFirstChild(player.UserId) or not string.match(currentGame.gameName, gameName)  then
            continue
        end
        RE_ZoneUiState:FireClient(player, Game, "Out")
    end
end

local function ShowStartPartToPlayer(GameData, Active)
    for _, player in pairs(PlayerService:GetPlayers()) do
        if GameData.Model.Allowed:FindFirstChild(player.UserId) then
            continue
        end
        RE_ActivateGame:FireClient(player, GameData, Active)
    end
end

function MinigamesEventLauncher:EventLaunch(Game)
	Game.isEventRunning = true
	Game.EventCurrentTime =  Game.EventTimeInSec
	task.spawn(function()
        ShowStartPartToPlayer(Game, true)
        StartingZoneModule:ShowLightRay(Game, 3)
		while Game.isEventRunning do
			Game.EventCurrentTime -= 1
			if Game.EventCurrentTime <= 0 then
                EventStartUi(Game)
                LaunchGame(Game)
				break
			end
            CallWaitingUi(Game)
            task.wait(1)
		end
        CallOutUi(Game)
        ShowStartPartToPlayer(Game, false)
	end)
end


function MinigamesEventLauncher:LaunchRandomMiniGame()
    local allGames = GetAllGames()
    if ToolsModule.LengthOfDic(allGames) <= 0 then
        return
    end
    local randomGame = GetRandomGame(allGames)
    MinigamesEventLauncher:EventLaunch(randomGame)
end


return MinigamesEventLauncher