local GameDataModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

--check if attribute script for time multiplicatior exist and set if not
local TIME_MULTIPLICATOR = script:GetAttribute("TIME_MULTIPLICATOR")
if not TIME_MULTIPLICATOR then
	TIME_MULTIPLICATOR = 2
end

-- Setup Variables for some important Datastore of game
EnvironmentModule.RegisterVariable("dev", "GameDataModule.DatastoreVariables", {
    Player = {
        PlayerData = {Name = "PlayerData", Version = 1},
        MapsData = {Name = "MapsData", Version = 1},
        DailyRewardTime = {Name = "DailyRewardTime", Version = 1},
        Days = {Name = "Days", Version = 1},
    },
    GameSystem = {
        AdvertisingSystem = {Name = "AdvertisingSystem", Version = "Test1"},
        AuctionHouse = {Name = "AuctionHouse", Version = 1},
        RaceData = {Name = "RaceData", Version = 1},
    }
})
EnvironmentModule.RegisterVariable("production", "GameDataModule.DatastoreVariables", {
    Player = {
        PlayerData = {Name = "PlayerData", Version = 1},
        MapsData = {Name = "MapsData", Version = 1},
        DailyRewardTime = {Name = "DailyRewardTime", Version = 1},
        Days = {Name = "Days", Version = 1},
    },
    GameSystem = {
        AdvertisingSystem = {Name = "AdvertisingSystem", Version = 1},
        AuctionHouse = {Name = "AuctionHouse", Version = 1},
        RaceData = {Name = "RaceData", Version = 1},
    }
})
GameDataModule.DatastoreVariables = EnvironmentModule.GetVariable("GameDataModule.DatastoreVariables")
--#############################################

GameDataModule.GenesIcons = {
    Marking = "rbxassetid://13899925060",
    Mane = "rbxassetid://13899924669",
    Tail = "rbxassetid://13899923924",
    Socks = "rbxassetid://13899924217",
    Eye = "rbxassetid://13899924833",
    Effect = "rbxassetid://13899924061",
    Job = "rbxassetid://13899924419",
    Tattoo = "rbxassetid://13899923668",
}

GameDataModule.AnimalsRacesList = {
    "Normal",
    "Ground",
    "Fire",
    "Ice",
    "Light",
    "Water",
    "Celestial"
}

GameDataModule.RarityList = {
    "Common",
    "Uncommon",
    "Rare",
    "UltraRare",
    "Legendary"
}

GameDataModule.DropCollectables = {
    NormalCrystal = "rbxassetid://13083135499",
    GroundCrystal = "rbxassetid://13083215115",
    FireCrystal = "rbxassetid://13083004413",
    IceCrystal = "rbxassetid://13083664179",
    WaterCrystal = "rbxassetid://13083088074",
    LightCrystal = "rbxassetid://13082902208",
    CelestialCrystal = "rbxassetid://13082778611",
    Ecus = "rbxassetid://13460462375",
    Feez = "rbxassetid://12991038150",
    Sparks = "rbxassetid://12991037754",
    TotalHarvests = "rbxassetid://12991037541"
}

GameDataModule.DropCollectablesWithBorders = {
    NormalCrystal = "rbxassetid://12988817950",
    GroundCrystal = "rbxassetid://12988439318",
    FireCrystal = "rbxassetid://12988439577",
    IceCrystal = "rbxassetid://12988439160",
    WaterCrystal = "rbxassetid://12988438570",
    LightCrystal = "rbxassetid://12988438892",
    CelestialCrystal = "rbxassetid://12988577362",
    Ecus = "rbxassetid://13521439836",
    Feez = "rbxassetid://12991038150",
    Sparks = "rbxassetid://13699994693",
    TotalHarvests = "rbxassetid://12991037541"
}

GameDataModule.CoastFusion = {
    Rarity = {
        Normal = 1000;
        Ground = 1500;
        Fire = 2000;
        Ice = 2500;
        Light = 3000;
        Water = 3500;
        Celestial = 4000;
    },
    Crystals = {
        Normal = 20;
        Ground = 30;
        Fire = 40;
        Ice = 50;
        Light = 60;
        Water = 70;
        Celestial = 100;
    }
}

GameDataModule.TimeGrowthHorseGoal = 1200/TIME_MULTIPLICATOR
GameDataModule.TimeBreedingGoal = 3
GameDataModule.CreatureMaintenance_Interval = 120/TIME_MULTIPLICATOR
GameDataModule.RewardCareAnimal = 10 -- Value incremented when player take care of animal (brush, scrap, fed...)

--[[ GameDataModule.TalentsGeneratorCost = {
    [1] = {
        Ecus = 10
    },
    [2] = {
        Ecus = 10
    },
    [3] = {
        Ecus = 10
    },
    [4] = {
        Ecus = 10
    },
} ]]

GameDataModule.TalentsGeneratorCost = {
    [1] = {
        Ecus = 1000
    },
    [2] = {
        Ecus = 5000,
        Feez = 15000
    },
    [3] = {
        Feez = 10000,
        CelestialCrystal = 500
    },
    [4] = {
        LightCrystal = 250,
        WaterCrystal = 500,
        CelestialCrystal = 1000
    }
}

GameDataModule.TalentsGeneratorLuckSuccess = {
    [1] = 30,
    [2] = 15,
    [3] = 3,
    [4] = 1
}

GameDataModule.DailyRewardImage = {
    Ecus = {
        Simple = "rbxassetid://13587143951",
        LittleStack = "rbxassetid://13587142967",
        BasicStack = "rbxassetid://13587142168",
        LargeStack = "rbxassetid://13587141078",
        BigStack = "rbxassetid://13587140011",
        BigBagStack = "rbxassetid://13587138967",
        ChestStack = "rbxassetid://13587137823",
    },
    Feez = {
        Simple = "rbxassetid://13587143951",
        LittleStack = "rbxassetid://13587142967",
        BasicStack = "rbxassetid://13587142168",
        LargeStack = "rbxassetid://13587141078",
        BigStack = "rbxassetid://13587140011",
        BigBagStack = "rbxassetid://13587138967",
        ChestStack = "rbxassetid://13587137823",
    },
    Background = {
        BlueBackground = "rbxassetid://13587149105",
        PinkBackground = "rbxassetid://13587148210",
    },
}

GameDataModule.RaceIcons = {
    Normal = "rbxassetid://12573160398",
    Ground = "rbxassetid://12996627578",
    Fire = "rbxassetid://12996627750",
    Ice = "rbxassetid://12573160810",
    Light = "rbxassetid://12996627389",
    Water = "rbxassetid://12996627153",
    Celestial = "rbxassetid://12996627888"
}

GameDataModule.CreatureTypeIcons = {
    Horse = "rbxassetid://12989137031",
	Cat = "rbxassetid://12989137266"
}

GameDataModule.GenderIcons = {
    Male = "rbxassetid://12989146335",
    Female = "rbxassetid://12989146772"
}

GameDataModule.RatingIcons = {
    Common = "rbxassetid://12989277486",
    Uncommon = "rbxassetid://12989276959",
    Rare = "rbxassetid://13081664620",
    UltraRare = "rbxassetid://13081664949",
    Legendary = "rbxassetid://12989277092"
}

GameDataModule.RarityIconsBorderless = {
    Common = "rbxassetid://13526722929",
    Uncommon = "rbxassetid://13526771176",
    Rare = "rbxassetid://13526228842",
    UltraRare = "rbxassetid://13526965220",
    Legendary = "rbxassetid://13526967723"
}

GameDataModule.InNurseryIcons = {
    True = "rbxassetid://10691817599",
    False = "rbxassetid://10691817599"
}

GameDataModule.GrowthIcons = {
    Baby = "rbxassetid://13687248803",
    Adult = "rbxassetid://13699790410"
}

GameDataModule.StallionIcons = {
    True = "rbxassetid://10691817599",
    False = "rbxassetid://10691817599"
}

GameDataModule.FiltersCategorieIcons = {
    Race = {
        Icon = "rbxassetid://12996593214",
        Data = GameDataModule.RaceIcons,
    },
    CreatureType = {
        Icon = "rbxassetid://12989136773",
        Data = GameDataModule.CreatureTypeIcons,
    },
    Gender = {
        Icon = "rbxassetid://12989146564",
        Data = GameDataModule.GenderIcons,
    },
    Rating = {
        Icon = "rbxassetid://12996818145",
        Data = GameDataModule.RatingIcons,
    },
    InNursery = {
        Icon = "rbxassetid://10691817599",
        Data = GameDataModule.InNurseryIcons,
    },
    Growth = {
        Icon = "rbxassetid://13687248803",
        Data = GameDataModule.GrowthIcons,
    },
    Stallion = {
        Icon = "rbxassetid://10691817599",
        Data = GameDataModule.StallionIcons
    },
}

GameDataModule.Icons = {
    LockExp = "rbxassetid://13687248653",
    UnlockExp = "rbxassetid://13687248517"
}

GameDataModule.AnimalSounds = {
    Running = { -- Default running sounds when no material detected
        ["Cat"] = "277067660",
        ["Horse"] = "",
    },
    Materials = {
        ["Air"] = "687874741",
        ["Cobblestone"] = "177940988",
        ["Wood"] = "177940988",
        ["Grass"] = "4776173570",
    }
}


GameDataModule.AnimalsNameList = {
    "Roxi",
    "Boby",
    "Haggis",
    "Gordon",
    "Sydney",
    "Zena",
    "Kyra",
    "Zakky",
    "Yola",
    "Polly",
    "Usana",
    "Hanson",
    "Miley",
    "Tapas",
}

GameDataModule.RaceEvolutionTable = {
    {
        Race = "Normal",
        EXP = 0,
        ColorSequence = ColorSequence.new(Color3.new(175, 175, 175)),
        Color = Color3.fromRGB(175, 175, 175)
    },
    {
        Race = "Ground",
        EXP = 100,
        ColorSequence = ColorSequence.new(Color3.fromRGB(255, 141, 61)),
        Color = Color3.fromRGB(255, 141, 61)
    },
    {
        Race = "Fire",
        EXP = 200,
        ColorSequence = ColorSequence.new(Color3.fromRGB(246, 57, 71)),
        Color = Color3.fromRGB(246, 57, 71)
    },
    {
        Race = "Ice",
        EXP = 300,
        ColorSequence = ColorSequence.new(Color3.fromRGB(41, 230, 230)),
        Color = Color3.fromRGB(41, 230, 230)
    },
    {
        Race = "Light",
        EXP = 400,
        ColorSequence = ColorSequence.new(Color3.fromRGB(254, 183, 60)),
        Color = Color3.fromRGB(254, 183, 60)
    },
    {
        Race = "Water",
        EXP = 500,
        ColorSequence = ColorSequence.new(Color3.fromRGB(69, 174, 255)),
        Color = Color3.fromRGB(69, 174, 255)
    },
    {
        Race = "Celestial",
        EXP = 600,
        ColorSequence = ColorSequence.new(Color3.fromRGB(200, 60, 255)),
        Color = Color3.fromRGB(200, 60, 255)
    },
}

EnvironmentModule.RegisterVariable("production", "GameDataModule.DeveloperProducts", {
    ["+ 10 Animal slots"] = {
        ProductID = 1590530053,
        Price = 50
    },
    ["InstantGrowthTime"] = {
        ProductID = 1590530303,
        Price = 50
    }
})
EnvironmentModule.RegisterVariable("dev", "GameDataModule.DeveloperProducts", {
    ["+ 10 Animal slots"] = {
        ProductID = 1519228137,
        Price = 50
    },
    ["InstantGrowthTime"] = {
        ProductID = 1524909964,
        Price = 50
    }
})
GameDataModule.DeveloperProducts = EnvironmentModule.GetVariable("GameDataModule.DeveloperProducts")


EnvironmentModule.RegisterVariable("dev", "GameDataModule.Gamepasses", {
    Automatic_Care = {
        Name = "Automatic Care",
        Price = 1,
        ProductID = 167909786,
    },
    VIP = {
        Name = "VIP",
        Price = 1,
        ProductID = 168340041,
    },
    MagnetizeX2 = {
        Name = "x2 Magnetize Range",
        Price = 1,
        ProductID = 168854834,
    },
    GoldsX2 = {
        Name = "x2 Golds",
        Price = 1,
        ProductID = 169082095,
    },
    FeezX2 = {
        Name = "x2 Feez",
        Price = 1,
        ProductID = 169103269,
    },
    GiantsDurationX2 = {
        Name = "x2 Giant's Duration",
        Price = 1,
        ProductID = 169105414,
    },
    DailyLimitCollectablesX2 = {
        Name = "x2 Daily Limit Collectables",
        Price = 1,
        ProductID = 180984038,
    },
    AllTeleportation = {
        Name = "Teleportation!",
        Price = 400,
        ProductID = 192915463,
    },
})
EnvironmentModule.RegisterVariable("production", "GameDataModule.Gamepasses", {
    Automatic_Care = {
        Name = "Automatic Care",
        Price = 250,
        ProductID = 215375168,
    },
    VIP = {
        Name = "VIP",
        Price = 500,
        ProductID = 215375412,
    },
    MagnetizeX2 = {
        Name = "x2 Magnetize Range",
        Price = 250,
        ProductID = 215375526,
    },
    GoldsX2 = {
        Name = "x2 Golds",
        Price = 250,
        ProductID = 215375628,
    },
    FeezX2 = {
        Name = "x2 Feez",
        Price = 250,
        ProductID = 215375753,
    },
    GiantsDurationX2 = {
        Name = "x2 Giant's Duration",
        Price = 250,
        ProductID = 215375871,
    },
    DailyLimitCollectablesX2 = {
        Name = "x2 Daily Limit Collectables",
        Price = 250,
        ProductID = 215375990,
    },
    AllTeleportation = {
        Name = "Teleportation!",
        Price = 400,
        ProductID = 215376097,
    },
})
GameDataModule.Gamepasses = EnvironmentModule.GetVariable("GameDataModule.Gamepasses")

GameDataModule.TagsData = {
    VIP = {
        {TagText = "🌟 VIP", TagColor = Color3.fromRGB(255, 208, 0)},
    },
    ADMIN = {
        {TagText = "🖥️ DEVELOPER", TagColor = Color3.fromRGB(255, 0, 0)},
    }
}

return GameDataModule