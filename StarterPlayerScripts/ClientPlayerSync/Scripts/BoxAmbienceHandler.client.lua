local PhysicsService = game:GetService("PhysicsService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local ZoneModule = require("Zone")
local AmbienceModule = require("AmbienceModule")
local CharacterHandler = require("CharacterAndMountHandler")
local AmbianceParticules = require("AmbianceParticules")
local UIAnimationModule = require("UIAnimationModule")
local PlayerDataModule = require("ReplicatedPlayerData")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

local Regions = ReplicatedStorage.SharedSync.Assets.BoxAmbienceSettings.Regions
Regions.Parent = workspace

--Create a new atmosphere object with our presets ambience
local MainAmbience = AmbienceModule.new(ReplicatedStorage.SharedSync.Assets.BoxAmbienceSettings.Presets)

local Zones = {}
local ZonesStacks = {}
local ZonesPriority = {}

local Player = game.Players.LocalPlayer
local InDamageArea = false
--Make a attribute to allow other script client to know status of InDamageArea
Player:SetAttribute("InDamageArea", false)
Player:GetAttributeChangedSignal("InDamageArea"):Connect(function()
	InDamageArea = Player:GetAttribute("InDamageArea")
end)

--[[
	This little function allow to start a thread function to make damage when player are in damage Area and stop function when is exited of area damage.
	We check if damage are send to creature or player
	Launch animation and stop when player enter or leave Area Damage
]]
local function SpawnDamageArea(damageArea)
	task.spawn(function()
		while InDamageArea do
			local isMount = CharacterHandler.Mount and true or false
			RemoteEvent.GroundMaterialChange:FireServer(Enum.Material[damageArea], isMount)
			if damageArea == "Ice" then
				UIAnimationModule.OnFrozenFeedbackUI(true, isMount and PlayerDataModule.LocalData.CreaturesCollection[CharacterHandler.Mount.ID].Race == "Ice" or false)
			elseif damageArea == "CrackedLava" then
				UIAnimationModule.OnFireFeedbackUI(true, isMount and PlayerDataModule.LocalData.CreaturesCollection[CharacterHandler.Mount.ID].Race == "Fire" or false)
			end
			task.wait(.3)
		end
		UIAnimationModule.OnFrozenFeedbackUI(false, false)
		UIAnimationModule.OnFireFeedbackUI(false, false)
	end)
end

for _, v in pairs(Regions:GetChildren()) do
    --Create a zone and store it in the table with the folders name
	Zones[v.Name] = ZoneModule.new(v)
	
    --Relocates it back out of workspace and allow to area not interact with other part in world (exemple camera collision)
	Zones[v.Name]:relocate()

	--Store the Priority value of Area
	ZonesPriority[v.Name] = v:GetAttribute("PriorityLayer")
	
    --Binds to group Zones so PlayerEntered is only called after all PlayerExit calls of current active zones
	--Zones[v.Name]:bindToGroup("Zones")
	
	Zones[v.Name].localPlayerEntered:Connect(function()
		print("TEST ENTER IN ZONE", v.Name)

		table.insert(ZonesStacks, v.Name)

		--Check priority for play or not change ambience
		local canPlayChange = false
		if #ZonesStacks > 1 then
			print("TEST PRIORITY", ZonesPriority[v.Name] , ZonesPriority[ZonesStacks[#ZonesStacks]])
			if ZonesPriority[v.Name] >= ZonesPriority[ZonesStacks[#ZonesStacks-1]] then
				canPlayChange = true
			end
		else
			canPlayChange = true
		end
		
		if canPlayChange then
			MainAmbience:ChangeAmbience(v.Name)
			AmbianceParticules:ActivateAmbianceParticulesFolder(v.Name)

			--Check if it's damage area to change attribute and make damage
			local damageArea = v:GetAttribute("DamageArea")
			if damageArea ~= "" then
				Player:SetAttribute("InDamageArea", true)
				SpawnDamageArea(damageArea)
			end

			--TODO Voir ce qu'on fait avec les particle car ici ça marche plus avec les layers priority
			--Check if zone have some ParticleEmitter object as child to create place holder in world
			local Parent = workspace:FindFirstChild("RegionsPreview") or workspace
			if not Parent:FindFirstChild(v.Name) then
				local Folder = Instance.new("Folder", Parent)
				Folder.Name = v.Name
				for _, areaPart in pairs(v:GetChildren()) do
					if areaPart:FindFirstChildOfClass("ParticleEmitter") then
						local c = areaPart:Clone()
						c.Anchored = true
						c.CanCollide = false
						c.Transparency = 1
						c.CanQuery = false
						c.CanTouch = false
						c.CollisionGroup = "CameraCollision"
						c.Parent = Folder
					end
				end
			end
		end
	end)
	
	Zones[v.Name].localPlayerExited:Connect(function()
		print("TEST EXIT OF ZONE", v.Name)

		--check if it's damage area to stop it damage take
		local damageArea = v:GetAttribute("DamageArea")
		if damageArea ~= "" then
			Player:SetAttribute("InDamageArea", false)
		end

		local id = table.find(ZonesStacks, v.Name)
		if id then
			table.remove(ZonesStacks, id)
			if #ZonesStacks > 0 then
				if ZonesStacks[#ZonesStacks] then
					MainAmbience:ChangeAmbience(ZonesStacks[#ZonesStacks])
				else
					MainAmbience:ChangeAmbience("Default")
				end
			else
				MainAmbience:ChangeAmbience("Default")
				AmbianceParticules:ActivateAmbianceParticulesFolder("Default")
			end
		end

		--If player exited area check if area have clone particle need to be destroyed
		local Parent = workspace:FindFirstChild("RegionsPreview") or workspace
		local exist = Parent:FindFirstChild(v.Name)
		if exist then
			exist:Destroy()
		end
	end)
end