local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

-- Require Module
local PlayerDataModule = require("ReplicatedPlayerData")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")

-- Remotes
local RemoteFunction = ReplicatedStorage.RemoteFunction
local RemoteEvent = ReplicatedStorage.RemoteEvent

local Player = game.Players.LocalPlayer

local SystemUnlockable = game.Workspace:WaitForChild("SystemUnlockable"):GetChildren()

repeat
    task.wait(1)
until PlayerDataModule.LocalData.SystemUnlocked

local function CheckSystemUnlock(value:string)
    -- Get all system unlocked
    local systemUnlocked = PlayerDataModule.LocalData.SystemUnlocked
    if systemUnlocked then
        for _, systemName in pairs(systemUnlocked) do
            if value == systemName then
                return true
            end
        end
    end

    return false
end

--[[
    Create proximity prompt with part placed at pos give in parameter. This proximity prompt trigger remote function to ask server to pay unlock
        system link to this proximity prompt part.
]]
local function CreateProximityPart(barrier:Part, pos:Vector3, systemName:string, showName:string)
    -- Make part where we can put proximity prompt
    local proximityPart = Instance.new("Part", barrier)
    proximityPart.Name = "proximityPart"
    proximityPart.CanCollide = false
    proximityPart.Anchored = true
    proximityPart.CastShadow = false
    proximityPart.Transparency = 1
    proximityPart.Size = Vector3.new(1,1,1)
    proximityPart.CFrame = barrier.CFrame
    proximityPart.CFrame += pos

    -- Make proximity prompt to trigger player unlock system
    local proximityPrompt = Instance.new("ProximityPrompt", proximityPart)
    proximityPrompt.KeyboardKeyCode = Enum.KeyCode.F
    proximityPrompt.RequiresLineOfSight = false
    proximityPrompt.ActionText = "Purchase"
    proximityPrompt.HoldDuration = 0
    proximityPrompt.MaxActivationDistance = 20
    proximityPrompt.Triggered:Connect(function()
        -- Call server to ask payout and server make all check and validation with return by RemoteEvent "SystemUnlocked"
        RemoteFunction.PurchaseSystemUnlockable:InvokeServer(systemName, showName)
    end)
end

--[[
    This function allow to create a barrier part collide to block player enter in system with physics detection
]]
local function CreateBarrierUnlockable(model, isChild:boolean, systemName:string)
    -- Get size and cframe of model
    local orientation, size
    if model:IsA("Model") then
        orientation, size = model:GetBoundingBox()
    else
        orientation = model.CFrame
        size = model.Size + Vector3.new(3,3,3)
    end

    local costUnlock = isChild and model.Parent:GetAttribute("CostUnlock") or model:GetAttribute("CostUnlock")
    local typeCostUnlock = isChild and model.Parent:GetAttribute("TypeCostUnlock") or model:GetAttribute("TypeCostUnlock")
    local ShowName = isChild and model.Parent:GetAttribute("SystemName") or model:GetAttribute("SystemName")

    -- Make part with good parameter
    local barrier = Instance.new("Part", model)
    barrier.Name = "UnlockablePart"
    barrier.Anchored = true
    barrier.CanCollide = true
    barrier.CastShadow = false
    barrier.Transparency = 0.5
    barrier.Size = size
    barrier.CFrame = orientation
    barrier.Material = Enum.Material.Glass

    -- Launch creation of proximity prompt to buy and unlock system
    if barrier.Size.X >= 20 then
        CreateProximityPart(barrier, Vector3.new(barrier.Size.X/2 + 1, -barrier.Size.Y/2 + 5, 0), systemName, ShowName)
        CreateProximityPart(barrier, Vector3.new(-barrier.Size.X/2 - 1, -barrier.Size.Y/2 + 5, 0), systemName, ShowName)
    end
    if barrier.Size.Z >= 20 then
        CreateProximityPart(barrier, Vector3.new(0, -barrier.Size.Y/2 + 5, barrier.Size.Z/2 + 1), systemName, ShowName)
        CreateProximityPart(barrier, Vector3.new(0, -barrier.Size.Y/2 + 5, -barrier.Size.Z/2 - 1), systemName, ShowName)
    end
    if barrier.Size.X < 20 and barrier.Size.Z < 20 then
        CreateProximityPart(barrier, Vector3.new(0, -barrier.Size.Y/2 + 5, 0), systemName, ShowName)
    end

    -- Prepare firework particle for unlock system with random position on area of system
    for i=0, 8 do
        local attach = Instance.new("Attachment", barrier)
        local particle = ReplicatedStorage.Assets.Particles.StarsExploseFirework:Clone()
        particle.Name = "particle"
        particle.Parent = attach
        attach.Position = Vector3.new(math.random(-barrier.Size.X/2,barrier.Size.X/2), 0, math.random(-barrier.Size.Z/2,barrier.Size.Z/2))
    end

    -- Make Surface Gui to place on all face needed to show cost of unlock system
    for i=0, 5 do
        if i ~= 1 and i ~= 4 then
            local ui = ReplicatedStorage.Assets.SystemUnlockableSurfaceGui:Clone()
            ui.Parent = barrier
            ui.Face = i

            ui.Frame.CostUnlock.Icon.Image = GameDataModule.DropCollectablesWithBorders[typeCostUnlock]
            ui.Frame.CostUnlock.ValueTxt.Text = ToolsModule.DotNumber(costUnlock)
            ui.Frame.SystemName.Text = ShowName
        end
    end
end

local function InitAllLockedSystem()
    for _, model in pairs(SystemUnlockable) do
        if not CheckSystemUnlock(model.Name) then
            -- Player don't have unlock this system, so create barrier unlockable
            -- Check if we make barrier on model or childs (exemple teleport is better to make barrier on child)
            if model:GetAttribute("IsBarrier") then
                CreateBarrierUnlockable(model, false, model.Name)
            else
                for _, child in pairs(model:GetChildren()) do
                    if child:IsA("BasePart") then
                        CreateBarrierUnlockable(child, true, model.Name)
                    end
                end
            end
        end
    end
end

InitAllLockedSystem()

--[[
    This remote event is call when server valid payout of player to unlock system and play animation unlock and
    destroy part collide who block player.
]]
RemoteEvent.SystemUnlocked.OnClientEvent:Connect(function(systemName)
    local model = game.Workspace:WaitForChild("SystemUnlockable"):FindFirstChild(systemName)
    if model then

        -- Check if the system model is set with barrier or if it's children
        if not model:GetAttribute("IsBarrier") then
            -- Model not set with barrier, so take and setup all children and for the effect take the shortest distance of player
            local selected
            for _, child in pairs(model:GetChildren()) do
                if child:IsA("BasePart") then
                    if (child.Position - Player.Character.PrimaryPart.Position).Magnitude < 20 then
                        selected = child
                    end
                end
            end

            -- Destroy other barrier child without play effects
            for _, child in pairs(model:GetChildren()) do
                if child:IsA("BasePart") then
                    if child ~= selected then
                        if child:FindFirstChild("UnlockablePart") then
                            child.UnlockablePart:Destroy()
                        end
                    end
                end
            end

            -- Set child selected like a model for get barrier and play their effects
            model = selected
        end

        -- Play effects particles and sounds of unlocked barrier
        local barrier = model:FindFirstChild("UnlockablePart")
        if barrier then
            barrier.CanCollide = false
            barrier.Transparency = 1

            for _, child in pairs(barrier:GetChildren()) do
                if child.Name == "proximityPart" or child.Name == "SystemUnlockableSurfaceGui" then
                    child:Destroy()
                end
            end

            local p = ReplicatedStorage.Assets.Particles.UnlockParticleEmitter:Clone()
            p.Parent = barrier
            p:Emit(150)

            SoundControllerModule:CreateSound("UnlockSystem")

            for _, attach in pairs(barrier:GetChildren()) do
                if attach:IsA("Attachment") then
                    attach.particle:Emit(100)
                    SoundControllerModule:CreateSound("SimpleFirework")
                    task.wait(Random.new():NextNumber(0.05, 1))
                end
            end

            task.wait(1)
            barrier:Destroy()
        end
    end
end)