local RarityDataModule = {
    PrctWeight = {
		Parent = 90,
		Other = 10
	}
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local ToolsModule = require("ToolsModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")

--Bindable function
local GetStockItemsServer = BindableFunction.GetStockItemsServer
local GetStockItemDataServer = BindableFunction.GetStockItemDataServer

local MaterialRarityWeights = {
    Common = 100,
    Uncommon = 75,
    Rare = 40,
    UltraRare = 20,
    Legendary = 5
}

local ColorRarityWeight = {
    OtherColor = 100,
    PureColors = 30
}

local GenesRarityWeights = {
    Nothing = 100,
    Common = 20,
    Uncommon = 10,
    Rare = 5,
    UltraRare = 3,
    Legendary = 1
}

--Table based on pourcentage of chance to obtain this race during legacy calculation
local RaceRarityPrct = {
    Normal = 100,
    Ground = 30,
    Fire = 20,
    Ice = 10,
    Light = 10,
    Water = 5,
    Celestial = 5
}

local PureColors = {
    Color3.fromRGB(255,255,255),
    Color3.fromRGB(0,0,0),
    Color3.fromRGB(255, 0, 0),
    Color3.fromRGB(0, 0, 255),
    Color3.fromRGB(0, 255, 0)
}

--chance to get an extra talent in %
local RarityMoreTalents = {
    0.001,
    0.1,
    1,
    90
}

local CommonMaterial = {
    Enum.Material.Plastic,
    Enum.Material.SmoothPlastic
}
local UncommonMaterial = {
    Enum.Material.Cobblestone
}
local RareMaterial = {
    Enum.Material.DiamondPlate,
    Enum.Material.Glass
}
local UltraRareMaterial = {
    Enum.Material.Foil,
    Enum.Material.Metal
}
local LegendaryMaterial = {
    Enum.Material.Neon
}

local CommonGene = {}
local UncommonGene = {}
local RareGene = {}
local UltraRareGene = {}
local LegendaryGene = {}

local function SetGenesTableRarity()
    CommonGene = {}
    UncommonGene = {}
    RareGene = {}
    UltraRareGene = {}
    LegendaryGene = {}

    local StockReference = GetStockItemDataServer:Invoke()
    --warn("STOCK : ", StockReference)
    for itemID, itemData in pairs(StockReference) do
        if string.lower(itemID):sub(1,6) == "images" then
            if itemData.AvailableItem then
                if itemData.Rarity == "Common" then
                    table.insert(CommonGene, itemData.ItemName)
                elseif itemData.Rarity == "Uncommon" then
                    table.insert(UncommonGene, itemData.ItemName)
                elseif itemData.Rarity == "Rare" then
                    table.insert(RareGene, itemData.ItemName)
                elseif itemData.Rarity == "UltraRare" then
                    table.insert(UltraRareGene, itemData.ItemName)
                elseif itemData.Rarity == "Legendary" then
                    table.insert(LegendaryGene, itemData.ItemName)
                end
            end
        end
    end
end

local function GetRarityParents(type, dataFather, dataMother)
    local rarityFather = nil
    local rarityMother = nil
    --print("TEST DATA FATHER / MOTHER", dataFather, dataMother)

    if type == "Material" then
        for _, mat in pairs(LegendaryMaterial) do
            if mat.Value == dataFather then
                rarityFather = "Legendary"
            end
            if mat.Value == dataMother then
                rarityMother = "Legendary"
            end
        end
        for _, mat in pairs(UltraRareMaterial) do
            if mat.Value == dataFather then
                rarityFather = "UltraRare"
            end
            if mat.Value == dataMother then
                rarityMother = "UltraRare"
            end
        end
        for _, mat in pairs(RareMaterial) do
            if mat.Value == dataFather then
                rarityFather = "Rare"
            end
            if mat.Value == dataMother then
                rarityMother = "Rare"
            end
        end
        for _, mat in pairs(UncommonMaterial) do
            if mat.Value == dataFather then
                rarityFather = "Uncommon"
            end
            if mat.Value == dataMother then
                rarityMother = "Uncommon"
            end
        end
        for _, mat in pairs(CommonMaterial) do
            if mat.Value == dataFather then
                rarityFather = "Common"
            end
            if mat.Value == dataMother then
                rarityMother = "Common"
            end
        end
        
    elseif type == "Color" then
        for _, color in pairs(PureColors) do
            if color == dataFather then
                rarityFather = "PureColors"
            end
            if color == dataMother then
                rarityMother = "PureColors"
            end
        end
        
        if not rarityMother then
            rarityMother = "OtherColor"
        end

        if not rarityFather then
            rarityFather = "OtherColor"
        end
    else
        --if gene
        if dataFather == "" then
            rarityFather = "Nothing"
        else
            local StockReference = GetStockItemDataServer:Invoke()
            rarityFather = StockReference[dataFather].Rarity
        end
        if dataMother == "" then
            rarityMother = "Nothing"
        else
            local StockReference = GetStockItemDataServer:Invoke()
            rarityMother = StockReference[dataMother].Rarity
        end
    end

    return rarityFather, rarityMother
end

local function RandomOther(type)
    if type == "Material" then
        return RarityDataModule.GetRandomMaterial()
    elseif type == "Color" then
        return RarityDataModule.GetRandomColor()
    else
        --IF GENE
        return RarityDataModule.GetRandomGene(type)
    end
end

function RarityDataModule.GetRandomValueOfTalent(talentID)
    --now select the value of talent in range with rarity in range value
    local min = CreaturesTalentsModule.TalentsTable[talentID].Value.Min
    local max = CreaturesTalentsModule.TalentsTable[talentID].Value.Max
    local nbRange = max - min

    local ValueWeight = {
        lastRange = {
            Weight = 1,
            Min = nbRange * 0.8,
            Max = max
        },
        secondRange = {
            Weight = 19,
            Min = nbRange * 0.3,
            Max = nbRange * 0.8
        },
        firstRange = {
            Weight = 80,
            Min = min,
            Max = nbRange * 0.3
        },
    }

    --make random to select random value in random range selected and determine power of abilitie
    local randomResult = Random.new():NextInteger(0, 100)
    if randomResult <= ValueWeight.lastRange.Weight then
        return Random.new():NextInteger(ValueWeight.lastRange.Min, ValueWeight.lastRange.Max)
    elseif randomResult <= ValueWeight.secondRange.Weight then
        return Random.new():NextInteger(ValueWeight.secondRange.Min, ValueWeight.secondRange.Max)
    else
        return Random.new():NextInteger(ValueWeight.firstRange.Min, ValueWeight.firstRange.Max)
    end
end

--[[
    This function allow to get randomly talents for creature. We have 2 step, first the chance to obtain a min 1 or more talents.
    Second step it's after know if we win min 1 talent, we make a random on rarity of all talent and check the first result match rarity.
    After this we check if exist other same rarity value and make a table of it and take random talent from there.
    This step are make the number of step 1 result.

    After we return table of id of talent creature win.
]]
function RarityDataModule.GetRandomTalent(dataFather, dataMother, isGenerator:boolean, existedTalents)
    --check how many talent can win creature
    local nbTalent

    -- Check creature can win with luck, more random talent only if not random from generator talent
    if not isGenerator then
        local r = Random.new()
        local r = r:NextNumber(0,100)
        r = string.format("%.2f", r)
        r = tonumber(r)
    
        for id, chance in ipairs(RarityMoreTalents) do
            if r <= chance then
                nbTalent = (#RarityMoreTalents - id)+1
                break
            end
        end
    else
        -- If is generator is sure only one talent
        nbTalent = 1
    end

    --create sorted table of little rarity to big rarity of talent
    local temp = {}
    local talentRarity = {}
    for id, talent in pairs(CreaturesTalentsModule.TalentsTable) do
        local rarityWeight = talent.RarityWeight
        --check if we have parent legacy
        if dataFather and dataMother then
            --for each parent we adding the value of rarity weight to same talent of parent to increase probabilities
            for _, t in pairs(dataFather) do
                if t == id then
                    rarityWeight += talent.RarityWeight
                end
            end
            for _, t in pairs(dataMother) do
                if t == id then
                    rarityWeight += talent.RarityWeight
                end
            end
        end

        -- Check if isGenerator random because we need to remove already knew talent by creature from generator talent system
        if isGenerator then
            if not existedTalents[id] then
                talentRarity[#talentRarity+1] = {key = id, value = rarityWeight}
            end
        else
            talentRarity[#talentRarity+1] = {key = id, value = rarityWeight}
        end
	end
	table.sort(talentRarity, function(a, b)
		return a.value < b.value
	end)

    print("test talent rarity", talentRarity, dataFather, dataMother)

    --make nb random select of rarity based on nb talent obtain and rarity of talent
    if nbTalent then
        for i=1, nbTalent, 1 do
            local random = Random.new()
            local result = random:NextNumber(0,talentRarity[#talentRarity].value)
            result = string.format("%.2f", result)
            result = tonumber(result)
        
            --find the rarity match with result of random
            for _, talent in pairs(talentRarity) do
                if result <= talent.value then
                    --when rarity talent is found, check if we have other talent with the same rarity and chose only random one of them
                    local other = {}
                    for _, otherTalent in pairs(talentRarity) do
                        if otherTalent.value == talent.value then
                            table.insert(other, otherTalent.key)
                        end
                    end
                    
                    --select one random of all same rarity talent and save it into temp talents
                    local selected = other[math.random(1,#other)]

                    temp[selected] = RarityDataModule.GetRandomValueOfTalent(selected)

                    print("TEST TALENT RARITY", selected, other , temp[selected])
                    break
                end
            end
        end
    end

    return temp
end

function RarityDataModule.GetRandomColor()
    local random = math.random(0,100)
    if random < ColorRarityWeight.PureColors then
        --print("LUCKY LEGENDARY COLOR")
        local color = PureColors[math.random(1,#PureColors)]
        return {r=color.R, g=color.G, b=color.B}
    else
        --print("OTHER COLOR")
        return ToolsModule.MakeRandomColorRGBFormat()
    end
end

function RarityDataModule.GetRandomMaterial()
    local random = math.random(0,100)
    if random < MaterialRarityWeights.Legendary then
        --print("LUCKY LEGENDARY MATERIAL")
        return LegendaryMaterial[math.random(1,#LegendaryMaterial)].Value
    elseif random < MaterialRarityWeights.UltraRare then
        return UltraRareMaterial[math.random(1,#UltraRareMaterial)].Value
    elseif random < MaterialRarityWeights.Rare then
        return RareMaterial[math.random(1,#RareMaterial)].Value
    elseif random < MaterialRarityWeights.Uncommon then
        return UncommonMaterial[math.random(1,#UncommonMaterial)].Value
    else
        return CommonMaterial[math.random(1,#CommonMaterial)].Value
    end
end

function RarityDataModule.GetRandomGene(type)
    if string.lower(type):match("tattoo") then
        type = "Tattoo"
    end

    local random = math.random(0,100)
    if random < GenesRarityWeights.Legendary then
        local copy = {}
        for _, gene in pairs(LegendaryGene) do
            if string.lower(gene):match(string.lower(type)) then
                table.insert(copy, gene)
            end
        end
        if #copy > 0 then
            --print("LUCKY LEGENDARY GENE")
            return copy[math.random(1,#copy)]
        else
            --print("NO LUCK NO EXIST")
            return ""
        end
    elseif random < GenesRarityWeights.UltraRare then
        local copy = {}
        for _, gene in pairs(UltraRareGene) do
            if string.lower(gene):match(string.lower(type)) then
                table.insert(copy, gene)
            end
        end
        if #copy > 0 then
            --print("ULTRA RARE GENE")
            return copy[math.random(1,#copy)]
        else
            --print("NO LUCK NO EXIST")
            return ""
        end
    elseif random < GenesRarityWeights.Rare then
        local copy = {}
        for _, gene in pairs(RareGene) do
            if string.lower(gene):match(string.lower(type)) then
                table.insert(copy, gene)
            end
        end
        if #copy > 0 then
            --print("RARE GENE")
            return copy[math.random(1,#copy)]
        else
            --print("NO LUCK NO EXIST")
            return ""
        end
    elseif random < GenesRarityWeights.Uncommon then
        local copy = {}
        for _, gene in pairs(UncommonGene) do
            if string.lower(gene):match(string.lower(type)) then
                table.insert(copy, gene)
            end
        end
        if #copy > 0 then
            --print("UNCOMMON GENE")
            return copy[math.random(1,#copy)]
        else
            --print("NO LUCK NO EXIST")
            return ""
        end
    elseif random < GenesRarityWeights.Common then
        local copy = {}
        for _, gene in pairs(CommonGene) do
            if string.lower(gene):match(string.lower(type)) then
                table.insert(copy, gene)
            end
        end
        if #copy > 0 then
            --print("COMMON GENE")
            return copy[math.random(1,#copy)]
        else
            --print("NO LUCK NO EXIST")
            return ""
        end
    else
        print("NOTHING GENE", type)
        return ""
    end
end

--[[
    This method allows to create a temporary table with a percentage rate of rarity to obtain the races given in parameter between two parents and the normal race.
    Then, we use the weight created in this table according to the percentage of chance of the reference table of rarity of
    the races to obtain in a random way one of the race of the parents or a normal. The rarer the breed the more difficult it is to get one.

    Rarity total must be 100. Method use for Legacy chose random race between two parent
]]
function RarityDataModule.GetRandomBetweenTwoRaces(dataFather, dataMother, dataNormal)
    print("TEST Legacy between 2 Races Parents")
    local raceFatherRarityPrct = RaceRarityPrct[dataFather.Race]
    local raceMotherRarityPrct = RaceRarityPrct[dataMother.Race]

    local n = raceMotherRarityPrct+raceFatherRarityPrct

    local rarity = {
        [dataMother.Race] = raceMotherRarityPrct,
        [dataFather.Race] = raceFatherRarityPrct,
        ["Normal"] = n>=100 and 100 or 100 - n
    }

    print("TEST Rarity Table Chance %", rarity)

    local temp = {
        [dataMother.Race] = dataMother,
        [dataFather.Race] = dataFather,
        [dataNormal.Race] = dataNormal
    }

    local RandomNumber = math.random(1, 100)
    local Number = 0

    for Rarity, Chance in pairs(rarity) do
        Number = Number + Chance
        if RandomNumber <= Number then
            print("TEST RACE LEGACY", Rarity)
            return temp[Rarity]
        end
    end
end

function RarityDataModule.CalculateRarityRandomLegacy(type, dataFather, dataMother)
    local rarityFather, rarityMother = GetRarityParents(type, dataFather, dataMother)

    --print("RARITY FATHER", rarityFather)
    --print("RARITY MOTHER", rarityMother)

    if rarityFather == rarityMother then
        --print("SAME RARITY")
        local weight
        if rarityMother:match("Other") then
            weight = 90
        else
            weight = 35
        end
        
        local random = math.random(0,100)
        if random < weight then
            local r = math.random(0,100)
            if r > 50 then
                --print("LEGACY MOTHER")
                return dataMother
            else
                --print("LEGACY FATHER")
                return dataFather
            end
        else
            --print("LEGACY RANDOM OTHER")
            return RandomOther(type)
        end
    else
        --print("NOT SAME RARITY")
        local random = math.random(0,100)
        local RarityWeight
        if type == "Material" then
            RarityWeight = MaterialRarityWeights
        elseif type == "Color" then
            RarityWeight = ColorRarityWeight
        else
            --IF GENE
            RarityWeight = GenesRarityWeights
        end

        if RarityWeight[rarityFather] < RarityWeight[rarityMother] then
            print("FATHER MORE RARE")
            if random < RarityWeight[rarityFather] then
                --print("LEGACY FATHER")
                return dataFather
            elseif random < RarityWeight[rarityMother] + (RarityWeight[rarityMother]*0.2) then --we give 20% more than GetRandomOther because it's Legacy Parent
                --print("LEGACY MOTHER")
                return dataMother
            else
                --print("LEGACY RANDOM OTHER")
                return RandomOther(type)
            end
        else
            print("MOTHER MORE RARE")
            if random < RarityWeight[rarityMother] then
                --print("LEGACY MOTHER")
                return dataMother
            elseif random < RarityWeight[rarityFather] + (RarityWeight[rarityFather]*0.2) then
                --print("LEGACY FATHER")
                return dataFather
            else
                --print("LEGACY RANDOM OTHER")
                return RandomOther(type)
            end
        end
    end
end

function RarityDataModule:Init()
    SetGenesTableRarity()
    warn("RarityDataModule Init Down")
end

local WeightRarity = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    UltraRare = 4,
    Legendary = 5
}

local WeightEvolution = {
    Normal = 1,
    Ground = 3,
    Fire = 5,
    Ice = 8,
    Light = 11,
    Water = 15,
    Celestial = 20
}

local PureColorWeight = 5


--[[
    This function allow to calculate the rarity of creature data give in parameter and return the Rating value of Creature after calculate with other rarity characteristic
    and genes.
]]
function RarityDataModule:CalculateCreatureRarity(CreatureData)
    local RarityBase = 0
    local RarityGene = 0
    local CreatureRarity

    --Calculation of RarityBase with rarity of Colors, Materials and Race
    for id, value in pairs(CreatureData.PartsMaterial) do
        local r = GetRarityParents("Material", value)
        RarityBase += WeightRarity[r]

        if CreatureData[id.."Color"] then
            if table.find(PureColors, Color3.fromRGB(CreatureData[id.."Color"].r,CreatureData[id.."Color"].g,CreatureData[id.."Color"].b)) then
                RarityBase += PureColorWeight
            end
        end
    end
    if table.find(PureColors, Color3.fromRGB(CreatureData.Color.r,CreatureData.Color.g,CreatureData.Color.b)) then
        RarityBase += PureColorWeight
    end
    RarityBase += WeightEvolution[CreatureData.Race]

    RarityBase*=2
    RarityBase = math.round(RarityBase/9) --Calcule average with 4 element(marking, mane, socks, tail) for material and color so divide by 8

    --Calculation of RarityGene with rarity of all gene equipped in creature
    for id, value in pairs(CreatureData.Genes) do
        if value then
            if id ~= "Wing" then
                local r = GetRarityParents("Gene", value, "")
                if WeightRarity[r] then
                    RarityGene += WeightRarity[r]
                end
            end
        end
    end

    RarityGene = math.round(RarityGene / ToolsModule.LengthOfDic(CreatureData.Genes))

    --print("TEST CREATURE RARITY BASE / RARITY GENE", RarityBase, RarityGene, math.round((RarityBase + RarityGene)/2))

    CreatureRarity = math.round((RarityBase + RarityGene)/2)

    if CreatureRarity <= WeightRarity.Common then
        print("TEST CREATURE Common")
        return "Common"
    elseif CreatureRarity <= WeightRarity.Uncommon then
        print("TEST CREATURE Uncommon")
        return "Uncommon"
    elseif CreatureRarity <= WeightRarity.Rare then
        print("TEST CREATURE Rare")
        return "Rare"
    elseif CreatureRarity <= WeightRarity.UltraRare then
        print("TEST CREATURE UltraRare")
        return "UltraRare"
    else
        print("TEST CREATURE Legendary")
        return "Legendary"
    end
end

return RarityDataModule