local InputController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Signal = require("Signal")


InputController.CurrentInputMap = "Swimming"
InputController.MappedInputs = {}

local Inputs = {
	Global = {
		
	},
	Farming = {
		Place = {Enum.UserInputType.MouseButton1}
	},
	Flight = {
		Ascend = {Enum.KeyCode.Space}
	},
	Swimming = {
		Ascend = {Enum.KeyCode.Space}
	},
	Walking = {
		Jump = {Enum.KeyCode.Space}
	}
}

InputController.Inputs = {}

function InputController:SetInputMap(Name)
	InputController.CurrentInputMap = Name
end

function InputController:ActivateInput(Name,...)
	if self.Inputs[self.CurrentInputMap][Name] then
		if self.Inputs[self.CurrentInputMap][Name].Active == false then
			self.Inputs[self.CurrentInputMap][Name].Active = true
			self.Inputs[self.CurrentInputMap][Name].Activated:Fire(...)
		end
	else
		warn("Invalid input")
	end
end

function InputController:DeactivateInput(Name,...)
	if self.Inputs[self.CurrentInputMap][Name] then
		if self.Inputs[self.CurrentInputMap][Name].Active == true then
			self.Inputs[self.CurrentInputMap][Name].Active = false
			self.Inputs[self.CurrentInputMap][Name].Deactivated:Fire(...)
		end
	else
		warn("Invalid input")
	end
end

function InputController:Init()
	--// Add Signals to each Action
	for MapName,InputTable in pairs(Inputs) do
		if not self.Inputs[MapName] then
			self.Inputs[MapName] = {}
		end 
		for Name,_ in pairs(InputTable) do
			self.Inputs[MapName][Name] = {
				Activated = Signal.new(),
				Deactivated = Signal.new(),
				Active = false
			}
		end
	end
	
	--// Functions for checking if input is bound and activating their binds
	
	local function CheckAndActivate(InputObject,...) 
		for Name,InputTriggers in pairs(Inputs[InputController.CurrentInputMap]) do
			if table.find(InputTriggers,InputObject.KeyCode) or table.find(InputTriggers,InputObject.UserInputType) then
				InputController:ActivateInput(Name,...)
			end
		end
	end
	local function CheckAndDeactivate(InputObject,...)
		for Name,InputTriggers in pairs(Inputs[InputController.CurrentInputMap]) do
			if table.find(InputTriggers,InputObject.KeyCode) or table.find(InputTriggers,InputObject.UserInputType) then
				InputController:DeactivateInput(Name,...)
			end
		end
	end

	--// Detect controller change and load states
	local GamepadStates = {}
	local CurrentGamepadEnum = Enum.UserInputType.Gamepad1
	local function LoadGamepadStates(GamepadEnum)
		local RawGamepadStates = UserInputService:GetGamepadState(GamepadEnum)
		GamepadStates = {}
		for _,State in pairs(RawGamepadStates) do
			GamepadStates[State.KeyCode] = State
		end
		CurrentGamepadEnum = GamepadEnum
	end
	LoadGamepadStates(Enum.UserInputType.Gamepad1)
	UserInputService.GamepadConnected:Connect(LoadGamepadStates)
	UserInputService.GamepadDisconnected:Connect(function(GamepadEnum) 
		if GamepadEnum == CurrentGamepadEnum then
			for _,Gamepad in pairs(UserInputService:GetConnectedGamepads()) do
				LoadGamepadStates(GamepadEnum)
				break
			end
		end
	end)

	--// Detect controller analog input
	local ControllerAnalogInputs = {
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonL2
	}
	local ActivatedAnalogInputs = {}
	RunService.RenderStepped:Connect(function()
		if #UserInputService:GetConnectedGamepads() > 0 then
			for _,InputObject in pairs(GamepadStates) do
				if table.find(ControllerAnalogInputs,InputObject.KeyCode) then
					if InputObject.Position.Z >= 0.5 and not ActivatedAnalogInputs[InputObject.KeyCode] then
						ActivatedAnalogInputs[InputObject.KeyCode] = true
						CheckAndActivate(InputObject)
					elseif InputObject.Position.Z < 0.5 and ActivatedAnalogInputs[InputObject.KeyCode] then
						CheckAndDeactivate(InputObject)
						ActivatedAnalogInputs[InputObject.KeyCode] = false
					end
				end
			end
		end
	end)

	--// Detect digital Inputs and fire their signals
	UserInputService.InputBegan:Connect(function(InputObject,GameProcessed)
		if not GameProcessed and not table.find(ControllerAnalogInputs,InputObject.KeyCode) then
			CheckAndActivate(InputObject)
		end
	end)
	UserInputService.InputEnded:Connect(function(InputObject,GameProcessed)
		if not GameProcessed and not table.find(ControllerAnalogInputs,InputObject.KeyCode) then
			CheckAndDeactivate(InputObject)
		end
	end)

	--// Set CurrentInputType
	if UserInputService.GamepadEnabled then
		InputController.CurrentInputType = "Console"
	elseif UserInputService.TouchEnabled then
		InputController.CurrentInputType = "Mobile"
	else
		InputController.CurrentInputType = "Desktop"
	end

	--// Detect CurrentInputType changes from 'MouseMovement'
	UserInputService.InputChanged:Connect(function(InputObject)
		if InputObject.UserInputType == Enum.UserInputType.MouseMovement then
			if "Desktop" ~= InputController.CurrentInputType then
				InputController.CurrentInputType = "Desktop"
				--InputController.InputTypeChangedSignal:Fire("Desktop")
			end
		end
	end)

	--// Detect CurrentInputType changes from 'LastInputType'
	UserInputService.LastInputTypeChanged:Connect(function(LastType)
		local NewType = InputController:GetInputTypeString(LastType)
		if NewType and NewType ~= InputController.CurrentInputType then
			InputController.CurrentInputType = NewType
			--InputController.InputTypeChangedSignal:Fire(NewType)
		end
	end)
end

function InputController:GetInputTypeString(InputEnum)
	if InputEnum == Enum.UserInputType.Keyboard then
		return "Desktop"
	elseif InputEnum == Enum.UserInputType.Touch then
		return "Mobile"
	elseif string.match(tostring(InputEnum),"Gamepad") then
		return "Console"
	end
end

InputController:Init()

return InputController
