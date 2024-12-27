local MapsClubsManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local HTTPService = game:GetService("HttpService")

--Require Module
local PlayerDataModule = require("PlayerDataModule")
local ClubsDataModule = require("ClubsDataModule")
local MapsManagerModule = require("MapsManagerModule")
local EnvironmentModule = require("EnvironmentModule")

local ClubName
local FirstPlayer

--When server side load, check if server is a Club Maps or not
if game.PlaceId ~= EnvironmentModule.GetPlaceId("ClubMap") then
    return MapsClubsManager
end

local function playerAdded(player)
    if not FirstPlayer then
        FirstPlayer = player
        MapsClubsManager:Init()
    end
end

function MapsClubsManager:Init()
    --if it's a Club Maps loaded, we need to check what club and what data need to load
    if FirstPlayer then
        ClubName = PlayerDataModule:Get(FirstPlayer, "Club")
        print("TEST CLUB NAME LOADED MAPS CLUB", ClubName)
        if ClubName then
            local ClubData = ClubsDataModule.GetDataClub(ClubName)
            MapsManagerModule.SetDataClubMap(ClubData)
            MapsManagerModule.LoadMap(EnvironmentModule.GetPlaceId("ClubMap"), tostring(EnvironmentModule.GetPlaceId("ClubMap")), "ClubMaps", HTTPService:JSONDecode(ClubData.MapsDataPositionning))
        end
    else
        warn("MAPS CLUB MANAGER - NOT FOUND FIRST PLAYER")
    end
end

local function SaveMapsClubData()
    local newMapClubData = MapsManagerModule.DatastorePositionning(EnvironmentModule.GetPlaceId("ClubMap"), true, true, tostring(EnvironmentModule.GetPlaceId("ClubMap")), "ClubMaps", true)
    ClubsDataModule.SetMapDataClub(ClubName, newMapClubData)
    ClubsDataModule.saveClub(ClubName)
end

game.Players.PlayerAdded:Connect(function(player)
    playerAdded(player)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
    playerAdded(player)
end

--when server go to close save maps data club
game:BindToClose(function()
	SaveMapsClubData()
	task.wait(2)
end)

return MapsClubsManager