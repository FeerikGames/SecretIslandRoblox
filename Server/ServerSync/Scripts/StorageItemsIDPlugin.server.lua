--[[
    This plugin are make only for the Feerik Games Studio to manage items ID of game Horse Prototype in storage items.
]]
local StudioWidgets = game.ServerScriptService:WaitForChild("StudioWidgets")
local CollapsibleTitledSection = require(StudioWidgets:FindFirstChild("CollapsibleTitledSection"))
local VerticallyScalingListFrame = require(StudioWidgets:FindFirstChild("VerticallyScalingListFrame"))
local LabeledMultiChoice = require(StudioWidgets:FindFirstChild("LabeledMultiChoice"))
local VerticalScrollingFrame = require(StudioWidgets:FindFirstChild("VerticalScrollingFrame"))
local LabeledCheckbox = require(StudioWidgets:FindFirstChild("LabeledCheckbox"))
local LabeledTextInput = require(StudioWidgets:FindFirstChild("LabeledTextInput"))
local CustomTextButton = require(StudioWidgets:FindFirstChild("CustomTextButton"))

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")

local ConfigFolder
if not game.ServerStorage:FindFirstChild("ManageStorageItemsIDPlugin") then
    ConfigFolder = Instance.new("Configuration", game.ServerStorage)
    ConfigFolder.Name = "ManageStorageItemsIDPlugin"
    ConfigFolder:SetAttribute("CanChangeName", false)
    ConfigFolder:SetAttribute("IntegrityInProcess", false)
    ConfigFolder:SetAttribute("AddingInProcess", false)
else
    ConfigFolder = game.ServerStorage.ManageStorageItemsIDPlugin
end

local connections = {}
local testEvent
if not ConfigFolder:FindFirstChild("TestEvent") then
    testEvent = Instance.new("BindableEvent", ConfigFolder)
    testEvent.Name = "TestEvent"
else
    testEvent = ConfigFolder.TestEvent
end

--[[ testEvent.Event:Connect(function(child)
    print("TEST BINDABLE EVENT")
    if not connections[child] then
        local childName = child.Name --for never change it
        connections[child] = child.Changed:Connect(function(property)
            if property == "Name" then
                print("CHANGE FROM UniqueItemsBehaviorPlugin")
                onChangedNameItem(child, childName)
            end
        end)
    end
end)
 ]]
-- Create a new toolbar section titled
local toolbar = plugin:CreateToolbar("Manage Storage Items ID Plugin")
-- Add a toolbar button
local pluginButton = toolbar:CreateButton("Manage Storage Items ID", "Manage  Storage", "rbxassetid://4458901886")

-- Make button clickable even if 3D viewport is hidden
pluginButton.ClickableWhenViewportHidden = true

local interface = plugin:CreateDockWidgetPluginGui(
    "Manage Shop GUI",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,true,true,200,44,200,44)
)
interface.Title = "Manage Game Storage"
interface.Enabled = false

local storageItems = game:GetService("ServerStorage"):FindFirstChild("ServerStorageSync"):FindFirstChild("ShopItemsStorage")

function onChangedNameItem(item, originName)
    if not ConfigFolder:GetAttribute("CanChangeName") then
        item.Name = originName
    end
end

function UniqueItemsBehaviorPlugin(child)
    local baseName = child.Name:split("//:")
    child.Name = baseName[1].."//:"..storageItems:GetAttribute("IndexIdRef")
    storageItems:SetAttribute("IndexIdRef", storageItems:GetAttribute("IndexIdRef") + 1)

    if not connections[child] then
        local childName = child.Name --for never change it
        --[[ connections[child] = child.Changed:Connect(function(property)
            if property == "Name" then
                print("CHANGE FROM UniqueItemsBehaviorPlugin")
                onChangedNameItem(child, childName)
            end
        end) ]]
    end
end

function onPluginButtonClickedAddSelectedChilds()
    local newSelected = {}
    for _, obj in pairs(Selection:Get()) do
        if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Model") then
            local clone = obj:Clone()
            clone.Parent = workspace
            table.insert(newSelected, clone)
        else
            warn(obj.Name.." is not a item can make into storage !")
        end
    end
    Selection:Set(newSelected)

    for _, obj in pairs(Selection:Get()) do
        print(obj.Name.." ARE IN SELECTED PLAYER")
        UniqueItemsBehaviorPlugin(obj)
        obj.Parent = storageItems
    end
    ChangeHistoryService:SetWaypoint("checkpoint")

    --after add item check integrity of all
    CheckIntegrityStorageItems()
end

local function SearchDuplicataOf(item)
    print("DUPLICATA", item)
    UniqueItemsBehaviorPlugin(item)
    print("DUPLICATA Renamed to :", item)
    --[[ if not connections[item] then
        print("DUPLICATA", item)
        UniqueItemsBehaviorPlugin(item)
        print("DUPLICATA Renamed to :", item)
    end ]]
end

function CheckIntegrityStorageItems()
    if not ConfigFolder:GetAttribute("IntegrityInProcess") then
        ConfigFolder:SetAttribute("IntegrityInProcess", true)
        local ok = true
        for _, item in pairs(storageItems:GetChildren()) do
            local baseName = item.Name:split("//:")
            if not baseName[2] then
                --warn(item.Name, "NOT A CORRECT NAME ITEM STORAGE")
                UniqueItemsBehaviorPlugin(item)
                ok = false
            else
                --here object have a good string id but, now check if not have duplicate of it
                ConfigFolder:SetAttribute("CanChangeName", true)
                SearchDuplicataOf(item)
                ConfigFolder:SetAttribute("CanChangeName", false)
            end
        end

        if ok then
            warn("ALL ITEM ARE OKAY, INTEGRITY OF STORAGE STATUS : OK.")
        end
        ConfigFolder:SetAttribute("IntegrityInProcess", false)
        ChangeHistoryService:SetWaypoint("checkpoint")
    else
        warn("ANOTHER INSTANCE OF CHECK INTEGRITY IN PROCESS !")
    end
end

function CheckIntegrityStorageItem(item)
    local baseName = item.Name:split("//:")
    if baseName[2] then
        ConfigFolder:SetAttribute("CanChangeName", true)
        SearchDuplicataOf(item)
        ConfigFolder:SetAttribute("CanChangeName", false)
    end

    ChangeHistoryService:SetWaypoint("checkpoint")
end

pluginButton.Click:Connect(function()
    interface.Enabled = not interface.Enabled
end)

local listFrame = VerticallyScalingListFrame.new("suffix")

local AddSelectedChildsBtn = CustomTextButton.new(
	"AddSelectedChildsBtn", -- name of the gui object
	"Make Selection into Storage" -- the text displayed on the button
)

local CheckIntegrityStorageBtn = CustomTextButton.new(
	"CheckIntegrityStorageBtn", -- name of the gui object
	"Check integrity of Storage Items" -- the text displayed on the button
)

-- use the :getButton() method to return the ImageButton gui object
local AddSelectedChildsBtnObject = AddSelectedChildsBtn:GetButton()
AddSelectedChildsBtnObject.Size = UDim2.new(1, 0, 0, 50)
local CheckIntegrityStorageBtnObject = CheckIntegrityStorageBtn:GetButton()
CheckIntegrityStorageBtnObject.Size = UDim2.new(1, 0, 0, 50)

AddSelectedChildsBtnObject.MouseButton1Click:Connect(onPluginButtonClickedAddSelectedChilds)
CheckIntegrityStorageBtnObject.MouseButton1Click:Connect(CheckIntegrityStorageItems)

listFrame:AddChild(AddSelectedChildsBtnObject)
listFrame:AddChild(CheckIntegrityStorageBtnObject)

listFrame:AddBottomPadding()
listFrame:GetFrame().Parent = interface

--at starting studio and plugin we make event on child for cancel rename of object
--[[ for _, child in pairs(storageItems:GetChildren()) do
    if not connections[child] then
        local childName = child.Name --for never change it
        connections[child] = child.Changed:Connect(function(property)
            if property == "Name" then
                print("CHANGE FROM INIT")
                onChangedNameItem(child, childName)
            end
        end)
    end
end ]]

storageItems.ChildAdded:Connect(function(child)
    if not connections[child] then
        --CheckIntegrityStorageItem(child)
    end
end)

print("INIT PLUGIN")