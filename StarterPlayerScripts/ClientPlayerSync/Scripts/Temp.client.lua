-- Stratiz 9/22/2021

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

local StarterGui = game:GetService("StarterGui")
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)


local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local CharacterHandler = require("CharacterAndMountHandler")
CharacterHandler:Init()

--Don"t setup race function if its competition parade server
if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	require("ClientRaceHandler"):Init()
end

local Event = game:GetService("ReplicatedStorage").SharedSync.HorseEvents.HorseMountFunction

local currentfly = false

require("ClientDropsHandler"):Init()

local exist = workspace:FindFirstChild("Carriages")
if exist then
	for _,Carriage in ipairs(exist:GetChildren()) do
		local Prompt = Carriage.Root:FindFirstChildOfClass("ProximityPrompt")
		if Prompt then
			Prompt.Triggered:Connect(function()
				if CharacterHandler.Mount then
					local Attach = Instance.new("Attachment")
					Attach.Parent = CharacterHandler.Mount.PrimaryPart
					Prompt:Destroy()
					Carriage.Root.Rope.Attachment1 = Attach
				end
			end)
		end
	end
end