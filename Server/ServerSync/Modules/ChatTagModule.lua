local ChatTagModule = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ChatService = require(ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local GameDataModule = require("GameDataModule")

local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

ChatService.SpeakerAdded:Connect(function(playerName)
    local player = game.Players[playerName]

    ChatTagModule.SetClassicNameTagColor(player)
    ChatTagModule.AddingTagVIP(player)
    ChatTagModule.AddingTagDEVELOPER(player)
end)

function ChatTagModule.AddingTagVIP(player)
    local speaker = ChatService:GetSpeaker(player.Name)
    if speaker then
        if BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.VIP.ProductID) then
            speaker:SetExtraData("Tags", GameDataModule.TagsData.VIP)
            speaker:SetExtraData("NameTag", Color3.fromRGB(255, 208, 0))
        end
    end
end

function ChatTagModule.AddingTagDEVELOPER(player)
    local speaker = ChatService:GetSpeaker(player.Name)
    if speaker then
        if player:GetRankInGroup(12349377) >= 128 then
            speaker:SetExtraData("Tags", GameDataModule.TagsData.ADMIN)
            speaker:SetExtraData("NameTag", Color3.fromRGB(255, 0, 0))
        end
    end
end

function ChatTagModule.SetClassicNameTagColor(player)
    local speaker = ChatService:GetSpeaker(player.Name)
    if speaker then
        speaker:SetExtraData("NameTag", Color3.fromRGB(255, 255, 255))
    end
end

return ChatTagModule