local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")

local ClubsGui = UIProviderModule:GetUI("ClubsGui")
local Background = ClubsGui:WaitForChild("Background")
local drop = Background.KickPopup.DropDown
local menu = drop.Menu
local open = menu.Open.Value
local select = drop.Select

local function CloseDropDown()
	menu:TweenSize(UDim2.new(1, 0, 0, 0), "Out", "Sine", 0.15, true)
	wait(0.05)
	for _, button in pairs(menu:GetChildren()) do
		if button:IsA("TextButton") then
			button.Visible = false
		end
	end
	open = false
end

local function OpenDropDown()
	menu:TweenSize(UDim2.new(1, 0, 1.958, 0), "Out", "Sine", 0.15, true)
	for _, button in pairs(menu:GetChildren()) do
		if button:IsA("TextButton") then
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
			button.BackgroundTransparency = 0.8
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
		end)
		button.Activated:Connect(function()
			drop.SelectedOption.Value = button.Name
			drop.Selection.Text = button.Text
			CloseDropDown()
		end)
	end
end