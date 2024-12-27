local HorsesDataModule = {
	--Data tables
	GrowthType = {Baby = "Baby", Adult = "Adult"},
	GenderHorse = {Male = "Male", Female = "Female"},
	RaceHorse = {
		Normal = "Normal",
		Ground = "Ground",
		Fire = "Fire",
		Ice = "Ice",
		Light = "Light",
		Water = "Water",
		Celestial = "Celestial"
	},
	CreatureType = {
		Horse = "Horse",
		Cat = "Cat"
	},
	ColorHorse = {Red = Color3.new(1, 0, 0), Blue = Color3.new(0, 0, 1), Green = Color3.new(0, 1, 0)},
	RatingValue = {
		Common = "Common",
		Uncommon = "Uncommon",
		Rare = "Rare",
		UltraRare = "UltraRare",
		Legendary = "Legendary"
	}
}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local ServerStorage = game.ServerStorage.ServerStorageSync

--Require Modules
local DataManagerModule = require("DataManagerModule")
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")
local ClubsDataModule = require("ClubsDataModule")
local HorseLoader = require("HorseLoader")
local GeneDataModule = require("GeneDataModule")
local RarityDataModule = require("RarityDataModule")
local HorseEffectModule = require("HorseEffect")
local CreatureEvolutionModule = require("CreatureEvolutionModule")
local HorseStatusHandler = require("HorseStatusHandler")
local GameDataModule = require("GameDataModule")
local AccessoryModule = require("AccessoryModule")
local EnvironmentModule = require("EnvironmentModule")

--Event
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local StartBreedingEvent = BindableEvent.StartBreeding
local StartGrowthFoal = BindableEvent.StartGrowthFoal
local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert
local ShowNotificationRemoteEvent = RemoteEvent.ShowNotification
local RE_ExitedHorse = RemoteEvent.ExitedHorse
local BE_AchievementProgress = BindableEvent.AchievementProgress

local InvokHorsePlayer = Instance.new("RemoteFunction", RemoteFunction)
InvokHorsePlayer.Name = "InvokHorsePlayer"
local CheckHorseOwnerIsPlayerID = Instance.new("RemoteFunction", RemoteFunction)
CheckHorseOwnerIsPlayerID.Name = "CheckHorseOwnerIsPlayerID"
local InstantGrowthTime = Instance.new("RemoteFunction", RemoteFunction)
InstantGrowthTime.Name = "InstantGrowthTime"

-- Parameters
local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")
local StockFolder = ServerStorage.ShopItemsStorage

--Structure Data Horse template
local CreatureData = {
	CreatureName = "";
	CreatureType = "";
	Age = 0;
	Level = 1;
	Exp = 0;
	ReadyToEvolve = false;
	LockExp = false;
	Gender = HorsesDataModule.GenderHorse.Male;
	Race = HorsesDataModule.RaceHorse.Fire;
	Color = {r=0,g=0,b=0};
	Married = ""; --HorseId
	Mature = false;
	Growth = HorsesDataModule.GrowthType.Baby;
	TimeGrowthValue = 0;
	Genes = {}; --One slot for type of genes with the id of gene coressponding type associated to the horse genes
	Accessory = {};
	LastTimeDecreaseMaintenance = 0;
	Maintenance = {
		Cleanness = {
			Value = 0;
			Max = 100;
			RateDecrease = 5;
		};
		Happyness = {
			Value = 0;
			Max = 100;
			RateDecrease = 5;
		};
		Fed = {
			Value = 0;
			Max = 100;
			RateDecrease = 5;
		};
		Brushed = {
			Value = 0;
			Max = 100;
			RateDecrease = 5;
		};
		Scrape = {
			Value = 0;
			Max = 100;
			RateDecrease = 5;
		};
	};
	Health = {
		Value = 0;
		Max = 100;
	};
	Stamina = {
		Value = 0;
		Max = 100;
	};
	Elegance = {
		Value = 0;
		Max = 100;
	};
	Magic = {
		Value = 0;
		Max = 100;
	};
	Speed = {
		Value = 0;
		Max = 100;
	};
	Mother = ""; --HorseId
	Father = ""; --HorseId
	EyesColor = {r=0,g=0,b=0};
	ManeColor = {r=0,g=0,b=0};
	TailColor = {r=0,g=0,b=0};
	SocksColor = {r=0,g=0,b=0};
	PartsMaterial = {
		Marking = 256, --256 is plastic id material
		Mane = 256,
		Tail = 256,
		Socks = 256
	};
	Stallion = false;
	Dead = false;
	Rating = HorsesDataModule.RatingValue.Common;
	DistanceWalked = 0;
	AchievementsMade = {
		--Name event is Key and value is ID of event EX: Event1 = "";
	};
	RankingsAtGames = {
		--Name game is Key and Value is ranking of horse at this game EX: Game1 = 200;
	};
	ListOfOwners = {
		--Use id player for save the owner	EX: Owner1 = ""; For acutal owner : "ActualOwner"
	};
	FamilyTree = {
		Parents = {
			Mother = "";
			Father = "";
		};
		Childrens = {
			--Use id children in value for save and key is order children EX: Child1 = "AZE80AEA0E8A0ZEOAJZO23'";
		};
	};
	Groups = {
			
	};
	InNursery = false;
	InFavourites = false;
	TimeObtained = 0;
	Talents = {};
	isDELETE = false;
}

local function GenerateCreatureUniqueID(player)
	local str = string.gsub(DataManagerModule.GenerateUniqueID(), "{", "")
	str = string.gsub(str, "}", "")
	str = string.gsub(str, "-", "")
	return str
end

--[[
	This method allow to return data chose randomly between data of father or data of mother
	based on pourcentage value given in paramters.
]]
local function LegacyDataFromMotherOrFather(dataFather, dataMother, fatherPrct, motherPrct, type)
	if type == "Race" then
		local random = math.random(0, 100)
		if random < RarityDataModule.PrctWeight.Other then
			local t = GameDataModule.RaceEvolutionTable
			local result = RarityDataModule.GetRandomBetweenTwoRaces(t[dataFather], t[dataMother], t[1])
			print("RESULT LEGACY RACE PARENTS", result, "Level :", table.find(t, result))
			return table.find(t, result)
		else
			--if the biggest chance, we make child as normal so Level 1 for race Normal
			return 1
		end
	else
		local total = fatherPrct+motherPrct
		local result = math.random(1, fatherPrct+motherPrct)
		
		if result<= total and result > (total-fatherPrct)  then
			return dataFather
		else
			return dataMother
		end
	end
end

--[[

]]
local function LegacyRandomData(player, dataFather, dataMother, type)
	local random = math.random(0, 100)
	if random < RarityDataModule.PrctWeight.Other then
		--print("LEGACY OTHER")
		if type == "Material" then
			return RarityDataModule.GetRandomMaterial()
		elseif type == "Color" then
			return RarityDataModule.GetRandomColor()
		elseif type == "Talents" then
			return RarityDataModule.GetRandomTalent()
		else
			--genes legacy in the same system
			return RarityDataModule.GetRandomGene(type)
		end
	else
		--print("LEGACY PARENT")
		if type == "Material" or type == "Color" then
			return RarityDataModule.CalculateRarityRandomLegacy(type, dataFather, dataMother)
		elseif type == "Talents" then
			return RarityDataModule.GetRandomTalent(dataFather, dataMother)
		else
			--IF GENE
			return RarityDataModule.CalculateRarityRandomLegacy(type, dataFather, dataMother)
		end
	end
end

local function ShowHorses(player, creatureID)
	RemoteEvent.ShowHorseUI:FireClient(player, creatureID)
end

--[[
	This method allow to setup and check if we can add data horse to favourites horses lists showed
	in the player profil UI.
]]
function HorsesDataModule.SetHorseFavourites(player, creatureID)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	local favouritesCreatures = PlayerDataModule:Get(player, "FavouritesCreatures")
	if favouritesCreatures and creaturesCollection then
		--check number of favourites slot is available
		for index, data in pairs(favouritesCreatures) do
			if creatureID == data then
				--already set in favourites, so remove it
				favouritesCreatures[index] = ""
				creaturesCollection[creatureID].InFavourites = false
				PlayerDataModule:Set(player, favouritesCreatures, "FavouritesCreatures")
				PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
				return false
			else
				--not already set but check if this slot is available and not already adding on other slots
				if data == "" then
					for i, d in pairs(favouritesCreatures) do
						if d == creatureID then
							--already set in favourites, so remove it
							favouritesCreatures[i] = ""
							creaturesCollection[creatureID].InFavourites = false
							PlayerDataModule:Set(player, favouritesCreatures, "FavouritesCreatures")
							PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
							return false
						end
					end
					
					--Slot is free, set horse id here
					favouritesCreatures[index] = creatureID
					creaturesCollection[creatureID].InFavourites = true
					PlayerDataModule:Set(player, favouritesCreatures, "FavouritesCreatures")
					PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
					return true
				end
			end
		end
		
		--Not free slots available return nil and set notification
		ShowNotificationRemoteEvent:FireClient(
			player,
			"Favoris complet",
			"Il n'y a plus de place dans vos favoris, enlevez un autre de vos favoris pour faire de la place."
		)
		return nil
	end
end

function HorsesDataModule.GetAllEnumDataForFilters()
	local dic = {
		Gender = HorsesDataModule.GenderHorse;
		Race = HorsesDataModule.RaceHorse;
		CreatureType = HorsesDataModule.CreatureType;
		Color = HorsesDataModule.ColorHorse;
		Growth = HorsesDataModule.GrowthType;
		Rating = HorsesDataModule.RatingValue;
		InNursery = {True = true, False = false};
		Stallion = {True = true, False = false}
	}
	return dic
end

local function ExitHorse(player, horse)
	while horse.PrimaryPart.Velocity.Y > 1 do
		task.wait(0.1)
	end
	RE_ExitedHorse:FireClient(player)
	HorseEffectModule.UpdatePlayerSparks(player, false)
end

function HorsesDataModule.ChangeRateDecreaseOfMaintenanceValue(player, creatureID, maintenanceType, Value)
	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
	if not CreatureData then
		return
	end
	CreatureData.Maintenance[maintenanceType].RateDecrease = Value
	PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
end

--[[
	This method allow to get timer value of breeding horse from data with the horse id.
]]
function HorsesDataModule.GetTimeBreedingValueOfCreatureID(player, creatureID)
	local nurseryCollection = PlayerDataModule:Get(player, "NurseryCollection")
	if nurseryCollection then
		return nurseryCollection[creatureID]["TimeBreedingValue"]
	end
end

--[[
	This method allow to set de timer breeding value in data for the horse id given in paramter.
]]
function HorsesDataModule.SetTimeBreedingValueOfCreatureID(player, creatureID, value)
	local nurseryCollection = PlayerDataModule:Get(player, "NurseryCollection")
	if nurseryCollection then
		if nurseryCollection[creatureID] then
			nurseryCollection[creatureID]["TimeBreedingValue"] = value
			PlayerDataModule:Set(player, nurseryCollection, "NurseryCollection")
		end
	end
end

--[[
	This method allow to get timer value of growth Foal from data with the horse id.
]]
function HorsesDataModule.GetTimeGrowthValueOfCreatureID(player, creatureID)
	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
	if CreatureData then
		return CreatureData.TimeGrowthValue
	end
end

--[[
	This method allow to set de timer growth value in data for the Foal id given in paramter.
]]
function HorsesDataModule.SetTimeGrowthValueOfCreatureID(player, creatureID, value)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	if creaturesCollection then
		if creaturesCollection[creatureID] then
			creaturesCollection[creatureID]["TimeGrowthValue"] = value
			PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
		end
	end
end

--[[
	This method allow to change de Growth type of creatureID given in parameter Foal to Horse type.
	Method send a notification annoucement for show player Foal have grow up into a horse.
]]
function HorsesDataModule.SetFoalToHorse(player, creatureID)
	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
	if CreatureData then
		--change the growth type of horse id to Horse type
		CreatureData.Growth = HorsesDataModule.GrowthType.Adult
		PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
		
		--increment the achievement of obtaine some grow up horses
		BE_AchievementProgress:Fire(player, "Achievement9", 1)
		BE_AchievementProgress:Fire(player, "Achievement1", 1)
		BE_AchievementProgress:Fire(player, "Achievement5", 1)
		
		--Notification event fire to player for show the notification and show horse grow up
		ShowPopupBindableEvent:Fire(
			player,
			CreatureData.CreatureName.." has grown up",
			"Your creature has grown into a adult !",
			ToolsModule.AlertPriority.Annoucement,
			ToolsModule.AlertTypeButton.OK,
			ToolsModule.AlertTypeButton.SeeCreature,
			nil,
			nil,
			ShowHorses,
			{creatureID}
		)
	end
end

--[[
	This method allow to create a little dictionnary store in Nursery Collection of player where
	we can found the horse mother id data for create baby.
	After assignement and data setup, send bindable event to signal and launch the start breeding event for Timer Manager.
]]
function HorsesDataModule.MoveHorsesToNursery(player, fatherID, motherID, babyName)
	--This function allow to check if player can pay to launch the behavior of MoveToNursery and make a creature fusion
	local function Payout(player)
		local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")

		-- Check if player have slots available
		local slotsAvailables, nbMaxSlotsAvailables, nbCreatures = PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(player, true)
		if not slotsAvailables then
			return
		end

		-- Calculation of Cost Fusion
		local firstCreature = creaturesCollection[fatherID]
		local secondCreature = creaturesCollection[motherID]

		local goldCost = GameDataModule.CoastFusion.Rarity[firstCreature.Race] + GameDataModule.CoastFusion.Rarity[secondCreature.Race]
		local crystal1 = GameDataModule.CoastFusion.Crystals[firstCreature.Race]
		local crystal2 = GameDataModule.CoastFusion.Crystals[secondCreature.Race]

		local canPayout = true

		-- Check if player have all needed ressources to pay
		if goldCost > PlayerDataModule:Get(player, "Ecus") then
			canPayout = false
		end

		if firstCreature.Race == secondCreature.Race then
			if crystal1*2 > PlayerDataModule:Get(player, "Crystals."..firstCreature.Race.."Crystal") then
				canPayout = false
			end
		else
			if crystal1 > PlayerDataModule:Get(player, "Crystals."..firstCreature.Race.."Crystal") then
				canPayout = false
			end

			if crystal2 > PlayerDataModule:Get(player, "Crystals."..secondCreature.Race.."Crystal") then
				canPayout = false
			end
		end

		if canPayout then
			local resultGold = PlayerDataModule:Decrement(player, goldCost, "Ecus")
			local resultCrystals, resultCrystal1, resultCrystal2
			if firstCreature.Race == secondCreature.Race then
				resultCrystals = PlayerDataModule:Decrement(player, crystal1*2, "Crystals."..firstCreature.Race.."Crystal")
			else
				resultCrystal1 = PlayerDataModule:Decrement(player, crystal1, "Crystals."..firstCreature.Race.."Crystal")
				resultCrystal2 = PlayerDataModule:Decrement(player, crystal2, "Crystals."..secondCreature.Race.."Crystal")

				resultCrystals = resultCrystal1 and resultCrystal2
			end

			local result = resultGold and resultCrystals
			if result then
				local nurseryCollection = PlayerDataModule:Get(player, "NurseryCollection")
				
				if nurseryCollection and creaturesCollection then
					creaturesCollection[fatherID].InNursery = true
					creaturesCollection[motherID].InNursery = true
					
					--Structure of mother store in Nursery Collection
					nurseryCollection[motherID] = {
						HorseFatherID = fatherID;
						BabyName = babyName;
						TimeBreedingValue = 0;
					}
			
					--Check if father or mother are invoke in game and destroy it
					local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Horse_"..player.Name)
					if exist then
						if exist.CreatureID.Value == motherID or exist.CreatureID.Value == fatherID then
							exist:Destroy()
						end
					end
			
					PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
					PlayerDataModule:Set(player, nurseryCollection, "NurseryCollection")
					
					StartBreedingEvent:Fire(player, motherID)
					
					ShowNotificationRemoteEvent:FireClient(
						player,
						"Reproduction lancé",
						creaturesCollection[fatherID].CreatureName.." & "..creaturesCollection[motherID].CreatureName.." sont en reproduction !"
					)

					RemoteEvent.CreaturesFusionLaunch:FireClient(player)
				end
			else
				warn("Error during payout with Decrement call value :\n", "ResultGold: "..resultGold.."\n", "ResultCrystal1: "..resultCrystal1.."\n", "ResultCrystal2: "..resultCrystal2)
			end
		else
			--[[ --if error with payout, it's because player don't have money so we make a popup who redirect player on the Purchase Ecus
			ShowPopupBindableEvent:Fire(
				player,
				"Fail Payout",
				"You don't have enough Ecus ...",
				ToolsModule.AlertPriority.Annoucement,
				nil,
				ToolsModule.AlertTypeButton.OK,
				ToolsModule.OpenEcusGui,
				{player}
			) ]]
		end
	end

	Payout(player)
end

--[[
	This method is call when the Breeding is down and allow to remove mother from Nursery and launch method
	to create the baby horse.
]]
function HorsesDataModule.RemoveHorsesFromNursery(player, motherID)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	local nurseryCollection = PlayerDataModule:Get(player, "NurseryCollection")
	
	if nurseryCollection and creaturesCollection then
		local motherNursery = nurseryCollection[motherID]
		creaturesCollection[motherNursery.HorseFatherID].InNursery = false
		creaturesCollection[motherID].InNursery = false
		
		HorsesDataModule.CreateHorseFromBreeding(player, motherNursery.HorseFatherID, motherID, motherNursery.BabyName, creaturesCollection)
		
		--Find and delete the data strcture of mother id from nursery because baby is born
		PlayerDataModule:Set(player, nil, "NurseryCollection."..motherID)
	end
	
end

--[[
	This method allow to create a baby horse with the father id and mother id. This method create a horse based
	on the default structure with default value.
	And set data non default by random value of mother or father by legacy value given.
]]
function HorsesDataModule.CreateHorseFromBreeding(player, fatherID, motherID, babyName, creaturesCollection)
	if creaturesCollection then
		local father = creaturesCollection[fatherID]
		local mother = creaturesCollection[motherID]
		
		local creatureID = GenerateCreatureUniqueID(player)
		local child = DataManagerModule.RecursiveCopy(CreatureData)
		child.CreatureName = ToolsModule.GenerateRandomName()
		child.CreatureType = father.CreatureType
		child.Mother = motherID
		child.Father = fatherID
		child.FamilyTree.Parents.Father = child.Father
		child.FamilyTree.Parents.Mother = child.Mother
		child.Growth = HorsesDataModule.GrowthType.Baby
		child.Gender = LegacyDataFromMotherOrFather(father.Gender, mother.Gender, 50,50)
		child.Level = LegacyDataFromMotherOrFather(father.Level, mother.Level, 50,50, "Race")
		child.Color = LegacyRandomData(player, father.Color, mother.Color, "Color")
		child.EyesColor = LegacyRandomData(player, father.EyesColor, mother.EyesColor, "Color")
		child.ManeColor = LegacyRandomData(player, father.ManeColor, mother.ManeColor, "Color")
		child.TailColor = LegacyRandomData(player, father.TailColor, mother.TailColor, "Color")
		child.SocksColor = LegacyRandomData(player, father.SocksColor, mother.SocksColor, "Color")
		child.Talents = LegacyRandomData(player, father.Talents, mother.Talents, "Talents")

		child.TimeObtained = os.time()
		child.ListOfOwners["ActualOwner"] = player.UserId

		--material part legacy
		local partsMaterial={}
		for part, materialID in pairs(child.PartsMaterial) do
			partsMaterial[part] = LegacyRandomData(player, father.PartsMaterial[part], mother.PartsMaterial[part], "Material")
		end
		child.PartsMaterial = partsMaterial

		--make genes parts dynamic
		local genes={}
		for _, gene in pairs(GeneDataModule.TypeOfGene) do
			if gene == "Eye" then
				--here we get a random gene
				local result = LegacyRandomData(player, father.Genes[gene], mother.Genes[gene], gene)
				--check obj of gene for check type of creature can use it
				local obj = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):FindFirstChild(result)
				if obj then
					local Species = obj:GetAttribute("Species")
					if Species then
						Species = Species:split(';')
						for _, specie in pairs(Species) do
							--if child fusion are type authorized in species of this gene, give result, if not, no luck and don't give gene
							if specie == child.CreatureType then
								genes[gene] = result
								GeneDataModule.CreateGeneFromLegacy(player, result, gene)
								break
							else
								genes[gene] = ""
							end
						end
					end
				else
					--if obj is not found it's because it's no gene exist so make empty
					genes[gene] = ""
				end
			elseif gene ~= "Wing" then
				local result = LegacyRandomData(player, father.Genes[gene], mother.Genes[gene], gene)
				genes[gene] = result
				GeneDataModule.CreateGeneFromLegacy(player, result, gene)
			end
		end

		genes["Wing"] = "rbxassetid://7787736329"
		child.Genes = genes

		child.Race = GameDataModule.RaceEvolutionTable[child.Level].Race

		child.Health.Value = child.Health.Max
		child.Stamina.Value = child.Stamina.Max
		child.Elegance.Value = child.Elegance.Max
		child.Magic.Value = child.Magic.Max
		
		for _, d in pairs(child.Maintenance) do
			d.Value = d.Max
		end
		
		child.LastTimeDecreaseMaintenance = os.time()
		
		child.Rating = RarityDataModule:CalculateCreatureRarity(child)

		creaturesCollection[creatureID] = child

		PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")

		HorsesDataModule.SetChildrenToParent(player, creatureID, fatherID)
		HorsesDataModule.SetChildrenToParent(player, creatureID, motherID)
		
		BE_AchievementProgress:Fire(player, "Achievement8", 1)
		
		if child.Race == HorsesDataModule.RaceHorse.Celestial then
			BE_AchievementProgress:Fire(player, "Achievement10", 1)
		end
		
		PlayerDataModule:Increment(player, 1,"TotalNumberOfCreatures")
		CreatureEvolutionModule.IncrementNumberOfRace(player, child.Race, child.CreatureType, 1)
		
		ClubsDataModule.UpdateHorsesOfClub(player, true)
		
		--[[ ShowPopupBindableEvent:Fire(
			player,
			"Creature Born",
			"YEAH ! "..child.CreatureName.." is born !",
			ToolsModule.AlertPriority.Annoucement,
			ToolsModule.AlertTypeButton.OK,
			ToolsModule.AlertTypeButton.SeeCreature,
			ShowHorses,
			{creatureID}
		) ]]
		
		--Starting the growth of foal to begin a horse, pass the id of foal born in parameter
		StartGrowthFoal:Fire(player, creatureID)

		RemoteEvent.SpawnChildFusionModel:FireClient(player, child, creatureID)
		
		return true
	end
	
	return false
end

--[[
	This method allow to manipulate data of horse and set value of FamilyTree.
]]
function HorsesDataModule.SetChildrenToParent(player, creatureID, parentID)
	local CreatureParent = PlayerDataModule:Get(player, "CreaturesCollection."..parentID)
	CreatureParent.FamilyTree.Childrens["Children"..DataManagerModule.GetLengthOfDictionnary(CreatureParent.FamilyTree["Childrens"])] = creatureID
	PlayerDataModule:Set(player, CreatureParent, "CreaturesCollection."..parentID)
end

--[[
	Create creature structure on server side based on CreatureData structure for Test adding creature.
]]
function HorsesDataModule.CreateHorseDataForTest(player, creatureType)
	local CreaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")

	local creatureID = GenerateCreatureUniqueID(player)
	local creatureData = DataManagerModule.RecursiveCopy(CreatureData)
	creatureData.CreatureName = ToolsModule.GenerateRandomName()
	creatureData.CreatureType = creatureType;
	creatureData.Age = math.random(1,200)
	creatureData.Level = 1
	creatureData.Exp = 0
	creatureData.Growth = HorsesDataModule.GrowthType.Adult
	creatureData.Gender = ToolsModule.GetRandomValueFromDictionnary(HorsesDataModule.GenderHorse)
	creatureData.Race = HorsesDataModule.RaceHorse.Normal
	creatureData.Color = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.Health.Value = math.random(1,100)
	creatureData.Stamina.Value = CreatureData.Stamina.Max
	creatureData.Magic.Value = math.random(1,100)
	creatureData.Speed.Value = math.random(1,100)
	creatureData.Elegance.Value = math.random(1,100)
	creatureData.LastTimeDecreaseMaintenance = os.time()
	creatureData.Maintenance.Cleanness.Value = math.random(1,100)
	creatureData.Maintenance.Happyness.Value = math.random(1,100)
	creatureData.Maintenance.Fed.Value = math.random(1,100)
	creatureData.Maintenance.Brushed.Value = math.random(1,100)
	creatureData.Maintenance.Scrape.Value = math.random(1,100)
	creatureData.EyesColor = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.ManeColor = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.TailColor = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.SocksColor = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.DistanceWalked = math.random(1,200)
	creatureData.Talents = RarityDataModule.GetRandomTalent()

	creatureData.TimeObtained = os.time()
	creatureData.ListOfOwners["ActualOwner"] = player.UserId

	--material part legacy
	local partsMaterial={}
	for part, materialID in pairs(creatureData.PartsMaterial) do
		partsMaterial[part] = RarityDataModule.GetRandomMaterial()
	end
	creatureData.PartsMaterial = partsMaterial

	--make genes parts dynamic
	local genes={}
	for _, gene in pairs(GeneDataModule.TypeOfGene) do
		genes[gene] = ""
	end
	genes["Wing"] = "rbxassetid://7787736329"
	creatureData.Genes = genes
	
	creatureData.Rating = RarityDataModule:CalculateCreatureRarity(creatureData)

	CreaturesCollection[creatureID] = creatureData
	
	PlayerDataModule:Set(player, CreaturesCollection, "CreaturesCollection")

	PlayerDataModule:Increment(player, 1, "TotalNumberOfCreatures")

	BE_AchievementProgress:Fire(player, "Achievement1", 1)
	BE_AchievementProgress:Fire(player, "Achievement5", 1)
	
	if creatureData.Race == HorsesDataModule.RaceHorse.Celestial then
		BE_AchievementProgress:Fire(player, "Achievement10", 1)
	end
	
	CreatureEvolutionModule.IncrementNumberOfRace(player, creatureData.Race, creatureData.CreatureType, 1)
	
	ClubsDataModule.UpdateHorsesOfClub(player, true)

	return creatureID
end

--[[
	This function allow to create a Animal based on Beatuiful animal make by Clement and not use random, we use model by clement to setup
	the same animal for player. Use in commande line.
	2 cases : 
		- isCustom is true : It's because command line who call this function are for custom Supra link to player ID
		- isCustom is false : It's call by command Pretty animal to get random pretty supra with type give
]]
function HorsesDataModule.CreatePrettyAnimal(player, creatureType, isCustom)
	-- Randomly take reference pretty animal from server storage pretty animals
	local PrettyAnimals = isCustom and game:GetService("ServerStorage").ServerStorageSync.PlayersCustomSupras:GetChildren() or game:GetService("ServerStorage").ServerStorageSync.PrettyAnimals[creatureType]:GetChildren()
	if #PrettyAnimals <= 0 then
		return
	end

	-- Found ModelReference of supra who need to copy value in newCreatureData
	local ModelReference
	if isCustom then
		for _, supra in pairs(PrettyAnimals) do
			for _, plr in pairs(supra.Players:GetChildren()) do
				if plr.Value == player.UserId then
					ModelReference = supra
					creatureType = supra:GetAttribute("CreatureType")
					break
				end
			end

			if ModelReference then
				break
			end
		end
	else
		ModelReference = PrettyAnimals[math.random(1,#PrettyAnimals)]
	end

	if not ModelReference then
		return
	end

	local creatureID = GenerateCreatureUniqueID(player)
	local creatureData = DataManagerModule.RecursiveCopy(CreatureData)
	creatureData.CreatureName = ToolsModule.GenerateRandomName()
	creatureData.CreatureType = creatureType;
	creatureData.Age = math.random(1,200)

	-- Find level of Supra give
	for id, value in pairs(GameDataModule.RaceEvolutionTable) do
		if value.Race == ModelReference:GetAttribute("Evolution") then
			creatureData.Level = id
			creatureData.Exp = value.EXP
			break
		end
	end

	creatureData.Growth = HorsesDataModule.GrowthType.Adult
	creatureData.Gender = ToolsModule.GetRandomValueFromDictionnary(HorsesDataModule.GenderHorse)
	creatureData.Race = ModelReference:GetAttribute("Evolution")
	creatureData.Health.Value = math.random(1,100)
	creatureData.Stamina.Value = CreatureData.Stamina.Max
	creatureData.Magic.Value = math.random(1,100)
	creatureData.Speed.Value = math.random(1,100)
	creatureData.Elegance.Value = math.random(1,100)
	creatureData.LastTimeDecreaseMaintenance = os.time()
	creatureData.Maintenance.Cleanness.Value = math.random(1,100)
	creatureData.Maintenance.Happyness.Value = math.random(1,100)
	creatureData.Maintenance.Fed.Value = math.random(1,100)
	creatureData.Maintenance.Brushed.Value = math.random(1,100)
	creatureData.Maintenance.Scrape.Value = math.random(1,100)

	-- Be carful when setup color not take directly color of part but construct in rgb format
	creatureData.EyesColor = ToolsModule.MakeRandomColorRGBFormat()
	creatureData.Color = {r=ModelReference.Marking_Body.Color.r, g=ModelReference.Marking_Body.Color.g, b=ModelReference.Marking_Body.Color.b}
	creatureData.ManeColor = {r=ModelReference.Mane.Color.r, g=ModelReference.Mane.Color.g, b=ModelReference.Mane.Color.b}
	creatureData.TailColor = {r=ModelReference.Tail.Color.r, g=ModelReference.Tail.Color.g, b=ModelReference.Tail.Color.b}
	creatureData.SocksColor = {r=ModelReference.Socks.Color.r, g=ModelReference.Socks.Color.g, b=ModelReference.Socks.Color.b}
	
	creatureData.DistanceWalked = math.random(1,200)
	creatureData.Talents = RarityDataModule.GetRandomTalent()

	creatureData.TimeObtained = os.time()
	creatureData.ListOfOwners["ActualOwner"] = player.UserId

	--material part legacy
	local partsMaterial={}
	for part, materialID in pairs(creatureData.PartsMaterial) do
		if part == "Marking" then
			partsMaterial[part] = ModelReference.Marking_Body.Material.Value
		else
			partsMaterial[part] = ModelReference[part].Material.Value
		end
	end
	creatureData.PartsMaterial = partsMaterial

	-- Init genes table
	local stock = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):GetChildren()
	local genes={}
	for _, gene in pairs(GeneDataModule.TypeOfGene) do
		genes[gene] = ""
	end

	-- Set gene data from Model Reference
	for _, gene in pairs(GeneDataModule.TypeOfGene) do
		if not string.lower(gene):match("tattoo") and not string.lower(gene):match("effect") then
			for _, child in pairs(ModelReference:GetChildren()) do
				if string.lower(child.Name):match(string.lower(gene)) then
					for _, obj in pairs(stock) do
						if string.lower(obj.Name):sub(1,6) == "images" then
							local objTextureID = string.gsub(obj.Texture, "%D", "")
							local childTextureID = string.gsub(child.TextureID, "%D", "")
							if objTextureID == childTextureID and string.lower(obj.Name):match(string.lower(gene)) then
								genes[gene] = obj.Name
								GeneDataModule.CreateGeneFromLegacy(player, obj.Name, gene) -- Adding gene into animals and create in gene inventory
								break
							end
						end
					end
				end
			end

		-- Setting of Tattoo gene found in Model Reference to apply in gene data
		elseif string.lower(gene):match("tattoo") then
			for _, child in pairs(ModelReference:GetDescendants()) do
				if child:IsA("Texture") then
					-- Check if Tattoo are visible on Model Reference and setup only visible tattoo
					if child.Transparency < 1 then
						if string.lower(child.Name):match(string.lower(gene)) then
							for _, obj in pairs(stock) do
								if string.lower(obj.Name):sub(1,6) == "images" then
									local objTextureID = string.gsub(obj.Texture, "%D", "")
									local childTextureID = string.gsub(child.Texture, "%D", "")
									if objTextureID == childTextureID and string.lower(obj.Name):match(string.lower("Tattoo")) then
										genes[gene] = obj.Name
										GeneDataModule.CreateGeneFromLegacy(player, obj.Name, gene) -- Adding gene into animals and create in gene inventory
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end

	-- TEMPORARY - Force setup Wing gene data with texture of wing reference model
	genes["Wing"] = ModelReference.Wing_Left.TextureID
	creatureData.Genes = genes

	-- Check if Model Reference have somes accessory and setup all of that and give for player
	for _, child in pairs(ModelReference:GetChildren()) do
		if child.Name:match("Accessory") then
			local accessoryID = child.Name
			local exist = table.find(creatureData.Accessory, accessoryID)
			if not exist then
				table.insert(creatureData.Accessory, accessoryID)

				-- Create accessory in data player
				if not AccessoryModule:CheckItemAreInInventory(player, accessoryID) then
					warn("test not in inventory", accessoryID)
					-- Get data of item to good setup new item
					local itemData = BindableFunction:WaitForChild("GetShopItemData"):Invoke(accessoryID)
					if itemData then
						-- Search reference obj in shop of item accessory need to new create for player
						local ShopItems = game.ServerStorage.ServerStorageSync.ShopItems:GetDescendants()
						for _, child in pairs(ShopItems) do
							if child:IsA("BasePart") then
								if child.Name == accessoryID then
									-- Call function of Accessory module to setup data and object reference of new item for this player
									AccessoryModule:SetNewItemInventoryData(player, accessoryID, 0, itemData.Rarity, itemData.ImageID, itemData.DisplayName, child)
									break
								end
							end
						end
					end
				end
			end
		end
	end
	
	creatureData.Rating = RarityDataModule:CalculateCreatureRarity(creatureData)

	local CreaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	CreaturesCollection[creatureID] = creatureData
	PlayerDataModule:Set(player, CreaturesCollection, "CreaturesCollection")

	PlayerDataModule:Increment(player, 1, "TotalNumberOfCreatures")
	
	CreatureEvolutionModule.IncrementNumberOfRace(player, creatureData.Race, creatureData.CreatureType, 1)
	
	ClubsDataModule.UpdateHorsesOfClub(player, true)

	return creatureID
end

--[[
	Create creature structure on server side based on CreatureData structure for the first time player choose creature for game
	with one color random on creature.
]]
local function CreateCreatureDataFirstTime(player, creatureType, favoritColor, gender)
	local CreaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")

	local creatureID = GenerateCreatureUniqueID(player)
	local creatureData = DataManagerModule.RecursiveCopy(CreatureData)
	creatureData.CreatureName = ToolsModule.GenerateRandomName()
	creatureData.CreatureType = creatureType;
	creatureData.Age = 1
	creatureData.Level = 1
	creatureData.Exp = 0
	creatureData.Growth = HorsesDataModule.GrowthType.Adult
	creatureData.Gender = gender
	creatureData.Race = HorsesDataModule.RaceHorse.Normal
	creatureData.Health.Value = CreatureData.Health.Max
	creatureData.Stamina.Value = CreatureData.Stamina.Max
	creatureData.LastTimeDecreaseMaintenance = os.time()
	creatureData.Maintenance.Cleanness.Value = creatureData.Maintenance.Cleanness.Max
	creatureData.Maintenance.Happyness.Value = creatureData.Maintenance.Happyness.Max
	creatureData.Maintenance.Fed.Value = creatureData.Maintenance.Fed.Max
	creatureData.Maintenance.Brushed.Value = creatureData.Maintenance.Brushed.Max
	creatureData.Maintenance.Scrape.Value = creatureData.Maintenance.Scrape.Max

	creatureData.Talents = RarityDataModule.GetRandomTalent()

	creatureData.EyesColor = RarityDataModule.GetRandomColor()

	--select where we apply favorite color select by player
	local t = {
		"Color",
		"ManeColor",
		"TailColor",
		"SocksColor"
	}

	local random = math.random(1,#t)
	for i, c in pairs(t) do
		if i == random then
			print("TEST FAVORITE COLOR ARE SETUP ON", c, favoritColor)
			creatureData[c] = favoritColor
		else
			creatureData[c] = RarityDataModule.GetRandomColor()
		end
	end

	creatureData.TimeObtained = os.time()
	creatureData.ListOfOwners["ActualOwner"] = player.UserId

	--material part legacy
	local partsMaterial={}
	for part, materialID in pairs(creatureData.PartsMaterial) do
		partsMaterial[part] = RarityDataModule.GetRandomMaterial()
	end
	creatureData.PartsMaterial = partsMaterial

	--make genes parts dynamic
	local genes={}
	for _, gene in pairs(GeneDataModule.TypeOfGene) do
		genes[gene] = ""
	end
	genes["Wing"] = "rbxassetid://7787736329"
	creatureData.Genes = genes

	creatureData.Rating = RarityDataModule:CalculateCreatureRarity(creatureData)
	
	CreaturesCollection[creatureID] = creatureData
	
	PlayerDataModule:Set(player, CreaturesCollection, "CreaturesCollection")

	PlayerDataModule:Increment(player, 1, "TotalNumberOfCreatures")

	CreatureEvolutionModule.IncrementNumberOfRace(player, creatureData.Race, creatureData.CreatureType, 1)

	return creatureData
end
RemoteFunction.FirstTimePlayed.CreateCreatureFirstTime.OnServerInvoke = CreateCreatureDataFirstTime

RemoteEvent.ShowHorseUI.OnServerEvent:Connect(function(player, creatureID)
	RemoteEvent.ShowHorseUI:FireClient(player, creatureID)
end)

--[[
	This function allow to player invoke horse given by CreatureID in parameter and setup the data of this horse appaerance and stats.
	(Actually stats not implemented, just make a genes data on horse)
 ]]
function HorsesDataModule.InvokHorsePlayer(player, creatureID, isDestroy)
	--if is destroy, we destroy actual invoked horse and return, else we invoke horse give in parameter
	if isDestroy then
		local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..player.Name)
		if exist then
			if exist.CreatureID.Value == creatureID then
				HorseEvents.SizeRatioChanged:FireClient(player, nil, true)
				HorseLoader:DismountCreature(player)
				HorseLoader:DeLoadCreature(exist, player)
				HorseStatusHandler:SetUpdateStatusCreature(player, false, creatureID)
			end
		end
		return
	end

	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
	local GenesCollection = PlayerDataModule:Get(player, "GenesCollection")

	--before clone Creature, check if its available and/or not a foal
	if CreatureData.InNursery then
		warn("CREATURE IS IN NURSERY CAN'T INVOKE IT")
		return false
	elseif CreatureData.Growth ~= HorsesDataModule.GrowthType.Adult then
		warn("IT'S NOT A ADULT, BABY CAN'T BE INVOKED !")
		return false
	elseif CreatureData["InSelling"] then
		warn("CAN'T INVOKE CREATURE IN SELLING !")
		return false
	end

	local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..player.Name)
	if exist then
		--check if the invoke are the same horse already invoke and do nothing if true
		--[[ if exist.CreatureID.Value == creatureID then
			return true
		end ]]

		-- Check if some Size bonus are available and disable it before invoke another animal (it's allow to setup move and camera properly)
		HorseEvents.SizeRatioChanged:FireClient(player, nil, true)

		--check if player is on invoked horse, if yes he can't invoke another horse
		local rider = exist.HumanoidRootPart:FindFirstChild("Rider")
		if rider then
			if rider.Value then
				ExitHorse(player, exist)
			end
		end
		--alaways dismount before deload creature to properly delete actuel invoked creature
		HorseLoader:DismountCreature(player)
		HorseStatusHandler:SetUpdateStatusCreature(player, false, exist.CreatureID.Value)
		HorseLoader:DeLoadCreature(exist,player)
	end

	local CreatureClone = ReplicatedStorage.SharedSync.Assets.CreaturesModels:FindFirstChild(CreatureData.CreatureType.."Character"):Clone()
	CreatureClone.Name = "Creature_"..player.Name
	CreatureClone.CreatureID.Value = creatureID

	CreatureClone["Wing_Left"].TextureID = CreatureData.Genes["Wing"]
	CreatureClone["Wing_Right"].TextureID = CreatureData.Genes["Wing"]

	if CreatureData.Race == HorsesDataModule.RaceHorse.Celestial then
		CreatureClone["Wing_Left"].Transparency = 0.01
		CreatureClone["Wing_Right"].Transparency = 0.01
	else
		CreatureClone["Wing_Left"].Transparency = 1
		CreatureClone["Wing_Right"].Transparency = 1
	end

	--set for gene data of horse the coressponding base part of horse textures
	for geneID, gene in pairs(CreatureData.Genes) do
		if geneID ~= "Wing" then
			for _, child in pairs(CreatureClone:GetChildren()) do
				if string.lower(child.Name):match(string.lower(geneID)) then
					if gene ~= "" then
						if string.lower(child.Name):match(string.lower("Accessory")) or string.lower(child.Name):match(string.lower("Eye")) then
							child.Transparency = 0.01
						else
							child.Transparency = 0
						end
						if not string.match(child.Name, "Effect") then
							if child:IsA("BasePart") then
								local exist = StockFolder:FindFirstChild(gene):FindFirstChildOfClass("SurfaceAppearance")
								if exist then
									local clone = exist:Clone()
									clone.Parent = child
									print("SURFACE EXIST CLONE IT", gene)
								else
									print("SURFACE NOT EXIST")
									child.TextureID = GenesCollection[gene].TextureID
								end
							end
						else
							child.Transparency = 1
						end
					end
					
					if string.lower(child.Name):match("mane") then
						local t = CreatureData.ManeColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureData.PartsMaterial.Mane
					elseif string.lower(child.Name):match("marking") then
						local t = CreatureData.Color
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureData.PartsMaterial.Marking
					elseif string.lower(child.Name):match("tail") then
						local t = CreatureData.TailColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureData.PartsMaterial.Tail
					elseif string.lower(child.Name):match("socks") then
						local t = CreatureData.SocksColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureData.PartsMaterial.Socks
	
						if CreatureData.Genes.Effect ~= "" then
							local effects =  StockFolder:FindFirstChild(CreatureData.Genes.Effect)
							for _, effect in pairs(effects:GetChildren()) do
								local cloned = effect:Clone()
								cloned.Parent = child.EffectFeet
								cloned.Name = "ParticleEmitter : ".. CreatureData.Genes.Effect
								cloned:SetAttribute("rateEmission", cloned.Rate)
								cloned.Rate = 0
							end
						end
					end
	
					--check if this Part contain Tattoo Texture and check if we need to setup this
					for _, texture in pairs(child:GetChildren()) do
						if texture:IsA("Texture") then
							if CreatureData.Genes[texture.Name] then
								if CreatureData.Genes[texture.Name] ~= "" then
									texture.Texture = GenesCollection[CreatureData.Genes[texture.Name]].TextureID
									texture.Transparency = 0
								end
							end
						end
					end
				end
			end
		end
	end
	
	CreatureClone.Parent = CreaturesFolder
	CreatureClone.PrimaryPart:SetNetworkOwner()
	
	--make a spawn and init horse for player can use it
	local offset = player.Character.HumanoidRootPart.CFrame.LookVector + Vector3.new(5.5,-0.1,0)
	CreatureClone:PivotTo(player.Character.HumanoidRootPart.CFrame --[[ * CFrame.new(offset) ]])
	
	HorseLoader:LoadCreature({CreatureClone, CreatureData})
	CreatureEvolutionModule.MakeEvolution(player, CreatureData.Race, CreatureData.CreatureType)

	-- Check all register accessory on this creature and setup them
	if CreatureData["Accessory"] then
		for _, accessoryId in pairs(CreatureData.Accessory) do
			AccessoryModule.EquippAccessory(player, accessoryId, creatureID, false)
		end
	end

	CreatureClone.PrimaryPart:SetNetworkOwner(player)

	task.spawn(function()
		HorseEffectModule.SummonEffect(CreatureClone)
	end)

	-- Set Last Creature Invoked in player data to auto summon it next connection
	if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
		PlayerDataModule:Set(player, creatureID, "LastCreatureSummoned")
	end
	
	--now when player invoke creature, make auto mount it, we can found function allow to setup properly the creature mount in CharacterAndMountHandler
	ReplicatedStorage.SharedSync.HorseEvents.ActionMount:FireClient(player, CreatureClone, false)

	HorseStatusHandler:SetUpdateStatusCreature(player, true, creatureID)
	--make this to show status maintenance creature after remote function have return to client and reset ui
	task.spawn(function()
		task.wait(.1)
		HorseStatusHandler.CheckHealthStatus(player, creatureID, nil, 0)
	end)

	return true
end

CheckHorseOwnerIsPlayerID.OnServerInvoke = function(player, creatureID)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	if creaturesCollection then
		for targetCreatureId, _ in pairs(creaturesCollection) do
			if targetCreatureId == creatureID then
				return true
			end
		end
	end
	return false
end

RemoteFunction.SearchSurfaceForFusion.OnServerInvoke = function(player, objID)
	if objID ~= "" then
		local item = game.ServerStorage.ServerStorageSync.ShopItemsStorage:FindFirstChild(objID)
		local exist = item:FindFirstChildOfClass("SurfaceAppearance")
		if exist then
			local clone = exist:Clone()
			clone.Parent = workspace
			task.spawn(function()
				task.wait()
				clone:Destroy()
			end)
			return clone
		end
	end
end

RemoteFunction.RenameHorse.OnServerInvoke = function(player, creatureID, rename)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	if creaturesCollection[creatureID] then
		if not creaturesCollection[creatureID]["InSelling"] then
			creaturesCollection[creatureID]["CreatureName"] = rename
			PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
	
			return true
		end
	end

	return false
end

--[[
	This remote function allow detect when player need to change status of lock exp for ths horse id give in parameter
]]
RemoteFunction.CreatureLockEXP.OnServerInvoke = function(player, creatureID)
	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
	if CreatureData then
		CreatureData.LockExp = not CreatureData.LockExp
		PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
		return CreatureData.LockExp
	end

	return "error"
end

--[[
	Remote function send by client when wan't to delete creature with ID give in parameter.
	Server make check if we can delete or not and if okay we adding in data creature the TAG "isDELETE" who allow filter creature deleted without delete data
	if we need to make restor animals.

	Server send popup to player to confirm delete or cancel deleting and client receive result with the same remote function set into HorsesCollectionCoreUI
]]
RemoteFunction.DeleteCreature.OnServerInvoke = function(player, creatureID, creatureName)
	-- Function callback for yes button from popup
	local function CallbackYES()
		local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
		if CreatureData then
			-- Check if creature are not in selling mode (can't delete if creature are in auction house)
			if not CreatureData.InSelling then
				CreatureData["isDELETE"] = true
				PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
				PlayerDataModule:Decrement(player, 1, "TotalNumberOfCreatures")
				
				-- Check genes of creature delete and make it again in gene inventory player
				for geneID, gene in pairs(CreatureData.Genes) do
					GeneDataModule.RemoveGeneFromCreature(player, gene, creatureID, geneID)
				end

				-- Check Accessory creature delete and restore quantity of them into accessory inventory of player
				if CreatureData["Accessory"] then
					for _, accessoryID in pairs(CreatureData.Accessory) do
						AccessoryModule:IncrementItemQuantityInventoryDataBy(player, accessoryID, 1)
					end
				end
				
				-- Destroy invoked creature if exist when deleted
				HorsesDataModule.InvokHorsePlayer(player, creatureID, true)
			else
				BindableEvent.ShowPopupAlert:Fire(
					player,
					"Warning !",
					"You can't delete an animal that is in the auction house.",
					ToolsModule.AlertPriority.Annoucement,
					nil,
					ToolsModule.AlertTypeButton.OK
				)
			end
		end

		-- Send to client delete are successfully
		RemoteFunction.DeleteCreature:InvokeClient(player, true)
	end

	-- Function callback for NO button from popup
	local function CallbackNO()
		-- Send to client action delete are cancel
		RemoteFunction.DeleteCreature:InvokeClient(player, false)
	end

	-- Setup popup with 2 methods for No button and YEs button of popup (confirm and cancel delete animals)
	BindableEvent.ShowPopupAlert:Fire(
		player,
		"Releasing ?",
		"Are you sure you want to delete "..creatureName.." ? \n <font color=\"rgb(255,0,0)\">You will not be able to undo this action !</font>",
		ToolsModule.AlertPriority.Annoucement,
		ToolsModule.AlertTypeButton.NO,
		ToolsModule.AlertTypeButton.YES,
		CallbackNO,
		{},
		CallbackYES,
		{creatureID}
	)
end

--[[
	Specific behavior make for Product Developer purchase InstantGrowthTime. Developer Product can't get custom parameter in function call for purchase in Robux.
	So when player make a purchase of it, we listen when the purchase is finish and we check if match with developer product InstantGrowthTime. If yes, we make
	result of purchase for player, so make creature with ID give go to Adult. If player don't purchase and cancel, we return if purchase success or not to client to make
	good behavior feedback.
]]
InstantGrowthTime.OnServerInvoke = function(player, creatureID)
	local purchaseDown = false
	local Purchased = false

	-- Launch Roblox prompt purchase for developer product InstantGrowthTime
	game:GetService("MarketplaceService"):PromptProductPurchase(player, 1524909964)

	-- Make event who listen when product purchase is Finished
	local co
	co = game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		-- Check the product purchase finish are the player asker and good product id
		if userId == player.UserId and productId == 1524909964 then
			co:Disconnect()
			Purchased = isPurchased
			if isPurchased then
				-- If successful purchase by player we change the growth time value to growth up it
				HorsesDataModule.SetTimeGrowthValueOfCreatureID(player, creatureID, GameDataModule.TimeGrowthHorseGoal + 1)
			end
			purchaseDown = true
		end
	end)

	-- wait purchase event have finish before return to client
	repeat
		task.wait(0.01)
	until purchaseDown

	return Purchased
end

--Allow other server to get AllCreatureRace Table
BindableFunction.GetAllCreatureRace.OnInvoke = function()
	return HorsesDataModule.RaceHorse
end
--Allow other server to get AllCreatureType Table
BindableFunction.GetAllCreatureType.OnInvoke = function()
	return HorsesDataModule.CreatureType
end

game.Players.PlayerRemoving:Connect(function(player)
	--If player removed, search and remove invoked horse
	local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..player.Name)
	if exist then
		HorseStatusHandler:SetUpdateStatusCreature(player, false, exist.CreatureID.Value)
		HorseLoader:DeLoadCreature(exist,player)
	end
end)

InvokHorsePlayer.OnServerInvoke = function(player, creatureID, isDestroy)
	return HorsesDataModule.InvokHorsePlayer(player, creatureID, isDestroy)
end

--[[
	This event allow to client send to other client by this script server, the open menu creature event to show on
	creature the UI Interaction.
	Index are a string to give the submenu of UI Interaction to Open
]]
RemoteEvent.OpenCreatureMenu.OnServerEvent:Connect(function(player, Creature, index, otherCreatureData)
	RemoteEvent.OpenCreatureMenu:FireClient(player, Creature, index, otherCreatureData)
end)

--[[
	This remote event allow to server synchro the visual gene equipped on the invoked creature when play change it in HorseCollectionCoreUI to see instant
	change of gene on creature and not make a invoke on the already invoked creature.
	Function check data and if is surface appearence to make the good apply of genes.
]]
RemoteEvent.UpdateVisualGene.OnServerEvent:Connect(function(player, creatureID, partData, isSurfaceApp)
	local creature = CreaturesFolder:FindFirstChild("Creature_"..player.Name)
	if creature then
		if creature.CreatureID.Value == creatureID then
			local child = creature:FindFirstChild(partData.Name)
			if isSurfaceApp then
				local exist = StockFolder:FindFirstChild(partData.GeneID):FindFirstChildOfClass("SurfaceAppearance")
				if exist then
					local t = child:FindFirstChildOfClass("SurfaceAppearance")
					if t then
						t:Destroy()
					end

					local clone = exist:Clone()
					clone.Parent = child
				end
			else
				child.Transparency = partData.Transparency
				child.TextureID = partData.TextureID
				local t = child:FindFirstChildOfClass("SurfaceAppearance")
				if t then
					t:Destroy()
				end
			end
		end
	end
end)

return HorsesDataModule