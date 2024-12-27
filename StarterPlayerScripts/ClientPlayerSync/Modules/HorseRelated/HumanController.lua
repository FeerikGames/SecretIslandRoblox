local HumanController = {
	Active = false,
	Human = nil
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local RunService = game:GetService("RunService")
local AnimatorModule = require("HumanAnimator")

local function Lerp(v0, v1, t)
	return v0 + t * (v1 - v0)
end

local Connections = {}

local Actions = {

}

function HumanController:Enable(Character)

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local ExtraValues = {
		Humanoid = Humanoid,
		PrimaryPart = Character.PrimaryPart
	}
	for Index,Value in pairs(ExtraValues) do
		if Value == nil then
			warn("Failed to enable human, "..Index.." is nil.")
			return
		end
	end
	self.Active = true

	self.Human = AnimatorModule:Bind(Character)
	return self.Human
end

function HumanController:Disable()
	for _,Connection in pairs(Connections) do
		Connection:Disconnect()
	end
	if self.Human then
		for _,Animation in pairs(self.Human.AnimationConnections) do
			Animation:Disconnect()
		end
		for _,Animation in pairs(self.Human.Animations) do
			Animation:Stop()
		end
	end
	self.Active = false
end


return HumanController
