local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SelfieMode = require(ReplicatedStorage:WaitForChild("SelfieMode"))
local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents

local ROTATION_SPEED_KEYS = math.rad(120) -- (rad/s)
local ROTATION_SPEED_MOUSE = Vector2.new(1, 0.77)*math.rad(0.5) -- (rad/s)
local ROTATION_SPEED_POINTERACTION = Vector2.new(1, 0.77)*math.rad(7) -- (rad/s)
local ROTATION_SPEED_TOUCH = Vector2.new(1, 0.66)*math.rad(1) -- (rad/s)
local ROTATION_SPEED_GAMEPAD = Vector2.new(1, 0.77)*math.rad(4) -- (rad/s)

local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

CameraController = {}


local target = nil
local targetPositionOffet:Vector3 = script:GetAttribute("targetPositionOffset")
local maxSpeedReference:number = script:GetAttribute("maxSpeedReference")

local autoPreviewMax:Vector3 =script:GetAttribute("autoPreviewMax")-- degre
local autoPreviewSmoothTime:number =script:GetAttribute("autoPreviewSmoothTime")
local autoPreviewSmoothMaxVelocity:number = script:GetAttribute("autoPreviewSmoothMaxVelocity")

local autoTargetSmoothTime:number =script:GetAttribute("autoTargetSmoothTime")
local autoTargetSmoothMaxVelocity:number =script:GetAttribute("autoTargetSmoothMaxVelocity")

local distanceSmoothTime:number = script:GetAttribute("distanceSmoothTime")
local distanceSmoothVelocityMax:number = script:GetAttribute("distanceSmoothVelocityMax")

local fovSmoothTime:number = script:GetAttribute("fovSmoothTime")
local fovSmoothVelocityMax:number = script:GetAttribute("fovSmoothVelocityMax")

local autoSmoothTime:number = script:GetAttribute("autoSmoothTime")
local autoSmoothMaxVelocity:number = script:GetAttribute("autoSmoothMaxVelocity")

local autoRotationOffsetBySpeedCurveX:NumberSequence = script:GetAttribute("autoRotationOffsetBySpeedCurveX")
local autoRotationOffsetBySpeedCurveY:NumberSequence = script:GetAttribute("autoRotationOffsetBySpeedCurveY")
local autoRotationOffsetBySpeedCurveZ:NumberSequence = script:GetAttribute("autoRotationOffsetBySpeedCurveZ")
local autoRotationOffsetBySpeedCurveValueAngleRange:NumberRange  = script:GetAttribute("autoRotationOffsetBySpeedCurveValueAngleRange")

local distanceCurve:NumberSequence = script:GetAttribute("distanceCurve")
local distanceCurveValueDistanceRange:NumberRange = script:GetAttribute("distanceCurveValueDistanceRange")
local fovCurve:NumberSequence = script:GetAttribute("fovCurve")
local fovCurveValueAngleRange:NumberRange = script:GetAttribute("fovCurveValueAngleRange")

local cameraSize:Vector3 = script:GetAttribute("cameraSize")

local pauseAutoCameraTime:number = script:GetAttribute("pauseAutoCameraTime")

local currentAutoRotationGlobalPositionSmoothVelocity = Vector3.new(0,0,0)
local currentAutoRotationGlobalRotationSmoothVelocity = Vector3.new(0,0,0)

local currentAutoRotationRotationSmoothVelocity = Vector3.new(0,0,0)
local currentAutoRotationPreviewSmoothVelocity = Vector3.new(0,0,0)

local currentAutoTargetSmoothVelocity = Vector3.new(0,0,0)

local currentDistanceSmoothVelocity = 0
local currentFovSmoothVelocity = 0
local currentPreview = Vector3.new(0,0,0)

local currentTargetRotation = Vector3.new(0,0,0)

local isCameraAuto = true
local pauseAutoCameraTimer = 0

local enabled = false
local connections = {}
local touchManualRotationLocker = nil
local touchManualRotation = nil
local mouseManualRotation = false;
local joystickManualRotation = false
local joystickPosition = Vector2.new(0,0)

local previewIntent = Vector3.new(0,0,0) -- percent 0-1
local lookBehind:boolean = false
local finalTargetZoom = 10
local raycastIgnoreList = nil
local raycastGroup = 0

function TerminateConnections()
	if connections then
		for _,connection in pairs(connections) do
			connection:Disconnect()
		end
		connections = {}
	end
end

 
function SetCameraTransform(followingPosition:Vector3, direction:Vector3)

	local forwardDirectionPlanXZ = Vector3.new(direction.X, 0, direction.Z).Unit
	local rightDirection = CFrame.fromAxisAngle(Vector3.new(0,1,0), math.pi / 2):VectorToWorldSpace(forwardDirectionPlanXZ)
	local upDirection = direction:Cross(rightDirection)
 
 	local raycastParams = RaycastParams.new()
	
	local finalIgnoreList = raycastIgnoreList

	if  finalIgnoreList == nil  then
		finalIgnoreList =  {target}
 	end

	raycastParams.FilterDescendantsInstances = finalIgnoreList
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.CollisionGroup = raycastGroup

	local targetPosition = nil

	local raycastResult = workspace:Raycast(followingPosition, -direction * (finalTargetZoom + cameraSize.Z/2), raycastParams) -- cast camera back
 
	if raycastResult then
 		targetPosition = raycastResult.Position  + (cameraSize.Z/2) * direction
	end
	
	if not raycastResult then
		local raycastResult = workspace:Raycast(followingPosition, -direction * finalTargetZoom + rightDirection * cameraSize.X/2, raycastParams) -- cast camera right

		if raycastResult then
			targetPosition = raycastResult.Position  + rightDirection * cameraSize.X/2
		end
	end
	if not raycastResult then
		local raycastResult = workspace:Raycast(followingPosition, -direction * finalTargetZoom - rightDirection * cameraSize.X/2, raycastParams) -- cast camera left

		if raycastResult then
			targetPosition = raycastResult.Position  + rightDirection * cameraSize.X/2
		end
	end
	if not raycastResult then
		local raycastResult = workspace:Raycast(followingPosition, -direction * finalTargetZoom + upDirection * cameraSize.Y/2, raycastParams) -- cast camera top

		if raycastResult then
			targetPosition = raycastResult.Position  - upDirection * cameraSize.Y/2
		end
	end
	if not raycastResult then
		local raycastResult = workspace:Raycast(followingPosition, -direction * finalTargetZoom - upDirection * cameraSize.Y/2, raycastParams) -- cast camera bottom

		if raycastResult then
			targetPosition = raycastResult.Position + upDirection * cameraSize.Y/2
		end
	end

	if raycastResult then
		game.Players.LocalPlayer.CameraMinZoomDistance = (targetPosition - followingPosition).Magnitude
	else
 		targetPosition = followingPosition - direction * finalTargetZoom
		game.Players.LocalPlayer.CameraMinZoomDistance = finalTargetZoom
	end

	game.Players.LocalPlayer.CameraMaxZoomDistance = game.Players.LocalPlayer.CameraMinZoomDistance

	workspace.CurrentCamera.CFrame = CFrame.lookAt(targetPosition , followingPosition)
end



function processManualCameraRotation(delta:Vector2)
	local currPitchAngle = math.asin(workspace.CurrentCamera.CFrame.LookVector.y)
	local yTheta = math.clamp(delta.Y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput:Vector2 = Vector2.new(delta.X, yTheta)

	local followingPosition = target.CFrame.Position + targetPositionOffet
	local finalDirection = (CFrame.Angles(0, -constrainedRotateInput.X, 0) * workspace.CurrentCamera.CFrame * CFrame.Angles(-constrainedRotateInput.Y,0,0)).LookVector

	SetCameraTransform(followingPosition ,   finalDirection)
end


function TouchStarted(touch, processed)
	if processed then
		touchManualRotationLocker = touch
		return
	end

	if touchManualRotation ~= touch then
		return
	end
end

function TouchMoved(touch, processed)
	
	if processed or (touchManualRotation ~= nil and touch ~= touchManualRotation) or touchManualRotationLocker == touch then
		return
	end

	if touchManualRotation == nil then
		touchManualRotation = touch
	end
  
	processManualCameraRotation(Vector2.new(touch.Delta.X, touch.Delta.Y) * ROTATION_SPEED_TOUCH)
end

function TouchEnded(touch, processed)

	if touch ~= touchManualRotation then
		return
	end

	touchManualRotation = nil
end

function InputBegan(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		mouseManualRotation = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		UserInputService.MouseIconEnabled = false
	end
end

function InputChanged(input, processed)
	
	if input == touchManualRotationLocker then
		touchManualRotationLocker = nil
	end
	
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.Gamepad1   then
		if  input.KeyCode == Enum.KeyCode.Thumbstick2 then
			if input.Position.Magnitude > 0.1 then
				joystickManualRotation = true
				joystickPosition = input.Position
			else
				joystickManualRotation = false
			end
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement and mouseManualRotation then
		processManualCameraRotation(Vector2.new(input.Delta.X,input.Delta.Y) * ROTATION_SPEED_MOUSE)
	end

end

function InputEnded(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		mouseManualRotation = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function ComputeAutoMode(deltaTime:number)
	if touchManualRotation or mouseManualRotation or joystickManualRotation then
		isCameraAuto = false
		pauseAutoCameraTimer = 0
	else
		pauseAutoCameraTimer += deltaTime

		if pauseAutoCameraTimer >= pauseAutoCameraTime then
			isCameraAuto = true
		end
	end
end

function ComputeZoom(deltaTime:number)
	local speed = target.Velocity.Magnitude

	local targetZoom =  UtilFunctions.NumberSequenceResolve(distanceCurve,NumberRange.new(0,maxSpeedReference),distanceCurveValueDistanceRange,  speed)
	local smoothedZoom, newLerpZoomVelocity = UtilFunctions.SmoothDamp(finalTargetZoom, targetZoom, currentDistanceSmoothVelocity , distanceSmoothTime, distanceSmoothVelocityMax, deltaTime)
	currentDistanceSmoothVelocity = newLerpZoomVelocity

	finalTargetZoom = smoothedZoom
 end

function ComputeFov(deltaTime:number)
	local speed = target.Velocity.Magnitude

	local targetFOV = UtilFunctions.NumberSequenceResolve(fovCurve, NumberRange.new(0,maxSpeedReference),fovCurveValueAngleRange,  speed)
	local interpolatedFOV, newLerpFovVelocity  = UtilFunctions.SmoothDamp(workspace.CurrentCamera.FieldOfView, targetFOV, currentFovSmoothVelocity, fovSmoothTime, fovSmoothVelocityMax, deltaTime)
	currentFovSmoothVelocity = newLerpFovVelocity
	workspace.CurrentCamera.FieldOfView = interpolatedFOV
end

function ComputeAutoPreview(deltaTime:number)
	local speed = target.Velocity.Magnitude
 	 
	local targetPreview:Vector3 = previewIntent * Vector3.new(math.rad(autoPreviewMax.X),math.rad(autoPreviewMax.Y), math.rad(autoPreviewMax.Z))
	local interpolatedCameraPreview, newCameraPreviewSmoothVelocity = UtilFunctions.SmoothDampVector3(currentPreview, targetPreview, currentAutoRotationPreviewSmoothVelocity , autoPreviewSmoothTime, autoPreviewSmoothMaxVelocity, deltaTime)

	currentPreview = interpolatedCameraPreview
	currentAutoRotationPreviewSmoothVelocity = newCameraPreviewSmoothVelocity
end


function ComputeAutoRotationOffset(deltaTime:number)
	local speed = target.Velocity.Magnitude
	
	local targetAutoRotationOffset:Vector3 = UtilFunctions.NumberSequenceResolveVector3(autoRotationOffsetBySpeedCurveX,autoRotationOffsetBySpeedCurveY,autoRotationOffsetBySpeedCurveZ, NumberRange.new(0,maxSpeedReference),autoRotationOffsetBySpeedCurveValueAngleRange,  speed)
	
	return targetAutoRotationOffset
end

function ComputeAutoTarget(deltaTime:number)
	local horseRotationX, horseRotationY, horseRotationZ = target.CFrame:ToOrientation()
		
	if lookBehind then
		horseRotationY += math.pi
	end

	local targetAutoRotationOffset:Vector3 = ComputeAutoRotationOffset(deltaTime)

	local startRotation:Vector3 = currentTargetRotation
	local targetRotation:Vector3 = Vector3.new(math.rad( - targetAutoRotationOffset.X ), horseRotationY + math.rad( targetAutoRotationOffset.Y ),math.rad(targetAutoRotationOffset.Z ))
	
	local newStartRotation:Vector3, newTargetRotation:Vector3 = UtilFunctions.ShortestRotationCycleVector3(startRotation, targetRotation)
	
	local smoothedRotation, newSmoothedRotationVelocity = UtilFunctions.SmoothDampVector3(newStartRotation, newTargetRotation, currentAutoTargetSmoothVelocity , autoTargetSmoothTime, autoTargetSmoothMaxVelocity, deltaTime)

	currentTargetRotation = smoothedRotation
	currentAutoTargetSmoothVelocity = newSmoothedRotationVelocity
end

function ComputeAutoGlobal(deltaTime:number)
	local targetAutoRotationOffset:Vector3 = ComputeAutoRotationOffset(deltaTime)

	local startRotationX, startRotationY, startRotationZ = workspace.CurrentCamera.CFrame:ToOrientation()
	local startRotation:Vector3 = Vector3.new(startRotationX, startRotationY, startRotationZ)
	local targetRotation:Vector3 = currentTargetRotation + currentPreview
	
	local newStartRotation:Vector3, newTargetRotation:Vector3 = UtilFunctions.ShortestRotationCycleVector3(startRotation, targetRotation)
	
	local smoothedRotation, newSmoothedRotationVelocity = UtilFunctions.SmoothDampVector3(newStartRotation, newTargetRotation, currentAutoRotationRotationSmoothVelocity , autoSmoothTime, autoSmoothMaxVelocity, deltaTime)

	currentAutoRotationRotationSmoothVelocity = newSmoothedRotationVelocity
	  
	local followingPosition = target.CFrame.Position + targetPositionOffet
	local finalDirection = CFrame.fromOrientation(smoothedRotation.X,smoothedRotation.Y,smoothedRotation.Z).LookVector

	SetCameraTransform(followingPosition, finalDirection)
end

function ComputeAuto(deltaTime:number)
	ComputeAutoPreview(deltaTime)
	ComputeAutoTarget(deltaTime)

	ComputeAutoGlobal(deltaTime)

  end

function ResetTargetRotation()
	local startRotationX, startRotationY, startRotationZ = workspace.CurrentCamera.CFrame:ToOrientation()
	currentTargetRotation = Vector3.new(startRotationX,startRotationY, startRotationZ )
end

function OnRenderStepped(deltaTime:number)
	if (target == nil) or SelfieMode.isSelfieModeOpen() then
		return
	end

 	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable

	ComputeZoom(deltaTime)
	ComputeFov(deltaTime)

	if joystickManualRotation then
		processManualCameraRotation(Vector2.new(joystickPosition.X,-joystickPosition.Y) * ROTATION_SPEED_GAMEPAD)
		return
	end

	ComputeAutoMode(deltaTime)
	
 	if isCameraAuto then
		ComputeAuto(deltaTime)
	else
		ResetTargetRotation()
	end

	
	local followingPosition = target.CFrame.Position + targetPositionOffet
	local finalDirection = workspace.CurrentCamera.CFrame.LookVector

 	workspace.CurrentCamera.Focus = target.CFrame

	SetCameraTransform(followingPosition, finalDirection)
 end

 
function CameraController.SetRaycastIgnoreList(ignoreList)
	raycastIgnoreList = ignoreList
end

function CameraController.SetRaycastGroup(groupId)
	raycastGroup = groupId
end

function CameraController.SetAutoRotationTargetMaxSpeed(speed)
	autoTargetSmoothMaxVelocity = speed
end

function CameraController.SetEnabled(state)
	if state == enabled then
		return
	end

	enabled = state
	
	if state then
		ResetTargetRotation()
		connections.RenderStepped = RunService.RenderStepped:Connect(OnRenderStepped)

		connections.InputBegan = UserInputService.InputBegan:Connect(InputBegan)
		connections.InputChanged = UserInputService.InputChanged:Connect(InputChanged)
		connections.InputEnd = UserInputService.InputEnded:Connect(InputEnded)

		connections.TouchStarted = UserInputService.TouchStarted:Connect(TouchStarted)
		connections.TouchMoved = UserInputService.TouchMoved:Connect(TouchMoved)
		connections.TouchEnded = UserInputService.TouchEnded:Connect(TouchEnded)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true

		local plr = game.Players.LocalPlayer
		plr.CameraMaxZoomDistance = 50

		TerminateConnections()

		plr.CameraMinZoomDistance = 15
	end
end

function CameraController.GetEnabled()
	return enabled
end

function CameraController.GetTarget()
	return target
end

function CameraController.IsInManualRotationMode()
	return touchManualRotation or mouseManualRotation or joystickManualRotation
end

function CameraController.SetTarget(newTarget)
	target = newTarget
	if newTarget ~= nil then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	end
end

function CameraController.SetAutoRotationOffsetBySpeedCurve(curveX:NumberSequence, curveY:NumberSequence, curveZ:NumberSequence, valueRange:NumberRange)
	autoRotationOffsetBySpeedCurveX = curveX
	autoRotationOffsetBySpeedCurveY = curveY
	autoRotationOffsetBySpeedCurveZ = curveZ
	autoRotationOffsetBySpeedCurveValueAngleRange = valueRange
end

function CameraController.SetDistanceCurve(curve:NumberSequence ,valueRange:NumberRange)
	distanceCurve = curve
	distanceCurveValueDistanceRange = valueRange
end

function CameraController.SetFovCurve(curve:NumberSequence ,valueRange:NumberRange)
	fovCurve = curve
	fovCurveValueAngleRange = valueRange
end

function CameraController.IsCameraAuto()
	return isCameraAuto
end

function CameraController.SetAutoRotationState(state:boolean)
	isCameraAuto = state

	if state == false then
		pauseAutoCameraTimer = 0
	end
end

function CameraController.SetViewBehind(state:boolean)
	lookBehind = state
end

function CameraController.GetPreviewOffset()
	return previewIntent
end

function CameraController.SetPreviewOffset(rotationOffset:Vector3)
	previewIntent = Vector3.new(rotationOffset.X,rotationOffset.Y,rotationOffset.Z)
end

function CameraController.SetTargetPositionOffset(newTargetPositionOffset:Vector3)
	targetPositionOffet = newTargetPositionOffset
end

HorseEvents.SizeRatioChanged.OnClientEvent:Connect(function(ratio, reset)
	if reset then
		distanceCurveValueDistanceRange = script:GetAttribute("distanceCurveValueDistanceRange")
	else
		distanceCurveValueDistanceRange = NumberRange.new(distanceCurveValueDistanceRange.Min * ratio, distanceCurveValueDistanceRange.Max * ratio)
	end
end)

return CameraController