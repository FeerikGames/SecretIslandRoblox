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
local UIAnimationModule = require("UIAnimationModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
local GetValueOf = RemoteFuncFolder:WaitForChild("GetValueOf")
local GetDataOfPlayer = RemoteFuncFolder:WaitForChild("GetDataOfPlayer")

-- Events
local RemoteEventFolder = ReplicatedStorage.RemoteEvent
local RE_RaceUiState = RemoteEventFolder:WaitForChild("RaceUiState")
local RE_RaceGiveUp = RemoteEventFolder:WaitForChild("RaceGiveUp")

--UI
local RaceGui = UIProviderModule:GetUI("RaceGui")
local resultPlayerItem = RaceGui.Template.resultsItem
local closeResultsButton = RaceGui.Results.CloseUI
local RainbowRaceGui = UIProviderModule:GetUI("RainbowRaceGui")

-- parameters
local fillStarterPlayerConnection
local outFillStarterPlayerConnection

--Properties


function Round(Number: number, Precision: number?) : number
	local Places = (Precision) and (10^Precision) or 1
	return (((Number * Places) + 0.5 - ((Number * Places) + 0.5) % 1)/Places)
end

-- Closes ui and resets connections and texts
local function clearCloseUi()
    for _, playerItem in pairs(RaceGui.Starting.Participants:GetChildren()) do
        if playerItem:IsA("Frame") then
            playerItem:Destroy()
        end
    end
    
    local starting = RaceGui.Starting
    starting.Visible = false
    starting.raceName.Text = ""
    starting.message.Text = ""
    
    RaceGui.CheckPoint.Visible = false
    RaceGui.CheckPoint.Text = ""

    if fillStarterPlayerConnection then
        fillStarterPlayerConnection:Disconnect()
        fillStarterPlayerConnection = nil
    end
    if outFillStarterPlayerConnection then
        outFillStarterPlayerConnection:disconnect()
        outFillStarterPlayerConnection = nil
    end
end


-- closes the result ui and delete its list
closeResultsButton.Activated:Connect(function()
    for _, playerItem in pairs(RaceGui.Results.Classement:GetChildren()) do
        if playerItem:IsA("Frame") then
            playerItem:Destroy()
        end
    end
    local Results = RaceGui.Results
    Results.Visible = false
    Results.raceName.Text = ""
    Results.result.Text = ""
end)

-- Fills the race result player list ui with the result of the race
-- Arguments : the race's data with race model
local function fillPlayersResults(RaceInfo)
    for _, playerItem in pairs(RaceGui.Results.Classement:GetChildren()) do
        if playerItem:IsA("Frame") then
            if not RaceInfo.Model.classement:FindFirstChild(playerItem.Name) then
                playerItem:Destroy()
            end
        end
    end

    for _, playerValue in pairs(RaceInfo.Model.classement:GetChildren()) do
        if playerValue.Value.Name then
            if RaceGui.Results.Classement:FindFirstChild(playerValue.Value.Name) then
                continue
            end
        else
            if RaceGui.Results.Classement:FindFirstChild(playerValue.Value) then
                continue
            end
        end
        local CreatureRace
        local playerName
        local playerIcon, isReady
        if playerValue.Value.Name then
            local CreatureId = playerValue.Creature.Value.CreatureID.Value
            local creaturesCollection = GetDataOfPlayer:InvokeServer(playerValue.Value, "CreaturesCollection")
            CreatureRace = creaturesCollection[CreatureId].Race
            playerName = playerValue.Value.Name
            playerIcon, isReady = PlayerService:GetUserThumbnailAsync(playerValue.Value.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        else
            playerName = playerValue.Value
            CreatureRace = "Bot"
        end

        local playerItem = resultPlayerItem:Clone()
        playerItem.Parent = RaceGui.Results.Classement
        playerItem.Name = playerName
        playerItem.LayoutOrder = playerValue.CurrentPlacement.Value

        playerItem.playerName.Text = playerName
        if playerIcon then
            playerItem.playerIcon.Image = playerIcon
        end
        local hour,min,sec = ToolsModule.ConvertSecToHour(Round(playerValue.CurrentTime.Value, 3))
        playerItem.timing.Text = hour .. ":" ..min .. ":" .. sec
        playerItem.creatureType.Text = CreatureRace
        playerItem.place.Text = playerValue.CurrentPlacement.Value
        playerItem.Visible = true
    end
end

-- Fills the race result player list ui with the result of the race
-- Arguments : the race's data (classement)
local function fillPlayersResultsFromData(data)
    for _, playerItem in pairs(RaceGui.Results.Classement:GetChildren()) do
        if playerItem:IsA("Frame") then
            if not data[playerItem.Name] then
                playerItem:Destroy()
            end
        end
    end
    for UserId, playerValue in pairs(data) do
        UserId = tonumber(UserId)
        local PlayerName = PlayerService:GetPlayerByUserId(UserId).Name
        if RaceGui.Results.Classement:FindFirstChild(UserId) then
            continue
        end
        local CreatureRace
        local playerName
        local playerIcon, isReady
        if PlayerName then
            local CreatureId = playerValue.Creature.CreatureID.Value
            local creaturesCollection = GetDataOfPlayer:InvokeServer(PlayerService:GetPlayerByUserId(UserId), "CreaturesCollection")
            CreatureRace = creaturesCollection[CreatureId].Race
            playerName = PlayerName
            playerIcon, isReady = PlayerService:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        end

        local playerItem = resultPlayerItem:Clone()
        playerItem.Parent = RaceGui.Results.Classement
        playerItem.Name = UserId
        playerItem.LayoutOrder = playerValue.CurrentPlacement

        playerItem.playerName.Text = playerName
        if playerIcon then
            playerItem.playerIcon.Image = playerIcon
        end
        local hour,min,sec = ToolsModule.ConvertSecToHour(Round(playerValue.CurrentTime, 3))
        playerItem.timing.Text = hour .. ":" ..min .. ":" .. sec
        playerItem.creatureType.Text = CreatureRace
        playerItem.place.Text = playerValue.CurrentPlacement
        playerItem.Visible = true
    end
end

-- Fills the rainbow player list ui with the result of the race
-- Arguments : the rainbow race's data
local function fillRainbowPlayersResults(RaceInfo)
    for _, playerItem in pairs(RainbowRaceGui.Results.Classement:GetChildren()) do
        if not playerItem:IsA("Frame") or RaceInfo.classement:FindFirstChild(playerItem.Name) then
            continue
        end
        playerItem:Destroy()
    end

    for _, playerValue in pairs(RaceInfo.classement:GetChildren()) do
        if playerValue.Value.Name then
            if RainbowRaceGui.Results.Classement:FindFirstChild(playerValue.Value.Name) then
                continue
            end
        else
            if RainbowRaceGui.Results.Classement:FindFirstChild(playerValue.Value) then
                continue
            end
        end
        local HorseType = "Player"
        local playerName
        local playerIcon, isReady
        if playerValue.Value.Name then
            HorseType = playerValue.HorseType.Value
            playerName = playerValue.Value.Name
            playerIcon, isReady = PlayerService:GetUserThumbnailAsync(playerValue.Value.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size352x352)
        else
            playerName = playerValue.Value
            HorseType = "Bot"
        end
        local playerItem = RainbowRaceGui.Template.resultsItem:Clone()
        playerItem.Parent = RainbowRaceGui.Results.Classement
        playerItem.Name = playerName
        playerItem.LayoutOrder = playerValue.CurrentPlacement.Value

        playerItem.playerName.Text = playerName
        if playerIcon then
            playerItem.playerIcon.Image = playerIcon
        end
        playerItem.horseType.Text = HorseType
        playerItem.place.Text = playerValue.CurrentPlacement.Value
        playerItem.Visible = true
    end
end

-- displays the result ui of the rainbow race with the results
local function InitRainbowResultUi(RaceInfo)
    RainbowRaceGui.Results.Visible = true
    RainbowRaceGui.Results.raceName.Text = "Rainbow race !"
    RainbowRaceGui.Results.result.Text = "You finished ".. RaceInfo.classement:FindFirstChild(Player.Name).CurrentPlacement.Value .. " !"
    
    fillRainbowPlayersResults(RaceInfo)
    fillStarterPlayerConnection = RaceInfo.classement.ChildAdded:Connect(function()
        task.wait(0.3)
        fillRainbowPlayersResults(RaceInfo)
    end)
    outFillStarterPlayerConnection = RaceInfo.classement.ChildRemoved:Connect(function()
        task.wait(0.3)
        fillRainbowPlayersResults(RaceInfo)
    end)
    
    while RainbowRaceGui.Results.Visible == true do
        if RaceInfo:FindFirstChild("classement") then
            fillRainbowPlayersResults(RaceInfo)
        end
        task.wait(0.3)
    end
    RE_RaceUiState:FireServer("Rainbow")
    clearCloseUi()
end


-- resets the checkpointUi's tween, set the texts and relaunch the tween
-- Arguments : Time to be displayed on screen (In seconds then womm be displayed - hour:min:sec)
local tweenInfo = TweenInfo.new(3,Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 0)
local CheckpointTween = TweenService:Create(RaceGui.CheckPoint, tweenInfo, {BackgroundTransparency = 1})
local function showCheckPoint(currentTimeInSec)
    --checkpoint fade
    CheckpointTween:Cancel()

    local hour,min,sec = ToolsModule.ConvertSecToHour(Round(currentTimeInSec, 2))
    RaceGui.CheckPoint.Text = hour .. ":" ..min .. ":" .. sec
    RaceGui.CheckPoint.UIStroke.Transparency = 0
    RaceGui.CheckPoint.TextTransparency = 0
    RaceGui.CheckPoint.BackgroundTransparency = 0
    RaceGui.CheckPoint.Visible = true

    TweenService:Create(RaceGui.CheckPoint.UIStroke, tweenInfo, {Transparency = 1}):Play()
    TweenService:Create(RaceGui.CheckPoint, tweenInfo, {TextTransparency = 1}):Play()
    CheckpointTween:Play()
end

-- Displays the Result ui of the race with placement or the timing depending on solo/multi.
-- Arguments : race's data used to get race's name and placement, dictionnary with players result data (only passed when in solo)
local function InitResultUi(RaceInfo, data)
    local Results = RaceGui.Results
    Results.Visible = true
    Results.raceName.Text = RaceInfo.DisplayName

    UIAnimationModule.ParticleExplosionUI(RaceGui.Template.StarsParticle, Results)

    if data then
        -- solo
        local hour,min,sec = ToolsModule.ConvertSecToHour(data[tostring(Player.UserId)].CurrentTime)
        Results.result.Text = "You finished in : " .. hour .. ":" ..min .. ":" .. sec
        fillPlayersResultsFromData(data)
    else
        -- multi
        local placement = RaceInfo.Model.classement[Player.Name].CurrentPlacement.Value
        Results.result.Text = "You finished : " ..  placement .. " !"
        fillPlayersResults(RaceInfo)
        fillStarterPlayerConnection = RaceInfo.Model.classement.ChildAdded:Connect(function()
            task.wait(0.3)
            fillPlayersResults(RaceInfo)
        end)
        outFillStarterPlayerConnection = RaceInfo.Model.classement.ChildRemoved:Connect(function()
            task.wait(0.3)
            fillPlayersResults(RaceInfo)
        end)
    end
end

-- Displays and change countdown info
local function CountDown(raceCountDown)
    local countdownFrame = RaceGui.CountDown
    countdownFrame.countDownText.Text = raceCountDown
    countdownFrame.Visible = true
end

-- Hides the countdown Ui
local function HideCountDownUi()
    local countdownFrame = RaceGui.CountDown
    countdownFrame.Visible = false
end

-- Displays the give up button for the race.
local function ShowPlayerGiveUpButton(RaceName, Visible)
    local GiveUpFrame = RaceGui.GiveUp
    GiveUpFrame.Visible = Visible
    GiveUpFrame.raceName.Text = RaceName
end

RaceGui.GiveUp.Options.GiveUpButton.Activated:Connect(function()
    RE_RaceGiveUp:FireServer()
    RaceGui.GiveUp.Visible = false
end)

-- Dictionnary of functions called by events
local RaceUiFunctions = {
    CountDown = function(RaceInfo, data, currentTime)
        clearCloseUi()
        CountDown(data)
    end,
    DoneCounting = function(RaceInfo, data, currentTime)
        clearCloseUi()
        HideCountDownUi()
    end,
    Start = function(RaceInfo, data, currentTime)
        clearCloseUi()
        ShowPlayerGiveUpButton(RaceInfo.DisplayName, true)
    end,
    CheckPoint = function(RaceInfo, data, currentTime)
        showCheckPoint(currentTime)
    end,
    Finish = function(RaceInfo, data, currentTime)
        clearCloseUi()
        ShowPlayerGiveUpButton(RaceInfo.DisplayName, false)
        InitResultUi(RaceInfo, data)
    end,
    RaceRainbowFinish = function(RaceInfo, data, currentTime)
        InitRainbowResultUi(RaceInfo)
    end,
}


RE_RaceUiState.OnClientEvent:Connect(function(RaceInfo, raceState, data, currentTime)
    RaceUiFunctions[raceState](RaceInfo, data, currentTime)
end)