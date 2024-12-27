
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

-- Require
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local HeadReplicationEvent = HorseEvents:WaitForChild("HeadReplicationEvent")

local CharacterFolder = Instance.new("Folder")
CharacterFolder.Parent = workspace
CharacterFolder.Name = "CharacterFolder"

PhysicsService:RegisterCollisionGroup("Humans")
PhysicsService:RegisterCollisionGroup("PlacingObject")
PhysicsService:RegisterCollisionGroup("DroppingCollectable")
PhysicsService:CollisionGroupSetCollidable("Humans", "PlacingObject", false)
PhysicsService:CollisionGroupSetCollidable("Humans", "DroppingCollectable", false)

--[[
	This function allow to check if player enter in game after click on notification invitation.
	We have a little delay to detect data of notification so we attempt 10s mini for sur have or not have join data.
	If JoinData are founded we get the userid of sender invitation and the position of portal sommon player to move the player invited at the good place.
]]
local function CheckInvitationPlayer(player)
	local ATTEMPT_LIMIT = 10
	local RETRY_DELAY = 1

	local launchData

	for i = 1, ATTEMPT_LIMIT do
		task.wait(RETRY_DELAY)
		local joinData = player:GetJoinData()
		if joinData.LaunchData ~= "" then
			launchData = joinData.LaunchData
			break
		end
	end

	--check if player come with invitation experience notification
	if launchData then
		local data = HttpService:JSONDecode(launchData)
		local UserID = data.senderUserID
		local SpawnLocation = Vector3.new(data.spawnLocation[1], data.spawnLocation[2], data.spawnLocation[3]) --get position and construct the vector3 position because json can't take vector3 but array

		--check userid exist and is friend with player (security check)
		if not UserID or not player:IsFriendsWith(UserID) then
			return
		end

		--check if sender of invitation are alaway in game to teleport player invited or not
		local SenderOfInvitation = game.Players:GetPlayerByUserId(UserID)
		local root = SenderOfInvitation and SenderOfInvitation.Character and SenderOfInvitation.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		player.Character:MoveTo(SpawnLocation)
	else
		warn("No launch data received!")
	end
end

--If principal place and farm place we can init clollectable system on server side
if game.PlaceId == EnvironmentModule.GetPlaceId("MainPlace") or game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") then
	local PopupDailyExist = false
	local CallPopupDailyLimit = Instance.new("RemoteEvent", RemoteEvent)
	CallPopupDailyLimit.Name = "CallPopupDailyLimit"
    --For collectable system server setup folder and chose at starting a fields spawn random for all player
	local CollectingFieldsSpawnsFolder = workspace:FindFirstChild("CollectingFieldsSpawns") or Instance.new("Folder", workspace)
	CollectingFieldsSpawnsFolder.Name = "CollectingFieldsSpawns"
	local Fields = CollectingFieldsSpawnsFolder:GetChildren()
	local FieldSpawn = Fields[math.random(1, #Fields)]
	RemoteFunction.GetCollectableFieldSpawn.OnServerInvoke = function()
		return FieldSpawn
	end
	CallPopupDailyLimit.OnServerEvent:Connect(function(player, limit, collectable)
		if PopupDailyExist then
			return
		end

		PopupDailyExist = true
		local function CallbackYES(player)
			PopupDailyExist = false
			MarketplaceService:PromptGamePassPurchase(player, GameDataModule.Gamepasses.DailyLimitCollectablesX2.ProductID)
		end

		local function CallbackNO(player)
			PopupDailyExist = false
		end

		if BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.DailyLimitCollectablesX2.ProductID) then
			BindableEvent.ShowPopupAlert:Fire(
				player,
				"Crystal Limit Reach!",
				"You can collect "..limit.." per day ! \n You have reach this limit for "..collectable.." !",
				ToolsModule.AlertPriority.Annoucement,
				nil,
				ToolsModule.AlertTypeButton.OK,
				CallbackNO,{},
				CallbackNO,{}
			)
		else
			BindableEvent.ShowPopupAlert:Fire(
				player,
				"Crystal Limit Reach!",
				"You can collect "..limit.." per day ! \n You have reach this limit for "..collectable.." ! \n Upgrade this limit with Gamepass ?!",
				ToolsModule.AlertPriority.Annoucement,
				"Upgrade",
				ToolsModule.AlertTypeButton.OK,
				CallbackYES,{},
				CallbackNO,{}
			)
		end
	end)
end

local HorseLoader
-- Move mount and dismount to HorseLoader then return the horse object to the client when they mount
-- Make sure to disable the animator on the server when you pass the horse control to the client
-- When the client dismounts, give control of animator back to server
-- Also figure out why walk animation just perpetually plays

game.Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(function(Character)
		repeat
			task.wait()
		until Player.Character and Player.Character.PrimaryPart
		Player.Character.Parent = CharacterFolder
		local Humanoid = Character:WaitForChild("Humanoid")
		Humanoid.Died:Connect(function()
			HorseLoader:DismountCreature(Player)
			task.wait(0.1)
			Player:LoadCharacter()
		end)
		for _,Part in ipairs(Character:GetDescendants()) do
			if Part:IsA("BasePart") then
				Part.CollisionGroup = "Humans"
			end
		end
		-- 
		local PlayerGui = Player:WaitForChild("PlayerGui")
		for _,Object in pairs(StarterGui:GetChildren()) do
			if not PlayerGui:FindFirstChild(Object.Name) then
				Object:Clone().Parent = PlayerGui
			end
		end

		--[[
			this is a coroutine to alaways check the Y position of character and check if is undermap, don't kill player just
			teleport him to spawn position. Limit of falling auto die player is -500, check before player goal this limite and die.
		]]
		task.spawn(function()
			while true do
				if Player.Character.HumanoidRootPart.Position.Y <= -800 then
					Player.Character.HumanoidRootPart.CFrame = game.Workspace.DefaultSpawn.CFrame + Vector3.new(0,2,0)
				end
				task.wait()
			end
		end)
	end)
	Player:LoadCharacter()

	task.spawn(function()
		CheckInvitationPlayer(Player)
	end)
end)

HorseLoader = require("HorseLoader")
HorseLoader:Init()

--Don"t setup race function if its competition parade server
if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	local RaceHandler = require("RaceHandler")
	local RaceAIHandler = require("RaceAIHandler")
	RaceAIHandler:Init()
	RaceHandler:Init()
	
	require("GlobalEventHandler"):Init()
end

--///

local Players = game:GetService("Players")

local ReplicationDistance = 100

--TODO: HeadReplicationEvent is deprecated, connections can be removed.
--[[ HeadReplicationEvent.OnServerEvent:Connect(function(Player,NewTranform)
	if Player.Character and Player.Character.PrimaryPart then
		local OriginPosition = Player.Character.PrimaryPart.Position
		for _,TargetPlayer in pairs(Players:GetPlayers()) do
			if TargetPlayer ~= Player then
				local TargetPosition = (TargetPlayer.Character and TargetPlayer.Character.PrimaryPart or {}).Position
				if TargetPosition and (OriginPosition - TargetPosition).Magnitude <= ReplicationDistance then
					HeadReplicationEvent:FireClient(TargetPlayer,Player,NewTranform)
				end
			end
		end
	end
end)]]

HorseEvents.CreatureChangeStyle.OnServerEvent:Connect(function(...)
	HorseEvents.CreatureChangeStyle:FireClient(...)
end)

local FarmingHandler = require("FarmingHandler")
FarmingHandler:Init()


local Wetlands = require("Wetlands")
Wetlands:Init()

local ServerDropsHandler = require("ServerDropsHandler")
ServerDropsHandler:Init()

require("HorseInteractionServer"):Init()

local MapsClubsManager = require("MapsClubsManager") --Init are make in this module if its good map club