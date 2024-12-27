local AccessoryCoreUIModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local Player = game:GetService("Players").LocalPlayer

--Require
local UIProviderModule = require("UIProviderModule")
local ToolsModule = require("ToolsModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local HorsesCollectionShopModule = require("HorsesCollectionShopModule")
local SoundControllerModule = require("SoundControllerModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.RemoteFunction
local RemoteEventFolder = ReplicatedStorage.RemoteEvent
local NewItemInventory = RemoteEventFolder:WaitForChild("NewItemInventory")
local RemoveItemInventory = RemoteEventFolder:WaitForChild("RemoveItemInventory")
local EquippAccessoryEvent:RemoteFunction = RemoteFuncFolder:WaitForChild("EquippAccessory")
local UnEquippAccessoryEvent:RemoteFunction = RemoteFuncFolder:WaitForChild("UnEquippAccessory")

--UI
local HorsesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
local UIDetailsHorse = HorsesCollectionGui.Background.DetailsHorse
local AccessoryGui = HorsesCollectionGui.Background.DetailsHorse.Infos2Frames.AccessoryUI
local TemplateFolder = HorsesCollectionGui:WaitForChild("Template")
local InventoryList = AccessoryGui.Inventory.List
local EquippedList = AccessoryGui.Equipped.List

local Assets = ReplicatedStorage.Assets

--[[
    This function creates an item in the list of accessories fitted to the animal. As well as the behavior of the button for de-equipping an accessory.
]]
local function CreateUnequippItemUI(accessoryID)
    local accessoryData = PlayerDataModule.LocalData.Inventory[accessoryID]
    local uiItem = TemplateFolder:WaitForChild("AccessoryItemTemplate"):Clone()
    uiItem.Name = accessoryID
    uiItem.Parent = EquippedList
    uiItem.Button.Active = false
    uiItem.BorderColor3 = ToolsModule.RarityColor[accessoryData.Rarity]
    uiItem.Button.Image = accessoryData.ImageID
    uiItem.QuantityText.Visible = false
    uiItem.Visible = true
    uiItem.Unequipp.Visible = true

    uiItem:AddTag("FloatingBox")
    uiItem:SetAttribute("FloatingBoxTitle", accessoryData.DisplayName)
    if accessoryData.Talent and accessoryData.Talent.ID then
        uiItem:SetAttribute("FloatingBoxContent", CreaturesTalentsModule.TalentsTable[accessoryData.Talent.ID].Desc:format(accessoryData.Talent.Value,"%"))
    else
        uiItem:SetAttribute("FloatingBoxContent", "Accessory")
    end

    uiItem.Unequipp.Activated:Connect(function()
        SoundControllerModule:CreateSound("Click")
        local result = UnEquippAccessoryEvent:InvokeServer(accessoryID, UIDetailsHorse.CreatureID.Value)
        if result then
            local creature:Model = workspace:FindFirstChild("RenderCreatureModelFolder"):FindFirstChild("CreatureModelCloneForRender")
            if creature then
                creature[accessoryID]:Destroy()
                uiItem:Destroy()
            end
        end
    end)
end
UnEquippAccessoryEvent.OnClientInvoke = function(accessoryID)
    local uiItem = EquippedList:FindFirstChild(accessoryID)
    if uiItem then
        local creature:Model = workspace:FindFirstChild("RenderCreatureModelFolder"):FindFirstChild("CreatureModelCloneForRender")
        if creature then
            creature[accessoryID]:Destroy()
            uiItem:Destroy()
        end
    end
end

--[[
    This function updates the interface list of accessories fitted to the animal, and sets up buttons
    to send a request to the server to remove an accessory.
]]
local function InitEquippedAccessory()
    if UIDetailsHorse.CreatureID.Value ~= "" then
        ToolsModule.DepopulateTypeOfItemFrom("Frame", EquippedList)
        local creatureData = PlayerDataModule.LocalData.CreaturesCollection[UIDetailsHorse.CreatureID.Value]
        if not creatureData["Accessory"] then
            return
        end

        for _, accessoryID in pairs(creatureData.Accessory) do
            CreateUnequippItemUI(accessoryID)
        end
    end
end

function AccessoryCoreUIModule.AccessoryButton()
    SoundControllerModule:CreateSound("Click")

    InitEquippedAccessory()
    HorsesCollectionShopModule.InitShopListAccessory()

    InventoryList.Visible = true
end

--[[
    This is a Remote Event execute function to create a item UI in Inventory. If the isUpdate Boolean parameter is given and it's true,
    so not create a ui item but search the item ui already exist and update data of him.
]]
NewItemInventory.OnClientEvent:Connect(function(item, isUpdate)
    for itemName, value in pairs(item) do
        -- Don't create item inventory ui if not min quantity
        if value.Quantity > 0 then
            local uiItemAlreadyExist = true
            local uiItem
    
            if not isUpdate then
                uiItem = TemplateFolder:WaitForChild("AccessoryItemTemplate"):Clone()
                uiItemAlreadyExist = false
            else
                uiItem = InventoryList:FindFirstChild(itemName)
                if not uiItem then
                    uiItem = TemplateFolder:WaitForChild("AccessoryItemTemplate"):Clone()
                    uiItemAlreadyExist = false
                end
            end
    
            uiItem.Name = itemName
            uiItem:SetAttribute("Modeller", 0)
            uiItem:SetAttribute("ObjectType", value.ObjectType)
            uiItem.Button.Image = value.ImageID
            uiItem.QuantityText.Text = value.Quantity
            uiItem.Visible = true
            uiItem.Parent = InventoryList
    
            if not uiItemAlreadyExist then
                uiItem:AddTag("FloatingBox")
                uiItem:SetAttribute("FloatingBoxTitle", value.DisplayName)
                if value.Talent and value.Talent.ID then
                    local content = CreaturesTalentsModule.TalentsTable[value.Talent.ID].Desc:format(value.Talent.Value,"%")
                    uiItem:SetAttribute("FloatingBoxContent", content)
                else
                    uiItem:SetAttribute("FloatingBoxContent", "Accessory")
                end

                -- Setup item behavior for equip creature summon with accessory selected in list ui
                uiItem.Button.Activated:Connect(function()
                    SoundControllerModule:CreateSound("Click")

                    -- If player click on button we apply accessory
                    local result = EquippAccessoryEvent:InvokeServer(itemName, UIDetailsHorse.CreatureID.Value, true)
    
                    -- Check if result to equipp accessory work and update model render in animal collection details
                    if result then
                        local creature:Model = workspace:FindFirstChild("RenderCreatureModelFolder"):FindFirstChild("CreatureModelCloneForRender")
                        if creature then
                            ToolsModule.CreateAccessoryClientSide(itemName, creature:GetAttribute("CreatureType"), creature)
    
                            -- Make UI equipped item for player can unquipp it
                            CreateUnequippItemUI(itemName)
                        end
                    end
                end)
            end
        end
    end
end)

--[[
    This remote event is call when server side launch a destroy event item, for remove from inventory UI.
]]
RemoveItemInventory.OnClientEvent:Connect(function(itemName)
    local ui = InventoryList:FindFirstChild(itemName)
    if ui then
        ui:Destroy()
    end
end)

-- Event receive when player buy accessory from shop in collection UI and need to auto equipp buy accessory
ReplicatedStorage.RemoteEvent.UpdateCollectionsUI.OnClientEvent:Connect(function(itemName)
    local result = EquippAccessoryEvent:InvokeServer(itemName, UIDetailsHorse.CreatureID.Value, true)

    -- Check if result to equipp accessory work and update model render in animal collection details
    if result then
        local creature:Model = workspace:FindFirstChild("RenderCreatureModelFolder"):FindFirstChild("CreatureModelCloneForRender")
        if creature then
            ToolsModule.CreateAccessoryClientSide(itemName, creature:GetAttribute("CreatureType"), creature)

            -- Make UI equipped item for player can unquipp it
            CreateUnequippItemUI(itemName)
        end
    end
end)

UIDetailsHorse.Infos2.AccessoryBtn.Activated:Connect(AccessoryCoreUIModule.AccessoryButton)

return AccessoryCoreUIModule