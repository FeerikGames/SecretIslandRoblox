local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local UtilFunctions = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("UtilFunctions"))
local PlayerModule = require(Players.LocalPlayer.PlayerScripts.PlayerModule)
 
MovementGroundKeyboardFilter = {}

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
	moveVector = Vector3.new(0,0,0)
	
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector += Vector3.new(0,0,-1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector += Vector3.new(0,0,1)
	end

	
end

function UpdateRotateIntent(deltaTime:number)
	local isLeftPressed = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local isRightPressed = UserInputService:IsKeyDown(Enum.KeyCode.D)
	
	if isLeftPressed == isRightPressed then
		rotationVector = Vector3.new(0,0,0)
	else
		if isLeftPressed then
			rotationVector = Vector3.new(0,-1,0)
		else
			rotationVector = Vector3.new(0,1,0)
		end
	end
end

 
function RenderStepped(deltaTime:number)
	UpdateMoveIntent(deltaTime)
	UpdateRotateIntent(deltaTime)
end

function MovementGroundKeyboardFilter.SetEnabled(newState:boolean)
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
  
function MovementGroundKeyboardFilter.GetMovementIntentVector()
	return moveVector
end

function MovementGroundKeyboardFilter.GetRotationIntentVector()
	return rotationVector
end
 

return MovementGroundKeyboardFilter