local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)



local joystickDeadzone:number = script:GetAttribute("joystickDeadzone")  
local joystickForwardAngleTreshold:number = script:GetAttribute("joystickForwardAngleTreshold")   -- degree
local joystickBackwardAngleTreshold:number = script:GetAttribute("joystickBackwardAngleTreshold")   -- degree
local joystickForwardOnlyAngle:number = script:GetAttribute("joystickForwardOnlyAngle")   -- degree
local joystickBackwardOnlyAngle:number = script:GetAttribute("joystickBackwardOnlyAngle")   -- degree
local joystickForwardWhenRotatingMagnitudeTreshold:number  = script:GetAttribute("joystickForwardWhenRotatingMagnitudeTreshold") 
local joystickBackwardWhenRotatingMagnitudeTreshold:number = script:GetAttribute("joystickBackwardWhenRotatingMagnitudeTreshold") 


MovementGroundAnalogicFilter = {}

local connections = {}
local enabled = false
local active = false

local currentAnalogicAngle = 0

local moveVector:Vector3 = Vector3.new(0,0,0)
local rotationVector:Vector3 = Vector3.new(0,0,0)

function TerminateConnections()
	if connections then
		for _,connection in pairs(connections) do
			connection:Disconnect()
		end
		connections = {}
	end
end

function processDirection(direction:Vector2)
	local joystickAngle = math.atan2(direction.Y,direction.X )
	currentAnalogicAngle = joystickAngle

	active = direction.Magnitude > joystickDeadzone

	if active then
		local joystickForwardHalfAngleTresholdRad = math.rad(joystickForwardAngleTreshold/2 ) 
		local joystickBackwardHalfAngleTresholdRad =  math.rad(joystickBackwardAngleTreshold /2 )

		local joystickForwardOnlyHalfAngleRad =  math.rad(joystickForwardOnlyAngle  /2)
		local joystickBackwardOnlyHalfAngleRad =  math.rad(joystickBackwardOnlyAngle /2 )

		local joystickAngleForwardReference = UtilFunctions.RepeatClampRadian(joystickAngle - math.pi / 2)
		local joystickAngleBackwardReference = UtilFunctions.RepeatClampRadian(joystickAngle + math.pi / 2)

		rotationVector = Vector3.new(0, math.clamp(direction.X, -1, 1) , 0)
		
		-- move forward/backward if only rotating and joystick Y reach threshold or was already moving forward/backward
		if moveVector.Z ~= 0 or direction.Y >= joystickForwardWhenRotatingMagnitudeTreshold or direction.Y <= -joystickBackwardWhenRotatingMagnitudeTreshold then
			if joystickAngleForwardReference > -joystickForwardOnlyHalfAngleRad and joystickAngleForwardReference < joystickForwardOnlyHalfAngleRad then -- if joystick in only forward angle
				moveVector = Vector3.new(0,0,direction.Y) -- forward
				rotationVector = Vector3.new(0,0,0)
			elseif joystickAngleBackwardReference > -joystickBackwardOnlyHalfAngleRad and joystickAngleBackwardReference < joystickBackwardOnlyHalfAngleRad then -- if joystick in only backward angle
				moveVector = Vector3.new(0,0,direction.Y)
				rotationVector = Vector3.new(0,0,0)
			else -- otherwise, handle the case when player is only rotating, if we reach the threshold, unlock the movement forward/backward
				if joystickAngleForwardReference > -joystickForwardHalfAngleTresholdRad and joystickAngleForwardReference < joystickForwardHalfAngleTresholdRad then
					moveVector = Vector3.new(0,0,direction.Y) -- forward
				elseif joystickAngleBackwardReference > -joystickBackwardHalfAngleTresholdRad and joystickAngleBackwardReference < joystickBackwardHalfAngleTresholdRad then
					moveVector = Vector3.new(0,0,direction.Y)
				end
			end
		end
 	else
		moveVector = Vector3.new(0,0,0)
	end
end


function TouchMoved(touch, processed)
	local movementVector:Vector3 = PlayerModule:GetControls():GetMoveVector()
	local	direction:Vector2  = Vector2.new(movementVector.X, -movementVector.Z)

	processDirection(direction)
end

function TouchEnd(touch, processed)
	local movementVector:Vector3 = PlayerModule:GetControls():GetMoveVector()
	local	direction:Vector2  = Vector2.new(movementVector.X, -movementVector.Z)

	processDirection(direction)
end


function InputChanged(input, processed)

	if input.UserInputType == Enum.UserInputType.Gamepad1   then
		if  input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local	direction:Vector2 = Vector2.new(input.Position.X, input.Position.Y)

			processDirection(direction)
		end
	end
end

 

function RenderStepped(deltaTime:number)
	 
end

function MovementGroundAnalogicFilter.SetEnabled(newState:boolean)
	if enabled == newState then
		return
	end

	enabled = newState

	if enabled then
		connections.RenderStepped = RunService.RenderStepped:Connect(RenderStepped)
		connections.InputChanged = UserInputService.InputChanged:Connect(InputChanged)
		connections.TouchMoved = UserInputService.TouchMoved:Connect(TouchMoved)
		connections.TouchEnded = UserInputService.TouchEnded:Connect(TouchEnd)
	else
		TerminateConnections()
	end
end


function MovementGroundAnalogicFilter.IsActive()
	return active
end

function MovementGroundAnalogicFilter.GetMovementIntentVector()
	return moveVector
end

function MovementGroundAnalogicFilter.GetRotationIntentVector()
	return rotationVector
end
 
function MovementGroundAnalogicFilter.SetForwardAngleTreshold(angle)
	joystickForwardAngleTreshold = angle
end

function MovementGroundAnalogicFilter.SetBackwardAngleTreshold(angle)
	joystickBackwardAngleTreshold = angle
end

function MovementGroundAnalogicFilter.SetOnlyForwardDeadzoneAngle(angle)
	joystickForwardOnlyAngle = angle
end

function MovementGroundAnalogicFilter.SetOnlyBackwardDeadzoneAngle(angle)
	joystickBackwardOnlyAngle = angle
end

function MovementGroundAnalogicFilter.SetJoystickForwardWhenRotatingMagnitudeTreshold(magnitude:number)
	joystickForwardWhenRotatingMagnitudeTreshold = magnitude
end

function MovementGroundAnalogicFilter.SetJoystickBackwardWhenRotatingMagnitudeTreshold(magnitude:number)
	joystickBackwardWhenRotatingMagnitudeTreshold = magnitude
end

return MovementGroundAnalogicFilter