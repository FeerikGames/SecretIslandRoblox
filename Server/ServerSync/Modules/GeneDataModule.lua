local GeneDataModule = {
	--IMPORTANT RULE OF NAME if another element contain part of another name, place it before it ! Exemple ManeTattoo before Mane
	TypeOfGene = {
		--"EarAccessory",
		--"TailAccessory",
		"Marking",
		"Mane",
		"Tail",
		"Socks",
		"Wing",
		"Eye",
		"Effect",
		"Job",
		"MarkingTattoo1",
		"MarkingTattoo2",
		"ManeTattoo1",
		"ManeTattoo2",
		"TailTattoo1",
		"TailTattoo2",
	}
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction

--Require Module
local DataManagerModule = require("DataManagerModule")
local PlayerDataModule = require("PlayerDataModule")
local RarityDataModule = require("RarityDataModule")
local ServerStorage = game.ServerStorage.ServerStorageSync

--Bindable function
local GetStockItemsServer = BindableFunction.GetStockItemsServer
local GetStockItemDataServer = BindableFunction.GetStockItemDataServer

--Events
local BE_AchievementProgress = BindableEvent.AchievementProgress
local GetTypeOfGenes = Instance.new("RemoteFunction", RemoteFunction)
GetTypeOfGenes.Name = "GetTypeOfGenes"
local GetTypeOfJobGenes = Instance.new("RemoteFunction", RemoteFunction)
GetTypeOfJobGenes.Name = "GetTypeOfJobGenes"

local RarityValue = {
	"Common",
    "Uncommon",
    "Rare",
    "UltraRare",
    "Legendary"
}

GetTypeOfGenes.OnServerInvoke = function()
	return GeneDataModule.TypeOfGene
end
GetTypeOfJobGenes.OnServerInvoke = function()
	return GeneDataModule.TypeOfJobGene
end

function GeneDataModule.GetAllEnumDataForFilters()
	local t = {}
	--remove all tattoo emplacement from list filter and make juste Tattoo to odentifiy all gene type tattoo
	for _, v in pairs(GeneDataModule.TypeOfGene) do
		if not v:match("Tattoo") then
			table.insert(t, v)
		end
	end
	table.insert(t, "Tattoo")

	local dic = {
		Rarity = RarityValue;
		Type = t;
	}
	return dic
end

--[[
	Create or update a gene data give in parameter by obj and obj parent info when player buy gene with shop module.
]]
function GeneDataModule:CreateGeneFromObjectShop(player, obj)
	local genesCollection = PlayerDataModule:Get(player, "GenesCollection")
	--check if already exist or not in genes collection
	if not genesCollection[obj.Name] then
		local typeGene = ""
		for index, value in pairs(GeneDataModule.TypeOfGene) do
			if string.lower(obj.Name):match(string.lower(value)) then
				typeGene = GeneDataModule.TypeOfGene[index]
				break
			elseif string.lower(obj.Name):match(string.lower("Tattoo")) then
				--Tattoo texture is specific because Tattoo can put on any type of gene tattoo because it's indicate emplacement tattoo, so name it Tattoo
				--and the behavior of code with gene use Tattoo for only setup texture with this specific case
				typeGene = "Tattoo"
				break
			end
		end
		
		local GeneData = {
			DisplayName = obj.Parent.DisplayName.Value,
			Quantity = 1,
			Rarity = obj.Parent.Rarity.Value,
			ImageID = obj.Parent.ImageID.Value,
			TextureID = obj.Texture,
			Type = typeGene,
			NbUsed = 0
		}

		genesCollection[obj.Name] = GeneData

		PlayerDataModule:Set(player, genesCollection, "GenesCollection")
		--DataManagerModule.convertDictionaryToFolders(GeneData, geneFolder)
		
		BE_AchievementProgress:Fire(player, "Achievement2", 1)
	else
		--already exist increment quantity
		PlayerDataModule:Increment(player, 1, "GenesCollection."..obj.Name..".Quantity")
		PlayerDataModule:Set(player, obj.Parent.DisplayName.Value, "GenesCollection."..obj.Name..".DisplayName")
	end
	print("TEST GENE BUY", obj)
end

--[[
	This method is called to give a gene to a horse with the parameters the player asked, gene id and horse id.
	To give gene, we check if gene id and horse id exist and check if another same type of gene is equipped.
	Check and manage the quantity and disponibility of gene to allow or not to give gene asked.
]]
function GeneDataModule.GiveGeneToCreature(player, geneID, creatureID, geneType)
	local genesCollection = PlayerDataModule:Get(player, "GenesCollection")
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")

	local gene = genesCollection[geneID]
	local creature = creaturesCollection[creatureID]
	
	print(gene)
	print(creature)
	
	if gene then
		if creature then
			local lastGeneEquiped = creature.Genes[geneType]

			-- If not lastGeneEquiped it's maybe new slot gene not set in data animal (if already slot setup lastGeneEquiped are equal to "", if nil it's not exist)
			if not lastGeneEquiped then
				-- So we verify if genetype are a good genetype with table of typeOfGene and if yes we apply new data slot for animal (update gene data animal)
				if table.find(GeneDataModule.TypeOfGene, geneType) then
					creature.Genes[geneType] = ""
					lastGeneEquiped = creature.Genes[geneType]
				end
			end

			--Check not already equipped
			if lastGeneEquiped ~= geneID then
				--Check if gene are disponible to equip it
				if gene.Quantity - gene.NbUsed > 0 then
					creature.Genes[geneType] = geneID
					gene.NbUsed += 1
					
					--If last gene exist, release this nb used for allow to equipp it on another horse
					if lastGeneEquiped ~= "" then
						lastGeneEquiped = genesCollection[lastGeneEquiped]
						lastGeneEquiped.NbUsed -= 1
					end

					--update rarity of creature after set new gene
					creature.Rating = RarityDataModule:CalculateCreatureRarity(creature)

					PlayerDataModule:Set(player, genesCollection, "GenesCollection")
					PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
					return true
				end
			end
		end
	end
	
	print("GENE NOT GIVEN")
	return false
end

function GeneDataModule.RemoveGeneFromCreature(player, geneID, creatureID, geneType, isDestroy)
	local genesCollection = PlayerDataModule:Get(player, "GenesCollection")
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")

	local gene = genesCollection[geneID]
	local creature = creaturesCollection[creatureID]
	
	if gene then
		if creature then
			local lastGeneEquiped = creature.Genes[geneType]
			--Check gene equipped is the removed gene
			if lastGeneEquiped == geneID then
				creature.Genes[geneType] = ""
				gene.NbUsed -= 1

				if isDestroy then
					gene.Quantity -= 1
				end

				--update rarity of creature after remove gene
				creature.Rating = RarityDataModule:CalculateCreatureRarity(creature)

				PlayerDataModule:Set(player, genesCollection, "GenesCollection")
				PlayerDataModule:Set(player, creaturesCollection, "CreaturesCollection")
				
				return true
			end
		end
	end
	
	print("REMOVE GENE NOT ACHIEVE")
	return false
end

function GeneDataModule.CreateGeneFromLegacy(player, geneName, type)
	if geneName == "" then
		return
	end
	local genesCollection = PlayerDataModule:Get(player, "GenesCollection")
	local StockReference = GetStockItemDataServer:Invoke()
	local Stock = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage")
	--check if already exist or not in genes collection
	if not genesCollection[geneName] then
		local dataItem = StockReference[geneName]

		if string.lower(type):match("tattoo") then
			type = "Tattoo"
		end

		local GeneData = {
			DisplayName = dataItem.DisplayName,
			Quantity = 1,
			Rarity = dataItem.Rarity,
			ImageID = dataItem.ImageID,
			TextureID = Stock[dataItem.ItemName].Texture,
			Type = type,
			NbUsed = 1
		}

		genesCollection[geneName] = GeneData

		print("GENE CREATED", geneName, dataItem.Rarity)
	else
		--already exist increment quantity
		genesCollection[geneName].Quantity += 1
		genesCollection[geneName].NbUsed += 1
		print("ALREADY EXIST, INCREMENTED", geneName)
	end

	PlayerDataModule:Set(player, genesCollection, "GenesCollection")
end

--[[
	This Remote function allow to return ImageID of geneID give in parameter by checking the stock data of the game.
	This remote is call by CharacterAndMountHandler when it's other creature to setup image of genes creature in UI.
]]
RemoteFunction.GetImageOfGeneID.OnServerInvoke = function(player, geneID)
	local StockReference = GetStockItemDataServer:Invoke()
	if StockReference then
		local dataItem = StockReference[geneID]
		return dataItem.ImageID
	end

	return ""
end

return GeneDataModule