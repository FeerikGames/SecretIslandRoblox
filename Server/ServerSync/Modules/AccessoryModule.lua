local AccessoryModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

--Require
local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")

--Remote Function
local RemoteFuncFolder = ReplicatedStorage.SharedSync.RemoteFunction
local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local Assets = ReplicatedStorage.SharedSync.Assets

local NewItemInventory = Instance.new("RemoteEvent", RemoteEventFolder)
NewItemInventory.Name = "NewItemInventory"
local RemoveItemInventory = Instance.new("RemoteEvent", RemoteEventFolder)
RemoveItemInventory.Name = "RemoveItemInventory"

local EquippAccessoryEvent:RemoteFunction = Instance.new("RemoteFunction", RemoteFuncFolder)
EquippAccessoryEvent.Name = "EquippAccessory"
local UnEquippAccessoryEvent:RemoteFunction = Instance.new("RemoteFunction", RemoteFuncFolder)
UnEquippAccessoryEvent.Name = "UnEquippAccessory"
local CloneAccessoryForPreview = Instance.new("RemoteFunction", RemoteFuncFolder)
CloneAccessoryForPreview.Name = "CloneAccessoryForPreview"

local GetStockItemDataServer = BindableFunction.GetStockItemDataServer

local Players = game:GetService("Players")

--When player connect to the game we complet is inventory with shop item he have already buy as Invenotry Data player in datastore
local function playerAdded(player)
    player.CharacterAdded:wait()
    task.wait(1) --!!CARE!! its make because a fantom backpack is created on reserved server and destroy quickly, so we lose reference to instance backpack, so wait 1s to let fantom backpack destroy and server game create real backpack player
    local InventoryDataPlayer = PlayerDataModule:Get(player, "Inventory")
    local inventoryPlayer = player:WaitForChild("Backpack")

    if InventoryDataPlayer then
        --check all item data inventory for player and search and clone physics object into backpack player
        for objName, val in pairs(InventoryDataPlayer) do
            --search into stock folders the item need
            local obj = GetObjectOfItemInStorage(objName)
            if obj then
                local clone = obj:Clone()
                clone.Parent = inventoryPlayer

                --check and update data information from stock if are changed
                local itemDataStock = GetStockItemDataServer:Invoke(objName)
                if itemDataStock then
                    if itemDataStock["Rarity"] ~= val.Rarity then
                        val.Rarity = itemDataStock["Rarity"]
                    end
                    if itemDataStock["ImageID"] ~= val.ImageID then
                        val.ImageID = itemDataStock["ImageID"]
                    end
                end

                clone:SetAttribute("Modeller", 0)
                clone:SetAttribute("StockQuantity",val.Quantity)
                clone:SetAttribute("ImageID",val.ImageID)
                clone:SetAttribute("Rarity",val.Rarity)
                clone:SetAttribute("ObjectType", val.ObjectType or "")

                --check if item quantity are not nil to setup it in UI Inventory or not, if nil we don't need to show item in inventory
                if val.Quantity > 0 then
                    --Send data to client side allow to update inventory UI list items
                    local itemData={}
                    itemData[objName] = {
                        Quantity = val.Quantity,
                        Rarity = val.Rarity,
                        ImageID = val.ImageID,
                        ObjectType = clone:GetAttribute("ObjectType")
                    }
                    NewItemInventory:FireClient(player, itemData)
                end
            end
        end
        PlayerDataModule:Set(player, InventoryDataPlayer, "Inventory")
    end
end

RemoveItemInventory.OnServerEvent:Connect(function(player, itemName)
    AccessoryModule:DecrementItemQuantityInventoryDataBy(player, itemName, 1)
end)

--[[
    This function call when new item is give for player to make a data save side on server and create object instance reference into backpack player.
    A Client Event is call to update the ui inventory for player see item in inventory.
]]
function AccessoryModule:SetNewItemInventoryData(player, itemName, quantity, rarity, imageID, displayName, object)
    local inventoryPlayer = player.Backpack

    -- Setup object 3D into backpack inventory of player for make reference instance
    local cloneObjectBuy = object:Clone()
    cloneObjectBuy.Parent = inventoryPlayer
    cloneObjectBuy:SetAttribute("StockQuantity",quantity)
    cloneObjectBuy:SetAttribute("ImageID", imageID)
    cloneObjectBuy:SetAttribute("Rarity", rarity)
    if object.Parent:FindFirstChild("ObjectType") then
        cloneObjectBuy:SetAttribute("ObjectType", object.Parent.ObjectType.Value)
    end

    -- Setup data object into data inventory player
    local InventoryDataPlayer = PlayerDataModule:Get(player, "Inventory")
    InventoryDataPlayer[itemName] = {
        DisplayName = displayName,
        Quantity = quantity,
        Rarity = rarity,
        ImageID = imageID,
        ObjectType = cloneObjectBuy:GetAttribute("ObjectType")
    }
    PlayerDataModule:Set(player, InventoryDataPlayer, "Inventory")

    local itemData={}
    itemData[itemName]=InventoryDataPlayer[itemName]
    NewItemInventory:FireClient(player, itemData)
end

--[[
    This function allow to update quantity of a item in data inventory of player when buy new one of existing item,
    check call in ShopModule.
]]
function AccessoryModule:IncrementItemQuantityInventoryDataBy(player, itemName, valueIncrement)
    local InventoryDataPlayer = PlayerDataModule:Get(player, "Inventory")
    InventoryDataPlayer[itemName].Quantity = InventoryDataPlayer[itemName].Quantity + valueIncrement
    local obj = AccessoryModule:CheckItemAreInInventory(player, itemName)
    obj:SetAttribute("StockQuantity", InventoryDataPlayer[itemName].Quantity) --update object inventory quantity

    PlayerDataModule:Set(player, InventoryDataPlayer, "Inventory")

    --Send client side the new data updated for item, parameter true allow to say on client side it's a update
    local itemData={}
    itemData[itemName]=InventoryDataPlayer[itemName]
    NewItemInventory:FireClient(player, itemData, true)
end

function AccessoryModule:DecrementItemQuantityInventoryDataBy(player, itemName, valueDecrement)
    local InventoryDataPlayer = PlayerDataModule:Get(player, "Inventory")
    InventoryDataPlayer[itemName].Quantity = InventoryDataPlayer[itemName].Quantity - valueDecrement --update data inventory quantity
    local obj = AccessoryModule:CheckItemAreInInventory(player, itemName)
    obj:SetAttribute("StockQuantity", InventoryDataPlayer[itemName].Quantity) --update object inventory quantity

    if InventoryDataPlayer[itemName].Quantity <= 0 then
        --Not destroy element from inventory because we need to keep track of item used by player. Just setting to quantity 0 and if is this case, we not show in inventory UI only
        --but keep track item in backpack.

        --[[ --remove from dictionnary data
        InventoryDataPlayer[itemName] = nil
        --remove from playerData folder serverside
        local objData = ServerStorage.PlayerData[player.UserId].Inventory:FindFirstChild(itemName)
        if objData then
            objData:Destroy()
        end
        --remove from backpack
        local obj = inventoryPlayer:FindFirstChild(itemName)
        if obj then
            obj:Destroy()
        end ]]

        --send information destroy to client side for remove item from inventory ui
        RemoveItemInventory:FireClient(player, itemName)
    else
        --Send client side the new data updated for item, parameter true allow to say on client side it's a update
        local itemData={}
        itemData[itemName]=InventoryDataPlayer[itemName]
        NewItemInventory:FireClient(player, itemData, true)
    end

    PlayerDataModule:Set(player, InventoryDataPlayer, "Inventory")
end

function AccessoryModule:CheckItemAreInInventory(player, itemName)
    local inventoryPlayer = player.Backpack
    local obj = inventoryPlayer:FindFirstChild(itemName)
    if obj then
        return obj
    end

    return false
end

--[[
    Function allow to clone the good object accessory, make auto placement of it and apply to the actuel summoned Animal of player
]]
local function CreateAccessoryObject(creatureModel, creatureType, creatureID, accessory)
    if creatureModel then
        -- Check if actual creature invoked are the modified creature
        if creatureID ~= creatureModel.CreatureID.Value then
            return
        end

        if accessory:FindFirstChild("MultipleAccessory") then
            local FolderMultipleAccessory = Instance.new("Folder", creatureModel)
			FolderMultipleAccessory.Name = accessory.Name

            -- If we found this folder it's special accessory need to be multiple clone of it (example feet accessory need on 4 feet)
            for _, part in pairs(accessory.MultipleAccessory:GetChildren()) do
                local clone:MeshPart = accessory:Clone()
                clone.Parent = FolderMultipleAccessory
            
                -- Check if actual animal have a size effect active or not to apply the good size ratio
                if creatureModel.PrimaryPart:GetAttribute("SizeEffectActive") then
                    local SizeRatio = creatureModel.PrimaryPart:GetAttribute("SizeRatio")
                    ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
                end
        
                local attachment:Attachment = Instance.new("Attachment", clone)
                local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
                constraint.Attachment0 = attachment
        
                -- Search bone reference instance
                for _, bone in pairs(creatureModel.RootPart:GetDescendants()) do
                    if bone:IsA("Bone") then
                        if bone.Name == part[creatureType].BoneNameRef.Value then
                            constraint.Attachment1 = bone
                        end
                    end
                end
        
                -- Apply reference position, orientation & size
                clone.Size = part[creatureType].Size.Value
                local rotX = math.rad(part[creatureType].Orientation.Value.X)
                local rotY = math.rad(part[creatureType].Orientation.Value.Y)
                local rotZ = math.rad(part[creatureType].Orientation.Value.Z)
                attachment.CFrame = CFrame.new(part[creatureType].Position.Value) * CFrame.fromOrientation(rotX,rotY,rotZ)
            end
        else
            -- Behavior if we not found folder multiple accessory we juste make classic setup for one mesh accessory
            local clone:MeshPart = accessory:Clone()
            clone.Parent = creatureModel
        
            -- Check if actual animal have a size effect active or not to apply the good size ratio
            if creatureModel.PrimaryPart:GetAttribute("SizeEffectActive") then
                local SizeRatio = creatureModel.PrimaryPart:GetAttribute("SizeRatio")
                ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
            end
    
            local attachment:Attachment = Instance.new("Attachment", clone)
            local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
            constraint.Attachment0 = attachment
    
            -- Search bone reference instance
            for _, bone in pairs(creatureModel.RootPart:GetDescendants()) do
                if bone:IsA("Bone") then
                    if bone.Name == clone[creatureType].BoneNameRef.Value then
                        constraint.Attachment1 = bone
                    end
                end
            end
    
            -- Apply reference position, orientation & size
            clone.Size = clone[creatureType].Size.Value
            local rotX = math.rad(clone[creatureType].Orientation.Value.X)
            local rotY = math.rad(clone[creatureType].Orientation.Value.Y)
            local rotZ = math.rad(clone[creatureType].Orientation.Value.Z)
            attachment.CFrame = CFrame.new(clone[creatureType].Position.Value) * CFrame.fromOrientation(rotX,rotY,rotZ)
        end

    end
end

--[[
    This function have 2 behaviors :
        - If is new equipp accessory on animal, we check animal don't have already equipped this accessory and if it's okay we
        adding the id of accessory into table of list accessory apply to animal and save creature data. After we decrement quantity value in inventory accessory of
        player.
        - If not new, the call is make for create and render the accessory on summoned animal of player so we just make creation of instance accessory.
]]
function AccessoryModule.EquippAccessory(player, accessoryID, creatureID, isNew)
    local inventoryPlayer = player.Backpack
    local accessory = inventoryPlayer:FindFirstChild(accessoryID)
    local creature:Model = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..player.Name)
    
    if accessory and creatureID ~= "" then
        local creatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)

        if not creatureData["Accessory"] then
            creatureData.Accessory = {}
        end

        if isNew then
            if not table.find(creatureData.Accessory, accessoryID) then
                CreateAccessoryObject(creature, creatureData.CreatureType, creatureID, accessory)

                table.insert(creatureData.Accessory, accessoryID)
                PlayerDataModule:Set(player, creatureData, "CreaturesCollection."..creatureID)
    
                AccessoryModule:DecrementItemQuantityInventoryDataBy(player, accessoryID, 1)

                return true
            end
        else
            CreateAccessoryObject(creature, creatureData.CreatureType, creatureID, accessory)
        end
    end
end
EquippAccessoryEvent.OnServerInvoke = AccessoryModule.EquippAccessory

--[[
    This function allows you to de-equip an accessory with an animal by updating the quantities on the corresponding item and updating
    the invoked model if it exists and corresponds to the modified animal.
]]
function AccessoryModule.UnEquippAccessory(player, accessoryID, creatureID)
    local inventoryPlayer = player.Backpack
    local accessory = inventoryPlayer:FindFirstChild(accessoryID)
    local creature:Model = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..player.Name)
    
    if accessory and creatureID ~= "" then
        local creatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
        local exist = table.find(creatureData.Accessory, accessoryID)

        if exist then
            if creature and creatureID == creature.CreatureID.Value then
                -- Remove object accessory if creature are invoked
                creature:FindFirstChild(accessoryID):Destroy()
            end

            table.remove(creatureData.Accessory, exist)
            PlayerDataModule:Set(player, creatureData, "CreaturesCollection."..creatureID)

            AccessoryModule:IncrementItemQuantityInventoryDataBy(player, accessoryID, 1)

            return true
        end
    end
end
UnEquippAccessoryEvent.OnServerInvoke = AccessoryModule.UnEquippAccessory

--[[
    This function go to search into storage game, the part object or model corresponding with the object needed
]]
function GetObjectOfItemInStorage(itemName)
    for _, child in pairs(game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):GetChildren()) do
        if child.Name == itemName then
            return child
        end
    end
end

--[[
    It's for clone on server side preview item need by player into backpack
    and if cloned is true it's for clean model clone after client clone on this side the item model
]]
local tempClone = {}
CloneAccessoryForPreview.OnServerInvoke = function(player, itemName, cloned)
    if not cloned then
        for _, child in pairs(game.ServerStorage.ServerStorageSync:WaitForChild("ShopItemsStorage"):GetChildren()) do
            if child.Name == itemName then
                tempClone[player.UserId] = child:Clone()
                tempClone[player.UserId].Parent = player.Backpack
                return tempClone[player.UserId]
            end
        end
    else
        if tempClone[player.UserId] then
            tempClone[player.UserId]:Destroy()
            tempClone[player.UserId] = nil
        end
    end
end

game.Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    playerAdded(player)
end

return AccessoryModule