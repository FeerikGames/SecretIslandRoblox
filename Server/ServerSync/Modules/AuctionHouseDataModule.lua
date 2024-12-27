local AuctionHouseDataModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")
local GameDataModule = require("GameDataModule")

if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
    return AuctionHouseDataModule
end

--To determine the type of data to work on
local dataType = "Test7"
local AUTOSAVE_INTERVAL = 60
local keyAllCreatures = "AllCreatures"

--Setup variables datastore of game
local DataStoreService = game:GetService("DataStoreService")
local AuctionHouseDatastore = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.GameSystem.AuctionHouse.Name..GameDataModule.DatastoreVariables.GameSystem.AuctionHouse.Version)
local PlayerDataModule = require("PlayerDataModule")
local DataManagerModule = require("DataManagerModule")
local GeneDataModule = require("GeneDataModule")
local ToolsModule = require("ToolsModule")
local AccessoryModule = require("AccessoryModule")

local AllCreaturesList = {}
local AuctionHouseCreatureTemp = {}

local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert

--[[
    Initialization of the data cache on the server of the list of Creatures in the sales hotel and the data of each horse
]]
function AuctionHouseDataModule.SetupData()
    local data = AuctionHouseDataModule.LoadAllCreatures()
    if data then
        AllCreaturesList = data
    else
        AllCreaturesList = {}
    end

    if #AllCreaturesList > 1 then
        for id, creatureID in pairs(AllCreaturesList) do
            local data = AuctionHouseDataModule.LoadCreature(creatureID)
            if data then
                if data.IsRemoved then
                    AuctionHouseDatastore:RemoveAsync(creatureID)
                else
                    AuctionHouseCreatureTemp[creatureID] = data
                end
            end
        end
    end
end

--[[
    Allows to load the data of a creature via its Id of the sales hotel directly on the datastore
]]
function AuctionHouseDataModule.LoadCreature(creatureID)
    local data
    local success, err = pcall(function()
        data = AuctionHouseDatastore:GetAsync(creatureID)
    end)

    if not success then
        data = AuctionHouseDataModule.LoadCreature(creatureID)
    end

    return data
end

--[[
    Allows to save and update the data of a horse in the datastore for the sales hotel
]]
function AuctionHouseDataModule.SaveCreature(creatureID)
	local data = AuctionHouseCreatureTemp[creatureID]

	local success, err = pcall(function()
		AuctionHouseDatastore:SetAsync(creatureID, data)
	end)

	if success then
		print("AuctionHousePrint",creatureID.. " data has been saved for auction House!")
	else
		AuctionHouseDataModule.SaveCreature(creatureID)
	end
end

--[[
    Allows you to retrieve the data that lists all the Id of the Creatures available for sale
]]
function AuctionHouseDataModule.LoadAllCreatures()
    local data
    local success, err = pcall(function()
        data = AuctionHouseDatastore:GetAsync(keyAllCreatures)
    end)

    if not success then
        data = AuctionHouseDataModule.LoadAllCreatures()
    end

    return data
end

--[[
    Allows to update the cache data on the server in comparison with the data in the datastore.
    Allows you to manage the content to be displayed for the client list.
]]
function AuctionHouseDataModule.UpdateAllCreatures()
    local success, updatedData = pcall(function()
        --Use updateasync to prevent multiple server access to this data
        return AuctionHouseDatastore:UpdateAsync(keyAllCreatures, function(data)
            local newData = {}
            if data then
                for _, v in pairs(data) do
                    table.insert(newData, v)
                end
            end
            
            for _, v in pairs(AllCreaturesList) do
                if not table.find(newData, v) then
                    table.insert(newData, v)
                end
            end

            return newData
        end)
    end)
    if success then
        print("AuctionHousePrint","Data Auction House AllCreatures Updated")
        AllCreaturesList = updatedData
        --use the new data updated to populate the temp list Creatures and replace last data horse or add new if not here
        --replace it make one by one so, if player check Creatures can see, it's not a pblm
        for _, v in pairs(AllCreaturesList) do
            local data = AuctionHouseDataModule.LoadCreature(v)
            if data then
                if data.IsRemoved then
                    AuctionHouseDatastore:RemoveAsync(v)
                else
                    AuctionHouseCreatureTemp[v] = data
                end
            end
        end
        print("AuctionHousePrint","Data Auction House Creatures LIST Updated")
    end
end

--[[
    This function allows to manage the data transfer of a horse bought by a player.
    We take the data of the horse and we clean the variables that are only used for the sales hotel.
    We change the owner and create the genes if there are any in the inventory of the new owner.
]]
local function CreatureTransfer(player, creatureID, data)
    local CreaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
    if CreaturesCollection then
        if not CreaturesCollection[creatureID] then
            warn("AuctionHousePrint","Player not have this creature, create it from data !")
            --clean data horse not need
            data["InSelling"] = nil
            data["IsBuy"] = nil
            data["SellValue"] = nil
            data["BuyBy"] = nil

            --create horse data into horse collection of new owner
            CreaturesCollection[creatureID] = data

            -- Update TimeObtained by now
            CreaturesCollection[creatureID].TimeObtained = os.time()

            --change owner of horse by new owner and save the history last owner
            CreaturesCollection[creatureID]["ListOfOwners"]["Owner"..DataManagerModule.GetLengthOfDictionnary(CreaturesCollection[creatureID]["ListOfOwners"])] = CreaturesCollection[creatureID]["ListOfOwners"].ActualOwner
            CreaturesCollection[creatureID]["ListOfOwners"].ActualOwner = player.UserId

            PlayerDataModule:Set(player, CreaturesCollection, "CreaturesCollection")

            --Check what genes we need to create and give to horse transfer
            for typeID, geneID in pairs(data.Genes) do
                if typeID ~= "Wing" then
                    if geneID ~= "" then
                        GeneDataModule.CreateGeneFromLegacy(player, geneID, typeID)
                    end
                end
            end

            -- Check accessory of animal and adding into player inventory accessory when it bought
            if data["Accessory"] then
                for _, accessoryID in pairs(data.Accessory) do
                    if not AccessoryModule:CheckItemAreInInventory(player, accessoryID) then
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
    end
end

--[[
    This function is used to check among the Creatures of the player in his collection, if we find one that is marked as for sale,
    we check if it has been sold or not.
    If the horse has been sold, we remove and destroy the current data of the horse in the collection of the player
    and we look at which genes were linked to the horse to reduce the quantity of those.
]]
local function CheckPlayerHaveSellCreatures(player)
    local sellTable = {}
    local CreaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
    if CreaturesCollection then
        for creatureID, creatureData in pairs(CreaturesCollection) do
            --check data horse are marked as  in selling
            if creatureData["InSelling"] then
                local result = AuctionHouseCreatureTemp[creatureID]
                if result then
                    if result.IsBuy then
                        print("AuctionHousePrint",player.Name, "HAVE SELL CREATURE", creatureID)
                        sellTable[result.CreatureName] = result.SellValue
                        --player have sell is horse, so we give money win by the selling
                        local r = PlayerDataModule:Increment(player, result.SellValue, "Ecus")
                        if not r then
                            warn("AuctionHousePrint","Error during increment process Evus after check creature sell")
                        end

                        --check if without this block we have again the pblm with synchro buyed horse and check selling horse with last owner on other server
                        --[[ local success, removedValue, keyInfo = pcall(function()
                            return AuctionHouseDatastore:RemoveAsync(data.Name)
                        end)
                        if not success then
                            print("AuctionHousePrint","Remove FAIL", data.Name, player.Name)
                        end ]]

                        --Remove and decrement quantity gene of horse because it's sell with horse so player can't keep them
                        for geneID, gene in pairs(creatureData.Genes) do
                            if gene ~= "" then
                                GeneDataModule.RemoveGeneFromCreature(player, gene, creatureID, geneID, true)
                            end
                        end

                        --table.remove(AllCreaturesList, table.find(AllCreaturesList, data.Name))
                        PlayerDataModule:Set(player, nil, "CreaturesCollection."..creatureID)
                        AuctionHouseCreatureTemp[creatureID] = nil
                    end
                end
            end
        end

        --here we check if sell table have content to show player selling successfull
        if DataManagerModule.GetLengthOfDictionnary(sellTable) > 0 then
            local stringMsg = ""
            --concatenate string with all sale success
            for i, v in pairs(sellTable) do
                if stringMsg ~= "" then
                    stringMsg = stringMsg.."\n"
                end

                stringMsg = stringMsg.."You sold "..i.." for "..v.." Ecus, congratulations!"
            end
            
            --fire a showing popup with info on the screen to informe player he have sale Creatures
            ShowPopupBindableEvent:Fire(
                player,
                "Successful Creatures Sale",
                stringMsg,
                ToolsModule.AlertPriority.Annoucement,
                nil,
                ToolsModule.AlertTypeButton.OK
            )
        end
    end
end

--[[
    When a player is connected, we check if this player have sale some Creatures
]]
local function playerAdded(player)
    CheckPlayerHaveSellCreatures(player)
end

local function Update()
    print("AuctionHousePrint","Auto-Update data for AuctionHouse Creatures starting")
    AuctionHouseDataModule.UpdateAllCreatures()
    for _, plr in pairs(game.Players:GetPlayers()) do
        CheckPlayerHaveSellCreatures(plr)
    end
    print("AuctionHousePrint","Auto-Update data for AuctionHouse Creatures ending")
end

--[[
    This function allow to launch every time define the update of chace data in server for Auction House.
]]
local function autoUpdate()
	while task.wait(AUTOSAVE_INTERVAL) do
        Update()
	end
end

--[[
    This method allows to verify and validate the purchase of a horse by a player.
    We check in the data stored in the datastore if the horse is still available for purchase or not.
    If yes, we lock the data of the horse with "BuyBy" which contains the id of the player and allows to say
    that this player just bought the horse. If not, we tell the player that the purchase failed, why and we update
    the information on the server's cache data to save calls to the datastore.
]]
function AuctionHouseDataModule.BuyCreature(player, creatureID, parent)
    -- Check if player have slots available
    local slotsAvailables = PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(player, true)
    if not slotsAvailables then
        -- Cancel with return and do nothing because no slot available
        return false
    end

    local res = true
    local success, updatedData = pcall(function()
        --check data on datastore with updateasync
        return AuctionHouseDatastore:UpdateAsync(creatureID, function(data)
            if data then
                --check if horse are removed or not
                if data["IsRemoved"] then
                    print("AuctionHousePrint","DATA IS REMOVED BY OWNER, NO CREATURE")
                    return nil
                end

                --check if creature are already buy or not and if player can buy it
                if not data.IsBuy and PlayerDataModule:Get(player, "Ecus") >= AuctionHouseCreatureTemp[creatureID].SellValue then
                    --player can buy horse, we lock this horse data for this player to prevent other buy players
                    print("AuctionHousePrint","WAIT TO SEE IF HORSE IS BUY")
                    --lock in data server
                    AuctionHouseCreatureTemp[creatureID]["BuyBy"] = player.UserId
                    AuctionHouseCreatureTemp[creatureID].IsBuy = true

                    --lock in datastore
                    data.IsBuy = true
                    data["BuyBy"] = player.UserId

                    return data
                else
                    --here we check if player can't buy it's because already buy or if not have money to buy it
                    if data.IsBuy then
                        warn("AuctionHousePrint","CREATURE ALREADY BUYED CHECK FROM STORE !")
                        RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                            player,
                            "Already bought",
                            "This creature has already been purchased, sorry.",
                            true,
                            parent
                        )
                        AuctionHouseCreatureTemp[creatureID].IsBuy = true
                        res = true
                    else
                        warn("AuctionHousePrint","YOU DON'T HAVE ECUS NEED TO BUY THIS CREATURE")
                        RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                            player,
                            "Not enough money",
                            "You don't have enough Ecus to buy this creature!",
                            true,
                            parent
                        )
                        res = false
                    end
                    return data
                end
            end
        end)
    end)
    if success then
        print("AuctionHousePrint","SEE UPDATED DATA", updatedData)
        if updatedData then
            if updatedData["BuyBy"] == player.UserId then
                warn("AuctionHousePrint","BUY CREATURE SUCCESSFUL, GOODJOB !")
                RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                    player,
                    "Successful purchase",
                    "Congratulations, you got a new creature, take care of it!",
                    true,
                    parent
                )

                local result = PlayerDataModule:Decrement(player, updatedData.SellValue, "Ecus")
                if not result then
                    warn("AuctionHousePrint","Error during decrement process after buy creature")
                end
                CreatureTransfer(player, creatureID, updatedData)
            else
                warn("AuctionHousePrint","BUY CREATURE FAILED, ALREADY BUY BY OTHER PLAYER !")
            end
        else
            RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                player,
                "No longer exists",
                "This creature has just been removed, sorry.",
                true,
                parent
            )
            AuctionHouseCreatureTemp[creatureID] = nil
        end

        return res
    end
end

--[[
    This method is called when the client wants to sell a horse. It takes as parameter the id of the horse to sell,
    its price and the tax to deduct from the player for the sale.
    if the information is valid, we create temporary data to identify the horse put
    on sale, we update the horse in the data of the player and the datastore.
]]
function AuctionHouseDataModule.SellCreature(player, creatureID, sellValue, taxe)
    print("AuctionHousePrint",player.UserId, "SELL FOR", sellValue, creatureID)
    local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
    if CreatureData then
        --if not in selling we can make sell horse (check it because client hack can be try to show client button to try sell horse already sell)
        if not CreatureData["InSelling"] then
            --we take the coast of taxe for place horse into auction house
            local result = PlayerDataModule:Decrement(player, taxe, "Ecus")
            if not result then
                warn("AuctionHousePrint","Error during decrement process after buy creature")
                return false
            end
            
            --make data to identify specifique case in auction house
            CreatureData["InSelling"] = true
            CreatureData["SellValue"] = sellValue
            CreatureData["IsBuy"] = false
    
            --set actual owner if not already set (for last data)
            if not CreatureData["ListOfOwners"].ActualOwner then
                CreatureData["ListOfOwners"].ActualOwner = player.UserId
            end
    
            --we save new data horse selling into server cache data
            AuctionHouseCreatureTemp[creatureID] = CreatureData
            --we save new data for this horse into player data
            PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
            
    
            --save data horse placed into auction house into datastore
            table.insert(AllCreaturesList, creatureID)
            AuctionHouseDataModule.SaveCreature(creatureID)
            return true
        end
    end
end

--[[
    This remote function allow to check when client click on buy button.
    We have 2 behavior :
        - It's a buy button : We check in server cache data if player can buy it or not.
        - It's a remove button : We check it's a owner of horse who need to remove horse from auction house and make
        check to see in data if not already buy. If not bought, we lock this horse as removed and update data server and datastore to
        prevent duplicata of horse.
    This remote function return true or false to say at the client if it update or not on the client side the search result list Creatures.
]]
RemoteFunction.AuctionHouse.BuyHorse.OnServerInvoke = function(player, creatureID, isRemove, parent)
    if not AuctionHouseCreatureTemp[creatureID] then
        RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
            player,
            "No longer exists",
            "This creature has just been removed, sorry.",
            true,
            parent
        )
        return true
    end

    --if player is the owner we check if he try to buy or remove
    if AuctionHouseCreatureTemp[creatureID].ListOfOwners.ActualOwner == player.UserId then
        if isRemove then
            --when player qnat remove horse we check if not already buy from cache data server
            if AuctionHouseCreatureTemp[creatureID].IsBuy then
                RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                    player,
                    "Can't Remove Creature",
                    "This creature has just been purchased.",
                    true,
                    parent
                )
                return true
            end

            --and we check from datastore with update to prevent multiple server access
            local success, updatedData = pcall(function()
                return AuctionHouseDatastore:UpdateAsync(creatureID, function(data)
                    --if not buy so player owner can remove it
                    if not data.IsBuy then
                        --lock with data removed
                        data["IsRemoved"] = true
                        print("AuctionHousePrint","DATA IS REMOVED BY OWNER")
                    end
                    return data
                end)
            end)

            if success then
                if not updatedData["IsRemoved"] then
                    RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                        player,
                        "Can't Remove Creature",
                        "This creature has just been purchased.",
                        true,
                        parent
                    )
                    AuctionHouseCreatureTemp[creatureID].IsBuy = true
                    return true
                else
                    --[[ local success, removedValue, keyInfo = pcall(function()
                        return AuctionHouseDatastore:RemoveAsync(creatureID)
                    end) ]]
                    --if success to remove and we found the removed data we make a remove from list and cache data server, the last updateasync have already update data of remove
                    table.remove(AllCreaturesList, table.find(AllCreaturesList, creatureID))
                    AuctionHouseCreatureTemp[creatureID] = nil
        
                    --here we check in player Creatures collection where is horse and remove auction house temp data for valid removed
                    local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
                    if CreatureData then
                        CreatureData.InSelling = nil
                        CreatureData.SellValue = nil
                        CreatureData.IsBuy = nil
                    end
                    PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)

                    print("AuctionHousePrint","Creature Remove from Auction House and restore into CreaturesCollection")
                    RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                        player,
                        "Creature Removed",
                        "You are sucessfully remove creature from auction house.",
                        true,
                        parent
                    )
                end
            end
        else
            warn("AuctionHousePrint","The seller cannot buy his own creature!")
            RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
                player,
                "Impossible Purchase",
                "The seller cannot buy his own creature!",
                true,
                parent
            )
        end

        return false
    end

    print("AuctionHousePrint","CHECK IF ALREADY BUY", AuctionHouseCreatureTemp[creatureID].IsBuy)
    if AuctionHouseCreatureTemp[creatureID].IsBuy then
        warn("AuctionHousePrint","CREATURE ALREADY BUY SORRRY")
        RemoteEvent.AuctionHouse.ShowInfoFrame:FireClient(
            player,
            "Too Late",
            "This creature has already been purchased, sorry.",
            true,
            parent
        )
    else
        return AuctionHouseDataModule.BuyCreature(player, creatureID, parent)
    end

    return true
end

--[[
    This remote function allow client to get data cach server for populate list filter by client and show Creatures
]]
RemoteFunction.AuctionHouse.GetHorseInSelling.OnServerInvoke = function()
    return AuctionHouseCreatureTemp
end

--[[
    this remote function allow client to call SellCreature Function on server side
]]
RemoteFunction.AuctionHouse.SellHorse.OnServerInvoke = AuctionHouseDataModule.SellCreature

RemoteEvent.AuctionHouse.ChangeCameraPlayer.OnServerEvent:Connect(function(player)
    RemoteEvent.AuctionHouse.ChangeCameraPlayer:FireClient(player)
end)

game.Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(game.Players:GetPlayers()) do
    playerAdded(player)
end

task.wait(2)

--this allow to init data cache at the start server
AuctionHouseDataModule.SetupData()

--Initialize autoupdate loop
task.spawn(autoUpdate)

--When server going to close, make a last update of server to save properly new data auction house
game:BindToClose(function()
	task.wait(1)
    print("Server closing, launch save Auction House")
    Update()
end)

return AuctionHouseDataModule