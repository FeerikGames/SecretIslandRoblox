local PlayerSettings = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SharedSync = ReplicatedStorage.SharedSync
local RemoteFunction = SharedSync.RemoteFunction
local RF_Settings = RemoteFunction.Settings

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local PlayerDataModule = require("PlayerDataModule")

RF_Settings.OnServerInvoke = function(Player, Path, Value)
    local Settings = PlayerDataModule:Get(Player)["PlayerSettings"]
    Settings[Path] = Value
    PlayerDataModule:Set(Player, Settings, "PlayerSettings")
end

return PlayerSettings