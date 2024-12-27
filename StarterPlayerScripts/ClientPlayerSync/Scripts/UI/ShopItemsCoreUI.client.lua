local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

--RequireModule
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local WalkSpeedModule = require("WalkSpeedModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local GameDataModule = require("GameDataModule")
local Fireworks = require("Fireworks")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
local RemoteEvent = ReplicatedStorage.RemoteEvent

local UpdateClientsShopUI = RemoteEvent:WaitForChild("UpdateClientsShopUI")
local getShopItemsDatas = RemoteFuncFolder:WaitForChild("GetShopItemsDatas")
local buyShopItemPlayer = RemoteFuncFolder:WaitForChild("BuyShopItemPlayer")
local getShopItemsContainer = RemoteFuncFolder:WaitForChild("GetShopItemsContainer")
local GetTypeOfGenes = ReplicatedStorage.RemoteFunction:WaitForChild("GetTypeOfGenes")
local GetDataOf = RemoteFuncFolder:WaitForChild("GetDataOf")
local ShowShopUIForItem = RemoteEvent.ShowShopUIForItem

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local ShopItemsGui = UIProviderModule:GetUI("ShopItemsGui")
local PlayerInfosGui = UIProviderModule:GetUI("PlayerInfosGui")
local ShopFrame = ShopItemsGui:WaitForChild("ShopFrame")
local TemplateFolder = ShopItemsGui:WaitForChild("Template")
local ShowUiBtn = AllButtonsMainMenusGui.ShopItemsGuiBtn
local ItemDetails = ShopFrame.ItemPreview:WaitForChild("ItemDetails")
local ItemDetailsRegular = ShopFrame.ItemPreview:WaitForChild("ItemDetailsRegular")
local ContainerDetails = ShopFrame:WaitForChild("ContainerDetails")

local LeftButton = ItemDetails:WaitForChild("LeftBtn")
local RightButton = ItemDetails:WaitForChild("RightBtn")
local RewardsListUI = ItemDetails:WaitForChild("PackItems")

local BuyBtnConnection
local ContainerDetailsEnterConnection
local ContainerDetailsExitConnection
local ActualCategorieLoad
local CloseUIConnection

local xSize = 0
local count = 0

local Settings = {
    tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, true),
    orignalBtnSize = ItemDetails.BuyBtn.Size
}

ShowUiBtn.Activated:Connect(function()
    ShopFrame.Visible = not ShopFrame.Visible
end)

ShopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    WalkSpeedModule.SetControlsPlayerAndCreature(not ShopFrame.Visible)
	ToolsModule.EnableOtherUI(not ShopFrame.Visible, {"ShopItemsGui"})

end)

local function ReplaceString(str)
	local newStr, replaced = string.gsub(str, "Frame", "")
	return newStr
end

local function SetBehaviorQuickButtonsShopRessources(ui)
    for _, child in pairs(ui:GetChildren()) do
        if child.Name == "ShowPurchase" then
            child.Activated:Connect(function()
                if ActualCategorieLoad ~= "Ressources" then
                    ToolsModule.DepopulateTypeOfItemFrom("Frame", ShopFrame.ItemsList)
                    PopulateItemsList("Ressources")
                    ItemDetails.Visible = false
                    ShopFrame.Background.Visible = false
                    ShopFrame.ButtonsList:WaitForChild("Ressources").BackgroundTransparency = 0
                    for _, v in pairs(ShopFrame.ButtonsList:GetChildren()) do
                        if v:IsA("TextButton") then
                            if v ~= ShopFrame.ButtonsList.Ressources then
                                v.BackgroundTransparency = 0.4
                            end
                        end
                    end
                    ActualCategorieLoad = "Ressources"
                end
                ShopFrame.Visible = not ShopFrame.Visible
            end)
        end
    end
end

SetBehaviorQuickButtonsShopRessources(PlayerInfosGui.PreviewPlayer.TotalHarvestsFrame)
SetBehaviorQuickButtonsShopRessources(PlayerInfosGui.PreviewPlayer.SparksFrame)

for _, Frame in pairs(PlayerInfosGui.PreviewPlayer:GetChildren()) do
    if not Frame:IsA("Frame") then continue end
    for _, Child in pairs(Frame:GetChildren()) do
        if Child.Name == "ShowPurchase" and Child:FindFirstChild("UICorner") then
            Child.MouseEnter:Connect(function()
                local Data = PlayerDataModule.LocalData[ReplaceString(Frame.Name)]
                Frame.ValueTxt.Text = ToolsModule.DotNumber(Data)
            end)
            Child.MouseLeave:Connect(function()
                local Data = PlayerDataModule.LocalData[ReplaceString(Frame.Name)]
                Frame.ValueTxt.Text = ToolsModule.AbbreviateNumber(Data)
            end)
        end
    end
end

function CheckDateAvailableItem(item)
    local Date = DateTime.now():ToIsoDate()
    Date = string.gsub(Date,"%-", "_")
    Date = string.gsub(Date,"[%s%p%a]+", "_" )
    Date = Date:split("_")

    local ActualDateNumber =tonumber(Date[1]..Date[2]..Date[3])

    if item.AvailableItem then
        if item.DateEndAvailable == 0 then
             return "Unlimited" --alaway available in shop
        else
            if item.DateStartAvailable ~= 0 then
                --check if date start correspond with actual date for availble item and is during or not available now
                if ActualDateNumber >= item.DateStartAvailable  and ActualDateNumber <= item.DateEndAvailable then
                    local dayBeforeEnd = item.DateEndAvailable - ActualDateNumber
                    return dayBeforeEnd.." d"
                end
                if ActualDateNumber < item.DateStartAvailable then
                    return "Comming Soon"
                end
            end
        end
    end
    return "Unvailable"
end

function CheckDatePromoItem(item)
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
                local dayBeforeEnd = item.DateEndPromo - ActualDateNumber
                return dayBeforeEnd.." d"
            end
            if ActualDateNumber < item.DateStartPromo then
                return false
            end
        end
    end
end

local TypeOfGene = GetTypeOfGenes:InvokeServer()

local function GetItemType(objName)
	local typeGene = ""
    for index, value in pairs(TypeOfGene) do
        if string.lower(objName):match(string.lower(value)) then
            typeGene = TypeOfGene[index]
            break
        elseif string.lower(objName):match(string.lower("Tattoo")) then
            typeGene = "Tattoo"
            break
        end
    end

    -- If typeGene not setup, check if obj name contain Pack to identifiy package of genes
    if typeGene == "" then
        if string.lower(objName):match(string.lower("pack")) then
            typeGene = "Pack"
        end
    end

    return typeGene
end

function PopulateItemDetails(item)
    --if a preview button connection exist remove it for replace by new with new item selected
    if BuyBtnConnection then
        BuyBtnConnection:Disconnect()
    end
    if ContainerDetailsEnterConnection then
        ContainerDetailsEnterConnection:Disconnect()
    end
    if ContainerDetailsExitConnection then
        ContainerDetailsExitConnection:Disconnect()
    end

    if CloseUIConnection then
        CloseUIConnection:Disconnect()
    end

    ItemDetailsRegular.Visible = false
    ItemDetails.Visible = false

    if item.ItemType == "ContainerItem" or item.ItemType == "RandomContainerItem" then
        ItemDetails = ShopFrame.ItemPreview:WaitForChild("ItemDetails")
    else
        ItemDetails = ShopFrame.ItemPreview:WaitForChild("ItemDetailsRegular")
    end

    ItemDetails.ItemImg.Image = item.ImageID
    ItemDetails.NameField.Txt.Text = item.DisplayName
    ItemDetails.ItemType.Text = GetItemType(item.ItemName)

    --local itemType = GetItemType(item.DisplayName or item.ItemName)
    --ItemDetails.ItemType.Text = GetItemName(item.DisplayName, item.ItemName)--itemType == "" and "Pack" or itemType
    --ItemDetails.BackgroundColor3 = RarityColor[item.Rarity]

    local d = CheckDateAvailableItem(item)
    if d == "Unvailable" or d == "Comming Soon" then
        ItemDetails.AvailableField.Visible = false
        ItemDetails.BuyBtn.Active = false
        ItemDetails.BuyBtn.AutoButtonColor = false
        ItemDetails.BuyBtn.BackgroundColor3 = Color3.fromRGB(110, 110, 110)
        ItemDetails.BuyBtn.BuyTxt.Text = d
    else
        ItemDetails.AvailableField.Txt.Text = d
        ItemDetails.AvailableField.Visible = false
        ItemDetails.BuyBtn.Active = true
        ItemDetails.BuyBtn.AutoButtonColor = true
        ItemDetails.BuyBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ItemDetails.BuyBtn.BuyTxt.Text = "Buy"
    end

    ItemDetails.PriceField.IconImg.Image = GameDataModule.DropCollectables[item.CurrencyType]

    local isPromo = CheckDatePromoItem(item)    
    if item.Promo ~= 0 then
        if isPromo then
            ItemDetails.PromoTimeField.Visible = false
            ItemDetails.PromoField.Visible = true
            ItemDetails.PromoTimeField.Txt.Text = isPromo

            ItemDetails.PriceField.Txt.Text = item.Price - (math.round(item.Price*(item.Promo/100)))
            ItemDetails.PromoField.Txt.Text = item.Promo.." %"
        else
            ItemDetails.PromoField.Visible = false
            ItemDetails.PromoTimeField.Visible = false
            ItemDetails.PriceField.Txt.Text = item.Price
        end
    else
        ItemDetails.PromoField.Visible = false
        ItemDetails.PromoTimeField.Visible = false
        ItemDetails.PriceField.Txt.Text = item.Price
    end

    local FieldLength = string.len(item.Price)
    local TextSize = math.clamp((FieldLength / 11), 0, 0.8)
    ItemDetails.PriceField.Txt.Size = UDim2.fromScale(TextSize, 1)

    RightButton.Visible = false
    LeftButton.Visible = false
    ItemDetails.Visible = true
    ShopFrame.Background.Visible = true

    local DefaultSize = ItemDetails.BuyBtn.Size

    BuyBtnConnection = ItemDetails.BuyBtn.Activated:Connect(function()        
        ItemDetails.BuyBtn.BuyTxt.Text = "Waiting..."
        ItemDetails.BuyBtn.Active = false
        ItemDetails.BuyBtn.ImageColor3 = Color3.fromRGB(83, 201, 19)

        local Size = DefaultSize
        TweenService:Create(
            ItemDetails.BuyBtn,
            Settings.tweenInfo,
            {Size = UDim2.fromScale(Size.X.Scale * 1.1, Size.Y.Scale * 1.15)}
        ):Play()

        local result = buyShopItemPlayer:InvokeServer(item, ActualCategorieLoad)
        task.delay(0.3, function()
            if result then
                Fireworks.new(ItemDetails.Position)
                ItemDetails.BuyBtn.BuyTxt.Text = "Buy"
                ItemDetails.BuyBtn.Active = true
            else
                ItemDetails.BuyBtn.BuyTxt.Text = "Fail buy..."
                ItemDetails.BuyBtn.Active = true
            end
            ItemDetails.BuyBtn.Size = DefaultSize
            ItemDetails.BuyBtn.ImageColor3 = Color3.fromRGB(87, 214, 17)
        end)
    end)

    CloseUIConnection = ItemDetails.CloseUI.Activated:Connect(function()
        ShopFrame.Background.Visible = false
    end)    

    ItemDetails.PackItems.Visible = false

    --ContainerDetailsEnterConnection = ItemDetails.ItemImg.MouseEnter:Connect(function()
        if item.ItemType == "ContainerItem" or item.ItemType == "RandomContainerItem" then            
            ToolsModule.DepopulateTypeOfItemFrom("Frame", ItemDetails.PackItems)
            local result = getShopItemsContainer:InvokeServer(item)
            if result then
                count = 0
                for _, value in pairs(result) do
                    count += 1
                    local clone = TemplateFolder.ContainerItemDetailsTemplate:Clone()
                    clone.Details.ItemImg.Image = value.Image
                    clone.Details.ItemType.Text = GetItemType(value.DisplayName)
                    clone.Parent = ItemDetails.PackItems
                    clone.Visible = true
                    xSize = clone.Size.X.Scale
                end

                ItemDetails.PackItems.UIListLayout.HorizontalAlignment = count >= 3 and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center
                ItemDetails.PackItems.Visible = true

                RightButton.Visible = count >= 3
                LeftButton.Visible = false
            end
        end
    --end)

   --[[ContainerDetailsExitConnection = ItemDetails.ItemImg.MouseLeave:Connect(function()
        ContainerDetails.Visible = false
    end)]]
end

LeftButton.Activated:Connect(function()
    local space = 3/count--math.round((xSize/count)*100)/100
    local t = math.clamp(RewardsListUI.CanvasPosition.X - (RewardsListUI.AbsoluteSize.X + (RewardsListUI.AbsoluteSize.X * space)), 0, RewardsListUI.AbsoluteCanvasSize.X)
    RightButton.Visible = true
    RewardsListUI.CanvasPosition = Vector2.new(t,0)
    LeftButton.Visible = t ~= 0
end)

--Button right allow to move and scroll list of daily reward
RightButton.Activated:Connect(function()
    local space = 3/count--math.round((xSize/count)*100)/100
    local t = math.clamp(RewardsListUI.CanvasPosition.X + (RewardsListUI.AbsoluteSize.X + (RewardsListUI.AbsoluteSize.X * space)), 0, RewardsListUI.AbsoluteCanvasSize.X)
    LeftButton.Visible = true
    RewardsListUI.CanvasPosition = Vector2.new(t,0)
    print(RewardsListUI.CanvasPosition.X , RewardsListUI.CanvasSize.X.Offset - RewardsListUI.AbsoluteSize.X)
    RightButton.Visible = RewardsListUI.CanvasPosition.X < (RewardsListUI.CanvasSize.X.Offset - RewardsListUI.AbsoluteSize.X)
end)

ShopFrame.Background.Activated:Connect(function()
    ItemDetailsRegular.Visible = false
    ItemDetails.Visible = false
    ShopFrame.Background.Visible = false
end)

function PopulateItemsList(categorieName)
    local result = getShopItemsDatas:InvokeServer(categorieName)
    if result then
        --print("RESULT OK", result)
        for categorie, items in pairs(result) do
            for _, itemData in pairs(items) do
                local ui = TemplateFolder:FindFirstChild("ShopItemTemplate"):Clone()
                
                ui.Name = itemData.ItemName
                ui.ItemPrice.PriceType.Value = itemData.CurrencyType
                ui.ItemPrice.IconImg.Image = GameDataModule.DropCollectables[itemData.CurrencyType]
                ui.ItemImg.Image = itemData.ImageID
                ui.ItemName.Text = itemData.DisplayName

                --[[local missingName = GetItemName(itemData.DisplayName, itemData.ItemName)
                ui.ItemType.Text = missingName]]

                local itemType = GetItemType(itemData.ItemName)
                ui.ItemType.Text = itemType

                ui.ItemPromo.Text = itemData.Promo.." %"
                if itemData.Promo == 0 then
                    ui.ItemPromo.Visible = false
                else
                    local isPromo = CheckDatePromoItem(itemData)
                    if not isPromo then
                        ui.ItemPromo.Visible = false
                    end
                end

                if ui.ItemPromo.Visible then
                    ui.ItemPrice.PriceTxt.Text = itemData.Price - (math.round(itemData.Price*(itemData.Promo/100)))
                else
                    ui.ItemPrice.PriceTxt.Text = itemData.Price
                end

                ui.ItemValid.Text = "Valid : "..CheckDateAvailableItem(itemData)

                --ui.BackgroundColor3 = RarityColor[itemData.Rarity]
                ui.LayoutOrder = itemData.Price
                ui.Visible = true
                ui.Parent = ShopFrame.ItemsList

                ui.Button.Activated:Connect(function()
                    PopulateItemDetails(itemData)
                end)
            end
        end
    end
end

function MakeCategoriesButtons()
    ToolsModule.DepopulateTypeOfItemFrom("TextButton", ShopFrame.ButtonsList)
    local result = GetDataOf:InvokeServer("Categorie")
    if result then
        if not ActualCategorieLoad then
            --set first by default if not setup
            local littleOrder = 999
            for dataName, data in pairs(result) do
                if data.LayoutOrder < littleOrder then
                    littleOrder = data.LayoutOrder
                    ActualCategorieLoad = dataName
                end
            end
        end

        for dataName, data in pairs(result) do
            local btnClone = TemplateFolder.CatBtnTemplate:Clone()
            btnClone.Name = dataName
            btnClone.Text = dataName
            btnClone.Parent = ShopFrame.ButtonsList
            btnClone.ImageLabel.Image = data.Image
            btnClone.LayoutOrder = data.LayoutOrder
            btnClone.Visible = true
        end
    end
end

ShopFrame.ButtonsList.ChildAdded:Connect(function(btn) -- Categories button behavior
    if btn:IsA("TextButton") then
        btn.Activated:Connect(function()
            if btn.Name ~= ActualCategorieLoad then
                --[[ ShopFrame.ItemsList.Visible = false
                ShopFrame.LoadText.Visible = true ]]
                ToolsModule.DepopulateTypeOfItemFrom("Frame", ShopFrame.ItemsList)
                PopulateItemsList(btn.Name)
                ItemDetails.Visible = false
                ItemDetailsRegular.Visible = false
                ShopFrame.Background.Visible = false
                --[[ ShopFrame.ItemsList.Visible = true
                ShopFrame.LoadText.Visible = false ]]
                btn.BackgroundTransparency = 0
                for _, v in pairs(ShopFrame.ButtonsList:GetChildren()) do
                    if v:IsA("TextButton") then
                        if v ~= btn then
                            v.BackgroundTransparency = 0.4
                        end
                    end
                end
                ActualCategorieLoad = btn.Name
            end
        end)
    end
end)

MakeCategoriesButtons()
PopulateItemsList(ActualCategorieLoad)

UpdateClientsShopUI.OnClientEvent:Connect(function()
    ToolsModule.DepopulateTypeOfItemFrom("Frame", ShopFrame.ItemsList)
    MakeCategoriesButtons()
    PopulateItemsList(ActualCategorieLoad)
end)

--[[
    This event is call by positionning object when we try to place object who quantity is 0, we redirect player to the store and the good item to
    buy it ! event call from MapsManagerModule when check quantity to instanciate or not the item.
]]
ShowShopUIForItem.OnClientEvent:Connect(function(itemName)
    local categorie
    local itemDatas

    --search categorie where is the item null quantity
    local result = getShopItemsDatas:InvokeServer()
    if result then
        local founded = false
        for catID, catData in pairs(result) do
            for Itemid, itemData in pairs(catData) do
                if Itemid == itemName then
                    categorie = catID
                    itemDatas = itemData
                    founded = true
                    break
                end
            end
            if founded then
                break
            end
        end
    end

    if itemDatas then
        --populate and show the item founded in the good categorie to allow player buy it
        ToolsModule.DepopulateTypeOfItemFrom("Frame", ShopFrame.ItemsList)
        PopulateItemsList(categorie)
        PopulateItemDetails(itemDatas)
        ShopFrame.Visible = true
    else
        --if here gene search are not found because not available in shop or no longer existing so informe player with popup
        RemoteEvent.ShowPopupAlert:FireServer("Not found",
            "This gene are no longer available in shop.",
            ToolsModule.AlertPriority.Annoucement,
            nil,
            ToolsModule.AlertTypeButton.OK
        )
    end
end)