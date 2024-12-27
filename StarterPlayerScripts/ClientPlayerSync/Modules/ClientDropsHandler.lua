local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientDropsHandler = {}
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local UtilFunctions = require("UtilFunctions")
local GetRemoteEvent = require("GetRemoteEvent")
local GetRemoteFunction = require("GetRemoteFunction")
local DropEvent = GetRemoteEvent("DropEvent")
local DropFunction = GetRemoteFunction("DropFunction")
local DropAssets = ReplicatedStorage.SharedSync.Assets.Drops

local DropsFolder = Instance.new("Folder")
DropsFolder.Name = "_DROPSFOLDER"
DropsFolder.Parent = workspace
local DropsCache = {}

local DropRayParams = RaycastParams.new()
DropRayParams.FilterDescendantsInstances = {workspace:WaitForChild("CreaturesFolder",2),workspace:WaitForChild("CharacterFolder",2),DropsFolder}

local function RemoveDrop(Data)
    Data = type(Data) == "table" and Data or {Data}
    if Data.Busy ~= true then
        Data.Busy = true
        for _,DropId in pairs(Data) do
            if DropsCache[DropId] then
                for i=1,60 do
                    if DropsCache[DropId] then
                        for _,Part in pairs(DropsCache[DropId].Instance:GetDescendants()) do
                            if Part:IsA("BasePart") then
                                Part.Transparency += (1/60)
                            end
                        end
                        task.wait()
                    else
                        return
                    end
                end
                DropsCache[DropId].Instance:Destroy()
                DropsCache[DropId] = nil
                break
            end
        end
        Data.Busy = false
    end
end

local function FallDrop(ID)
    local Data = DropsCache[ID] or {}
    if Data.Busy == false then
        Data.Busy = true
        local RayOriginCFrame = Data.Instance.PrimaryPart.CFrame
        local RayResult = workspace:Raycast(RayOriginCFrame.Position,Vector3.new(0,-1000,0),DropRayParams)
        local EndPosition
        if RayResult then
            EndPosition = RayResult.Position
            local t = 0
            local currentDelta = RunService.Heartbeat:Wait()
            local StartCFrame = Data.Instance.PrimaryPart.CFrame
            while t < 1 do
                if Data.Instance.Parent then
                    t += 0.02 * (currentDelta/(1/60))
                    Data.Instance:PivotTo(StartCFrame:Lerp(CFrame.new(EndPosition),TweenService:GetValue(t,Enum.EasingStyle.Quint,Enum.EasingDirection.In)))
                    currentDelta = RunService.Heartbeat:Wait()
                else
                    break
                end
            end
            Data.Type = "Ground"
        end
        Data.Busy = false
    end
end

local function PickUpDrop(ID)
    local DropData = DropsCache[ID] or {}
    if DropData.Busy == false then
        DropData.Busy = true
        --task.spawn(function()
        local PickedUp = DropFunction:InvokeServer(ID)
        if PickedUp == true then
            if DropData.Instance.PrimaryPart then
                local t = 0
                local currentDelta = RunService.Heartbeat:Wait()
                if DropData.Instance.PrimaryPart then
                    local StartCFrame = DropData.Instance.PrimaryPart.CFrame
                    while t < 1 do
                        if DropData.Instance.Parent and Player.Character and Player.Character.PrimaryPart then
                            t += 0.035 * (currentDelta/(1/60))
                            DropData.Instance:PivotTo(StartCFrame:Lerp(Player.Character.PrimaryPart.CFrame,TweenService:GetValue(t,Enum.EasingStyle.Quint,Enum.EasingDirection.In)))
                            currentDelta = RunService.Heartbeat:Wait()
                        else
                            break
                        end
                    end
                end
                DropData.Busy = false
                RemoveDrop(ID)
            end
        else
            warn("Server said nah")
            DropData.Busy = false
        end
        --end)
    end
end

local function MakeDrop(Id,Data, isRetrieved)
    Data.Instance = DropAssets[Data.Name]:Clone()
    Data.Instance:PivotTo(CFrame.new(Data.OriginPosition))
    Data.Instance.Parent = DropsFolder
    local EndPosition 
    if Data.Type == "Air" then
        EndPosition = (CFrame.new(Data.OriginPosition + Vector3.new(0,Data.Params.Height,0)) * CFrame.Angles(0,math.rad(math.random(360)),0) * CFrame.new(0,0,math.random(0,6))).Position
    else -- Ground is default
        local RayOriginCFrame = CFrame.new(Data.OriginPosition) * CFrame.Angles(0,math.rad(math.random(360)),0) * CFrame.new(0,5,math.random(5,8))
        local RayResult = workspace:Raycast(RayOriginCFrame.Position,Vector3.new(0,-30,0),DropRayParams)
        if RayResult then
            EndPosition = RayResult.Position + Vector3.new(0,1,0)
        else
            EndPosition = Data.OriginPosition
        end
    end 
    local t = 0
    local currentDelta = RunService.Heartbeat:Wait()
    
    while t < 1 do
        t += 0.025 * (currentDelta/(1/60))
        local End = UtilFunctions.QuadBezier(t,Data.OriginPosition,UtilFunctions.Lerp(Data.OriginPosition,EndPosition,0.5)+Vector3.new(0,16,0),EndPosition)
        Data.Instance:PivotTo(CFrame.new(End))
        currentDelta = RunService.Heartbeat:Wait()
        if not Data.Instance.Parent then
            break
        end
    end
    Data.LastOffset = CFrame.new()
    Data.EndPosition = EndPosition
    Data.SpawnTick = tick()
    Data.Busy = false
    DropsCache[Id] = Data
    if isRetrieved then
        PickUpDrop(Id)
    end
end

function ClientDropsHandler:Init()
    DropEvent.OnClientEvent:Connect(function(Reason,Id,Data, isRetrieved)
        if Reason == "Add" then
            MakeDrop(Id,Data, isRetrieved)
        elseif Reason == "Remove" then
            RemoveDrop(Id)
        end
    end)
    RunService.Heartbeat:Connect(function(Delta)
        --print(DropsCache)
        if not Player.Character or not Player.Character.PrimaryPart then
            return
        end
        for ID,DropData in pairs(DropsCache) do
            if not DropData.Instance or not DropData.Instance.PrimaryPart then
                continue
            end
            if DropData.Type == "Air" then
                local Offset = CFrame.new(0,0,0)--CFrame.new(0,math.sin(tick() - DropData.SpawnTick),0)
                DropData.Instance:PivotTo(DropData.Instance.PrimaryPart.CFrame * CFrame.new(0,DropData.Params.ClimbRate * (Delta/(1/60)),0) * DropData.LastOffset:Inverse() * Offset )
                DropData.LastOffset = Offset
                if DropData.Params.FallAfter > 0 and tick() - DropData.SpawnTick > DropData.Params.FallAfter then
                    FallDrop(ID)
                end
            end
            if (DropData.Instance.PrimaryPart.Position - Player.Character.PrimaryPart.Position).Magnitude < 14 then
                PickUpDrop(ID)
            end
        end
    end)
end


return ClientDropsHandler