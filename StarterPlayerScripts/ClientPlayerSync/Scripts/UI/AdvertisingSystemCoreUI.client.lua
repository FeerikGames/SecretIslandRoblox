local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game.Players.LocalPlayer

-- Check first if player is admin or owner and create a dashboard admin if yes else do nothing
if Player:GetRankInGroup(12349377) >= 250 then
    local CollectionService = game:GetService("CollectionService")
    local HttpService = game:GetService("HttpService")
    --RequireModule
    local ToolsModule = require("ToolsModule")
    local UIProviderModule = require("UIProviderModule")

    --Remote Function
    local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
    local RemoteEventFolder = ReplicatedStorage.RemoteEvent

    local FilterMessageEvent = RemoteEventFolder.FilterMessage

    --UI
    local AdvertisingGui = UIProviderModule:GetUI("AdvertisingGui")
    local TemplateFolder = AdvertisingGui:WaitForChild("Template")
    local AdminFrame = AdvertisingGui:WaitForChild("AdminFrame")

    local ListsFrame = AdminFrame:WaitForChild("ListsFrame")
    local PublishList = ListsFrame:WaitForChild("ItemsList")
    local NotPublishList = ListsFrame:WaitForChild("ItemsNoPublishList")

    local ItemEdit = AdminFrame:WaitForChild("ItemEdit")
    local ItemDetails = ItemEdit:WaitForChild("ItemDetails")
    local ImagesContainer = ItemEdit.ImagesContainer

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

    local function ResetItemDetailsToDataValue(datas)
        for _, child in pairs(ImagesContainer.ItemsList:GetChildren()) do
            if not child:IsA("UIGridLayout") then
                child:Destroy()
            end
        end

        for _, child in pairs(ItemEdit.PreviewFrame:GetChildren()) do
            if child:IsA("ImageLabel") then
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

            if index == "Images" then
                for imgID, imgData in pairs(value) do
                    CreateImageBehavior(imgID, imgData)
                end
            end
        end
    end

    local function MakeDateFormat()
        print("SETUP DATE ITEM ENTER IN PUBLISH")
        local Date = DateTime.now():ToIsoDate()
        Date = string.gsub(Date,"%-", "_")
        Date = string.gsub(Date,"[%s%p%a]+", "_" )
        Date = Date:split("_")
        local ActualDateNumber = tonumber(Date[1]..Date[2]..Date[3])
        return ActualDateNumber
    end

    local function MakeInputNumberOnly(input)
        local CurrentText = input.Text
        CurrentText = CurrentText:gsub("[^%w%s_]+", "")
        CurrentText = CurrentText:gsub("%a", "")
        input.Text = CurrentText
    end

    --[[
        This method allow to save on server the data of save or new created advertise
    ]]
    local function SaveAdvertisingCreated()
        local itemDatas = {}
        if not selectedItemID then
            selectedItemID = HttpService:GenerateGUID(true)
        end

        itemDatas["ID"] = selectedItemID

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

        --make images part to save all data need to show image after
        local images = {}
        for _, child in pairs(ImagesContainer.ItemsList:GetChildren()) do
            if not child:IsA("UIGridLayout") then
                images[_] = {
                    ImgID = child.ImageID.Text,
                    PosX = tonumber(child.PosX.Text),
                    PosY = tonumber(child.PosY.Text),
                    SizeX = tonumber(child.SizeX.Text),
                    SizeY = tonumber(child.SizeY.Text),
                    Zindex = tonumber(child.Zindex.Text),
                    ScaleType = child.ScaleTypeDropDown.SelectedOption.Value
                }
            end
        end
        itemDatas["Images"] = images

        if itemDatas["AdvertisingName"] == "" then
            itemDatas["AdvertisingName"] = selectedItemID
        end
        itemDatas["DateSetupItemStock"] = MakeDateFormat()

        RemoteFuncFolder.AdvertisingSystem.SaveAdvertisingItemData:InvokeServer(itemDatas["ID"], itemDatas)
        saved = true
        ItemEdit.Visible = false

        PopulateDataUIList()
    end

    local function PopulateItemDetails(datas)
        --StockItemsFrame.LoadText.Visible = true
        ItemEdit.Visible = false
        loading = true

        ResetItemDetailsToDataValue(datas)

        local exist = ItemDetails:FindFirstChild("DuplicateBtn")
        if exist then
            exist:Destroy()
        end
        if datas.ID then
            print("Create a duplicate Button")
            local dupli = ItemDetails.SaveBtn:Clone()
            dupli.Name = "DuplicateBtn"
            dupli.Text = "Duplicate"
            dupli.Parent = ItemDetails
            dupli.Activated:Connect(function()
                --new id because new item
                selectedItemID = HttpService:GenerateGUID(true)
                --by default we make it into not publish
                ItemDetails.PublishedItem.CheckBox.Check.Value = false
                
                --save for create new item with all data of last execpt ID is new
                SaveAdvertisingCreated()

                --show not publish list where are duplicate new item
                PopulateDataUIList()
                ListsFrame.NotPublishedBtn.BackgroundTransparency = 0
                ListsFrame.PublishedBtn.BackgroundTransparency = 0.4
                PublishList.Visible = false
                NotPublishList.Visible = true

                --show new item
                ItemEdit.Visible = true

                --destroy button duplicate
                dupli:Destroy()
            end)
        end

        --StockItemsFrame.LoadText.Visible = false
        ItemEdit.Visible = true
        loading = false
    end

    --Init List published and not published
    function PopulateDataUIList()
        ToolsModule.DepopulateTypeOfItemFrom("TextButton", PublishList)
        ToolsModule.DepopulateTypeOfItemFrom("TextButton", NotPublishList)
        local result = RemoteFuncFolder.AdvertisingSystem.GetAdvertisingData:InvokeServer()
        if result then
            for ID, datas in pairs(result) do
                local clone = TemplateFolder.ItemBtn:Clone()
                clone.Name = ID
                clone.Text = datas["AdvertisingName"] and datas["AdvertisingName"] or ID

                clone.Activated:Connect(function()
                    if not loading then
                        print("LOAD")
                        if not saved then
                            print("NOT SAVE")
                            local popup = TemplateFolder.PopupTemplate:Clone()
                            popup.Parent = ItemEdit.Parent
                            popup.Visible = true
                            ItemEdit.Visible = false
                            popup.SaveBtn.Activated:Connect(function()
                                popup.Visible = false
                                SaveAdvertisingCreated()
                                PopulateItemDetails(datas)
                                saved = true
                                popup:Destroy()
                                selectedItemID = ID
                            end)
                            popup.QuitBtn.Activated:Connect(function()
                                popup.Visible = false
                                PopulateItemDetails(datas)
                                saved = true
                                popup:Destroy()
                            end)
                        else
                            print("SAVE")
                            selectedItemID = ID
                            PopulateItemDetails(datas)
                            saved = true
                        end
                    else
                        warn("Waiting other datas are already in loading ...")
                    end
                    print("SELECTED ITEM ID IS", selectedItemID)
                end)

                if datas.PublishedItem then
                    clone.Parent = PublishList
                else
                    clone.Parent = NotPublishList
                end

                clone.Visible = true
            end
        end
    end

    AdminFrame.CreateBtn.Activated:Connect(function()
        selectedItemID = nil
        local exist = ItemDetails:FindFirstChild("DuplicateBtn")
        if exist then
            exist:Destroy()
        end
        ResetItemDetailsToDataValue(ItemDetailsDefaultValue)
        ItemEdit.Visible = true
    end)

    ItemDetails.SaveBtn.Activated:Connect(SaveAdvertisingCreated)

    --####### PREVIEW ADVERTISING PART #########
    ItemDetails.TitleContent.Input:GetPropertyChangedSignal("Text"):Connect(function()
        saved = false
        ItemEdit.PreviewFrame.Title.Text = ItemDetails.TitleContent.Input.Text
    end)
    ItemDetails.BodyContent.Input:GetPropertyChangedSignal("Text"):Connect(function()
        saved = false
        ItemEdit.PreviewFrame.AdvertisingText.Text = ItemDetails.BodyContent.Input.Text
    end)
    --##########################################
    
    ItemDetails.DisplayTime.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DisplayTime.Input)
    end)
    ItemDetails.DateStartAvailable.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateStartAvailable.Input)
    end)
    ItemDetails.DateEndAvailable.Input:GetPropertyChangedSignal('Text'):Connect(function()
        saved = false
        MakeInputNumberOnly(ItemDetails.DateEndAvailable.Input)
    end)

    ItemDetails.Images.ShowContainer.Activated:Connect(function()
        ImagesContainer.Visible = true
        ItemDetails.Visible = false
    end)

    ListsFrame.PublishedBtn.Activated:Connect(function()
        PopulateDataUIList()
        ListsFrame.NotPublishedBtn.BackgroundTransparency = 0.4
        ListsFrame.PublishedBtn.BackgroundTransparency = 0
        PublishList.Visible = true
        NotPublishList.Visible = false
    end)

    ListsFrame.NotPublishedBtn.Activated:Connect(function()
        PopulateDataUIList()
        ListsFrame.NotPublishedBtn.BackgroundTransparency = 0
        ListsFrame.PublishedBtn.BackgroundTransparency = 0.4
        PublishList.Visible = false
        NotPublishList.Visible = true
    end)

    AdminFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if AdminFrame.Visible then
            PopulateDataUIList()
        end
    end)
    
    --##################### IMAGES SETUP PART ########################
    function CreateImageBehavior(imgID, imgData)
        local clone = TemplateFolder.ImgSetupTemplate:Clone()
        clone.Visible = true
        clone.Parent = ImagesContainer.ItemsList
        clone.ZIndex = 1
        for _, child in ipairs(ImagesContainer.ItemsList:GetChildren()) do
            if not child:IsA("UIGridLayout") then
                child.ZIndex += 1
            end
        end

        --create new images
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.fromScale(imgID and imgData.SizeX or 1, imgID and imgData.SizeY or 1)
        img.Position = UDim2.fromScale(imgID and imgData.PosX or 0, imgID and imgData.PosY or 0)
        img.Image = imgID and imgData.ImgID or ""
        img.ZIndex = imgID and imgData.Zindex or 1
        img.ScaleType = Enum.ScaleType.Fit
        img.BackgroundTransparency = 1
        img.Parent = ItemEdit.PreviewFrame

        clone.ImageID.Text = imgID and imgData.ImgID or ""
        clone.PosX.Text = imgID and imgData.PosX or 0
        clone.PosY.Text = imgID and imgData.PosY or 0
        clone.SizeX.Text = imgID and imgData.SizeX or 1
        clone.SizeY.Text = imgID and imgData.SizeY or 1
        clone.Zindex.Text = imgID and imgData.Zindex or 1
        clone.ScaleTypeDropDown.SelectedOption.Value = imgID and imgData.ScaleType or "Fit"

        clone.DeleteBtn.Activated:Connect(function()
            img:Destroy()
            clone:Destroy()
        end)
        
        clone.ImageID:GetPropertyChangedSignal("Text"):Connect(function()
            img.Image = clone.ImageID.Text
            saved = false
        end)
        clone.PosX:GetPropertyChangedSignal("Text"):Connect(function()
            img.Position = UDim2.fromScale(tonumber(clone.PosX.Text), tonumber(clone.PosY.Text))
            saved = false
        end)
        clone.PosY:GetPropertyChangedSignal("Text"):Connect(function()
            img.Position = UDim2.fromScale(tonumber(clone.PosX.Text), tonumber(clone.PosY.Text))
            saved = false
        end)
        clone.SizeX:GetPropertyChangedSignal("Text"):Connect(function()
            img.Size = UDim2.fromScale(tonumber(clone.SizeX.Text), tonumber(clone.SizeY.Text))
            saved = false
        end)
        clone.SizeY:GetPropertyChangedSignal("Text"):Connect(function()
            img.Size = UDim2.fromScale(tonumber(clone.SizeX.Text), tonumber(clone.SizeY.Text))
            saved = false
        end)
        clone.Zindex:GetPropertyChangedSignal("Text"):Connect(function()
            img.ZIndex = tonumber(clone.Zindex.Text)
            saved = false
        end)
        clone.ScaleTypeDropDown.SelectedOption.Changed:Connect(function()
            img.ScaleType = Enum.ScaleType[clone.ScaleTypeDropDown.SelectedOption.Value]
        end)
    end

    ImagesContainer.NewBtn.Activated:Connect(function()
        CreateImageBehavior()
    end)

    ImagesContainer.CloseBtn.Activated:Connect(function()
        ImagesContainer.Visible = false
        ItemDetails.Visible = true
    end)
    --################################################################

    --####### FILTERING TEXT #########
    FilterMessageEvent.OnClientEvent:Connect(function(message, sender, from)
        if sender.UserId == game.Players.LocalPlayer.UserId then
            if from == script.Name then
                
            end
        end
    end)
    --################################
end