local SoccerModule = {}
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Maid = require("Maid")

local Interactible = Workspace.InteractibleScenery
local Assets = ServerStorage.ServerStorageSync.AssetsRessources
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

local Arena = Workspace:FindFirstChild("SoccerArena")
if not Arena then
    return SoccerModule
end
local ResetScore = Arena.ScriptedObjects.ResetScore
local Board = Arena.ScriptedObjects.Board
local ArenaPivot = Arena:GetPivot()

local LastKick = tick()
local LastReset = tick()

local Debug = false
local CurveInfo = TweenInfo.new(
	0.6, -- Time it takes to complete curve
	Enum.EasingStyle.Linear, -- EasingStyle
	Enum.EasingDirection.Out, -- EasingDirection
	0,
	false,
	0.125 -- DelayTime before ball will curve
)
local function CheckAngle(RootPart, Object)
	local Distance = (Object.Position - RootPart.Position);
	local LookVector = (RootPart.CFrame.lookVector);
	return math.deg(math.acos(Distance:Dot(LookVector) / (Distance.magnitude * LookVector.magnitude)));
end

local function LerpNumber(p0, p1, a)
	a = math.min(a, 1)
	return p0 + ((p1 - p0) * a)
end

function evalNS(ns, time)
	if time == 0 then return ns.Keypoints[1].Value end
	if time == 1 then return ns.Keypoints[#ns.Keypoints].Value end
	for i = 1, #ns.Keypoints - 1 do
		local this = ns.Keypoints[i]
		local next = ns.Keypoints[i + 1]
		if time >= this.Time and time < next.Time then
			local alpha = (time - this.Time) / (next.Time - this.Time)
			return (next.Value - this.Value) * alpha + this.Value
		end
	end
end

local HeartBeatTask = Maid.new()
RemoteEvent.SoccerBallHandler.OnServerEvent:Connect(function(Player)
    local CreatureFolder = game.Workspace:FindFirstChild("CreaturesFolder")
    if CreatureFolder then
        local CreatureModel = CreatureFolder:FindFirstChild("Creature_" .. Player.Name)
        local SoccerBall = Interactible:FindFirstChild("Ball")
        if CreatureModel and SoccerBall then
            local HasForce = SoccerBall:FindFirstChild("VectorForce")
            if HasForce then
                return
            end

            local AngleForce = SoccerBall:GetAttribute("AngleForce")
            local KickForce = SoccerBall:GetAttribute("KickForce")
            local HeightForce = SoccerBall:GetAttribute("HeightForce")

            SoccerBall:SetNetworkOwner(Player)
            local RootPart = CreatureModel.PrimaryPart

            local Angle = RootPart.CFrame:ToObjectSpace(SoccerBall.CFrame)
            local CreatureSpeed = RootPart.Velocity.magnitude * 2500
            
            if Angle.X > 0 then
                --print "Soccer ball is to right of player!"
            else
                --print "Soccer ball is to left of player!"
            end

            local UpdatedAngle = math.abs(Angle.X * AngleForce)
            local AppliedForce = RootPart.CFrame * CFrame.new(Vector3.new(Angle.X > 0 and UpdatedAngle or -UpdatedAngle, HeightForce, -KickForce))
            local NumberSequence = SoccerBall:GetAttribute("AngleSequence")

            if Debug then
                local Part = Instance.new("Part")
                Part.Name = "_Direction"
                Part.CanCollide = false
                Part.Anchored = true
                Part.CFrame = AppliedForce
                Part.Transparency = 0.7
                Part.Material = Enum.Material.Neon
                Part.Color = Color3.fromRGB(255,0,0)
                Part.Size = Vector3.new(2,2,2)
                Part.Parent = Workspace
                Debris:AddItem(Part, 2)
                print("Angle: ", Angle.X, "UpdatedAngle: ", UpdatedAngle)
            end

            local Attachment = Instance.new("Attachment", SoccerBall)
            local VectorForce = Instance.new("VectorForce", SoccerBall)
            VectorForce.ApplyAtCenterOfMass = true
            VectorForce.Attachment0 = Attachment
            VectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
            VectorForce.Force = AppliedForce.Position
            VectorForce.Enabled = true
            SoccerBall.Kick:Play()
            Debris:AddItem(VectorForce, CurveInfo.Time)
            Debris:AddItem(Attachment, CurveInfo.Time)

            local CheckAngle = math.abs(Angle.X) <= SoccerBall:GetAttribute("ExemptAngles").Max and 0 or 1
            local Count = 0
            HeartBeatTask:DoCleaning()
            HeartBeatTask:GiveTask(RunService.Heartbeat:Connect(function(deltaTime)
                if Count < 1 then
                    local SequencePosition = evalNS(NumberSequence, Count)
                    if SequencePosition then
                        UpdatedAngle = math.abs((Angle.X * CheckAngle) * AngleForce) * SequencePosition
                        AppliedForce = RootPart.CFrame * CFrame.new(Vector3.new(Angle.X > 0 and UpdatedAngle or -UpdatedAngle, HeightForce, -KickForce))
                        VectorForce.Force = AppliedForce.Position
                    end
                    Count += 0.01
	            else
		            HeartBeatTask:DoCleaning()
	            end
            end))
        end
    end

    if tick() - LastKick < 1.5 then
        return
    end

    LastKick = tick()
end)



local function UpdateBoard()
    local Attributes = Board:GetAttributes()
    for Name, Score in pairs(Attributes) do
        Board.SurfaceGui.Frame[Name].Text = Score
    end
end

local function AddScore(TeamNet)
    local ScoreAttribute = Board:GetAttribute(TeamNet.Name .. "Score")
    Board:SetAttribute(TeamNet.Name .. "Score", ScoreAttribute + 1)
    UpdateBoard()

    task.spawn(function()
        TeamNet.PrimaryPart.Particles.Enabled = true
        task.wait(0.65)
        TeamNet.PrimaryPart.Particles.Enabled = false
    end)
end

local function SpawnBall(CFrame, Model) -- Will replace method below once we need to create more minigames.
    local Object = Assets[Model.Name]:Clone()
    Object.CFrame = CFrame
    Object.Anchored = false
    Object.Massless = true
    Object.Parent = Interactible

    local maidConstructor = Maid.new()
    maidConstructor:GiveTask() -- This is where we will handle property changes & cleanup if destroyed
end

function SoccerModule:SpawnBall()
    local SoccerBall = Interactible:FindFirstChild("Ball")
    if SoccerBall then
        SoccerBall:Destroy()
    end

    SoccerBall = Assets.Ball:Clone()
    SoccerBall.CFrame = ArenaPivot
    SoccerBall.Anchored = false
    SoccerBall.Massless = true
    SoccerBall.Parent = Interactible

    SoccerBall.Velocity = Vector3.new(0,0,0)
    SoccerBall.AssemblyLinearVelocity = Vector3.new(0,0,0)
	SoccerBall.AssemblyAngularVelocity = Vector3.new(0,0,0)
    SoccerBall:SetNetworkOwner(nil)

    LastKick = tick()

    local maidConstructor = Maid.new()
    maidConstructor:GiveTask(SoccerBall.Touched:Connect(function(Object)
        if Object.Name == "Root" and Object:IsDescendantOf(Arena) then
            AddScore(Object.Parent)

            maidConstructor:DoCleaning()
            self:SpawnBall()
        end
    end))
end

function RemoveScore()
    if tick() - LastReset < 6 then
        return
    end

    LastReset = tick()
    local Attributes = Board:GetAttributes()
    for Name, Score in pairs(Attributes) do
        Board:SetAttribute(Name, 0)
    end
    UpdateBoard()
end

ResetScore.ClickDetector.MouseClick:Connect(function(Player)
    RemoveScore()
end)

ResetScore.Touched:Connect(function(Object)
    RemoveScore()
end)

SoccerModule:SpawnBall()
return SoccerModule