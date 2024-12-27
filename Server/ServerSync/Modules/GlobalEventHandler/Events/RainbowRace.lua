local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

local TweenService = game:GetService("TweenService")
local RainbowRace = {}

--Don"t setup race function if its competition parade server
if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
	return RainbowRace
end

local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets")
local RainbowSpawns = workspace:WaitForChild("RainbowSpawns"):GetChildren()
local LastSpawns = nil

local HorseLoader = require("HorseLoader")
local ServerDropsHandler = require("ServerDropsHandler")
local ToolsModule = require("ToolsModule")
local PlayerDataModule = require("PlayerDataModule")

local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_RaceUiState = RemoteEventFolder:WaitForChild("RaceUiState")
local BF_Horsemount = ReplicatedStorage.SharedSync.HorseEvents:WaitForChild("HorseMountBindableFunction")

local radius = 1000
local maxDropsOnComplete = 100
local dropHeight = Vector3.new(0,10,0)

local CurrentRainbow = nil
local CurrentRainbowPlayersFinished = {}

local function dropReward(dropPosition)
    local Drops = Assets.Drops:GetChildren()
    for i=1, math.random(maxDropsOnComplete/2, maxDropsOnComplete) do
        local rand = math.random(0,100)
        local spawning
        if rand < 45 then
            spawning = Drops[3].Name
        elseif rand < 75 then
            spawning = Drops[2].Name
        else
            spawning = Drops[1].Name
        end
        ServerDropsHandler:SpawnDrop(spawning,1, dropPosition,"Ground")
        task.wait(0.02)
    end
end

local function SetPlayerDataClassement(isPlayer, player, classement, playerModel)
    local playerValue
    if isPlayer then
        if classement:FindFirstChild(tostring(player)) then
            return
        end
        playerValue = Instance.new("ObjectValue", classement)
        playerValue.Value = player
        playerValue.Name = player.Name
    end
    local Horse = Instance.new("ObjectValue", playerValue)
    local horses = BF_Horsemount:Invoke(player, "GetHorses")

    local creaturePlayer
    for _, v in pairs(horses) do
        if v.Instance.Name == "Creature_"..player.Name then
            creaturePlayer = v
        end
    end

    Horse.Value = creaturePlayer.Instance
    Horse.Name = "Horse"

    local CurrentPlacement = Instance.new("IntValue", playerValue)
    CurrentPlacement.Value = CurrentRainbowPlayersFinished[playerModel]
    CurrentPlacement.Name = "CurrentPlacement"

    local CreatureRace = Instance.new("StringValue", playerValue)
    local creatureID = creaturePlayer.Instance.CreatureID.Value
    CreatureRace.Value = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID..".Race")
    CreatureRace.Name = "HorseType"
end

local function lightRaySpawn(position)
    local lightRay = Assets.LightRay:Clone()
    lightRay.Transparency = 1
    lightRay.Position = position + Vector3.new(0,1700,0)
    lightRay.Size *= Vector3.new(0,1,1)
    lightRay.Parent = workspace


    local tweenInfo = TweenInfo.new(3,Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0)
    local goal = {}
    goal.Transparency = 0
    goal.Size = Vector3.new(1795.4, 30, 30)
    goal.Position = lightRay.Position - Vector3.new(0,897,0)
    local endGoal = {}
    endGoal.Transparency = 1
    local tween = TweenService:Create(lightRay, tweenInfo, goal)
    tween.Completed:Connect(function(playbackState)
        local endTween = TweenService:Create(lightRay, tweenInfo, endGoal)
        endTween:Play()
        endTween.Completed:Connect(function(playbackState)
            lightRay:Destroy()
        end)
    end)
    tween:Play()
end

local function dispawnLastRainbow()
    if CurrentRainbow then
        for i=1,100 do
            CurrentRainbow.Transparency = i/100
            task.wait()
        end
    end
    if CurrentRainbow then
        CurrentRainbow:Destroy()
        CurrentRainbowPlayersFinished = {}
    end
end

local function instantiateNewRainbow(CFramePosition)
    local NewRainbow = Assets.Rainbow:Clone()
    NewRainbow.CanCollide = false
    NewRainbow.Anchored = true
    NewRainbow.Parent = workspace
    NewRainbow.CFrame = CFramePosition
    NewRainbow.Transparency = 1
    local classement = Instance.new("Folder", NewRainbow)
    classement.Name = "classement"
    lightRaySpawn(CFramePosition.Position)
    for i=1,100 do
        NewRainbow.Transparency = 1-(i/100)
        task.wait()
    end
    CurrentRainbow = NewRainbow
end

local function setupIAToRainbow()
    local NearbyHorses = {}
    for _,CreatureData in pairs(HorseLoader.ActiveCreatures) do
        if CreatureData.MovementAI and CreatureData.PrimaryPart.Parent and (CreatureData.PrimaryPart.Position - CurrentRainbow.Position).Magnitude < 1500 then
            table.insert(NearbyHorses,CreatureData)
            local XSize = math.floor(CurrentRainbow.Size.X/2)
            local ZSize = math.floor(CurrentRainbow.Size.Z/2)
            local pos = (CurrentRainbow.CFrame * CFrame.new(math.random(-XSize,XSize),0,math.random(-ZSize,ZSize))).Position
            CreatureData.MovementAI:SetTarget(pos)
        end
    end
end

local function SetupTouchToFinish()
    CurrentRainbow.Touched:Connect(function(otherPart)
        local playerModel = otherPart:FindFirstAncestorWhichIsA("Model")
        if not playerModel then
            return
        end
        local isPlayer = playerModel.Parent == workspace.CharacterFolder
        if not isPlayer or ToolsModule.LengthOfDic(CurrentRainbowPlayersFinished) > 3 then
            return
        end
        if CurrentRainbowPlayersFinished[playerModel] ~= nil then
            return
        end
        CurrentRainbowPlayersFinished[playerModel] = ToolsModule.LengthOfDic(CurrentRainbowPlayersFinished) + 1
        local player = Players:GetPlayerFromCharacter(playerModel)
        SetPlayerDataClassement(isPlayer, player, CurrentRainbow.classement, playerModel)
        RE_RaceUiState:FireClient(player, CurrentRainbow, "RaceRainbowFinish")
    end)
end

local function SpawnRainbow(CFramePosition)
    if CFramePosition then
        dispawnLastRainbow()
        instantiateNewRainbow(CFramePosition)
        --setupIAToRainbow()
        SetupTouchToFinish()
    else
        warn("Infinite race has no result")
    end
end

RE_RaceUiState.OnServerEvent:Connect(function(player, reason)
    if reason == "Rainbow" then
        local dropPos = player.Character.PrimaryPart.Position + dropHeight
        dropReward(dropPos)
    end
end)

local NEEDED_PLAYERS = 1
local RADIUS = 30

function RainbowRace.CanStart()
    local MaxGrouping = 0
    for _,RootPlayer in pairs(Players:GetPlayers()) do
        if RootPlayer.Character and RootPlayer.Character.PrimaryPart then
            local CurrentGrouping = 0
            for _,TargetPlayer in pairs(Players:GetPlayers()) do
                if TargetPlayer.Character and TargetPlayer.Character.PrimaryPart then
                    if (RootPlayer.Character.PrimaryPart.Position - TargetPlayer.Character.PrimaryPart.Position).Magnitude < RADIUS then
                        CurrentGrouping += 1
                    end
                end
            end
            if CurrentGrouping > MaxGrouping then
                MaxGrouping = CurrentGrouping
            end
        end
    end
    if MaxGrouping >= NEEDED_PLAYERS and #RainbowSpawns > 0 then
        return true
    else
        return false
    end
end

local function checkValidSpawningPosition(position, size, blacklist)
    local isValidPosition = true
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
    overlapParams.FilterDescendantsInstances = blacklist
    local overlappedParts = workspace:GetPartBoundsInRadius(position, size.Magnitude + 1, overlapParams)
    if #overlappedParts > 0 then
        isValidPosition = false
    end

    return isValidPosition
end

function RainbowRace:Start()
    if self.CanStart() == true then
        --[[ local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.IgnoreWater = false
        local position
        local validPosition = false
        while validPosition == false do
            local rayOrigin = Vector3.new(math.random(-radius,radius),30,math.random(-radius,radius))
            local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0,-1000,0), raycastParams)
            if raycastResult and raycastResult.Material ~= Enum.Material.Water and raycastResult.Material ~= Enum.Material.CrackedLava then
                position = raycastResult.Position + Assets.Rainbow.Size * Vector3.new(0,0.5,0)
                validPosition = checkValidSpawningPosition(position, Assets.Rainbow.Size, {workspace.Terrain})
            end
            task.wait()
        end

        SpawnRainbow(CFrame.new(position)) ]]

        --Replace random placement with raycast because new map are so random complicated place to spawn random rainbow properly with environnement
        local newSpawn = nil
        repeat
            newSpawn = RainbowSpawns[math.random(1,#RainbowSpawns)].CFrame
            task.wait()
        until newSpawn ~= LastSpawns
        LastSpawns = newSpawn
        SpawnRainbow(newSpawn)
    end
end

function RainbowRace:Blink()
    if CurrentRainbow then
        local transVal = 0.85
        for i=1, 2 do
            CurrentRainbow.Transparency = transVal
            task.wait(1)
            CurrentRainbow.Transparency = 0
            task.wait(1)
        end
        for i=1, 3 do
            CurrentRainbow.Transparency = transVal
            task.wait(0.15)
            CurrentRainbow.Transparency = 0
            task.wait(0.15)
        end
    end
end

return RainbowRace