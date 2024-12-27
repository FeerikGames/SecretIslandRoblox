local PurchaseStoreModule = {}
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")
local DataManagerModule = require("DataManagerModule")
local GameDataModule = require("GameDataModule")
local ChatTagModule = require("ChatTagModule")
 
local dataType = "Test7"
local AUTOSAVE_INTERVAL = 120
-- Data store for tracking purchases that were successfully processed (its only a way to make sur the process is valid or not if roblox server bug)
local purchaseHistoryStore = DataStoreService:GetDataStore("PurchaseHistory")
local giveHistoryStore = DataStoreService:GetDataStore("GiveHistory".."Test6")
local allPlayersPurchaseProductsHistory = DataStoreService:GetDataStore("PlayersPurchaseProductsHistory"..dataType)
local sessionDataPlayersPurchaseProductsHistory = {}

local ShowPopupBindableEvent = ReplicatedStorage.SharedSync.BindableEvent.ShowPopupAlert

--Exemple of data structure for allPlayersPurchaseProductsHistory datastore
local dataExemple = {
    ["PlayerId"] = {
        ["PurchaseID"] = {
            ["Date"] = "",
            ["ProductID"]=0,
            ["ProductName"]="",
            ["CurrencySpent"]=0,
            ["CurrencyType"]="",
            ["PurchaseSuccess"]=false
        }
    }
}
 
--List of developer products for the game to create all products functions
local developerProducts = MarketplaceService:GetDeveloperProductsAsync():GetCurrentPage()

local gameProducts = {
    [1] = {
        ProductName = "20,000 Ecus",
        Price = 199,
        ImageID = GameDataModule.DailyRewardImage.Ecus.LargeStack,
        ProductType = "Ecus",
        CurrencyType = "Feez",
        CurrencyImageID = GameDataModule.DropCollectables.Feez
    },
    [2] = {
        ProductName = "100,000 Ecus",
        Price = 699,
        ImageID = GameDataModule.DailyRewardImage.Ecus.BigBagStack,
        ProductType = "Ecus",
        CurrencyType = "Feez",
        CurrencyImageID = GameDataModule.DropCollectables.Feez
    },
    [3] = {
        ProductName = "500,000 Ecus",
        Price = 2999,
        ImageID = GameDataModule.DailyRewardImage.Ecus.ChestStack,
        ProductType = "Ecus",
        CurrencyType = "Feez",
        CurrencyImageID = GameDataModule.DropCollectables.Feez
    },
}
 
-- Table setup containing product IDs and functions for handling purchases
local productFunctions = {}
local gameProductFunctions = {}

-- Cache for Gamepass own by player (make this because Roblox make auto cache on function UserOwnsGamePassAsync and we can't know if player have alaway or not the gamepass when check more one time)
local GamepassesPlayersCache = {}

--Create remote to allow player get the list of productsID to make a dynamic UI
local getProductsIDListRemoteFunction = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
getProductsIDListRemoteFunction.Name = "GetProductsIDListRemoteFunction"

local getGameProductsRemoteFunction = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
getGameProductsRemoteFunction.Name = "GetGameProductsRemoteFunction"
local gameProductPurchase = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
gameProductPurchase.Name = "GameProductPurchase"

local getPlayersPurchaseProductsHistory = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
getPlayersPurchaseProductsHistory.Name = "GetPlayersPurchaseProductsHistory"

local getPlayersGiveProductsHistory = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
getPlayersGiveProductsHistory.Name = "GetPlayersGiveProductsHistory"

local giveProductCommandAdmin = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
giveProductCommandAdmin.Name = "GiveProductCommandAdmin"

local deleteProductCommandAdmin = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
deleteProductCommandAdmin.Name = "DeleteProductCommandAdmin"

-- Events about Gamepass Management
local client_checkPlayerHasGamepass = Instance.new("RemoteFunction", ReplicatedStorage.SharedSync.RemoteFunction)
client_checkPlayerHasGamepass.Name = "CheckPlayerHasGamepass"

local server_checkPlayerHasGamepass = Instance.new("BindableFunction", ReplicatedStorage.SharedSync.BindableFunction)
server_checkPlayerHasGamepass.Name = "CheckPlayerHasGamepass"

local GamePassPromptPurchaseFinished = Instance.new("RemoteEvent", ReplicatedStorage.SharedSync.RemoteEvent)
GamePassPromptPurchaseFinished.Name = "GamePassPromptPurchaseFinished"


--When player connect we get this purchase data to set in the session
local function playerAdded(player)
    -- Set cache Gamepass owned by player
    GamepassesPlayersCache[player.UserId] = {}
    for id, data in pairs(GameDataModule.Gamepasses) do
        local hasPass = false

        -- Check if the player already owns the Pass
        local success, message = pcall(function()
            hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, data.ProductID)
        end)

        -- Check if player is autorize to have free gamepass
        if player:GetRankInGroup(12349377) >= 128 then
            hasPass = true
        end

        -- If there's an error, issue a warning and exit the function
        if not success then
            warn("Error while checking if player has pass: " .. tostring(message))
        end

        -- Player have the gamepass, so adding into cache server table
        if hasPass then
            table.insert(GamepassesPlayersCache[player.UserId], data.ProductID)
        end
    end

    --load data player
    sessionDataPlayersPurchaseProductsHistory[player.UserId] = PurchaseStoreModule.loadPurchaseProductData(player)
    print("SHOW SESSION PURCHASE DATA", sessionDataPlayersPurchaseProductsHistory)

    local playerGiveStatus = PurchaseStoreModule.loadGiveHistoryData(player.UserId)
    if playerGiveStatus then
        print("playerGiveStatus", playerGiveStatus)
        for index, giveStatus in pairs(playerGiveStatus) do
            if not giveStatus.Delivery then
                print("giveStatus", giveStatus)
                --Notification event fire to player for show the notification
                ShowPopupBindableEvent:Fire(
                    player,
                    "GIVE PRODUCTS BY ADMIN",
                    "Admin give to you the following products :\n"..GetInfosProductForPopupAdmin(giveStatus.ListOfProducts),
                    ToolsModule.AlertPriority.AdminMessage,
                    nil,
                    ToolsModule.AlertTypeButton.OK,
                    nil,
                    nil,
                    GiveProductToPlayer,
                    {giveStatus.ListOfProducts, index}
                )
            end
        end
    end
end

-- Function to load properly the data player of give history and init it if new
PurchaseStoreModule.loadGiveHistoryData = function(playerId)
	local key = playerId
	local data
	local success, err = pcall(function()
		data = giveHistoryStore:GetAsync(key)
        if not data then
            data = {}
        end
	end)
	
	if not success then
		data = PurchaseStoreModule.loadGiveHistoryData(playerId)
	end
	
	return data
end

-- Function to save in datastore give history data
PurchaseStoreModule.saveGiveHistoryData = function(playerId, data)
	local key = playerId
	
	local success, err = pcall(function()
		giveHistoryStore:SetAsync(key, data)
	end)
	
	if not success then
		PurchaseStoreModule.saveGiveHistoryData(playerId, data)
	end

    return success
end

-- Function to load properly the data player of purchase products and init it if new
PurchaseStoreModule.loadPurchaseProductData = function(player)
	local key = player.UserId
	local data
	local success, err = pcall(function()
		data = allPlayersPurchaseProductsHistory:GetAsync(key)
        if not data then
            data = {}
        end
	end)
	
	if not success then
		data = PurchaseStoreModule.loadPurchaseProductData(player)
	end
	
	return data
end

-- Function to save in datastore from session data Purchase Products of player
PurchaseStoreModule.savePurchaseProductData = function(player)
	local key = player.UserId
	local data = sessionDataPlayersPurchaseProductsHistory[key]
	
	local success, err = pcall(function()
		allPlayersPurchaseProductsHistory:SetAsync(key, data)
	end)
	
	if success then
		print(player.Name.. "'s purchase products data has been saved!")
	else
		PurchaseStoreModule.savePurchaseProductData(player)
	end
end

--This function return a string to show a list of name products given by admin in popup player
function GetInfosProductForPopupAdmin(listProducts)
    local result = ""

    for productId, quantity in pairs(listProducts) do
        local gameProduct = gameProducts[tonumber(productId)]
        local devProduct = GetDeveloperProduct(tonumber(productId))        

        if gameProduct then
            result = result.."- "..gameProduct.ProductName.." in "..quantity.." quantity \n"
        elseif devProduct then
            result = result.."- "..devProduct.displayName.." in "..quantity.." quantity \n"
        end
    end

    return result
end

function GetDeveloperProduct(productID)
    for _, developerProduct in pairs(developerProducts) do
        if developerProduct.ProductId == productID then
            return developerProduct
        end
    end
end
 
--Make all productFunctions behaviour
function InitProductFunctionsFromMarketplace()
    -- Same behavior for all Feez purchase so make foreach for Feez only
    for _, developerProduct in pairs(developerProducts) do
        if developerProduct.displayName:match("Feez") then -- WARN ! This match work because Feez are not translate by Roblox, be careful for other product if u need name because Roblox auto translate it
            --Exemple: ProductId 1219964000 for 130 Feez cost 159 Robux
            productFunctions[developerProduct.ProductId] = function(receipt, player)
                --Get the value Feez to increment with this productId Buy
                local feezValue = developerProduct.displayName:match("^(.+)%s")
                feezValue = tonumber(feezValue)
                -- Logic/code for player buying 100 gold (may vary)
                local feez = PlayerDataModule:Get(player, "Feez")
                if feez then
                    local result = PlayerDataModule:Increment(player, feezValue, "Feez")
                    -- Indicate a successful purchase
                    if result then
                        return true
                    end
                end
            end
        end
    end

    productFunctions[GameDataModule.DeveloperProducts["+ 10 Animal slots"].ProductID] = function(receipt, player)
        local slotIncrementValue = 10
        local actualNbMaxSlots = PlayerDataModule:Get(player, "NbMaxSlotsCreature")
        if actualNbMaxSlots then
            local result = PlayerDataModule:Increment(player, slotIncrementValue, "NbMaxSlotsCreature")
            -- Indicate a successful purchase
            if result then
                return true
            end
        end
    end

    -- This product are specific. Is Instant Growth Time, we can't pass creature ID in parameter of product developer function, so we use PromptProductPurchaseFinished
    -- launch after this function to check if player have make buy or not (look reference of behavior in HorseDataModule "InstantGrowthTime" remote function)
    productFunctions[GameDataModule.DeveloperProducts["InstantGrowthTime"].ProductID] = function(receipt, player)
        return true
    end
end

--Make all gameProductFunctions behaviour - Actually work only to set up the Ecus product of game player can buy
function InitGameProductsFunction()
    for _, gameProduct in pairs(gameProducts) do
        gameProductFunctions[_] = function(player)
            --Get the value Ecus to increment with this productId Buy
            local boughtValue = gameProduct.ProductName:match("^(.+)%s")
            local costValue = gameProduct.Price
            boughtValue = string.gsub(boughtValue, ",", "")
            boughtValue = tonumber(boughtValue)

            local CurrencyUsed = PlayerDataModule:Get(player, gameProduct.CurrencyType)
            local bought =  PlayerDataModule:Get(player, gameProduct.ProductType)

            if CurrencyUsed and bought then
                local ResultUsedValue = PlayerDataModule:Decrement(player, costValue, gameProduct.CurrencyType)
                --check if player have nice paye cost of purchase
                if ResultUsedValue then
                    local result = PlayerDataModule:Increment(player, boughtValue, gameProduct.ProductType)
                    -- Indicate a successful purchase
                    if result then
                        return true
                    end
                end
            end
        end
    end
end

function GetPlayersPurchaseProductsHistory(player, playerName)
    local result = {}
    -- Search keys by prefix or not
    local listSuccess, pages = pcall(function()
        if playerName and playerName ~= "" then
            local userID = game.Players:GetUserIdFromNameAsync(playerName)
            return allPlayersPurchaseProductsHistory:ListKeysAsync(userID) --give prefix optinnnal
        end
        return allPlayersPurchaseProductsHistory:ListKeysAsync() --give prefix optinnnal
    end)
    if listSuccess then
        while true do
            local items = pages:GetCurrentPage()
            for _, v in ipairs(items) do
                local value = allPlayersPurchaseProductsHistory:GetAsync(v.KeyName)
                result[v.KeyName] = value
            end
            if pages.IsFinished then
                break
            end
            pages:AdvanceToNextPageAsync()
        end
    end

    return result
end

function GetPlayersGiveProductsHistory(player, playerName)
    local result = {}
    -- Search keys by prefix or not
    local listSuccess, pages = pcall(function()
        if playerName and playerName ~= "" then
            local userID = game.Players:GetUserIdFromNameAsync(playerName)
            return giveHistoryStore:ListKeysAsync(userID) --give prefix optinnnal
        end
        return giveHistoryStore:ListKeysAsync() --give prefix optinnnal
    end)
    if listSuccess then
        while true do
            local items = pages:GetCurrentPage()
            for _, v in ipairs(items) do
                local value = giveHistoryStore:GetAsync(v.KeyName)
                result[v.KeyName] = value
            end
            if pages.IsFinished then
                break
            end
            pages:AdvanceToNextPageAsync()
        end
    end

    return result
end

-- Make a save datas of purchase for dashboard in session data to not surcharge datastore call
function SaveDataOfPurchaseProduct(receiptInfo)
    local allPlayerPurchaseData = sessionDataPlayersPurchaseProductsHistory[receiptInfo.PlayerId]
    local date = DateTime.now():ToIsoDate()
    date=string.gsub(date,"%-", "_")

    allPlayerPurchaseData[receiptInfo.PurchaseId] = {
        ["Date"] = date,
        ["ProductID"]=receiptInfo.ProductId,
        ["ProductName"]=receiptInfo.ProductName,
        ["CurrencySpent"]=receiptInfo.CurrencySpent,
        ["CurrencyType"]=receiptInfo.CurrencyType,
        ["PurchaseSuccess"]=receiptInfo.Success
    }
    print(sessionDataPlayersPurchaseProductsHistory[receiptInfo.PlayerId])
    print("Save session purchase product history of "..receiptInfo.PlayerId)
end

-- The core 'ProcessReceipt' callback function
local function processReceipt(receiptInfo)
	-- Determine if the product was already granted by checking the data store  
	local playerProductKey = receiptInfo.PlayerId .. "_" .. receiptInfo.PurchaseId
	local purchased = false
	local success, errorMessage = pcall(function()
		purchased = purchaseHistoryStore:GetAsync(playerProductKey)
	end)

	-- If purchase was recorded, the product was already granted
	if success and purchased then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif not success then
		error("Data store error:" .. errorMessage)
	end
 
	-- Find the player who made the purchase in the server
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- The player probably left the game
		-- If they come back, the callback will be called again
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- Look up handler function from 'productFunctions' table above
	local handler = productFunctions[receiptInfo.ProductId]
 
	-- Call the handler function and catch any errors
	local success, result = pcall(handler, receiptInfo, player)
	if not success or not result then
		warn("Error occurred while processing a product purchase")
		print("\nProductId:", receiptInfo.ProductId)
		print("\nPlayer:", player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record transaction in data store so it isn't granted again
	local success, errorMessage = pcall(function()
		purchaseHistoryStore:SetAsync(playerProductKey, true)
        print("PurchaseHistory save for", playerProductKey)
	end)
	if not success then
		error("Cannot save purchase data: " .. errorMessage)
	end

    local info = {
        PlayerId = receiptInfo.PlayerId,
        ProductId = receiptInfo.ProductId,
        PurchaseId = receiptInfo.PurchaseId,
        ProductName = GetDeveloperProduct(receiptInfo.ProductId).displayName,
        CurrencySpent = receiptInfo.CurrencySpent,
        CurrencyType = ToolsModule.CurrencyType.Robux,
        Success = success
    }
    SaveDataOfPurchaseProduct(info)
 
	-- IMPORTANT: Tell Roblox that the game successfully handled the purchase
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Set the callback
MarketplaceService.ProcessReceipt = processReceipt

--[[
    This is the process receipt for GamePass because we don't have the same process for Developer Product and GamePass.
    We wait the end of purchase prompt for know if player have purchass gamepass or not.
    If purchass are success we setup gamepasses cache player to know status of buyed gamepasses (prevent the cache roblox of function UserOwnsGamePassAsync)
    End we send the result with event to client side.
]]
local function onGamePassPromptPurchaseFinished(player, purchasedPassID, purchaseSuccess)
    if purchaseSuccess then
        for id, data in pairs(GameDataModule.Gamepasses) do
            if data.ProductID == purchasedPassID then
                table.insert(GamepassesPlayersCache[player.UserId], purchasedPassID)

                -- Make a table data with purchase informations for save in History Purchase
                local str = string.gsub(DataManagerModule.GenerateUniqueID(), "{", "")
                str = string.gsub(str, "}", "")
                str = string.gsub(str, "-", "")
                local receiptInfo = {
                    PlayerId = player.UserId,
                    ProductId = purchasedPassID,
                    PurchaseId = str,
                    ProductName = data.Name,
                    CurrencySpent = data.Price,
                    CurrencyType = ToolsModule.CurrencyType.Robux,
                    Success = purchaseSuccess
                }

                SaveDataOfPurchaseProduct(receiptInfo)

                if id == "VIP" then
                    ChatTagModule.AddingTagVIP(player)
                    ToolsModule.CreateOverHeadGuiName(player)
                end

                break
            end
        end
    end

    GamePassPromptPurchaseFinished:FireClient(player, purchasedPassID, purchaseSuccess)
end

-- Set the callback for Gamepass
MarketplaceService.PromptGamePassPurchaseFinished:Connect(onGamePassPromptPurchaseFinished)

-- Little function can call by server or client to check into cache server if player have already buy the gamepass give in parameters
local function checkPlayerHaveGamepass(player, gamepassID)
    if GamepassesPlayersCache[player.UserId] then
        if table.find(GamepassesPlayersCache[player.UserId], gamepassID) then
            return true
        end
    end

    return false
end

-- Remote function client/server callback check player has buy gamepass or not
client_checkPlayerHasGamepass.OnServerInvoke = checkPlayerHaveGamepass
server_checkPlayerHasGamepass.OnInvoke = checkPlayerHaveGamepass

--RemoteFunction call by player want to buy a game product
gameProductPurchase.OnServerInvoke = function(player, gameProductID)
    local handler = gameProductFunctions[gameProductID]
    local success, result = pcall(handler, player)
	if not success or not result then
		warn("Error occurred while processing a product purchase\n","Player:", player)
    else
        local str = string.gsub(DataManagerModule.GenerateUniqueID(), "{", "")
        str = string.gsub(str, "}", "")
        str = string.gsub(str, "-", "")
        local receiptInfo = {
            PlayerId = player.UserId,
            ProductId = gameProductID,
            PurchaseId = str,
            ProductName = gameProducts[gameProductID].ProductName,
            CurrencySpent = gameProducts[gameProductID].Price,
            CurrencyType = ToolsModule.CurrencyType.Feez,
            Success = result
        }
        SaveDataOfPurchaseProduct(receiptInfo)
	end
    return result
end

function GiveProductToPlayer(player, listProducts, giveID)
    local playerGiveStatus = PurchaseStoreModule.loadGiveHistoryData(player.UserId)
    if playerGiveStatus[giveID] then
        local result

        for productId, quantity in pairs(listProducts) do
            print("ADMIN GIVE TO", player, productId, quantity)
            local gameProduct = gameProducts[tonumber(productId)]
            local devProduct = GetDeveloperProduct(tonumber(productId))
    
            print("PRODUCT", gameProduct, devProduct)
    
            if gameProduct then
                for i=1, tonumber(quantity) do
                    result = PlayerDataModule:Increment(player, gameProduct.ProductName:match("^(.+)%s"), gameProduct.ProductType)
                    print("RESULT OF GIVE", result)
                end
            elseif devProduct then
                for i=1, tonumber(quantity) do
                    result = PlayerDataModule:Increment(player, devProduct.displayName:match("^(.+)%s"), devProduct.displayName:match("%a+"))
                    print("RESULT OF GIVE", result)
                end
            end
        end
    
        if result then        
            if playerGiveStatus then
                playerGiveStatus[giveID].Delivery = true
                print("PLAYER GIVE STATUS LIST", playerGiveStatus)
                PurchaseStoreModule.saveGiveHistoryData(player.UserId, playerGiveStatus)
            end
        end
    else
        warn("The"..giveID.." are no longer available for "..player.Name.."....")
    end
end

giveProductCommandAdmin.OnServerInvoke = function(admin, playerName, listProducts)
    local targetID
    local ok, err = pcall(function()
        targetID = game.Players:GetUserIdFromNameAsync(playerName)
    end)

    if not ok then
        return false
    end

    local target = game.Players:GetPlayerByUserId(targetID)
    if target then
        print("PLAYER EXIST IN SAME SERVER")
        local playerGiveStatus = PurchaseStoreModule.loadGiveHistoryData(target.UserId)

        local str = string.gsub(DataManagerModule.GenerateUniqueID(), "{", "")
        str = string.gsub(str, "}", "")
        str = string.gsub(str, "-", "")
        local date = DateTime.now():ToIsoDate()
        date=string.gsub(date,"%-", "_")

        playerGiveStatus[str] = {
            ["Date"] = date,
            ["PlayerId"] = target.UserId,
            ["PlayerName"] = target.Name,
            ["ListOfProducts"] = listProducts,
            ["Delivery"] = false
        }

        print("PLAYER GIVE STATUS ",playerGiveStatus)

        local success = PurchaseStoreModule.saveGiveHistoryData(target.UserId, playerGiveStatus)

        if success then
            --Notification event fire to player for show the notification
            ShowPopupBindableEvent:Fire(
                target,
                "GIVE PRODUCTS BY ADMIN",
                "Admin give to you the following products :\n"..GetInfosProductForPopupAdmin(listProducts),
                ToolsModule.AlertPriority.AdminMessage,
                nil,
                ToolsModule.AlertTypeButton.OK,
                nil,
                nil,
                GiveProductToPlayer,
                {listProducts, str}
            )

            return true
        end
    else
        print("PLAYER DONT EXIST ON THIS SERVER OR NOT CONNECTED")
        if targetID then
            print("PLAYER ID EXIST")

            local playerAlreadyPlayGame = PlayerDataModule:Load(targetID)
            if playerAlreadyPlayGame then
                local playerGiveStatus = PurchaseStoreModule.loadGiveHistoryData(targetID)

                local str = string.gsub(DataManagerModule.GenerateUniqueID(), "{", "")
                str = string.gsub(str, "}", "")
                str = string.gsub(str, "-", "")
                local date = DateTime.now():ToIsoDate()
                date=string.gsub(date,"%-", "_")

                playerGiveStatus[str] = {
                    ["Date"] = date,
                    ["PlayerId"] = targetID,
                    ["PlayerName"] = playerName,
                    ["ListOfProducts"] = listProducts,
                    ["Delivery"] = false
                }
                
                PurchaseStoreModule.saveGiveHistoryData(targetID, playerGiveStatus)

                return true
            else
                return false
            end
        end
    end
end

deleteProductCommandAdmin.OnServerInvoke = function(admin, playerID, giveID)
    local playerGiveStatus = PurchaseStoreModule.loadGiveHistoryData(playerID)
    if playerGiveStatus[giveID] then
        if not playerGiveStatus[giveID].Delivery then
            playerGiveStatus[giveID] = nil
            PurchaseStoreModule.saveGiveHistoryData(playerID, playerGiveStatus)
            return true
        end
    end
    return false
end

--Set Remote Function to send List of products ID
getProductsIDListRemoteFunction.OnServerInvoke = function(player)
    local productsIDList = {}
    for index, _ in pairs(productFunctions) do
        table.insert(productsIDList, index)
    end
    return productsIDList
end

getGameProductsRemoteFunction.OnServerInvoke = function()
    return gameProducts
end

getPlayersPurchaseProductsHistory.OnServerInvoke = GetPlayersPurchaseProductsHistory
getPlayersGiveProductsHistory.OnServerInvoke = GetPlayersGiveProductsHistory

local function autoSave()
	while task.wait(AUTOSAVE_INTERVAL) do
		print("Auto-saving purchase data for all players")
		
		for key, dataTable in pairs(sessionDataPlayersPurchaseProductsHistory) do
			local player = game.Players:GetPlayerByUserId(key)
			PurchaseStoreModule.savePurchaseProductData(player)
		end
	end
end

InitProductFunctionsFromMarketplace()
InitGameProductsFunction()
task.spawn(autoSave) --Initialize autosave loop

game.Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    playerAdded(player)
end
game.Players.PlayerRemoving:Connect(function(player)
	PurchaseStoreModule.savePurchaseProductData(player)
	sessionDataPlayersPurchaseProductsHistory[player.UserId] = nil
end)

return PurchaseStoreModule