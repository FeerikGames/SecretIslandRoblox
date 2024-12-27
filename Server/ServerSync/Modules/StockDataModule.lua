local StockDataModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage").ServerStorageSync
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

--To determine the type of data to work on
local dataType = "Test3"

local HTTPService = game:GetService("HttpService")

--Require Modules
local DataManagerModule = require("DataManagerModule")
local RarityDataModule = require("RarityDataModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEventFolder = ReplicatedStorage.SharedSync.BindableEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local SendStockItemDataEvent = Instance.new("RemoteFunction", RemoteFuncFolder)
SendStockItemDataEvent.Name = "SendStockItemDataEvent"
local GetStockItemData = Instance.new("RemoteFunction", RemoteFuncFolder)
GetStockItemData.Name = "GetStockItemData"
local SaveStockItemData = Instance.new("RemoteFunction", RemoteFuncFolder)
SaveStockItemData.Name = "SaveStockItemData"
local GetDataOf = Instance.new("RemoteFunction", RemoteFuncFolder)
GetDataOf.Name = "GetDataOf"
local SaveDataOf = Instance.new("RemoteFunction", RemoteFuncFolder)
SaveDataOf.Name = "SaveDataOf"
local GetSpeciesOfItem = Instance.new("RemoteFunction", RemoteFuncFolder)
GetSpeciesOfItem.Name = "GetSpeciesOfItem"
local GetTextureIDOfItem = Instance.new("RemoteFunction", RemoteFuncFolder)
GetTextureIDOfItem.Name = "GetTextureIDOfItem"

--Bindable function for other module need to use this function
local GetStockItemsServer = BindableFunction.GetStockItemsServer
local GetStockItemDataServer = BindableFunction.GetStockItemDataServer

local ClientAskServerObjStorage = Instance.new("RemoteEvent", RemoteEventFolder)
ClientAskServerObjStorage.Name = "ClientAskServerObjStorage"
local ShowItemInViewPort = Instance.new("RemoteEvent", RemoteEventFolder)
ShowItemInViewPort.Name = "ShowItemInViewPort"

local UpdateShopItems = BindableEventFolder:WaitForChild("UpdateShopItems")

--Setup variables datastore of game
local DataStoreService = game:GetService("DataStoreService")
local StockItemsDatastore = DataStoreService:GetDataStore("StockItems"..dataType)

local StockItemsDataSession = {}

-- Check if we found folder in Descendants and change children of folder in first folder storage reference (allow to artist make good structure when adding new items and for project are more speed to find this object)
for _, child in pairs(game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):GetDescendants()) do
    if child:IsA("Folder") and not child:GetAttribute("IsSetting") then
        for _, v in pairs(child:GetChildren()) do
            v.Parent = game.ServerStorage.ServerStorageSync.ShopItemsStorage
        end
        child:Destroy()
    end
end
local StorageItemsData = game.ServerStorage.ServerStorageSync.ShopItemsStorage:GetChildren()

function GetDataStorageItems()
    local data = {}
    for _, obj in pairs(StorageItemsData) do
        table.insert(data, obj.Name)
    end
    return data
end

GetStockItemsServer.OnInvoke = GetDataStorageItems
SendStockItemDataEvent.OnServerInvoke = GetDataStorageItems

--This event call by client allow to give it the attributes Species to check object gene creature type autorized to use it.
GetSpeciesOfItem.OnServerInvoke = function(plr, objID)
    local obj = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):FindFirstChild(objID)
    return obj:GetAttribute("Species")
end

GetTextureIDOfItem.OnServerInvoke = function(plr, objID)
    local obj = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):FindFirstChild(objID)
    return obj.Texture
end

ShowItemInViewPort.OnServerEvent:Connect(function(player, itemID, parent)
    for _, child in pairs(StorageItemsData) do
        if child.Name == itemID then
            local clone = child:Clone()
            clone.Name = itemID
            clone.Parent = parent
            break
        end
    end
end)

--[[
    Method is from admin store manage to allow admin client access and show element from storage server side
]]
ClientAskServerObjStorage.OnServerEvent:Connect(function(player, objID)
    local playerGui = player:WaitForChild("PlayerGui")
    local ItemEdit = playerGui.StarterGuiSync.ShopItemsGui.StockItemsFrame.ItemEdit
    local viewport = ItemEdit.ItemDetails.ViewportFrame

    for _, child in pairs(StorageItemsData) do
        if child.Name == objID then
            if child:IsA("Decal") then
                local exist = viewport:GetChildren()
                if exist then
                    for _, v in pairs(exist) do
                        if not v:IsA("ImageLabel") then
                            v:Destroy()
                        end
                    end
                end
                viewport.ImageLabel.Image = child.Texture
                viewport.ImageLabel.Visible = true
            else
                local exist = viewport:GetChildren()
                if exist then
                    for _, v in pairs(exist) do
                        if not v:IsA("ImageLabel") then
                            v:Destroy()
                        end
                    end
                end
                viewport.ImageLabel.Visible = false

                local clone = child:Clone()
                clone.Parent = ItemEdit.ItemDetails.ViewportFrame
                local target
                if clone:IsA("Model") then
                    target = clone.PrimaryPart
                else
                    target = clone
                end

                local viewportCamera = Instance.new("Camera")
                viewport.CurrentCamera = viewportCamera
                viewportCamera.Parent = viewport
                local cameraOffset = Vector3.new(0, 5, 6)
                viewportCamera.Focus = target.CFrame
                local rotatedCFrame = CFrame.Angles(0, 0, 0)
                rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
                viewportCamera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
                viewportCamera.CFrame = CFrame.new(viewportCamera.CFrame.Position, target.Position)
                break
            end
        end
    end
end)

GetDataOf.OnServerInvoke = function(player, dataType)
    if dataType == "Categorie" then        
        return StockDataModule.LoadCategorieShop()
    elseif dataType == "ObjectType" then
        return StockDataModule.LoadObjectTypeShop()
    end
end
SaveDataOf.OnServerInvoke = function(player, dataName, data, action, dataType)
    local newData = {}

    if dataType == "Categorie" then
        newData = StockDataModule.LoadCategorieShop()
    elseif dataType == "ObjectType" then
        newData = StockDataModule.LoadObjectTypeShop()
    end

    if newData then
        if action == "delete" then
            if newData[dataName] then
                newData[dataName] = nil
            end

            local result
            if dataType == "Categorie" then
                result = StockDataModule.SaveCategorieShop(newData)
            elseif dataType == "ObjectType" then
                result = StockDataModule.SaveObjectTypeShop(newData)
            end

            UpdateShopItems:Fire()
            return result

        elseif action == "check" then
            -- Check if item already exist or not
            return newData[dataName] and false or true

        elseif action == "save" then
            newData[dataName] = data
            local result
            if dataType == "Categorie" then
                result = StockDataModule.SaveCategorieShop(newData)
            elseif dataType == "ObjectType" then
                result = StockDataModule.SaveObjectTypeShop(newData)
            end
            UpdateShopItems:Fire()
            return result
        end
    end
end

GetStockItemData.OnServerInvoke = function(player, itemID)
    return StockItemsDataSession[itemID]
    --return StockDataModule.LoadStockItem(itemID)
end

GetStockItemDataServer.OnInvoke = function(itemID)
    if itemID then
        return StockDataModule.LoadStockItem(itemID)
    else
        return StockItemsDataSession
    end
end

SaveStockItemData.OnServerInvoke = function(player, itemID, itemDatas)
    --make a verification of integrity of type data in serverr side before to save it the StockItemsDataSession
    --all data send are a string, but some date need to be a number so check it here
    for index, value in pairs(itemDatas) do
        if index == "DateEndAvailable" or index == "DateEndPromo" or index == "DateStartAvailable" or index == "DateStartPromo" or index == "Price" or index == "Promo" or index == "QuantityMaxByPlayer" then
            if typeof(value) ~= "number" then
                if value == "" then
                    itemDatas[index] = 0
                else
                    itemDatas[index] = tonumber(value)
                end
            end
        end
    end
    StockItemsDataSession[itemID] = itemDatas
    local result = StockDataModule.SaveStockItem(itemID, itemDatas)
    if result then
        if itemDatas.AvailableInShop then
            --Create and make object into shop
            CreateObjectShopData(itemID, itemDatas)
        else
            DestroyObjectShopData(itemID, true)
        end
    end
end

function DestroyObjectShopData(itemID, update)
    --print("REMOVE OBJECT IN SHOP")
    local shopFolder = game.ServerStorage.ServerStorageSync:WaitForChild("ShopItems")
    for _, cat in pairs(shopFolder:GetChildren()) do
        for _, obj in pairs(cat:GetChildren()) do
            if obj.Name == itemID then
                obj:Destroy()
                if update then
                    UpdateShopItems:Fire()
                end
                return
            end
        end
    end
end

function CreateFolderItemDataForShop(itemID, itemDatas)
    DestroyObjectShopData(itemID, false)
    --print("CREATE OBJECT FOR SHOP")
    local folderItem = Instance.new("Folder")
    folderItem.Name = itemID
    for index, value in pairs(itemDatas) do
        if index == "Items" then
            local folderContainer = Instance.new("Folder")
            folderContainer.Name = "Items"
            folderContainer.Parent = folderItem
            for i, name in pairs(value) do
                local val = Instance.new("StringValue")
                val.Name = "Item"..i
                val.Value = name
                val.Parent = folderContainer
            end
        else
            local val
            if typeof(value) == "string" then
                val = Instance.new("StringValue")
            elseif typeof(value) == "boolean" then
                val = Instance.new("BoolValue")
            elseif typeof(value) == "number" then
                val = Instance.new("NumberValue")
            end
            val.Name = index
            val.Value = value
            val.Parent = folderItem
        end
    end

    return folderItem
end

function CreateObjectShopData(itemID, itemDatas)
    local folderItem = CreateFolderItemDataForShop(itemID, itemDatas)
    --search object part in stock to clone it into folder shop
    for _, child in pairs(StorageItemsData) do
        if child.Name == itemID then
            local clone = child:Clone()
            clone.Name = itemID
            clone.Parent = folderItem
        
            local shopFolder = ServerStorage:WaitForChild("ShopItems")
            if not shopFolder:FindFirstChild(itemDatas.ItemCategorie) then
                local catFolder = Instance.new("Folder")
                catFolder.Name = itemDatas.ItemCategorie
                catFolder.Parent = shopFolder
            end
            folderItem.Parent = shopFolder:WaitForChild(itemDatas.ItemCategorie)

            UpdateShopItems:Fire()
            break
        end
    end
end

function LoadInShopAllItemsStockSetup()
    --get list of name objects are in storage
    warn("Start LoadInShopAllItemsStockSetup")
    StockDataModule.LoadStockItems()

    for itemID, itemDatas in pairs(StockItemsDataSession) do
        if itemDatas then
            if itemDatas.AvailableInShop then
                --Create and make object into shop
                CreateObjectShopData(itemID, itemDatas)
            end
        end
    end

    warn("LoadInShopAllItemsStockSetup Init Down", StockItemsDataSession)
end

function SaveLastData()
    warn("Start save last data")
    local temp = {}
    --get list of name objects are in storage
    for _, item in pairs(StorageItemsData) do
        local itemDatas = StockItemsDatastore:GetAsync(item.Name)
        if itemDatas then
            warn("save temp", item.Name)
            temp[item.Name] = itemDatas
        end
    end
    StockItemsDataSession = temp
    StockDataModule.SaveStockItems()
    warn("Save last data DOWN")
end

function StockDataModule:GetItemsForContainerItem(containerItem)
    local items = {}
    for _, obj in pairs(StorageItemsData) do
        for _, itemID in pairs(containerItem.Items) do
            if obj.Name == itemID then
                local itemDatas = StockDataModule.LoadStockItem(itemID)
                local folderItem = CreateFolderItemDataForShop(itemID, itemDatas)
                --folderItem.Parent = workspace
                for _, child in pairs(StorageItemsData) do
                    if child.Name == itemID then
                        local clone = child:Clone()
                        clone.Name = itemID
                        clone.Parent = folderItem
                    end
                end
                items[itemID] = folderItem
                break
            end
        end
    end
    return items
end

function StockDataModule.LoadCategorieShop()
    local data
    local success, err = pcall(function()
        data = StockItemsDatastore:GetAsync("Admin-Categories")
    end)

    if not success then
        data = StockDataModule.LoadCategorieShop()
    end
    return data
end

function StockDataModule.SaveCategorieShop(data)
    local success, err = pcall(function()
        StockItemsDatastore:SetAsync("Admin-Categories", data)
    end)

    if not success then
        StockDataModule.SaveCategorieShop(data)
    else
        print("CATEGORIES DATAS SAVED")
        return true
    end
end

function StockDataModule.LoadObjectTypeShop()
    local data
    local success, err = pcall(function()
        data = StockItemsDatastore:GetAsync("Admin-ObjectType")
    end)

    if not success then
        data = StockDataModule.LoadObjectTypeShop()
    end
    return data
end

function StockDataModule.SaveObjectTypeShop(data)
    local success, err = pcall(function()
        StockItemsDatastore:SetAsync("Admin-ObjectType", data)
    end)

    if not success then
        StockDataModule.SaveObjectTypeShop(data)
    else
        print("OBJECT TYPE DATAS SAVED")
        return true
    end
end

function StockDataModule.LoadStockItems()
    local data
    local success, err = pcall(function()
        data = StockItemsDatastore:GetAsync("ConfiguredItemsDatas")
    end)
    if not success then
        data = StockDataModule.LoadStockItems()
    end

    if data then
        StockItemsDataSession = data
    end
end

function StockDataModule.SaveStockItems()
    local data = StockItemsDataSession

    local success, err = pcall(function()
        StockItemsDatastore:SetAsync("ConfiguredItemsDatas", data)
    end)

    if not success then
        StockDataModule.SaveStockItems()
    end
end

function StockDataModule.LoadStockItem(itemID)
    return StockItemsDataSession[itemID]
end

function StockDataModule.SaveStockItem(itemID, itemDatas)
    if itemID ~= "" then
        StockItemsDataSession[itemID] = itemDatas
        StockDataModule.SaveStockItems()
        return true
    end
end
--SaveLastData()
LoadInShopAllItemsStockSetup()
RarityDataModule:Init()

return StockDataModule
--[[ for i = 1, 500, 1 do
    local item:Decal = Instance.new("Decal", game.ServerStorage.ServerStorageSync.ShopItemsStorage)
    item.Name = "test_perf//:test"..i
end ]]

--[[ local Data = game:GetService("DataStoreService"):GetDataStore("StockItemsTest3")
local suc,dat = pcall(function()
    return Data:GetAsnyc("Effect_StarsRainbow//:50")
end)
print(game:GetService("HttpService"):JSONEncode(dat):len()) ]]