local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local playerService = game:GetService("Players")
local player = playerService.LocalPlayer
local RemoteFunction = ReplicatedStorage.SharedSync:FindFirstChild("RemoteFunction")
local PlayerDataModule = require("ReplicatedPlayerData")

local RE_QuestFollow = ReplicatedStorage.SharedSync.RemoteEvent.Quest.QuestFollow

local trackedItems = {}
local closestTrackedItem = nil
local trackBeam = Instance.new("Beam", workspace)
trackBeam.FaceCamera = true
trackBeam.Texture = "rbxassetid://8081777495"
trackBeam.Width0 = 5
trackBeam.Width1 = 5
trackBeam.Segments = 1

local function getTrackedItems()
	table.clear(trackedItems)
	local count = 1
	local questFollowing
	local Quests = PlayerDataModule.LocalData.Quests
	for index, quest in pairs(Quests) do
		if quest.Following then
			questFollowing = index
			for _, item in pairs(workspace.Quests:GetChildren()) do
				if item:GetAttribute(questFollowing) == true then
					trackedItems[count] = item
					trackedItems[count]:GetPropertyChangedSignal("Parent"):Connect(function()
						if not trackedItems[count] then
							getTrackedItems()
						end
					end)
					count += 1
				end
			end
			break
		end
	end
end

local function resetTracking()
	trackedItems = {}
	closestTrackedItem = nil
	trackBeam.Attachment0 = nil
	trackBeam.Attachment1 = nil
end

local function getClosestTrackedItem()
	local distance = math.huge
	local closestItem = nil
	for _, item in pairs(trackedItems) do
		local comparedDistance
		local itemPos
		if item:IsA("Model") then
			if item.PrimaryPart then
				itemPos = item.PrimaryPart.Position
			end
		else
			itemPos = item.Position
		end
		
		if itemPos then
			comparedDistance = (itemPos - player.Character.PrimaryPart.Position).Magnitude
			if comparedDistance < distance then
				distance = comparedDistance
				closestItem = item
			end
		end
	end
	closestTrackedItem = closestItem
end


local function setAttachment(part)
	local trackAttachment = Instance.new("Attachment")
	trackAttachment.Name = "TrackAttachment"
	trackAttachment.Parent = part
	trackAttachment.Position = Vector3.new(0,0,0)
	trackAttachment.WorldOrientation = Vector3.new(90,0,0)
end

local function TargetVisualUpdate()
	if closestTrackedItem then
		if not player.Character.PrimaryPart:FindFirstChild("TrackAttachment") then
			setAttachment(player.Character.PrimaryPart)
		end
		trackBeam.Attachment0 = player.Character.PrimaryPart.TrackAttachment
		if closestTrackedItem:IsA("Model") then
			if not closestTrackedItem.PrimaryPart:FindFirstChild("TrackAttachment") then
				setAttachment(closestTrackedItem.PrimaryPart)
			end
			trackBeam.Attachment1 = closestTrackedItem.PrimaryPart.TrackAttachment
		else
			if not closestTrackedItem:FindFirstChild("TrackAttachment") then
				setAttachment(closestTrackedItem)
			end
			trackBeam.Attachment1 = closestTrackedItem.TrackAttachment
		end
	end
end

local function updateTextureLength()
	while wait() do
		if closestTrackedItem then
			local closestTrackedItemPos
			if closestTrackedItem:IsA("Model") then
				if closestTrackedItem.PrimaryPart then
					closestTrackedItemPos = closestTrackedItem.PrimaryPart.Position
				end
			else
				closestTrackedItemPos = closestTrackedItem.Position
			end
			if closestTrackedItemPos then
				trackBeam.TextureLength = (closestTrackedItemPos - player.Character.PrimaryPart.Position).Magnitude /3
			end
		end
	end
end

local function updateClosestItem()
	while wait(0.7) do
		getClosestTrackedItem()
		TargetVisualUpdate()
	end
end


workspace.Quests.ChildAdded:Connect(function()
	getTrackedItems()
end)
player.CharacterAdded:Connect(function()
	player.Character:WaitForChild("HumanoidRootPart")
	task.delay(0, function()
		updateClosestItem()
	end)
	task.delay(0, function()
		updateTextureLength()
	end)
end)

RE_QuestFollow.OnClientEvent:Connect(function(questFollowing)
	if questFollowing.Following then
		getTrackedItems()
	else
		resetTracking()
	end
end)
