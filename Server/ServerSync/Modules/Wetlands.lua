local RunService = game:GetService("RunService")
local Wetlands = {}

local WetlandsFolder = workspace:FindFirstChild("Wetlands") or Instance.new("Folder")
WetlandsFolder.Name = "Wetlands"
WetlandsFolder.Parent = workspace

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local HorseLoader = require("HorseLoader")
local SpatialUtils = require("SpatialUtils")
local ServerDropsHandler = require("ServerDropsHandler")
local PlayerDataModule = require("PlayerDataModule")

local Assets = ReplicatedStorage.SharedSync.Assets

--Config
local TestConfig = {
    JUMPS_NEEDED = 30,
    MAX_DROPS_PER_JUMP = 2,
    MAX_DROPS_ON_COMPLETE = 50,
    COOLDOWN = 0.2
}

local wetlandModel = Assets.WetlandBlock
local wetlandSpawnRange = 100
local waterHorseWetLandLifeTimeSec = 15

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

local function checkValidSpawningPosition(position, size, blacklist)
    local isValidPosition = true
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
    overlapParams.FilterDescendantsInstances = blacklist
    local overlappedParts = workspace:GetPartBoundsInRadius(position, size.Magnitude + 1, overlapParams)
    print("CHECKING valid pos")
    if #overlappedParts > 0 then
        isValidPosition = false
    end

    return isValidPosition
end

local function instanciateWetlandAtRandomPos()
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    raycastParams.FilterDescendantsInstances = {workspace.Terrain}

    local isValidPos = false
    local position

    while not isValidPos do
        local rayOrigin = Vector3.new(math.random(0-wetlandSpawnRange,0+wetlandSpawnRange),20,math.random(0-wetlandSpawnRange,0+wetlandSpawnRange))
        local raycastResult = workspace:Raycast(rayOrigin, Vector3.new(0,-1000,0), raycastParams)
        position = raycastResult.Position
        isValidPos = checkValidSpawningPosition(position, wetlandModel.Size, {workspace.Terrain; workspace.SpawnLocation})
        wait()
    end

    local spawned = wetlandModel:Clone()
    spawned.Parent = workspace.Wetlands
    spawned.Position = position
end

local ActivePoints = {}

local function dropReward(dropPosition)
    local Drops = Assets.Drops:GetChildren()
    for i=1, math.random(TestConfig.MAX_DROPS_ON_COMPLETE/2, TestConfig.MAX_DROPS_ON_COMPLETE) do
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
        wait(0.02)
    end
end

local ActiveConnections = {}
function Wetlands:Init()
    HorseLoader.PlayerMountedHorse:Connect(function(Player,CreatureData)
        local Connections = {}
        local Humanoid = CreatureData.Instance:FindFirstChild("Humanoid")
        local HorsePrimaryPart = CreatureData.Instance.PrimaryPart
        if not Humanoid or not HorsePrimaryPart then
            return
        end
        Connections.Jumping = Player.Character.Humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
            local TargetWetland
            local axisXZ = Vector3.new(1,0,1)
            for _, WetlandBlock in ipairs(WetlandsFolder:GetChildren()) do
                if SpatialUtils.IsPositionInPart(CreatureData.Instance.PrimaryPart.Position,WetlandBlock, axisXZ) then
                    TargetWetland = WetlandBlock
                end
            end
            if not TargetWetland then
                return
            end
            local TargetPoint
            local TargetPointIndex = 1
            for Index, PointData in pairs(ActivePoints) do
                if ((PointData.Instance.Position - HorsePrimaryPart.Position) * axisXZ).Magnitude < 5  then
                    TargetPoint = PointData
                    TargetPointIndex = Index
                end
            end
            if not TargetPoint then
                local HasActivePoint = false 
                for _,PointData in ipairs(ActivePoints) do
                    if PointData.Creator == Player then
                        HasActivePoint = true
                    end
                end
                if not HasActivePoint then
                    local NewPoint = {
                        LastJumpTime = {},
                        Creator = Player,
                        Contributors = {},
                        Instance = Assets.WetlandPoint:Clone()
                    }
                    NewPoint.LastJumpTime[Player] = tick();
                    NewPoint.Instance.Parent = workspace
                    NewPoint.Instance.CFrame = CFrame.new((HorsePrimaryPart.Position * Vector3.new(1,0,1)) + Vector3.new(0,TargetWetland.Position.Y,0))
                    table.insert(ActivePoints,NewPoint)
                    TargetPoint = NewPoint
                end
            elseif tick() >= TargetPoint.LastJumpTime[Player] + TestConfig.COOLDOWN then
                TargetPoint.LastJumpTime[Player] = tick()
                TargetPoint.Contributors[Player] = (TargetPoint.Contributors[Player] or 0) + 100/TestConfig.JUMPS_NEEDED
                local Drops = Assets.Drops:GetChildren()
                for i=1,math.random(TestConfig.MAX_DROPS_PER_JUMP) do
                    local rand = math.random(0,100)
                    local spawning = Drops[2].Name
                    if rand < 45 then
                        spawning = Drops[3].Name
                    elseif rand < 75 then
                        spawning = Drops[2].Name
                    else
                        spawning = Drops[1].Name
                    end
                    ServerDropsHandler:SpawnDrop(spawning,1,TargetPoint.Instance.Position,math.random(2) == 1 and "Ground" or "Air")
                end
                local TotalPercent = 0
                for Player,Amount in pairs(TargetPoint.Contributors) do
                    TotalPercent += Amount
                end
                TargetPoint.Instance.ProgressBar.Frame.Fill.Size = UDim2.fromScale(math.clamp(TotalPercent/100,0,1),1)
                if TotalPercent >= 100 then
                    delay(0, function()
                        dropReward(TargetPoint.Instance.Position)
                    end)
                    TargetPoint.Instance:Destroy()
                    local isRespawning = TargetWetland:GetAttribute("Respawn")
                    TargetWetland:Destroy()
                    if isRespawning then
                        instanciateWetlandAtRandomPos()
                    end
                    table.remove(ActivePoints,TargetPointIndex)
                end
            end
        end)
        ActiveConnections[CreatureData.Instance] = Connections

        --                                  WATERHORSES GENERATING TEMPORARY WETLANDS
        task.delay(0,function()
            while ActiveConnections[CreatureData.Instance] do
                if CreatureData.Instance:FindFirstChild("CreatureID") then
                    if PlayerDataModule:Get(Player, "CreaturesCollection."..CreatureData.Instance.CreatureID.Value).Race == "Water" then
                        local planeVelocity = Player.Character.PrimaryPart.Velocity * Vector3.new(1,0,1)
                        if planeVelocity.Magnitude > 3 then
                            local spawned = wetlandModel:Clone()
                            spawned.Parent = workspace.Wetlands
                            spawned:SetAttribute("Respawn", false)
                            local raycastParam = RaycastParams.new()
                            raycastParam.FilterType = Enum.RaycastFilterType.Whitelist
                            raycastParam.FilterDescendantsInstances = {workspace.Terrain}
                            local rayResult = workspace:Raycast(Player.Character.PrimaryPart.Position, Vector3.new(0,-50,0), raycastParam)
                            local right = Vector3.xAxis:Cross(rayResult.Normal)
                            spawned.CFrame = CFrame.fromMatrix(rayResult.Position, right, rayResult.Normal)
                            spawned.Size = Vector3.new(7,1.5,7)
                            task.delay(waterHorseWetLandLifeTimeSec, function()
                                spawned:Destroy()
                            end)
                        end
                    end
                end
                task.wait(2)
            end
        end)

    end)
    HorseLoader.PlayerDismountedHorse:Connect(function(Player,HorseData)
        if ActiveConnections[HorseData.Instance] then
            for _,Connection in pairs(ActiveConnections[HorseData.Instance]) do
                Connection:Disconnect()
            end
        end
        ActiveConnections[HorseData.Instance] = nil
    end)

    RunService.Heartbeat:Connect(function()
        for Index,PointData in ipairs(ActivePoints) do
            local lastJump = 0

            for _, jumpTime in pairs(PointData.LastJumpTime) do
                if jumpTime >= lastJump then
                    lastJump = jumpTime
                end
            end

            if tick() - lastJump > 5 then
                PointData.Instance:Destroy()
                table.remove(ActivePoints,Index)
            end 
        end
    end)
end

return Wetlands