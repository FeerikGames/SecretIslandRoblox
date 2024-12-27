local TalentsType = {
    Speed = "Speed",
    Duration = "Duration",
    Gains = "Gains"
}

local CreaturesTalentsModule = {
    TalentsTable = {
        FireWalker = {
            Name = "Fire Walker",
            Desc = "Creature have the power ability to walk %s%s more time on fire ground",
            TalentType = TalentsType.Duration,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.5,
            UpgradeCost = {
                Feez = 3000
            }
        },
        WaterWalker = {
            Name = "Water Walker",
            Desc = "Creature have the power ability to swim %s%s more time on water",
            TalentType = TalentsType.Duration,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.5,
            UpgradeCost = {
                Feez = 3000
            }
        },
        FireSpeed = {
            Name = "Fire Speed",
            Desc = "Creature have the power ability to walk %s%s more quickly on fire ground",
            TalentType = TalentsType.Speed,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.25,
            UpgradeCost = {
                Feez = 3000
            }
        },
        WaterSpeed = {
            Name = "Water Speed",
            Desc = "Creature have the power ability to swim %s%s more quickly on water",
            TalentType = TalentsType.Speed,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.25,
            UpgradeCost = {
                Feez = 3000
            }
        },
        ExpSpeed = {
            Name = "Wise",
            Desc = "Creature have the power ability to learn %s%s quickly other",
            TalentType = TalentsType.Gains,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.025,
            UpgradeCost = {
                Feez = 3000
            }
        },
        Speedy = {
            Name = "Speedy",
            Desc = "Creature have the power ability to move %s%s quickly other",
            TalentType = TalentsType.Gains,
            Value = {
                Min = 5,
                Max = 30
            },
            RarityWeight = 0.025,
            UpgradeCost = {
                Feez = 3000
            }
        }
    }
}

function CreaturesTalentsModule.GetTalentsType()
    return TalentsType
end

return CreaturesTalentsModule