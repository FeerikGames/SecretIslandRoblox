local module = {}
task.wait(5)
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local playerCollisionGroupName = "Humans"
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, "Horses", false)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, "CameraCollision", false)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, "SoccerWalls", false)
PhysicsService:CollisionGroupSetCollidable("Horses", "SoccerWalls", false)

local previousCollisionGroups = {}

local function setCollisionGroup(object)
	if object:IsA("BasePart") then
		previousCollisionGroups[object] = object.CollisionGroup
		object.CollisionGroup = playerCollisionGroupName
	end
end

local function setCollisionGroupRecursive(object)
	setCollisionGroup(object)

	for _, child in ipairs(object:GetChildren()) do
		setCollisionGroupRecursive(child)
	end
end

local function resetCollisionGroup(object)
	local previousCollisionGroupName = previousCollisionGroups[object]
	if not previousCollisionGroupName then return end

	object.CollisionGroup = previousCollisionGroupName
	previousCollisionGroups[object] = nil
end

local function onCharacterAdded(character)
	setCollisionGroupRecursive(character)

	character.DescendantAdded:Connect(setCollisionGroup)
	character.DescendantRemoving:Connect(resetCollisionGroup)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in pairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

return module
