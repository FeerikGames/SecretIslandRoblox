local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedSync = ReplicatedStorage.SharedSync
local RemoteFunction = SharedSync.RemoteFunction
local RF_Settings = RemoteFunction.Settings

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local ReplicatedPlayerData = require("ReplicatedPlayerData")
local UIProviderModule = require("UIProviderModule")

local Topbar = UIProviderModule:GetUI("TopBar")
local Container = Topbar.TopbarContainer

local PlayerSettings = ReplicatedPlayerData.LocalData["PlayerSettings"]

repeat
    PlayerSettings = ReplicatedPlayerData.LocalData["PlayerSettings"]
    task.wait(1)
until PlayerSettings ~= nil

local ButtonControls = {
    isSoundActivated = function(Status)
        Workspace["Soundtrack Theme"].Volume = Status and 0.13 or 0
        Container.isSoundActivated.Icon.Image = Status and "rbxassetid://6296233560" or "rbxassetid://6678521081"
    end,
}

for _, Button in pairs(Container:GetChildren()) do
    if not Button:IsA("TextButton") then
        continue
    end

    local Status = true
    if PlayerSettings then
        Status = PlayerSettings[Button.Name]
    end

    ButtonControls[Button.Name](Status)

    Button.MouseButton1Click:Connect(function()
        Status = not Status
        RF_Settings:InvokeServer(Button.Name, Status)
        local Function = ButtonControls[Button.Name]
        if Function then
            Function(Status)
        end
    end)
end

