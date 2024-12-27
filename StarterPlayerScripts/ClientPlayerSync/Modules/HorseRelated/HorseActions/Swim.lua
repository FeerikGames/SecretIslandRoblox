local HorseSwim = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local InputController = require("InputController")
local LocalPlayer = Players.LocalPlayer

local CurrentSwimState = "Hover"
local PitchAlpha = 0

local Creature = nil
local BodyVelocity = nil
function HorseSwim:Init(NewCreature)
	
	Creature = NewCreature
	Creature.Connections.Swim = {}
	--UpdateSwimState(BodyVelocity.Velocity,-PitchAlpha)
	
end

function HorseSwim:SetEnabled(State)
	local Humanoid = Creature.Instance.Humanoid
	if State == true then
		--BodyVelocity.MaxForce = Vector3.new(10000000,10000000,10000000)  
		--BodyVelocity.Velocity = Vector3.new()
		--Creature.CurrentTerrain = "Water"
	elseif Creature.CurrentTerrain == "Water" then
		Creature.CurrentTerrain = "Land"
		BodyVelocity.MaxForce = Vector3.new()
	end
end

function HorseSwim:SetStyle(StyleName)
	if self.Styles[StyleName] then
		if Creature.Connections.Swim then
			for _,Connection in pairs(Creature.Connections.Swim) do
				Connection:Disconnect()
			end
			Creature.Connections.Swim = {}
		end
		
		self.Styles[StyleName](Creature)
	else
		warn("No swim style named "..StyleName)
	end
	
end

HorseSwim.Styles = {}

HorseSwim.Styles.Float = function()
	local Humanoid = Creature.Humanoid
	local HumanoidRootPart = Creature.PrimaryPart
	--Config
	local Boyancy = 5
	local WaterRayParams = RaycastParams.new()
	WaterRayParams.FilterType = Enum.RaycastFilterType.Whitelist
	WaterRayParams.FilterDescendantsInstances = {workspace.Terrain}
	WaterRayParams.IgnoreWater = false
	--
	local CurrentBoyancy = 5
	--local BodyVelocity = Creature.PrimaryPart:FindFirstChild("Swim")
	Creature.Connections.Swim.Main = RunService.Heartbeat:Connect(function(Delta)
		local min = HumanoidRootPart.Position - (.5 * HumanoidRootPart.Size)
		local max = HumanoidRootPart.Position + (.5 * HumanoidRootPart.Size)	
		local region = Region3.new(min,max):ExpandToGrid(4)
		local material = workspace.Terrain:ReadVoxels(region,4)[1][1][1] 
		if material == Enum.Material.Water then
			local WaterRayResult = workspace:Raycast(HumanoidRootPart.Position + Vector3.new(0,1,0),Vector3.new(0,-5,0),WaterRayParams)
			CurrentBoyancy = Boyancy
			if WaterRayResult and WaterRayResult.Material == Enum.Material.Water then
				local Magnitude = (WaterRayResult.Position - HumanoidRootPart.Position).Magnitude
				--print("Distance above water",Magnitude)
				CurrentBoyancy = Boyancy * math.clamp(Magnitude,0,1)
			end
			--print("FLOAT")
			BodyVelocity.Parent = HumanoidRootPart
			BodyVelocity.MaxForce = Vector3.new(0,10000000,0)  
			BodyVelocity.Velocity = Vector3.new(0,CurrentBoyancy,0)
			Creature.CurrentTerrain = "Water"
		else
			BodyVelocity.MaxForce = Vector3.new()  
			BodyVelocity.Velocity = Vector3.new()
			BodyVelocity.Parent = nil
			if Creature.CurrentTerrain == "Water" then
				Creature.CurrentTerrain = "Land"
			end
		end
	end)
	
end

HorseSwim.Styles.Swim = function()
	local Humanoid = Creature.Humanoid
	local HumanoidRootPart = Creature.PrimaryPart
	--Config
	local WaterRayParams = RaycastParams.new()
	WaterRayParams.FilterType = Enum.RaycastFilterType.Whitelist
	WaterRayParams.FilterDescendantsInstances = {workspace.Terrain}
	WaterRayParams.IgnoreWater = false
	local MaxSpeed = 10
	local Ascending = false
	--
	--local BodyVelocity = Creature.PrimaryPart:FindFirstChild("Swim")
	local HumanHumanoid = nil
	if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		HumanHumanoid = LocalPlayer.Character.Humanoid
	end
	Creature.Connections.Swim.Main = RunService.Heartbeat:Connect(function(Delta)
		local min = HumanoidRootPart.Position - (.5 * HumanoidRootPart.Size)
		local max = HumanoidRootPart.Position + (.5 * HumanoidRootPart.Size)	
		local region = Region3.new(min,max):ExpandToGrid(4)
		local material = workspace.Terrain:ReadVoxels(region,4)[1][1][1] 
		local AscentRate = 0
		if Ascending then
			AscentRate = MaxSpeed * 1.5
		end
		if material == Enum.Material.Water then
			local WaterRayResult = workspace:Raycast(HumanoidRootPart.Position + Vector3.new(0,1,0),Vector3.new(0,-5,0),WaterRayParams)
			local SwimForce = 1
			if WaterRayResult and WaterRayResult.Material == Enum.Material.Water then
				local Magnitude = (WaterRayResult.Position - (HumanoidRootPart.Position + Vector3.new(0,1,0))).Magnitude
				--print("Distance above water",Magnitude)
				SwimForce = 1-math.clamp(Magnitude,0,1)
			end
			--print("FLOAT")
			BodyVelocity.Parent = HumanoidRootPart
			BodyVelocity.MaxForce = Vector3.new(10000000,10000000,10000000)  
			--BodyVelocity.Velocity = Vector3.new(0,0,0)
			Creature.CurrentTerrain = "Water"
			
			
			local Pitch, Yaw, Roll = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()
			
			PitchAlpha = math.clamp(math.deg(Pitch)/90,-1,0)
			
			local VelocityFactor = 1
			
			if HumanHumanoid and HumanHumanoid.MoveDirection.Magnitude > 0 then
				Creature.PrimaryPart.CFrame = Creature.PrimaryPart.CFrame:Lerp(CFrame.new(Creature.PrimaryPart.Position) * CFrame.Angles(0, Yaw, 0),0.1)
				local MovementDifferenceAlpha = 1-((HumanHumanoid.MoveDirection - Creature.PrimaryPart.CFrame.LookVector).Magnitude/2)
				--
				local CurrentFlightVelocity = math.clamp(MaxSpeed * (VelocityFactor * MovementDifferenceAlpha),15,30) 
				BodyVelocity.Velocity = ((((Creature.PrimaryPart.CFrame).LookVector * CurrentFlightVelocity) + Vector3.new(0,AscentRate,0)) * Vector3.new(1,SwimForce,1)) + Vector3.new(0,PitchAlpha * CurrentFlightVelocity,0)
			else
				BodyVelocity.Velocity = Vector3.new(0,AscentRate * SwimForce,0)
				--LastStopTime = tick()
			end
		else
			BodyVelocity.MaxForce = Vector3.new()  
			BodyVelocity.Velocity = Vector3.new()
			BodyVelocity.Parent = nil
			if Creature.CurrentTerrain == "Water" then
				Creature.CurrentTerrain = "Land"
			end
		end
	end)
	Creature.Connections.Swim.Accend = InputController.Inputs.Swimming.Ascend.Activated:Connect(function()
		print("UP!")
		Ascending = true
	end)
	Creature.Connections.Swim.Accend = InputController.Inputs.Swimming.Ascend.Deactivated:Connect(function()
		Ascending = false
	end)
end

return HorseSwim
