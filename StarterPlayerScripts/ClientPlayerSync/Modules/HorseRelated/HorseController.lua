local HorseController = {
	Active = false,
	Creature = nil
}

--- Config
local AutoRotateLerpRate = 0.05
---

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HorseBumpHandler = require("HorseBumpHandler")
local HorseAnimator = require("HorseAnimator")
local GameDataModule = require("GameDataModule")

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
--local RE_HorseAudio = HorseEvents:WaitForChild("HorseAudioEvent")

local LocalPlayer = Players.LocalPlayer

local function Lerp(v0, v1, t)
	return v0 + t * (v1 - v0)
end

--local Connections = {}


local Actions = {}

for _,ActionModule in pairs(script.Parent.HorseActions:GetChildren()) do
	Actions[ActionModule.Name] = require(ActionModule)
end

local function UnbindRunning()
	local success, message = pcall(function()
		RunService:UnbindFromRenderStep("FloorMaterialStep")
	end)
end

function HorseController:Enable(CreatureData)
	if self.Active == false then
		local Humanoid = CreatureData.Instance:FindFirstChildOfClass("Humanoid")
		
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming,false)
		
		local ExtraValues = {
			Humanoid = Humanoid,
			PrimaryPart = CreatureData.Instance.PrimaryPart,
			RootPart = CreatureData.Instance:FindFirstChild("RootPart")
		}
		for Index,Value in pairs(ExtraValues) do
			if Value == nil then
				warn("Failed to enable horse, "..Index.." is nil.")
				return
			end
		end
		self.Active = true
		
		HorseAnimator:Bind(CreatureData)
		self.Creature = CreatureData
		
		for Index,Value in pairs(ExtraValues) do
			self.Creature[Index] = Value
		end
		
		self.Creature.Connections = {}
		
		self.Creature.Actions = Actions
		for _,Action in pairs(self.Creature.Actions) do
			if type(Action) == "table" then
				Action:Init(self.Creature)
			end
		end
 
		self.Creature.CurrentWalkType = ""
		self.Creature.CurrentTerrain = "Land" -- Air,Land,Sea
		
		self.Creature.Actions.Flight:SetStyle("Glider")
		self.Creature.Actions.Walk:SetStyle("Gallop")
		self.Creature.Actions.Walk:SetEnabled(true)
 
		local LastMaterial = Enum.Material.Plastic
		local CanBindNew = true

		local Sound = ExtraValues.PrimaryPart:WaitForChild("Running")
		self.Creature.Connections.Running = Humanoid.Running:Connect(function(Speed)
			local Velocity = self.Creature.RootPart.Velocity.Magnitude
			if Speed > 0 and CanBindNew then
				RunService:BindToRenderStep("FloorMaterialStep", Enum.RenderPriority.Character.Value - 5, function()
					Velocity = self.Creature.RootPart.Velocity.Magnitude
					local MaterialName = Humanoid.FloorMaterial.Name
					local SoundId = GameDataModule.AnimalSounds.Materials[MaterialName]
					if not SoundId then
						SoundId = GameDataModule.AnimalSounds.Running["Cat"]
					end
					Sound.SoundId = "rbxassetid://" .. SoundId

					-- Check if animal lose velocity not play sound or if Air material check if fly mode or not to not play air sound when animal jump and only if fly
					if Velocity < 1 or (MaterialName == "Air" and not self.Creature.Actions.Flight:IsEnabled()) then
						UnbindRunning()
						CanBindNew = true
						Sound.Volume = 0
					end
				end)
				CanBindNew = false
				Sound.Volume = 0.5
			elseif Speed <= 0 then
				UnbindRunning()
				CanBindNew = true
				Sound.Volume = 0
			end
		end)

		Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			if not self.Active then
				return
			end
			local FloorMaterial = Humanoid.FloorMaterial
			if LastMaterial == Enum.Material.Air and FloorMaterial ~= Enum.Material.Air then
				self.Creature.Actions.Flight:SetEnabled(false)
				self.Creature.Actions.Walk:SetEnabled(true)
			end
			LastMaterial = FloorMaterial
		end)

		--HorseBumpHandler:Enable(self.Creature)
		--
		local LastSlopeAngle = 0
		local LastHipOffset = 0
		--local SeatBone = self.Creature.RootPart:FindFirstChild("torax",true) 
		--local BaseBone = self.Creature.RootPart:FindFirstChild("body_general")
		local HumanHumanoid = nil
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
			HumanHumanoid = LocalPlayer.Character.Humanoid
			self.Creature.Connections.JumpConnection = HumanHumanoid:GetPropertyChangedSignal("Jump"):Connect(function()
				if HumanHumanoid.Jump == true then
					Humanoid.Jump = true
				end
			end)
		end

		self.Creature.Connections.CreatureAdjustments = RunService.RenderStepped:Connect(function()
			local RootPart = self.Creature.Instance.PrimaryPart
			if RootPart and RootPart:FindFirstChild("Motor6D") then
				local Parameters = RaycastParams.new()
				Parameters.FilterDescendantsInstances = {self.Creature.Instance,workspace:WaitForChild("CharacterFolder")}
				local ZOffset = RootPart.Size.Z/2

				--Be carful not set Y to 0 here for no nil raycast
				local FrontRayResult = workspace:Raycast((RootPart.CFrame * CFrame.new(0,0,-ZOffset)).Position,Vector3.new(0,-6*RootPart.Size.Y,0),Parameters)
				local BackRayResult = workspace:Raycast((RootPart.CFrame * CFrame.new(0,0,ZOffset)).Position,Vector3.new(0,-6*RootPart.Size.Y,0),Parameters)
				local HipHeightResult = workspace:Raycast(RootPart.Position,Vector3.new(0,-6*RootPart.Size.Y,0),Parameters)

				if FrontRayResult and BackRayResult then
					local LookDirection = (RootPart.CFrame * CFrame.new(0,-30*RootPart.Size.Y,ZOffset)):ToObjectSpace(CFrame.lookAt(BackRayResult.Position,FrontRayResult.Position)).LookVector
					local Angle = Lerp(LastSlopeAngle,math.sign(FrontRayResult.Position.Y-BackRayResult.Position.Y) * math.acos(LookDirection:Dot(Vector3.new(0,0,-1))),0.3)
					Angle = Angle == Angle and Angle or 0
					--SeeRaycast(FrontRayResult, RootPart, "Front")
					--SeeRaycast(BackRayResult, RootPart, "Back")
					
					local NewHipHeight = 0
					if HipHeightResult then
						--SeeRaycast(HipHeightResult, RootPart, "Height")

						NewHipHeight = math.clamp((RootPart.Position - HipHeightResult.Position).Magnitude,1,100)
						NewHipHeight += NewHipHeight^2/15

					else
						--Humanoid.HipHeight = 3
					end

					LastHipOffset = Lerp(LastHipOffset,NewHipHeight,0.2)

					RootPart.Motor6D.C0 = CFrame.Angles(Angle,0,0)
					RootPart.Motor6D.C1 = CFrame.new(0,0,0)
					
					LastSlopeAngle = Angle
				end
				
				---
				
			end
			-- Movement
			
			 
		end)
	end
	return self.Creature
end

function SeeRaycast(result, rootPart, name)
	if result then
		local distance = (rootPart.Position - result.Position).Magnitude
		local exist = workspace:FindFirstChild("RaycastViewer"..name)
		if exist then
			exist:Destroy()
		end
		local p = Instance.new("Part",workspace)
		p.Name = "RaycastViewer"..name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.BrickColor = BrickColor.Red()
		p.Size = Vector3.new(0.1, 0.1, distance)
		p.CFrame = CFrame.lookAt(rootPart.Position, result.Position)*CFrame.new(0, 0, -distance/2)
	end
end



function HorseController:Disable()
	if self.Creature then
		if self.Creature.BumpHandler then
			self.Creature.BumpHandler:Disable()
		end
		local function TerminateConnections(Table)
			for _,Connection in pairs(Table) do
				if type(Connection) == "table" then
					TerminateConnections(Connection)
				else
					Connection:Disconnect()
				end
			end
		end
		
		TerminateConnections(self.Creature.Connections)
		
		for _,Animation in pairs(self.Creature.Animator.Animations) do
			if type(Animation) == "userdata" then
				Animation:Stop()
			end
		end

		self.Creature.Animator:SetMovementAnimation("Idle")
		self.Creature.Animator:Unbind()

		for _,Action in pairs(self.Creature.Actions) do
			if type(Action) == "table" then
				Action:SetEnabled(false)
			end
		end
	end
	self.Active = false
end

--[[RE_HorseAudio.OnClientEvent:Connect(function(Creature)
	print("On client material change")
end)]]


return HorseController