local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

local WalkSpeedModule = {
    CreatureSpeed = script:GetAttribute("CreatureSpeed"),
    SlipStreamBonus = script:GetAttribute("SlipStreamBonus"),
    PegasusBonus = script:GetAttribute("PegasusBonus"),
    BumpBonus = script:GetAttribute("BumpBonus"),
    SlowerMalus = script:GetAttribute("SlowerMalus"),
    WalkMalus = script:GetAttribute("WalkMalus"),
    PushMalus = script:GetAttribute("PushMalus"),
    FlightSpeed = script:GetAttribute("FlightSpeed")
}

local SpeedInfluenceTable = {
    speedHorseCurrentInfluence = 0,
    speedSlipStreamInfluence = 0,
    speedWalkInfluence = 0,
    speedSlowerInfluence = 0,
    speedBumpInfluence = 0,
    speedPushInfluence = 0,
    speedSizeInfluence = 0,
    speedTalentInfluence = 0,
    speedTalentFixInfluence = 0
}

local blockedSpeedRatio = 1
local function ApplySpeed(target)
    local temp = WalkSpeedModule.CreatureSpeed
    for _, v in pairs(SpeedInfluenceTable) do
        temp += math.floor(temp * (v/100))
    end

	local speed = temp * blockedSpeedRatio
	if target then
        if target:FindFirstChild("Humanoid") then
            target.Humanoid.WalkSpeed = speed
        end
	end
end

function WalkSpeedModule.AddSlipStreamBonus(target)
    SpeedInfluenceTable.speedSlipStreamInfluence = WalkSpeedModule.SlipStreamBonus
    ApplySpeed(target)
end

function WalkSpeedModule.RemoveSlipStreamBonus(target, instantRemove)
    SpeedInfluenceTable.speedSlipStreamInfluence = instantRemove and 0 or math.clamp(SpeedInfluenceTable.speedSlipStreamInfluence-0.25,0,WalkSpeedModule.SlipStreamBonus)
    ApplySpeed(target)
    return SpeedInfluenceTable.speedSlipStreamInfluence
end

function WalkSpeedModule.ApplyBlockedMalus(target, value)
    blockedSpeedRatio = value
    ApplySpeed(target)
end

function WalkSpeedModule.ApplyBumpBonus(target, isApply)
    if isApply then
        SpeedInfluenceTable.speedBumpInfluence = WalkSpeedModule.BumpBonus
    else
        SpeedInfluenceTable.speedBumpInfluence = 0
    end
    ApplySpeed(target)
end

--TODO IMPROVE WITH NO THREAD FOR APPLY MALUS BUT DETECXTION OF LOW HEALTH
function WalkSpeedModule.ApplySlowerMalus(target,isApply)
    if isApply then
        SpeedInfluenceTable.speedSlowerInfluence = WalkSpeedModule.SlowerMalus
    else
        SpeedInfluenceTable.speedSlowerInfluence = 0
    end
    ApplySpeed(target)
end

function WalkSpeedModule.ApplyTalentBonus(target, isApply, value)
    if isApply then
        SpeedInfluenceTable.speedTalentInfluence += value
    else
        SpeedInfluenceTable.speedTalentInfluence = 0
    end
    ApplySpeed(target)
end

function WalkSpeedModule.ApplySpeedTalentFixBonus(target, isApply, value)
    if isApply then
        SpeedInfluenceTable.speedTalentFixInfluence += value
    else
        SpeedInfluenceTable.speedTalentFixInfluence = 0
    end
    ApplySpeed(target)
end

function WalkSpeedModule.ApplyPushMalus(isApply)
    if isApply then
        SpeedInfluenceTable.speedPushInfluence = WalkSpeedModule.PushMalus
    else
        SpeedInfluenceTable.speedPushInfluence = 0
    end
end

function WalkSpeedModule.SetSpeedToPegasus(target, isRemove)
    SpeedInfluenceTable.speedHorseCurrentInfluence = isRemove and 0 or WalkSpeedModule.PegasusBonus
    ApplySpeed(target)
end

function WalkSpeedModule.SetSpeedToRun(target)
    SpeedInfluenceTable.currentWalkSpeedMinus = 0
    ApplySpeed(target)
end

function WalkSpeedModule.SetSpeedToWalk(target)
    SpeedInfluenceTable.currentWalkSpeedMinus = WalkSpeedModule.WalkMalus
    ApplySpeed(target)
end

function WalkSpeedModule.CheckIfSlowerMalusIsApply()
    if SpeedInfluenceTable.speedSlowerInfluence == 0 then
        return false
    else
        return true
    end
end

-- Return the current speed Influence Table
function WalkSpeedModule.GetSpeedInfluenceTable()
    return SpeedInfluenceTable
end

if RunService:IsClient() then
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local PlayerControls = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls()

    local FlightModule = require(LocalPlayer.PlayerScripts.ClientPlayerSync.Modules.HorseRelated.HorseActions:WaitForChild("Flight"))

    --[[
        Function allow to stop or active fly movement depending of stat receive by SetControlsPlayerAndCreature call.
        Function SetControls... is call when UI are open or close and allow to make good behavior for movement on the ground of player and creature,
        with this function ApplyFlightStat we can make the good behavior for celestial crature too.
    ]]
    function ApplyFlightState(Creature, stat)
        if Creature.PrimaryPart then
            local fly = Creature.PrimaryPart:FindFirstChild("Flight")
            if fly then
                if not stat then
                    if fly.Enabled then
                        FlightModule:SetStyle("Helicopter")
                        FlightModule.TerminateConnections()
                        Creature.PrimaryPart.Flight.VectorVelocity = Vector3.new()
                    end
                else
                    if fly.Enabled then
                        FlightModule:SetStyle("Glider")
                    end
                end
            end
        end
    end

    function WalkSpeedModule.SetControlsPlayerAndCreature(stat)
        local creature = workspace.CreaturesFolder:FindFirstChild("Creature_"..LocalPlayer.Name)
        if stat then
            PlayerControls:Enable()
            if creature then
                blockedSpeedRatio = 1
                ApplySpeed(creature)
                ApplyFlightState(creature, stat)
            end
        else
            PlayerControls:Disable()
            if creature then
                blockedSpeedRatio = 0
                ApplySpeed(creature)
                ApplyFlightState(creature, stat)
            end
        end
    end

    --Connect module to SizeRatioChanged event to know what influence size have on speed creature and apply new speed bonus by size ratio
    HorseEvents.SizeRatioChanged.OnClientEvent:Connect(function(ratio, reset)
        local creature = workspace.CreaturesFolder:FindFirstChild("Creature_"..LocalPlayer.Name)
        if creature then
            if reset then
                SpeedInfluenceTable.speedSizeInfluence = 0
            else
                if SpeedInfluenceTable.speedSizeInfluence == 0 then
                    SpeedInfluenceTable.speedSizeInfluence = ratio * 50
                else
                    SpeedInfluenceTable.speedSizeInfluence = 0
                end
            end
            
            ApplySpeed(creature)
        end
    end)

    RemoteEvent.WalkSpeed.ApplySpeedTalentFixBonus.OnClientEvent:Connect(WalkSpeedModule.ApplySpeedTalentFixBonus)
    RemoteEvent.WalkSpeed.ApplyTalentBonus.OnClientEvent:Connect(WalkSpeedModule.ApplyTalentBonus)
    RemoteEvent.WalkSpeed.ApplyControlsPlayerAndCreature.OnClientEvent:Connect(WalkSpeedModule.SetControlsPlayerAndCreature)
end

return WalkSpeedModule