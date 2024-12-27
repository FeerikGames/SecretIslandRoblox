local EventHandler = {}

local EventModules = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

function EventHandler:Init()
    for _, Module in ipairs(script:WaitForChild("Events"):GetChildren()) do
        EventModules[Module.Name] = require(Module)
        task.spawn(function()
            if EventHandler[Module.Name .. "StartCycle"] then
                EventHandler[Module.Name .. "StartCycle"](nil, Module.Name)
            end
        end)
    end
end

EventHandler.ActiveEvents = {}

function EventHandler:MinigamesEventLauncherStartCycle(ModuleName)
    -- Don't active mini game event or race event in MyFarm place
    if game.PlaceId ~= EnvironmentModule.GetPlaceId("MyFarm") then
        while true do
            task.wait(60)
            EventModules[ModuleName]:LaunchRandomMiniGame()
        end
    end
end

-- Rainbow race cycle :
function EventHandler:RainbowRaceStartCycle(ModuleName)
    while true do
        EventModules[ModuleName]:Start()
        task.wait(15)
        task.spawn(function()
            EventModules[ModuleName]:Blink()
        end)
        task.wait(5)
    end
end

return EventHandler