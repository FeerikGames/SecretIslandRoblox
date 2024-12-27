local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)

local joystickDeadzone:number = script:GetAttribute("joystickDeadzone")  


MovementAirAnalogicFilter = {}

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
 		rotationVector = Vector3.new(math.clamp(direction.Y, -1, 1), math.clamp(-direction.X, -1, 1) , 0)
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

function MovementAirAnalogicFilter.SetEnabled(newState:boolean)
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


function MovementAirAnalogicFilter.IsActive()
	return active
end

function MovementAirAnalogicFilter.GetMovementIntentVector()
	return moveVector
end

function MovementAirAnalogicFilter.GetRotationIntentVector()
	return rotationVector
end

return MovementAirAnalogicFilter