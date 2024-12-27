local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementAI = {}
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Maid = require("Maid")
local HorsePathfinding = require("HorsePathfinding")

local Modes = {
    IdleWalk = function(HorseData)
        local AI = HorseData.MovementAI
        --print("Do idel")
        local _Maid = Maid.new()
        HorseData.Animator:SetMovementAnimation("Walk") 
        local StartPosition = HorseData.Instance.PrimaryPart.Position
        local LastIterationTick = 0
        _Maid["MainRunner"] = RunService.Heartbeat:Connect(function(deltaTime)
            if (tick() - LastIterationTick) > 1 then
                LastIterationTick = tick()
                --
                if math.random(3) == 1 then
                    local Direction = CFrame.lookAt(StartPosition,(CFrame.new(StartPosition) * CFrame.Angles(0,math.rad(math.random(360)),0) * CFrame.new(0,0,-5)).Position)
                    local Distance = math.random(5,20)
                    local RaycastResult = workspace:Raycast(StartPosition,Direction.LookVector * Distance)
                    if not RaycastResult then
                        AI:SetTarget((Direction * CFrame.new(0,0,-Distance)).Position,nil,10)
                    end
                end
                --
            end
        end)
        _Maid["OnTerminate"] = function()
            HorseData.Animator:SetMovementAnimation("Gallop") 
        end
        return _Maid
    end
}

function MovementAI:Make(HorseData)
    if HorseData.MovementAI then
        HorseData.MovementAI:Terminate()
    end

    local Humanoid = HorseData.Humanoid
    local Horse = HorseData.Instance

    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "Swim"
    BodyVelocity.Parent = Horse.PrimaryPart
    BodyVelocity.MaxForce = Vector3.new()
    BodyVelocity.P = 200
    BodyVelocity.Velocity = Vector3.new(0,12,0)

    local AngularVelocity = Instance.new("BodyAngularVelocity")
    AngularVelocity.Name = "Turn"
    AngularVelocity.Parent = Horse.PrimaryPart
    AngularVelocity.MaxTorque = Vector3.new(0,math.huge,0)
    AngularVelocity.P = 1000
    AngularVelocity.AngularVelocity = Vector3.new(0,0,0)

    
    local JumpRayParams = RaycastParams.new()
    local IgnoreCheckpoints = {}
    JumpRayParams.FilterDescendantsInstances = {workspace:FindFirstChild("AI_Holder"),workspace:FindFirstChild("CreaturesFolder"),workspace:FindFirstChild("CharacterFolder"),unpack(IgnoreCheckpoints)}
    JumpRayParams.FilterType = Enum.RaycastFilterType.Blacklist

    HorseData.MovementAI = {}
    local AI = HorseData.MovementAI
    AI.Maid = Maid.new()
    
    local MaxWalkspeed = script:GetAttribute("MaxWalkspeed")
    local MinWalkspeed = script:GetAttribute("MinWalkspeed")
    local MaxTurnSpeed = script:GetAttribute("TurnSpeedMax")
    local MinTurnSpeed = script:GetAttribute("TurnSpeedMin")
    local TURN_SPEED = MinTurnSpeed
    local CurrentStateMaid = nil
    local CurrentMovePosition = nil
    local CurrentWaypoints = {}
    local CurrentWaypointIndex = 1

    function AI:SetTarget(Position,Waypoints,Priority)
        Priority = Priority or 100
        if CurrentStateMaid then
            CurrentStateMaid:DoCleaning()
        end
        if typeof(Position) ~= "CFrame" then
            Position = CFrame.new(Position)
        end
        MaxWalkspeed = math.random(MinWalkspeed,MaxWalkspeed)
        TURN_SPEED = math.random(MinTurnSpeed,MaxTurnSpeed)
        Waypoints = Waypoints or HorsePathfinding.Pathfind(Horse.PrimaryPart.CFrame,Position)
        if Waypoints[1] then
            CurrentMovePosition = Waypoints[1].Position
            CurrentWaypoints = Waypoints
            CurrentWaypointIndex = 1
        else
            warn("Cannot set target, no waypoints")
        end
    end

    AI.EnableIdleBehavior = true
    --[[function AI:StopCurrentState()
        if CurrentStateMaid then
            CurrentStateMaid:DoCleaning()
        end
    end

    function AI:StartState(State)
        self:StopCurrentState()
        CurrentStateMaid = Modes[State](HorseData)
    end]]

    function AI:Terminate()
        self.Maid:DoCleaning()
        HorseData.MovementAI = nil
    end

    
    print("MAKING AI CONNECTION")
    Maid["TargetUpdater"] = RunService.Heartbeat:Connect(function(deltaTime)
        if Horse.PrimaryPart then
            if CurrentMovePosition then
                --Humanoid:MoveTo(CurrentMovePosition)
                ---
                Humanoid:MoveTo((Horse.PrimaryPart.CFrame * CFrame.new(0,0,-5)).Position)
                local Pitch, Yaw, Roll = Horse.PrimaryPart.CFrame:ToObjectSpace(CFrame.lookAt(Horse.PrimaryPart.Position,CurrentMovePosition)):ToEulerAnglesYXZ()
                local DirectionFactor = TweenService:GetValue(1-(math.clamp(math.abs(math.deg(Yaw)),0,60)/60),Enum.EasingStyle.Circular,Enum.EasingDirection.In)
                local TurnAmount = math.clamp(math.abs(math.deg(Yaw)),0,TURN_SPEED) * (1-DirectionFactor)
                AngularVelocity.AngularVelocity = Vector3.new(0,math.sign(Yaw) * TurnAmount,0)
                --[[Horse.PrimaryPart.CFrame *= CFrame.Angles(
                    0,
                    math.rad(math.sign(Yaw) * TurnAmount),--math.rad(math.deg(Yaw) - -math.sign(Yaw) * 1),
                    0
                )]]
                --print(math.floor(math.deg(Yaw)))
                Humanoid.WalkSpeed = MaxWalkspeed * DirectionFactor
                --print(Humanoid.WalkSpeed)
                ---
                if (CurrentMovePosition * Vector3.new(1,0,1) - Horse.PrimaryPart.Position * Vector3.new(1,0,1)).Magnitude < 5 then
                    CurrentMovePosition = nil
                    CurrentWaypointIndex += 1
                end
            end
            if not CurrentMovePosition then
                if CurrentWaypoints[CurrentWaypointIndex] then
                    CurrentMovePosition = CurrentWaypoints[CurrentWaypointIndex].Position
                elseif CurrentWaypointIndex == #CurrentWaypoints+1 then
                    print("LAST")
                    CurrentMovePosition = (Horse.PrimaryPart.CFrame * CFrame.new(0,0,-10)).Position
                    if AI.EnableIdleBehavior == true and not CurrentStateMaid then
                        CurrentStateMaid = Modes.IdleWalk(HorseData)
                    end
                end
                
            end

            --Swim
        
            local min = Horse.PrimaryPart.Position - (.5 * Horse.PrimaryPart.Size)
            local max = Horse.PrimaryPart.Position + (.5 * Horse.PrimaryPart.Size)
            local region = Region3.new(min,max):ExpandToGrid(4)
            local material = workspace.Terrain:ReadVoxels(region,4)[1][1][1]
            if material == Enum.Material.Water then
                BodyVelocity.MaxForce = Vector3.new(0,10000000000,0)
            else
                BodyVelocity.MaxForce = Vector3.new(0,0,0)
            end
            -- Jump
            local RayResult = workspace:Raycast(Horse.PrimaryPart.Position - Vector3.new(0,1.5,0),Horse.PrimaryPart.CFrame.LookVector * 5,JumpRayParams)
            if RayResult then
                Humanoid.Jump = true
            end
        end
    end)
end

return MovementAI