local GameBonusModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local CreatureSizeModule = require("CreatureSizeModule")
local ServerDropsHandler = require("ServerDropsHandler")
local ToolsModule = require("ToolsModule")
local PlayerDataModule = require("PlayerDataModule")

-- Parameters

local LoserRatio = 0.5
local NumberRatio = 0.5

-- All the bonuses : with a "BonusType" var to set how it will be executed. parameters and an "EffectFunction" to be called.
local Bonuses = {
    Piece = {
        BonusScale = 1,
        BonusType = "Ressource",
        ressource = "Sparks",
        number = 15,
        EffectFunction = ServerDropsHandler.SpawnDrop,
    },
    Giant = {
        BonusScale = 10,
        BonusType = "Boost",
        Duration = 6,
        Ratio = 4,
        EffectFunction = CreatureSizeModule.ResizeCreature,
    }
}

-- The functions that will get a random bonus bassed on a calculation process
local GetBonusFunction = {
    -- Simple random with equal chances
    Random = function()
        local randomBonusNum = math.random(ToolsModule.LengthOfDic(Bonuses))
        local randomBonus = nil
        local count = 1
        for index, Bonus in pairs(Bonuses) do
            if count == randomBonusNum then
                randomBonus = Bonus
                break
            end
            count += 1
        end
        return randomBonus
    end,
    -- A roll dice that is influenced by the ratio passed, it will roll a dice for each bonuses (have to get 1 btwn 1 and "BonusScale")
    -- it will take the bonus successful with the highest "BonusScale"
    Ratio = function(ratio)
        local BonusChosed = Bonuses.Piece
        for index, Bonus in pairs(Bonuses) do
            local LoserBonus = math.round(ratio * LoserRatio * Bonus.BonusScale)
            local roll = math.random(1, math.clamp(Bonus.BonusScale, 1 , 10000))
            if roll <= 1 + LoserBonus and Bonus.BonusScale > BonusChosed.BonusScale and LoserBonus ~= 0 then
                BonusChosed = Bonus
            end
        end
        return BonusChosed
    end,
    -- same process as the ratio with a positif number modificator multiplied by the "NumberRatio"
    -- Exemple in race : ratio = placement of player, number = numb of checkpoints late
    RatioAndNumber = function(ratio, number)
        local BonusChosed = Bonuses.Piece
        local NumberBonus = number * NumberRatio
        for index, Bonus in pairs(Bonuses) do
            local LoserBonus = math.round(ratio * LoserRatio * Bonus.BonusScale)
            local roll = math.random(1, math.clamp(Bonus.BonusScale, 1 , 10000))
            if roll <= 1 + LoserBonus + NumberBonus and Bonus.BonusScale > BonusChosed.BonusScale and LoserBonus ~= 0 then
                BonusChosed = Bonus
            end
        end
        return BonusChosed
    end
}


-- Will apply a Bonus to player according to the calculation Method given (a string matching the above function's names) for exemple "Ratio"
-- and the according arguments
function GameBonusModule:ApplyBonusToPlayer(player, CalculationType, ...)
    -- get the bonus from the function according to the calculation type.
    local randomBonus = GetBonusFunction[CalculationType](...)
    local Character = player.Character
    -- Fire bonus Function with its arguments.
    if randomBonus.BonusType == "Boost" then
        randomBonus.EffectFunction(Character, randomBonus.Ratio, randomBonus.Duration)
    elseif randomBonus.BonusType == "Ressource" then
        local dropPosition = Character.PrimaryPart.position + Character.PrimaryPart.AssemblyLinearVelocity
        for i = 1, randomBonus.number, 1 do
            randomBonus.EffectFunction(nil, randomBonus.ressource, randomBonus.number, dropPosition, "Ground", player, true)
            task.wait(0.01)
        end
    end
end

return GameBonusModule