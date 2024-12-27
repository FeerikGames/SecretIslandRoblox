local SoundController = {}

local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local SoundEvent = RemoteEvent.Sounds.SoundControllerEvent

local SoundsFolder = ReplicatedStorage.SharedSync.Assets.Sounds

local SOUND_LIMIT = 16
local QUEUE_REMOVAL = 2

SoundController.SoundQueue = {}
SoundController.SoundReduced = false --Allow to know if actually sound are reduced to reduced new instance sounds
SoundController.VolumeReducedRatio = 0.9 --in pourcentage so 0.5 = 50%

local function FindSoundByName(Name)
    for _, Sound in pairs(SoundsFolder:GetDescendants()) do
        if not Sound:IsA("Sound") then
            continue
        end

        if Sound.Name == Name then
            return Sound
        end
    end

    local Sound = Instance.new("Sound")
    Sound.SoundId = "rbxassetid://" .. Name
    return Sound
end

local function AddToQueue(SoundId)
    local IdInQueue = SoundController.SoundQueue[SoundId]
    if IdInQueue and IdInQueue >= SOUND_LIMIT then
        return false
    end
    
    if IdInQueue then
        SoundController.SoundQueue[SoundId] += 1
    else
        SoundController.SoundQueue[SoundId] = 1
    end

    task.spawn(function()
        task.wait(QUEUE_REMOVAL)
        SoundController.SoundQueue[SoundId] += -1
        if SoundController.SoundQueue[SoundId] <= 0 then
            SoundController.SoundQueue[SoundId] = nil
        end
    end)

    return true
end

local function SetParentOfSound(Sound, parent)
    local SoundPart
    if typeof(parent) == "Vector3" then
        SoundPart = Instance.new("Part")
        SoundPart.CanCollide = false
        SoundPart.Anchored = true
        SoundPart.Transparency = 1
        SoundPart.Parent = Workspace.CurrentCamera
        SoundPart.Position = parent
        Sound.Parent = SoundPart
    else
        Sound.Parent = parent or SoundService
    end
    return SoundPart
end

local function InstanceSound(soundName, parent, Volume)
    local Sound = FindSoundByName(soundName)
    if not Sound then
        warn("Could not validate Sound:", soundName)
        return
    end

    Sound = Sound:Clone()

    if parent then
        local CanPlay = AddToQueue(Sound.SoundId)
        if not CanPlay then
            return
        end
    end

    local SoundPart = SetParentOfSound(Sound, parent)
    if Volume then
        Sound.Volume = Volume
    end
    Sound:Play()

    task.spawn(function()
        if not Sound.Looped then
            Sound.Ended:Wait()
            Sound:Destroy()
            if SoundPart then SoundPart:Destroy() end
        end
    end)

    return Sound
end

function SoundController:CreateSound(SoundName, Parent, Volume)
    if RunService:IsServer() then
        SoundEvent:FireAllClients(SoundName, Parent, Volume)
    elseif RunService:IsClient() then
        InstanceSound(SoundName, Parent, Volume)
    end
end

if RunService:IsClient() then
    SoundEvent.OnClientEvent:Connect(function(SoundName, Parent, Volume)
        InstanceSound(SoundName, Parent, Volume)
    end)
end

return SoundController