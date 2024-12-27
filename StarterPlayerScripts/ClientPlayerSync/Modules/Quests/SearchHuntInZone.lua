local SearchInZone = {}
local playerService = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local PlayerDataModule = require("ReplicatedPlayerData")
local ToolsModule = require("ToolsModule")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local HorseEvent = ReplicatedStorage.SharedSync.HorseEvents
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

local Assets = ReplicatedStorage.SharedSync.Assets
local Player = playerService.LocalPlayer

-- Events

local RE_QuestProgress = RemoteEvent.Quest.QuestProgress
local RE_HorseMountEvent = HorseEvent.HorseMountEvent
local RE_CreatureWasEvolved = RemoteEvent.CreatureEvolution.CreatureWasEvolved

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.FilterDescendantsInstances = {workspace}
raycastParams.IgnoreWater = false

local waterRaycastParams = RaycastParams.new()
waterRaycastParams.FilterType = Enum.RaycastFilterType.Whitelist
waterRaycastParams.FilterDescendantsInstances = {workspace}
waterRaycastParams.IgnoreWater = true

local currentHorseType
local currentHorseRace


function SearchInZone:QuestTypeSearchHuntInZone(Model:Instance, color:Color3, howMany:number, origin:Vector3, radius:number, questIndex:string, ZoneType, TypeRequirement:string, RaceRequirement:string)
    for i = 1, howMany, 1 do
        local objectToSpawn = Model
        if typeof(Model) == "table" then
            objectToSpawn = Model[math.random(1,#Model)]
        end
        --Calculate position
        local validPosition = false
        local position
        local size
        if objectToSpawn:IsA("Model") then
            size = objectToSpawn.PrimaryPart.Size
        else
            size = objectToSpawn.Size
        end
        local tryCount = 0
        while validPosition == false do
            tryCount += 1
            if tryCount > 50 then
                warn("Couldn't find proper place in zone for object to be spawned. zone Type : ", ZoneType)
                return
            end
            local rayOrigin = Vector3.new(math.random(origin.X-radius,origin.X+radius),5000,math.random(origin.Z-radius,origin.Z+radius))
            local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0,-10000,0), raycastParams)
            if raycastResult then
                if ZoneType ~= Enum.Material.Ground and ZoneType ~= nil then
                    if raycastResult.Material ~= ZoneType then
                        continue
                    end
                end
                if ZoneType == nil or ZoneType == Enum.Material.Ground then
                    if raycastResult.Material == Enum.Material.CrackedLava or raycastResult.Material == Enum.Material.Water then
                        continue
                    end
                end
                position = raycastResult.Position
                if ZoneType == Enum.Material.Water then
                    local waterRayOrigin = raycastResult.Position
                    local waterRaycastResult = workspace:Raycast(waterRayOrigin, Vector3.new(0,-1000,0), waterRaycastParams)
                    position = waterRaycastResult.Position
                end
                validPosition = checkValidSpawningPosition(position, size, {workspace.Terrain})
            end
            task.wait()
        end



        --Spawning
        local spawned = objectToSpawn:Clone()
        spawned.Name = objectToSpawn.Name .. "Clone " .. i
        spawned.Parent = workspace.Quests
        spawned:SetAttribute(questIndex, true)
        local boulder = nil
        if ZoneType == Enum.Material.Ground then
            boulder = SpawnGroundRocks(questIndex, spawned, position)
        end
        local Detection
        spawned:SetAttribute("TypeRequirement", TypeRequirement)
        spawned:SetAttribute("RaceRequirement", RaceRequirement)
        if spawned:IsA("Model") then
            spawned:PivotTo(CFrame.new(position + Vector3.new(0,spawned.PrimaryPart.Size.Y/2,0)) * CFrame.Angles(0,math.rad(math.random(0,360)),0))
            Detection = spawned.PrimaryPart.Detection
            if color then
                spawned.PrimaryPart.Color = color
                spawned.PrimaryPart.TextureID = ""
            end
        end
        Detection.Touched:Connect(function(objTouched)
            local modelTouched = objTouched:FindFirstAncestorWhichIsA("Model")
            if modelTouched then
                local playerTouched = playerService:GetPlayerFromCharacter(modelTouched)
                if playerTouched then
                    PlayerCollectObject(playerTouched, questIndex, TypeRequirement, RaceRequirement, spawned, boulder)
                end
            end
        end)
        Detection.TouchEnded:Connect(function(Touched)
            local modelTouched = Touched:FindFirstAncestorWhichIsA("Model")
            if modelTouched then
                local playerTouched = playerService:GetPlayerFromCharacter(modelTouched)
                if playerTouched and playerTouched == Player then
                    spawned.PrimaryPart.InfoUi.Enabled = false
                end
            end
        end)
    end
end

function SearchInZone:searchHuntInZoneSetup(quest, QuestIndex)
    local model
    if quest.QuestType.searchObjectInZone.Object == "All" then
        model = ReplicatedStorage.SharedSync.Assets.Quests.SearchObject:GetChildren()
    else
        model = ReplicatedStorage.SharedSync.Assets.Quests.SearchObject:WaitForChild(quest.QuestType.searchObjectInZone.Object)
    end
    local numberToSpawn = quest.Goal - quest.Progress
    local originpoint = Vector3.new(quest.QuestType.searchObjectInZone.ZoneOrigin.X,quest.QuestType.searchObjectInZone.ZoneOrigin.Y,quest.QuestType.searchObjectInZone.ZoneOrigin.Z)
    local TypeRequirements = quest.QuestRequirements.CreatureType
    local RaceRequirements = quest.QuestRequirements.CreatureRace
    local ZoneType = convertZoneType(quest.QuestType.searchObjectInZone.ZoneType)
    local colortable
    if quest.QuestType.searchObjectInZone.Color then
        colortable = BrickColor.new(quest.QuestType.searchObjectInZone.Color)
    end
    local color = nil
    if colortable then
        color = Color3.new(colortable.r, colortable.g, colortable.b)
    end
    SearchInZone:QuestTypeSearchHuntInZone(model, color, numberToSpawn, originpoint, quest.QuestType.searchObjectInZone.ZoneSize, QuestIndex, ZoneType, TypeRequirements, RaceRequirements)
    CheckQuestRequirementsForObjects()
end

--TOOL FUNCTIONS

function PlayerCollectObject(playerInteract, questIndex, TypeRequirement, RaceRequirement, spawned, boulder)
    local typeReq = currentHorseType ~= TypeRequirement
    local raceReq = currentHorseRace ~= RaceRequirement
    if TypeRequirement == "Any" then
        typeReq = false
    end
    if RaceRequirement == "Any" then
        raceReq = false
    end
    if typeReq or raceReq then
        spawned.PrimaryPart.InfoUi.Enabled = true
        return
    end
    if playerInteract == Player then
        if spawned:IsA("Model") then
            for _, child in pairs(spawned:GetChildren()) do
                if child:IsA("BasePart") then
                    spawned.PrimaryPart.Detection.CanTouch = false
                    task.spawn(function()
                        ToolsModule.PlayCollectObject(Player, child)
                        spawned:Destroy()
                    end)
                end
            end
        else
            ToolsModule.PlayCollectObject(Player, spawned)
            spawned:Destroy()
        end

        RE_QuestProgress:FireServer(questIndex, 1)
        if boulder then
            boulder:Destroy()
        end
    end
end

function SpawnGroundRocks(questIndex, objectHiding, position)
    local boulderModel = Assets.Quests.BoulderHide
    local boulderSpawned = boulderModel:Clone()
    boulderSpawned.Parent = workspace.InteractibleScenery
    boulderSpawned:PivotTo(CFrame.new(position))
    boulderSpawned:SetAttribute("QuestIndex", questIndex) --adding a attribute of quest index reference for found and delete object if not success quest
    return boulderSpawned
end

function checkValidSpawningPosition(position, size, blacklist)
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

function convertZoneType(zoneType)
    if zoneType == "CrackedLava" then
        return Enum.Material.CrackedLava
    elseif zoneType == "Water" then
        return Enum.Material.Water
    elseif zoneType == "Ground" then
        return Enum.Material.Ground
    end
end

function CheckQuestRequirementsForObjects()
    for _, questObj in pairs(workspace.Quests:GetChildren()) do
        local typeNeeded = questObj:GetAttribute("TypeRequirement")
        local raceNeeded = questObj:GetAttribute("RaceRequirement")
        if typeNeeded == "Any" and raceNeeded == "Any" or not questObj or not raceNeeded then
            return
        end
        local text = "Need a " .. raceNeeded .. " " .. typeNeeded
        local InfoUi = questObj:IsA("Model") and questObj.PrimaryPart.InfoUi or questObj.InfoUi
        InfoUi.Frame.Requirement.Text = text
    end
end


RE_HorseMountEvent.OnClientEvent:Connect(function(Horse)
    if Horse then
        local CreatureId = Horse.Instance.CreatureID.Value
        currentHorseType = Horse.CreatureType
        currentHorseRace = PlayerDataModule.LocalData.CreaturesCollection[CreatureId].Race
    else
        currentHorseType = nil
        currentHorseRace = nil
    end
    CheckQuestRequirementsForObjects()
end)

RE_CreatureWasEvolved.OnClientEvent:Connect(function(creatureID)
    local creatureCollection = PlayerDataModule.LocalData.CreaturesCollection
    currentHorseType = creatureCollection[creatureID].CreatureType
    currentHorseRace = creatureCollection[creatureID].Race
end)

return SearchInZone