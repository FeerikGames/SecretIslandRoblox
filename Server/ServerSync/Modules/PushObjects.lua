local pushObjects = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

-- Require Module
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")

local remoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RF_ApplyMultiPush = remoteFunction.ApplyMultiPush
local RockExplode = Instance.new("RemoteEvent", ReplicatedStorage.SharedSync.RemoteEvent)
RockExplode.Name = "RockExplode"

local pushObjectFolder = workspace.InteractibleScenery

local pushedObjects = {}

local function SetupCurrentPushAttributeOnPushParts()
    for _, part in pairs(pushObjectFolder:GetDescendants()) do
		if part:GetAttribute("playersNeeded") ~= nil then
			part:SetAttribute("currentPlayers", 0)
            pushedObjects[part] = {}
		end
	end
end

SetupCurrentPushAttributeOnPushParts()

local function ApplyMultiPush(part, numberAdded)
    local currentPlayers = part:GetAttribute("currentPlayers")
    part:SetAttribute("currentPlayers", currentPlayers + numberAdded)
end

RF_ApplyMultiPush.OnServerInvoke = function(player, part, numberAdded)
    if numberAdded > 0 then
        pushedObjects[part][player] = true
    else
        pushedObjects[part][player] = nil
    end
    ApplyMultiPush(part, numberAdded)
    RF_ApplyMultiPush:InvokeClient(player)
end

-- Event listener call when player have push on during some time a rock. Make explosion animation and sounds for server and send reward drops collectables for all players around rock
RockExplode.OnServerEvent:Connect(function(player, rock)
    if rock then
        -- Play sound and particle explod
        SoundControllerModule:CreateSound("RockImpact", rock)
        for _, particle in pairs(rock.Parent:GetDescendants()) do
            if particle:IsA("ParticleEmitter") and particle.Name == "Explo" then
                particle:Emit(200)
            end
        end

        -- Search all player around Rock and give reward (RockExplod remote event are call into CoinsCollectingReward for play Droppable function of collectables)
        for _, plr in pairs(game.Players:GetChildren()) do
            if plr.Character then
                if (rock.Position - plr.Character.PrimaryPart.Position).Magnitude < rock.Size.X + 15 then
                    RockExplode:FireClient(plr, rock.CFrame, "", ReplicatedStorage.SharedSync.Assets.Drops.DropCollectable, rock.Parent.Drops:GetChildren(), 20, true)
                end
            end
        end

        -- Get all child basepart of rock parent and disable physics and visual for let time to make drop
        for _, child in pairs(rock.Parent:GetDescendants()) do
            if child:IsA("BasePart") then
                child.Transparency = 1
                child.Anchored = true
                child.CanCollide = false
                child.CanQuery = false
                child.CanTouch = false
            end
        end

        -- Wait lettle time before destroy all
        task.spawn(function()
            task.wait(10)
            rock.Parent:Destroy()
        end)
    end
end)

playerService.PlayerRemoving:Connect(function(player)
    for _, pushedParts in pairs(pushObjectFolder:GetChildren()) do
        if pushedParts:GetAttribute("currentPlayers") == nil or pushedObjects[pushedParts][player] == nil then
            continue
        end
        pushedObjects[pushedParts][player] = nil
        ApplyMultiPush(pushedParts, -1)
    end
end)

return pushObjects