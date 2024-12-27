local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

-- Require
local GameDataModule = require("GameDataModule")

local DataVersioning = {}

DataVersioning.Versions = {}

DataVersioning.Versions[1] = function(Data)
    Data = HttpService:JSONDecode(Data)
    Data._VERSION = 1
end

DataVersioning.Versions[2] = function(Data)
    --update data race Pegasus become Ice race animals
    for id, creature in pairs(Data.CreaturesCollection) do
        if creature.Race == "Pegasus" then
            Data.CreaturesCollection[id].Race = "Ice"
        end
    end
end

DataVersioning.Versions[3] = function(Data)
    -- Update data schema with adding new currency Crystals
    local Crystals = {
        NormalCrystal = 0;
        GroundCrystal = 0;
        FireCrystal = 0;
        IceCrystal = 0;
        LightCrystal = 0;
        WaterCrystal = 0;
        CelestialCrystal = 0;
    }

    Data["Crystals"] = Crystals
end

DataVersioning.Versions[4] = function(Data)
    -- Update data schema with adding new table
    Data["SystemUnlocked"] = {}
end

DataVersioning.Versions[5] = function(Data)
    -- Update data schema with adding new data of max number slots creature player can have same time in collection
    Data["NbMaxSlotsCreature"] = 20
end

DataVersioning.Versions[6] = function(Data)
    -- Update data schema with changement of Inventory behavior for Accessory items
    Data["Inventory"] = {}
end

DataVersioning.Versions[7] = function(Data)
    --update data animals adding new variable ReadyToEvolve to have new behavior xp with lock and ready evolve
    for id, creature in pairs(Data.CreaturesCollection) do
        if GameDataModule.RaceEvolutionTable[creature.Level + 1] then
            Data.CreaturesCollection[id]["ReadyToEvolve"] = creature.Exp >= GameDataModule.RaceEvolutionTable[creature.Level + 1].EXP and true or false
        else
            Data.CreaturesCollection[id]["ReadyToEvolve"] = false
        end
    end
end

DataVersioning.Versions[8] = function(Data)
    -- Update data schema with adding new table for world teleportation part unlocked
    Data["WorldTeleportUnlocked"] = {}
end

DataVersioning.Versions[9] = function(Data)
    -- Update data schema with adding new variable to register ID of last summoned Creature
    Data["LastCreatureSummoned"] = ""
end

function DataVersioning:UpdateVersion(Data)
    local CurrentVersion = Data._VERSION or 0
    for Index, VersionFunction in pairs(self.Versions) do
        if CurrentVersion < Index then
            VersionFunction(Data)
            Data._VERSION = Index
        end
    end
end

return DataVersioning