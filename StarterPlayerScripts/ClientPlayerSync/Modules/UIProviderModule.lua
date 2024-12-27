local ContentProvider = game:GetService("ContentProvider")

local UIProviderModule = {}
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local StarterGuiSync = PlayerGui:WaitForChild("StarterGuiSync")

ContentProvider:PreloadAsync(PlayerGui:GetDescendants())

print("UI PROVIDER LAUNCHED")

UIProviderModule.ListUI = {}

function UIProviderModule:GetUI(UiName)
	if self.ListUI[UiName] then
		return self.ListUI[UiName]
	else
		local Ui = PlayerGui:WaitForChild("StarterGuiSync"):WaitForChild(UiName)
		self.ListUI[UiName] = Ui
		return Ui
	end
end

function UIProviderModule:GetAllUI()
	return UIProviderModule.ListUI
end

for _,UIObject in ipairs(PlayerGui:GetDescendants()) do
	if UIObject:IsA("ScreenGui") then
		UIProviderModule.ListUI[UIObject.Name] = UIObject
		--print("UI PROVIDER", UIObject)
	end
end

--[[ task.delay(10, function()
	for index, value in ipairs(StarterGuiSync:GetChildren()) do
		print("VALUE", value.Name)
	end
end) ]]

return UIProviderModule