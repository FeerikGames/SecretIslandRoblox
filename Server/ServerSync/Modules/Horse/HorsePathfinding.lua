local PathfindingService = game:GetService("PathfindingService")
local HorsePathfinding = {}

local VISUALIZE_PATH = true
local FolderVisualize = Instance.new("Folder", workspace)
FolderVisualize.Name = "IA PATH VIZUALISE"
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
            VisualPart.BrickColor = BrickColor.Green()
            local CFRoot = CFrame.lookAt(RayBasePosition,Waypoints[i].Position)
            
            VisualPart.Anchored = true
            VisualPart.CanCollide = false
            VisualPart.CFrame = CFRoot * CFrame.new(0,0,-Magnitude/2)
            VisualPart.Size = Vector3.new(0.2,0.2,Magnitude)
            VisualPart.Parent = FolderVisualize

        end
        if PathSanityResult then
            if VISUALIZE_PATH then
                local PathBlockPart = Instance.new("Part")
                PathBlockPart.Anchored = true
                PathBlockPart.CanCollide = false
                PathBlockPart.Name = "BRUH"
                PathBlockPart.Parent = FolderVisualize
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

function HorsePathfinding.Pathfind(Start,End,RacePath)
    --print("TEST START POINT TO OBJ SPACE Z", Start:PointToObjectSpace(End.Position).Z)
    --determine si le start est derrière la position end ?
    --[[ if Start:PointToObjectSpace(End.Position).Z < 0 then
        local BezierWaypoints = GenerateBezierWaypoints(Start,End)
        if BezierWaypoints then
            return BezierWaypoints
        end
    end ]]
    local RacePath = RacePath or PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentHeight = 7,
        AgentCanJump = true,
        WaypointSpacing = 8,
        Costs = {
        }
    })

    local StartCFrame = Start
    local EndCFrame = End
    local success, errorMessage = pcall(function()
        RacePath:ComputeAsync(StartCFrame.Position, EndCFrame.Position)
    end)
    if success then
        if VISUALIZE_PATH then
            local Waypoints = RacePath:GetWaypoints()
            for _, child in pairs(FolderVisualize:GetChildren()) do
                child:Destroy()
            end
            for _, waypoint in pairs(Waypoints) do
                local VisualPart = Instance.new("Part")
                VisualPart.BrickColor = BrickColor.Blue()
                VisualPart.Anchored = true
                VisualPart.CanCollide = false
                VisualPart.CanQuery = false
			    VisualPart.CanTouch = false
                VisualPart.Position = waypoint.Position
                VisualPart.Size = Vector3.new(1,1,1)
                VisualPart.Parent = FolderVisualize
            end
        end
        return RacePath:GetWaypoints()
    else
        warn("Failed to pathfind |", errorMessage)
    end
end

function HorsePathfinding.PathfindCheckpoints(Start,Checkpoints) 
    local Paths = {}
    local RacePath = PathfindingService:CreatePath({ 
        AgentRadius = 3,
        AgentHeight = 7,
        AgentCanJump = true,
        Costs = {
            --Water = math.huge,
            --Checkpoint = 0
        }
    })

    for Index=1, #Checkpoints do
        local StartCFrame = (Checkpoints[Index-1] and Checkpoints[Index-1].Properties or Start).CFrame 
        local EndCFrame = Checkpoints[Index].Properties.CFrame --* CFrame.new(0,0,-1)
        local Result = HorsePathfinding.Pathfind(StartCFrame,EndCFrame,RacePath)
        if Result then
            table.insert(Paths,Result)
        end
    end
    return Paths
end

return HorsePathfinding