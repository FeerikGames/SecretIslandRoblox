local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local RemoteEvent = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("RemoteEvent")
local InitPetEvolutionRemoteEvent = RemoteEvent.CreatureEvolution.InitPetEvolution::RemoteEvent
local triggerTagName = "PetEvolutionTrigger"

local triggerTouchedConnections: { [Instance]: RBXScriptConnection } = {}
local playersInZoneByTrigger: { [BasePart]: { [Player]: boolean } } = {}
local lockedPlayers: { [Player]: boolean } = {}

local PLAYER_LOCK_DURATION = 1 -- in seconds

local function onPartTouch(trigger: BasePart, otherPart: BasePart)
	local model = otherPart:FindFirstAncestorOfClass("Model")

	if not model then -- we search only models to get player characters
		return
	end

	if model.PrimaryPart ~= otherPart then -- avoid multiple call for each character part, use only the root part
		return
	end

	local player = Players:GetPlayerFromCharacter(model)

	if not player then -- we search only player models
		return
	end

	if lockedPlayers[player] then -- ignore locked players
		return
	end

	local playersInZone = playersInZoneByTrigger[trigger]

	if not playersInZone then -- init trigger player in zone list if do not exist yet
		playersInZone = {}
		playersInZoneByTrigger[trigger] = playersInZone
	end

	if playersInZone[player] then -- ignore player already inside the trigger zone
		return
	end

	playersInZone[player] = true -- register player in trigger zone
	lockedPlayers[player] = true -- lock the player to block next touch event

	InitPetEvolutionRemoteEvent:FireClient(player)
end

local function OnInstanceAdded(instance: Instance) -- instance with the expected tag added
	if not instance:IsA("BasePart") then
		return
	end

	local trigger = instance :: BasePart

	triggerTouchedConnections[trigger] = trigger.Touched:Connect(function(otherPart) -- register the touch event
		onPartTouch(trigger, otherPart)
	end)
end

local function OnInstanceRemoved(instance: Instance) -- instance with the expected tag removed
	local touchConnection = triggerTouchedConnections[instance]

	if touchConnection then
		touchConnection:Disconnect() -- do not listen touched event anymore
		triggerTouchedConnections[instance] = nil
	end
end

local function OnPostSimulation() -- called each time the physic simulation is done
	for trigger, playersInZone in pairs(playersInZoneByTrigger) do -- for each trigger with their player in zone list
		for player, _ in pairs(playersInZone) do -- for each player in the trigger player in zone list
			local playerPrimaryPart = player.Character.PrimaryPart

			if not player.Character or not player.Character.PrimaryPart then -- if player is dead ? reset
				playersInZone[player] = nil
				lockedPlayers[player] = nil
				continue
			end

			local triggerRadius = math.max(trigger.Size.X, trigger.Size.Z) * 0.5 -- compute the max trigger radius detection
			local playerRadius = math.max(playerPrimaryPart.Size.X, playerPrimaryPart.Size.Z) * 0.5 -- compute the max player radius detection

			local detectionRadius = (triggerRadius + playerRadius) * 1.2 -- compute the merged player/trigger radius detection with extra 20%

			local deltaPosition = player.Character.PrimaryPart.CFrame.Position - trigger.CFrame.Position -- compute delta position
			local distance = deltaPosition.Magnitude -- to get the distance between trigger and player

			if distance ~= distance then -- nan check
				distance = 0
			end

			if distance > detectionRadius then -- if the player is outside the detection radius
				playersInZone[player] = nil -- the player is not inside the zone and

				task.delay(PLAYER_LOCK_DURATION, function() -- after PLAYER_LOCK_DURATION seconds
					lockedPlayers[player] = nil -- unlock the player to let him able to re-fire the enter event
				end)
			end
		end
	end
end

CollectionService:GetInstanceAddedSignal(triggerTagName):Connect(OnInstanceAdded) -- register the callback called when the expected tag is applied on a instance
CollectionService:GetInstanceRemovedSignal(triggerTagName):Connect(OnInstanceRemoved)-- register the callback called when the expected tag is removed from a instance

local triggersAlreadyInMap = CollectionService:GetTagged(triggerTagName) -- get already tagged triggers
for _, trigger in ipairs(triggersAlreadyInMap) do -- for each of them
	OnInstanceAdded(trigger) -- call manually the callback to register them as pet creation trigger
end

RunService.PostSimulation:Connect(OnPostSimulation) -- listen each post physic simulation step
