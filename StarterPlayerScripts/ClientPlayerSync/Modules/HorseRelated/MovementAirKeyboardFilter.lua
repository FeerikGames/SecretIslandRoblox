local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)
 
MovementAirKeyboardFilter = {}

local connections = {}
local enabled = false
 

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

function UpdateMoveIntent(deltaTime:number)
 
	
end

function UpdateRotateIntent(deltaTime:number)
	local isForwardPressed = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local isBackwardPressed = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local isLeftPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local isRightPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
	
	rotationVector = Vector3.new()

	if (isForwardPressed) then
		rotationVector += Vector3.new(1,0,0)
	end
	if (isBackwardPressed) then
		rotationVector += Vector3.new(-1,0,0)
	end
	if (isLeftPressed) then
		rotationVector += Vector3.new(0,1,0)
	end
	if (isRightPressed) then
		rotationVector += Vector3.new(0,-1,0)
	end
end

 
function RenderStepped(deltaTime:number)
	UpdateMoveIntent(deltaTime)
	UpdateRotateIntent(deltaTime)
end

function MovementAirKeyboardFilter.SetEnabled(newState:boolean)
	if enabled == newState then
		return
	end

	enabled = newState

	if enabled then
		connections.RenderStepped = RunService.RenderStepped:Connect(RenderStepped)
 	
	else
		TerminateConnections()
	end
end
  
function MovementAirKeyboardFilter.GetMovementIntentVector()
	return moveVector
end

function MovementAirKeyboardFilter.GetRotationIntentVector()
	return rotationVector
end
 

return MovementAirKeyboardFilter