local HorseInteraction = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local Assets = ReplicatedStorage.SharedSync:WaitForChild("Assets"):WaitForChild("InteractionAssets")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local InteractionUISystem = require("InteractionUISystem")
local GetRemoteEvent = require("GetRemoteEvent")

local InteractionEvent = GetRemoteEvent("InteractionEvent")


HorseInteraction.Actions = {}

function HorseInteraction.Actions.Brushed(TargetHorse)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Brushed",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value})
        task.spawn(function()
            local Brush = Assets.Brush:Clone()
            Brush.Parent = workspace
            for i=1,100 do
                Brush.CFrame = TargetHorse.PrimaryPart.CFrame * CFrame.new(-1,0,2-(i/100)*4) * CFrame.Angles(0,0,math.rad(-90))
                RunService.Heartbeat:Wait()
            end
            Brush:Destroy()
        end)
    end
end

function  HorseInteraction.Actions.Fed(TargetHorse, isFull)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Fed",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value, IsFull = isFull})
        task.spawn(function()
            local Hays = Assets.Hays:Clone() 
            Hays.Parent = workspace
            for i=1,150 do
                Hays.CFrame = TargetHorse.PrimaryPart.CFrame * CFrame.new(0, -3.25-(i/100)*1, -5) * CFrame.Angles(0,0,0)
                RunService.Heartbeat:Wait()
            end
            Hays:Destroy()
        end)
    end
end

function HorseInteraction.Actions.Cleanness(TargetHorse)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Cleanness",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value})
        task.spawn(function()
            local particles = Assets.ParticleCleanness:Clone()
            particles.Parent =  TargetHorse.PrimaryPart
            particles.Enabled = true
            task.wait(2)
            particles.Enabled = false
            particles:Destroy()
        end)
    end
end

function HorseInteraction.Actions.Happyness(TargetHorse)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Happyness",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value})
        task.spawn(function()
            task.wait(2) -- this wait replace time of the animation
        end)
    end
end

function HorseInteraction.Actions.Scrape(TargetHorse)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Scrape",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value})

        task.spawn(function()
            local particles = Assets.ParticleCleanness:Clone()
            particles.Parent =  TargetHorse.PrimaryPart
            particles.Enabled = true
            task.wait(2)
            particles.Enabled = false
            particles:Destroy()
        end)
    end
end

function HorseInteraction.Actions.Care(TargetHorse)
    if TargetHorse:FindFirstChild("CreatureID") then
        InteractionEvent:FireServer("Care",{HorseTarget = TargetHorse, CreatureID = TargetHorse.CreatureID.Value})

        task.spawn(function()
            local particles = Assets.JoyEmission:GetChildren()
            local instanciatedParticles = {}
            for _, particle in pairs(particles) do
                instanciatedParticles[_] = particle:Clone()
                instanciatedParticles[_].Enabled = true
                instanciatedParticles[_].Parent = TargetHorse.EffectHead
            end
            task.wait(2) -- this wait replace time of the animation we make another time for show to player what happen with this action
            for _, particle in pairs(instanciatedParticles) do
                particle.Enabled = false
                particle:Destroy()
            end
            --TargetHorse.PrimaryPart.ShowMaintenanceBar:Destroy()
            --TargetHorse.PrimaryPart.Prompt.Enabled = true
        end)
    end
end

return HorseInteraction