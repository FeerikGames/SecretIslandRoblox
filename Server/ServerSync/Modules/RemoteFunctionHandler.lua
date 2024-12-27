local RemoteFunctionHandlerModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

--Require Module
local PlayerDataModule = require("PlayerDataModule")
local GeneDataModule = require("GeneDataModule")
local HorsesDataModule = require("HorsesDataModule")
local TeleportModule = require("TeleportModule")
local ClubDataModule = require("ClubsDataModule")
local AchievementsDataModule = require("AchievementsDataModule")
local QuestsDataModule = require("QuestsDataModule")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")

--[[
	This script module lists all the remotes function that the client needs
	to obtain information that only the server can do. Remote Function allow to make a return value
	for client, unlike Remote Event.
]]

RemoteFunction:WaitForChild("GetHorsesCollection").OnServerInvoke = function(player, nbValue, index, filterChoose, otherPlayer)
	if otherPlayer then
		return PlayerDataModule:GetNbData(otherPlayer, "CreaturesCollection", nbValue, index, filterChoose)
	else
		return PlayerDataModule:GetNbData(player, "CreaturesCollection", nbValue, index, filterChoose)
	end
	--return PlayerDataModule:Get(player, "HorsesCollection")
end

RemoteFunction:WaitForChild("GetGenesCollection").OnServerInvoke = function(player)
	return PlayerDataModule:Get(player, "GenesCollection")
end

RemoteFunction.AuctionHouse:WaitForChild("GetGenesCollectionForAuctionHouse").OnServerInvoke = function(player)
	local folder = game.ServerStorage.ServerStorageSync.ShopItemsStorage
	local genes = {}

	for _, v in pairs(folder:GetChildren()) do
		if v:IsA("Decal") then
			genes[v.Name] = v.Texture
		end
	end

	return genes
end

RemoteFunction:WaitForChild("GiveGeneToHorse").OnServerInvoke = function(player, geneID, creatureID, geneType)
	return GeneDataModule.GiveGeneToCreature(player, geneID, creatureID, geneType)
end

RemoteFunction:WaitForChild("RemoveGeneFromHorse").OnServerInvoke = function(player, geneID, creatureID, geneType)
	return GeneDataModule.RemoveGeneFromCreature(player, geneID, creatureID, geneType)
end

RemoteFunction:WaitForChild("MoveHorsesToNursery").OnServerInvoke = function(player, horseFatherID, horseMotherID, babyName)
	return HorsesDataModule.MoveHorsesToNursery(player, horseFatherID, horseMotherID, babyName)
end

RemoteFunction:WaitForChild("GetAllEnumDataFiltersOf").OnServerInvoke = function(player, nameOfParentEnumData)
	if nameOfParentEnumData == "Horses" then
		return HorsesDataModule.GetAllEnumDataForFilters()
		elseif nameOfParentEnumData == "Genes" then
			return GeneDataModule.GetAllEnumDataForFilters()
		end
	end
	
	RemoteFunction:WaitForChild("GetValueOf").OnServerInvoke = function(player, dataNeed, otherPlayer)
		if otherPlayer then
			return PlayerDataModule:Get(otherPlayer, dataNeed)
		else
			return PlayerDataModule:Get(player, dataNeed)
		end
	end

RemoteFunction:WaitForChild("SetValueOf").OnServerInvoke = function(player, stat, value, otherPlayer)
	if otherPlayer then
		return PlayerDataModule:Set(otherPlayer, value, stat)
	else
		return PlayerDataModule:Set(player, value, stat)
	end
end

RemoteFunction:WaitForChild("SetHorseFavourites").OnServerInvoke = function(player, creatureID)
	return HorsesDataModule.SetHorseFavourites(player, creatureID)
end

RemoteFunction:WaitForChild("GetCodeForPrivateServer").OnServerInvoke = function(privateServerID)
	return TeleportModule.GetCodeForPrivateServer(privateServerID)
end

--### CLUB ###
RemoteFunction.Club:WaitForChild("CreateNewClub").OnServerInvoke = function(player, clubImg, clubName, clubDesc)
	return ClubDataModule.CreateNewClub(player, clubImg, clubName, clubDesc)
end

RemoteFunction.Club:WaitForChild("GetClubData").OnServerInvoke = function(player, clubName)
	return ClubDataModule.GetClub(player, clubName)
end

RemoteFunction.Club:WaitForChild("GetAllClubs").OnServerInvoke = function(player)
	return ClubDataModule.getAllClub()
end

RemoteFunction.Club:WaitForChild("AddNewClubMember").OnServerInvoke = function(player, clubName)
	return ClubDataModule.AddNewMember(player, clubName)
end

RemoteFunction.Club:WaitForChild("RemoveClubMember").OnServerInvoke = function(player, playerIdRemove, clubName, banValue, typeBan)
	return ClubDataModule.DeleteMember(player, playerIdRemove, clubName, banValue, typeBan)
end

RemoteFunction.Club:WaitForChild("ChangeOwnerOfClub").OnServerInvoke = function(player, clubName, newOwnerID, lastOwnerID)
	return ClubDataModule.ChangeOwnerClub(clubName, newOwnerID, lastOwnerID)
end

RemoteFunction.Club:WaitForChild("ChangeAdminOfClub").OnServerInvoke = function(player, clubName, playerID, isAdmin)
	return ClubDataModule.ChangeAdminClub(clubName, playerID, isAdmin)
end

RemoteFunction.Club:WaitForChild("ChangeDescOfClub").OnServerInvoke = function(player, clubName, text)
	return ClubDataModule.ChangeDescClub(clubName, text)
end
--###########

RemoteFunction:WaitForChild("GetAchievements").OnServerInvoke = function(player)
	print(PlayerDataModule:Get(player, "Achievements"))
	return PlayerDataModule:Get(player, "Achievements")
end

RemoteFunction:WaitForChild("GetAchievementsDataStruct").OnServerInvoke = function(player)
	return AchievementsDataModule.GetAchievements()
end

RemoteFunction:WaitForChild("IncrementValueOf").OnServerInvoke = function(player, stat, value)
	-- Check if player have GamePasses X2 currency drop for example Ecus or Feez
	local newValue = value
	if stat == "Ecus" then
		newValue = BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.GoldsX2.ProductID) and value * 2 or value
	elseif stat == "Feez" then
		newValue = BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.FeezX2.ProductID) and value * 2 or value
	end

	PlayerDataModule:Increment(player, newValue, stat)
end

RemoteFunction:WaitForChild("DecrementValueOf").OnServerInvoke = function(player, stat, value)
	 return PlayerDataModule:Decrement(player, value, stat)
end

RemoteFunction:WaitForChild("SetAchievementValueOfStat").OnServerInvoke = function(player, index, stat, value)
	return AchievementsDataModule.SetAchievementValueOfStat(player, index, stat, value)
end

RemoteFunction:WaitForChild("SetQuestValueOfStat").OnServerInvoke = function(player, index, stat, value)
	return QuestsDataModule.SetQuestValueOfStat(player, index, stat, value)
end

RemoteFunction:WaitForChild("SetNetworkOwnerOfPart").OnServerInvoke = function(player, part, OwnerPlayer)
	part:SetNetworkOwner(OwnerPlayer)
	return true
end

-- Check if player have slots available
RemoteFunction:WaitForChild("CheckCreaturesCollectionSlotsAreAvailables").OnServerInvoke = function(player, callPopup)
	local slotsAvailables, nbMaxSlotsAvailables, nbCreatures = PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(player, callPopup)
	return slotsAvailables, nbMaxSlotsAvailables, nbCreatures
end

-- Remote function call for check and valid by server to unlock system of game
RemoteFunction.PurchaseSystemUnlockable.OnServerInvoke = function(player, systemName, showName)
	local systemObjectOnServerSide = game.Workspace.SystemUnlockable:FindFirstChild(systemName)
	if systemObjectOnServerSide then
		-- System founded on Server Side, check value and make purchase for player call it
		local costUnlock = systemObjectOnServerSide:GetAttribute("CostUnlock")
        local typeCostUnlock = systemObjectOnServerSide:GetAttribute("TypeCostUnlock")

		local function Callback(player)
			local result = PlayerDataModule:Decrement(player, costUnlock, string.match(typeCostUnlock, "Crystal") and "Crystals."..typeCostUnlock or typeCostUnlock)
			if result then
				local systemUnlocked = PlayerDataModule:Get(player, "SystemUnlocked")
				table.insert(systemUnlocked, systemName)
				PlayerDataModule:Set(player, systemUnlocked, "SystemUnlocked")
				RemoteEvent.SystemUnlocked:FireClient(player, systemName)
			else
				warn("Error during purchase system "..systemName.." !")
				BindableEvent.ShowPopupAlert:Fire(
					player,
					"Fail Unlock",
					"You don't have enough "..typeCostUnlock.." ...",
					ToolsModule.AlertPriority.Annoucement,
					nil,
					ToolsModule.AlertTypeButton.OK
				)
			end
		end

		BindableEvent.ShowPopupAlert:Fire(
			player,
			"Unlock ?",
			"Are you sure you want to buy "..showName.." for "..ToolsModule.DotNumber(costUnlock).." "..typeCostUnlock.." ?",
			ToolsModule.AlertPriority.Annoucement,
			ToolsModule.AlertTypeButton.NO,
			ToolsModule.AlertTypeButton.YES,
			nil,nil,
			Callback,
			{player}
		)
	else
		warn("System "..systemName.." not found on Server Side !")
	end
end

RemoteEvent.ActivateFusionSystem.OnServerEvent:Connect(function(player)
	RemoteEvent.ActivateFusionSystem:FireClient(player)
end)

RemoteEvent.UpdateCollectionsUI.OnServerEvent:Connect(function(player, id, itemName)
	RemoteEvent.UpdateCollectionsUI:FireClient(player, id, itemName)
end)

return RemoteFunctionHandlerModule