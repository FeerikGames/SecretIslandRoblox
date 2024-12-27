local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

if game.PlaceId ~= EnvironmentModule.GetPlaceId("MainPlace") then
	return
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()
local PlayerDataModule = require("ReplicatedPlayerData")

--Remote
local RemoteFunction = ReplicatedStorage.RemoteFunction
local RemoteEvent = ReplicatedStorage.RemoteEvent
local HorseEvents = ReplicatedStorage.HorseEvents

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local GameDataModule = require("GameDataModule")

local LocalPlayer = game.Players.LocalPlayer

--UI
local PlayerInfoGui = UIProviderModule:GetUI("PlayerInfosGui")
local GUI = game.Players.LocalPlayer.PlayerGui.StarterGuiSync:WaitForChild("AuctionHouseGui")
local AuctionHouseGui = GUI:WaitForChild("Background")
local Template = AuctionHouseGui.Parent.Template
local InfosCreatureFrame = AuctionHouseGui.InfosCreatureFrame
local FilterFrame = AuctionHouseGui.FilterFrame
local SubMenu = AuctionHouseGui.SubMenu
local DropDown = AuctionHouseGui.DropDown
local ItemHoverTextTemplate = Template.ItemHoverTextTemplate
local DropdownBtnTemplate = Template.DropDownItem
local LeftBtn = AuctionHouseGui.LeftBtn
local RightBtn = AuctionHouseGui.RightBtn
local BuyBtn = AuctionHouseGui.BuyBtn

local CreaturesModularPartsFolder = ReplicatedStorage.Assets.CreaturesModularParts

local CreatureFilterList = {}
local CreatureFilterSelected
local indexFilterSelector = 1

local OpenBrickColorPickerFrom = nil
local SearchIsFinish = true
local CanUseButton = true

local Debounce = true

local AuctionHouseObj = game.Workspace:WaitForChild("SystemUnlockable"):WaitForChild("Pet Store"):WaitForChild("AuctionHouse")
local AuctionHouseCircle = game.Workspace:WaitForChild("SystemUnlockable"):WaitForChild("Pet Store"):WaitForChild("AuctionHouseCircle")


local function DropDownActivated(item, data)
	DropDown.Visible = true
    ToolsModule.DepopulateTypeOfItemFrom("ImageButton", DropDown.Items)

    
    if data then
        local btnClone = DropdownBtnTemplate:Clone()
        btnClone.Name = ""
        btnClone.DropDownItemTxt.Text = "All"
        btnClone.Parent = DropDown.Items
		btnClone.Visible = true
		btnClone.Activated:Connect(function()
			item.Select.SelectedOption.Value = ""
			item.Select.SelectTxt.Text = btnClone.DropDownItemTxt.Text
			DropDown.Visible = false
			ToolsModule.DepopulateTypeOfItemFrom("ImageButton", DropDown.Items)
		end)

        for _, name in pairs(data) do
			local btnClone = DropdownBtnTemplate:Clone()
            btnClone.Name = string.match(item.Name, "Material") ~= nil and _.Value or name
            btnClone.DropDownItemTxt.Text = name
			btnClone.Parent = DropDown.Items
			btnClone.Visible = true
			btnClone.Activated:Connect(function()
				item.Select.SelectedOption.Value = btnClone.Name
				item.Select.SelectTxt.Text = name
				DropDown.Visible = false
				ToolsModule.DepopulateTypeOfItemFrom("ImageButton", DropDown.Items)
			end)
        end
    end
end

local function ResetOtherDropDown(item)
	for _, Item in pairs(SubMenu.Items:GetChildren()) do
		if Item:FindFirstChild("Select") then
			Item.Select.Opened.Value = false
		end
	end
	for _, Item in pairs(FilterFrame:GetChildren()) do
		if Item:FindFirstChild("Select") then
			Item.Select.Opened.Value = false
		end
	end
end

local function SubMenuActivated(item, Type)
	DropDown.Position = UDim2.new(0.509,0,0.469,0)
	DropDown.Visible = false
	for _, object in pairs(SubMenu.Items:GetChildren()) do
		if object:IsA("Frame") == false then
			continue
		end
		if string.find(object.Name, Type) then
			object.Visible = true
		else
			object.Visible = false
		end
	end
	SubMenu.Visible = true
end

local function ResetOtherMenu(Current)
	for _, Frame in pairs(FilterFrame:GetChildren()) do
		if Frame:FindFirstChild("Menu") then
			if Frame.Name ~= Current then
				Frame.Menu.MenuTxt.Text = "Menu"
			end
		end
	end
end

local function InitSubMenuButton(Frame, Type)
	ResetOtherDropDown()
	if Frame.Menu.MenuTxt.Text == "Menu" then
		ResetOtherMenu(Frame.Name)
		Frame.Menu.MenuTxt.Text = "Close"
		SubMenuActivated(Frame.Menu, Type)
	else
		Frame.Menu.MenuTxt.Text = "Menu"
		SubMenu.Visible = false
		DropDown.Visible = false
	end
end

function InitDropdownData(item, data)
	item.Select.Activated:Connect(function()
		if item.Parent == FilterFrame then
			SubMenu.Visible = false
			DropDown.Position = UDim2.new(0.34,0,0.469,0)
			ResetOtherMenu("")
		end
		if item.Select.Opened.Value == false then
			ResetOtherDropDown(item)
			item.Select.Opened.Value = true
			DropDownActivated(item, data)
		else
			item.Select.Opened.Value = false
			DropDown.Visible = false
			ToolsModule.DepopulateTypeOfItemFrom("TextButton", DropDown.Items)
		end
	end)
end

local SEGMENTS = 13

local function Luminosity(color)
	return math.sqrt((color.r * 0.299) ^ 2 + (0.587 * color.g) ^ 2 + (0.114 * color.b) ^ 2)
end

local function ClampHue(h, segments)
	return math.floor(h * segments)
end

local function SortLuma(colorA, colorB)
	local hA, sA, vA = Color3.toHSV(colorA)
	local hB, sB, vB = Color3.toHSV(colorB)
	
	local clampedHA = ClampHue(hA, SEGMENTS)
	local clampedHB = ClampHue(hB, SEGMENTS)
	
	local lumA = Luminosity(colorA)
	local lumB = Luminosity(colorB)
	
	if clampedHA == clampedHB then
		return lumA < lumB
	else
		return clampedHA < clampedHB
	end
end

function InitBrickColorPick()
	local colors = {}
	--[[ for i = 0, 127 do
		local newColor = BrickColor.palette(i)
		if not table.find(colors, newColor.Color) then
			table.insert(colors, newColor.Color)
		end
	end ]]
	for i = 0, 1032 do
		local newColor = BrickColor.new(i)
		if not table.find(colors, newColor.Color) then
			table.insert(colors, newColor.Color)
		end
	end

	table.sort(colors, SortLuma)
	print("COLOR TABLE", colors)

	local ActualParent = Template.ColorBlock:Clone()
	ActualParent.Parent = AuctionHouseGui.BrickColorPicker
	ActualParent.Visible = true

	for i, v in pairs(colors) do
		if i>1 then
			if (i%13)-1 == 0 then
				ActualParent = Template.ColorBlock:Clone()
				ActualParent.Parent = AuctionHouseGui.BrickColorPicker
				ActualParent.Visible = true
			end
		end

		local clone = Template.ButtonColor:Clone()
		clone.Parent = ActualParent
		clone.LayoutOrder = i
		clone.BackgroundColor3 = v
		clone.Visible = true
		clone.Activated:Connect(function()
			print("Order", clone.LayoutOrder)
			OpenBrickColorPickerFrom.ShowBrickColorSelector.ImageColor3 = v
			OpenBrickColorPickerFrom.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = BrickColor.new(v).Name

			AuctionHouseGui.BrickColorPicker.Visible = false
			OpenBrickColorPickerFrom = nil
		end)
	end

	--[[ local previous = nil
	for count = 1, 1032, 1 do
		local color = BrickColor.new(count)
		if color ~= previous then
			print("Color",color)
			previous = color
			local clone = AuctionHouseGui.Template.ButtonColor:Clone()
			clone.Parent = AuctionHouseGui.BrickColorPicker
			clone.LayoutOrder = count
			clone.BackgroundColor3 = color.Color
			clone.Visible = true
		end
	end ]]
end

local function PopulateFilterFrameData()
    local data = RemoteFunction:WaitForChild("GetAllEnumDataFiltersOf"):InvokeServer("Horses")
    InitDropdownData(FilterFrame.CreatureRace, data.Race)
	InitDropdownData(FilterFrame.CreatureType, data.CreatureType)
    InitDropdownData(FilterFrame.CreatureRating, data.Rating)
    InitDropdownData(FilterFrame.CreatureGender, data.Gender)

	local dataMaterial = {
		[Enum.Material.Neon] = "Neon",
		[Enum.Material.Foil] = "Foil",
		[Enum.Material.Plastic] = "Plastic",
		[Enum.Material.Cobblestone] = "Cobblestone",
		[Enum.Material.DiamondPlate] = "DiamondPlate",
		[Enum.Material.Glass] = "Glass",
		[Enum.Material.SmoothPlastic] = "SmoothPlastic"
	}
	InitDropdownData(SubMenu.Items.CreatureMaterial, dataMaterial)
	InitDropdownData(SubMenu.Items.CreatureBodyMaterial, dataMaterial)
	InitDropdownData(SubMenu.Items.CreatureManeMaterial, dataMaterial)
	InitDropdownData(SubMenu.Items.CreatureTailMaterial, dataMaterial)
	InitDropdownData(SubMenu.Items.CreatureSocksMaterial, dataMaterial)
end

--[[
	Create item ui based on template for create item hover text into Info1 UI
]]
local function CreateItemHoverText(dataName, dataValue)
	local clone = ItemHoverTextTemplate:Clone()
	clone.Visible = true
	clone.Name = dataName

	if dataName == "Married" then
		if dataValue == "" then
			dataValue = "unmarried"
		end
	elseif dataName == "InNursery" then
		if dataValue then
			clone:SetAttribute("TextHover", "Not Available")
		else
			clone:SetAttribute("TextHover", "Available")
		end
	else
		clone:SetAttribute("TextHover", tostring(dataValue))
	end
	
	
	clone.Parent = InfosCreatureFrame.Infos
	local iconsData = GameDataModule[dataName.."Icons"]
	if iconsData then
		clone.Image = iconsData[tostring(dataValue):gsub("^%l", string.upper)]
	end
end

local function PopulateCreatureInfosFrame()
    ToolsModule.DepopulateTypeOfItemFrom("ImageButton", InfosCreatureFrame.Infos)
	InfosCreatureFrame.Characteristics.Visible = true
	InfosCreatureFrame.Infos.Visible = true

    CreateItemHoverText("Race", CreatureFilterSelected["Race"])
	CreateItemHoverText("Gender", CreatureFilterSelected["Gender"])
	CreateItemHoverText("Rating", CreatureFilterSelected["Rating"])
	--[[ CreateItemHoverText("Married", CreatureFilterSelected["Married"])
	CreateItemHoverText("InNursery", CreatureFilterSelected["InNursery"])
	CreateItemHoverText("Growth", CreatureFilterSelected["Growth"]) ]]

    for _, item in pairs(InfosCreatureFrame.Characteristics.ScrollingFrame:GetChildren()) do
		if item:IsA("Frame") then
			if item.Name:match("Color") then
				item.ItemValue.BackgroundColor3 = Color3.new(CreatureFilterSelected[item.Name].r, CreatureFilterSelected[item.Name].g, CreatureFilterSelected[item.Name].b)
			elseif item.Name:match("Talents") then
				local creatureTalent = CreatureFilterSelected.Talents
				local temp = {}
				-- Reset talents frames
				for _, talentFrame in pairs(item:GetChildren()) do
					talentFrame.Visible = false
				end

				-- Setup on UI talents list, the talent founded and not setup again in ui
				for _, talentFrame in pairs(item:GetChildren()) do
					for id, value in pairs(creatureTalent) do
						if not table.find(temp, id) then
							talentFrame.Title.Text = CreaturesTalentsModule.TalentsTable[id].Name
							talentFrame:SetAttribute("TextHover", CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%"))
							table.insert(temp, id)
							talentFrame.Visible = true
							break
						end
					end
				end
			else
				if item.Name == "CreatureOwner" then
					if CreatureFilterSelected["ListOfOwners"]["ActualOwner"] then
						item.ItemValue.Text = CreatureFilterSelected["ListOfOwners"].ActualOwner ~= "" and game.Players:GetNameFromUserIdAsync(CreatureFilterSelected["ListOfOwners"].ActualOwner) or "..."
					end

				elseif CreatureFilterSelected["Maintenance"][item.Name] then
					item.ItemValue.Text = CreatureFilterSelected["Maintenance"][item.Name].Value
					
				elseif typeof(CreatureFilterSelected[item.Name]) == "table" then
					item.ItemValue.Text = CreatureFilterSelected[item.Name].Value
					
				else
					item.ItemValue.Text = CreatureFilterSelected[item.Name]
					if item.Name == "Rating" then
						item.ItemValue.TextColor3 = ToolsModule.RarityColor[CreatureFilterSelected[item.Name]]
					end
				end
			end
        end
    end

	if indexFilterSelector == 1 then
		LeftBtn.Visible = false
		RightBtn.Visible = true
	elseif indexFilterSelector == #CreatureFilterList then
		LeftBtn.Visible = true
		RightBtn.Visible = false
	else
		LeftBtn.Visible = true
		RightBtn.Visible = true
	end

	if CreatureFilterSelected.ListOfOwners.ActualOwner == LocalPlayer.UserId then
		AuctionHouseGui.BuyBtn.BuyTxt.Text = "Remove from sale"
		AuctionHouseGui.BuyBtn.BuyTxt.Position = UDim2.fromScale(0.5,0.482)
		AuctionHouseGui.BuyBtn.Icon.Visible = false
	else
		AuctionHouseGui.BuyBtn.BuyTxt.Text ="Price : " .. ToolsModule.DotNumber(CreatureFilterSelected.SellValue)
		AuctionHouseGui.BuyBtn.BuyTxt.Position = UDim2.fromScale(0.613,0.482)
		AuctionHouseGui.BuyBtn.Icon.Visible = true
		AuctionHouseGui.BuyBtn.Icon.Image = GameDataModule.DropCollectablesWithBorders.Ecus
	end
	
	AuctionHouseGui.NbFounded.Text = indexFilterSelector.." / "..#CreatureFilterList
end

--[[
	We check if model of Creature are available for female and male and if yes remove it to clean
]]
local function RemoveModelCreature()
	local model = AuctionHouseObj.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if model then
		model:Destroy()
	end
end

--[[
    Reset Data for Search with new search filter data
]]
local function ResetDataSearch(resetUI)
    if resetUI then
		FilterFrame.CreatureName.Input.Text = ""
		FilterFrame.CreatureOwnerName.Input.Text = ""

        FilterFrame.CreatureRace.Select.SelectedOption.Value = ""
		FilterFrame.CreatureType.Select.SelectedOption.Value = ""
        FilterFrame.CreatureRating.Select.SelectedOption.Value = ""
        FilterFrame.CreatureGender.Select.SelectedOption.Value = ""

		SubMenu.Items.CreatureMaterial.Select.SelectedOption.Value = ""
		SubMenu.Items.CreatureBodyMaterial.Select.SelectedOption.Value = ""
		SubMenu.Items.CreatureManeMaterial.Select.SelectedOption.Value = ""
		SubMenu.Items.CreatureTailMaterial.Select.SelectedOption.Value = ""
		SubMenu.Items.CreatureSocksMaterial.Select.SelectedOption.Value = ""

        FilterFrame.CreatureRace.Select.SelectTxt.Text = "All"
		FilterFrame.CreatureType.Select.SelectTxt.Text = "All"
        FilterFrame.CreatureRating.Select.SelectTxt.Text = "All"
        FilterFrame.CreatureGender.Select.SelectTxt.Text = "All"

		SubMenu.Items.CreatureMaterial.Select.SelectTxt.Text = "All"
		SubMenu.Items.CreatureBodyMaterial.Select.SelectTxt.Text = "All"
		SubMenu.Items.CreatureManeMaterial.Select.SelectTxt.Text = "All"
		SubMenu.Items.CreatureTailMaterial.Select.SelectTxt.Text = "All"
		SubMenu.Items.CreatureSocksMaterial.Select.SelectTxt.Text = "All"

		SubMenu.Items.CreatureColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = "Select Color"
		SubMenu.Items.CreatureColor.ShowBrickColorSelector.ImageColor3 = Color3.fromRGB(0, 115, 255)
		SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = "Select Color"
		SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.ImageColor3 = Color3.fromRGB(0, 115, 255)
		SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = "Select Color"
		SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.ImageColor3 = Color3.fromRGB(0, 115, 255)
		SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = "Select Color"
		SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.ImageColor3 = Color3.fromRGB(0, 115, 255)
		SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text = "Select Color"
		SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.ImageColor3 = Color3.fromRGB(0, 115, 255)
		AuctionHouseGui.BrickColorPicker.Visible = false
		OpenBrickColorPickerFrom = nil
		RemoveModelCreature()
    end

	ResetOtherMenu("")
	SubMenu.Visible = false
	ResetOtherDropDown()
	DropDown.Visible = false

	LeftBtn.Visible = false
	RightBtn.Visible = false

	AuctionHouseGui.BuyBtn.Visible = false
	AuctionHouseGui.NbFounded.Text = ""
	
	InfosCreatureFrame.Characteristics.Visible = false
	InfosCreatureFrame.Infos.Visible = false
	
	CreatureFilterList = {}
    indexFilterSelector = 1
    CreatureFilterSelected = nil
end

local function SearchInAllValueForTypeData(datas, type, value)
	local statsFound = {}

	if type == "Color" then
		if BrickColor.new(datas["Color"].r,datas["Color"].g,datas["Color"].b).Color == value then
			table.insert(statsFound, "Color")
		end

		if BrickColor.new(datas["ManeColor"].r,datas["ManeColor"].g,datas["ManeColor"].b).Color == value then
			table.insert(statsFound, "ManeColor")
		end

		if BrickColor.new(datas["TailColor"].r,datas["TailColor"].g,datas["TailColor"].b).Color == value then
			table.insert(statsFound, "TailColor")
		end

		if BrickColor.new(datas["SocksColor"].r,datas["SocksColor"].g,datas["SocksColor"].b).Color == value then
			table.insert(statsFound, "SocksColor")
		end
	
	elseif type == "Material"  then
		if datas["PartsMaterial"].Tail == value then
			table.insert(statsFound, "Tail")
		end
		if datas["PartsMaterial"].Mane == value then
			table.insert(statsFound, "Mane")
		end
		if datas["PartsMaterial"].Marking == value then
			table.insert(statsFound, "Marking")
		end
		if datas["PartsMaterial"].Socks == value then
			table.insert(statsFound, "Socks")
		end
	end

	return statsFound
end

--[[
	This function allow to set a Creature model with good texture and colors, and materials for Creature selected and good gender Creature.
]]
local function SpawnGoodTargetForFusion(direction)
	Debounce = false
	--get available gene from store item because player can not have a gene on Creature in sale
	local AvailableGenesCollection = RemoteFunction.AuctionHouse:WaitForChild("GetGenesCollectionForAuctionHouse"):InvokeServer()
	local target = AuctionHouseObj
	local cloneCreatureModel = target.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if cloneCreatureModel then
		cloneCreatureModel:Destroy()
		cloneCreatureModel = nil
	end
	
	if direction == "Right" then
        if indexFilterSelector < #CreatureFilterList  then
            indexFilterSelector += 1
        end
    else
        if indexFilterSelector ~= 1 then
            indexFilterSelector -= 1
        end
    end
    CreatureFilterSelected = CreatureFilterList[indexFilterSelector]
	
	--If model Creature never setup for this gender of Creature selected we make one for the first time and after we use it and change only texture, colors and meterials
	if not cloneCreatureModel then
		local connexionChildRemove
		cloneCreatureModel = ReplicatedStorage.Assets.CreaturesModels[CreatureFilterSelected.CreatureType.."ModelFusion"]:Clone()
		cloneCreatureModel.Name = "CloneCreatureModel"
		cloneCreatureModel.Parent = target.SpawnTarget
		cloneCreatureModel:PivotTo(target.SpawnTarget.CFrame * CFrame.new(4.2,0,0) * CFrame.Angles(0,0,math.rad(-90)))

		--set idle anim creature
		local animCtrler = Instance.new("AnimationController", cloneCreatureModel)
		local animator = Instance.new("Animator", animCtrler)
		local AnimIdle = animator:LoadAnimation(ReplicatedStorage.Assets.Animations[CreatureFilterSelected.CreatureType].Idle)
		AnimIdle:Play()

		--We set the visual infinite rotation for platform where model is placed
		local info = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, 0) -- -1 is for repeat count which will be infinite, false is for bool reverses which means it will not go backwards
		local goals = {Orientation = Vector3.new(0, 360, 90)} --Rotating it 360 degrees will make it go back to the original starting point, and with an infinite repeat count, it will go forever.
		local tween = TweenService:Create(target.SpawnTarget, info, goals)
		tween:Play()

		--Rotation for Model Creature
		local modelPivot = cloneCreatureModel:GetPivot()
		local CFrameValue = Instance.new("CFrameValue")
		CFrameValue.Value = modelPivot

		local steppedConnection = RunService.Stepped:Connect(function()
			if cloneCreatureModel then
				cloneCreatureModel:PivotTo(CFrameValue.Value)
			end
		end)
		
		local spininfo = TweenInfo.new(2.5,Enum.EasingStyle.Linear)

		local Spin1 = TweenService:Create(CFrameValue, spininfo, {Value = modelPivot * CFrame.Angles(0,math.rad(90),0)})
		local Spin2 = TweenService:Create(CFrameValue, spininfo, {Value = modelPivot * CFrame.Angles(0,math.rad(180),0)})
		local Spin3 = TweenService:Create(CFrameValue, spininfo, {Value = modelPivot * CFrame.Angles(0,math.rad(-90),0)})
		local Spin4 = TweenService:Create(CFrameValue, spininfo, {Value = modelPivot * CFrame.Angles(0,math.rad(0),0)})

		Spin1:Play()
		Spin1.Completed:Connect(function() Spin2:Play() end)
		Spin2.Completed:Connect(function() Spin3:Play() end)
		Spin3.Completed:Connect(function() Spin4:Play() end)
		Spin4.Completed:Connect(function() Spin1:Play() end)

		--if model Creature are remove, we clear all event and tween service who use for this and above pblm memory allowed
		connexionChildRemove = target.SpawnTarget.ChildRemoved:Connect(function(child)
			connexionChildRemove:Disconnect()
			steppedConnection:Disconnect()
			tween:Cancel()
			Spin1:Cancel()
			Spin2:Cancel()
			Spin3:Cancel()
			Spin4:Cancel()
			CFrameValue:Destroy()
		end)
	end

    --[[ cloneCreatureModel.HumanoidRootPart.Gui.CreatureName.Text = CreatureFilterSelected.CreatureName
    if CreatureFilterSelected.Gender == "Male" then
        cloneCreatureModel.HumanoidRootPart.Gui.CreatureName.TextColor3 = Color3.fromRGB(85, 170, 255)
    else
        cloneCreatureModel.HumanoidRootPart.Gui.CreatureName.TextColor3 = Color3.fromRGB(255, 85, 255)
    end ]]

	cloneCreatureModel.CreatureID.Value = CreatureFilterSelected.CreatureID

	if CreatureFilterSelected.Race == "Celestial" then
		cloneCreatureModel["Wing_Left"].Transparency = 0.01
		cloneCreatureModel["Wing_Right"].Transparency = 0.01
		cloneCreatureModel["Wing_Left"].TextureID = CreatureFilterSelected.Genes["Wing"]
		cloneCreatureModel["Wing_Right"].TextureID = CreatureFilterSelected.Genes["Wing"]
	else
		cloneCreatureModel["Wing_Left"].Transparency = 1
		cloneCreatureModel["Wing_Right"].Transparency = 1
	end

	ToolsModule.CheckEvolutionPartCreatureToAttribute(cloneCreatureModel, CreatureFilterSelected)

	-- Check all register accessory on this creature and setup them
	if CreatureFilterSelected["Accessory"] then
		for _, accessoryID in pairs(CreatureFilterSelected.Accessory) do
			local creatureType = CreatureFilterSelected.CreatureType
			local accessory = ReplicatedStorage.Assets.CreaturesAccessory[accessoryID]

			if accessory then
				if accessory:FindFirstChild("MultipleAccessory") then
					local FolderMultipleAccessory = Instance.new("Folder", cloneCreatureModel)
					FolderMultipleAccessory.Name = accessoryID
					-- If we found this folder it's special accessory need to be multiple clone of it (example feet accessory need on 4 feet)
					for _, part in pairs(accessory.MultipleAccessory:GetChildren()) do
						local clone:MeshPart = accessory:Clone()
						clone.Parent = FolderMultipleAccessory
					
						-- Check if actual animal have a size effect active or not to apply the good size ratio
						if cloneCreatureModel.PrimaryPart:GetAttribute("SizeEffectActive") then
							local SizeRatio = cloneCreatureModel.PrimaryPart:GetAttribute("SizeRatio")
							ToolsModule.ScaleMesh(Vector3.new(SizeRatio,SizeRatio,SizeRatio), clone)
						end
				
						local attachment:Attachment = Instance.new("Attachment", clone)
						local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
						constraint.Attachment0 = attachment
				
						-- Search bone reference instance
						for _, bone in pairs(cloneCreatureModel.RootPart:GetDescendants()) do
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
					local clone:MeshPart = accessory:Clone()
					clone.Parent = cloneCreatureModel
				
					local attachment:Attachment = Instance.new("Attachment", clone)
					local constraint:RigidConstraint = Instance.new("RigidConstraint", clone)
					constraint.Attachment0 = attachment
				
					-- Search bone reference instance
					for _, bone in pairs(cloneCreatureModel.RootPart:GetDescendants()) do
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
			else
				warn("Accessory "..accessoryID.." not found in player inventory!")
			end
		end
	end

	for typeGene, gene in pairs(CreatureFilterSelected.Genes) do
		if typeGene ~= "Wing" then
			for _, child in pairs(cloneCreatureModel:GetChildren()) do
				if string.lower(child.Name):match(string.lower(typeGene)) then
					if gene ~= "" then
						child.TextureID = AvailableGenesCollection[CreatureFilterSelected.Genes[typeGene]]
						if string.lower(child.Name):match(string.lower("Accessory")) or string.lower(child.Name):match(string.lower("Eye")) then
							child.Transparency = 0.01
						else
							child.Transparency = 0
						end
	
						--Check if its mesh part if texture gene to apply have a surface appereance or not
						if child:IsA("MeshPart") then
							local exist = RemoteFunction.SearchSurfaceForFusion:InvokeServer(gene)
							if exist then
								--if yes destroy the actuel and replace by another
								local t = child:FindFirstChildOfClass("SurfaceAppearance")
								if t then
									t:Destroy()
								end
								local clone = exist:Clone()
								clone.Parent = child
							else
								--if not destroy it
								local t = child:FindFirstChildOfClass("SurfaceAppearance")
								if t then
									t:Destroy()
								end
							end
						end
					else
						if string.lower(child.Name):match(string.lower("Eye")) then
							if CreatureFilterSelected.CreatureType == "Cat" then
								child.TextureID = "rbxassetid://10052299194"
							else
								child.TextureID = "rbxassetid://8476638575" --this allow to make a default texture for eye (actually only eye are a default texture)
							end
						elseif string.lower(child.Name):match(string.lower("Accessory")) then
							child.Transparency = 1
						else
							child.TextureID = ""
						end
	
						--if no gene for this part and it's a Meshpart and we found a surface, delete it
						if child:IsA("MeshPart") then
							local t = child:FindFirstChildOfClass("SurfaceAppearance")
							if t then
								t:Destroy()
							end
						end
					end
					
					if string.lower(child.Name):match("mane") then
						local t = CreatureFilterSelected.ManeColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureFilterSelected.PartsMaterial.Mane
					elseif string.lower(child.Name):match("marking") then
						local t = CreatureFilterSelected.Color
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureFilterSelected.PartsMaterial.Marking
					elseif string.lower(child.Name):match("tail") then
						local t = CreatureFilterSelected.TailColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureFilterSelected.PartsMaterial.Tail
					elseif string.lower(child.Name):match("socks") then
						local t = CreatureFilterSelected.SocksColor
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = CreatureFilterSelected.PartsMaterial.Socks
					end
	
					--check if this Part contain Tattoo Texture and check if we need to setup this
					for _, texture in pairs(child:GetChildren()) do
						if texture:IsA("Texture") then
							if CreatureFilterSelected.Genes[texture.Name] ~= "" then
								texture.Texture = AvailableGenesCollection[CreatureFilterSelected.Genes[texture.Name]]
								texture.Transparency = 0
							else
								texture.Texture = ""
								texture.Transparency = 1
							end
						end
					end
				end
			end
		end
	end

    PopulateCreatureInfosFrame()
	Debounce = true
end

local function PopupInfo(title, message, showBtn, parent)
	local clone = parent:FindFirstChild("PopupInfo") and parent.PopupInfo or Template.PopupInfo:Clone()
	clone.Parent = parent
	clone.Title.Text = title
	clone.Content.Text = message
	clone.Visible = true
	clone.OkBtn.Activated:Connect(function()
		CanUseButton = true
		clone:Destroy()
	end)

	clone.OkBtn.Visible = showBtn
end

local function SearchBtnActivated()
	if not SearchIsFinish then
		return
	end
	SearchIsFinish = false
	ResetDataSearch(false)
	local AvailableCreatureCollection = RemoteFunction.AuctionHouse.GetHorseInSelling:InvokeServer()
	if AvailableCreatureCollection then
		for index, datas in pairs(AvailableCreatureCollection) do
			local AllFilterOk = false
			if datas["Race"] == FilterFrame.CreatureRace.Select.SelectedOption.Value or FilterFrame.CreatureRace.Select.SelectedOption.Value == "" then
				if datas["CreatureType"] == FilterFrame.CreatureType.Select.SelectedOption.Value or FilterFrame.CreatureType.Select.SelectedOption.Value == "" then
					if datas["Gender"] == FilterFrame.CreatureGender.Select.SelectedOption.Value or FilterFrame.CreatureGender.Select.SelectedOption.Value == "" then
						if datas["Rating"] == FilterFrame.CreatureRating.Select.SelectedOption.Value or FilterFrame.CreatureRating.Select.SelectedOption.Value == "" then
							if BrickColor.new(datas["Color"].r,datas["Color"].g,datas["Color"].b).Color == SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.BackgroundColor3 or (SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text == "Select Color" and SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.BackgroundColor3 == Color3.fromRGB(0,0,0)) then
								if BrickColor.new(datas["ManeColor"].r,datas["ManeColor"].g,datas["ManeColor"].b).Color == SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.BackgroundColor3 or (SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text == "Select Color" and SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.BackgroundColor3 == Color3.fromRGB(0,0,0)) then
									if BrickColor.new(datas["TailColor"].r,datas["TailColor"].g,datas["TailColor"].b).Color == SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.BackgroundColor3 or (SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text == "Select Color" and SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.BackgroundColor3 == Color3.fromRGB(0,0,0)) then
										if BrickColor.new(datas["SocksColor"].r,datas["SocksColor"].g,datas["SocksColor"].b).Color == SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.BackgroundColor3 or (SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text == "Select Color" and SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.BackgroundColor3 == Color3.fromRGB(0,0,0)) then
											if datas["PartsMaterial"].Marking == tonumber(SubMenu.Items.CreatureBodyMaterial.Select.SelectedOption.Value) or SubMenu.Items.CreatureBodyMaterial.Select.SelectedOption.Value == "" then
												if datas["PartsMaterial"].Mane == tonumber(SubMenu.Items.CreatureManeMaterial.Select.SelectedOption.Value) or SubMenu.Items.CreatureManeMaterial.Select.SelectedOption.Value == "" then
													if datas["PartsMaterial"].Tail == tonumber(SubMenu.Items.CreatureTailMaterial.Select.SelectedOption.Value) or SubMenu.Items.CreatureTailMaterial.Select.SelectedOption.Value == "" then
														if datas["PartsMaterial"].Socks == tonumber(SubMenu.Items.CreatureSocksMaterial.Select.SelectedOption.Value) or SubMenu.Items.CreatureSocksMaterial.Select.SelectedOption.Value == "" then
															if #SearchInAllValueForTypeData(datas, "Color", SubMenu.Items.CreatureColor.ShowBrickColorSelector.BackgroundColor3) > 0 or (SubMenu.Items.CreatureColor.ShowBrickColorSelector.ShowBrickColorSelectorTxt.Text == "Select Color" and SubMenu.Items.CreatureColor.ShowBrickColorSelector.BackgroundColor3 == Color3.fromRGB(0,0,0)) then
																if #SearchInAllValueForTypeData(datas, "Material", tonumber(SubMenu.Items.CreatureMaterial.Select.SelectedOption.Value)) > 0 or SubMenu.Items.CreatureMaterial.Select.SelectedOption.Value == "" then
																	if string.match(string.lower(datas["CreatureName"]), string.lower(FilterFrame.CreatureName.Input.Text)) or FilterFrame.CreatureName.Input.Text == "" then
																		if datas["ListOfOwners"].ActualOwner == (FilterFrame.CreatureOwnerName.Input.Text ~= "" and game.Players:GetUserIdFromNameAsync(FilterFrame.CreatureOwnerName.Input.Text) or "") or FilterFrame.CreatureOwnerName.Input.Text == "" then
																			AllFilterOk = true
																		else
																			AllFilterOk = false
																		end
																	else
																		AllFilterOk = false
																	end
																else
																	AllFilterOk = false
																end
															else
																AllFilterOk = false
															end
														else
															AllFilterOk = false
														end
													else
														AllFilterOk = false
													end
												else
													AllFilterOk = false
												end
											else
												AllFilterOk = false
											end
										else
											AllFilterOk = false
										end
									else
										AllFilterOk = false
									end
								else
									AllFilterOk = false
								end
							else
								AllFilterOk = false
							end
						else
							AllFilterOk = false
						end
					else
						AllFilterOk = false
					end
				else
					AllFilterOk = false
				end
			else
				AllFilterOk = false
			end
	
			if AllFilterOk then
				if not datas["InNursery"] then
					if not datas["IsBuy"] then
						if not datas["IsRemoved"] then
							local d = datas
							d["CreatureID"] = index
							table.insert(CreatureFilterList, d)
						end
					end
				end
			end
		end
	
		if #CreatureFilterList ~= 0 then
			AuctionHouseGui.BuyBtn.Visible = true
			SpawnGoodTargetForFusion("Left")
			AuctionHouseGui.NbFounded.Text = indexFilterSelector.." / "..#CreatureFilterList
		else
			RemoveModelCreature()
			AuctionHouseGui.NbFounded.Text = "0 / "..#CreatureFilterList
			if not AuctionHouseGui:FindFirstChild("PopupInfo") then
				PopupInfo("No results", "No creature with the selected information was found.", true, AuctionHouseGui)
			end
		end
	end
	SearchIsFinish = true
end

--Call from Click Detector to select Creature from corresponding list gender
LeftBtn.Activated:Connect(function()
	if not CanUseButton then
		return
	end

    if #CreatureFilterList ~= 0 then
		if Debounce then
			SpawnGoodTargetForFusion("Left")
		end
    end
end)

RightBtn.Activated:Connect(function()
	if not CanUseButton then
		return
	end

    if #CreatureFilterList ~= 0 then
		if Debounce then
			SpawnGoodTargetForFusion("Right")
		end
    end
end)

BuyBtn.Activated:Connect(function()
	if not CanUseButton then
		return
	end

    if CreatureFilterSelected then
		CanUseButton = false
		PopupInfo("", "Waiting ....", false, AuctionHouseGui)
		if CreatureFilterSelected.ListOfOwners.ActualOwner == LocalPlayer.UserId then
			RemoteFunction.AuctionHouse.BuyHorse:InvokeServer(CreatureFilterSelected.CreatureID, true, AuctionHouseGui)
			SearchBtnActivated()
		else
			local result = RemoteFunction.AuctionHouse.BuyHorse:InvokeServer(CreatureFilterSelected.CreatureID, nil, AuctionHouseGui)
			if result then
				SearchBtnActivated()
			else
				local exist = AuctionHouseGui:FindFirstChild("PopupInfo")
				if exist then
					exist:Destroy()
					CanUseButton = true
				end
			end
		end
    end
end)

SubMenu.Items.CreatureColor.ShowBrickColorSelector.Activated:Connect(function()
	AuctionHouseGui.BrickColorPicker.Visible = false
	AuctionHouseGui.BrickColorPicker.Visible = true
	OpenBrickColorPickerFrom = SubMenu.Items.CreatureColor
end)

SubMenu.Items.CreatureBodyColor.ShowBrickColorSelector.Activated:Connect(function()
	AuctionHouseGui.BrickColorPicker.Visible = false
	AuctionHouseGui.BrickColorPicker.Visible = true
	OpenBrickColorPickerFrom = SubMenu.Items.CreatureBodyColor
end)

SubMenu.Items.CreatureManeColor.ShowBrickColorSelector.Activated:Connect(function()
	AuctionHouseGui.BrickColorPicker.Visible = false
	AuctionHouseGui.BrickColorPicker.Visible = true
	OpenBrickColorPickerFrom = SubMenu.Items.CreatureManeColor
end)

SubMenu.Items.CreatureTailColor.ShowBrickColorSelector.Activated:Connect(function()
	AuctionHouseGui.BrickColorPicker.Visible = false
	AuctionHouseGui.BrickColorPicker.Visible = true
	OpenBrickColorPickerFrom = SubMenu.Items.CreatureTailColor
end)

SubMenu.Items.CreatureSocksColor.ShowBrickColorSelector.Activated:Connect(function()
	AuctionHouseGui.BrickColorPicker.Visible = false
	AuctionHouseGui.BrickColorPicker.Visible = true
	OpenBrickColorPickerFrom = SubMenu.Items.CreatureSocksColor
end)

FilterFrame.CreatureMaterials.Menu.Activated:Connect(function()
	InitSubMenuButton(FilterFrame.CreatureMaterials, "Material")
end)

FilterFrame.CreatureColors.Menu.Activated:Connect(function()
	InitSubMenuButton(FilterFrame.CreatureColors, "Color")
end)

AuctionHouseGui.SearchBtn.Activated:Connect(function()
	if not CanUseButton then
		return
	end
	SearchBtnActivated()
end)

AuctionHouseGui.ResetBtn.Activated:Connect(function()
	if not CanUseButton then
		return
	end
    ResetDataSearch(true)
end)

RemoteEvent.AuctionHouse.ShowInfoFrame.OnClientEvent:Connect(PopupInfo)

--[[
	Event button to exit Auction House, we make camera to player, disable auction house gui and reset searching data
]]
AuctionHouseGui.Back.Activated:Connect(function()
	ToolsModule.MakeOthersPlayersInvisible(false)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
	controls:Enable()
	AuctionHouseGui.Visible = false
	PlayerInfoGui.Enabled = true
	ToolsModule.EnableOtherUI(true, {"AuctionHouseGui"})

	ResetDataSearch(true)
end)

--[[
	Fire when player enter in auction house field (send by PlayerTouchHandler) to setup animation camera to move it
	in position to see and show ui Auction House.
	This method disable controle character to prevent move player during buy and disable other button interface to prevent other non desired actions.
]]
RemoteEvent.AuctionHouse.ChangeCameraPlayer.OnClientEvent:Connect(function()
	ToolsModule.MakeOthersPlayersInvisible(true)
	CameraController.SetEnabled(false)
	--Check if player have enter in auction house with creature summoned, if yes deload it because we can have conflict UI with event on creatures
	local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..LocalPlayer.Name)
	if exist then
		--Dismount and Deload Creature from world
		RemoteFunction.InvokHorsePlayer:InvokeServer(exist.CreatureID.Value, true)
	end
	
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	
	
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = AuctionHouseObj.CameraPart.CFrame})
	tween:Play()

	controls:Disable()
	AuctionHouseGui.Visible = true
	PlayerInfoGui.Enabled = false
	ToolsModule.EnableOtherUI(false, {"AuctionHouseGui"})
	
	--reset position player to make good feel with launch auction house field
	LocalPlayer.Character.HumanoidRootPart.CFrame = AuctionHouseCircle.ResetPos.CFrame

	SearchBtnActivated()
end)

--show golds of player into auction house
AuctionHouseGui.EcusFrame.IconImg.Image = GameDataModule.DropCollectablesWithBorders.Ecus
AuctionHouseGui.EcusFrame.ValueTxt.Text = PlayerDataModule.LocalData.Ecus
PlayerDataModule:Changed("Ecus", function()
	AuctionHouseGui.EcusFrame.ValueTxt.Text = PlayerDataModule.LocalData.Ecus
end)

task.wait(2)
PopulateFilterFrameData()
InitBrickColorPick()