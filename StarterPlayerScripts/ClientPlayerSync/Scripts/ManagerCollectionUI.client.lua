local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui"):WaitForChild("StarterGuiSync")
local Mouse = Player:GetMouse()

--[[
	Allow to set dynamic size of scrolling frame with UIGrid or UIList
	/!\ Use a UIAspectRatioConstraint into a UIGrid or UIList /!\
]]
local function registerDynamicScrollingFrame(frame)
	local layout = frame:FindFirstChildWhichIsA("UIGridStyleLayout")
	local absoluteContentSize = layout.AbsoluteContentSize
	frame.CanvasSize = UDim2.new(0, 0, absoluteContentSize.Y, 0)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local absoluteContentSize = layout.AbsoluteContentSize
		frame.CanvasSize = UDim2.fromOffset(absoluteContentSize.X, absoluteContentSize.Y)
	end)
end

--[[
	Allow to set behavior of Object tagged as Tooltips to show text on hover this object and display
	the attribute TextHover value.
]]
local function setHoveringObjectTextMouse(obj)
	local ScreenGui:ScreenGui = UIProviderModule:GetUI("MouseHover")
	local TextLabel = ScreenGui:WaitForChild("TextLabel")

	obj.MouseMoved:Connect(function(x ,y)
		local textHover = obj:GetAttribute("TextHover")
		local mode = obj:GetAttribute("Mode")
		local ratio = Player.PlayerGui:FindFirstChild("TouchGui") and 1 or 1
		if textHover then

			if mode == "top" then
				TextLabel.AnchorPoint = Vector2.new(0.5,0)
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X/2, obj.AbsolutePosition.Y - obj.AbsoluteSize.Y*0.9)
			elseif mode == "bot" then
				TextLabel.AnchorPoint = Vector2.new(0.5,0)
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X/2, obj.AbsolutePosition.Y + obj.AbsoluteSize.Y*1.3)
			elseif mode == "left" then
				TextLabel.AnchorPoint = Vector2.new(0,0.5)
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X - obj.AbsoluteSize.X*1.7, obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2)
			elseif mode == "right" then
				TextLabel.AnchorPoint = Vector2.new(0,0.5)
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X*1.1, obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2)
			end

			--[[ if mode == "top" then
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X/2, (obj.AbsolutePosition.Y - obj.AbsoluteSize.Y*1.2)/ratio)
			elseif mode == "left" then
				TextLabel.Position = UDim2.fromOffset(((obj.AbsolutePosition.X - obj.AbsoluteSize.X))*ratio, obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2)
			elseif mode == "bot" then
				TextLabel.Position = UDim2.fromOffset(obj.AbsolutePosition.X + obj.AbsoluteSize.X/2, (obj.AbsolutePosition.Y + obj.AbsoluteSize.Y*1.2)*ratio)
			elseif mode == "right" then
				TextLabel.Position = UDim2.fromOffset(((obj.AbsolutePosition.X + obj.AbsoluteSize.X) + TextLabel.AbsoluteSize.X/2)*ratio, obj.AbsolutePosition.Y + obj.AbsoluteSize.Y/2)
			end ]]

			--[[ local Side = (ScreenGui.AbsoluteSize.Y/2) - Mouse.Y --If mouse is above the top half of screen -> value will be positive, if it is below half -> value will be negative
			local AdjustmentX, AdjustmentY = 1,1 --These adjustments will need tweaking depending on the rotation increment and tooltip frame size
			if Side >= 0 then --If mouse is topside (positive)
				TextLabel.Position = UDim2.fromOffset(Mouse.X - AdjustmentX,Mouse.Y - AdjustmentY)
			elseif Side < 0 then --If mouse is bottomside (negative)
				TextLabel.Position = UDim2.fromOffset(Mouse.X + AdjustmentX,Mouse.Y + AdjustmentY)
			end ]]

			TextLabel.Text = textHover
			TextLabel.Visible = true
		end
	end)


	obj.MouseLeave:Connect(function(x ,y)
		TextLabel.Visible = false
	end)

	if obj:IsA("ImageButton") then
		obj.Activated:Connect(function()
			TextLabel.Visible = false
		end)
	end
end

--[[
	Allow to change visibility of parented object who is a close ui button when activated button
]]
local function hideInterfaceParent(obj)
	obj.Activated:Connect(function()
		obj.Parent.Visible = false
	end)
end

local function DropDownBehavior(drop)
	local menu = drop.Menu
	local open = menu.Open.Value
	local select = drop.Select

	local function CloseDropDown()
		menu:TweenSize(UDim2.new(1, 0, 0, 0), "Out", "Sine", 0.15, true)
		task.wait(0.05)
		for _, button in pairs(menu:GetChildren()) do
			if button:IsA("TextButton") or button:IsA("ImageButton") then
				button.Visible = false
			end
		end
		open = false
	end
	
	local function OpenDropDown()
		local sizeOpen = menu:GetAttribute("SizeOpen")
		menu:TweenSize(sizeOpen or UDim2.new(1, 0, 1.958, 0), "Out", "Sine", 0.15, true)
		for _, button in pairs(menu:GetChildren()) do
			if button:IsA("TextButton") or button:IsA("ImageButton") then
				button.Visible = true
			end
		end
		open = true
	end
	
	select.Activated:Connect(function()
		if not open then
			OpenDropDown()
		else
			CloseDropDown()
		end
	end)

	for _, button in pairs(menu:GetChildren()) do
		if button:IsA("TextButton") then
			button.MouseEnter:Connect(function()
				button.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end)
			button.Activated:Connect(function()
				drop.SelectedOption.Value = button.Name
				drop.Selection.Text = button.Text
				CloseDropDown()
			end)
		elseif button:IsA("ImageButton") then
			button.MouseEnter:Connect(function()
				button.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
			end)
			button.MouseLeave:Connect(function()
				button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end)
			button.Activated:Connect(function()
				drop.SelectedOption.Value = button.Name
				drop.Selection.Image = button.Image
				CloseDropDown()
			end)
		end
	end

	-- Init dropdown with close it first
	CloseDropDown()
end

--This function allow to setup the checkbox behavior, if checked change image and this value to corresponding status check
local function CheckboxBehavior(obj)
	local EmptyCheckID = "rbxassetid://6401772806"
	local CheckedId = "rbxassetid://6401773001"

	obj.Activated:Connect(function()
		if obj.Check.Value then
			obj.Check.Value = false
			obj.Image = EmptyCheckID
		else
			obj.Check.Value = true
			obj.Image = CheckedId
		end
	end)

	obj.Check.Changed:Connect(function()
		if obj.Check.Value then
			obj.Image = CheckedId
		else
			obj.Image = EmptyCheckID
		end
	end)
end

--[[
	This function allow to set behavior animation of button when player hover or click on button
]]
local function ButtonBehavior(button)
	local originSize = button.Size

	local function leftMouseButtonUp()
		local info = TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		local tween = TweenService:Create(button, info, {Size = UDim2.fromScale(originSize.X.Scale, originSize.Y.Scale)})
		tween:Play()
	end

	local function leftMouseButtonDown()
		local info = TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
		local tween = TweenService:Create(button, info, {Size = UDim2.fromScale(originSize.X.Scale - 0.015, originSize.Y.Scale - 0.015)})
		tween:Play()
	end

	local animationActive = false
	local function animation(X, Y)
		if not animationActive then
			animationActive = true
			local info = TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
			local tween = TweenService:Create(button, info, {Size = UDim2.fromScale(originSize.X.Scale - 0.01, originSize.Y.Scale - 0.01)})
			tween:Play()
			
		end
	end

	if button:IsA("Button") or button:IsA("ImageButton") then
		button.MouseButton1Up:Connect(leftMouseButtonUp)
		button.MouseButton1Down:Connect(leftMouseButtonDown)
	end

	button.MouseMoved:Connect(animation)
	button.MouseLeave:Connect(function()
		if animationActive then
			animationActive = false
			local info = TweenInfo.new(.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In)
			local tween = TweenService:Create(button, info, {Size = UDim2.fromScale(originSize.X.Scale, originSize.Y.Scale)})
			tween:Play()
		end
	end)
end

--[[
	Catch all object with tag DynamicsScrolling for apply the dynamic size system
	Allow to not duplicate code in all object we need to dynamic scroll size
]]
CollectionService:GetInstanceAddedSignal("DynamicScrollingFrame"):Connect(registerDynamicScrollingFrame)
for _, frame in ipairs(CollectionService:GetTagged("DynamicScrollingFrame")) do
	registerDynamicScrollingFrame(frame)
end

--[[
	Catch all object with tag ObjectHoveringText for apply the hovering text object
]]
CollectionService:GetInstanceAddedSignal("ObjectHoveringText"):Connect(setHoveringObjectTextMouse)
for _, obj in ipairs(CollectionService:GetTagged("ObjectHoveringText")) do
	setHoveringObjectTextMouse(obj)
end

--[[
	Catch all object with tag HideUIButton for apply the closing interface visibility
]]
CollectionService:GetInstanceAddedSignal("HideUIButton"):Connect(hideInterfaceParent)
for _, obj in ipairs(CollectionService:GetTagged("HideUIButton")) do
	hideInterfaceParent(obj)
end

--[[
	Catch all object with tag DropDown for apply the bahavior of dropdoawn button
]]
CollectionService:GetInstanceAddedSignal("DropDown"):Connect(DropDownBehavior)
for _, obj in ipairs(CollectionService:GetTagged("DropDown")) do
	DropDownBehavior(obj)
end

--[[
	Catch all object with tag CheckBox for apply the behavior of checkbox change value
]]
CollectionService:GetInstanceAddedSignal("CheckBox"):Connect(CheckboxBehavior)
for _, obj in ipairs(CollectionService:GetTagged("CheckBox")) do
	CheckboxBehavior(obj)
end

--[[
	Catch all object with tag ButtonAnimation for apply the behavior of button interaction
]]
CollectionService:GetInstanceAddedSignal("ButtonAnimation"):Connect(ButtonBehavior)
for _, obj in ipairs(CollectionService:GetTagged("ButtonAnimation")) do
	ButtonBehavior(obj)
end
