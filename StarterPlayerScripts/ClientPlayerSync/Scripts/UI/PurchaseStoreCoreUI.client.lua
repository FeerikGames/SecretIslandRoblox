local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game.Players.LocalPlayer

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")
local GameDataModule = require("GameDataModule")

--UI
local PurchaseStoreGui = UIProviderModule:GetUI("PurchaseStoreGui")
local ItemTemplate = PurchaseStoreGui.Template:WaitForChild("ItemTemplate")
local PurchasePopup = PurchaseStoreGui.Template:WaitForChild("PurchasePopupTemplate")
local ConfirmPopup = PurchaseStoreGui.Template:WaitForChild("ConfirmPurchasePopupTemplate")
local FeezBackground = PurchaseStoreGui:WaitForChild("FeezBackground")
local GamepassesBackground = PurchaseStoreGui:WaitForChild("GamepassesBackground")
local EcusBackground = PurchaseStoreGui:WaitForChild("EcusBackground")
local SparksBackground = PurchaseStoreGui:WaitForChild("SparksBackground")

local PlayerInfosGui = UIProviderModule:GetUI("PlayerInfosGui")

--Get remote for get the list of productsID to make a dynamic UI
local getProductsIDListRemoteFunction = ReplicatedStorage.RemoteFunction:WaitForChild("GetProductsIDListRemoteFunction")
local getGameProductsRemoteFunction = ReplicatedStorage.RemoteFunction:WaitForChild("GetGameProductsRemoteFunction")
local gameProductPurchase = ReplicatedStorage.RemoteFunction:WaitForChild("GameProductPurchase")

local purchaseIncoming = false

--[[
    Function for init interface of Gamepasses ui behavior. If player wan't buy Gamepass in game it's possible with this UI.
]]
function InitGamepassesProductsUI()
    -- We check all GamePasses setup in GameDataModule and get product info from Roblox API and setup UI element added into list player can interact
    for id, data in pairs(GameDataModule.Gamepasses) do
        -- Get product info gamepass type for setup all UI data
        local gamepassInfo = MarketplaceService:GetProductInfo(data.ProductID, Enum.InfoType.GamePass)
        local cloneItemUI = ItemTemplate:Clone()
        cloneItemUI.Name = data.ProductID
        cloneItemUI.ItemImgBtn.Image = "rbxassetid://"..gamepassInfo.IconImageAssetId
        cloneItemUI.ItemImgBtn.ItemName.Text = gamepassInfo.Name
        cloneItemUI.Price.Text = gamepassInfo.PriceInRobux
        cloneItemUI.Logo.Image = "rbxassetid://7955510691" --Icon robux
        cloneItemUI.Visible = true
        cloneItemUI.Parent = GamepassesBackground.ScrollingFrame

        -- We check if player have already buy this gamepass
        if not ReplicatedStorage.RemoteFunction.CheckPlayerHasGamepass:InvokeServer(data.ProductID) then
            -- If not we make behavior of button image click to buy Gamepass
            cloneItemUI.ItemImgBtn.Activated:Connect(function()
                if not ReplicatedStorage.RemoteFunction.CheckPlayerHasGamepass:InvokeServer(data.ProductID) then
                    -- Activate API Roblox to buy the Gamepass with product ID setup for gamepass click by player
                    MarketplaceService:PromptGamePassPurchase(Player, data.ProductID)

                    -- Disable all UI for focus on prompt purchase Roblox
                    FeezBackground.Visible = false
                    EcusBackground.Visible = false
                    GamepassesBackground.Visible = false
                end
            end)
        else
            -- If already buy, we change visual UI of gamepass to show at player already buy this gamepass
            cloneItemUI.ItemImgBtn.Active = false
            cloneItemUI.Price.Text = "Owned"
            cloneItemUI.Price.AnchorPoint = Vector2.new(.5,0)
            cloneItemUI.Price.Size = UDim2.fromScale(1, cloneItemUI.Price.Size.Y.Scale)
            cloneItemUI.Price.Position = UDim2.fromScale(.5, cloneItemUI.Price.Position.Y.Scale)
            cloneItemUI.Logo.ImageTransparency = 1
        end
    end
end

-- Little listen to show/Hide GamepassBackground UI - TEMPORAIRE
UIProviderModule:GetUI("AllButtonsMainMenusGui"):WaitForChild("SubMenu").GamepassesBtn.Activated:Connect(function()
    GamepassesBackground.Visible = not GamepassesBackground.Visible
end)

-- Remote Event GamePassPromptPurchaseFinished listen, event send by server when pruchase Gamepass are make and return if purchase Success and what PAss ID are buy by player
ReplicatedStorage.RemoteEvent:WaitForChild("GamePassPromptPurchaseFinished").OnClientEvent:Connect(function(purchasedPassID, purchaseSuccess)
    -- If pruchase success we setup UI properly to show good status of Gamepass buy by player
    if purchaseSuccess then
        local itemUI = GamepassesBackground.ScrollingFrame:FindFirstChild(purchasedPassID)
        if itemUI then
            itemUI.ItemImgBtn.Active = false
            itemUI.Price.Text = "Owned"
            itemUI.Price.AnchorPoint = Vector2.new(.5,0)
            itemUI.Price.Size = UDim2.fromScale(1, itemUI.Price.Size.Y.Scale)
            itemUI.Price.Position = UDim2.fromScale(.5, itemUI.Price.Position.Y.Scale)
            itemUI.Logo.ImageTransparency = 1
        end
    end
end)

function InitFeezProductsUI()
    local productsList = getProductsIDListRemoteFunction:InvokeServer()
    if not productsList then
        return
    end
    for _, productID in pairs(productsList) do
        local productInfo = MarketplaceService:GetProductInfo(productID, Enum.InfoType.Product)
        if productInfo.Name:match("Feez") then
            local cloneItemUI = ItemTemplate:Clone()
            cloneItemUI.Name = productID
            cloneItemUI.ItemImgBtn.Image = "rbxassetid://"..productInfo.IconImageAssetId
            cloneItemUI.ItemImgBtn.ItemName.Text = productInfo.Name
            cloneItemUI.Price.Text = productInfo.PriceInRobux
            cloneItemUI.Logo.Image = "rbxassetid://7955510691" --Icon robux
            cloneItemUI.Visible = true
            cloneItemUI.Parent = FeezBackground.ScrollingFrame
            cloneItemUI.LayoutOrder = tonumber(productInfo.PriceInRobux)
    
            cloneItemUI.ItemImgBtn.Activated:Connect(function()
                MarketplaceService:PromptProductPurchase(Player, productID)
                FeezBackground.Visible = false
                EcusBackground.Visible = false
                GamepassesBackground.Visible = false
            end)
        end
    end
end

function InitProductsUI(product, Background)
    local gameProductsList = getGameProductsRemoteFunction:InvokeServer()
    if not gameProductsList then
        return
    end
    for _, gameProduct in pairs(gameProductsList) do
        if gameProduct.ProductType ~= product then
            continue
        end
        local cloneItemUI = ItemTemplate:Clone()
        cloneItemUI.Name = _
        cloneItemUI.ItemImgBtn.Image = gameProduct.ImageID
        cloneItemUI.ItemImgBtn.ItemName.Text = gameProduct.ProductName
        cloneItemUI.Price.Text = gameProduct.Price
        cloneItemUI.Logo.Image = gameProduct.CurrencyImageID -- Ecus icon
        cloneItemUI.Visible = true
        cloneItemUI.Parent = Background.ScrollingFrame

        cloneItemUI.ItemImgBtn.Activated:Connect(function()
            purchaseIncoming = true
            --Check if popup for buy ecu already exist
            local exist = PurchaseStoreGui:FindFirstChild("PurchasePopupTemplate")
            local exist2 = PurchaseStoreGui:FindFirstChild("ConfirmPurchasePopupTemplate")
            if exist then
                --destroy it if already exist
                exist:Destroy()
            end
            if exist2 then
                exist2:Destroy()
            end

            --Show popup to cinfirm buy by player
            CreatePopupPurchase(cloneItemUI.Name, gameProduct)
            FeezBackground.Visible = false
            EcusBackground.Visible = false
            SparksBackground.Visible = false
            GamepassesBackground.Visible = false
        end)
    end
end

--Function to create a confirm popup for buy ecu
function CreatePopupPurchase(idProd, gameProduct)
    local popup = PurchasePopup:Clone()
    popup.Parent = PurchaseStoreGui
    popup.Ask.Text = popup.Ask.Text.." "..gameProduct.ProductName.." ?"
    popup.ImageProduct.Image = gameProduct.ImageID
    popup.YesBtn.Icon.Image = gameProduct.CurrencyImageID
    popup.YesBtn.PriceTxt.Text = gameProduct.Price
    popup.Visible = true

    popup.NoBtn.Activated:Connect(function()
        purchaseIncoming = false
        popup:Destroy()
    end)
    popup.YesBtn.Activated:Connect(function()
        local result = gameProductPurchase:InvokeServer(tonumber(idProd))
        CreateConfirmPopup(result, gameProduct)
        popup:Destroy()
    end)
end

--function to show result success or not to buy game product
function CreateConfirmPopup(result, gameProduct)
    local popup = ConfirmPopup:Clone()
    popup.Parent = PurchaseStoreGui
    popup.Visible = true

    if not result then
        popup.Ask.Text = "FAIL to purchase "..gameProduct.ProductName.." product!"
        popup.Ask.TextColor3 = Color3.fromRGB(0, 0, 0)
    else
        popup.Ask.Text = "Your purchase of "..gameProduct.ProductName.." succeeded!"
        popup.Ask.TextColor3 = Color3.fromRGB(0, 0, 0)
    end

    popup.OkBtn.Activated:Connect(function()
        purchaseIncoming = false
        popup:Destroy()
    end)
end

for _, child in pairs(PlayerInfosGui.PreviewPlayer.FeezFrame:GetChildren()) do
    if child.Name == "ShowPurchase" then
        child.Activated:Connect(function()
            if not purchaseIncoming then
                FeezBackground.Visible = true
                EcusBackground.Visible = false
                SparksBackground.Visible = false
                GamepassesBackground.Visible = false
            end
        end)
    end
end

for _, child in pairs(PlayerInfosGui.PreviewPlayer.EcusFrame:GetChildren()) do
    if child.Name == "ShowPurchase" then
        child.Activated:Connect(function()
            if not purchaseIncoming then
                EcusBackground.Visible = true
                FeezBackground.Visible = false
                SparksBackground.Visible = false
                GamepassesBackground.Visible = false
            end
        end)
    end
end

InitFeezProductsUI()
InitGamepassesProductsUI()
InitProductsUI("Ecus", EcusBackground)

FeezBackground:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not FeezBackground.Visible)
	if FeezBackground.Visible then
        local exist = PurchaseStoreGui:FindFirstChild("ConfirmPurchasePopupTemplate")
        if exist then
            exist:Destroy()
        end
    end
end)

GamepassesBackground:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not GamepassesBackground.Visible)
	if GamepassesBackground.Visible then
        local exist = PurchaseStoreGui:FindFirstChild("ConfirmPurchasePopupTemplate")
        if exist then
            exist:Destroy()
        end
    end
end)

EcusBackground:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not EcusBackground.Visible)
	if EcusBackground.Visible then
        local exist = PurchaseStoreGui:FindFirstChild("ConfirmPurchasePopupTemplate")
        if exist then
            exist:Destroy()
        end
    end
end)

SparksBackground:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not SparksBackground.Visible)
	if SparksBackground.Visible then
        local exist = PurchaseStoreGui:FindFirstChild("ConfirmPurchasePopupTemplate")
        if exist then
            exist:Destroy()
        end
    end
end)


--####### ADMIN PURCHASE STORE ##############

-- Check first if player is admin or owner and create a dashboard admin if yes else do nothing
if Player:GetRankInGroup(12349377) >= 254 then
    print("Player is the owner or admin of the group")
    local DashboardFrame = PurchaseStoreGui:WaitForChild("AdminDashboard")
    local PurchasesPanel = DashboardFrame.ListPurchasesPlayers
    local GiverPanel = DashboardFrame.GiverPlayersPanel
    local ItemDashboard = PurchaseStoreGui.Template:WaitForChild("DashboardItemTemplate")
    local giveProductCommandAdmin = ReplicatedStorage.RemoteFunction:WaitForChild("GiveProductCommandAdmin")
    local getPlayersPurchaseProductsHistory = ReplicatedStorage.RemoteFunction:WaitForChild("GetPlayersPurchaseProductsHistory")
    local getPlayersGiveProductsHistory = ReplicatedStorage.RemoteFunction:WaitForChild("GetPlayersGiveProductsHistory")
    local deleteProductCommandAdmin = ReplicatedStorage.RemoteFunction:WaitForChild("DeleteProductCommandAdmin")
    local nbOccurenceFind = 0

    --### DROPDOWN BEHAVIOR ###
    local drop
    local menu
    local open
    local select
    local co1, co2, co3, co4

    function InitDropDown(searchField)
        drop = searchField.DropDown
        menu = drop.Menu
        open = menu.Open.Value
        select = drop.Select
        if co1 and co2 and co3 and co4 then
            co1:Disconnect()
            co2:Disconnect()
            co3:Disconnect()
            co4:Disconnect()
        end

        local function CloseDropDown()
            menu:TweenSize(UDim2.new(1, 0, 0, 0), "Out", "Sine", 0.15, true)
            task.wait(0.05)
            for _, button in pairs(menu:GetChildren()) do
                if button:IsA("TextButton") then
                    button.Visible = false
                end
            end
            open = false
        end
    
        local function OpenDropDown()
            menu:TweenSize(UDim2.new(1, 0, 1.958, 0), "Out", "Sine", 0.15, true)
            for _, button in pairs(menu:GetChildren()) do
                if button:IsA("TextButton") then
                    button.Visible = true
                end
            end
            open = true
        end
    
        co4 = select.Activated:Connect(function()
            if not open then
                OpenDropDown()
            else
                CloseDropDown()
            end
        end)
    
        for _, button in pairs(menu:GetChildren()) do
            if button:IsA("TextButton") then
                co1 = button.MouseEnter:Connect(function()
                    button.BackgroundTransparency = 0.2
                end)
                co2 = button.MouseLeave:Connect(function()
                    button.BackgroundTransparency = 0
                end)
                co3 = button.Activated:Connect(function()
                    searchField.Date2SearchField.Visible = false
                    if button.Name == "Date" then
                        searchField.Date2SearchField.Visible = true
                    end
                    searchField.Text = ""
                    drop.SelectedOption.Value = button.Name
                    drop.Selection.Text = button.Text
                    CloseDropDown()
                end)
            end
        end
    end
    --############

    --For Text Filter Clubsbook
    local Objects = {['Frame'] = true, ['TextLabel'] = true, ['ImageButton'] = false, ['ImageLabel'] = false}
    local Type = 1

    --[[
        This function allow to filter list of purchase element based on value of Text input in parent frame elements.
        Set the visibility and the order layout for display what the player want.
    ]]
    function TextFilter(panel, Text)
        nbOccurenceFind=0
        panel.NbOccurenceFind.Text = nbOccurenceFind.." Occurences find"
        for i,v in pairs(panel.ScrollingFrame:GetChildren()) do
            if Objects[v.ClassName] then
                local child = v:FindFirstChild(drop.SelectedOption.Value)
                if child then
                    --check if search is Date to a specific search, if not, other research are the same behavior
                    --TODO work but we can refactor this part
                    if drop.SelectedOption.Value == "Date" then
                        panel.NbOccurenceFind.Text = ""
                        local text = string.gsub(panel.SearchField.Text,"[%s%p%a]+", "_" )
                        local valueDate1 = text:split("_")
                        text = string.gsub(panel.SearchField.Date2SearchField.Text,"[%s%p%a]+", "_" )
                        local valueDate2 = text:split("_")
                        text = string.gsub(child.Text,"[%s%p%a]+", "_" )
                        local valueDate3 = text:split("_")

                        pcall(function()
                            if tonumber(valueDate3[1]) >= tonumber(valueDate1[1]) and  tonumber(valueDate3[1]) <= tonumber(valueDate2[1]) then
                                --years OK
                                if Type == 1 then
                                    v.Visible = true
                                end
                                v.LayoutOrder = 0
                            else
                                if Type == 1 then
                                    v.Visible = false
                                end
                                v.LayoutOrder = 1
                            end

                            if tonumber(valueDate3[1]..valueDate3[2]) >= tonumber(valueDate1[1]..valueDate1[2]) and  tonumber(valueDate3[1]..valueDate3[2]) <= tonumber(valueDate2[1]..valueDate2[2]) then
                                --Month OK
                                if Type == 1 then
                                    v.Visible = true
                                end
                                v.LayoutOrder = 0
                            else
                                if Type == 1 then
                                    v.Visible = false
                                end
                                v.LayoutOrder = 1
                            end
                            
                            if tonumber(valueDate3[1]..valueDate3[2]..valueDate3[3]) >= tonumber(valueDate1[1]..valueDate1[2]..valueDate1[3]) and  tonumber(valueDate3[1]..valueDate3[2]..valueDate3[3]) <= tonumber(valueDate2[1]..valueDate2[2]..valueDate2[3]) then
                                --Day OK
                                if Type == 1 then
                                    v.Visible = true
                                end
                                v.LayoutOrder = 0
                            else
                                if Type == 1 then
                                    v.Visible = false
                                end
                                v.LayoutOrder = 1
                            end
                        end)
                    else
                        if string.match(string.lower(child.Text), Text) then
                            nbOccurenceFind+=1
                            panel.NbOccurenceFind.Text = nbOccurenceFind.." Occurences find"
                            if Type == 1 then
                                v.Visible = true
                            end
                            v.LayoutOrder = 0
                        else
                            if Type == 1 then
                                v.Visible = false
                            end
                            v.LayoutOrder = 1
                        end
                    end
                end
            end
        end
    end

    --Function use for init a search field in admin panel purchase give in parameters
    function SearchFieldTextChangedInit(panel, searchfield)
        local CurrentText = searchfield.Text
        if CurrentText == "" then
            for i,v in pairs(panel.ScrollingFrame:GetChildren()) do
                if Objects[v.ClassName] then
                    if nbOccurenceFind-1<0 then
                        nbOccurenceFind = 0
                    else                        
                        nbOccurenceFind-=1
                    end
                    panel.NbOccurenceFind.Text = ""
                    v.Visible = true
                end
            end
        else
            TextFilter(panel, string.lower(CurrentText))
        end
    end

    --[[
        This is listener of value text of input filter text for purchase elements
        when text is modified use TextFilter() for update ui dynamic list of purchase element
    ]]
    PurchasesPanel.SearchField:GetPropertyChangedSignal('Text'):Connect(function()
        SearchFieldTextChangedInit(PurchasesPanel, PurchasesPanel.SearchField)
        PurchasesPanel.SearchField.Date2SearchField.Text = PurchasesPanel.SearchField.Text
    end)

    PurchasesPanel.SearchField.Date2SearchField:GetPropertyChangedSignal('Text'):Connect(function()
        SearchFieldTextChangedInit(PurchasesPanel, PurchasesPanel.SearchField.Date2SearchField)
    end)

    GiverPanel.SearchField:GetPropertyChangedSignal('Text'):Connect(function()
        SearchFieldTextChangedInit(GiverPanel, GiverPanel.SearchField)
        GiverPanel.SearchField.Date2SearchField.Text = GiverPanel.SearchField.Text
    end)

    GiverPanel.SearchField.Date2SearchField:GetPropertyChangedSignal('Text'):Connect(function()
        SearchFieldTextChangedInit(GiverPanel, GiverPanel.SearchField.Date2SearchField)
    end)


    --[[
        This function allow to player admin load data of players or name player given in parameter.
        And setup correctly this data get by server into a UI elements.
        Parameter playerName depending of SearchPlayer text field value.
    ]]
    function LoadData(playerName)
        local nbDataFind = 0
        ToolsModule.DepopulateTypeOfItemFrom("Frame", PurchasesPanel.ScrollingFrame)
        PurchasesPanel.WaitingTxt.Visible = true
        PurchasesPanel.ScrollingFrame.Visible = false
        local result = getPlayersPurchaseProductsHistory:InvokeServer(playerName)
        if result then
            print("ADMIN "..Player.UserId.." get purchase command and data", result)
            for plrId, purchases in pairs(result) do
                if purchases then                        
                    for purchaseId, product in pairs(purchases) do
                        local item = ItemDashboard:Clone()
                        item.Name = purchaseId
                        item.Date.Text = product.Date
                        pcall(function()
                            item.PlayerName.Text = game.Players:GetNameFromUserIdAsync(tonumber(plrId))
                        end)
                        item.ProductID.Text = product.ProductID
                        item.ProductName.Text = product.ProductName
                        item.CurrencySpent.Text = product.CurrencySpent
                        for i, v in pairs(ToolsModule.CurrencyType) do
                            if v == product.CurrencyType then
                                item.CurrencyType.Text = i
                                break
                            end
                        end
                        item.PurchaseSuccess.Text = tostring(product.PurchaseSuccess)
                        item.Visible = true
                        item.Parent = PurchasesPanel.ScrollingFrame
                        
                        nbDataFind += 1
                    end
                end
            end
            PurchasesPanel.WaitingTxt.Visible = false
            PurchasesPanel.ScrollingFrame.Visible = true
            PurchasesPanel.NbDataFind.Text = nbDataFind.." Datas find"
        end
    end

    --when is clicked button load data for player given if its found, if no player given : get all players data
    PurchasesPanel.SearchPlayer.SearchBtn.Activated:Connect(function()
        LoadData(PurchasesPanel.SearchPlayer.Text)
    end)

    GiverPanel.SearchPlayer.SearchBtn.Activated:Connect(function()
        ToolsModule.DepopulateTypeOfItemFrom("Frame", GiverPanel.ScrollingFrame)
        GiverPanel.WaitingTxt.Visible = true
        GiverPanel.ScrollingFrame.Visible = false
        local result = getPlayersGiveProductsHistory:InvokeServer(GiverPanel.SearchPlayer.Text)
        if result then
            for _, giverStatus in pairs(result) do
                if giverStatus then
                    for giverId, giver in pairs(giverStatus) do                        
                        local item = PurchaseStoreGui.Template.DashboardGiveStatusItemTemplate:Clone()
                        item.Name = giverId
                        item.Date.Text = giver.Date
                        item.PlayerId.Text = giver.PlayerId
                        item.PlayerName.Text = giver.PlayerName
                        for productID, quantity in pairs(giver.ListOfProducts) do
                            local c = item.ScrollingFrame.Frame:Clone()
                            c.Parent = item.ScrollingFrame
                            c.ProductField.Text = productID
                            c.QuantityField.Text = quantity
                            c.Visible = true
                        end
                        item.Delivery.Text = tostring(giver.Delivery)

                        item.DeleteBtn.Activated:Connect(function()
                            local result = deleteProductCommandAdmin:InvokeServer(giver.PlayerId,giverId)
                            if result then
                                item:Destroy()
                            else
                                warn("Can't delete if already receipe by player target or not found giveID")
                            end
                        end)

                        item.Visible = true
                        item.Parent = GiverPanel.ScrollingFrame
                    end
                end
            end
            GiverPanel.WaitingTxt.Visible = false
            GiverPanel.ScrollingFrame.Visible = true
        end
    end)

    GiverPanel.CommandFrame.GiveBtn.Activated:Connect(function()
        local commandFrame = GiverPanel.CommandFrame
        local playerName = commandFrame.PlayerField.Text

        if playerName ~= "" then
            local listProducts = {}
            local isSet = false

            for _, product in pairs(commandFrame.ScrollingFrame:GetChildren()) do
                if product:IsA("Frame") then
                    if product.ProductField.Text ~= "" and product.QuantityField.Text ~= "" then
                        listProducts[product.ProductField.Text] = product.QuantityField.Text
                        isSet = true
                    else
                        isSet = false
                    end
                end
            end

            if not isSet then
                warn("List of products can't nil !")
                return
            end

            --reset ui
            for _, product in pairs(commandFrame.ScrollingFrame:GetChildren()) do
                if product:IsA("Frame") then
                    product:Destroy()
                end
            end
            --commandFrame.PlayerField.Text = ""
            commandFrame.ScrollingFrame.Visible = false
            commandFrame.GiveBtn.Visible = false
            commandFrame.PlayerField.Text = ""

            --send data server
            local result = giveProductCommandAdmin:InvokeServer(playerName, listProducts)
            if not result then
                warn("The player not exist or never play at this game, give command is not possible !")
            end
        else
            warn("GIVE NAME OF PLAYER WANT SEND PRODUCT BY ADMIN")
        end
    end)

    GiverPanel.CommandFrame.AddProductBtn.Activated:Connect(function()
        if GiverPanel.CommandFrame.PlayerField.Text ~= "" then
            GiverPanel.CommandFrame.ScrollingFrame.Visible = true
            GiverPanel.CommandFrame.GiveBtn.Visible = true
            local clone = PurchaseStoreGui.Template.ItemGiveProductTemplate:Clone()
            clone.Parent = GiverPanel.CommandFrame.ScrollingFrame
            clone.Visible = true
            clone.RemoveProductBtn.Activated:Connect(function()
                clone:Destroy()
                if #GiverPanel.CommandFrame.ScrollingFrame:GetChildren() <= 1 then
                    GiverPanel.CommandFrame.ScrollingFrame.Visible = false
                    GiverPanel.CommandFrame.GiveBtn.Visible = false
                end
            end)
            clone.ProductField:GetPropertyChangedSignal('Text'):Connect(function()
                local CurrentText = clone.ProductField.Text
                CurrentText = CurrentText:gsub("[^%w%s_]+", "")
                CurrentText = CurrentText:gsub("%a", "")
                clone.ProductField.Text = CurrentText
            end)
            clone.QuantityField:GetPropertyChangedSignal('Text'):Connect(function()
                local CurrentText = clone.QuantityField.Text
                CurrentText = CurrentText:gsub("[^%w%s_]+", "")
                CurrentText = CurrentText:gsub("%a", "")
                clone.QuantityField.Text = CurrentText
            end)
        end
    end)

    DashboardFrame.PurchasesPanelBtn.Activated:Connect(function()
        PurchasesPanel.Visible = true
        DashboardFrame.PurchasesPanelBtn.BackgroundTransparency = Color3.fromRGB(255, 255, 255)
        DashboardFrame.GivePanelBtn.BackgroundColor3 = Color3.fromRGB(83, 83, 83)
        GiverPanel.Visible = false        
        InitDropDown(PurchasesPanel.SearchField)
    end)

    DashboardFrame.GivePanelBtn.Activated:Connect(function()
        PurchasesPanel.Visible = false
        DashboardFrame.GivePanelBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        DashboardFrame.PurchasesPanelBtn.BackgroundColor3 = Color3.fromRGB(83, 83, 83)
        GiverPanel.Visible = true
        InitDropDown(GiverPanel.SearchField)
    end)
    InitDropDown(PurchasesPanel.SearchField)
else
    print("Player is NOT the owner or admin of the group")
end

--###########################################