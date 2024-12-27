local ShopItemsModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage").ServerStorageSync
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")
local DataManagerModule = require("DataManagerModule")
local AccessoryModule = require("AccessoryModule")
local StockDataModule = require("StockDataModule")
local GeneDataModule = require("GeneDataModule")

local ShopItemsFolder = ServerStorage:WaitForChild("ShopItems")
local ShopItemsDatas = {}

--Remote Function
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFuncFolder = ReplicatedStorage.SharedSync.RemoteFunction
local BindableEventFolder = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local UpdateClientsShopUI = Instance.new("RemoteEvent", RemoteEvent)
UpdateClientsShopUI.Name = "UpdateClientsShopUI"

local getShopItemsDatas = Instance.new("RemoteFunction", RemoteFuncFolder)
getShopItemsDatas.Name = "GetShopItemsDatas"
local buyShopItemPlayer = Instance.new("RemoteFunction", RemoteFuncFolder)
buyShopItemPlayer.Name = "BuyShopItemPlayer"
local getShopItemsContainer = Instance.new("RemoteFunction", RemoteFuncFolder)
getShopItemsContainer.Name = "GetShopItemsContainer"

local UpdateShopItems = BindableEventFolder:WaitForChild("UpdateShopItems")
local getShopItemData = Instance.new("BindableFunction", BindableFunction)
getShopItemData.Name = "GetShopItemData"

local RarityWeights = {
    Common = 100,
    Uncommon = 50,
    Rare = 25,
    UltraRare = 8,
    Legendary = 2
}

function ConvertFolderDataToDictionnary()
    --Converte folder data for shop items into a dictionnary
    DataManagerModule.convertDataToDictionary(ShopItemsFolder, ShopItemsDatas)
    print("UPDATE SHOP")
    UpdateClientsShopUI:FireAllClients()
end
ConvertFolderDataToDictionnary()

UpdateShopItems.Event:Connect(ConvertFolderDataToDictionnary)

getShopItemsDatas.OnServerInvoke = function(player, categorie)
    if categorie then
        local dataAsk = {}
        dataAsk[categorie] = ShopItemsDatas[categorie]
        return dataAsk
    else
        return ShopItemsDatas
    end
end

getShopItemsContainer.OnServerInvoke = function(player, item)
    local sendToClient = {}
    local items = StockDataModule:GetItemsForContainerItem(item)--GetItemsFromContainerItemType(item)
    for itemID, item in pairs(items) do
        sendToClient[itemID] = {
            Image = item.ImageID.Value,
            Rarity = item.Rarity.Value,
            DisplayName = item.DisplayName.Value or itemID
        }
    end
    for _, item in pairs(items) do
        item:Destroy()
    end
    return sendToClient
end

--[[ 

 ]]
function GetRandomRarityItems(items)
    local randomItems = {}
    local weightNumber = math.random(0,100)
    if weightNumber < RarityWeights.Legendary then
        print("RARITY IS LEGENDARY")
        for _, item in pairs(items) do
            if item.Rarity.Value == "Legendary" then
                table.insert(randomItems, item)
            end
        end
    elseif weightNumber < RarityWeights.UltraRare  then
        print("RARITY IS ULTRA RARE")
        for _, item in pairs(items) do
            if item.Rarity.Value == "UltraRare" then
                table.insert(randomItems, item)
            end
        end
    elseif weightNumber < RarityWeights.Rare  then
        print("RARITY IS RARE")
        for _, item in pairs(items) do
            if item.Rarity.Value == "Rare" then
                table.insert(randomItems, item)
            end
        end
    elseif weightNumber < RarityWeights.Uncommon  then
        print("RARITY IS UNCOMMON")
        for _, item in pairs(items) do
            if item.Rarity.Value == "Uncommon" then
                table.insert(randomItems, item)
            end
        end
    else
        print("RARITY IS COMMON")
        for _, item in pairs(items) do
            if item.Rarity.Value == "Common" then
                table.insert(randomItems, item)
            end
        end
    end
    --print("RANDOM ITEMS",randomItems, #randomItems)
    if #randomItems == 0 then
        return GetRandomRarityItems(items)
    end
    return randomItems
end

--[[ 
    This function can check all items we have in container. A recursive function search into item if we have a container item type
    (random or container) and if we have we check again all items for setup the good list of items player obtains with this purchase store item.
    At the end, the items list is all item player obtain.
 ]]
function GetItemsFromContainerItemType(item)
    local result = StockDataModule:GetItemsForContainerItem(item)
    local items = {}

    local function searchItemsRecursive(result)
        local items = {}
        for _, childItem in pairs(result) do
            --print("ITEM IN RESULT", childItem)
            if childItem:FindFirstChild("Items") then
                --print("CHILD ARE A CONTAINER SO CHECK ITEM OF IT")
                if childItem.ItemType.Value == "ContainerItem" then
                    local r = StockDataModule:GetItemsForContainerItem(StockDataModule.LoadStockItem(childItem.Name))
                    --print("ITEM OF CONTAINER", r)
                    items = searchItemsRecursive(r)
                    for _, other in pairs(r) do
                        items[other.Name] = other
                    end
                    result[childItem.Name] = nil
                elseif childItem.ItemType.Value == "RandomContainerItem" then
                    local r = StockDataModule:GetItemsForContainerItem(StockDataModule.LoadStockItem(childItem.Name))
                    --print("ITEM OF RANDOM CONTAINER", r)
                    local randomItem = GetRandomRarityItems(r)
                    local itemSelected = randomItem[math.random(1, #randomItem)]
                    --print("RANDOM ITEM SELECTED", itemSelected)
                    if itemSelected.ItemType.Value == "ContainerItem" or itemSelected.ItemType.Value == "RandomContainerItem" then
                        items = searchItemsRecursive(r)
                    else
                        items[itemSelected.Name] = itemSelected
                    end
                    result[childItem.Name] = nil
                end
            end
        end
        return items
    end

    items = searchItemsRecursive(result)

    for itemID, itemX in pairs(items) do
        result[itemID] = itemX
    end

    --print("ALL ITEMS FROM CONTAINERS ITEM", result)
    return result
end

--[[ 

 ]]
function CheckQuantityItem(inventoryPlayer, items)
    --now we have item to give player, check if no pblm with object one by one and can't buy if pblm detected
    for itemID, item in pairs(items) do
        --check if player have already this object and quanitty allow for this object are not at the max
        local exist = inventoryPlayer:FindFirstChild(itemID)
        if exist then
            if exist:GetAttribute("StockQuantity") >= item.QuantityMaxByPlayer.Value then
                --quantity max reach so not allow to buy
                return false
            end
        end
    end

    return true
end

--[[
    This function lalow to return true or false for check if a item are in promotion or not to apply the good value at the buy
]]
function CheckPromoIsActive(item)
    local Date = DateTime.now():ToIsoDate()
    Date = string.gsub(Date,"%-", "_")
    Date = string.gsub(Date,"[%s%p%a]+", "_" )
    Date = Date:split("_")

    local ActualDateNumber = tonumber(Date[1]..Date[2]..Date[3])

    if item.DateEndPromo == 0 then
        return false
    else
        if item.DateStartPromo ~= 0 then
            --check if date start correspond with actual date for availble item and is during or not available now
            if ActualDateNumber >= item.DateStartPromo  and ActualDateNumber <= item.DateEndPromo then
                return true
            end
            if ActualDateNumber < item.DateStartPromo then
                return false
            end
        end
    end
end

--[[ 

 ]]
function PayoutBuyItemPlayer(player, item, object)
    --Make a decrement money value and check if all its ok
    local result
    local quantity = 1
    if CheckPromoIsActive(item) then
        result = PlayerDataModule:Decrement(player, quantity * item.Price - (math.round(item.Price*(item.Promo/100))), item.CurrencyType)
    else
        result = PlayerDataModule:Decrement(player, quantity * item.Price, item.CurrencyType)
    end

    if not result then
        warn("Error during decrement process after buy object")
        return false
    end

    return true
end

--[[
    This method increment to the playerData the ressources he paid
]]
function GetRessourceFromItem(player, item, object)
    local PlayerDataDefaultStructure = PlayerDataModule.GetPlayerDataDefaultStructure()
    local ressource

    for index, data in pairs(PlayerDataDefaultStructure) do
        if not ressource then
            ressource = string.match(object.Name, index)
        end
    end
    local quantity = 1
    local nameQuantity = object.Name:match("(%d+)%p")
    if nameQuantity then
        quantity = nameQuantity
    end
    if ressource then
        PlayerDataModule:Increment(player, quantity, ressource)
    else
        warn("Ressource to increment not found in Data struct. check if the ressource exist or if the bought item has the ressource name in its name.")
    end
end

--[[

]]
function CloneObjectIntoInventoryPlayer(player, obj, isExist, inventoryPlayer)
    if obj.Parent:FindFirstChild("ObjectType") then
        if obj.Parent.ObjectType.Value == "Genes" then
            GeneDataModule:CreateGeneFromObjectShop(player, obj)
            return
        end
    end

    if not isExist then
        AccessoryModule:SetNewItemInventoryData(player, obj.Name, 1, obj.Parent.Rarity.Value, obj.Parent.ImageID.Value, obj.Parent.DisplayName.Value, obj)
    else
        AccessoryModule:IncrementItemQuantityInventoryDataBy(player, isExist.Name, 1)
    end
end

--[[ 

 ]]
function BuySingleItem(player, item)
    local inventoryPlayer = player.Backpack
    --check if player have already this object and quanitty allow for this object are not at the max
    local exist = inventoryPlayer:FindFirstChild(item.ItemName)
    if exist then
        if exist:GetAttribute("StockQuantity") >= item.QuantityMaxByPlayer then
            --quantity max reach so not allow to buy
            return false
        end
    end
    --TODO maybe we have to check date start and end again in the server side for sure
    --if all is okay we can take and clone object to give player
    for _, shopCategory in pairs(ShopItemsFolder:GetChildren()) do
        for _, folder in pairs(shopCategory:GetChildren()) do
            if folder.Name == item.ItemName then
                local obj = folder:FindFirstChild(item.ItemName)
                if obj then
                    local result = PayoutBuyItemPlayer(player, item)
                    if not result then
                        return false
                    end

                    if item.ObjectType == "Ressource" then
                        GetRessourceFromItem(player, item, obj)
                    else
                        --if here buy it's ok so make a clone if player don't have already this object or increment stock value of object
                        CloneObjectIntoInventoryPlayer(player, obj, exist, inventoryPlayer)
                    end

                    print(item.ItemName.." BUYED FOR "..item.Price - (math.round(item.Price*(item.Promo/100))).." by "..player.Name)
                    return true
                end
            end
        end
    end

    return false
end

--[[ 

 ]]
function BuyContainerItem(player, item)
    local inventoryPlayer = player.Backpack
    local items = GetItemsFromContainerItemType(item)

    local result = CheckQuantityItem(inventoryPlayer, items)
    if not result then
        return false
    end

    local result = PayoutBuyItemPlayer(player, item)
    if not result then
        return false
    end

    for itemID, item in pairs(items) do
        local exist = inventoryPlayer:FindFirstChild(itemID)
        local obj = item:FindFirstChild(itemID)
        if obj then
            --if here buy it's ok so make a clone if player don't have already this object or increment stock value of object
            CloneObjectIntoInventoryPlayer(player, obj, exist, inventoryPlayer)
        end
    end

    for _, item in pairs(items) do
        item:Destroy()
    end

    return true
end

--[[ 

 ]]
function BuyRandomContainerItem(player, item)
    local inventoryPlayer = player.Backpack
    local items = StockDataModule:GetItemsForContainerItem(item)--GetItemsFromContainerItemType(item)

    local result = CheckQuantityItem(inventoryPlayer, items)
    if not result then
        return false
    end

    local result = PayoutBuyItemPlayer(player, item)
    if not result then
        return false
    end

    --Get all item in random container with the rarity random selected
    local randomItems = GetRandomRarityItems(items)

    --get random item into the random rarity
    local itemSelected = randomItems[math.random(1, #randomItems)]

    --check if random item selected is a container type and if yes, we launch the search function with recursivity for potential container of container
    if itemSelected.ItemType.Value == "ContainerItem" or itemSelected.ItemType.Value == "RandomContainerItem" then
        local convert={}
        DataManagerModule.convertDataToDictionary(itemSelected, convert)
        for itemID, item in pairs(GetItemsFromContainerItemType(convert)) do
            local exist = inventoryPlayer:FindFirstChild(itemID)
            local obj = item:FindFirstChild(itemID)
            if obj then
                --if here buy it's ok so make a clone if player don't have already this object or increment stock value of object
                CloneObjectIntoInventoryPlayer(player, obj, exist, inventoryPlayer)
            end
        end
    --if just a single item, make simply a give to player
    else
        local exist = inventoryPlayer:FindFirstChild(itemSelected.Name)
        local obj = itemSelected:FindFirstChild(itemSelected.Name)
        if obj then
            --if here buy it's ok so make a clone if player don't have already this object or increment stock value of object
            CloneObjectIntoInventoryPlayer(player, obj, exist, inventoryPlayer)
        end
    end

    for _, item in pairs(items) do
        item:Destroy()
    end

    return true
end

--[[
    When player search to buy item this function is call. Check if player can buy with money need by item
    and alaway return if buy proceceed ok or not for client use result and feedback player.
]]
buyShopItemPlayer.OnServerInvoke = function(player, item)
    if item then
        if item.AvailableItem then
            --Check type of item and make about type item the correct function
            if item.ItemType == "SingleItem" then
                return BuySingleItem(player, item)
            elseif item.ItemType == "ContainerItem" then
                return BuyContainerItem(player, item)
            elseif item.ItemType == "RandomContainerItem" then
                return BuyRandomContainerItem(player, item)
            end
        end
    end
    
    return false
end

getShopItemData.OnInvoke = function(accessoryID)
    for _, categorie in pairs(ShopItemsDatas) do
        for itemID, itemData in pairs(categorie) do
            if itemID == accessoryID then
                return itemData
            end
        end
    end
end

RemoteEvent.ShowShopUIForItem.OnServerEvent:Connect(function(player, NameObject)
    RemoteEvent.ShowShopUIForItem:FireClient(player, NameObject)
end)

return ShopItemsModule