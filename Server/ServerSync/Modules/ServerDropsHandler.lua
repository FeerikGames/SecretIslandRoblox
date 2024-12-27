local ServerDropsHandler = {}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local DropEvent = GetRemoteEvent("DropEvent")
local RE_SpawnDrop = ReplicatedStorage.SharedSync.RemoteEvent.SpawnDrop
local DropFunction = GetRemoteFunction("DropFunction")
local DropAssets = ReplicatedStorage.SharedSync.Assets.Drops
local PlayerDataModule = require("PlayerDataModule")

--Config
local TestConfig = {
    AIR_DROP_FALL_CHANCE = 25,
    DROP_LIFETIME = 30,
    BASE_CLIMB_RATE = 0.1,
} 

local ConfigFolder = Instance.new("Folder")
ConfigFolder.Name = script.Name.."Config"
ConfigFolder.Parent = workspace
for Name,Value in pairs(TestConfig) do
    local ValueObject = Instance.new("NumberValue",ConfigFolder)
    ValueObject.Name = Name
    ValueObject.Value = Value
    ValueObject.Changed:Connect(function()
        TestConfig[Name] = ValueObject.Value
    end)
end
--
local DropsCache = {}
local CurrentDropID = 0

local function RemoveDropFromID(ID)
    if DropsCache[ID] then
        if DropsCache[ID].Player then
            --DropEvent:FireClient(PlayerTarget,"Remove",RemoveTable) -- TODO: Re-enable
        else
            ---DropEvent:FireAllClients("Remove",RemoveTable)
            for _,Player in pairs(Players:GetPlayers()) do
                if Player ~= DropsCache[ID].Player then
                    DropEvent:FireClient(Player,"Remove",ID)
                end
            end
        end
        DropsCache[ID] = nil
    end
end

function ServerDropsHandler:Init()
    Players.PlayerRemoving:Connect(function(Player)
        self:RemoveDropsForPlayer(Player)
    end)
    
    DropFunction.OnServerInvoke = function(Player,DropId)
        if DropId then
            if DropsCache[DropId] then
                --Award Player from FoundDrop.Value and FoundDrop.Name
                PlayerDataModule:Increment(Player, 1, DropsCache[DropId].Name)
                if DropsCache[DropId].Player then
                    return true
                else
                    for _,FocusPlayer in pairs(Players:GetPlayers()) do
                        if Player ~= FocusPlayer then
                            DropEvent:FireClient(FocusPlayer,"Remove",DropId)
                        end
                    end
                    return true
                end
            else
                warn("Didnt find drop",DropId,DropsCache)
            end
        end
    end

    RunService.Heartbeat:Connect(function()
        for ID,DropData in pairs(DropsCache) do
            if tick() - DropData.SpawnTick > DropData.Lifetime then
                RemoveDropFromID(ID)
            end
        end
    end)
end

function ServerDropsHandler:SpawnDrop(DropName : string, Value, OriginPosition, DropType, PlayerTarget, isRetrieved)
    if DropAssets:FindFirstChild(DropName) then
        CurrentDropID += 1
        if CurrentDropID >= 10^10 then
            CurrentDropID = 0
        end
        RemoveDropFromID(CurrentDropID)
        local Params = {}
        if DropType == "Air" then
            Params.FallAfter = math.random(10,20)
            Params.Height = 25
            Params.ClimbRate = TestConfig.BASE_CLIMB_RATE
        end
        local NewDrop = {
            Player = PlayerTarget,
            Name = DropName,
            Value = Value,
            OriginPosition = OriginPosition,
            Type = DropType or "Ground",
            Lifetime = TestConfig.DROP_LIFETIME,
            SpawnTick = tick(),
            Params = Params
        }
        local NewId = "ID"..CurrentDropID
        DropsCache[NewId] = NewDrop
        if PlayerTarget then
            DropEvent:FireClient(PlayerTarget, "Add", NewId, NewDrop, isRetrieved)
        else
            DropEvent:FireAllClients("Add",NewId,NewDrop)
        end
    else
        warn("Invalid drop name",DropName)
    end
end


function ServerDropsHandler:RemoveDropsForPlayer(Player)
    local RemoveTable = {}
    for ID,DropData in pairs(DropsCache) do
        if DropData.Player == Player then
            RemoveTable[ID] = DropData.ID
            DropsCache[ID] = nil
        end
    end
    if #RemoveTable > 0 then
        DropEvent:FireClient(Player,"Remove",RemoveTable)
    end
end

RE_SpawnDrop.OnServerEvent:Connect(function(player, DropName,Value,OriginPosition,DropType,PlayerTarget)
    ServerDropsHandler:SpawnDrop(DropName,Value,OriginPosition,DropType,PlayerTarget)
end)

return ServerDropsHandler