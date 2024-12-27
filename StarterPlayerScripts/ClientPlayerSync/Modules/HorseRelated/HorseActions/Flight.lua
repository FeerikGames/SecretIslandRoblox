local HorseFlight = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerDataModule = require("ReplicatedPlayerData")

local StarterPlayer = game:GetService("StarterPlayer")
local CameraController = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local MovementAirAnalogicFilter = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules.HorseRelated:WaitForChild("MovementAirAnalogicFilter"))
local MovementAirKeyboardFilter = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules.HorseRelated:WaitForChild("MovementAirKeyboardFilter"))

local CurrentFlightVelocity = ReplicatedStorage.SharedSync.Modules.WalkSpeedModule:GetAttribute("FlightSpeed")
local currentStyle = ""
local CurrentFlightState = "Hover"
local PitchAlpha = 0

local Creature = nil
local LinearVelocity = nil

local creatureCameraOffset= script:GetAttribute("creatureCameraOffset")

local flightCameraAutoRotationOffsetBySpeedCurveValuePositionRange:NumberRange = script:GetAttribute("flightCameraAutoRotationOffsetBySpeedCurveValuePositionRange")
local flightCameraAutoRotationOffsetBySpeedCurveX:NumberSequence = script:GetAttribute("flightCameraAutoRotationOffsetBySpeedCurveX")
local flightCameraAutoRotationOffsetBySpeedCurveY:NumberSequence = script:GetAttribute("flightCameraAutoRotationOffsetBySpeedCurveY")
local flightCameraAutoRotationOffsetBySpeedCurveZ:NumberSequence = script:GetAttribute("flightCameraAutoRotationOffsetBySpeedCurveZ")

local flightCameraDistanceCurve:NumberSequence = script:GetAttribute("flightCameraDistanceCurve")
local flightCameraDistanceCurveValueDistanceRange:NumberRange = script:GetAttribute("flightCameraDistanceCurveValueDistanceRange")

local flightCameraFovCurve:NumberSequence = script:GetAttribute("flightCameraFovCurve")
local flightCameraFovCurveValueAngleRange:NumberRange = script:GetAttribute("flightCameraFovCurveValueAngleRange")

local enabled = false

function TerminateConnections()
	if Creature.Connections.Flight then
		for _,Connection in pairs(Creature.Connections.Flight) do
			Connection:Disconnect()
		end
		Creature.Connections.Flight = {}
	end
end

function HorseFlight.TerminateConnections()
	TerminateConnections()
end

function HorseFlight:Init(NewCreature)
	Creature = NewCreature

	LinearVelocity = NewCreature.Instance.PrimaryPart:WaitForChild("Flight")
 
	Creature.Connections.Flight = {}
	local function UpdateFlightState(Velocity)
		local NewState = ""
		if Velocity.Magnitude > 0 then
			if PitchAlpha < -0.6 then
				NewState = "Dive"
			elseif PitchAlpha < 0 then
				NewState = "Glide"
			elseif PitchAlpha >= 0 then
				NewState = "Normal Fly"
			elseif PitchAlpha > 0.5 then
				NewState = "Climbing Fly"
			end
		else
			NewState = "Hover"
		end
		if CurrentFlightState ~= NewState then
			print("New flight state: "..NewState)
			CurrentFlightState = NewState
		end
	end

	self:SetStyle("Glider")
	--UpdateFlightState(LinearVelocity.Velocity,-PitchAlpha)
	
end

function HorseFlight:SetEnabled(State)
	
	if State == enabled then
		return
	end
	
	enabled = State
	
	MovementAirAnalogicFilter.SetEnabled(State)
	MovementAirKeyboardFilter.SetEnabled(State)
	
	CameraController.SetEnabled(State)

	local CreatureRace = PlayerDataModule.LocalData.CreaturesCollection[Creature.Instance.CreatureID.Value].Race
	if CreatureRace and CreatureRace == "Celestial" then
		local Humanoid = Creature.Instance.Humanoid
		if State == true then
			Creature.Animator:Play("Fly")
			Creature.PrimaryPart.FlightEvent:FireServer(true)
			LinearVelocity.Enabled = true
			LinearVelocity.MaxForce = 10000000  
			LinearVelocity.VectorVelocity = Vector3.new(0,50,0)
			task.wait(0.4)
			LinearVelocity.VectorVelocity = Vector3.new()
			Creature.CurrentTerrain = "Air"
			Humanoid.AutoRotate = false
			self.Styles[currentStyle](Creature)
		else
			if Creature.CurrentTerrain == "Air" then
				Creature.CurrentTerrain = "Land"
			
				Humanoid.AutoRotate = false
				Creature.Animator:Stop("Fly")
			end

			LinearVelocity.MaxForce = 0
			Creature.PrimaryPart.FlightEvent:FireServer(false)
			LinearVelocity.Enabled = false
		end
	else
		warn("Creature race not Air, can't fly !")
	end

	if State == false then
		TerminateConnections()
	end
end

function HorseFlight:IsEnabled()
	return enabled
end

function HorseFlight:SetStyle(StyleName)
	
	if currentStyle == StyleName then
		return
	end

	
	if self.Styles[StyleName] then
		currentStyle = StyleName
		TerminateConnections()

		if enabled then
			self.Styles[StyleName](Creature)
		end

	else
		warn("No flight style named "..StyleName)
	end

end

HorseFlight.Styles = {}

HorseFlight.Styles.Helicopter = function()
	--[[
	-- Config
	local DecentRate = 3
	local MaxSpeed = 30
	--
	local CurrentDecentRate = -DecentRate
	local Humanoid = Creature.Humanoid
	
	local HumanHumanoid = nil
	if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		HumanHumanoid = LocalPlayer.Character.Humanoid
	end
	--local LinearVelocity = Creature.PrimaryPart:FindFirstChild("Flight")
	local LastStopTime = tick()
	
	CameraController.SetDistanceCurve(flightCameraDistanceCurve,flightCameraDistanceCurveValueDistanceRange )
	CameraController.SetFovCurve(flightCameraFovCurve,flightCameraFovCurveValueAngleRange)
	CameraController.SetAutoRotationPositionOffsetBySpeedCurve(flightCameraAutoRotationOffsetBySpeedCurveX,flightCameraAutoRotationOffsetBySpeedCurveY,flightCameraAutoRotationOffsetBySpeedCurveZ,flightCameraAutoRotationOffsetBySpeedCurveValuePositionRange)
	CameraController.SetAutoRotationState(true)
	--CameraController.SetPositionOffset((Character:WaitForChild("Head").CFrame.Position + Vector3.new(0,1.5,0)) - Creature.PrimaryPart.CFrame.Position + creatureCameraOffset )
	CameraController.SetTarget(humanoidRootpart)
	CameraController.SetRaycastIgnoreList({Creature.Instance,game.Players.LocalPlayer.Character})
	CameraController.SetRaycastGroup("CameraCollision")

	Creature.Connections.Flight.Main = RunService.Heartbeat:Connect(function(Delta)
		--local CameraAngle = Get2DCFrameDifference(CFrame.new(),workspace.CurrentCamera.CFrame)	
		if Creature.CurrentTerrain == "Air" and LinearVelocity then
			local Pitch, Yaw, Roll = workspace.CurrentCamera.CFrame:ToEulerAnglesYXZ()

			local VelocityFactor = math.clamp(tick()-LastStopTime,0,2)/2
			
			if HumanHumanoid and HumanHumanoid.MoveDirection.Magnitude > 0 then
				Creature.PrimaryPart.CFrame = Creature.PrimaryPart.CFrame:Lerp(CFrame.new(Creature.PrimaryPart.Position) * CFrame.Angles(0, Yaw, 0),0.1)
				local MovementDifferenceAlpha = 1-((HumanHumanoid.MoveDirection - Creature.PrimaryPart.CFrame.LookVector).Magnitude/2)
				--
				local CurrentFlightVelocity = math.clamp(MaxSpeed * (VelocityFactor * MovementDifferenceAlpha),15,30) 
				LinearVelocity.Velocity = ((Creature.PrimaryPart.CFrame).LookVector * CurrentFlightVelocity) + Vector3.new(0,CurrentDecentRate,0)
			else
				LinearVelocity.Velocity = Vector3.new(0,CurrentDecentRate,0)
				LastStopTime = tick()
			end
		end
	end) 
	Creature.Connections.Flight.InputDown = InputController.Inputs.Flight.Ascend.Activated:Connect(function()
		CurrentDecentRate = DecentRate * 2
	end) 
	Creature.Connections.Flight.InputUp = InputController.Inputs.Flight.Ascend.Activated:Connect(function()
		CurrentDecentRate = -DecentRate
	end)]]
end

function processMovements(deltaTime:number, moveIntent:Vector3, rotateIntent:Vector3)
	local rotation = Vector3.new(math.rad(-rotateIntent.X * 0) ,math.rad(rotateIntent.Y * 90) ,0)* deltaTime

	--print("rotation", rotation)

	Creature.PrimaryPart.CFrame =   Creature.PrimaryPart.CFrame * CFrame.Angles(rotation.x,rotation.y,rotation.z)
	--print ("look vector",Creature.PrimaryPart.CFrame.LookVector )
	LinearVelocity.VectorVelocity = (Creature.PrimaryPart.CFrame.LookVector + Vector3.new(0,1 * rotateIntent.X,0)).Unit * CurrentFlightVelocity
	
end

local function ProcessGliderControlJoystick(deltaTime:number)
	local rotateIntent = MovementAirAnalogicFilter.GetRotationIntentVector()
	local moveIntent = MovementAirAnalogicFilter.GetMovementIntentVector()

	CameraController.SetPreviewOffset(Vector3.new(0,0,0))

	processMovements(deltaTime, moveIntent, rotateIntent)

end

local function ProcessGliderControlKeyboard(deltaTime:number)
	local rotateIntent = MovementAirKeyboardFilter.GetRotationIntentVector()
	local moveIntent = MovementAirKeyboardFilter.GetMovementIntentVector()
  	
	CameraController.SetPreviewOffset(Vector3.new(0,0,0))

	processMovements(deltaTime, moveIntent, rotateIntent)
end

local function ProcessGliderControl(deltaTime:number)
	if Creature.CurrentTerrain == "Air" and LinearVelocity then
		if MovementAirAnalogicFilter.IsActive() then -- if the joystick (virtual or real) is used and outside of its deadzone
			ProcessGliderControlJoystick(deltaTime)
		else
			ProcessGliderControlKeyboard(deltaTime)
		end
	end
end

HorseFlight.Styles.Glider = function()
	local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoidRootpart = Character:WaitForChild("HumanoidRootPart")

	CameraController.SetDistanceCurve(flightCameraDistanceCurve, flightCameraDistanceCurveValueDistanceRange )
	CameraController.SetFovCurve(flightCameraFovCurve,flightCameraFovCurveValueAngleRange)
	CameraController.SetAutoRotationOffsetBySpeedCurve(flightCameraAutoRotationOffsetBySpeedCurveX,flightCameraAutoRotationOffsetBySpeedCurveY,flightCameraAutoRotationOffsetBySpeedCurveZ,flightCameraAutoRotationOffsetBySpeedCurveValuePositionRange)
	CameraController.SetAutoRotationState(true)
	CameraController.SetTarget(humanoidRootpart)
	CameraController.SetTargetPositionOffset( creatureCameraOffset )
	CameraController.SetRaycastIgnoreList({Creature.Instance,game.Players.LocalPlayer.Character})
	CameraController.SetRaycastGroup("CameraCollision")

	Creature.Connections.Flight.Main = RunService.RenderStepped:Connect(function(deltaTime)
		ProcessGliderControl(deltaTime)
	end)
end

--Event to update distance camera on fly creature depending of Size of creature
HorseEvents.SizeRatioChanged.OnClientEvent:Connect(function(ratio, reset)
	if reset then
		flightCameraDistanceCurveValueDistanceRange = script:GetAttribute("flightCameraDistanceCurveValueDistanceRange")
	else
		flightCameraDistanceCurveValueDistanceRange = NumberRange.new(flightCameraDistanceCurveValueDistanceRange.Min * ratio, flightCameraDistanceCurveValueDistanceRange.Max * ratio)
	end
end)


return HorseFlight
