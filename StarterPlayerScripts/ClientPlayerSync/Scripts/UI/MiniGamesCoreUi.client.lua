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

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
local GetValueOf = RemoteFuncFolder:WaitForChild("GetValueOf")
local GetDataOfPlayer = RemoteFuncFolder:WaitForChild("GetDataOfPlayer")

-- Events
local RemoteEventFolder = ReplicatedStorage.RemoteEvent
local remoteFunction = ReplicatedStorage.RemoteFunction
local RE_MiniGameUiState = RemoteEventFolder:WaitForChild("MiniGameUiState")
local RE_MiniGameGiveUp = RemoteEventFolder:WaitForChild("MiniGameGiveUp")

--UI
local MiniGamesGui = UIProviderModule:GetUI("MiniGamesGui")



local function ShowHidePlayerGiveUpButton(DisplayName, Visible)
    local GiveUpFrame = MiniGamesGui.GiveUp
    GiveUpFrame.Visible = Visible
    GiveUpFrame.gameName.Text = DisplayName
end

MiniGamesGui.GiveUp.Options.GiveUpButton.Activated:Connect(function()
    RE_MiniGameGiveUp:FireServer()
    MiniGamesGui.GiveUp.Visible = false
end)

local MiniGamesUiFunctions = {
    Start = function(GameInfo)
        local displayName = GameInfo.GameName
        if GameInfo.DisplayName then
            displayName = GameInfo.DisplayName
        end
        ShowHidePlayerGiveUpButton(displayName, true)
    end,
    Finish = function(GameInfo)
        ShowHidePlayerGiveUpButton("", false)
    end,
}


RE_MiniGameUiState.OnClientEvent:Connect(function(GameInfo, GameState)
    MiniGamesUiFunctions[GameState](GameInfo)
end)