local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game.Players.LocalPlayer

-- Check first if player is admin or owner and create a dashboard admin if yes else do nothing
if Player:GetRankInGroup(12349377) >= 250 then
    local CollectionService = game:GetService("CollectionService")
    --RequireModule
    local ToolsModule = require("ToolsModule")
    local UIProviderModule = require("UIProviderModule")

    --Remote Function
    local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
    local RemoteEventFolder = ReplicatedStorage.RemoteEvent

    local SendStockItemDataEvent = RemoteFuncFolder:WaitForChild("SendStockItemDataEvent")
    local ClientAskServerObjStorage = RemoteEventFolder:WaitForChild("ClientAskServerObjStorage")
    local ShowItemInViewPort = RemoteEventFolder:WaitForChild("ShowItemInViewPort")
    local GetStockItemData = RemoteFuncFolder:WaitForChild("GetStockItemData")
    local SaveStockItemData = RemoteFuncFolder:WaitForChild("SaveStockItemData")
    local GetDataOf = RemoteFuncFolder:WaitForChild("GetDataOf")
    local SaveDataOf = RemoteFuncFolder:WaitForChild("SaveDataOf")

    --UI
    local ShopItemsGui = UIProviderModule:GetUI("ShopItemsGui")
    local StockItemsFrame = ShopItemsGui:WaitForChild("StockItemsFrame")
    local TemplateFolder = ShopItemsGui:WaitForChild("Template")
    local ListsFrame = StockItemsFrame:WaitForChild("ListsFrame")
    local ItemsList = ListsFrame:WaitForChild("ItemsList")
    local ItemsNoSetupList = ListsFrame:WaitForChild("ItemsNoSetupList")
    local ItemDetails = StockItemsFrame.ItemEdit:WaitForChild("ItemDetails")
    local ContainerEdit = StockItemsFrame:WaitForChild("ContainerEdit")
    local CategoriesEdit = StockItemsFrame:WaitForChild("CategoriesEdit")
    local ObjectTypeEdit = StockItemsFrame:WaitForChild("ObjectTypeEdit")
    local QuickSearchList = ContainerEdit:WaitForChild("QuickSearchList")

    local loading = false
    local saved = true
    local selectedItemID = nil

    local ItemDetailsDefaultValue = {}
    for _, child in pairs(ItemDetails:GetChildren()) do
        if child:FindFirstChild("Input") then
            ItemDetailsDefaultValue[child.Name] = child.Input.Text
        elseif child:FindFirstChild("DropDown") then
            ItemDetailsDefaultValue[child.Name] = child.DropDown.SelectedOption.Value
            ItemDetailsDefaultValue[child.Name] = child.DropDown.Selection.Text
        elseif child:FindFirstChild("CheckBox") then
            ItemDetailsDefaultValue[child.Name] = child.CheckBox.Check.Value
        end
    end

    local result = SendStockItemDataEvent:InvokeServer()
    if result then
        for _, objID in pairs(result) do
            local clone = TemplateFolder.ItemBtn:Clone()
            clone.Name = objID
            clone.Text = objID:split("//:")[1]

            clone.Activated:Connect(function()
                if not loading then
                    if not saved then
                        local popup = TemplateFolder.PopupTemplate:Clone()
                        popup.Parent = ItemDetails.Parent
                        popup.Visible = true
                        ItemDetails.Visible = false
                        popup.SaveBtn.Activated:Connect(function()
                            popup.Visible = false
                            SaveItemDatas()
                            ClientAskServerObjStorage:FireServer(objID)
                            PopulateItemDetails(objID)
                            saved = true
                            popup:Destroy()
                            selectedItemID = objID
                        end)
                        popup.QuitBtn.Activated:Connect(function()
                            popup.Visible = false
                            ClientAskServerObjStorage:FireServer(objID)
                            PopulateItemDetails(objID)
                            saved = true
                            popup:Destroy()
                        end)
                    else
                        selectedItemID = objID
                        ClientAskServerObjStorage:FireServer(objID)
                        PopulateItemDetails(objID)
                        saved = true
                    end
                else
                    warn("Waiting other datas are already in loading ...")
                end
                print("SELECTED ITEM ID IS", selectedItemID)
            end)

            local result = GetStockItemData:InvokeServer(objID)
            if result then
                if not result.DateSetupItemStock then
                    clone.Parent = ItemsNoSetupList
                else
                    clone.Parent = ItemsList
                end
            else
                clone.Parent = ItemsNoSetupList
            end
            clone.Visible = true
        end
    end

    local function MakeDateFormat()
        print("SETUP DATE ITEM ENTER IN STOCK")
        local Date = DateTime.now():ToIsoDate()
        Date = string.gsub(Date,"%-", "_")
        Date = string.gsub(Date,"[%s%p%a]+", "_" )
        Date = Date:split("_")
        local ActualDateNumber = tonumber(Date[1]..Date[2]..Date[3])
        return ActualDateNumber
    end

    function InitDropdownData(item, dataName)
        ToolsModule.DepopulateTypeOfItemFrom("TextButton", item.DropDown.Menu)
        CollectionService:RemoveTag(item.DropDown,"DropDown")

        local cloneDrop = item.DropDown:Clone()
        cloneDrop.Name = "DropDown"
        item.DropDown:Destroy()

        cloneDrop.Parent = item
        
        local result = GetDataOf:InvokeServer(dataName)
        if result then
            for dataName, name in pairs(result) do
                local btnClone = TemplateFolder.DropdownBtnTemplate:Clone()
                btnClone.Name = dataName
                btnClone.Text = dataName
                btnClone.Parent = cloneDrop.Menu
            end
            CollectionService:AddTag(cloneDrop,"DropDown")
        end
    end

    function ResetItemDetailsToDataValue(datas)
        for _, child in pairs(ContainerEdit.ItemsList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end

        for index, value in pairs(datas) do
            --check different type of data : Input, Dropbox, checkbox
            if ItemDetails:FindFirstChild(index) then
                if ItemDetails[index]:FindFirstChild("Input") then
                    ItemDetails[index].Input.Text = value
                elseif ItemDetails[index]:FindFirstChild("DropDown") then
                    ItemDetails[index].DropDown.SelectedOption.Value = value
                    ItemDetails[index].DropDown.Selection.Text = value
                elseif ItemDetails[index]:FindFirstChild("CheckBox") then
                    ItemDetails[index].CheckBox.Check.Value = value
                end
            end

            if index == "Items" then
                --if its container setup container list items
                if ItemDetails.ItemType.DropDown.SelectedOption.Value == "ContainerItem" or ItemDetails.ItemType.DropDown.SelectedOption.Value == "RandomContainerItem" then
                    for _, item in pairs(value) do
                        AddItemToContainerList(item)
                    end
                end
            end
        end
    end

    function PopulateItemDetails(itemID)
        StockItemsFrame.LoadText.Visible = true
        ItemDetails.Visible = false
        loading = true

        InitDropdownData(ItemDetails.ItemCategorie, "Categorie")
        InitDropdownData(ItemDetails.ObjectType, "ObjectType")

        ResetItemDetailsToDataValue(ItemDetailsDefaultValue)
        
        ItemDetails.DisplayName.Input.Text = itemID:split("//:")[1]
        ItemDetails.ItemName.Input.Text = itemID
        local result = GetStockItemData:InvokeServer(itemID)
        if result then
            ResetItemDetailsToDataValue(result)
        end

        StockItemsFrame.LoadText.Visible = false
        ItemDetails.Visible = true
        loading = false
    end

    function MakeInputNumberOnly(input)
        local CurrentText = input.Text
        CurrentText = CurrentText:gsub("[^%w%s_]+", "")
        CurrentText = CurrentText:gsub("%a", "")
        input.Text = CurrentText
    end

    function CheckNoRecursiveContainer(item)
        local isOk = true
        if item.ItemName == ItemDetails.ItemName.Input.text then
            return false
        end
        if item.ItemType == "ContainerItem" or item.ItemType == "RandomContainerItem" then
            for _, name in pairs(item.Items) do
                if name == ItemDetails.ItemName.Input.text then
                    return false
                else
                    local result = GetStockItemData:InvokeServer(name)
                    if result then
                        isOk = CheckNoRecursiveContainer(result)
                    end
                end
            end
        end

        return isOk
    end

    function AddItemToContainerList(itemName)
        if not ContainerEdit.ItemsList:FindFirstChild(itemName) then
            local result = GetStockItemData:InvokeServer(itemName)
            if result then
                if not CheckNoRecursiveContainer(result) then
                    warn("CAN'T ADD THIS ITEM BECAUSE RECURSIVE CONTENT CONTAINERS ITEMS !!")
                    return
                end
                local clone = TemplateFolder.ContainerItemEditAddTemplate:Clone()
                clone.Name = result.ItemName
                clone.Visible = true
                clone.Parent = ContainerEdit.ItemsList

                for index, value in pairs(result) do
                    if clone:FindFirstChild(index) then
                        clone[index].Text = value
                    end
                end

                ShowItemInViewPort:FireServer(result.ItemName, ContainerEdit.AddItemContainer)

                local obj = ContainerEdit.AddItemContainer:WaitForChild(result.ItemName)
                obj.Parent = clone.ViewportFrame
                local target
                if obj:IsA("Model") then
                    target = obj.PrimaryPart
                else
                    target = obj
                end

                if target:IsA("Decal") then
                    clone.ViewportFrame.ImageLabel.Image = target.Texture
                    clone.ViewportFrame.ImageLabel.Visible = true
                else
                    clone.ViewportFrame.ImageLabel.Visible = false
                    local viewportCamera = Instance.new("Camera")
                    clone.ViewportFrame.CurrentCamera = viewportCamera
                    viewportCamera.Parent = clone.ViewportFrame
                    local cameraOffset = Vector3.new(0, 5, 6)
                    viewportCamera.Focus = target.CFrame
                    local rotatedCFrame = CFrame.Angles(0, 0, 0)
                    rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
                    viewportCamera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
                    viewportCamera.CFrame = CFrame.new(viewportCamera.CFrame.Position, target.Position)
                end

                clone.DeleteBtn.Activated:Connect(function()
                    clone:Destroy()
                end)
            else
                warn(itemName.." not found in stock !")
            end
        else
            warn(itemName.." are already in this container list !")
        end
    end

    function PopulateQuickListSearch(item, clone)
        local result = GetStockItemData:InvokeServer(item.Name)
        if result then
            for index, value in pairs(result) do
                if clone:FindFirstChild(index) then
                    clone[index].Text = value
                end
            end

            ShowItemInViewPort:FireServer(result.ItemName, QuickSearchList.Waiter)

            local obj = QuickSearchList.Waiter:WaitForChild(result.ItemName)
            obj.Parent = clone.ViewportFrame
            local target
            if obj:IsA("Model") then
                target = obj.PrimaryPart
            else
                target = obj
            end

            if target:IsA("Decal") then
                clone.ViewportFrame.ImageLabel.Image = target.Texture
                clone.ViewportFrame.ImageLabel.Visible = true
            else
                clone.ViewportFrame.ImageLabel.Visible = false
                local viewportCamera = Instance.new("Camera")
                clone.ViewportFrame.CurrentCamera = viewportCamera
                viewportCamera.Parent = clone.ViewportFrame
                local cameraOffset = Vector3.new(0, 5, 6)
                viewportCamera.Focus = target.CFrame
                local rotatedCFrame = CFrame.Angles(0, 0, 0)
                rotatedCFrame = CFrame.new(target.Position) * rotatedCFrame
                viewportCamera.CFrame = rotatedCFrame:ToWorldSpace(CFrame.new(cameraOffset))
                viewportCamera.CFrame = CFrame.new(viewportCamera.CFrame.Position, target.Position)
            end
        end
    end

    function SaveItemDatas()
        local itemDatas = {}
        local itemID = selectedItemID
        itemDatas["ItemName"] = selectedItemID

        for _, child in pairs(ItemDetails:GetChildren()) do
            if child:IsA("Frame") then
                --check different type of data : Input, Dropbox, checkbox
                if child:FindFirstChild("Input") then
                    itemDatas[child.Name] = child.Input.Text
                elseif child:FindFirstChild("DropDown") then
                    itemDatas[child.Name] = child.DropDown.SelectedOption.Value
                elseif child:FindFirstChild("CheckBox") then
                    itemDatas[child.Name] = child.CheckBox.Check.Value
                end
            end
        end

        --if player don't have specifique name of item, we use by default the itemID
        if itemDatas["DisplayName"] == "" then
            itemDatas["DisplayName"] = itemID
        end

        --for container object we have to add Items part in data
        if ItemDetails.ItemType.DropDown.SelectedOption.Value == "ContainerItem" or ItemDetails.ItemType.DropDown.SelectedOption.Value == "RandomContainerItem" then
            local items = {}
            for _, child in pairs(ContainerEdit.ItemsList:GetChildren()) do
                if child:IsA("Frame") then
                    table.insert(items, child.Name)
                    child:Destroy()
                end
            end
            itemDatas["Items"] = items
        end

        --make date for first time edit item infos (with that we know when item are added and setup in stock)
        local result = GetStockItemData:InvokeServer(itemID)
        if result then
            if not result.DateSetupItemStock then
                itemDatas["DateSetupItemStock"] = MakeDateFormat()
                ItemsNoSetupList:FindFirstChild(itemID).Parent = ItemsList
            else 
                itemDatas["DateSetupItemStock"] = result.DateSetupItemStock
            end
        else
            itemDatas["DateSetupItemStock"] = MakeDateFormat()
            ItemsNoSetupList:FindFirstChild(itemID).Parent = ItemsList
        end

        --Make a date for save when the item are maked available in shop
        if result then
            if not result.LastDateItemAvailableInShop then
                if ItemDetails.AvailableInShop.CheckBox.Check.Value then
                    itemDatas["LastDateItemAvailableInShop"] = MakeDateFormat()
                end
            else
                if result.AvailableInShop then
                    itemDatas["LastDateItemAvailableInShop"] = result.LastDateItemAvailableInShop
                else
                    if ItemDetails.AvailableInShop.CheckBox.Check.Value then
                        itemDatas["LastDateItemAvailableInShop"] = MakeDateFormat()
                    else
                        itemDatas["LastDateItemAvailableInShop"] = result.LastDateItemAvailableInShop
                    end
                end
            end
        else
            if ItemDetails.AvailableInShop.CheckBox.Check.Value then
                itemDatas["LastDateItemAvailableInShop"] = MakeDateFormat()
            end
        end

        print("DATA READY TO SEND SERVER IS", itemDatas)
        SaveStockItemData:InvokeServer(itemID, itemDatas)
        saved = true
        ItemDetails.Visible = false
    end

    ItemDetails.SaveBtn.Activated:Connect(SaveItemDatas)

    ItemDetails.ContainerItems.ShowContainer.Activated:Connect(function()
        ContainerEdit.Visible = true
        ListsFrame.Visible = false
        ItemDetails.Visible = false
    end)

    ContainerEdit.CloseUI.Activated:Connect(function()
        ContainerEdit.Visible = false
        ListsFrame.Visible = true
        ItemDetails.Visible = true
    end)

    ContainerEdit.AddItemContainer.AddBtn.Activated:Connect(function()
        --[[ saved = false
        AddItemToContainerList(ContainerEdit.AddItemContainer.Input.Text) ]]
    end)

    ItemDetails.ItemType.DropDown.SelectedOption.Changed:Connect(function()
        saved = false
        if ItemDetails.ItemType.DropDown.SelectedOption.Value == "ContainerItem" or ItemDetails.ItemType.DropDown.SelectedOption.Value == "RandomContainerItem" then
            ItemDetails.ContainerItems.Visible = true
        else
            ItemDetails.ContainerItems.Visible = false
        end
    end)

    ItemDetails.DateEndAvailable.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateEndAvailable.Input)
    end)

    ItemDetails.DateStartAvailable.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateStartAvailable.Input)
    end)

    ItemDetails.DateEndPromo.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateEndPromo.Input)
    end)

    ItemDetails.DateStartPromo.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateStartPromo.Input)
    end)

    ItemDetails.Price.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.Price.Input)
    end)

    ItemDetails.Promo.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.Promo.Input)
    end)

    ItemDetails.QuantityMaxByPlayer.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.QuantityMaxByPlayer.Input)
    end)

    --### QUICK SEARCH PART ###
    local function SearchQuickItemStock(searchID)
        for _, item in pairs(ListsFrame.ItemsList:GetChildren()) do
            if item:IsA("TextButton") then
                local exist = QuickSearchList:FindFirstChild(item.Name)
                if string.match(string.lower(item.Name), string.lower(searchID)) then
                    exist.Visible = true
                else
                    exist.Visible = false
                end
            end
        end
    end

    local function SetupQuickSearchItems()
        for _, item in pairs(ListsFrame.ItemsList:GetChildren()) do
            if not item:IsA("UIListLayout") then
                local clone = TemplateFolder.QuickSearchItem:Clone()
                clone.Name = item.Name
                clone.Parent = QuickSearchList
                PopulateQuickListSearch(item, clone)
                clone.AddBtn.Activated:Connect(function()
                    saved = false
                    AddItemToContainerList(item.Name)
                end)
            end
        end
    end
    SetupQuickSearchItems()

    ContainerEdit.AddItemContainer.Input:GetPropertyChangedSignal("Text"):Connect(function()
        local CurrentText = ContainerEdit.AddItemContainer.Input.Text
        if CurrentText == "" then
            QuickSearchList.Visible = false
        else
            QuickSearchList.Visible = true
        end
        SearchQuickItemStock(CurrentText)
    end)

    --#########################

    --#### CATEGORIE & OBJECT TYPE PART ####
    local function CloneItem(dataName, data, List)
        local clone = TemplateFolder.CategorieAddTemplate:Clone()
        clone.Name = dataName
        clone.CatName.Text = dataName
        if data then
            clone.ImageInput.Visible = true
            clone.ImageInput.Text = data.Image

            clone.LayoutOrderInput.Visible = true
            clone.LayoutOrderInput.Text = data.LayoutOrder

            clone.ImageInput:GetPropertyChangedSignal('Text'):Connect(function()
                SaveDataOf:InvokeServer(dataName, {Image = clone.ImageInput.Text, LayoutOrder = tonumber(clone.LayoutOrderInput.Text)}, "save", "Categorie")
            end)
            clone.LayoutOrderInput:GetPropertyChangedSignal('Text'):Connect(function()
                MakeInputNumberOnly(clone.LayoutOrderInput)
                if clone.LayoutOrderInput.Text ~= "" then
                    SaveDataOf:InvokeServer(dataName, {Image = clone.ImageInput.Text, LayoutOrder = tonumber(clone.LayoutOrderInput.Text)}, "save", "Categorie")
                end
            end)
        end

        clone.DeleteBtn.Activated:Connect(function()
            local result
            if List.Name == "ObjectTypeList" then
                result = SaveDataOf:InvokeServer(dataName, "", "delete", "ObjectType")
            elseif List.Name == "List" then
                result = SaveDataOf:InvokeServer(dataName, data, "delete", "Categorie")
            end
            if result then
                clone:Destroy()
            end
        end)

        clone.Parent = List
        clone.Visible = true
    end

    local function CheckCanClone(Edit, dataType)
        local name = Edit.Add.Input.Text
        local result = SaveDataOf:InvokeServer(name, "", "check", dataType)
        if result then
            CloneItem(name, dataType=="Categorie" and "" or false, Edit.List)
            SaveDataOf:InvokeServer(name, {Image="",LayoutOrder=1}, "save", dataType)
        else
            warn("ERROR OR ALREADY EXISTING "..dataType.." DETECTED !")
        end
    end

    local result = GetDataOf:InvokeServer("Categorie")
    --warn("CATEGORIES DATA", result)
    if result then
        for dataName, data in pairs(result) do
            CloneItem(dataName, data, CategoriesEdit.List)
        end
    end
    
    local result = GetDataOf:InvokeServer("ObjectType")
    --print("OBJECT TYPE DATA", result)
    if result then
        for dataName, data in pairs(result) do
            CloneItem(dataName, false, ObjectTypeEdit.List)
        end
    end

    CategoriesEdit.Add.AddBtn.Activated:Connect(function()
        CheckCanClone(CategoriesEdit, "Categorie")
    end)

    ObjectTypeEdit.Add.AddBtn.Activated:Connect(function()
        CheckCanClone(ObjectTypeEdit, "ObjectType")
    end)
    --########################

    local function SelectedBtn(btn)
        for _, b in pairs(StockItemsFrame.ButtonsList:GetChildren()) do
            if b:IsA("TextButton") then
                if b == btn then
                    b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                else
                    b.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
                end
            end
        end
    end

    StockItemsFrame.ButtonsList:WaitForChild("StockBtn").Activated:Connect(function()
        CategoriesEdit.Visible = false
        ObjectTypeEdit.Visible = false
        ListsFrame.Visible = true
        if not saved then
            ItemDetails.Visible = true
        end
        SelectedBtn(StockItemsFrame.ButtonsList.StockBtn)
    end)

    StockItemsFrame.ButtonsList:WaitForChild("CategorieBtn").Activated:Connect(function()
        CategoriesEdit.Visible = true
        ObjectTypeEdit.Visible = false
        ListsFrame.Visible = false
        ItemDetails.Visible = false
        SelectedBtn(StockItemsFrame.ButtonsList.CategorieBtn)
    end)

    StockItemsFrame.ButtonsList:WaitForChild("ObjectTypeBtn").Activated:Connect(function()
        ObjectTypeEdit.Visible = true
        CategoriesEdit.Visible = false
        ListsFrame.Visible = false
        ItemDetails.Visible = false
        SelectedBtn(StockItemsFrame.ButtonsList.ObjectTypeBtn)
    end)

    ListsFrame.SetupBtn.Activated:Connect(function()
        ListsFrame.NotSetupBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        ListsFrame.SetupBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ItemsList.Visible = true
        ItemsNoSetupList.Visible = false
    end)

    ListsFrame.NotSetupBtn.Activated:Connect(function()
        ListsFrame.NotSetupBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ListsFrame.SetupBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
        ItemsList.Visible = false
        ItemsNoSetupList.Visible = true
    end)

    -- Event to listen text value of input search items name in list of setup or not setup item to search more quickly and setup quickly stock item of shop
    ListsFrame.SearchInput:GetPropertyChangedSignal('Text'):Connect(function()
        local list = ItemsList.Visible and ItemsList or ItemsNoSetupList
        for _, child in pairs(list:GetChildren()) do
            if child:IsA("TextButton") then
                if ListsFrame.SearchInput.Text == "" then
                    child.Visible = true
                else
                    if not string.lower(child.Name):match(string.lower(ListsFrame.SearchInput.Text)) then
                        child.Visible = false
                    end
                end
            end
        end
    end)
end