local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local FilterManager = require("FilterManager")
local WalkSpeedModule = require("WalkSpeedModule")

--Remote
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local GenesCollectionGui = UIProviderModule:GetUI("GenesCollectionGui")
local ItemTemplate = GenesCollectionGui.Template.ItemTemplate
local UIBackground = GenesCollectionGui.Background
local ScrollingFrame = UIBackground.ScrollingFrame
local ShowUiBtn = AllButtonsMainMenusGui.SubMenu.GenesCollectionGuiBtn

--Filters
local FilterGui = UIProviderModule:GetUI("FilterGui")
local UIFilterBackground = FilterGui:WaitForChild("FilterBackground")
local GenesCollectionFilters = {"Type", "Rarity"}

--Init interface visibility
local function InitInterfaceVisibility()
	UIBackground.Visible = false
	ScrollingFrame.Visible = true
	FilterManager.CleanFilters()
end

local function ResetDataGenesCollectionUI()
	ToolsModule.DepopulateTypeOfItemFrom("Frame", ScrollingFrame)
end

local function PopulateDataGenesCollection()
	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	ResetDataGenesCollectionUI()
	
	for index, data in pairs(AvailableGenesCollection) do
		if FilterManager.CheckFiltersIsOk(data) then
			if data["NbUsed"] then
				if data["NbUsed"] > 0 then
					for i=1, data["NbUsed"] do
						local c = ItemTemplate:Clone()
						c.Visible = true
						c.Name = index
						c.ItemName.Text = data["DisplayName"]
						c.Parent = ScrollingFrame
						c.ItemImgBtn.Image = data["ImageID"]
						c.ItemImgBtn.ImageTransparency = 0.6
						c.ItemImgBtn.IsUsed.Visible = true
						c.ItemImgBtn.Quantity.Visible = false
					end
				end
				
				local totalItemShow = data["Quantity"] - data["NbUsed"]
				if totalItemShow >= 1 then
					local cloneItem = ItemTemplate:Clone()
					cloneItem.Visible = true
					cloneItem.Name = index
					cloneItem.ItemName.Text = data["DisplayName"]
					cloneItem.ItemImgBtn.Image = data["ImageID"]
					cloneItem.Parent = ScrollingFrame
					
					if totalItemShow == 1 then
						cloneItem.ItemImgBtn.Quantity.Visible = false
					end
					
					cloneItem.ItemImgBtn.Quantity.Text = tostring(totalItemShow)
					
					cloneItem.ItemImgBtn.Activated:Connect(function()
					end)
				end
			end
		end
	end
end

local function ActiveFilters()
	FilterManager.InitUIFilter("Genes", GenesCollectionFilters,true)
	for index, childs in pairs(UIFilterBackground:GetChildren()) do
		if childs.Name:match("DropDown") then
			for _, child in pairs(childs:GetChildren()) do
				if child:IsA("ImageButton") then
					child.Activated:Connect(function()
						PopulateDataGenesCollection()
					end)
				end
			end
		end
	end
end

InitInterfaceVisibility()

ShowUiBtn.Activated:Connect(function()
	UIBackground.Visible = not UIBackground.Visible
end)


UIBackground:GetPropertyChangedSignal("Visible"):Connect(function()
	PopulateDataGenesCollection()
	WalkSpeedModule.SetControlsPlayerAndCreature(not UIBackground.Visible)
	ToolsModule.EnableOtherUI(not UIBackground.Visible, {"GenesCollectionGui","FilterGui"})
	if UIBackground.Visible then
		ActiveFilters()
	else	
		InitInterfaceVisibility()
		FilterManager.CleanFilters()
	end
end)