local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Maid = require("Maid")

local Whitelist = {}
local MaidConstructor = Maid.new()

local CharacterScripts = script.Parent
local FolderSync = CharacterScripts.Parent
local Character = FolderSync.Parent

local Settings = {
    TagName = "Platform",
    rayDirection = Vector3.new(0, -30, 0),
    LastCFrame = nil
}

local function CleanUp()
    MaidConstructor:DoCleaning()
end

for _, inst in pairs(CollectionService:GetTagged(Settings.TagName)) do
	table.insert(Whitelist, inst)
end

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = Whitelist
raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
raycastParams.IgnoreWater = true

Character.Humanoid.Died:Connect(function()
    CleanUp()
    return
end)

MaidConstructor:GiveTask(RunService.Heartbeat:Connect(function()
    local HumanoidRootPart = Character.PrimaryPart
    local raycastResult = Workspace:Raycast(HumanoidRootPart.CFrame.Position, Settings.rayDirection, raycastParams)

    if raycastResult then
        if Settings.LastCFrame == nil then
            Settings.LastCFrame = raycastResult.Instance.CFrame
        end

        local PlatformCFrame = raycastResult.Instance.CFrame 
        local Inverse = PlatformCFrame * Settings.LastCFrame:inverse()
        Settings.LastCFrame = raycastResult.Instance.CFrame
        HumanoidRootPart.CFrame = Inverse * HumanoidRootPart.CFrame
    else
        Settings.LastCFrame = nil
    end
end))
