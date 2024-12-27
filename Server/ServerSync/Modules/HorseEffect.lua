local HorseEffect = {}
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local remoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local remoteFunction = ReplicatedStorage.SharedSync.RemoteFunction

local WalkSpeedModule = require("WalkSpeedModule")
local PlayerDataModule = require("PlayerDataModule")

local CreaturesFolder = workspace.CreaturesFolder
local Assets = ReplicatedStorage.SharedSync.Assets

local RE_UpdateSparks = remoteEvent.UpdateSparks
local RE_SyncClientSparks = remoteEvent.SyncClientSparks
local RF_HorseEffectActivation = remoteFunction.HorseEffectActivation
local RE_ChangeSmokeMaterial = remoteEvent.ChangeSmokeMaterial
local RE_HorseSpeedEffectActivation = remoteEvent.HorseSpeedEffectActivation

local playersMoving = {}
local playersSlipstreamStatus = {}

HorseEffect.SmokeEffectStruct = {
    smoke = Assets.Effects.Smoke;
    grass = Assets.Effects.Grass;
    snow = "rbxassetid://8404924931"
}

local sparksUseRatio = 1
local sparksEffectModifier = 1

local function GetHorseFromPlayer(player)
    local horse = CreaturesFolder:FindFirstChild("Creature_"..player)
    return horse
end

-- Activate/deactivate the slipStream particles
local function SlipStreamEffectActivation(creature, isActive)
    for _, effect in pairs(creature.PrimaryPart.SlipStreamEffects:GetChildren()) do
        if effect:IsA("ParticleEmitter") then
            effect.Enabled = isActive
        end
    end
end

function HorseEffect.SummonEffect(creature)
    
    local modelEffect:Model = Assets.Effects.SupraAppartitionEffect:Clone()
    modelEffect.Parent = creature
    modelEffect:PivotTo(creature.PrimaryPart.CFrame + Vector3.new(0,-5,0))
    
    -- Timing of animation rotate server side
    local duration = modelEffect:GetAttribute("duration")

    Debris:AddItem(modelEffect, duration)

    for _, particle in pairs(modelEffect.ParticulesPart:GetChildren()) do
        if particle:IsA("ParticleEmitter") then
            particle:Emit(100)
        end
    end

    

    -- Rotate function
    local function rotateModel()
        local startTime = tick()
        local endTime = startTime + duration
        local nbRotate = modelEffect:GetAttribute("nbRotate")

        while tick() < endTime do
            local elapsedTime = tick() - startTime
            local rotationY = elapsedTime / duration * (360*nbRotate)
            
            -- Apply rotate to the model
            modelEffect:PivotTo(CFrame.new(modelEffect.PrimaryPart.Position) * CFrame.Angles(0, math.rad(rotationY), 0))
            
            -- Wait the next update of Heartbeat server to make smoothly rotate
            game:GetService("RunService").Heartbeat:Wait()
        end
    end

    -- Start coroutine
    coroutine.wrap(rotateModel)()
end

function HorseEffect.UpdatePlayerSparks(player, isMoving)
    if isMoving then
        local initSparks = PlayerDataModule:Get(player, "Sparks")
        RE_SyncClientSparks:FireClient(player, initSparks)
        playersMoving[player.UserId] = true

        -- If slipstream effect is activated and creature move we make sur to enable slipstream effect (example after stop move we disable effect, if slipstream is alaway ok and move enable again effect)
        if playersSlipstreamStatus[player.UserId] then
            local creature = GetHorseFromPlayer(player.Name)
            if creature then
                SlipStreamEffectActivation(creature, true)
            end
        end

        while task.wait(1) and playersMoving[player.UserId] do
            if not playersMoving[player.UserId] then
                break
            end
            local sparks = PlayerDataModule:Get(player, "Sparks")
            if sparks > 0 then
                sparks -= sparksUseRatio * sparksEffectModifier
                sparks = sparks<=0 and 0 or sparks
                PlayerDataModule:Set(player, sparks, "Sparks")
            end
            RE_SyncClientSparks:FireClient(player, sparks)
        end
    else
        playersMoving[player.UserId] = false
        local horse = GetHorseFromPlayer(player.Name)
        if horse then
            -- deactivate SlipStream when stop moving
            if playersSlipstreamStatus[player.UserId] then
                SlipStreamEffectActivation(horse, false)
            end
        end
    end
end

local function HorseEffectActivation(player, horse, isActive, rate, currentSparks)
    local totalEffects = 0
    if horse.Socks:FindFirstChild("EffectFeet") and currentSparks then
        local effects = horse.Socks.EffectFeet:GetChildren()
        rate = math.clamp(rate, 0, 100)
        for _, effect in pairs(effects) do
            if effect:IsA("ParticleEmitter") then
                if effect.Name ~= "Smoke" and effect.Name ~= "DisabledWillDestroy" then
                    totalEffects += 1
                end
                if isActive and currentSparks > 0 and effect.Name ~= "Smoke" and effect.Name ~= "DisabledWillDestroy" then
                    -- If player have use power giant adapt rate of particle depending of size ratio
                    local ratio = 1
                    if horse.PrimaryPart:GetAttribute("SizeEffectActive") then
                        ratio = horse.PrimaryPart:GetAttribute("SizeRatio")
                    end
                    effect.Rate = rate/90 * effect:GetAttribute("rateEmission") * ratio
                else
                    effect.Rate = 0
                end
            end
        end
        sparksEffectModifier = 1
        if totalEffects < 1 then
            sparksEffectModifier = 0
        end
        if totalEffects < 1 or currentSparks <= 0 then
            horse.Socks.EffectFeet.Smoke.Rate = rate/90 * horse.Socks.EffectFeet.Smoke:GetAttribute("rateEmission")
        end
    end
    return totalEffects
end

local function TerrainEffect(player, smokeEffect, material)
    
    local instanciatedEffect = HorseEffect.SmokeEffectStruct.grass:Clone()
    instanciatedEffect.Parent = smokeEffect.Parent
    instanciatedEffect.Name = "Smoke"
    instanciatedEffect.Rate = smokeEffect.Rate

    --[[ if material == Enum.Material.Grass then
    else
        local instanciatedEffect = HorseEffect.SmokeEffectStruct.smoke:Clone()
        instanciatedEffect.Parent = smokeEffect.Parent
        instanciatedEffect.Name = "Smoke"
        instanciatedEffect.Rate = smokeEffect.Rate
    end ]]

    smokeEffect.Name = "DisabledWillDestroy"
    smokeEffect.Enabled = false

    task.delay(3, function()
        smokeEffect:Destroy()
    end)
end

RF_HorseEffectActivation.OnServerInvoke = function(player, horse, isActive, rate, currentSparks)
    return HorseEffectActivation(player, horse, isActive, rate, currentSparks)
end

RE_HorseSpeedEffectActivation.OnServerEvent:Connect(function(player, creature, isActive)
    playersSlipstreamStatus[player.UserId] = isActive
    SlipStreamEffectActivation(creature, isActive)
end)

RE_ChangeSmokeMaterial.OnServerEvent:Connect(TerrainEffect)

RE_UpdateSparks.OnServerEvent:Connect(HorseEffect.UpdatePlayerSparks)
return HorseEffect