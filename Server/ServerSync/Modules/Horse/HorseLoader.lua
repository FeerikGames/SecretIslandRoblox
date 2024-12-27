local HorseLoader = {}
local HttpService = game:GetService("HttpService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))


local MovementAI = require("MovementAI")
local Signal = require("Signal")
local HorseAnimator = require("HorseAnimator")
local DataManagerModule = require("DataManagerModule")
local RarityDataModule = require("RarityDataModule")
local ToolsModule = require("ToolsModule")
local EnvironmentModule = require("EnvironmentModule")

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local HorseEvent = HorseEvents:WaitForChild("HorseEvent")
local RE_HorseMountEvent = HorseEvents.HorseMountEvent
local RE_HorseDeloaded = HorseEvents:WaitForChild("HorseDeloaded")
local BF_Horsemount = HorseEvents:WaitForChild("HorseMountBindableFunction")
--local RE_HorseAudio = HorseEvents:WaitForChild("HorseAudioEvent")

local Assets = ReplicatedStorage.SharedSync:WaitForChild("Assets")

local CreaturesFolder = workspace:FindFirstChild("CreaturesFolder") or Instance.new("Folder")
CreaturesFolder.Parent = workspace
CreaturesFolder.Name = "CreaturesFolder"

local CharacterFolder = workspace:WaitForChild("CharacterFolder")
local CreaturesModularPartsFolder = Assets.CreaturesModularParts

--to save the original height of creature
local OriginHipHeight


-- Config
local CreatureToLoad = 1
--

print("Creature loader init")
local CreatureSpawns = {}
local SpawnsFolder = workspace:WaitForChild("CreaturesSpawns",1)
if SpawnsFolder then
    for _,Spawn in ipairs(SpawnsFolder:GetChildren()) do
        table.insert(CreatureSpawns,{
            CFrame = Spawn.CFrame,
            Size = Spawn.Size
        })
        Spawn:Destroy()
    end
end

HorseLoader.PlayerMountedHorse = Signal.new()
HorseLoader.PlayerDismountedHorse = Signal.new()

HorseLoader.ActiveCreatures = {}

local function GetActiveCreatureDataByID(ID)
    for _,CreatureData in ipairs(HorseLoader.ActiveCreatures) do
        if CreatureData.ID == ID then
            return CreatureData
        end
    end
end

local function RemoveActiveCreatureDataByID(ID)
    for _,CreatureData in ipairs(HorseLoader.ActiveCreatures) do
        if CreatureData.ID == ID then
           table.remove(HorseLoader.ActiveCreatures, _)
        end
    end
end

--[[
    This function allow to apply randomly color, race and material to IA invoked.
]]
local function MakeRandomAppearenceCreature(NewCreature, CreatureType)
    --Get random race for creature
    local RaceRandom = ToolsModule.GetRandomValueFromDictionnary(BindableFunction.GetAllCreatureRace:Invoke())

    --Check for apply Race Tail
	local TailEvolve = CreaturesModularPartsFolder[CreatureType].Tail[RaceRandom]:Clone()
	TailEvolve.Parent = NewCreature
	NewCreature.Tail.Motor6D.Parent = TailEvolve
	TailEvolve.Motor6D.Part1 = TailEvolve
	NewCreature.Tail:Destroy()
	TailEvolve.Name = "Tail"

	--Check for apply Race Mane
	local ManeEvolve = CreaturesModularPartsFolder[CreatureType].Mane[RaceRandom]:Clone()
	ManeEvolve.Parent = NewCreature
	NewCreature.Mane.Motor6D.Parent = ManeEvolve
	ManeEvolve.Motor6D.Part1 = ManeEvolve
	NewCreature.Mane:Destroy()
	ManeEvolve.Name = "Mane"

    --Apply some random color/Material on part creature
    local markingColor = BrickColor.Random()
    local markingMaterial = RarityDataModule.GetRandomMaterial()
    for _, part in pairs(NewCreature:GetChildren()) do
        if string.lower(part.Name):match("marking") then
            part.BrickColor = markingColor
            part.Material = markingMaterial
        end
    end
    NewCreature.Mane.BrickColor = BrickColor.Random()
    NewCreature.Mane.Material = RarityDataModule.GetRandomMaterial()
    NewCreature.Socks.BrickColor = BrickColor.Random()
    NewCreature.Socks.Material = RarityDataModule.GetRandomMaterial()
    NewCreature.Tail.BrickColor = BrickColor.Random()
    NewCreature.Tail.Material = RarityDataModule.GetRandomMaterial()
end

function HorseLoader:GetCreatureWithPlayer(Player)
	for _,Horse in pairs(HorseLoader.ActiveCreatures) do
        if Horse.Instance then
            if Horse.Instance.Seat and Horse.Instance.Seat:FindFirstChild("Rider") then
                if Horse.Instance.Seat.Rider.Value == Player then
                    return Horse
                end
            end
        end
	end
end

function HorseLoader:MountCreature(Player,ID)
	if not HorseLoader:GetCreatureWithPlayer(Player) then
		local CreatureData = GetActiveCreatureDataByID(ID)
        if CreatureData then
            HorseEvents.ShowHealthBar:FireClient(Player, true, ID)
            if CreatureData.MovementAI then
                print("its gone thooo")
                CreatureData.MovementAI:Terminate()
            end
            if CreatureData.Animator then
                CreatureData.Animator:Unbind()
            end
            local RiderValue = CreatureData.Instance.Seat:FindFirstChild("Rider")
            if not RiderValue or RiderValue.Value == nil then
                if not RiderValue then
                    RiderValue = Instance.new("ObjectValue",CreatureData.Instance.Seat)
                    RiderValue.Name = "Rider"
                end
                if CreatureData.Instance.PrimaryPart:FindFirstChild("Prompt") then
                    CreatureData.Instance.PrimaryPart.Prompt.Enabled = false
                end
                RiderValue.Value = Player
                CreatureData.Instance.Parent = CreaturesFolder
                --CreatureData.Instance:PivotTo(Player.Character.PrimaryPart.CFrame)
                local Human = Player.Character
                Human.Archivable = true
                local Humanoid = Human:FindFirstChild("Humanoid")
                Human.Parent = CharacterFolder
                if Humanoid then
                    Humanoid.Sit = true
                    Humanoid.AutoRotate = false
                    --CreatureData.Instance.PrimaryPart.Anchored = true
                    Human:PivotTo(CreatureData.Instance.Seat.CFrame)
                    local RiderM6D = Instance.new("Motor6D")
                    RiderM6D.Name = "RiderM6D"
                    RiderM6D.Parent = CreatureData.Instance.Seat
                    RiderM6D.Part0 = CreatureData.Instance.Seat
                    RiderM6D.C1 = CreatureData.Instance.PrimaryPart.Motor6D.C1 * CFrame.new(0,-CreatureData.Instance.PrimaryPart.Size.Y,0)
                    RiderM6D.Part1 = Human.PrimaryPart
                    --CreatureData.Instance.PrimaryPart.Anchored = false
                end

                self.PlayerMountedHorse:Fire(Player,CreatureData)
                RE_HorseMountEvent:FireClient(Player, CreatureData)
                return CreatureData
            else
                warn("Someone is already on that creature",ID)
            end
        else
            warn("Invalid creature ID",ID)
        end
    else
        warn("player is on a creature")
	end
end

function HorseLoader:DismountCreature(Player)
	local Creature = HorseLoader:GetCreatureWithPlayer(Player)
    if Creature then
        HorseEvents.ShowHealthBar:FireClient(Player, false)
        local CreatureInstance = Creature.Instance
        if CreatureInstance.Seat:FindFirstChild("RiderM6D") then
            CreatureInstance.Seat.RiderM6D:Destroy()
        end
        if CreatureInstance.Seat:FindFirstChild("Rider") then
            CreatureInstance.Seat.Rider.Value = nil
        end
        if CreatureInstance.PrimaryPart:FindFirstChild("Prompt") then
            CreatureInstance.PrimaryPart.Prompt.Enabled = true
        end
        Player.Character = CharacterFolder[Player.Name]
        local Humanoid = Player.Character:FindFirstChild("Humanoid")
        if Humanoid then
            Humanoid.Sit = false
            Humanoid.AutoRotate = true
        end
        Player.Character:PivotTo(CFrame.new(Player.Character.PrimaryPart.Position))

        self.PlayerDismountedHorse:Fire(Player,Creature)
        RE_HorseMountEvent:FireClient(Player)
        --MovementAI:Make(Horse)
    end
end

function HorseLoader.MakeCreatureDataTable(Creature, CreatureData, CreatureID)
    local NewID = CreatureID or HttpService:GenerateGUID(false)
    local NewCreatureObject = {
        Instance = Creature,
        PrimaryPart = Creature.PrimaryPart,
        Humanoid = Creature:WaitForChild("Humanoid"),
        ID = NewID,
        CreatureType = CreatureData and CreatureData.CreatureType or "Horse" --if creature data not given, by default it's a Horse creature (for IA)
    }
    function NewCreatureObject:Terminate()
        if self.Instance then
            if self.Instance.PrimaryPart then
                local FXPart = self.Instance.PrimaryPart:Clone()
                FXPart.Anchored = true
                FXPart.CanCollide = false
                FXPart.CanTouch = false
                FXPart.CanQuery = false
                FXPart.Parent = workspace
                Debris:AddItem(FXPart,10)
                FXPart.Transparency = 1
                local FX = Assets.HorseTerminationEffect:Clone()
                FX.Parent = FXPart
                FX.Enabled = true
                task.delay(0.5,function()
                    FX.Enabled = false
                end)
            end
            self.Instance:Destroy()
        end
    end
    HorseAnimator:Bind(NewCreatureObject)
    return NewCreatureObject
end

local DefaultHorseOffset = 0
function HorseLoader:LoadCreature(CreatureInfo,isAI)
    local Creature = not isAI and CreatureInfo[1] or nil
    local CreatureData = not isAI and CreatureInfo[2] or nil
    local RandomCreatureTypeIA = ToolsModule.GetRandomValueFromDictionnary(BindableFunction.GetAllCreatureType:Invoke())
    local NewCreature = (Creature or Assets.CreaturesModels[RandomCreatureTypeIA.."Character"]:Clone())
    
    if isAI then
        NewCreature.Parent = CreaturesFolder
    end

    if not Creature then
        if #CreatureSpawns > 0 then
            local TargetSpawn = CreatureSpawns[math.random(#CreatureSpawns)]
            local SpawnCFrame = TargetSpawn.CFrame * CFrame.new(math.random(math.ceil(TargetSpawn.Size.X/2)),0,math.random(math.ceil(TargetSpawn.Size.Z/2)))
            NewCreature:PivotTo(SpawnCFrame)
            DefaultHorseOffset += 4
        end
    end

    local Sound = Instance.new("Sound")
    Sound.Name = "Running"
    Sound.Looped = true
    Sound.Volume = 0
    Sound:Play()
    Sound.Parent = NewCreature.PrimaryPart

    local NewData = self.MakeCreatureDataTable(NewCreature, CreatureData, not isAI and Creature.CreatureID.Value or nil)
    
    if isAI then
        MakeRandomAppearenceCreature(NewCreature, RandomCreatureTypeIA)
        MovementAI:Make(NewData)
    end
    
    --check talent of creature
    if CreatureData then
        if CreatureData.Talents["Speedy"] then
            RemoteEvent.WalkSpeed.ApplySpeedTalentFixBonus:FireClient(game.Players[Creature.Name:split("_")[2]], Creature, true, CreatureData.Talents["Speedy"] )
        end
    end

    --save original size of creature loaded
    OriginHipHeight = NewCreature.Humanoid.HipHeight
    --connect to event attribute change of Size ratio, if change we apply ratio on height creature so that its size corresponds with the height of the ground
    NewCreature.HumanoidRootPart:GetAttributeChangedSignal("SizeRatio"):Connect(function()
        local ratio = NewCreature.HumanoidRootPart:GetAttribute("SizeRatio")
        if ratio == 1 then
            NewCreature.Humanoid.HipHeight = OriginHipHeight
            NewCreature.Humanoid.JumpPower = 60
        else
            NewCreature.Humanoid.HipHeight *= ratio
            --size influence jump power for tall creature
            NewCreature.Humanoid.JumpPower *= ratio
        end
    end)

    table.insert(self.ActiveCreatures,NewData)
    NewCreature:SetAttribute("ID",NewData.ID)
    print("doing bind?")
    HorseEvent:FireAllClients("Add",NewData)
end

function HorseLoader:DeLoadCreature(Creature, player)
    print("Deload Creature", Creature.Name)
    RemoveActiveCreatureDataByID(Creature:GetAttribute("ID"))
    RE_HorseDeloaded:FireClient(player)
    Creature:Destroy()
end

function HorseLoader:Init()    
    PhysicsService:RegisterCollisionGroup("Horses")
    
    local function HorseCollisonGroup(Horse)
        for _,Part in ipairs(Horse:GetDescendants()) do
            if Part:IsA("BasePart") then
                Part.CollisionGroup = "Horses"
            end
        end
    end

    CreaturesFolder.ChildAdded:Connect(HorseCollisonGroup)
    for _,Horse in pairs(CreaturesFolder:GetChildren()) do
        HorseCollisonGroup(Horse)
    end

    local function creatureMount(Player,Reason,CreatureID)
        if Reason == "Mount" then
            if Player.Character then
                if CreatureID then -- is human
                    print("Wants to mount")
                    return self:MountCreature(Player,CreatureID)
                else -- is horse
                    self:DismountCreature(Player)
                    return false
                end
            end
        elseif Reason == "GetHorses" then
            return self.ActiveCreatures
        end
    end
    --
    HorseEvents.HorseMountFunction.OnServerInvoke = function(Player,Reason,CreatureID)
        return creatureMount(Player,Reason,CreatureID)
    end
    BF_Horsemount.OnInvoke = function(Player,Reason,CreatureID)
        return creatureMount(Player,Reason,CreatureID)
    end

    HorseEvent.OnServerEvent:Connect(function(...)
        HorseEvent:FireClient(...)
    end)

    --[[RE_HorseAudio.OnServerEvent:Connect(function(Client)
        print(Client.Name .. " has fired the server!")
    end)]]

    --[[
        Event allow to client to set localplayer as NetworkOwner of Creature ID give in parameter
        SetNetworkOwner can onyl call on server side and client know when summoned creature is down at the end he ask server
        to make it owner network of creature invoked.
        If dismount or remove creature we have takeOwner false and make a SetNetworkOwnershipAuto() because if nobody mount creature
        it’s not really important who owns an empty.
    ]]
    HorseEvents.SetNetworkOwner.OnServerEvent:Connect(function(player, creatureID, takeOwner)
        local CreatureData = GetActiveCreatureDataByID(creatureID)
        if CreatureData then
            if takeOwner then
                CreatureData.Instance.HumanoidRootPart:SetNetworkOwner(player)
            else
                CreatureData.Instance.HumanoidRootPart:SetNetworkOwnershipAuto()
            end
        end
    end)
    --
    --[[ for _,Horse in pairs(CreaturesFolder:GetChildren()) do
        self:LoadCreature({Horse, nil},true)
    end ]]

    --Setup IA in environment only on principal place
    if game.PlaceId == EnvironmentModule.GetPlaceId("MainPlace") then
        for i=1,CreatureToLoad do
            self:LoadCreature(nil,true)
        end
    end
    
end

return HorseLoader