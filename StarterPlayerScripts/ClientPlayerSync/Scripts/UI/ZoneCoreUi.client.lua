local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local PlayerService = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game.Players.LocalPlayer

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local WalkSpeedModule = require("WalkSpeedModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
local GetValueOf = RemoteFuncFolder:WaitForChild("GetValueOf")
local GetDataOfPlayer = RemoteFuncFolder:WaitForChild("GetDataOfPlayer")
local RF_ZoneChoice = RemoteFuncFolder:WaitForChild("ZoneChoice")

-- Events
local RemoteEventFolder = ReplicatedStorage.RemoteEvent
local remoteFunction = ReplicatedStorage.RemoteFunction
local RE_ZoneUiState = RemoteEventFolder:WaitForChild("ZoneUiState")
local RE_ZoneUiWaiting = RemoteEventFolder:WaitForChild("ZoneUiWaiting")

--UI
local ZoneGui = UIProviderModule:GetUI("ZoneGui")
local startPlayerItem = ZoneGui.Template.startItem

--Properties

local fillStarterPlayerConnection = nil
local outFillStarterPlayerConnection = nil
local isChoiceAborted = false

function Round(Number: number, Precision: number?) : number
	local Places = (Precision) and (10^Precision) or 1
	return (((Number * Places) + 0.5 - ((Number * Places) + 0.5) % 1)/Places)
end

-- Clears the Zone Ui and reset connections
local function clearCloseUi()
    for _, playerItem in pairs(ZoneGui.Starting.Participants.List:GetChildren()) do
        if playerItem:IsA("Frame") then
            playerItem:Destroy()
        end
    end
    
    local starting = ZoneGui.Starting
    starting.Visible = false
    starting.raceName.Text = ""
    starting.message.Text = ""
    if fillStarterPlayerConnection then
        fillStarterPlayerConnection:Disconnect()
        fillStarterPlayerConnection = nil
    end
    if outFillStarterPlayerConnection then
        outFillStarterPlayerConnection:Disconnect()
        outFillStarterPlayerConnection = nil
    end
end

-- Fills the players list of the Starting screen with gameData
local function fillPlayersStarter(GameData)
    for _, playerItem in pairs(ZoneGui.Starting.Participants.List:GetChildren()) do
        if playerItem:IsA("Frame") then
            if not GameData.Model.participants:FindFirstChild(playerItem.Name) then
                playerItem:Destroy()
            end
        end
    end

    for _, playerValue in pairs(GameData.Model.participants:GetChildren()) do
        if ZoneGui.Starting.Participants.List:FindFirstChild(playerValue.Value.Name) then
            continue
        end

        local playerIcon, isReady = PlayerService:GetUserThumbnailAsync(playerValue.Value.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        local playerItem = startPlayerItem:Clone()
        playerItem.Parent = ZoneGui.Starting.Participants.List
        playerItem.Name = playerValue.Value.Name
        playerItem.playerName.Text = playerValue.Value.Name
        playerItem.playerIcon.Image = playerIcon
        playerItem.Visible = true
    end
end

-- Displays and initiate the start ui (with childAdded Event to update on new player joining)
local function InitStartUi(GameData)
    local starting = ZoneGui.Starting
    starting.Visible = true
    starting.raceName.Text = GameData.GameName

    starting:SetAttribute("MiniGameType", GameData.GameName)
    starting.CloseBtn.Visible = GameData.GameName ~= "Race" and true or false

    if GameData.DisplayName then
        starting.raceName.Text = GameData.DisplayName
    end
    starting.message.Text = "Minimum "..GameData.playerNeeded.." players is required..."
    fillPlayersStarter(GameData)
    fillStarterPlayerConnection = GameData.Model.participants.ChildAdded:Connect(function()
        task.wait(0.3)
        fillPlayersStarter(GameData)
    end)
    outFillStarterPlayerConnection = GameData.Model.participants.ChildRemoved:Connect(function()
        task.wait(0.3)
        fillPlayersStarter(GameData)
    end)
end

-- Displays and initiate the event ui (with childAdded Event to update on new player joining)
local function InitEventUi(GameData, countdown)
    local starting = ZoneGui.Starting
    if not starting.Visible then
        fillPlayersStarter(GameData)
        fillStarterPlayerConnection = GameData.Model.participants.ChildAdded:Connect(function()
            task.wait(0.3)
            fillPlayersStarter(GameData)
        end)
        outFillStarterPlayerConnection = GameData.Model.participants.ChildRemoved:Connect(function()
            task.wait(0.3)
            fillPlayersStarter(GameData)
        end)
    end
    starting.Visible = true
    starting.raceName.Text = "Event : ".. GameData.GameName
    if GameData.DisplayName then
        starting.raceName.Text = "Event : ".. GameData.DisplayName
    end
    starting.message.Text = "Start in : " .. countdown
end

-- Displays and fill info of the CountDown and maybe the WaitingForMorePlayers screen
local function CountDown(countDown, isWaitingForMorePlayers, gameData)
    WalkSpeedModule.SetControlsPlayerAndCreature(false)
    local countdownFrame = ZoneGui.CountDown
    local WaitingForMorePlayersFrame = ZoneGui.CountDown.WaitingForPlayers
    -- if the screen was already visible change the info.
    if countdownFrame.Visible then
        WaitingForMorePlayersFrame.countDownText.Text = "Players: " .. ToolsModule.LengthOfDic(gameData.Players) .. "/" .. gameData.playerNeeded
    end
    countdownFrame.Visible = true
    countdownFrame.countDownText.Text = countDown
    if isWaitingForMorePlayers then
        WaitingForMorePlayersFrame.Visible = true
    end
end

-- Hides the CountDown and waitingForMorePlayers screens
local function HideCountDownUi()
    WalkSpeedModule.SetControlsPlayerAndCreature(true)
    local countdownFrame = ZoneGui.CountDown
    local WaitingForMorePlayersFrame = ZoneGui.CountDown.WaitingForPlayers
    countdownFrame.Visible = false
    WaitingForMorePlayersFrame.Visible = false
end

-- Displays the waiting screen
local function ShowPlayerWaitingScreen(GameName, isWaiting)
    local waitingFrame = ZoneGui.Waiting
    waitingFrame.Visible = isWaiting
    waitingFrame.message.Text = "Game in progress. Wait until the end of the game."
    waitingFrame.raceName.Text = GameName
    waitingFrame:SetAttribute("MiniGameType", GameName)
    waitingFrame.CloseBtn.Visible = GameName ~= "Race" and true or false
end

-- Displays the choice screen
local function ShowPlayerChoiceScreen(GameName, Visible)
    local ChoiceFrame = ZoneGui.Choice
    ChoiceFrame.Visible = Visible
    ChoiceFrame.raceName.Text = GameName
end

-- Called when player has to choose btwn solo and multiplayer for a game
-- Arguments : GameName to be displayed
RF_ZoneChoice.OnClientInvoke = function(GameName)
    isChoiceAborted = false
    -- variables to track player choice
    local choosed = false
    local isSolo = false
    ShowPlayerChoiceScreen(GameName, true)
    local ChoiceFrame = ZoneGui.Choice
    local connections = {}
    connections[1] = ChoiceFrame.Options.MultiButton.Activated:Connect(function()
        choosed = true
        isSolo = false
        ShowPlayerChoiceScreen(GameName, false)
    end)
    connections[2] = ChoiceFrame.Options.SoloButton.Activated:Connect(function()
        choosed = true
        isSolo = true
        ShowPlayerChoiceScreen(GameName, false)
    end)

    -- Waiting for the player to choose to return if he choosed solo. if the choice was aborted the return "abort" (when player leave start).
    while not choosed do
        if isChoiceAborted then
            connections[1]:Disconnect()
            connections[2]:Disconnect()
            isChoiceAborted = false
            return "abort"
        end
        task.wait(0.5)
    end
    connections[1]:Disconnect()
    connections[2]:Disconnect()
    return isSolo
end

RE_ZoneUiWaiting.OnClientEvent:Connect(function(GameName, isWaiting)
    clearCloseUi()
    ShowPlayerWaitingScreen(GameName, isWaiting)
end)

-- Functions called by zoneUi event
local RaceUiFunctions = {
    EventWaiting = function(GameData, data, currentTime)
        InitEventUi(GameData, currentTime)
    end,
    Waiting = function(GameData, data, currentTime)
        clearCloseUi()
        InitStartUi(GameData, data)
    end,
    WaitingForMorePlayers = function(GameData, data, currentTime)
        clearCloseUi()
        CountDown(data, true, GameData)
    end,
    Out = function()
        isChoiceAborted = true
        ShowPlayerChoiceScreen("", false)
        clearCloseUi()
    end,
    DoneCounting = function(GameData, data, currentTime)
        clearCloseUi()
        HideCountDownUi()
    end,
}


RE_ZoneUiState.OnClientEvent:Connect(function(GameData, raceState, data, currentTime)
    RaceUiFunctions[raceState](GameData, data, currentTime)
end)

ZoneGui.Starting.CloseBtn.Activated:Connect(function()
    if ZoneGui.Starting:GetAttribute("MiniGameType") ~= "Race" then
        ReplicatedStorage.RemoteEvent.MiniGames:WaitForChild("PlayerExitMiniGameEvent"):FireServer(ZoneGui.Starting:GetAttribute("MiniGameType"))
    end
end)

ZoneGui.Waiting.CloseBtn.Activated:Connect(function()
    if ZoneGui.Waiting:GetAttribute("MiniGameType") ~= "Race" then
        ReplicatedStorage.RemoteEvent.MiniGames:WaitForChild("PlayerExitMiniGameEvent"):FireServer(ZoneGui.Waiting:GetAttribute("MiniGameType"))
    end
end)