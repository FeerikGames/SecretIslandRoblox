--Stratiz
local RaceAIHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

--Don"t setup race function if its competition parade server
if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
	return RaceAIHandler
end

local HorseAnimator = require("HorseAnimator")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local HorseLoader = require("HorseLoader")
local MovementAI = require("MovementAI")

PhysicsService:RegisterCollisionGroup("HorseAI")

--// for testing

local AI_CONFIG = Instance.new("Folder",workspace)
AI_CONFIG.Name = "AI_CONFIG"
local SpeedConfig = Instance.new("NumberValue",AI_CONFIG)
SpeedConfig.Name = "AvgSpeed"
SpeedConfig.Value = 30

local VISUALIZE_PATH = true
local PathSanityRayParams = RaycastParams.new()
--//


local function CubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

local function GenerateBezierWaypoints(StartCFrame,EndCFrame)
    local Waypoints = {}
    PathSanityRayParams.FilterDescendantsInstances = {workspace:WaitForChild("CreaturesFolder"),workspace:FindFirstChild("AI_Holder"),workspace:FindFirstChild("CharacterFolder")}
    for i=1,50 do
        Waypoints[i] = CFrame.new(CubicBezier(0.02*i,StartCFrame.Position,(StartCFrame * CFrame.new(0,0,-10)).Position,(EndCFrame * CFrame.new(0,0,10)).Position,EndCFrame.Position))
        local RayBasePosition = (Waypoints[i-1] or StartCFrame).Position
        local Magnitude = (RayBasePosition-Waypoints[i].Position).Magnitude
        local PathSanityResult = workspace:Raycast(RayBasePosition,CFrame.lookAt(RayBasePosition,Waypoints[i].Position).LookVector * Magnitude,PathSanityRayParams)
        if VISUALIZE_PATH then
            local VisualPart = Instance.new("Part")
            VisualPart.BrickColor = BrickColor.random()
            local CFRoot = CFrame.lookAt(RayBasePosition,Waypoints[i].Position)
            
            VisualPart.Anchored = true
            VisualPart.CanCollide = false
            VisualPart.CFrame = CFRoot * CFrame.new(0,0,-Magnitude/2)
            VisualPart.Size = Vector3.new(0.2,0.2,Magnitude)
            --VisualPart.Parent = workspace

        end
        if PathSanityResult then
            if VISUALIZE_PATH then
                local PathBlockPart = Instance.new("Part")
                PathBlockPart.Anchored = true
                PathBlockPart.CanCollide = false
                PathBlockPart.Name = "Marker"
                PathBlockPart.Parent = workspace
                PathBlockPart.Color = Color3.new(1)
                PathBlockPart.Size = Vector3.new(1,1,1)
                PathBlockPart.CFrame = CFrame.new(PathSanityResult.Position)
            end
            warn("Path is blocked! fallback to pathfinding")
            return
        end
    end
    return Waypoints 
end

local HorseCharacterTemplate = ReplicatedStorage.SharedSync.Assets.CreaturesModels:WaitForChild("HorseCharacter")
local function MakeNPC(Parent)
    HorseCharacterTemplate.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
    local NewNPC = HorseCharacterTemplate:Clone()
    
    NewNPC:WaitForChild("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.Swimming,false) -- maybe do this to the default rig???
    NewNPC:WaitForChild("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics,false)

    NewNPC.Humanoid.AutoRotate = false 
    
    if NewNPC.PrimaryPart and NewNPC.PrimaryPart:FindFirstChild("Prompt") then
        NewNPC.PrimaryPart.Prompt:Destroy()
    end
    for _,Part in pairs(NewNPC:GetDescendants()) do
        if Part:IsA("BasePart") then
            Part.CollisionGroup = "HorsesAI"
        end
    end
    
    NewNPC.Parent = Parent
    NewNPC.PrimaryPart:SetNetworkOwner(nil)
    local HorseData = HorseLoader.MakeCreatureDataTable(NewNPC)
    HorseAnimator:Bind(HorseData)
    return NewNPC, HorseData
end

function RaceAIHandler:Generate(RaceData,Amount)
    local AI_Holder
    if RaceData.AI_Holder then
        AI_Holder = RaceData.AI_Holder
        AI_Holder:ClearAllChildren()
    else
        AI_Holder = game.Workspace:FindFirstChild("AI_Holder")
        if not AI_Holder then
            print("CREATE AI FOLDER")
            AI_Holder = Instance.new("Folder")
            AI_Holder.Name = "AI_Holder"
            AI_Holder.Parent = workspace
        end

        local AI_Race_Holder = AI_Holder:FindFirstChild(tostring(RaceData.RaceLink))
        if not AI_Race_Holder then
            print("CREATE IA RACE HOLDER")
            AI_Race_Holder = Instance.new("Folder")
            AI_Race_Holder.Name = tostring(RaceData.RaceLink)
            AI_Race_Holder.Parent = AI_Holder
        end

        AI_Holder = AI_Race_Holder
        RaceData.AI_Holder = AI_Holder
    end

    --local Checkpoints = RaceModel:WaitForChild("Checkpoints")
    
    --[[for _,Checkpoint in pairs(Checkpoints:GetChildren()) do
        if Checkpoint:FindFirstChildOfClass("PathfindingModifier") then
            Checkpoint:FindFirstChildOfClass("PathfindingModifier"):Destroy()
        end
        local Modifier = Instance.new("PathfindingModifier")
        Modifier.ModifierId = "Checkpoint"
        Modifier.PassThrough = true
        Modifier.Parent = Checkpoint
    end]]
    
    local AITable = {}
    for ID=1,Amount do
        local CheckpointOffset = (math.random()-0.5)/0.5
        local Horse,HorseData = MakeNPC(AI_Holder)

        MovementAI:Make(HorseData)

        --HorseBumpHandler:Enable(HorseData,AI_Holder)
        -- Edit animation
        HorseData.Animator:SetMovementAnimation("Gallop")
        --
        local Connections = {}

        AITable["AI"..ID] = {
            IsAI = true,
            Data = HorseData,
            Horse = Horse,
            Finished = false,
            Stuck = false,
            CheckpointOffset = CheckpointOffset,
        }
    end
    return AITable, AI_Holder
end

function RaceAIHandler:Init()
    PhysicsService:CollisionGroupSetCollidable("HorseAI", "HorseAI", false)
    PhysicsService:CollisionGroupSetCollidable("HorseAI", "Humans", false)
    PhysicsService:CollisionGroupSetCollidable("HorseAI", "Horses", false)
end

return RaceAIHandler
