local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

--Don"t setup race function if its competition parade server
if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") or game.PlaceId == EnvironmentModule.GetPlaceId("MapA") or game.PlaceId == EnvironmentModule.GetPlaceId("MapB") then
	return
end

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local controls = require(game:GetService("Players").LocalPlayer.PlayerScripts.PlayerModule):GetControls()

local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage.RemoteEvent

--RequireModule
local UIProviderModule = require("UIProviderModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local ToolsModule = require("ToolsModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local GameDataModule = require("GameDataModule")
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))

--Filters
local AutelFusion = game.Workspace:WaitForChild("SystemUnlockable"):WaitForChild("FusionSystem")

local CameraPartPos = AutelFusion:WaitForChild("CameraPartPos",3)
local CameraChildPos = AutelFusion:WaitForChild("CameraChildPos",3)
local LocalPlayer = game.Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local CreatureFemaleList = {}
local CreatureFemaleSelected
local indexFemaleSelector = 0

local CreatureMaleList = {}
local CreatureMaleSelected
local indexMaleSelector = 0

local CreatureTypeSelected = "Horse"

local FusionInProgress = false
local tempGeneModel = {
	MaleSelector = {};
	FemaleSelector = {};
	ShowChildFusion = {};
}
local tempTextureModel = {
	MaleSelector = {};
	FemaleSelector = {};
	ShowChildFusion = {};
}
local modelGeneClickBegan

local connectionChildGeneBegan
local connectionChildGeneRelease

local connectionFemaleGeneBegan
local connectionFemaleGeneRelease

local connectionMaleGeneBegan
local connectionMaleGeneRelease

local connectionClickOnModel

--UI
local HorsesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
local BreedingGui = UIProviderModule:GetUI("BreedingGui")
local Background = BreedingGui:WaitForChild("Background")
local ActionsButtons = Background:WaitForChild("ActionsButtons")
local FemaleNavButtons = Background:WaitForChild("FemaleNavButtons")
local MaleNavButtons = Background:WaitForChild("MaleNavButtons")
local CreatureTypeDropdown = Background:WaitForChild("CreatureTypeMenu")
local BackChildBtn = Background:WaitForChild("BackChildBtn")
local InfosChildFrame = Background:WaitForChild("InfosChildFrame")
local ShowCostFusionFrame = Background.ShowCostFusionFrame

local function LaunchParticleFusion(isActive)
	local part1 = AutelFusion.MaleSelector.ParticuleStarsRainbow1
	local part2 = AutelFusion.FemaleSelector.ParticuleStarsRainbow1

	for _, v in pairs(part1:GetChildren()) do
		v.Enabled = isActive
	end
	for _, v in pairs(part2:GetChildren()) do
		v.Enabled = isActive
	end
end

-- Clean list of cost value
local function ClearCostUI()
	for _, child in pairs(ShowCostFusionFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

--[[
	This is allow to disable or enable button when fusion are in progress and we don't wan't player interact with ui
]]
local function EnableButtons(value)
	for _, btn in pairs(FemaleNavButtons:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.Active = value
		end
	end
	for _, btn in pairs(MaleNavButtons:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.Active = value
		end
	end
	for _, btn in pairs(ActionsButtons:GetChildren()) do
		if btn:IsA("TextButton") then
			btn.Active = value
		end
	end
	for _, btn in pairs(CreatureTypeDropdown:GetChildren()) do
		if btn:IsA("ImageButton") then
			btn.Active = value
		end
	end
end

--[[
	This function allow to populate data info of child when player wan't to see it
]]
local function PopulateCharacteristicsInfosFrame(frame,CreatureSelected)
    for _, item in pairs(frame:GetChildren()) do
		if item:IsA("Frame") then
			if item.Name:match("Supra") then
				local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
				local ViewportFrame = item.Data.ViewportFrame
				item.Data.ItemName.Text = CreatureSelected.CreatureName
				ToolsModule.MakeCreatureModelForRender(CreatureSelected, AvailableGenesCollection, ViewportFrame)
			elseif item:FindFirstChild("ItemValue") and item.ItemValue:IsA("ImageLabel") then
				item.Title.Text = CreatureSelected[item.Name]
				if item.Name == "Race" then
					item.ItemValue.Image = GameDataModule.RatingIcons[CreatureSelected.Rating]
				end
			elseif item.Name:match("Color") then
				item.ItemValue.BackgroundColor3 = Color3.new(CreatureSelected[item.Name].r, CreatureSelected[item.Name].g, CreatureSelected[item.Name].b)
			elseif item.Name:match("Talents") then
				local creatureTalent = CreatureSelected.Talents
				local temp = {}
				for _, talentFrame in pairs(item:GetChildren()) do
					if talentFrame:IsA("Frame") then
						for id, value in pairs(creatureTalent) do
							if not table.find(temp, id) then
								talentFrame.Title.Text = CreaturesTalentsModule.TalentsTable[id].Name
								talentFrame:SetAttribute("TextHover", CreaturesTalentsModule.TalentsTable[id].Desc:format(value,"%"))
								table.insert(temp, id)
								talentFrame.Visible = true
								break
							else
								talentFrame.Visible = false
							end
						end
					end
				end
			else
				if item:FindFirstChild("ItemValue") then
					if item.Name == "CreatureOwner" then
						if CreatureSelected["ListOfOwners"]["ActualOwner"] then
							item.ItemValue.Text = CreatureSelected["ListOfOwners"].ActualOwner ~= "" and game.Players:GetNameFromUserIdAsync(CreatureSelected["ListOfOwners"].ActualOwner) or "..."
						end

					elseif CreatureSelected["Maintenance"][item.Name] then
						item.ItemValue.Text = CreatureSelected["Maintenance"][item.Name].Value
						
					elseif typeof(CreatureSelected[item.Name]) == "table" then
						item.ItemValue.Text = CreatureSelected[item.Name].Value
						
					else
						item.ItemValue.Text = CreatureSelected[item.Name]
					end
				end
			end
        end
    end
end

--[[
	This function allow to set a horse model with good texture and colors, and materials for horse selected and good gender horse.
]]
local function SpawnGoodTargetForFusion(gender, direction, creatureID)
	--here we check gender and make a good system selector from list populate with all horse data (male list or female list)
	if gender == "Male" then
		if direction == "Right" then
			if indexMaleSelector + 1 > #CreatureMaleList then
				return
			end
			if indexMaleSelector < #CreatureMaleList  then
				indexMaleSelector += 1
			end
		elseif direction == "Left" then
			if indexMaleSelector - 1 < 1 then
				return
			end
			if indexMaleSelector ~= 1 then
				indexMaleSelector -= 1
			end
		end

		if creatureID then
			for index, data in pairs(CreatureMaleList) do
				if data.CreatureID == creatureID then
					indexMaleSelector = index
				end
			end
		end

		CreatureMaleSelected = CreatureMaleList[indexMaleSelector]
		--[[ cloneHorseModel.HumanoidRootPart.Gui.HorseName.Text = HorseMaleSelected.HorseName
		cloneHorseModel.HumanoidRootPart.Gui.HorseName.TextColor3 = Color3.fromRGB(85, 170, 255) ]]
	else
		if direction == "Right" then
			if indexFemaleSelector + 1 > #CreatureFemaleList then
				return
			end
			if indexFemaleSelector < #CreatureFemaleList  then
				indexFemaleSelector += 1
			end
		elseif direction == "Left" then
			if indexFemaleSelector - 1 < 1 then
				return
			end
			if indexFemaleSelector ~= 1 then
				indexFemaleSelector -= 1
			end
		end

		if creatureID then
			for index, data in pairs(CreatureFemaleList) do
				if data.CreatureID == creatureID then
					indexFemaleSelector = index
				end
			end
		end

		CreatureFemaleSelected = CreatureFemaleList[indexFemaleSelector]
		--[[ cloneHorseModel.HumanoidRootPart.Gui.HorseName.Text = HorseFemaleSelected.HorseName
		cloneHorseModel.HumanoidRootPart.Gui.HorseName.TextColor3 = Color3.fromRGB(255, 85, 255) ]]
	end

	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	local target = AutelFusion[gender.."Selector"]

	local cloneCreatureModel = target.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if cloneCreatureModel then
		cloneCreatureModel:Destroy()
		cloneCreatureModel = nil
	end
	
	--Here after selected gender and horse, we make all change on the instantiate horse model to show the good parameter of horse selected
	local selection = gender == "Male" and CreatureMaleSelected or CreatureFemaleSelected

	--If model horse never setup for this gender of horse selected we make one for the first time and after we use it and change only texture, colors and meterials
	if not cloneCreatureModel then
		cloneCreatureModel = ReplicatedStorage.Assets.CreaturesModels[selection.CreatureType.."ModelFusion"]:Clone()
		cloneCreatureModel.Name = "CloneCreatureModel"
		cloneCreatureModel.Parent = target.SpawnTarget

		--set idle anim creature
		local animCtrler = Instance.new("AnimationController", cloneCreatureModel)
		local animator = Instance.new("Animator", animCtrler)
		local AnimIdle = animator:LoadAnimation(ReplicatedStorage.Assets.Animations[selection.CreatureType].Idle)
		AnimIdle:Play()
		
		local _,s = cloneCreatureModel:GetBoundingBox()
		if gender == "Female" then
			cloneCreatureModel:PivotTo(target.SpawnTarget.CFrame * CFrame.new(s.X/2,0,0) * CFrame.Angles(0,0,math.rad(-90)))
		else
			cloneCreatureModel:PivotTo(target.SpawnTarget.CFrame * CFrame.new(s.X/2,0,0) * CFrame.Angles(math.rad(180),0,math.rad(-90)))
		end

		--We set the visual infinite rotation for platform where model is placed
		local info = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, 0) -- -1 is for repeat count which will be infinite, false is for bool reverses which means it will not go backwards
		local goals = {Orientation = Vector3.new(0, 360, 90)} --Rotating it 360 degrees will make it go back to the original starting point, and with an infinite repeat count, it will go forever.
		local tween = TweenService:Create(target.SpawnTarget, info, goals)
		tween:Play()

		--Rotation for Model horse
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

		--if model horse are remove, we clear all event and tween service who use for this and above pblm memory allowed
		local co
		co = target.SpawnTarget.ChildRemoved:Connect(function(child)
			co:Disconnect()
			steppedConnection:Disconnect()
			tween:Cancel()
			Spin1:Cancel()
			Spin2:Cancel()
			Spin3:Cancel()
			Spin4:Cancel()
			CFrameValue:Destroy()
		end)
	end

	cloneCreatureModel.CreatureID.Value = selection.CreatureID

	--we destroy horse invoked by player who correspond to the show horse into fusion system
	RemoteFunction.InvokHorsePlayer:InvokeServer(selection.CreatureID, true)

	if selection.Race == "Celestial" then
		cloneCreatureModel["Wing_Left"].Transparency = 0.01
		cloneCreatureModel["Wing_Right"].Transparency = 0.01
		cloneCreatureModel["Wing_Left"].TextureID = selection.Genes["Wing"]
		cloneCreatureModel["Wing_Right"].TextureID = selection.Genes["Wing"]
	else
		cloneCreatureModel["Wing_Left"].Transparency = 1
		cloneCreatureModel["Wing_Right"].Transparency = 1
	end

	ToolsModule.CheckEvolutionPartCreatureToAttribute(cloneCreatureModel, selection)

	-- Check all register accessory on this creature and setup them
	if selection["Accessory"] then
		for _, accessoryID in pairs(selection.Accessory) do
			ToolsModule.CreateAccessoryClientSide(accessoryID, selection.CreatureType, cloneCreatureModel)
		end
	end

	for typeGene, gene in pairs(selection.Genes) do
		if typeGene ~= "Wing" then
			for _, child in pairs(cloneCreatureModel:GetChildren()) do
				if string.lower(child.Name):match(string.lower(typeGene)) then
					if gene ~= "" then
						child.TextureID = AvailableGenesCollection[selection.Genes[typeGene]].TextureID
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
							--this allow to make a default texture for eye (actually only eye are a default texture)
							if selection.CreatureType == "Cat" then
								child.TextureID = "rbxassetid://10052299194"
							else
								child.TextureID = "rbxassetid://8476638575"
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
						local t = selection["ManeColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = selection["PartsMaterial"].Mane
					elseif string.lower(child.Name):match("marking") then
						local t = selection["Color"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = selection["PartsMaterial"].Marking
					elseif string.lower(child.Name):match("tail") then
						local t = selection["TailColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = selection["PartsMaterial"].Tail
					elseif string.lower(child.Name):match("socks") then
						local t = selection["SocksColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = selection["PartsMaterial"].Socks
					end
	
					--check if this Part contain Tattoo Texture and check if we need to setup this
					for _, texture in pairs(child:GetChildren()) do
						if texture:IsA("Texture") then
							if selection.Genes[texture.Name] ~= "" then
								texture.Texture = AvailableGenesCollection[selection.Genes[texture.Name]].TextureID
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

	-- After totally setup creature model for show it in Fusion system, we setup UI for Cost Fusion (only if Male and Female are selected)
	if CreatureMaleSelected and CreatureFemaleSelected then
		ClearCostUI()

		-- Little local function refactor to create ui of crystal cost
		local function MakeUICrystalCost(race, cost)
			local crystalCost = BreedingGui.Template.CostItem:Clone()
			crystalCost.Name = race.."Crystal"
			crystalCost.Parent = ShowCostFusionFrame
			crystalCost.Icon.Image = GameDataModule.DropCollectablesWithBorders[race.."Crystal"]
			crystalCost.IconBorder.Image = crystalCost.Icon.Image
			crystalCost.ValueTxt.Text = ToolsModule.DotNumber(tostring(PlayerDataModule.LocalData.Crystals[race.."Crystal"])).." / "..ToolsModule.DotNumber(tostring(cost))
			if tonumber(cost) <= PlayerDataModule.LocalData.Crystals[race.."Crystal"] then
				crystalCost.ValueTxt.TextColor3 = Color3.fromRGB(0, 255, 0)
			else
				crystalCost.ValueTxt.TextColor3 = Color3.fromRGB(255, 0, 0)
			end
			crystalCost.Visible = true
		end

		if CreatureMaleSelected.Race == CreatureFemaleSelected.Race then
			MakeUICrystalCost(CreatureMaleSelected.Race, GameDataModule.CoastFusion.Crystals[CreatureMaleSelected.Race]*2)
		else
			MakeUICrystalCost(CreatureMaleSelected.Race, GameDataModule.CoastFusion.Crystals[CreatureMaleSelected.Race])
			MakeUICrystalCost(CreatureFemaleSelected.Race, GameDataModule.CoastFusion.Crystals[CreatureFemaleSelected.Race])
		end
		
		local goldcost = GameDataModule.CoastFusion.Rarity[CreatureMaleSelected.Race] + GameDataModule.CoastFusion.Rarity[CreatureFemaleSelected.Race]
		local goldCostUI = BreedingGui.Template.CostItem:Clone()
		goldCostUI.Name = "GoldsCost"
		goldCostUI.LayoutOrder = 2
		goldCostUI.Parent = ShowCostFusionFrame
		goldCostUI.Icon.Image = GameDataModule.DropCollectablesWithBorders.Ecus
		goldCostUI.IconBorder.Image = goldCostUI.Icon.Image
		goldCostUI.ValueTxt.Text = ToolsModule.DotNumber(tostring(PlayerDataModule.LocalData.Ecus)).." / "..ToolsModule.DotNumber(tostring(goldcost))
		if goldcost <= PlayerDataModule.LocalData.Ecus then
			goldCostUI.ValueTxt.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			goldCostUI.ValueTxt.TextColor3 = Color3.fromRGB(255, 0, 0)
		end
		goldCostUI.Visible = true
	end
end

local function SpawnChildResultFusion(childData, childID)
	LaunchParticleFusion(false)
	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	local target = AutelFusion.ShowChildFusion
	local cloneCreatureModel:Model = target.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if cloneCreatureModel then
		cloneCreatureModel:Destroy()
		cloneCreatureModel = nil
	end
	
	--If model horse never setup for this gender of horse selected we make one for the first time and after we use it and change only texture, colors and meterials
	if not cloneCreatureModel then
		cloneCreatureModel = ReplicatedStorage.Assets.CreaturesModels[childData.CreatureType.."ModelFusion"]:Clone()
		cloneCreatureModel.Name = "CloneCreatureModel"
		cloneCreatureModel.Parent = target.SpawnTarget

		--set idle anim creature
		local animCtrler = Instance.new("AnimationController", cloneCreatureModel)
		local animator = Instance.new("Animator", animCtrler)
		local AnimIdle = animator:LoadAnimation(ReplicatedStorage.Assets.Animations[childData.CreatureType].Idle)
		AnimIdle:Play()
		
		local _,s = cloneCreatureModel:GetBoundingBox()
		cloneCreatureModel:PivotTo(target.SpawnTarget.CFrame * CFrame.new(s.X/4,0,0) * CFrame.Angles(0,0,math.rad(-90)))

		--We set the visual infinite rotation for platform where model is placed
		local info = TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, 0) -- -1 is for repeat count which will be infinite, false is for bool reverses which means it will not go backwards
		local goals = {Orientation = Vector3.new(0, 360, 90)} --Rotating it 360 degrees will make it go back to the original starting point, and with an infinite repeat count, it will go forever.
		local tween = TweenService:Create(target.SpawnTarget, info, goals)
		tween:Play()

		--Rotation for Model horse
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

		--if model horse are remove, we clear all event and tween service who use for this and above pblm memory allowed
		target.SpawnTarget.ChildRemoved:Connect(function(child)
			steppedConnection:Disconnect()
			tween:Cancel()
			Spin1:Cancel()
			Spin2:Cancel()
			Spin3:Cancel()
			Spin4:Cancel()
			CFrameValue:Destroy()
		end)
	end

	--cloneHorseModel.HumanoidRootPart.Gui.Enabled = false
	--[[ cloneHorseModel.HumanoidRootPart.Gui.HorseName.Text = childData.HorseName
	if childData.HorseName == "Female" then
		cloneHorseModel.HumanoidRootPart.Gui.HorseName.TextColor3 = Color3.fromRGB(255, 85, 255)
	else
		cloneHorseModel.HumanoidRootPart.Gui.HorseName.TextColor3 = Color3.fromRGB(85, 170, 255)
	end ]]

	cloneCreatureModel.CreatureID.Value = childID

	if childData.Race == "Air" then
		cloneCreatureModel["Wing_Left"].Transparency = 0.01
		cloneCreatureModel["Wing_Right"].Transparency = 0.01
	else
		cloneCreatureModel["Wing_Left"].Transparency = 1
		cloneCreatureModel["Wing_Right"].Transparency = 1
	end

	ToolsModule.CheckEvolutionPartCreatureToAttribute(cloneCreatureModel, childData)

	-- Change size for look like baby
	--cloneCreatureModel:ScaleTo(0.5)
	for _, child in pairs(cloneCreatureModel:GetChildren()) do
		if child:IsA("BasePart") then
			ToolsModule.ScaleMesh(Vector3.new(0.5,0.5,0.5), child)
		end
	end
	cloneCreatureModel.Tetine.Transparency = 0

	for typeGene, gene in pairs(childData.Genes) do
		if typeGene ~= "Wing" then
			for _, child in pairs(cloneCreatureModel:GetChildren()) do
				if string.lower(child.Name):match(string.lower(typeGene)) then
					if gene ~= "" then
						child.TextureID = AvailableGenesCollection[childData.Genes[typeGene]].TextureID
						if string.lower(child.Name):match(string.lower("Accessory")) or string.lower(child.Name):match(string.lower("Eye")) then
							child.Transparency = 0.01
						else
							child.Transparency = 0
						end
	
						if childData["CreatureType"] == "Cat" and child.Name == "Mane" and childData["Race"] == "Normal" then
							child.Transparency = 1
							child.TextureID = ""
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
							--this allow to make a default texture for eye (actually only eye are a default texture)
							if childData["CreatureType"] == "Cat" then
								child.TextureID = "rbxassetid://10052299194"
							else
								child.TextureID = "rbxassetid://8476638575" 
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
						local t = childData["ManeColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = childData["PartsMaterial"].Mane
					elseif string.lower(child.Name):match("marking") then
						local t = childData["Color"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = childData["PartsMaterial"].Marking
					elseif string.lower(child.Name):match("tail") then
						local t = childData["TailColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = childData["PartsMaterial"].Tail
					elseif string.lower(child.Name):match("socks") then
						local t = childData["SocksColor"]
						child.Color = Color3.new(t.r, t.g, t.b)
						child.Material = childData["PartsMaterial"].Socks
					end
	
					--check if this Part contain Tattoo Texture and check if we need to setup this
					for _, texture in pairs(child:GetChildren()) do
						if texture:IsA("Texture") then
							if childData.Genes[texture.Name] ~= "" then
								texture.Texture = AvailableGenesCollection[childData.Genes[texture.Name]].TextureID
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

	FusionInProgress = false
	EnableButtons(true)
	PopulateCharacteristicsInfosFrame(InfosChildFrame.Characteristics, childData)
	ActionsButtons.RefreshBtn.Visible = true

	-- Little spawn function to update the growth time of child show in UI where we make button pay instant growth time creature
	task.spawn(function()
		repeat
			-- Check if player are VIP and apply time /2 if yes
			local TimeGrowthVIP = RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.VIP.ProductID) and GameDataModule.TimeGrowthHorseGoal/2 or GameDataModule.TimeGrowthHorseGoal
			-- Convert this time in horloge time can show in ui
			local hour,min,sec = ToolsModule.ConvertSecToHour(TimeGrowthVIP - PlayerDataModule.LocalData.CreaturesCollection[childID].TimeGrowthValue)
			Background.GrowthInfoFrame.Frame.GrowthTime.Text = hour.." : "..min.." : "..sec
			Background.GrowthInfoFrame.Frame.BuyInstantGrowth.CreatureID.Value = childID
			task.wait(0.1)
		until not AutelFusion.ShowChildFusion.SpawnTarget:FindFirstChild("CloneCreatureModel")
		Background.GrowthInfoFrame.Frame.BuyInstantGrowth.CreatureID.Value = ""
	end)
	
	SeeChildOnClick()
end

--[[
	This function allow to get all model in fusion system and show or hide all genes from all model to best visibility on legacy parent for child.
	In button we have a value boolean if it's true all gens are visible, if it's false, all gene are hiden
]]
local function SetVisibilityGenesAllModelFusion()
	local child = AutelFusion.ShowChildFusion.SpawnTarget:FindFirstChildWhichIsA("Model")
	local female = AutelFusion.FemaleSelector.SpawnTarget:FindFirstChildWhichIsA("Model")
	local male = AutelFusion.MaleSelector.SpawnTarget:FindFirstChildWhichIsA("Model")

	local t = {
		["FemaleSelector"] = female,
		["MaleSelector"] = male,
		["ShowChildFusion"] = child
	}

	if child and female and male then
		if ActionsButtons.RefreshBtn.WithGenes.Value then
			ActionsButtons.RefreshBtn.WithGenes.Value = false
			for index, model in pairs(t) do
				if model then
					for _, child in pairs(model:GetChildren()) do
						if child:IsA("MeshPart") then
							if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
								tempGeneModel[index][child.Name] = child.TextureID
								child.TextureID = ""
								for _, v in pairs(child:GetChildren()) do
									if v:IsA("Texture") then
										tempTextureModel[index][v.Name] = v.Texture
										v.Texture = ""
									end
								end
							end
						end
					end
				end
			end
		else
			ActionsButtons.RefreshBtn.WithGenes.Value = true
			for index, model in pairs(t) do
				if model then
					for _, child in pairs(model:GetChildren()) do
						if child:IsA("MeshPart") then
							if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
								if tempGeneModel[index][child.Name] then
									child.TextureID = tempGeneModel[index][child.Name]
									for _, v in pairs(child:GetChildren()) do
										if v:IsA("Texture") then
											v.Texture = tempTextureModel[index][v.Name]
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

local function RemoveChildModel()
	local model = AutelFusion.ShowChildFusion.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if model then
		model:Destroy()
	end

	ActionsButtons.RefreshBtn.Visible = false

	tempGeneModel = {
		MaleSelector = {};
		FemaleSelector = {};
		ShowChildFusion = {};
	}
	tempTextureModel = {
		MaleSelector = {};
		FemaleSelector = {};
		ShowChildFusion = {};
	}
end

--[[
	We check if model of horse are available for female and male and if yes remove it to clean
]]
local function RemoveModelsCreature()
	local model = AutelFusion.FemaleSelector.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if model then
		model:Destroy()
	end
	
	model = AutelFusion.MaleSelector.SpawnTarget:FindFirstChild("CloneCreatureModel")
	if model then
		model:Destroy()
	end

	RemoveChildModel()
end

--[[
	Reset properly data list, index and horses selected
]]
local function DepopulateCreaturesDataLists()
	CreatureMaleList = {}
	CreatureFemaleList = {}
	CreatureMaleSelected = nil
	CreatureFemaleSelected = nil
	indexFemaleSelector = 0
	indexMaleSelector = 0
end

--[[
	Heer we check horse available for player and if horse are not in nursery or a foal, we add it to the good gender list to allow show model in world when is selected from list
]]
local function PopulateCreaturesDataLists()
	DepopulateCreaturesDataLists()
	local AvailableCreaturesCollection = PlayerDataModule.LocalData.CreaturesCollection

	-- Remove isDELETE creature from collection
	for index, data in pairs(AvailableCreaturesCollection) do
		if data["isDELETE"] then
			AvailableCreaturesCollection[index] = nil
		end
	end
	
	for index, datas in pairs(AvailableCreaturesCollection) do
		if not datas["InNursery"] then
			if datas["Growth"] ~= "Baby" then
				if datas["CreatureType"] == CreatureTypeSelected then
					if datas["Gender"] == "Male" then
						local d = datas
						d["CreatureID"] = index
						table.insert(CreatureMaleList, d)
					else
						local d = datas
						d["CreatureID"] = index
						table.insert(CreatureFemaleList, d)
					end
				end
			end
		end
	end
end

--[[
	Allow to reset and update properly the data horse in list
]]
local function UpdateCreaturesDataLists()
	RemoveModelsCreature()
	PopulateCreaturesDataLists()
end

--[[
	This function allow to make a focus on scroll list of fusion creature on selectedCreature.
	Function get all children in list, check if visibility are true to count only visible gender selected and make a sorted table from layoutorder for calculate
	properly the position in scroll frame.
	When player click on show list and a creature already selected, function can found position in scroll list and setup the good canvas position to go auto at the good
	item frame in list.
]]
local function FocusScrollOnLastCreatureOfListBreeding(lastCreatureGender)
	local selectedItem
	local nbVisibleElement = 0
	local actualPos

	--get all children of bredding
	local children = HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding:GetChildren()

	--sorted all children by layout order represent the time breed
	local sortedTargets = {}
	for _, child in pairs(children) do
		if child:IsA("Frame") then
			sortedTargets[#sortedTargets+1] = {key = child, value = child.LayoutOrder}
		end
	end
	table.sort(sortedTargets, function(a, b)
		return a.value < b.value
	end)
	
	--check nb element visible we have and get the actual pos of selected item in this list
	for _, target in ipairs(sortedTargets) do
		if target.key:IsA("Frame") then
			if target.key.Visible then
				local t = target.key:FindFirstChildWhichIsA("ViewportFrame")
				if t then
					if t.Name == lastCreatureGender.CreatureID then
						selectedItem = target.key
						actualPos = nbVisibleElement+1
					end
				end
				nbVisibleElement+=1
			end
		end
	end

	--calculate the new canvas position to found the item by position and number of element in scroll list
	if selectedItem then
		local maxElem = nbVisibleElement
		local nbElementPerLine = 1
		local nbLine = math.floor((maxElem/nbElementPerLine)+0.5)
		local lineToShow = math.floor(((actualPos * nbLine)/maxElem)+0.5)

		repeat
			--wait until CanvasSize automatic calculation are not finish
			task.wait(0.1)
		until HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.CanvasSize.Y.Offset ~= 0

		local incrementPos = HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.CanvasSize.Y.Offset / nbLine
		local newPos = incrementPos * (lineToShow-1)

		--print("test newpos", maxElem, nbLine, actualPos, lineToShow, incrementPos, newPos)

		--if selectItem same absolute position with padding less as List UI it's first item so don't scroll (+4 is because using  of padding)
		if math.floor(selectedItem.AbsolutePosition.Y + 0.5) == math.floor(HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.AbsolutePosition.Y + 0.5) + 4 then
			return
		end

		--make tween animation for scroll smooth to new position
		if HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.CanvasPosition ~= Vector2.new(0, newPos) then
			local tweenInfo = TweenInfo.new(
				0.5, -- Time
				Enum.EasingStyle.Linear, -- EasingStyle
				Enum.EasingDirection.Out, -- EasingDirection
				0, -- RepeatCount (when less than zero the tween will loop indefinitely)
				false, -- Reverses
				0 -- DelayTime
			)
		
			local tween = TweenService:Create(HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding, tweenInfo, {CanvasPosition = Vector2.new(0, newPos)})
			
			tween:Play()
		end
	end
end

--[[
	This function allow to enable and setup for the gender selected the UI list of creature available
]]
local function SelectCreature(gender)
	HorsesCollectionGui.Enabled = true
	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.Populate.Value = false
	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.Populate.Value = true
	task.wait(.1)
	for _, creature in pairs(HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding:GetChildren()) do
		if creature:IsA("Frame") then
			if creature.CreatureType.Value == CreatureTypeSelected and creature.CreatureGender.Value == gender and creature.CreatureGrowth.Value == "Adult" then
				creature.Visible = true
				creature.ItemImgBtn.Activated:Connect(function()
					--spawn target when click to show model of creature selected at slot defined by gender
					local t = creature:FindFirstChildWhichIsA("ViewportFrame")
					print("TEST CLICKED", t.Name)
					SpawnGoodTargetForFusion(gender, nil, t.Name)
					RemoveChildModel()

					--here we get local data of creature and make update ui characteristic of creature selected for fusion
					PopulateCharacteristicsInfosFrame(HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.ScrollingFrame, PlayerDataModule.LocalData.CreaturesCollection[t.Name])
					HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.Visible = true
				end)
			else
				creature.Visible = false
			end
		end
	end

	--before to show ui check position depending of gender and check if last selected gender to setup ui at the good position
	if gender == "Male" then
		--set focus scroll list on last creature selected and populate characteristics ui
		if CreatureMaleSelected then
			FocusScrollOnLastCreatureOfListBreeding(CreatureMaleSelected)
			PopulateCharacteristicsInfosFrame(HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.ScrollingFrame, CreatureMaleSelected)
		end

		--make miror ui for gender
		HorsesCollectionGui.CreaturesListForBreedingBack.Position = UDim2.fromScale(0.87, 0.556)
		HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.Position = UDim2.fromScale(-0.065, HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.Position.Y.Scale)
	else
		--set focus scroll list on last creature selected and populate characteristics ui
		if CreatureFemaleSelected then
			FocusScrollOnLastCreatureOfListBreeding(CreatureFemaleSelected)
			PopulateCharacteristicsInfosFrame(HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.ScrollingFrame, CreatureFemaleSelected)
		end

		--make miror ui for gender
		HorsesCollectionGui.CreaturesListForBreedingBack.Position = UDim2.fromScale(0.13, 0.556)
		HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.Position = UDim2.fromScale(1.98, HorsesCollectionGui.CreaturesListForBreedingBack.SelectedCharacteristicsUI.Position.Y.Scale)
	end

	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.Position = UDim2.fromScale(0.5, HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.Position.Y.Scale)
	HorsesCollectionGui.CreaturesListForBreedingBack.Visible = true
end

--[[
	This function is call for return a connection to a click or touch began for player into breeding system to detect when player click or touch a model
	to hide all genes of model target.
]]
local function SeeGenesClickBeganOnModel(parentName)
	local connection = UserInputService.InputBegan:Connect(function(key,IsTyping)
		if not IsTyping then
			if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
				if Mouse.Target then
					local model = Mouse.Target:FindFirstAncestorWhichIsA("Model")
					if model then
						local parent = model:FindFirstAncestor(parentName)
						if parent and ActionsButtons.RefreshBtn.WithGenes.Value then -- here we check the value of gobal show gene to dodge a conflict visibility of gene
							modelGeneClickBegan = model
							for _, child in pairs(model:GetChildren()) do
								if child:IsA("MeshPart") then
									if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
										tempGeneModel[parentName][child.Name] = child.TextureID
										child.TextureID = ""
										for _, v in pairs(child:GetChildren()) do
											if v:IsA("Texture") then
												tempTextureModel[parentName][v.Name] = v.Texture
												v.Texture = ""
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	return connection
end

--[[
	This function work in pair with SeeGenesClickBeganOnModel. When player release click or touch, if model was previously targeted by SeeGenesClickBeganOnModel function,
	we cancel remove all genes to reset visual model of creature and allo player to see without button juste on press and release the differents appearence of creature.
]]
local function SeeGenesClickReleaseOnModel(parentName)
	local connection = UserInputService.InputEnded:Connect(function(key,IsTyping)
		if not IsTyping then
			if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
				if modelGeneClickBegan then
					if modelGeneClickBegan:FindFirstAncestor(parentName) then
						for _, child in pairs(modelGeneClickBegan:GetChildren()) do
							if child:IsA("MeshPart") then
								if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
									child.TextureID = tempGeneModel[parentName][child.Name]
									for _, v in pairs(child:GetChildren()) do
										if v:IsA("Texture") then
											v.Texture = tempTextureModel[parentName][v.Name]
										end
									end
								end
							end
						end
						modelGeneClickBegan = nil
					end
				end
			end
		end
	end)

	return connection
end

--[[
	This function allow to setup camera and ui when player click on model child to see it in details.
]]
function SeeChildOnClick()
	if CameraChildPos then
		local camera = workspace.CurrentCamera

		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local tween = TweenService:Create(camera, tweenInfo, {CFrame = CameraChildPos.CFrame})
		tween:Play()
		tween.Completed:Wait()
		InfosChildFrame.Visible = true
		BackChildBtn.Visible = true

		-- When zoom on child check if it's baby or not to show UI buy instant growth up
		local creatureID = Background.GrowthInfoFrame.Frame.BuyInstantGrowth.CreatureID.Value
		if creatureID ~= "" then
			if PlayerDataModule.LocalData.CreaturesCollection[creatureID].Growth == "Baby" then
				Background.GrowthInfoFrame.Visible = true
			end
		end

		ActionsButtons.Visible = false
		FemaleNavButtons.Visible = false
		MaleNavButtons.Visible = false
		CreatureTypeDropdown.Visible = false

		--[[
			This event allow to remove or to replace the gene of child fusion. With this button player can see is creature with or not with gene.
			By default the gene are showed and if player click first time, we stock gene in temp dic for reapply gene if player release click or touch.
		]]
		connectionChildGeneBegan = SeeGenesClickBeganOnModel("ShowChildFusion")
		connectionChildGeneRelease = SeeGenesClickReleaseOnModel("ShowChildFusion")

	end
end

--[[
	This function make a event connection to activate the function SeeChildOnClick when player click or touch the child model.
]]
local function ActiveClickSeeChild()
	connectionClickOnModel = UserInputService.InputBegan:Connect(function(key,IsTyping)
		if not IsTyping then
			if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
				if Mouse.Target then
					local model = Mouse.Target:FindFirstAncestorWhichIsA("Model")
					if model then
						local parent = model:FindFirstAncestor("ShowChildFusion")
						if parent then
							--when model is found disconnect now because we can create conflict with other connection for the behavior child zoom
							connectionClickOnModel:Disconnect()
							SeeChildOnClick()
						end
					end
				end
			end
		end
	end)
end

BackChildBtn.Activated:Connect(function()
	local camera = workspace.CurrentCamera
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {CFrame = CameraPartPos.CFrame})
	tween:Play()
	InfosChildFrame.Visible = false
	BackChildBtn.Visible = false
	Background.GrowthInfoFrame.Visible = false
	tween.Completed:Wait()
	ActionsButtons.Visible = true
	FemaleNavButtons.Visible = true
	MaleNavButtons.Visible = true
	CreatureTypeDropdown.Visible = true
	ShowCostFusionFrame.Visible = true

	--disconnect event began and release of child to dodge the conflict with zoom click/touch
	connectionChildGeneBegan:Disconnect()
	connectionChildGeneRelease:Disconnect()

	--when bakc button is clicked we reactivate the behavior of click/touch on child zoom
	ActiveClickSeeChild()
end)

--[[
	Behavior of button to buy in Robux instant growth creature. Client call remote function InstantGrowthTime server with Id of animal to instant growth.
]]
Background.GrowthInfoFrame.Frame.BuyInstantGrowth.Activated:Connect(function()
	if Background.GrowthInfoFrame.Frame.BuyInstantGrowth.CreatureID.Value ~= "" then
		Background.GrowthInfoFrame.Visible = false
		local result = RemoteFunction.InstantGrowthTime:InvokeServer(Background.GrowthInfoFrame.Frame.BuyInstantGrowth.CreatureID.Value)
		if not result then
			Background.GrowthInfoFrame.Visible = true
		end
	end
end)

local function NavButtonBehavior(gender, dir)
	if not ActionsButtons.RefreshBtn.WithGenes.Value then
		SetVisibilityGenesAllModelFusion()
	end
	SpawnGoodTargetForFusion(gender, dir)
	RemoveChildModel()
end

--Call from Click Detector to select horse from corresponding list gender
FemaleNavButtons.Previous.Activated:Connect(function()
	if not FusionInProgress then
		if #CreatureFemaleList > 0 then
			NavButtonBehavior("Female", "Left")
		end
	end
end)

FemaleNavButtons.Next.Activated:Connect(function()
	if not FusionInProgress then
		if #CreatureFemaleList > 0 then
			NavButtonBehavior("Female", "Right")
		end
	end
end)

FemaleNavButtons.SelectCreature.Activated:Connect(function()
	if not ActionsButtons.RefreshBtn.WithGenes.Value then
		SetVisibilityGenesAllModelFusion()
	end
	FemaleNavButtons.Next.Visible = HorsesCollectionGui.CreaturesListForBreedingBack.Visible
	FemaleNavButtons.Previous.Visible = HorsesCollectionGui.CreaturesListForBreedingBack.Visible
	if not HorsesCollectionGui.CreaturesListForBreedingBack.Visible then
		SelectCreature("Female")
		MaleNavButtons.Visible = false
		FemaleNavButtons.SelectCreature.Txt.Text = "Close"
		FemaleNavButtons.Position = UDim2.fromScale(0.2, 0.9)
	else
		HorsesCollectionGui.CreaturesListForBreedingBack.Visible = false
		MaleNavButtons.Visible = true
		FemaleNavButtons.SelectCreature.Txt.Text = "Select"
		FemaleNavButtons.Position = UDim2.fromScale(0.8, 0.9)
	end
end)

MaleNavButtons.SelectCreature.Activated:Connect(function()
	if not ActionsButtons.RefreshBtn.WithGenes.Value then
		SetVisibilityGenesAllModelFusion()
	end
	MaleNavButtons.Next.Visible = HorsesCollectionGui.CreaturesListForBreedingBack.Visible
	MaleNavButtons.Previous.Visible = HorsesCollectionGui.CreaturesListForBreedingBack.Visible
	if not HorsesCollectionGui.CreaturesListForBreedingBack.Visible then
		SelectCreature("Male")
		FemaleNavButtons.Visible = false
		MaleNavButtons.SelectCreature.Txt.Text = "Close"
		MaleNavButtons.Position = UDim2.fromScale(0.8, 0.9)
	else
		HorsesCollectionGui.CreaturesListForBreedingBack.Visible = false
		FemaleNavButtons.Visible = true
		MaleNavButtons.SelectCreature.Txt.Text = "Select"
		MaleNavButtons.Position = UDim2.fromScale(0.2, 0.9)
	end
end)

MaleNavButtons.Previous.Activated:Connect(function()
	if not FusionInProgress then
		if #CreatureMaleList > 0 then
			NavButtonBehavior("Male", "Left")
		end
	end
end)

MaleNavButtons.Next.Activated:Connect(function()
	if not FusionInProgress then
		if #CreatureMaleList > 0 then
			NavButtonBehavior("Male", "Right")
		end
	end
end)

--Button to show or hide all genes on all model in fusion system
ActionsButtons.RefreshBtn.Activated:Connect(function()
	SetVisibilityGenesAllModelFusion()
end)

--Button to valid horses used for fusion and make a baby. Now BabyName is random name.
ActionsButtons.FusionBtn.Activated:Connect(function()
	HorsesCollectionGui.CreaturesListForBreedingBack.Visible = false
	if not FusionInProgress then
		if CreatureMaleSelected and CreatureFemaleSelected then
			local fatherID = CreatureMaleSelected.CreatureID
			local motherID = CreatureFemaleSelected.CreatureID

			RemoteFunction:WaitForChild("MoveHorsesToNursery"):InvokeServer(fatherID, motherID, "")
		else
			warn("Select horse to fusion before create !")
		end
	end
end)

local function ResetButtonSize()
	for _, Button in pairs(CreatureTypeDropdown:GetChildren()) do
		if Button:IsA("ImageButton") then
			Button.Size = UDim2.fromScale(0.387, 0.772)
		end
	end
end

for _, Button in pairs(CreatureTypeDropdown:GetChildren()) do
	if Button:IsA("ImageButton") then
		Button.Activated:Connect(function()
			if not FusionInProgress then
				ResetButtonSize()
				Button.Size = UDim2.fromScale(0.434, 0.844)
				ClearCostUI()
				CreatureTypeSelected = Button.Name
				UpdateCreaturesDataLists()
			end
		end)
	end
end

RemoteEvent.CreaturesFusionLaunch.OnClientEvent:Connect(function()
	if not FusionInProgress then
		ShowCostFusionFrame.Visible = false
		EnableButtons(false)
		RemoveChildModel()
		print("Parent move to nursery !")
		LaunchParticleFusion(true)
		FusionInProgress = true
	end
end)

local function SetCreatureListUI()
	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.Size = UDim2.fromScale(0.92, 0.92)
	HorsesCollectionGui.CreaturesListForBreedingBack.Size = UDim2.fromScale(0.193, 0.574)
	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.UIGridLayout.CellSize = UDim2.fromScale(0.4,0.2)
	HorsesCollectionGui.CreaturesListForBreedingBack.CreaturesListForBreeding.UIGridLayout.FillDirectionMaxCells = 2
end

--Event call first time when player enter in fusion systeme in world
ReplicatedStorage.RemoteEvent.ActivateFusionSystem.OnClientEvent:Connect(function()
	SetCreatureListUI()
	ToolsModule.MakeOthersPlayersInvisible(true)
	PopulateCreaturesDataLists()
	if CameraPartPos then
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
		local tween = TweenService:Create(camera, tweenInfo, {CFrame = CameraPartPos.CFrame})
		tween:Play()

		controls:Disable()
		Background.Visible = true

		ToolsModule.EnableOtherUI(false, {"BreedingGui"})
		--reset position player to make good feel with launch
		LocalPlayer.Character.HumanoidRootPart.CFrame = AutelFusion.ResetPos.CFrame

		ActiveClickSeeChild()

		--connect to event active or disable genes on model Male
		connectionMaleGeneBegan = SeeGenesClickBeganOnModel("MaleSelector")
		connectionMaleGeneRelease = SeeGenesClickReleaseOnModel("MaleSelector")

		--connect to event active or disable genes on model Female
		connectionFemaleGeneBegan = SeeGenesClickBeganOnModel("FemaleSelector")
		connectionFemaleGeneRelease = SeeGenesClickReleaseOnModel("FemaleSelector")
	end
end)

--[[
	Event button to exit Auction House, we make camera to player, disable auction house gui and reset searching data
]]
ActionsButtons.LeaveBtn.Activated:Connect(function()
	ClearCostUI()

	HorsesCollectionGui.CreaturesListForBreedingBack.Visible = false
	ToolsModule.MakeOthersPlayersInvisible(false)

	if not FusionInProgress then
		UpdateCreaturesDataLists()
	end

	connectionClickOnModel:Disconnect()

	connectionMaleGeneBegan:Disconnect()
	connectionMaleGeneRelease:Disconnect()

	connectionFemaleGeneBegan:Disconnect()
	connectionFemaleGeneRelease:Disconnect()

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
	controls:Enable()
	Background.Visible = false
	ToolsModule.EnableOtherUI(true, {"BreedingGui"})
end)

ActionsButtons.RefreshBtn.WithGenes.Changed:Connect(function()
	if ActionsButtons.RefreshBtn.WithGenes.Value then
		ActionsButtons.RefreshBtn.RefreshTxt.Text = "Hide All Genes"
	else
		ActionsButtons.RefreshBtn.RefreshTxt.Text = "Show All Genes"
	end
end)

ReplicatedStorage.RemoteEvent.SpawnChildFusionModel.OnClientEvent:Connect(SpawnChildResultFusion)