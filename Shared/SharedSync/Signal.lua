-- Stratiz 5/2021
-- 1st party signal module

local Bind = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BindableFolder = ReplicatedStorage:FindFirstChild("_bindables")
if not BindableFolder then
	BindableFolder = Instance.new("Folder")
	BindableFolder.Name = "_bindables"
	BindableFolder.Parent = ReplicatedStorage
end

Bind.new = function()
	local NewBind = Instance.new("BindableEvent")
	NewBind.Parent = BindableFolder
	local ReturnObject = {}
	function ReturnObject:Connect(...)
		return NewBind.Event:Connect(...)
	end
	function ReturnObject:Fire(...)
		NewBind:Fire(...)
	end
	return ReturnObject
end

return Bind