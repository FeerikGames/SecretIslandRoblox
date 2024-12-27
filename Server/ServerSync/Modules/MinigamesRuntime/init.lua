local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_MiniGameUiState = RemoteEventFolder:WaitForChild("MiniGameUiState")
local RE_MiniGameGiveUp = RemoteEventFolder:WaitForChild("MiniGameGiveUp")
local RE_ActivateGame = RemoteEventFolder.ActivateGame

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local GameFunctions = require(script.GameFunctions)
local GamePanelModule = require("GamePanelModule")
local ToolsModule = require("ToolsModule")
local StartingZoneModule = require("StartingZoneModule")

-- Remote Events
local PlayerEnterMiniGameEvent = Instance.new("RemoteEvent", ReplicatedStorage.SharedSync.RemoteEvent.MiniGames)
PlayerEnterMiniGameEvent.Name = "PlayerEnterMiniGameEvent"
local PlayerExitMiniGameEvent = Instance.new("RemoteEvent", ReplicatedStorage.SharedSync.RemoteEvent.MiniGames)
PlayerExitMiniGameEvent.Name = "PlayerExitMiniGameEvent"

local RestartMiniGameEvent = Instance.new("BindableEvent", ReplicatedStorage.SharedSync.BindableEvent)
RestartMiniGameEvent.Name = "RestartMiniGameEvent"

local MinigameModule = {}
MinigameModule.LoadedModules = {}
MinigameModule.InMinigame = {}
MinigameModule.Settings = {
    TagName = "MinigameButtons",
    CanClick = true,
    CanTouch = true,
    ButtonDelay = 2, -- Attribute or Default statement
}

local function Activate(Player, Model)
    print("Minigame: ", Player, Model)
    local Button = Model:FindFirstChild("Button")
    if Button then
        local Properties = {
            Size = Vector3.new(Button.Size.X, Button.Size.Y / 2, Button.Size.Z),
            Position = Button.Position - Vector3.new(0, Button.Size.Y / 2, 0)
        }

        --TweenService:Create(Button, TweenInfo, Properties):Play()
    end

    local MinigameName = Model.Parent.Name
    local CanPlay = GameFunctions:CanPlay(Player, MinigameName)
    if not CanPlay then
        return
    end

    local GameModule = MinigameModule.LoadedModules[MinigameName]

    GameModule:Init(Player, Model)
end

local function GetWorldSize(part)
	local size = part.CFrame:VectorToWorldSpace(part.Size)
	return Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
end

function MinigameModule:Init()
    for _, Module in pairs(script:GetChildren()) do
        local loadModule = coroutine.create(function()
            local GameModule = require(Module)
            self.LoadedModules[Module.Name] = GameModule
        end)
    
        coroutine.resume(loadModule)
    end

    for _, MinigameFolder in pairs(CollectionService:GetTagged(self.Settings.TagName)) do
        if not MinigameFolder:IsA("Folder") then
            continue
        end


        local Button = MinigameFolder:FindFirstChild("Button")
        local Zone = MinigameFolder:FindFirstChild("Zone")

        if Zone and Button then
            warn("Minigame folder has both a zone and button!")
            return
        end

        if Button then
            local LastTouch = tick()
            local Interaction = Button:FindFirstChild("Interaction")
            if not Interaction then
                warn("Failed to find interacton part on minigame button!")
                continue
            end

            if self.Settings.CanClick then
                local ClickDetector = Instance.new("ClickDetector")
                ClickDetector.Parent = Interaction
                Interaction.ClickDetector.MouseClick:Connect(function(Player)
                    if tick() - LastTouch < self.Settings.ButtonDelay then
                        return
                    end
                
                    Activate(Player, Button)
                    LastTouch = tick()
                end)
            end

            if self.Settings.CanTouch then
                Interaction.Touched:Connect(function(Object)
                    if tick() - LastTouch < 3 then
                        return
                    end
                
                    local Humanoid = Object.Parent:FindFirstChild("Humanoid")
                    if not Humanoid then
                        return
                    end

                    local Player = Players:GetPlayerFromCharacter(Object.Parent)
                    if not Player then
                        return
                    end

                    Activate(Player, Button)
                    LastTouch = tick()
                end)
            end
        elseif Zone then
            local GameModule = self.LoadedModules[MinigameFolder.Name]
            local GameData = GameModule.GameData

            local PanelPosition = Zone.Start.CFrame + (Zone.Start.CFrame.RightVector * Zone.Start.Size.X) + Vector3.new(0,-4,0)
            --GamePanelModule:MakePanelInfo(PanelPosition, Zone.Start, Zone.Parent.Name, GameData.playerNeeded .. " player(s) needed")
            
            GameData["Model"] = Zone

            -- Setup behavior of button mini game (active/disable game field launcher)
            StartingZoneModule.SetupButtonBehavior(GameData, self.LaunchGameForPlayers)

            -- Remote event listen when player enter in mini game zone, we check if mini game are the good and setup start for this player
            PlayerEnterMiniGameEvent.OnServerEvent:Connect(function(player, minigame)
                if minigame == GameData.GameName then
                    StartingZoneModule.SetDataAccordingToConditionsAndLaunchGame(player.Character.PrimaryPart, GameData, GameData.GameName, self.LaunchGameForPlayers)
                end
            end)
        
            -- Remote event listen when player leave mini game zone, we check if mini game are the good and remove player
            PlayerExitMiniGameEvent.OnServerEvent:Connect(function(player, minigame)
                if minigame == GameData.GameName then
                    StartingZoneModule:ActiveGameStartPartToPlayer(player, GameData, false)
                    StartingZoneModule.PlayerExitZone(player.Character.PrimaryPart, GameData, GameData.GameName)
                end
            end)
        end
    end

end

function MinigameModule.LaunchGameForPlayers(GameData, players)
    local GameModule = MinigameModule.LoadedModules[GameData.GameName]
    GameModule.GameData.Ongoing = true
    for _, PlayerInstance in pairs(players) do
        GameModule:Init(PlayerInstance)
        RE_ActivateGame:FireClient(PlayerInstance.player, GameData, false)
        RE_MiniGameUiState:FireClient(PlayerInstance.player ,GameModule.GameData, "Start")
    end
end

-- Function Launching game if conditions are good
function MinigameModule:LaunchGame(GameData)
    local players = ToolsModule.deepCopy(GameData.Players)
    GameData.Players = {}
    MinigameModule.LaunchGameForPlayers(GameData, players)
end

local function playerLeaveGame(Player)
    local currentGame = StartingZoneModule:GetPlayerCurrentGame(Player)
    local GameModule = MinigameModule.LoadedModules[currentGame.gameName]
    GameModule:PlayerLeave(Player)
end

function MinigameModule:GetMinigamesData()
    local minigamesData = {}
    for _, minigameModule in pairs(MinigameModule.LoadedModules) do
        if not minigameModule.GameData then
            continue
        end
        minigamesData[minigameModule.GameData.GameName] = minigameModule.GameData
    end
    return minigamesData
end

RE_MiniGameGiveUp.OnServerEvent:Connect(playerLeaveGame)

-- Event Server for know when mini game is finish and change status of player waiting in mini game for next party
RestartMiniGameEvent.Event:Connect(function(GameData)
    for _, playerValue in pairs(GameData.Model.waiting:GetChildren()) do
        local player = playerValue.Value
        StartingZoneModule.SetDataAccordingToConditionsAndLaunchGame(player.Character.PrimaryPart, GameData, GameData.GameName, MinigameModule.LaunchGameForPlayers)
    end
end)

MinigameModule:Init()
return MinigameModule