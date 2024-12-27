local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")

local Modules = PlayerScripts.ClientPlayerSync.Modules.AutoCall

for _, module in pairs(Modules:GetChildren()) do
	local loadMod = coroutine.create(function()
		require(module)
	end)

	coroutine.resume(loadMod)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage:WaitForChild("SharedSync").Modules:WaitForChild("RequireModule"))
local ReplicatedData = require("ReplicatedPlayerData")
ReplicatedData:Init()

local Cmdr = require(game.ReplicatedStorage:WaitForChild("CmdrClient"))
Cmdr:SetActivationKeys({Enum.KeyCode.F2})