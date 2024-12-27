local FilterManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))

--Require
local UIProviderModule = require("UIProviderModule")
local GameDataModule = require("GameDataModule")

--Remote
local RemoteFunction = ReplicatedStorage.RemoteFunction

local FilterGui = UIProviderModule:GetUI("FilterGui")
local DropdownTemplate = FilterGui.Template.DropDown
local UIFilterBackground = FilterGui.FilterBackground
local FilterBtnTemplate = FilterGui.FilterBtn

local FilterApply = {}

local function MakeDropDownList(btnRef, index, datas, isHorizontal)
	if not UIFilterBackground:FindFirstChild(index.."DropDown") then
		local dropdown = Instance.new("Frame")
		dropdown.Name = index.."DropDown"
		dropdown.Parent = UIFilterBackground
		dropdown.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dropdown.BackgroundTransparency = 0.3
		dropdown.AutomaticSize = Enum.AutomaticSize.X
		--dropdown.BackgroundTransparency = 1
		--dropdown.BorderSizePixel = 1
		dropdown.Visible = false

		local uiStroke = Instance.new("UIStroke")
		uiStroke.Color = Color3.fromRGB(0, 108, 240)
		uiStroke.Thickness = 4.75
		uiStroke.Parent = dropdown
		
		local uiList = Instance.new("UIListLayout")
		uiList.Parent = dropdown
		uiList.FillDirection = isHorizontal and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
		uiList.HorizontalAlignment = isHorizontal and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left
		uiList.VerticalAlignment = Enum.VerticalAlignment.Center
		uiList.SortOrder = Enum.SortOrder.LayoutOrder

		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0.1,0)
		uiCorner.Parent = dropdown
		local nbElem = 0

		local uiStroke = Instance.new("UIStroke", dropdown)
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		uiStroke.Color = Color3.fromRGB(0, 108, 240)
		uiStroke.LineJoinMode = Enum.LineJoinMode.Round
		uiStroke.Thickness = 3
		
		for _, data in pairs(datas) do
			nbElem+=1
			local clone = FilterBtnTemplate:Clone()
			clone.Visible = true

			-- Make here specific check only for Rating type to adding layout order in showing buttons in filter order
			if index == "Rating" then
				clone.LayoutOrder = table.find(GameDataModule.RarityList, data)
			elseif index == "Race" then
				clone.LayoutOrder = table.find(GameDataModule.AnimalsRacesList, data)
			end

			clone.Name = index..clone.Name
			clone.Size = UDim2.fromScale(1,0.8)
			
			local val = Instance.new("StringValue")
			val.Name = index
			val.Value = tostring(data):gsub("^%l", string.upper) --WARNING for the moment only string work correctly boolean is use as stringValue think to modify this when try to improve system
			val.Parent = clone

			local iconsData = GameDataModule.FiltersCategorieIcons[index]
			if iconsData then
				clone.Image = iconsData.Data[val.Value]
			end

			clone.Parent = dropdown
			clone:SetAttribute("TextHover", tostring(data))

			clone.Activated:Connect(function()
				if not FilterApply[val.Name] then
					clone.Size = UDim2.fromScale(clone.Size.X.Scale, 1)
					FilterApply[val.Name] = val.Value
				elseif FilterApply[val.Name] ~= val.Value then
					for _, v in pairs(dropdown:GetChildren()) do
						local child = v:FindFirstChildWhichIsA("StringValue")
						if child then
							if child.Value == FilterApply[val.Name] then
								v.Size = UDim2.fromScale(v.Size.X.Scale, 0.8)
								clone.Size = UDim2.fromScale(clone.Size.X.Scale, 1)
								FilterApply[val.Name] = val.Value
								break
							end
						end
					end
				else
					FilterApply[val.Name] = nil
					clone.Size = UDim2.fromScale(clone.Size.X.Scale, 0.8)
				end
			end)
		end
		
		--Dynamics size for dropdown TODO->improve...
		dropdown.Size = isHorizontal and UDim2.fromScale(btnRef.Size.X.Scale, nbElem) or UDim2.fromScale(nbElem, btnRef.Size.Y.Scale)
		dropdown.Position = isHorizontal and UDim2.fromScale(0.119 * btnRef.LayoutOrder + 0.023, 1) or UDim2.fromScale(1.185, (dropdown.Size.Y.Scale * btnRef.LayoutOrder) + UIFilterBackground.List.UIListLayout.Padding.Scale*btnRef.LayoutOrder)
		for _, child in pairs(dropdown:GetChildren()) do
			if child:IsA("ImageButton") then
				child.Size = isHorizontal and UDim2.fromScale(child.Size.X.Scale, btnRef.Size.Y.Scale/nbElem) or UDim2.fromScale(1/nbElem, child.Size.Y.Scale)
			end
		end
		uiList.Padding = isHorizontal and UDim.new((dropdown.Size.Y.Scale-(dropdown.Size.Y.Scale - (nbElem*(btnRef.Size.Y.Scale/nbElem))))/(nbElem*15), 0) or UDim.new((dropdown.Size.X.Scale-(dropdown.Size.X.Scale - (nbElem*(btnRef.Size.X.Scale/nbElem))))/(nbElem*15), 0)
	end
end

--Specific function only for filter Positionning objects data (because not from datastore)
function MakeFiltersButtonsForObjectsList(typeFiltersChoose, typeFilters)
	for _, item in pairs(typeFiltersChoose) do
		local clone = FilterBtnTemplate:Clone()
		clone.ImageTransparency = 0.4
		clone.Visible = true
		clone.Name = item
		clone.Parent = UIFilterBackground.List
		local iconsData = GameDataModule.FiltersCategorieIcons[item]
		if iconsData then
			clone.Image = iconsData.Icon
		end
		
		clone:SetAttribute("TextHover", item)

		clone.LayoutOrder = #UIFilterBackground.List:GetChildren() - 2 -- -2 because him self + UIListLayout children not counted for this
	
		clone.Activated:Connect(function()
			local gui = UIProviderModule:GetUI(typeFilters)
			local Background = gui:WaitForChild("Background")
			local otherBtn = UIFilterBackground.List:GetChildren()

			--check already actif
			if clone.ImageTransparency == 0 then
				--if yes, disable filter behavior to all visible
				clone.ImageTransparency = 0.4
				for _, obj in pairs(Background:FindFirstChildWhichIsA("ScrollingFrame"):GetChildren()) do
					if obj:IsA("TextButton") or obj:IsA("Frame") then
						obj.Visible = true
					end
				end
				return
			end

			--If not already actif, apply the good visibility object and filters buttons
			for _, btn in pairs(otherBtn) do
				if btn:IsA("ImageButton") then
					if btn ~= clone then
						btn.ImageTransparency = 0.4
					else
						btn.ImageTransparency = 0
					end
				end
			end
			for _, obj in pairs(Background:FindFirstChildWhichIsA("ScrollingFrame"):GetChildren()) do
				if obj:IsA("TextButton") or obj:IsA("Frame") then
					if obj:GetAttribute("ObjectType") == clone.Name then
						obj.Visible = true
					else
						obj.Visible = false
					end
				end
			end
		end)
	end
end

function FilterManager.InitUIFilter(typeFilters, typeFiltersChoose, isHorizontal)
	if isHorizontal then
		UIFilterBackground.Size = UDim2.fromScale(0.75,0.08)
		UIFilterBackground.List. Size = UDim2.fromScale(0.95, 0.8)
		UIFilterBackground.List.UIListLayout.FillDirection = Enum.FillDirection.Horizontal
		UIFilterBackground.List.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	else
		UIFilterBackground.Size = UDim2.fromScale(0.12,0.6)
		UIFilterBackground.List. Size = UDim2.fromScale(0.95, 0.96)
		UIFilterBackground.List.UIListLayout.FillDirection = Enum.FillDirection.Vertical
		UIFilterBackground.List.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	
	if typeFilters == "PositionningGui" or typeFilters == "InventoryGui" then
		MakeFiltersButtonsForObjectsList(typeFiltersChoose, typeFilters)
	else
		
		local AllEnumData = RemoteFunction:WaitForChild("GetAllEnumDataFiltersOf"):InvokeServer(typeFilters) --Horses or Genes
		for _, item in pairs(typeFiltersChoose) do
			if AllEnumData[item] then
				local clone = FilterBtnTemplate:Clone()
				clone.Visible = true
				clone.Name = item.."Filters"
				if not isHorizontal then
					clone.Size = UDim2.fromScale(0.9,0.18)
					clone:SetAttribute("Mode", "right")
				end
				local iconsData = GameDataModule.FiltersCategorieIcons[item]
				if iconsData then
					clone.Image = iconsData.Icon
				end
				clone.Parent = UIFilterBackground.List
				
				if item == "Race" then
					clone:SetAttribute("TextHover", "Type")
				elseif item == "CreatureType" then
					clone:SetAttribute("TextHover", "Kind")
				else
					clone:SetAttribute("TextHover", item)
				end

				clone.LayoutOrder = #UIFilterBackground.List:GetChildren() - 2 -- -2 because him self + UIListLayout children not counted for this
				clone.ImageTransparency = 0

				MakeDropDownList(clone, item, AllEnumData[item], isHorizontal)

				clone.Activated:Connect(function()
					local dropdown = UIFilterBackground:FindFirstChild(item.."DropDown")
					if dropdown then
						dropdown.Visible = not dropdown.Visible
					end
				end)
			end
		end
	end
	UIFilterBackground.Visible = true
end

function FilterManager.CheckFiltersIsOk(data)
	local filterIsOk = true
	if FilterApply then
		for filterName, filterData in pairs(FilterApply) do
			if tostring(data[filterName]) ~= filterData then
				filterIsOk = false
			end
		end
	end
	
	return filterIsOk
end

function FilterManager.CleanFilters()
	for _, childs in pairs(UIFilterBackground:GetChildren()) do
		if childs.Name:match("List") then
			for _, child in pairs(childs:GetChildren()) do
				if child:IsA("ImageButton") then
					child:Destroy()
				end
			end
		elseif childs.Name:match("DropDown") then
			childs:Destroy()
		end
	end
	FilterApply = {}
	UIFilterBackground.Visible = false
end

function FilterManager.GetFiltersChoose()
	return FilterApply
end

return FilterManager
