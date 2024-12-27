local QuestsMod = {}
local playerService = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local PlayerDataModule = require("ReplicatedPlayerData")

--References

local Assets = ReplicatedStorage.SharedSync.Assets
local Player = playerService.LocalPlayer
local SearchHuntInZoneModule = require("SearchHuntInZone")

-- Events

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RE_QuestGenerate = RemoteEvent.Quest.QuestGenerate
local RE_QuestFailed = RemoteEvent.Quest.QuestFailed
local RF_QuestSetup = RemoteFunction.QuestSetup


local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.FilterDescendantsInstances = {workspace}
raycastParams.IgnoreWater = false

function QuestsMod.QuestSetup(QuestIndex)
    local Quests = PlayerDataModule.LocalData.Quests
    local quest = Quests[QuestIndex]
    if quest.QuestType["searchObjectInZone"] ~= nil then
        SearchHuntInZoneModule:searchHuntInZoneSetup(quest, QuestIndex)
    end
    return true
end

--Function to delete all object marked by quests in interactif object and quests folders object
function QuestsMod:DeleteInvalidQuestObjects(questIndex)
    local questObjects = workspace.Quests:GetChildren()
    local questInteractibleSceneryObjects = workspace.InteractibleScenery:GetChildren()
    local toDelete = {}

    for _, object in pairs(questObjects) do
        if object:GetAttribute(questIndex) == true then
            table.insert(toDelete, object)
        end
    end

    for _, object in pairs(questInteractibleSceneryObjects) do
        if object:GetAttribute("QuestIndex") == questIndex then
            table.insert(toDelete, object)
        end
    end

    for _, questObject in pairs(toDelete) do
        questObject:Destroy()
    end
end



function QuestsMod:ActivationPartQuest(ActivationPart)
    local QuestGiven = ActivationPart.QuestGiven.Value

    if not QuestGiven then
        return
    end

    local debounce = false
    local debounceTime = 1
    
    local QuestData = {
        ActivationType = {
            Touch = QuestGiven.ActivationType.Touch.Value,
            TouchEnded = QuestGiven.ActivationType.TouchEnded.Value,
            Clicked = QuestGiven.ActivationType.Clicked.Value
        };
        Title = QuestGiven.Title.Value;
        Description = QuestGiven.Description.Value;
        NumbOfQuestsGiven = QuestGiven.NumbOfQuestsGiven.Value;
        Requirements = {
            Type = QuestGiven.Requirements.Type.Value,
            Race = QuestGiven.Requirements.Race.Value,
        };
        QuestType = {
            SearchObjectInZone = {
                Enabled = QuestGiven.SearchObjectInZone.Value,
                ObjectSearched = QuestGiven.SearchObjectInZone.ObjectSearched.Value,
                ObjectColor = QuestGiven.SearchObjectInZone.ObjectColor.Value.Name,
                ZoneType = QuestGiven.SearchObjectInZone.ZoneType.Value,
                ZoneSize = QuestGiven.SearchObjectInZone.ZoneSize.Value,
                ZoneOrigin = {
                    X = nil,
                    Y = nil,
                    Z = nil,
                },
            }
        };
        Goal = QuestGiven.Goal.Value;
        EcusReward = QuestGiven.EcusReward.Value;
        FeezReward = QuestGiven.FeezReward.Value;
        SparksReward = QuestGiven.SparksReward.Value;
        DeleteQuests = QuestGiven.DeleteQuests.Value;
        TimeAllowedInMin = QuestGiven.TimeAllowedInMin.Value;
        TimeWarnRatio = QuestGiven.TimeWarnRatio.Value
    }

    if QuestGiven.SearchObjectInZone.ZoneOrigin.Value then
        QuestData.QuestType.SearchObjectInZone.ZoneOrigin = {
            X = QuestGiven.SearchObjectInZone.ZoneOrigin.Value.Position.X,
            Y = QuestGiven.SearchObjectInZone.ZoneOrigin.Value.Position.Y,
            Z = QuestGiven.SearchObjectInZone.ZoneOrigin.Value.Position.Z,
        }
    else
        QuestData.QuestType.SearchObjectInZone.ZoneOrigin = {
            X = ActivationPart.Position.X,
            Y = ActivationPart.Position.Y,
            Z = ActivationPart.Position.Z,
        }
    end

    -- Random Management :

    RandomQuestDataManagement(QuestData, QuestGiven)

    if not QuestData.ActivationType.Touch and not QuestData.ActivationType.Clicked and not QuestData.ActivationType.TouchEnded then
        QuestData.ActivationType.Touch = true
    end
    if QuestGiven.ActivationType:GetAttribute("Random") then
        local random = math.round(math.random(0,3))
        if random == 1 then
            QuestData.ActivationType.Touch = true
            QuestData.ActivationType.TouchEnded = false
            QuestData.ActivationType.Clicked = false
        elseif random == 2 then
            QuestData.ActivationType.TouchEnded = true
            QuestData.ActivationType.Touch = false
            QuestData.ActivationType.Clicked = false
        elseif random == 3 then
            QuestData.ActivationType.Clicked = true
            QuestData.ActivationType.Touch = false
            QuestData.ActivationType.TouchEnded = false
        end
    end

    -- Activation :
    if QuestData.ActivationType.Touch then
        ActivationPart.Touched:Connect(function(touchedPart)
            local horse = touchedPart:FindFirstAncestorWhichIsA("Model")
            local touchedPlayer = touchedPart:FindFirstAncestor(Player.Name)
            if touchedPlayer and touchedPlayer.Parent.Name == "CharacterFolder" and not debounce or horse and horse.Parent.Name == "CreaturesFolder" and touchedPart.Name == "ProximityDetection" and string.match(horse.Name, Player.Name) and not debounce then
                debounce = true
                task.delay(debounceTime, function()
                    debounce = false
                end)
                RE_QuestGenerate:FireServer(QuestData, true)
            end
        end)
    end
    if QuestData.ActivationType.TouchEnded then
        ActivationPart.TouchEnded:Connect(function(touchedPart)
            local horse = touchedPart:FindFirstAncestorWhichIsA("Model")
            local touchedPlayer = touchedPart:FindFirstAncestor(Player.Name)
            if touchedPlayer and touchedPlayer.Parent.Name == "CharacterFolder" and not debounce or horse and horse.Parent.Name == "CreaturesFolder" and touchedPart.Name == "ProximityDetection" and string.match(horse.Name, Player.Name) and not debounce then
                debounce = true
                task.delay(debounceTime, function()
                    debounce = false
                end)
                RE_QuestGenerate:FireServer(QuestData, true)
            end
        end)
    end
    if QuestData.ActivationType.Clicked then
        local clickDetector = Instance.new("ClickDetector", ActivationPart)
        clickDetector.MouseClick:Connect(function(playerWhoClicked)
            if playerWhoClicked.Name == Player.Name and not debounce then
                debounce = true
                task.delay(debounceTime, function()
                    debounce = false
                end)
                RE_QuestGenerate:FireServer(QuestData, true)
            end
        end)
    end
end


function QuestsMod:RespawnQuestSetup()
    local Quests = PlayerDataModule.LocalData.Quests
    print(Quests, "  :", PlayerDataModule.LocalData)
    workspace:WaitForChild("Terrain")
    for questIndex, quest in pairs(Quests) do
        if quest.Active then
            QuestsMod.QuestSetup(questIndex)
        end
    end
end

--Tool Functions

function RandomQuestDataManagement(QuestData, QuestGiven)
    if QuestData.NumbOfQuestsGiven == -1 then
        local randomRange = QuestGiven.NumbOfQuestsGiven:GetAttribute("RandomRange")
        QuestData.NumbOfQuestsGiven = {min = randomRange.Min, max = randomRange.Max}
    end
    if QuestData.QuestType.SearchObjectInZone.ZoneSize == -1 then
        local randomRange = QuestGiven.SearchObjectInZone.ZoneSize:GetAttribute("RandomRange")
        QuestData.QuestType.SearchObjectInZone.ZoneSize = {min = randomRange.Min, max = randomRange.Max}
    end
    if QuestGiven.SearchObjectInZone.ObjectColor:GetAttribute("Random") then
        QuestData.QuestType.SearchObjectInZone.ObjectColor = "Random"
    end
    if QuestData.Goal == -1 then
        local randomRange = QuestGiven.Goal:GetAttribute("RandomRange")
        QuestData.Goal = {min = randomRange.Min, max = randomRange.Max}
    end
    if QuestGiven.EcusReward:GetAttribute("Random") == true then
        local randomRange = QuestGiven.EcusReward:GetAttribute("RandomRange")
        QuestData.EcusReward = {min = randomRange.Min, max = randomRange.Max}
    elseif QuestGiven.EcusReward.Value == -1 then
        QuestData.EcusReward = {ratio = QuestGiven.EcusReward:GetAttribute("Ratio")}
    end
    if QuestGiven.FeezReward:GetAttribute("Random") == true then
        local randomRange = QuestGiven.FeezReward:GetAttribute("RandomRange")
        QuestData.FeezReward = {min = randomRange.Min, max = randomRange.Max}
    elseif QuestGiven.FeezReward.Value == -1 then
        QuestData.FeezReward = {ratio = QuestGiven.FeezReward:GetAttribute("Ratio")}
    end
    if QuestGiven.SparksReward:GetAttribute("Random") == true then
        local randomRange = QuestGiven.SparksReward:GetAttribute("RandomRange")
        QuestData.SparksReward = {min = randomRange.Min, max = randomRange.Max}
    elseif QuestGiven.SparksReward.Value == -1 then
        QuestData.SparksReward = {ratio = QuestGiven.SparksReward:GetAttribute("Ratio")}
    end
    if QuestGiven.TimeAllowedInMin:GetAttribute("Random") == true then
        local randomRange = QuestGiven.TimeAllowedInMin:GetAttribute("RandomRange")
        QuestData.TimeAllowedInMin = {min = randomRange.Min, max = randomRange.Max}
    elseif QuestGiven.TimeAllowedInMin.Value == -1 then
        QuestData.TimeAllowedInMin = {ratio = QuestGiven.TimeAllowedInMin:GetAttribute("Ratio")}
    end
end



for _, QuestGiver in pairs(workspace.QuestGivers:GetChildren()) do
    QuestsMod:ActivationPartQuest(QuestGiver)
end
task.delay(30,function()
    QuestsMod:RespawnQuestSetup()
end)
Player.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    --QuestsMod:RespawnQuestSetup()
end)

RF_QuestSetup.OnClientInvoke = function(QuestIndex)
    QuestsMod.QuestSetup(QuestIndex)
    
end

RE_QuestFailed.OnClientEvent:Connect(function(questIndex)
    QuestsMod.DeleteInvalidQuestObjects(nil,questIndex)
end)

return QuestsMod
