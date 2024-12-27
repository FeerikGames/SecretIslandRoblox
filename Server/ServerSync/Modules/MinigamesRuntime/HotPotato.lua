local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage.SharedSync.Assets
local Creatures = Workspace:FindFirstChild("CreaturesFolder")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local StartingZoneModule = require("StartingZoneModule")
local GameFunctions = require(script.Parent.GameFunctions)
local ToolsModule = require("ToolsModule")
local Maid = require("Maid")

local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_MiniGameUiState = RemoteEventFolder:WaitForChild("MiniGameUiState")
local RE_ActivateGame = RemoteEventFolder.ActivateGame


local HotPotato = {}

HotPotato.GameData = {
    Ongoing = false,
    WaitingForMorePlayers = false,
    isEventRunning = false,
    EventTimeInSec = 40,
    EventCurrentTime = 0,
	WaitForOthersTimeInSec = 3,
	WaitForOthersCountDown = 0,
    playerNeeded = 2,
    GameName = "HotPotato",
    DisplayName = "Hot Potato",
    TimeBeforeExplosion = 130,
    DelayBeforeCanTag = 2,
    Players = {},
    Tagger = nil,
    Connections = nil,
}


local function InitTaggerConnections(Player)
    if HotPotato.GameData.Connections then
        HotPotato.GameData.Connections:DoCleaning()
    end
    
    HotPotato.GameData.Tagger = Player
    
    local Creature = Creatures:FindFirstChild("Creature_" .. Player.player.Name)
    if not Creature then
        return
    end

    local TagColour = Creature.HumanoidRootPart:FindFirstChild("TagColour")
    if not TagColour then
        TagColour = Assets.TagColour:Clone()
        TagColour.Parent = Creature.HumanoidRootPart
        TagColour.Frame.BackgroundColor3 = Color3.new(1, 0, 0)
    end

    task.spawn(function()
        task.wait(HotPotato.GameData.DelayBeforeCanTag) -- So they can't instantly tag someone
        HotPotato.GameData.Connections = Maid.new()    
        HotPotato.GameData.Connections:GiveTask(Creature.HumanoidRootPart.Touched:Connect(function(Object)
            -- Touch need work only if HumanoidRootPart of other creature player is touch
            local TargetRootPart = Object.Name == "HumanoidRootPart" and Object or nil
            if not TargetRootPart then
                return
            end

            local FindCreatureOwner = string.split(TargetRootPart.Parent.Name, "_") -- Check if owner is tagger
            local Owner = Players:FindFirstChild(FindCreatureOwner[2])
            local getPlayer = HotPotato.GameData.Players[Owner.UserId]
            if not getPlayer then
                return
            end

            if Owner then
                HotPotato.GameData.Connections:DoCleaning()
                print("FOUND OWNER TO GIVE TAG TO: ", TargetRootPart)
                local TagColour = Creature.HumanoidRootPart:FindFirstChild("TagColour")
                if TagColour then
                    TagColour.Parent = TargetRootPart
                end

                HotPotato:AssignTagger(getPlayer)
                return
            end
        end))
    end)
end

function HotPotato:StartGame()
    local Multiplier = 1.1
    self.GameData.ActiveGame = true
    local Delay = 1

    if not self.GameData.Tagger then
        self:AssignTagger()
    end

    local Creature = Creatures:FindFirstChild("Creature_" .. self.GameData.Tagger.player.Name)
    local TagColour = Creature.HumanoidRootPart:FindFirstChild("TagColour")

    task.spawn(function()
        for i = 1, self.GameData.TimeBeforeExplosion do
            Delay /= Multiplier
            task.wait(Delay)

            if self.GameData.Tagger == nil then
                self:AssignTagger()
            end
            if ToolsModule.LengthOfDic(self.GameData.Players) < self.GameData.playerNeeded then
                self.GameData.ActiveGame = false
                break
            end

            Creature = Creatures:FindFirstChild("Creature_" .. self.GameData.Tagger.player.Name)
            TagColour = Creature.HumanoidRootPart:FindFirstChild("TagColour")

            if TagColour then
                local SelectedColour = TagColour.Frame.BackgroundColor3 == Color3.new(1, 1, 1) and Color3.new(1, 0, 0) or Color3.new(1, 1, 1)
                TagColour.Frame.BackgroundColor3 = SelectedColour
            end
         end

         if TagColour then
            TagColour:Destroy()
         end

        if self.GameData.Tagger then
            print("Explode the player: ", self.GameData.Tagger.player)
            local Character = self.GameData.Tagger.player.Character
            local VectorForce = Instance.new("VectorForce")
            VectorForce.Attachment0 = Character.HumanoidRootPart.RootRigAttachment
            VectorForce.Force = Vector3.new(0,2500000,0)
            VectorForce.Enabled = true
            VectorForce.Parent = Character.HumanoidRootPart
            Debris:AddItem(VectorForce, 1.5)
        end

        print("ENDING THE HOT POTATO GAME")
        for _, Player in pairs(self.GameData.Players) do
            HotPotato:PlayerLeave(Player.player)
            GameFunctions:CanPlay(Player.player, "HotPotato") -- <- Remove all players from minigame when it's over
        end

        self.GameData.Ongoing = false
        self.GameData.ActiveGame = false

        -- Game ending make event to try to relaunch game if found player participants already in zone mini game
        ReplicatedStorage.SharedSync.BindableEvent:WaitForChild("RestartMiniGameEvent"):Fire(self.GameData)
    end)
end

function HotPotato:AssignTagger(NewTagger)
    if NewTagger then
        InitTaggerConnections(NewTagger)
        return
    end

    local ActivePlayers = ToolsModule.LengthOfDic(HotPotato.GameData.Players)
    if HotPotato.GameData.Tagger ~= nil or ActivePlayers == 0 then
        return
    end
    local randomPlayer = math.random(ToolsModule.LengthOfDic(HotPotato.GameData.Players))
    local randomPlayerUserId = nil
    local count = 1

    for UserId, player in pairs(HotPotato.GameData.Players) do
        if count == randomPlayer then
            randomPlayerUserId = UserId
        end
        count += 1
    end
    
    local GetPlayer = HotPotato.GameData.Players[randomPlayerUserId]
    HotPotato.GameData.Tagger = GetPlayer
    InitTaggerConnections(GetPlayer)
end

function HotPotato:PlayerLeave(player)
    local PlayerInstance = HotPotato.GameData.Players[player.UserId]
    RE_MiniGameUiState:FireClient(player, HotPotato.GameData, "Finish")
    RE_ActivateGame:FireClient(PlayerInstance.player, HotPotato.GameData, true)
    StartingZoneModule:EndPlayerCurrentGame(HotPotato.GameData, PlayerInstance.player)
    if HotPotato.GameData.Tagger == PlayerInstance then
        HotPotato.GameData.Tagger = nil
    end
    local TagColour = PlayerInstance.creature.HumanoidRootPart:FindFirstChild("TagColour")
    if TagColour then
        TagColour:Destroy()
    end
    
    HotPotato.GameData.Players[player.UserId] = nil
end


-- setup player data for the game
local function SetupPlayerData(PlayerInstance)
    HotPotato.GameData.Players[PlayerInstance.player.UserId] = PlayerInstance
end

function HotPotato:Init(PlayerInstance, Button)
    local Creature = PlayerInstance.creature
    if not Creature then
        return
    end
    SetupPlayerData(PlayerInstance)
    self:AssignTagger()
    if not HotPotato.GameData.ActiveGame then
        self:StartGame()
    end
end

Creatures.ChildRemoved:Connect(function(Child)
    local FindCreatureOwner = string.split(Child.Name, "_") -- Getting creature owner <- Do we have a function for this elsewhere?
    local Owner = Players:FindFirstChild(FindCreatureOwner[2])
    if not HotPotato.GameData.Tagger then
        return
    end
    if HotPotato.GameData.Tagger.player == Owner then
        HotPotato.GameData.Tagger = nil
        HotPotato.GameData.Connections:DoCleaning()
        local IsPlaying = table.find(HotPotato.GameData.Players, Owner)
        if IsPlaying then
            table.remove(HotPotato.GameData.Players, IsPlaying)
        end

        HotPotato:AssignTagger()
    end
end)

return HotPotato