local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local BumpHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local Signal = require("Signal")
local WalkSpeedModule = require("WalkSpeedModule")
local EnvironmentModule = require("EnvironmentModule")

local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")

local HorseBumpOverlapParams = OverlapParams.new()
HorseBumpOverlapParams.FilterType = Enum.RaycastFilterType.Whitelist

--// for testing

local BUMP_CONFIG = Instance.new("Folder",workspace)
BUMP_CONFIG.Name = "BUMP_CONFIG"

local CollisionQuery = OverlapParams.new()
CollisionQuery.FilterType = Enum.RaycastFilterType.Whitelist
CollisionQuery.FilterDescendantsInstances = CollectionService:GetTagged("PropCollision")
--//

local PropCollisions = CollectionService:GetTagged("PropCollision")

if RunService:IsServer() then
    PhysicsService:RegisterCollisionGroup("PropCollision")
    for _,Part in ipairs(PropCollisions) do
        if Part:IsA("BasePart") then
            Part.CollisionGroup = "PropCollision"
        end
    end
else
    --local NewCollisionTable = {}
    for _,Part in pairs(PropCollisions) do
        if Part:IsA("BasePart") then
            local ClientPart = Part:Clone()
            ClientPart.Parent = Part.Parent
            Part:Destroy()
        end
    end
end

local BumpIndex = 0

function BumpHandler:Enable(Horse,TargetFolder)
    if Horse.BumpHandler then
        Horse.BumpHandler:Disable()
    end
    
    -- Don't setup detection touch behavior of Animals if Place are the Fashion Show
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		return
	end

    Horse.BumpHandler = {}
    Horse.BumpHandler.Connections = {}
    function Horse.BumpHandler:Disable()
        for _,Connection in pairs(Horse.BumpHandler.Connections) do
            Connection:Disconnect()
        end
        Horse.BumpHandler = nil
    end
    Horse.BumpHandler.BumpStateChanged = Signal.new()

    local Debounce = false
    Horse.BumpHandler.Connections.MainLoop = RunService.Heartbeat:Connect(function()
        local HorsesNearby = {}
        local Whitelist = {}
        for _,HorseInstance in pairs((TargetFolder or CreaturesFolder):GetChildren()) do
            if HorseInstance ~= Horse.Instance and HorseInstance.PrimaryPart and (HorseInstance.PrimaryPart.Position - Horse.PrimaryPart.Position).Magnitude < 10 then
                table.insert(HorsesNearby,HorseInstance)
                table.insert(Whitelist,HorseInstance.PrimaryPart)
            end
        end
        HorseBumpOverlapParams.FilterDescendantsInstances = Whitelist
        local TouchingHorses = workspace:GetPartsInPart(Horse.PrimaryPart,HorseBumpOverlapParams)
        if TouchingHorses[1] and Debounce == false then
            Debounce = true
            local Dominant = Horse.PrimaryPart
            local Victim = TouchingHorses[1]
            if Horse.PrimaryPart.CFrame:ToObjectSpace(TouchingHorses[1].CFrame).Position.Y < 0 then
                Dominant = TouchingHorses[1]
                Victim = Horse.PrimaryPart
            end
            --print("BUMPED!")
            local CurrentBumpIndex
            if math.abs(Dominant.AssemblyLinearVelocity.Magnitude - Victim.AssemblyLinearVelocity.Magnitude) < 10 then
                BumpIndex += 1
                CurrentBumpIndex = BumpIndex
                --print("Speed boost!!!")
                --if RunService:IsServer() then
                --    PhysicsService:CollisionGroupSetCollidable("HorseAI", "PropCollision", false)
                --else
                local CollisionParts = CollectionService:GetTagged("PropCollision")
                for _,Part in pairs(CollisionParts) do
                    if Part:IsA("BasePart") then
                        Part.CanCollide = false
                    else
                        print("what?")
                    end
                end
                --end
                
                WalkSpeedModule.ApplyBumpBonus(Horse.Instance, true)
                --[[ for _,Part in pairs(Horse.Instance:GetDescendants()) do
                    if Part:IsA("BasePart") or Part:IsA("Texture") or Part:IsA("Decal") then
                        Part.LocalTransparencyModifier = 0.5
                    end
                end ]]

                Horse.BumpHandler.BumpStateChanged:Fire(true,CollisionParts)
                
                task.wait(3)
                
                WalkSpeedModule.ApplyBumpBonus(Horse.Instance, false)
            end
            while workspace:GetPartsInPart(Horse.PrimaryPart,CollisionQuery)[1] do
                task.wait(0.2)
                print("INSIDE")
            end
            --[[ for _,Part in pairs(Horse.Instance:GetDescendants()) do
                if Part:IsA("BasePart") or Part:IsA("Texture") or Part:IsA("Decal") then
                    Part.LocalTransparencyModifier = 0
                end 
            end ]]
            --if RunService:IsServer() then
              --  PhysicsService:CollisionGroupSetCollidable("HorseAI", "PropCollision", true)
            --else
            if CurrentBumpIndex == BumpIndex then
                for _,Part in ipairs(CollectionService:GetTagged("PropCollision")) do
                    if Part:IsA("BasePart") then
                        Part.CanCollide = true
                    end
                end
            end
            --end
            Horse.BumpHandler.BumpStateChanged:Fire(false)
            Debounce = false
        end
    end)
    

end




return BumpHandler