local ServerStorage = game:GetService("ServerStorage")

local ServerStorageSync = ServerStorage.ServerStorageSync
local Assets = ServerStorageSync.AssetsRessources

local GameFunctions = require(script.Parent.GameFunctions)

local Balloons = {}

function Balloons:Init(Player: Player, Button: Instance)
    local SpawnAmount = Button:GetAttribute("SpawnAmount")
    local CurrentAmount = GameFunctions:GetObjectCount(Button.Parent:GetChildren(), Button)
    if CurrentAmount >= SpawnAmount then
        --break
        return
    end

    local Balloon = Assets.Balloon:Clone()
    Balloon.Transparency = 0
    Balloon.BrickColor = BrickColor.random()
    Balloon.Material = Enum.Material.SmoothPlastic
    Balloon.CFrame = Button.Interaction.CFrame + GameFunctions:GetRandomPosition(70)
    Balloon.Parent = Button.Parent
    Balloon:SetNetworkOwnershipAuto()
end

return Balloons