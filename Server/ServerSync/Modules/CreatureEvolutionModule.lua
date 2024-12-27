local CreatureEvolutionModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local TweenService = game:GetService("TweenService")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local PlayerDataModule = require("PlayerDataModule")
local RarityDataModule = require("RarityDataModule")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")
local SoundControllerModule = require("SoundControllerModule")

local CreatureTips = require("CreatureTips")
local Messages = CreatureTips.Messages

local ServerStorage = game.ServerStorage.ServerStorageSync
local CreaturesModularPartsFolder = ReplicatedStorage.SharedSync.Assets.CreaturesModularParts

local function AnimateEvolution(player:Player, color)
    RemoteEvent.CreatureEvolution.SetupCameraEvolution:FireClient(player, true)

    local particle = ReplicatedStorage.SharedSync.Assets.LevelUpParticle:Clone()
    local CreatureFolder = game.Workspace:FindFirstChild("CreaturesFolder")
    if CreatureFolder then
        local creatureModel = CreatureFolder:FindFirstChild("Creature_"..player.Name)
        if creatureModel then
            local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureModel.CreatureID.Value)
            -- Attach particle evolution part to creature
            local weld = Instance.new("Weld")
            weld.Parent = particle
            particle.Parent = creatureModel.HumanoidRootPart
            particle.CFrame = particle.Parent.CFrame
            weld.Part0 = creatureModel.HumanoidRootPart
            weld.Part1 = particle

            -- Hide player for evolution animation
            local playerPart = {}
            for _, v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    if v.Transparency < 1 then
                        playerPart[v.Name] = v.Transparency
                        v.Transparency = 1
                    end
                end
            end

            -- Activate First step of animation particle evolution
            SoundControllerModule:CreateSound("EvolutionComming", creatureModel.HumanoidRootPart)
            for _, v in pairs(particle.FirstStep:GetChildren()) do
                v.Enabled = true
            end

            -- Change size of number sequence for Core to make bigger and hide creature (not tween because can't tween NumberSequence)
            for i=1, 100 do
                particle.FirstStep.Core.Size = NumberSequence.new(i/10)
                task.wait(0.025)
            end

            -- When finish Core animation disable all First step animation effect
            SoundControllerModule:CreateSound("EvolutionDown", creatureModel.HumanoidRootPart)
            for _, v in pairs(particle.FirstStep:GetChildren()) do
                v.Enabled = false
            end

            -- Activate second part of animation with Emit of Color success evolution
            for _, v in pairs(particle.SecondStep:GetChildren()) do
                v.Color = color
                v:Emit(200)
            end

            task.wait(1.5)
            -- Restore visibility of player
            for _, v in pairs(player.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    if playerPart[v.Name] then
                        v.Transparency = playerPart[v.Name]
                    end
                end
            end

            RemoteEvent.CreatureEvolution.SetupCameraEvolution:FireClient(player, false)

            BindableEvent.ShowPopupAlert:Fire(
                player,
                "EVOLVED!",
                CreatureData.CreatureName.." is now "..CreatureData.Race.." type!",
                ToolsModule.AlertPriority.Annoucement,
                nil,
                ToolsModule.AlertTypeButton.OK,
                nil,
                {},
                nil,
                {}
            )
        end
    end
end

local function AnimateGiveExp(player, exp)
    if player.PlayerGui:FindFirstChild("LevelGUI") then
        local text = player.PlayerGui.LevelGUI:FindFirstChild("TextLabel")
        if text then
            text:SetAttribute("Value", tonumber(exp)+text:GetAttribute("Value"))
            text.Text = "+"..tostring(text:GetAttribute("Value")).." EXP"
        end
    else
        local levelGui = Instance.new("ScreenGui")
        levelGui.Name = "LevelGUI"
        local text = ReplicatedStorage.SharedSync.Assets.LevelupGUI.TextLabel:Clone()
        text.Parent = levelGui
        text:SetAttribute("Value", tonumber(exp)+text:GetAttribute("Value"))
        levelGui.Parent = player.PlayerGui
    
        text.Size = UDim2.fromScale(1,0.1)
        text.Position = UDim2.fromScale(Random.new():NextNumber(0.4,0.6), 0.17)
    
        text.Text = "+"..tostring(text:GetAttribute("Value")).." EXP"
        text.TextColor3 = Color3.fromRGB(238, 0, 255)
        local info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
        local goals = {Position = UDim2.fromScale(text.Position.X.Scale, 0.25)}
        local tween = TweenService:Create(text, info, goals)
        levelGui.Enabled = true
        tween:Play()
        tween.Completed:Connect(function()
            levelGui:Destroy()
        end)
    end
end

--[[
    This method was call to say on server and client side a evolution has taken place and make update on race behavior
]]
local function SendEventCreatureWasEvolved(player, creatureID)
    BindableEvent.CreatureWasEvolved:Fire()
    RemoteEvent.CreatureEvolution.CreatureWasEvolved:FireClient(player, creatureID)
end

--[[
    Function callback for make evolution of creature ID give in parameters
    This function allow to make evolution Data of creature. Increment race of creature, save level and
    send event creature was evolve to player animation and update all data connected to event evolution creature.
]]
local function EvolveCreature(Player, CreatureID)
    local CreatureData = PlayerDataModule:Get(Player, "CreaturesCollection."..CreatureID)
    -- Increment level of creature and update Races
    CreatureData.Level += 1
    CreatureEvolutionModule.IncrementNumberOfRace(Player, CreatureData.Race, CreatureData.CreatureType, -1)
    CreatureData.Race = GameDataModule.RaceEvolutionTable[CreatureData.Level].Race
    CreatureEvolutionModule.IncrementNumberOfRace(Player, CreatureData.Race, CreatureData.CreatureType, 1)
    CreatureData.Exp = 0
    
    --update rarity of creature after evolve
    CreatureData.Rating = RarityDataModule:CalculateCreatureRarity(CreatureData)
    CreatureData.ReadyToEvolve = false
    
    PlayerDataModule:Set(Player, CreatureData, "CreaturesCollection."..CreatureID)
    SendEventCreatureWasEvolved(Player, CreatureID)

    -- Launch Animation and change visual of creature with Evolution
    task.spawn(function()
        AnimateEvolution(Player, GameDataModule.RaceEvolutionTable[CreatureData.Level].ColorSequence)
    end)
    task.wait(2.2)
    CreatureEvolutionModule.MakeEvolution(Player, CreatureData.Race, CreatureData.CreatureType)
end

--[[
    Same function like EvolveCreature but we have a diffferent behavior for adapte it to CommandLine allow player authorized to change
    evolution of animal summoned
]]
function CreatureEvolutionModule.EvolveCreatureCommandeLine(Player, CreatureID, evolutionSelected)
    -- Found level of evolution selected
    local levelSelected = 1
    for level, evoData in pairs(GameDataModule.RaceEvolutionTable) do
        if evoData.Race == evolutionSelected then
            levelSelected = level
        end
    end

    local CreatureData = PlayerDataModule:Get(Player, "CreaturesCollection."..CreatureID)
    -- Increment level of creature and update Races
    CreatureData.Level = levelSelected
    CreatureEvolutionModule.IncrementNumberOfRace(Player, CreatureData.Race, CreatureData.CreatureType, -1)
    CreatureData.Race = GameDataModule.RaceEvolutionTable[CreatureData.Level].Race
    CreatureEvolutionModule.IncrementNumberOfRace(Player, CreatureData.Race, CreatureData.CreatureType, 1)
    CreatureData.Exp = 0
    
    --update rarity of creature after evolve
    CreatureData.Rating = RarityDataModule:CalculateCreatureRarity(CreatureData)
    CreatureData.ReadyToEvolve = false
    
    PlayerDataModule:Set(Player, CreatureData, "CreaturesCollection."..CreatureID)
    SendEventCreatureWasEvolved(Player, CreatureID)

    -- Launch Animation and change visual of creature with Evolution
    task.spawn(function()
        AnimateEvolution(Player, GameDataModule.RaceEvolutionTable[CreatureData.Level].ColorSequence)
    end)
    task.wait(2.2)
    CreatureEvolutionModule.MakeEvolution(Player, CreatureData.Race, CreatureData.CreatureType)
end

function CreatureEvolutionModule.MakeEvolution(player, race, creatureType)
    local CreatureFolder = game.Workspace:FindFirstChild("CreaturesFolder")
    if CreatureFolder then
        local creatureModel = CreatureFolder:FindFirstChild("Creature_"..player.Name)
        if creatureModel then

            local SizeEffectActive = creatureModel.PrimaryPart:GetAttribute("SizeEffectActive")
			local SizeRatio = creatureModel.PrimaryPart:GetAttribute("SizeRatio")

            --model ok make evolution
            --TAIL EVOLVE
            local TailEvolve = CreaturesModularPartsFolder[creatureType].Tail[race]:Clone()
            TailEvolve.Parent = creatureModel

            creatureModel.Tail.Motor6D.Parent = TailEvolve
            TailEvolve.Motor6D.Part1 = TailEvolve

            TailEvolve.BrickColor = creatureModel.Tail.BrickColor
            TailEvolve.Material = creatureModel.Tail.Material
            
            local exist = creatureModel.Tail:FindFirstChildOfClass("SurfaceAppearance")
            if exist then
                local clone = exist:Clone()
                clone.Parent = TailEvolve
            else
                TailEvolve.TextureID = creatureModel.Tail.TextureID
            end

            --check if this Part contain Tattoo Texture and check if we need to setup this
            for _, texture in pairs(creatureModel.Tail:GetChildren()) do
                if texture:IsA("Texture") then
                    if TailEvolve:FindFirstChild(texture.Name) then
                        TailEvolve[texture.Name].Texture = texture.Texture
                        TailEvolve[texture.Name].Transparency = texture.Transparency
                    end
                end
            end
            
            creatureModel.Tail:Destroy()
            TailEvolve.Name = "Tail"

            if SizeEffectActive then
                ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), TailEvolve)
            end

            --MANE EVOLVE
            local ManeEvolve = CreaturesModularPartsFolder[creatureType].Mane[race]:Clone()
            ManeEvolve.Parent = creatureModel

            creatureModel.Mane.Motor6D.Parent = ManeEvolve
            ManeEvolve.Motor6D.Part1 = ManeEvolve

            ManeEvolve.BrickColor = creatureModel.Mane.BrickColor
            ManeEvolve.Material = creatureModel.Mane.Material
            
            local exist = creatureModel.Mane:FindFirstChildOfClass("SurfaceAppearance")
            if exist then
                local clone = exist:Clone()
                clone.Parent = ManeEvolve
            else
                ManeEvolve.TextureID = creatureModel.Mane.TextureID
            end

            --check if this Part contain Tattoo Texture and check if we need to setup this
            for _, texture in pairs(creatureModel.Mane:GetChildren()) do
                if texture:IsA("Texture") then
                    if ManeEvolve:FindFirstChild(texture.Name) then
                        ManeEvolve[texture.Name].Texture = texture.Texture
                        ManeEvolve[texture.Name].Transparency = texture.Transparency
                    end
                end
            end
            
            creatureModel.Mane:Destroy()
            ManeEvolve.Name = "Mane"

            if SizeEffectActive then
                ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), ManeEvolve)
            end

            --Show Wings if race are Celestial
            if race == "Celestial" then
                creatureModel["Wing_Left"].Transparency = 0.01
                creatureModel["Wing_Right"].Transparency = 0.01
            else
                creatureModel["Wing_Left"].Transparency = 1
                creatureModel["Wing_Right"].Transparency = 1
            end
        end
    end
end

function CreatureEvolutionModule.GiveNbEXP(player, creatureID, value)
    local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
    --check if horse can gain exp
    if CreatureData["LockExp"] then
        if CreatureData.LockExp then
            --warn("Horse Can't Win EXP, Locked by player !")
            return false
        end
    end

    -- If creature are ready to evolve she can't win exp
    if CreatureData.ReadyToEvolve then
        return false
    end

    --check talent creature
    if CreatureData.Talents["ExpSpeed"] then
        value += math.floor(value * (CreatureData.Talents["ExpSpeed"]/100))
    end

    CreatureData.Exp += value

    --[[ if CreatureData.Level == 1 and CreatureData.Exp > 0 and CreatureData.Exp <= 10 then -- TODO: Check to ensure they are a new player
        BindableEvent.ShowPopupAlert:Fire(player, Messages.FirstCrystal.Title, Messages.FirstCrystal.Message, ToolsModule.AlertPriority.Annoucement, "Dismiss", "Test", Messages.FirstCrystal.Function, {player}, CreatureTips.TextParams)
    end ]]

    if GameDataModule.RaceEvolutionTable[CreatureData.Level + 1] then
        if CreatureData.Exp >= GameDataModule.RaceEvolutionTable[CreatureData.Level + 1].EXP then
            if not CreatureData.ReadyToEvolve then
                CreatureData.ReadyToEvolve = true
                -- Creature can evolve into another race creature
                RemoteEvent.CreatureEvolution.ReadyToEvolve:FireClient(player)
            end
        else
            AnimateGiveExp(player, value)
        end
    else
        warn("Level Max was Reach")
        return false
    end

    PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
    return true
end

function CreatureEvolutionModule.IncrementNumberOfRace(player, creatureRace, creatureType, value)
	local TotalNumberOfCreaturesType = PlayerDataModule:Get(player, "TotalNumberOfCreaturesType")
	TotalNumberOfCreaturesType[creatureType][creatureRace] += value
	PlayerDataModule:Set(player, TotalNumberOfCreaturesType, "TotalNumberOfCreaturesType")
end

RemoteEvent.CreatureEvolution.LaunchEvolve.OnServerEvent:Connect(EvolveCreature)

RemoteFunction.CreatureEvolution.GiveExpToCreature.OnServerInvoke = function(player, creatureID, value)
    return CreatureEvolutionModule.GiveNbEXP(player, creatureID, value)
end

RemoteFunction.CreatureEvolution.GetLevelPalierExp.OnServerInvoke = function(player, level)
    local data = GameDataModule.RaceEvolutionTable[level+1]
    return data and data.EXP or "N/A"
end

return CreatureEvolutionModule