local CreatureSizeModule = {}


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")

local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local function SetSeatPlayer(model)
	local RiderM6D = model.Seat:FindFirstChild("RiderM6D")
	local succes, error = pcall(function()
		RiderM6D.C1 = model.PrimaryPart.Motor6D.C1 * CFrame.new(0,-model.PrimaryPart.Size.Y,0)
	end)
	if error then
		warn("Player not found on creature so can't setup seat position")
	end
end

local function sizingEveryMesh(Character, model, SizeRatio, SizeFromOriginal)
    model.PrimaryPart:SetAttribute("SizeEffectActive", true)
    model.PrimaryPart:SetAttribute("SizeRatio", SizeFromOriginal)
    if not model or not model.PrimaryPart then
        return
    end
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), child)
        elseif child:IsA("Folder") then
            for _, part in pairs(child:GetChildren()) do
                ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), part)
            end
        end
    end

    -- Check effect feet particle and resize it with ratio
    for _, particle in pairs(model.Socks.EffectFeet:GetChildren()) do
        if particle:IsA("ParticleEmitter") then
            particle.Size = NumberSequence.new{
                NumberSequenceKeypoint.new(0,ToolsModule.EvalNumberSequence(particle.Size,0)*SizeRatio),
                NumberSequenceKeypoint.new(1,ToolsModule.EvalNumberSequence(particle.Size,1)*SizeRatio)
            }
        end
    end

    SetSeatPlayer(model)
    --event to allow client setup speed, jump or camera depending of size ratio
    HorseEvents.SizeRatioChanged:FireClient(game.Players[Character.Name], SizeRatio)
end

function CreatureSizeModule.ResizeCreature(Character, SizeRatio, EffectTime)
    -- Check if player have gamepass X2 power size duration
    EffectTime = BindableFunction.CheckPlayerHasGamepass:Invoke(game.Players[Character.Name], GameDataModule.Gamepasses.GiantsDurationX2.ProductID) and EffectTime * 2 or EffectTime
    
    --Found creature and if yes we launch resize on all meshpart of creature
    local model = game.Workspace.CreaturesFolder:FindFirstChild("Creature_"..Character.Name)
    if not model then
        return
    end
    if model.PrimaryPart:GetAttribute("SizeEffectActive") then
        return
    end
    local rider = model.Seat:FindFirstChild("Rider")
    if not rider then
        return
    elseif not rider.Value then
        return
    end
    sizingEveryMesh(Character, model, SizeRatio, SizeRatio)
    --Resize creature back after a time.
    task.delay(EffectTime, function()
        -- Check if Animal are alaway summon before make a resizing
        if game.Workspace.CreaturesFolder:FindFirstChild("Creature_"..Character.Name) ~= model then
            return
        end
        sizingEveryMesh(Character, model, 1/SizeRatio, 1)
        model.PrimaryPart:SetAttribute("SizeEffectActive", false)
    end)
end

local function SetupResizeSpheres()
    local folder = workspace.SystemUnlockable:WaitForChild("ScaleSystem",3)
    if folder then
        for _, sphere in pairs(folder:GetChildren()) do
            local SizeRatio = sphere:GetAttribute("SizeRatio")
            local EffectTime = sphere:GetAttribute("EffectTime")
            --Touch event to launch resize of creature touch if there is player
            sphere.Touched:Connect(function(target)
                if not (target.Name == "HumanoidRootPart") or not target.Parent then
                    return
                end
                local Character = target.Parent
                local Humanoid = Character:FindFirstChild("Humanoid")
                if not Humanoid or Character.Name:match("Creature") then
                    return
                end
                CreatureSizeModule.ResizeCreature(Character, SizeRatio, EffectTime)
            end)
        end
    end
end

SetupResizeSpheres()

HorseEvents.CreatureResizeEvent.OnServerEvent:Connect(function(player, SizeRatio, EffectTime)
    CreatureSizeModule.ResizeCreature(player, SizeRatio, EffectTime)
end)

return CreatureSizeModule