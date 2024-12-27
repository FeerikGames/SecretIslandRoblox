-- Stratiz 2021 :)
-- For use on projects that dont actually use nevermore
--- local ReplicatedStorage = game:GetService("ReplicatedStorage")
--- local require = require(ReplicatedStorage.SharedModules:WaitForChild("RequireModule"))
---
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
-- Aggregate modules
local Modules = {}

local ModulePaths = {
	RunService:IsClient() and Players.LocalPlayer:WaitForChild("PlayerScripts") or game:GetService("ServerScriptService"),
	ReplicatedStorage:WaitForChild("SharedCustom"),
	ReplicatedStorage:WaitForChild("SharedSync"),
}

for _,ModuleFolder in ipairs(ModulePaths) do
	for _,Module in pairs(ModuleFolder:GetDescendants()) do
		if Module:IsA("ModuleScript") then
			table.insert(Modules,Module)
		end
	end
	ModuleFolder.DescendantAdded:Connect(function(Module)
		if Module:IsA("ModuleScript") then
			table.insert(Modules,Module)
		end
	end)
end

----
local NevermoreLite = function(ModuleName)
	if typeof(ModuleName) == "Instance" then
		return require(ModuleName)
	end
	local TargetModule
	for _,Module in pairs(Modules) do
		if Module:IsA("ModuleScript") and Module.Name == ModuleName then
			if TargetModule then
				warn("!!! Duplicate module detected: "..ModuleName,2)
			else
				TargetModule = Module
			end
		end
	end
	if not TargetModule then
		error("!!! Module "..ModuleName.." not found !!!",3)
	end
	return require(TargetModule)
end

_G.require = NevermoreLite
return NevermoreLite