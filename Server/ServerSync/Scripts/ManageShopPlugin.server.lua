--[[
    This plugin is only for the Feerik Games Studio to manage shop of game Horse Prototype with the specific spec of game.
]]

local CollapsibleTitledSection = require(game.ServerScriptService.StudioWidgets:FindFirstChild("CollapsibleTitledSection"))
local VerticallyScalingListFrame = require(game.ServerScriptService.StudioWidgets:FindFirstChild("VerticallyScalingListFrame"))
local LabeledMultiChoice = require(game.ServerScriptService.StudioWidgets:FindFirstChild("LabeledMultiChoice"))
local VerticalScrollingFrame = require(game.ServerScriptService.StudioWidgets:FindFirstChild("VerticalScrollingFrame"))
local LabeledCheckbox = require(game.ServerScriptService.StudioWidgets:FindFirstChild("LabeledCheckbox"))
local LabeledTextInput = require(game.ServerScriptService.StudioWidgets:FindFirstChild("LabeledTextInput"))

-- Create a new toolbar section titled
local toolbar = plugin:CreateToolbar("Manage Shop Plugin")
-- Add a toolbar button
local manageShopButton = toolbar:CreateButton("Manage Shop Game", "Manage Shop Game", "rbxassetid://4458901886")
-- Make button clickable even if 3D viewport is hidden
manageShopButton.ClickableWhenViewportHidden = true

local interface = plugin:CreateDockWidgetPluginGui(
    "Manage Shop GUI",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,true,true,200,44,200,44)
)
interface.Title = "Manage GAME SHOP"

manageShopButton.Click:Connect(function()
    
end)

local choicesTypeShopItem = {
	{Id = "SingleItem", Text = "Single Item"},
	{Id = "ContainerItem", Text = "Container Items"},
	{Id = "RandomContainerItem", Text = "Random Container Items"}
}

local choicesCurrencyType = {
	{Id = "Ecus", Text = "Ecus"},
	{Id = "Feez", Text = "Feez"}
}

local choicesRarity = {
	{Id = "Common", Text = "Common"},
	{Id = "Uncommon", Text = "Uncommon"},
    {Id = "Rare", Text = "Rare"},
    {Id = "UltraRare", Text = "UltraRare"},
    {Id = "Legendary", Text = "Legendary"},
}

local scrollFrame = VerticalScrollingFrame.new("suffix")

local listFrame = VerticallyScalingListFrame.new("suffix")
local collapseCreateItemSection = CollapsibleTitledSection.new("suffix", "Create Shop Item Section", true, true, true)

local ItemTypeMultiChoice = LabeledMultiChoice.new("ItemType", "Type Of Item", choicesTypeShopItem, 1)
ItemTypeMultiChoice:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()

local AvailableItemCheckbox = LabeledCheckbox.new(
	"AvailableItem", -- name suffix of gui object
	"Available Item", -- text beside the checkbox
	true, -- initial value
	false -- initially disabled?
)
AvailableItemCheckbox:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()

local ItemNameInput = LabeledTextInput.new(
	"ItemName", -- name suffix of gui object
	"Item Name", -- title text
	"" -- default value
)
ItemNameInput:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()
--remove special character from here
ItemNameInput:SetValueChangedFunction(function(newValue)
	local CurrentText = newValue
    CurrentText = CurrentText:gsub("[^%w%s_]+", "")
    ItemNameInput:SetValue(CurrentText)
end)

local PriceInput = LabeledTextInput.new(
	"Price", -- name suffix of gui object
	"Price", -- title text
	"0" -- default value
)
PriceInput:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()
--Make only number for this field
PriceInput:SetValueChangedFunction(function(newValue)
	local CurrentText = newValue
    CurrentText = CurrentText:gsub("[^%w%s_]+", "")
    CurrentText = CurrentText:gsub("%a", "")
    PriceInput:SetValue(CurrentText)
end)

local CurrencyTypeMultiChoice = LabeledMultiChoice.new("CurrencyType", "Currency Type", choicesCurrencyType, 1)
CurrencyTypeMultiChoice:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()

local RarityMultiChoice = LabeledMultiChoice.new("Rarity", "Item Rarity", choicesRarity, 1)
RarityMultiChoice:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()

local DateStartPromoInput = LabeledTextInput.new(
	"DateStartPromo", -- name suffix of gui object
	"Date Start Promotion", -- title text
	"0" -- default value
)
DateStartPromoInput:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()
--Make only number for this field
DateStartPromoInput:SetValueChangedFunction(function(newValue)
	local CurrentText = newValue
    CurrentText = CurrentText:gsub("[^%w%s_]+", "")
    CurrentText = CurrentText:gsub("%a", "")
    DateStartPromoInput:SetValue(CurrentText)
end)

local DateEndPromoInput = LabeledTextInput.new(
	"DateEndPromo", -- name suffix of gui object
	"Date End Promotion", -- title text
	"0" -- default value
)
DateEndPromoInput:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()
--Make only number for this field
DateEndPromoInput:SetValueChangedFunction(function(newValue)
	local CurrentText = newValue
    CurrentText = CurrentText:gsub("[^%w%s_]+", "")
    CurrentText = CurrentText:gsub("%a", "")
    DateEndPromoInput:SetValue(CurrentText)
end)

local PriceInput = LabeledTextInput.new(
	"Price", -- name suffix of gui object
	"Price", -- title text
	"0" -- default value
)
PriceInput:GetFrame().Parent = collapseCreateItemSection:GetContentsFrame()
--Make only number for this field
PriceInput:SetValueChangedFunction(function(newValue)
	local CurrentText = newValue
    CurrentText = CurrentText:gsub("[^%w%s_]+", "")
    CurrentText = CurrentText:gsub("%a", "")
    PriceInput:SetValue(CurrentText)
end)


listFrame:AddChild(collapseCreateItemSection:GetSectionFrame()) -- add child to expanding VerticallyScalingListFrame
listFrame:AddBottomPadding() -- add padding to VerticallyScalingListFrame
listFrame:GetFrame().Parent = scrollFrame:GetContentsFrame() -- scroll content will be the VerticallyScalingListFrame
scrollFrame:GetSectionFrame().Parent = interface -- set the section parent