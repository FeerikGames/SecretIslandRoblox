local ReplicatedStorage = game:GetService("ReplicatedStorage")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
--local UIProviderModule = require("UIProviderModule")

local CreatureTips = {}

CreatureTips.TextParams = {
    TitleColor = Color3.fromRGB(70, 123, 202),
    MessageColor = Color3.fromRGB(77, 77, 77)
}

CreatureTips.Messages = {
    FirstCrystal = {
        Title = "Experience Crystal",
        Message = "You found a crystal! Collect these to level up your animal and unlock new features.",
        Image = "", -- TODO: Have PopUpAlertModule updated to allow images
        Function = function(...)
            local Args = {...}
            print(Args)
        end
    },
}

return CreatureTips