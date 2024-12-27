local HorseWalk = {}

local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local InputController = require("InputController")
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)
local CameraController = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local MovementGroundAnalogicFilter = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules.HorseRelated:WaitForChild("MovementGroundAnalogicFilter"))
local MovementGroundKeyboardFilter = require(StarterPlayer.StarterPlayerScripts.ClientPlayerSync.Modules.HorseRelated:WaitForChild("MovementGroundKeyboardFilter"))
local WalkSpeedModule = require("WalkSpeedModule")



local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
task.wait(5)
if not LocalPlayer.Character then
	LocalPlayer.CharacterAdded:Wait()
end
local Character = LocalPlayer.Character
local Humanoid:Humanoid = Character:WaitForChild("Humanoid")
local humanoidRootpart = Character:WaitForChild("HumanoidRootPart")
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent


local autoRotationPreviewKeyboardIncreaseCurve:NumberSequence = script:GetAttribute("autoRotationPreviewKeyboardIncreaseCurve")
local autoRotationPreviewKeyboardIncreaseCurveKeyTime:number = script:GetAttribute("autoRotationPreviewKeyboardIncreaseCurveKeyTime")

local autoRotationPreviewAllInputDecreaseCurve:NumberSequence = script:GetAttribute("autoRotationPreviewAllInputDecreaseCurve")
local autoRotationPreviewAllInputDecreaseCurveKeyTime:number = script:GetAttribute("autoRotationPreviewAllInputDecreaseCurveKeyTime")

local autoRotationPreviewKeyboardChangePerSecMax:number = 0.1 --script:GetAttribute("autoRotationPreviewKeyboardChangePerSecMax")

local rotationYawJoystickCurve:NumberSequence = script:GetAttribute("rotationYawJoystickCurve")
local rotationYawJoystickChangeSpeed:number = script:GetAttribute("rotationYawJoystickChangeSpeed")
local rotationYawKeyboardCurve:NumberSequence = script:GetAttribute("rotationYawKeyboardCurve")
local rotationYawKeyboardChangeSpeed:number = script:GetAttribute("rotationYawKeyboardChangeSpeed")


local rotationYawPerSecondsMax:number = script:GetAttribute("rotationYawPerSecondsMax")

local walkingJoystickForwardAngleTreshold:number  = script:GetAttribute("walkingJoystickForwardAngleTreshold") -- degree
local walkingJoystickBackwardAngleTreshold:number  = script:GetAttribute("walkingJoystickBackwardAngleTreshold") -- degree
local walkingJoystickForwardOnlyAngle:number  = script:GetAttribute("walkingJoystickForwardOnlyAngle") -- degree
local walkingJoystickBackwardOnlyAngle:number  = script:GetAttribute("walkingJoystickBackwardOnlyAngle") -- degree
local walkingJoystickForwardWhenRotatingMagnitudeTreshold:number = script:GetAttribute("walkingJoystickForwardWhenRotatingMagnitudeTreshold") 
local walkingJoystickBackwardWhenRotatingMagnitudeTreshold:number = script:GetAttribute("walkingJoystickBackwardWhenRotatingMagnitudeTreshold") 

local gallopJoystickForwardAngleTreshold:number  = script:GetAttribute("gallopJoystickForwardAngleTreshold") -- degree
local gallopJoystickBackwardAngleTreshold:number  = script:GetAttribute("gallopJoystickBackwardAngleTreshold") -- degree
local gallopJoystickForwardOnlyAngle:number  = script:GetAttribute("gallopJoystickForwardOnlyAngle") -- degree
local gallopJoystickBackwardOnlyAngle:number  = script:GetAttribute("gallopJoystickBackwardOnlyAngle") -- degree
local gallopJoystickForwardWhenRotatingMagnitudeTreshold:number = script:GetAttribute("gallopJoystickForwardWhenRotatingMagnitudeTreshold") 
local gallopJoystickBackwardWhenRotatingMagnitudeTreshold:number = script:GetAttribute("gallopJoystickBackwardWhenRotatingMagnitudeTreshold") 

local creatureCameraOffset:Vector3 = script:GetAttribute("creatureCameraOffset")

local walkCameraAutoRotationOffsetBySpeedCurveValuePositionRange:NumberRange = script:GetAttribute("walkCameraAutoRotationOffsetBySpeedCurveValuePositionRange")
local walkCameraAutoRotationOffsetBySpeedCurveX:NumberSequence = script:GetAttribute("walkCameraAutoRotationOffsetBySpeedCurveX")
local walkCameraAutoRotationOffsetBySpeedCurveY:NumberSequence = script:GetAttribute("walkCameraAutoRotationOffsetBySpeedCurveY")
local walkCameraAutoRotationOffsetBySpeedCurveZ:NumberSequence = script:GetAttribute("walkCameraAutoRotationOffsetBySpeedCurveZ")

local walkCameraDistanceCurve:NumberSequence = script:GetAttribute("walkCameraDistanceCurve")
local walkCameraDistanceCurveValueDistanceRange:NumberRange = script:GetAttribute("walkCameraDistanceCurveValueDistanceRange")

local walkCameraFovCurve:NumberSequence = script:GetAttribute("walkCameraFovCurve")
local walkCameraFovCurveValueAngleRange:NumberRange = script:GetAttribute("walkCameraFovCurveValueAngleRange")

local gallopCameraAutoRotationOffsetBySpeedCurveValuePositionRange:NumberRange =  script:GetAttribute("gallopCameraAutoRotationOffsetBySpeedCurveValuePositionRange")
local gallopCameraAutoRotationOffsetBySpeedCurveX:NumberSequence =  script:GetAttribute("gallopCameraAutoRotationOffsetBySpeedCurveX")
local gallopCameraAutoRotationOffsetBySpeedCurveY:NumberSequence =  script:GetAttribute("gallopCameraAutoRotationOffsetBySpeedCurveY")
local gallopCameraAutoRotationOffsetBySpeedCurveZ:NumberSequence =  script:GetAttribute("gallopCameraAutoRotationOffsetBySpeedCurveZ")

local gallopCameraDistanceCurve:NumberSequence  = script:GetAttribute("gallopCameraDistanceCurve")
local gallopCameraDistanceCurveValueDistanceRange:NumberRange = script:GetAttribute("gallopCameraDistanceCurveValueDistanceRange")

local gallopCameraFovCurve:NumberSequence  = script:GetAttribute("gallopCameraFovCurve")
local gallopCameraFovCurveValueAngleRange:NumberRange  = script:GetAttribute("gallopCameraFovCurveValueAngleRange")

local rotationSpeedFromJoystick:number = script:GetAttribute("rotationSpeedFromJoystick")
local rotationSpeedFromKeyboard:number = script:GetAttribute("rotationSpeedFromKeyboard")

local maximimumForwardSpeedForBackward:number = script:GetAttribute("maximimumForwardSpeedForBackward")
local maximimumBackwardSpeedForForward:number = script:GetAttribute("maximimumBackwardSpeedForForward")

local currentYawRotationDirection = 0
local currentTimeSameKeyboardDirection = 0
local currentTimeNoRotationInput = 0
local lastKeyboardYawDirection = 0
local currentStyle = ""
local Creature = nil
local rotationPower = 0
local cameraForceRotationSpeed = 0

local enabled = false
local keepMove = false
local keepMoveSens = -1

function TerminateConnections()
	if Creature.Connections.Walk then
		for _,Connection in pairs(Creature.Connections.Walk) do
			Connection:Disconnect()
		end
		Creature.Connections.Walk = {}
	end
end

--local speedInterpolatedCameraPreviewIntent = UtilFunctions.Lerp(Vector3.new(0,0,0), previewIntent, math.clamp(speed / maxSpeedReference, 0, 1))

function processMovements(deltaTime:number, moveIntent:Vector3, rotateIntent:Vector3, rotationYawChangeSpeedMax:number)
	CameraController.SetViewBehind( moveIntent.Z < -0.1)
 	
	if math.abs(rotateIntent.Y) <= 0.2 then
		currentTimeNoRotationInput += deltaTime

		local previewYDecreasePercentPerSeconds = UtilFunctions.NumberSequenceResolve(autoRotationPreviewAllInputDecreaseCurve,NumberRange.new(0, autoRotationPreviewAllInputDecreaseCurveKeyTime),NumberRange.new(0,1), currentTimeNoRotationInput)
		local sign = -math.sign(CameraController.GetPreviewOffset().Y)

		local delta = rotateIntent.Y - CameraController.GetPreviewOffset().Y
	
		local previewY =  CameraController.GetPreviewOffset().Y + sign * math.min(previewYDecreasePercentPerSeconds * 1 * deltaTime ,   math.abs(delta))
		previewY = UtilFunctions.Clamp(previewY, -1,1)
 
		CameraController.SetPreviewOffset(Vector3.new(0, previewY , 0))
	else
		currentTimeNoRotationInput = 0
	end
  	 
	local finalTranslation = Creature.PrimaryPart.CFrame.LookVector * Creature.Humanoid.WalkSpeed  * math.sign(moveIntent.Z)

	Creature.Humanoid:MoveTo(Creature.PrimaryPart.Position + finalTranslation)

	local finalRotationY = 0

	if CameraController.IsInManualRotationMode() and math.abs(finalTranslation.Z) > 0.05 then
		local _,cameraY,_ =  Workspace.CurrentCamera.CFrame:ToOrientation()
		local _,creatureY,_ =  Creature.PrimaryPart.CFrame:ToOrientation()

		creatureY, cameraY = UtilFunctions.ShortestRotationCycle(creatureY, cameraY)

		local newRotation
		newRotation,  cameraForceRotationSpeed = UtilFunctions.SmoothDamp(creatureY, cameraY, cameraForceRotationSpeed, 0.1, 10000, deltaTime)
		local deltaRotationFromCreatureToCamera = newRotation - creatureY

		finalRotationY =  deltaRotationFromCreatureToCamera
	else
		cameraForceRotationSpeed = 0
		local targetYawRotationPerSecond = -math.sign(rotateIntent.Y) * UtilFunctions.Lerp(0, rotationYawPerSecondsMax, math.abs(rotateIntent.Y)) 
		
		if math.sign(targetYawRotationPerSecond) ~= math.sign(currentYawRotationDirection)  then
			currentYawRotationDirection = 0
		end

		local delta = targetYawRotationPerSecond - currentYawRotationDirection
		local yawRotationVectorChange = math.sign(delta) * rotationYawChangeSpeedMax * deltaTime;
		currentYawRotationDirection  += math.sign(yawRotationVectorChange) * math.min(math.abs(delta), math.abs(yawRotationVectorChange))
		finalRotationY = math.rad( currentYawRotationDirection * deltaTime)
	end
	Creature.PrimaryPart.CFrame = Creature.PrimaryPart.CFrame * CFrame.Angles(0,finalRotationY,0)
end


function KeepForwardBackwardWhenRotating(deltaTime:number, moveIntent:Vector3, rotateIntent:Vector3)
	local velocityZ = Creature.PrimaryPart.CFrame:VectorToObjectSpace(  Creature.PrimaryPart.Velocity).Z

	if math.abs(moveIntent.Z) < 0.1 and math.abs(rotateIntent.Y) > 0 then -- if player only want to rotate
		if keepMove then -- and was alraedy moving forward/backward
			moveIntent = Vector3.new(0,0, keepMoveSens) -- keep the movemen direction
		end
	elseif math.abs(moveIntent.Z) > 0.1 then
		keepMove = true	

		if  moveIntent.Z >= 0 then
			keepMoveSens = 1 
		else
			keepMoveSens = -1
		end
		moveIntent = Vector3.new(0,0, keepMoveSens)
	else
		keepMove = false
	end
	
	return moveIntent, rotateIntent
end

function processAnalogic(deltaTime:number)
	local rotateIntent = MovementGroundAnalogicFilter.GetRotationIntentVector()
	local moveIntent = MovementGroundAnalogicFilter.GetMovementIntentVector()
	
	local velocityZ = Creature.PrimaryPart.CFrame:VectorToObjectSpace(Creature.PrimaryPart.Velocity).Z

	moveIntent, rotateIntent = KeepForwardBackwardWhenRotating(deltaTime, moveIntent, rotateIntent)
	
	local newIntentRotationY = math.sign(rotateIntent.Y) *   UtilFunctions.NumberSequenceResolve(rotationYawJoystickCurve, NumberRange.new(0,1),NumberRange.new(0,1),  math.abs(rotateIntent.Y))
	rotateIntent = Vector3.new(rotateIntent.X,newIntentRotationY,rotateIntent.Z)
	
	if (moveIntent.Z > 0 and velocityZ >= maximimumBackwardSpeedForForward) or (moveIntent.Z < 0 and velocityZ <= -maximimumForwardSpeedForBackward) then -- reverse velocity only at slow speed
		moveIntent = Vector3.new(moveIntent.X,moveIntent.Y,-moveIntent.Z)
	end
	
	if (math.abs(rotateIntent.Y) >= 0.2) then
		local previewY = -math.sign(rotateIntent.Y) * UtilFunctions.NumberSequenceResolve(rotationYawJoystickCurve, NumberRange.new(0,1),NumberRange.new(0,1),  math.abs(rotateIntent.Y))	 

		CameraController.SetPreviewOffset(Vector3.new(0, previewY , 0))
	end

	processMovements(deltaTime, moveIntent, rotateIntent, rotationYawJoystickChangeSpeed)
end

function processKeyboard(deltaTime:number )
	local rotateIntent = MovementGroundKeyboardFilter.GetRotationIntentVector()
	local moveIntent = MovementGroundKeyboardFilter.GetMovementIntentVector()
 	
	moveIntent, rotateIntent = KeepForwardBackwardWhenRotating(deltaTime, moveIntent, rotateIntent)
  
	if lastKeyboardYawDirection ~= rotateIntent.Y   then
		currentTimeSameKeyboardDirection = 0
	else
		currentTimeSameKeyboardDirection += deltaTime		
	end

	lastKeyboardYawDirection = rotateIntent.Y

	if rotateIntent.Y ~= 0 then 
		local keyboardPreviewYChangePercentPerSeconds = UtilFunctions.NumberSequenceResolve(autoRotationPreviewKeyboardIncreaseCurve,NumberRange.new(0, autoRotationPreviewKeyboardIncreaseCurveKeyTime),NumberRange.new(0,1), currentTimeSameKeyboardDirection)
		
		local sign = -math.sign(rotateIntent.Y)
		local delta = -rotateIntent.Y - CameraController.GetPreviewOffset().Y
	 
		local change = math.min(keyboardPreviewYChangePercentPerSeconds * deltaTime ,   math.abs(delta))

 		if math.sign(CameraController.GetPreviewOffset().Y) ~= sign then
			change *= 3
		 end

 		local keyboardPreviewY = CameraController.GetPreviewOffset().Y + sign * change
 	
 		keyboardPreviewY = UtilFunctions.Clamp(keyboardPreviewY, -1,1)

 		CameraController.SetPreviewOffset(Vector3.new(rotateIntent.X, keyboardPreviewY , rotateIntent.Z))
	end
		
 
	processMovements(deltaTime, moveIntent, rotateIntent, rotationYawKeyboardChangeSpeed)
end
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
function processControl(deltaTime:number)	
	if Creature.CurrentTerrain ~= "Air" and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		if MovementGroundAnalogicFilter.IsActive() then -- if the joystick (virtual or real) is used and outside of its deadzone
			processAnalogic(deltaTime)
		else
			processKeyboard(deltaTime)
		end
	end
end

function RenderStepped(deltaTime:number)
	processControl(deltaTime)
end

function HorseWalk:Init(NewCreature)
	Creature = NewCreature
	Creature.Connections.Walk = {}
	self:SetStyle("Gallop")
end

function HorseWalk:SetEnabled(State)

	if State == enabled then
		return
	end
	enabled = State
	MovementGroundAnalogicFilter.SetEnabled(State)
	MovementGroundKeyboardFilter.SetEnabled(State)
	CameraController.SetEnabled(State)
	if State == true then
		self.Styles[currentStyle](Creature)
	else
		TerminateConnections()
	end
end

function HorseWalk:SetStyle(StyleName)

	if currentStyle == StyleName then
		return
	end

	if self.Styles[StyleName] then
		currentStyle = StyleName

		--Send change style event for animation human
		HorseEvents.CreatureChangeStyle:FireServer(currentStyle)
		
		TerminateConnections()
		local CurrentMovementAnimation = Creature.Animator.CurrentMovementAnimation
		if Creature.CurrentTerrain == "Land" and CurrentMovementAnimation.Animation.Name ~= StyleName then
			if CurrentMovementAnimation and CurrentMovementAnimation.IsPlaying then
				CurrentMovementAnimation:Stop()
			end
			Creature.Animator:SetMovementAnimation(StyleName)
		end
		if enabled then		
			self.Styles[StyleName](Creature)
		end
	else
		warn("No walk style named "..StyleName)
	end

end



function HorseWalk:SetSpeedModifier(StyleName)
	if self.Styles[StyleName] then
		local CurrentMovementAnimation = Creature.Animator.CurrentMovementAnimation
		if Creature.CurrentTerrain == "Land" and CurrentMovementAnimation.Animation.Name ~= StyleName then
			if CurrentMovementAnimation and CurrentMovementAnimation.IsPlaying then
				CurrentMovementAnimation:Stop()
			end
			Creature.Animator:SetMovementAnimation(StyleName)
		end
		self.Styles[StyleName](Creature)
	else
		warn("No walk style named "..StyleName)
	end
end

HorseWalk.Styles = {}

HorseWalk.Styles.Walk = function()
	MovementGroundAnalogicFilter.SetJoystickForwardWhenRotatingMagnitudeTreshold(walkingJoystickForwardWhenRotatingMagnitudeTreshold)
	MovementGroundAnalogicFilter.SetJoystickBackwardWhenRotatingMagnitudeTreshold(walkingJoystickBackwardWhenRotatingMagnitudeTreshold)
	MovementGroundAnalogicFilter.SetForwardAngleTreshold(walkingJoystickForwardAngleTreshold)
	MovementGroundAnalogicFilter.SetBackwardAngleTreshold(walkingJoystickBackwardAngleTreshold)
	MovementGroundAnalogicFilter.SetOnlyForwardDeadzoneAngle(walkingJoystickForwardOnlyAngle)
	MovementGroundAnalogicFilter.SetOnlyBackwardDeadzoneAngle(walkingJoystickBackwardOnlyAngle)

	CameraController.SetDistanceCurve(walkCameraDistanceCurve, walkCameraDistanceCurveValueDistanceRange )
	CameraController.SetFovCurve(walkCameraFovCurve,walkCameraFovCurveValueAngleRange )
	CameraController.SetAutoRotationOffsetBySpeedCurve(walkCameraAutoRotationOffsetBySpeedCurveX, walkCameraAutoRotationOffsetBySpeedCurveY,walkCameraAutoRotationOffsetBySpeedCurveZ,walkCameraAutoRotationOffsetBySpeedCurveValuePositionRange)
	CameraController.SetAutoRotationState(true)
	CameraController.SetTargetPositionOffset( creatureCameraOffset )
	CameraController.SetTarget(humanoidRootpart)
	CameraController.SetRaycastIgnoreList({Creature.Instance,game.Players.LocalPlayer.Character})
	CameraController.SetRaycastGroup("CameraCollision")

	WalkSpeedModule.SetSpeedToWalk(Creature.Instance)

	Creature.Connections.Walk.RenderStepped = RunService.RenderStepped:Connect(RenderStepped)

end

HorseWalk.Styles.Gallop = function()
	MovementGroundAnalogicFilter.SetJoystickForwardWhenRotatingMagnitudeTreshold(gallopJoystickForwardWhenRotatingMagnitudeTreshold)
	MovementGroundAnalogicFilter.SetJoystickBackwardWhenRotatingMagnitudeTreshold(gallopJoystickBackwardWhenRotatingMagnitudeTreshold)
	MovementGroundAnalogicFilter.SetForwardAngleTreshold(gallopJoystickForwardAngleTreshold)
	MovementGroundAnalogicFilter.SetBackwardAngleTreshold(gallopJoystickBackwardAngleTreshold)
	MovementGroundAnalogicFilter.SetOnlyForwardDeadzoneAngle(gallopJoystickForwardOnlyAngle)
	MovementGroundAnalogicFilter.SetOnlyBackwardDeadzoneAngle(gallopJoystickBackwardOnlyAngle)

	CameraController.SetDistanceCurve(gallopCameraDistanceCurve,gallopCameraDistanceCurveValueDistanceRange)
	CameraController.SetFovCurve(gallopCameraFovCurve,gallopCameraFovCurveValueAngleRange)
	CameraController.SetAutoRotationOffsetBySpeedCurve(gallopCameraAutoRotationOffsetBySpeedCurveX,gallopCameraAutoRotationOffsetBySpeedCurveY,gallopCameraAutoRotationOffsetBySpeedCurveZ,gallopCameraAutoRotationOffsetBySpeedCurveValuePositionRange)
	CameraController.SetAutoRotationState(true)
	CameraController.SetTargetPositionOffset( creatureCameraOffset )
	CameraController.SetTarget(humanoidRootpart)
	CameraController.SetRaycastIgnoreList({Creature.Instance,game.Players.LocalPlayer.Character})
	CameraController.SetRaycastGroup("CameraCollision")

	WalkSpeedModule.SetSpeedToRun(Creature.Instance)

	Creature.Connections.Walk.RenderStepped = RunService.RenderStepped:Connect(RenderStepped)

end

HorseEvents.SizeRatioChanged.OnClientEvent:Connect(function(ratio, reset)
	if reset then
		gallopCameraDistanceCurveValueDistanceRange = script:GetAttribute("gallopCameraDistanceCurveValueDistanceRange")
		walkCameraDistanceCurveValueDistanceRange = script:GetAttribute("walkCameraDistanceCurveValueDistanceRange")
	else
		gallopCameraDistanceCurveValueDistanceRange = NumberRange.new(gallopCameraDistanceCurveValueDistanceRange.Min * ratio, gallopCameraDistanceCurveValueDistanceRange.Max * ratio)
		walkCameraDistanceCurveValueDistanceRange = NumberRange.new(walkCameraDistanceCurveValueDistanceRange.Min * ratio, walkCameraDistanceCurveValueDistanceRange.Max * ratio)
	end
end)

--Check for ever if Creature Exist and if player are on the horse and moving, give EXP to horse
--[[ task.spawn(function()
	while true do
		if Creature then
			if LocalPlayer.Character.Humanoid.MoveDirection.Magnitude > 0 then
				if Creature.Instance then
					local rider = Creature.Instance.Seat:FindFirstChild("Rider")
					if rider then
						if rider.Value then
							RemoteEventFolder.GiveExpToCreature:FireServer(Creature.Instance.CreatureID.Value, 10)
							--print("TEST", "GIVE XP WITH WALKING", Creature.Instance.CreatureID.Value)
						end
					end

				end
			end
		end

		task.wait(5)
	end
end) ]]

return HorseWalk
