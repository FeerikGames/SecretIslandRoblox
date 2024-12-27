local ReplicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("SharedSync")
local require = require(ReplicatedStorage.Modules:WaitForChild("RequireModule"))
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

--Remote
local RemoteFunction = ReplicatedStorage:FindFirstChild("RemoteFunction")
local RemoteEvent = ReplicatedStorage.RemoteEvent
local GetTypeOfGenes = ReplicatedStorage.RemoteFunction:WaitForChild("GetTypeOfGenes")
local GetSpeciesOfItem = ReplicatedStorage.RemoteFunction:WaitForChild("GetSpeciesOfItem")
local FilterMessageEvent = ReplicatedStorage.RemoteEvent.FilterMessage

--Require
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local FilterManager = require("FilterManager")
local PlayerDataModule = require("ReplicatedPlayerData")
local WalkSpeedModule = require("WalkSpeedModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")
local HorsesCollectionShopModule = require(script.Parent.HorsesCollectionShopModule)

--Filters
local FilterGui = UIProviderModule:GetUI("FilterGui")
local UIFilterBackground = FilterGui:WaitForChild("FilterBackground")
local CreaturesCollectionFilters = {"CreatureType", "Race", "Gender", "Rating", "Growth"--[[ , "InNursery", "Stallion" ]]}

local RenderCreatureModelFolder = Instance.new("Folder", workspace)
RenderCreatureModelFolder.Name = "RenderCreatureModelFolder"

local CollectionsHouse = game.Workspace:WaitForChild("CollectionsHouse")

--UI
local AllButtonsMainMenusGui = UIProviderModule:GetUI("AllButtonsMainMenusGui")
local PlayerInfoGui = UIProviderModule:GetUI("PlayerInfosGui")
local HorsesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
local UIBackground = HorsesCollectionGui:WaitForChild("Background")
local ItemHoverTextTemplate = HorsesCollectionGui.Template.ItemHoverTextTemplate
local ItemGeneList = HorsesCollectionGui.Template.ItemGeneList
local ScrollingFrame = UIBackground:WaitForChild("ScrollingFrame")
local CreaturesListForBreeding = HorsesCollectionGui:WaitForChild("CreaturesListForBreedingBack"):WaitForChild("CreaturesListForBreeding")
local ShowUiBtn = AllButtonsMainMenusGui.HorsesCollectionGuiBtn
local UIDetailsHorse = UIBackground:FindFirstChild("DetailsHorse")
local SellFrame = HorsesCollectionGui:WaitForChild("SellFrame")
local RenameFrame = HorsesCollectionGui:WaitForChild("RenameFrame")

local FavouritesImg = "rbxassetid://5078542968"
local UnFavouritesImg = "rbxassetid://5078542682"

local CameraEnabled = CameraController.GetEnabled()
local PopupDeleteVisible = false

--variable for ui page system
local CreaturesCollectionNbElementByPage = 6
local CreaturesCollectionNbValuePage = CreaturesCollectionNbElementByPage
local CreaturesCollectionIndexPage = 1
local CreaturesCollectionPageInfo = 1
local CreaturesCollectionPageMaxInfo = 1

--Variable for SHow/Hide Genes Model
local tempGeneModel = {}
local tempTextureModel = {}
local modelGeneClickBegan
local connectionModelGeneBegan
local connectionModelGeneRelease
local Mouse = game.Players.LocalPlayer:GetMouse()

--[[
	Init interface visibility
]]
local function InitInterfaceVisibility()
	UIBackground.Visible = false
	ScrollingFrame.Visible = true
	UIDetailsHorse.Visible = false
	FilterManager.CleanFilters()

	UIBackground.PagesCollections.Visible = true
	UIBackground.ScrollingFrame.Visible = true
	
	UIDetailsHorse.CreatureID.Value = ""
	UIDetailsHorse.Infos2Frames.CharacteristicsUI.Visible = false
	UIDetailsHorse.Infos2Frames.EntretienUI.Visible = false
	UIDetailsHorse.Infos2Frames.GenesUI.Visible = false
	UIDetailsHorse.Infos2Frames.AccessoryUI.Visible = false
	UIDetailsHorse.Infos2Frames.BackgroundFramePreview.Visible = false

	UIDetailsHorse.Infos2Frames.GenesUI.GenesListChoosen.Visible = false
end

local function ShowCreatureInCollection()
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		local RF_GetThemeCreature = game.ReplicatedStorage.RemoteFunctions:WaitForChild("GetThemeCreature", 5)
		if RF_GetThemeCreature then
			local filter = RF_GetThemeCreature:InvokeServer()
			local t = FilterManager.GetFiltersChoose()
			if filter ~= "All" then
				t["CreatureType"] = filter
			else
				t["CreatureType"] = nil
			end

			PopulateDataCreaturesCollection(t)
			return
		end
	end

	PopulateDataCreaturesCollection(FilterManager.GetFiltersChoose())
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
	
	
	clone.Parent = UIDetailsHorse.Infos1
	local iconsData = GameDataModule[dataName.."Icons"]
	if iconsData then
		clone.Image = iconsData[tostring(dataValue):gsub("^%l", string.upper)]
	end
end

--[[
	Little function to setup visual Baby to Adult
]]
local function GrowthModelBabyToAdult()
	for _, child in pairs(UIBackground.ScrollingFrame:GetDescendants()) do
		if child.Name == UIDetailsHorse.CreatureID.Value then
			local exist = child.WorldModel:FindFirstChildWhichIsA("Model")
			if exist then
				--exist:ScaleTo(1)
				local scale = 1/0.5
				for _, child in pairs(exist:GetChildren()) do
					if child:IsA("BasePart") then
						ToolsModule.ScaleMesh(Vector3.new(scale,scale,scale), child)
					end
				end
				exist.Tetine.Transparency = 1
				break
			end
		end
	end

	local exist = RenderCreatureModelFolder:FindFirstChild("CreatureModelCloneForRender")
	if exist then
		--exist:ScaleTo(1)
		local scale = 1/0.5
		for _, child in pairs(exist:GetChildren()) do
			if child:IsA("BasePart") then
				ToolsModule.ScaleMesh(Vector3.new(scale,scale,scale), child)
			end
		end
		exist.Tetine.Transparency = 1
	end
end

--[[
	This function allow to render front of the camera player, the horse model selected in HorsesCollection
	With this method, we have a best render quality as in viewportframe.
]]
local function RenderCreatureModelInWorld(isRender, CreatureType)
	if isRender then
		local exist = RenderCreatureModelFolder:FindFirstChild("CreatureModelCloneForRender")
		if exist then
			RunService:UnbindFromRenderStep("LaunchRotateCreatureModel")
			exist:Destroy()
			connectionModelGeneBegan:Disconnect()
			connectionModelGeneRelease:Disconnect()
			tempGeneModel = {}
			tempTextureModel = {}
		end

		local clone:Model = UIDetailsHorse.ViewportFrame.WorldModel:FindFirstChildWhichIsA("Model"):Clone()
		clone.Parent = RenderCreatureModelFolder
		clone.Name = "CreatureModelCloneForRender"
		clone:ScaleTo(0.6)

		--set idle anim creature
		local animCtrler = Instance.new("AnimationController", clone)
		local animator = Instance.new("Animator", animCtrler)
		local AnimIdle = animator:LoadAnimation(ReplicatedStorage.Assets.Animations[CreatureType].Idle)
		AnimIdle:Play()

		local i = 0
		local function RotateCreature()
			if i == 360 then
				i=0
			end
			
			local _,s = clone:GetBoundingBox()
			clone:PivotTo(CollectionsHouse.SpawnCreature.CFrame * CFrame.new(0,s.Y/(clone:GetScale() < 1 and 4 or 5),0) * CFrame.Angles(0,math.rad(i),0))
			i+=1
		end

		--Rotation for Model horse and render in world
		RunService:BindToRenderStep("LaunchRotateCreatureModel", Enum.RenderPriority.Camera.Value + 1, RotateCreature)

		connectionModelGeneBegan = SeeGenesClickBeganOnModel()
		connectionModelGeneRelease = SeeGenesClickReleaseOnModel()
	else
		local exist = RenderCreatureModelFolder:FindFirstChild("CreatureModelCloneForRender")
		if exist then
			RunService:UnbindFromRenderStep("LaunchRotateCreatureModel")
			exist:Destroy()
			connectionModelGeneBegan:Disconnect()
			connectionModelGeneRelease:Disconnect()
			tempGeneModel = {}
			tempTextureModel = {}
		end
	end
end

--[[
	This Method allow to populate data in UI structure for show horse data
]]
local function PopulateDataUI(frame, dataCreature)
	--Get all item to populate from the fram to populate
	local items = frame:GetChildren()
	--Get available gene collection for player for check corresponding with genes and horse id
	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	local CreatureModel = RenderCreatureModelFolder.CreatureModelCloneForRender --UIDetailsHorse.ViewportFrame.HorseModel

	--update rating visual
	if UIDetailsHorse.Infos1:FindFirstChild("Rating") then
		UIDetailsHorse.Infos1.Rating:SetAttribute("TextHover", dataCreature.Rating)
	end

	for _, item in pairs(items) do
		if item:IsA("Frame") and frame.Name ~= "Genes" then
			if item.Name:match("Color") then
				item.ItemValue.BackgroundColor3 = Color3.new(dataCreature[item.Name].r, dataCreature[item.Name].g, dataCreature[item.Name].b)
			elseif item.Name:match("Talents") then
				local creatureTalent = dataCreature.Talents
				local temp = {}
				print("All Talent:", creatureTalent)
				for _, talentFrame in pairs(item:GetChildren()) do
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
			else
				if dataCreature["Maintenance"][item.Name] then
					item.ItemValue.Text = dataCreature["Maintenance"][item.Name].Value
				elseif typeof(dataCreature[item.Name]) == "table" then
					item.ItemValue.Text = dataCreature[item.Name].Value
					
				else
					item.ItemValue.Text = dataCreature[item.Name]
				end
			end
		elseif item:IsA("Frame") and frame.Name == "Genes" then
			for _, item in pairs(item:GetChildren()) do
				if item:IsA("ImageButton") then
					-- Init default image of slot gene icons
					item.Image = item.Name:match("Tattoo") and GameDataModule.GenesIcons.Tattoo or GameDataModule.GenesIcons[item.Name]
					
					--Check type of gene for display this type and name and if no gene display, juste type of gene emplacement is show
					local geneID = dataCreature[frame.Name][item.Name]
					for i, v in pairs(AvailableGenesCollection) do
						if i == geneID then
							item:SetAttribute("TextHover", v["Type"].." "..v["DisplayName"])
							item.ItemID.Value = geneID
							item.Image = v["ImageID"]
							item.Unequipp.Visible = true

							local founded = false
							for _, child in pairs(CreatureModel:GetChildren()) do
								if child:IsA("BasePart") then
									if string.lower(child.Name):match(string.lower(item.Name)) then
										child.TextureID = v["TextureID"]
										if string.lower(child.Name):match(string.lower("Accessory")) or string.lower(child.Name):match(string.lower("Eye")) then
											child.Transparency = 0.01
										else
											child.Transparency = 0
										end

										local isSurface = false
										--Check if its mesh part if texture gene to apply have a surface appereance or not
										if child:IsA("MeshPart") then
											local exist = RemoteFunction.SearchSurfaceForFusion:InvokeServer(geneID)
											if exist then
												isSurface = true
												--if yes destroy the actuel and replace by another
												local t = child:FindFirstChildOfClass("SurfaceAppearance")
												if t then
													t:Destroy()
												end
												local clone = exist:Clone()
												clone.Parent = child
											else
												isSurface = false
												--if not destroy it
												local t = child:FindFirstChildOfClass("SurfaceAppearance")
												if t then
													t:Destroy()
												end
											end
										end
										RemoteEvent.UpdateVisualGene:FireServer(UIDetailsHorse.CreatureID.Value, {Name=child.Name,Transparency=child.Transparency,TextureID=child.TextureID,GeneID=geneID},isSurface)
										founded = true
									end
								end
							end
							if not founded then
								for _, child in pairs(CreatureModel:GetDescendants()) do
									if child:IsA("Texture") then
										if string.lower(child.Name):match(string.lower(item.Name)) then
											child.Texture = v["TextureID"]
											child.Transparency = 0
											founded = true
											break
										end
									end
								end
							end

							if not founded then
								if string.match(geneID, "Effect") then
									local effects
									-- Same behavior like accessory use for take Particle Effects from shop items
									local clone = ReplicatedStorage.RemoteFunction.CloneAccessoryForPreview:InvokeServer(geneID, false)
									if clone then
										effects = clone:Clone()
										ReplicatedStorage.RemoteFunction.CloneAccessoryForPreview:InvokeServer(geneID, true)
									end

									for _, effect:ParticleEmitter in pairs(effects:GetChildren()) do
										if effect:IsA("ParticleEmitter") then
											effect.Parent = CreatureModel.Socks.EffectFeet
											effect.LockedToPart = true
											effect.Acceleration = Vector3.new(0,1.5,0)
										end
									end
								end
							end
							break
						else
							item:SetAttribute("TextHover", item.Name)
							item.ItemID.Value = ""
							item.Unequipp.Visible = false

							local founded = false
							local DefaultCreatureModel = ReplicatedStorage.Assets.CreaturesModels[dataCreature["CreatureType"].."Character"]
							for _, child in pairs(CreatureModel:GetChildren()) do
								if string.lower(child.Name):match(string.lower(item.Name)) then
									if child:IsA("BasePart") then
										if child:IsA("MeshPart") then
											local t = child:FindFirstChildOfClass("SurfaceAppearance")
											if t then
												t:Destroy()
											end
										end

										--make difference for mane cats not make as horse
										if dataCreature["CreatureType"] == "Cat" and child.Name == "Mane" and dataCreature["Race"] == "Normal" then
											child.Transparency = 1
											child.TextureID = ""
										else
											child.Transparency = DefaultCreatureModel[child.Name].Transparency
											child.TextureID = DefaultCreatureModel[child.Name].TextureID
										end

										RemoteEvent.UpdateVisualGene:FireServer(UIDetailsHorse.CreatureID.Value, {Name=child.Name,Transparency=child.Transparency,TextureID=child.TextureID})
										founded = true
									end
								end
							end
							if not founded then
								for _, child in pairs(CreatureModel:GetDescendants()) do
									if child:IsA("Texture") then
										if string.lower(child.Name):match(string.lower(item.Name)) then
											child.Transparency = DefaultCreatureModel[child.Parent.Name][child.Name].Transparency
											founded = true
											break
										end
									end
								end
							end
							if not founded then
								if string.lower(item.Name):match(string.lower("Effect")) then
									for _, effect in pairs(CreatureModel.Socks.EffectFeet:GetChildren()) do
										if effect:IsA("ParticleEmitter") then
											effect:Destroy()
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

	if dataCreature.Race == "Celestial" then
		CreatureModel["Wing_Left"].Transparency = 0.01
		CreatureModel["Wing_Right"].Transparency = 0.01
		CreatureModel["Wing_Left"].TextureID = dataCreature.Genes["Wing"]
		CreatureModel["Wing_Right"].TextureID = dataCreature.Genes["Wing"]
	else
		CreatureModel["Wing_Left"].Transparency = 1
		CreatureModel["Wing_Right"].Transparency = 1
	end

	--allow to update color and material of horse part horse
	for _, child in pairs(CreatureModel:GetChildren()) do
		--print("SEE TYPE GENE NAME",string.lower(item.Name))
		if string.lower(child.Name):match("mane") then
			local t = dataCreature["ManeColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = dataCreature["PartsMaterial"].Mane
		elseif string.lower(child.Name):match("marking") then
			local t = dataCreature["Color"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = dataCreature["PartsMaterial"].Marking
		elseif string.lower(child.Name):match("tail") then
			local t = dataCreature["TailColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = dataCreature["PartsMaterial"].Tail
		elseif string.lower(child.Name):match("socks") then
			local t = dataCreature["SocksColor"]
			child.Color = Color3.new(t.r, t.g, t.b)
			child.Material = dataCreature["PartsMaterial"].Socks
		end
	end
end

--[[
	This little function allow to create item gene display into list of gene when we click of button type of genes.
	This function is use into PopulateGenesListUI().
]]
local function CreateGeneItemInList(index, item, data, GenesListChoosen)
	local itemGeneList = ItemGeneList:Clone()
	itemGeneList.Visible = true
	itemGeneList.Name = index
	itemGeneList.Parent = GenesListChoosen.List
	itemGeneList:SetAttribute("TextHover", data["DisplayName"])
	itemGeneList.ItemName.Text = data["DisplayName"]
	itemGeneList.Image = data["ImageID"]
	itemGeneList.QuantityText.Text = data.Quantity - data.NbUsed
	itemGeneList.QuantityText.Visible = true

	--And for all gene can equipp, set the remote function server who make give gene to horse
	itemGeneList.Activated:Connect(function()
		local success = RemoteFunction:WaitForChild("GiveGeneToHorse"):InvokeServer(index, UIDetailsHorse.CreatureID.Value, item.Name)

		--if success refreshing ui information directly
		if success then
			--Refresh UI
			local AvailableCreaturesCollection = RemoteFunction:WaitForChild("GetHorsesCollection"):InvokeServer()
			PopulateDataUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes, AvailableCreaturesCollection[UIDetailsHorse.CreatureID.Value])
			PopulateGenesListUI(GenesListChoosen, item)
			ShowCreatureInCollection() --to refresh actual page horse for update properly the visual of little render horse
		end
	end)
end

--[[
	This Method allow to populate genes items and there behavior in list of genes showing by type
	in Genes UI.
]]
function PopulateGenesListUI(GenesListChoosen, item)
	-- Change color of UIStroke of button item selected
	item.UIStroke.Color = Color3.fromRGB(0, 255, 0)
	item.SelectedFrame.Visible = true
	
	-- Make selected visual behavior for button and reset others
	for _, framebutton in pairs(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes:GetChildren()) do
		for _, button in pairs(framebutton:GetChildren()) do
			if button:IsA("ImageButton") then
				if button ~= item then
					button.UIStroke.Color = Color3.fromRGB(0, 108, 240)
					button.SelectedFrame.Visible = false
				end

				-- If one part of animal are invisible and it's a "can equipp" genes slot, we don't show buttons because animal not display actually this part
				if RenderCreatureModelFolder.CreatureModelCloneForRender then
					for _, child in pairs(RenderCreatureModelFolder.CreatureModelCloneForRender:GetChildren()) do
						if child.Name == button.Name then
							if child.Transparency == 1 then
								framebutton.Visible = false
							else
								framebutton.Visible = true
							end
							break
						end
					end
				end
			end
		end
	end
	
	GenesListChoosen.LoadingTxt.Visible = true
	GenesListChoosen.List.Visible = false
	GenesListChoosen.Visible = true
	GenesListChoosen.GeneTypeSelected.Text = item.Name.." Inventory"

	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	ToolsModule.DepopulateTypeOfItemFrom("ImageButton", GenesListChoosen.List)
	
	--For all type of gene make a list of same type gene available to equipp
	for index, data in pairs(AvailableGenesCollection) do
		--Check if type of data corrsponding to the button activated and show only gene are available to equipp
		--Check if gene is a specific texture as Tattoo and show it in all item name contain Tattoo to use it as a emplacment for the texture tattoo
		if (data["Type"] == item.Name or (data["Type"]:match("Tattoo") and item.Name:match("Tattoo"))) and data["Quantity"] - data["NbUsed"] > 0 then

			if data["Type"] == "Eye" then
				--check if type creature correspond with valid species for eye gene only actually
				local Species = GetSpeciesOfItem:InvokeServer(index)
				if Species then
					Species = Species:split(';')
					for _, specie in pairs(Species) do
						if specie == PlayerDataModule.LocalData.CreaturesCollection[UIDetailsHorse.CreatureID.Value].CreatureType then
							CreateGeneItemInList(index, item, data, GenesListChoosen)
						end
					end
				end
			else
				CreateGeneItemInList(index, item, data, GenesListChoosen)
			end
		end
	end

	--populate data finish
	GenesListChoosen.LoadingTxt.Visible = false
	GenesListChoosen.List.Visible = true
end

--[[ 

 ]]
 local function InitGenesButton()
	-- Setup all genes Principal of animal
	local TypeOfGene = GetTypeOfGenes:InvokeServer()
	if TypeOfGene then
		-- We group genes with their specific tattoo slot to make list of genes with tattoo reference UX
		for _, gene in pairs(TypeOfGene) do
			if not gene:match("Tattoo") and not gene:match("Eye") and not gene:match("Effect") and not gene:match("Job") and not gene:match("Wing") then
				local FrameGene:Frame = HorsesCollectionGui.Template.TemplateFrameGene:Clone()
				FrameGene.Parent = UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes
				FrameGene.Name = "List"..gene
				FrameGene.Visible = true

				-- Setup buttons of same type of actual gene (take tatoo to make list of button Mane with ManeTatoo1 and ManeTattoo2 for example)
				for _, g in pairs(TypeOfGene) do
					if g:match(gene) then
						local btn = HorsesCollectionGui.Template.GeneButtonTemplate:Clone()
						btn.Visible = true
						btn.Image = g:match("Tattoo") and GameDataModule.GenesIcons.Tattoo or GameDataModule.GenesIcons[g]
						btn.Name = g
						btn:SetAttribute("TextHover", g)
						btn.Parent = FrameGene
					end
				end
			end
		end

		-- Specific behavior because this gene not have tattoo slot, so we group it in the same frame list of genes
		local FrameGene:Frame = HorsesCollectionGui.Template.TemplateFrameGene:Clone()
		FrameGene.Parent = UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes
		FrameGene.Name = "ListOthers"
		FrameGene.Visible = true

		for _, gene in pairs(TypeOfGene) do
			if gene:match("Eye") or gene:match("Effect") or gene:match("Job") then
				local btn = HorsesCollectionGui.Template.GeneButtonTemplate:Clone()
				btn.Visible = true
				btn.Image = GameDataModule.GenesIcons[gene]
				btn.Name = gene
				btn:SetAttribute("TextHover", gene)
				btn.Parent = FrameGene
			end
		end
	end
 end

--[[
	This method allow to setup behaviour of genes button in details of horse.
	This method attribut on every button activated connection to execute when button is pressed or touched.
	The Behaviour it's to show the list of available type gene horse can equipp when corresponding to the type
	button gene pressed. And if select element of this list, try to equipp gen to the horse if it's possible.
]]
local function SetButtonsGenesBehaviour()
	local GenesListChoosen = UIDetailsHorse.Infos2Frames.GenesUI.GenesListChoosen
	for _, item in pairs(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes:GetChildren()) do
		for _, item in pairs(item:GetChildren()) do
			if item:IsA("ImageButton") then
				--Make behaviour for all button of GenesUI
				item.Activated:Connect(function()
					PopulateGenesListUI(GenesListChoosen, item)
					HorsesCollectionShopModule.PopulateGenesShopListUI(item)
				end)
				
				item.Unequipp.Activated:Connect(function()
					local success = RemoteFunction:WaitForChild("RemoveGeneFromHorse"):InvokeServer(item.ItemID.Value, UIDetailsHorse.CreatureID.Value, item.Name)
	
					--if success refreshing ui information directly
					if success then
						print("UNEQUIPPED GENE's HORSE")
						item.Image = item.Name:match("Tattoo") and GameDataModule.GenesIcons.Tattoo or GameDataModule.GenesIcons[item.Name]
						--Refresh data ui of gene
						local AvailableCreaturesCollection = RemoteFunction:WaitForChild("GetHorsesCollection"):InvokeServer()
						PopulateDataUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes, AvailableCreaturesCollection[UIDetailsHorse.CreatureID.Value])
						PopulateGenesListUI(GenesListChoosen, item)
						ShowCreatureInCollection()--to refresh actual page horse for update properly the visual of little render horse
					end
				end)
			end
		end
	end
end

--[[
	Event send by other Module to need refresh UI Genes of Actual selected animals. 
	Example : If buy new gene Mane in shop into the collection we refresh the Mane list inventory of player Mane to display new bought element in inventory instantly
]]
RemoteEvent.UpdateCollectionsUI.OnClientEvent:Connect(function(index, itemName)
	if itemName then
		for _, item in pairs(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes:GetChildren()) do
			for _, item in pairs(item:GetChildren()) do
				if item:IsA("ImageButton") then
					if itemName == item.Name then
						ReplicatedStorage.RemoteFunction:WaitForChild("GiveGeneToHorse"):InvokeServer(index, UIDetailsHorse.CreatureID.Value, item.Name)

						--Refresh UI
						local AvailableCreaturesCollection = RemoteFunction:WaitForChild("GetHorsesCollection"):InvokeServer()
						PopulateDataUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes, AvailableCreaturesCollection[UIDetailsHorse.CreatureID.Value])
						PopulateGenesListUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesListChoosen, item)
						ShowCreatureInCollection() --to refresh actual page horse for update properly the visual of little render horse
						break
					end
				end
			end
		end
	end
end)

UIDetailsHorse.Infos2Frames.GenesUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if UIDetailsHorse.Infos2Frames.GenesUI.Visible then
		local item = UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes:WaitForChild("ListMarking"):WaitForChild("Marking")
		PopulateGenesListUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesListChoosen, item)
		HorsesCollectionShopModule.PopulateGenesShopListUI(item)
	end
end)

local function SetUIDataOfHorse(index, data)
	UIDetailsHorse.Visible = true
	UIDetailsHorse.Infos2Frames.GenesUI.GenesListChoosen.Visible = false
	UIDetailsHorse.HorseName.Text = data["CreatureName"]
	UIDetailsHorse.CreatureID.Value = index

	ToolsModule.DepopulateTypeOfItemFrom("ImageButton", UIDetailsHorse.Infos1)
	
	CreateItemHoverText("Race", data["Race"])
	CreateItemHoverText("Rating", data["Rating"])
	CreateItemHoverText("Gender", data["Gender"])
	--[[ CreateItemHoverText("Married", data["Married"])
	CreateItemHoverText("InNursery", data["InNursery"])
	CreateItemHoverText("Growth", data["Growth"]) ]]
	
	RenderCreatureModelInWorld(true, data.CreatureType)

	-- Setup UI for Growth option
	if PlayerDataModule.LocalData.CreaturesCollection[index].Growth == "Baby" then
		-- If growth is baby show ui for pay instant growth up creature
		UIDetailsHorse.GrowthInfoFrame.Visible = true
		-- Make a little spawn function to update ui time before growth up creature
		task.spawn(function()
			repeat
				-- Check if player are VIP and apply time /2 if yes
				local TimeGrowthVIP = RemoteFunction.CheckPlayerHasGamepass:InvokeServer(GameDataModule.Gamepasses.VIP.ProductID) and GameDataModule.TimeGrowthHorseGoal/2 or GameDataModule.TimeGrowthHorseGoal
				-- Convert this time in horloge time can show in ui
				local hour,min,sec = ToolsModule.ConvertSecToHour(TimeGrowthVIP - PlayerDataModule.LocalData.CreaturesCollection[index].TimeGrowthValue)
				UIDetailsHorse.GrowthInfoFrame.Frame.GrowthTime.Text = hour.." : "..min.." : "..sec
				task.wait(0.1)
			until UIDetailsHorse.CreatureID.Value ~= index
		end)
	else
		UIDetailsHorse.GrowthInfoFrame.Visible = false
	end

	if not data.InSelling then
		UIDetailsHorse.IconsInfo.AuctionHouseCartImg.Visible = false
		--set ui of button can use by player if horse not in selling
		if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
			UIDetailsHorse.FavouritesBtn.Visible = true
			UIDetailsHorse.ActionsButtons.LockExp.Visible = true
			UIDetailsHorse.ActionsButtons.RenameHorse.Visible = true
			UIDetailsHorse.ActionsButtons.SellHorse.Visible = true
			UIDetailsHorse.ActionsButtons.SellHorse.SellHorseTxt.Text = "Sell Creature"
			UIDetailsHorse.ActionsButtons.SellHorse:SetAttribute("SellMode", true)
			UIDetailsHorse.Infos2.GenesBtn.Visible = true
			UIDetailsHorse.Infos2.AccessoryBtn.Visible = true
			UIDetailsHorse.DeleteBtn.Visible = true
		end
		UIDetailsHorse.InvokeHorse.Visible = true

		if data["InFavourites"] then
			UIDetailsHorse.FavouritesBtn.Image = FavouritesImg
		else
			UIDetailsHorse.FavouritesBtn.Image = UnFavouritesImg
		end
	
		if data["LockExp"] then
			UIDetailsHorse.ActionsButtons.LockExp.Image = GameDataModule.Icons.LockExp
		else
			UIDetailsHorse.ActionsButtons.LockExp.Image = GameDataModule.Icons.UnlockExp
		end

		PopulateDataUI(UIDetailsHorse.Infos2Frames.GenesUI.GenesButtons.Genes, data)
	else
		UIDetailsHorse.IconsInfo.AuctionHouseCartImg.Visible = true
		--set ui of button can't use by player if horse are in selling
		UIDetailsHorse.FavouritesBtn.Visible = false
		UIDetailsHorse.ActionsButtons.LockExp.Visible = false
		UIDetailsHorse.InvokeHorse.Visible = false
		UIDetailsHorse.ActionsButtons.RenameHorse.Visible = false
		UIDetailsHorse.Infos2.GenesBtn.Visible = false
		UIDetailsHorse.Infos2.AccessoryBtn.Visible = false
		UIDetailsHorse.DeleteBtn.Visible = false

		--selling button become get from selling if in selling
		if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
			UIDetailsHorse.ActionsButtons.SellHorse.Visible = true
			UIDetailsHorse.ActionsButtons.SellHorse.SellHorseTxt.Text = "Remove from selling"
			UIDetailsHorse.ActionsButtons.SellHorse:SetAttribute("SellMode", false)
		end
	end
	
	PopulateDataUI(UIDetailsHorse.Infos2Frames.CharacteristicsUI.ScrollingFrame, data)
	PopulateDataUI(UIDetailsHorse.Infos2Frames.EntretienUI.ScrollingFrame, PlayerDataModule.LocalData.CreaturesCollection[index])
end

local function ShowSpecificCreatureUI(creatureID)
	--not show ui horse if player are in some system
	local BreedingGui = UIProviderModule:GetUI("BreedingGui")
	local AuctionHouseGui = UIProviderModule:GetUI("AuctionHouseGui")
	if BreedingGui.Background.Visible or AuctionHouseGui.Background.Visible then
		return
	end

	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	local CreatureData = PlayerDataModule.LocalData.CreaturesCollection[creatureID]
	if CreatureData then
		local exist = UIDetailsHorse.ViewportFrame.WorldModel:FindFirstChildWhichIsA("Model")
		if exist then
			exist:Destroy()
		end

		local c = ToolsModule.MakeCreatureModelForRender(CreatureData, AvailableGenesCollection)
		c.Parent = UIDetailsHorse.ViewportFrame.WorldModel

		UIBackground.Visible = true
		SetUIDataOfHorse(creatureID, CreatureData)
	end
end

--[[
	Main Method for send and prepare all populate UI of Horses List and Horse Detail.
]]
function PopulateDataCreaturesCollection(filters)
	--Get available creature in collection whith remote function
	local AvailableCreaturesCollection, MaxElements = RemoteFunction:WaitForChild("GetHorsesCollection"):InvokeServer(CreaturesCollectionNbValuePage, CreaturesCollectionIndexPage, filters)
	local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()
	
	-- Get data to make visual slots UI
	local slotsAvailables, nbMaxSlotsAvailables, nbCreatures = RemoteFunction.CheckCreaturesCollectionSlotsAreAvailables:InvokeServer(false)
	local nbSlotAvailables = (nbMaxSlotsAvailables-nbCreatures)

	-- If we are on Competition map, behavior for Creatue collection are little bit different and not need to show slots
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") or ToolsModule.LengthOfDic(filters) > 0 then
		slotsAvailables = false
	else
		MaxElements += nbSlotAvailables + 1
	end

	-- Check number of slot you can make in this page
	local nbSlotToMake = math.abs(CreaturesCollectionNbElementByPage - ToolsModule.LengthOfDic(AvailableCreaturesCollection))
	local lastPage = false
	if CreaturesCollectionNbValuePage > nbMaxSlotsAvailables then
		nbSlotToMake -= math.abs(CreaturesCollectionNbValuePage - nbMaxSlotsAvailables)
	end

	--check max element to determine the number of pages to show it in UI
	local around = MaxElements%CreaturesCollectionNbElementByPage == 0 and 0 or 0.5
	CreaturesCollectionPageMaxInfo = math.round(MaxElements/CreaturesCollectionNbElementByPage + around)
	UIBackground.PagesCollections.PageValue.Text = CreaturesCollectionPageInfo.."/"..CreaturesCollectionPageMaxInfo

	--check max element receive to show or not de right page button ui
	if CreaturesCollectionNbValuePage >= MaxElements then
		UIBackground.PagesCollections.MaxRightBtn.Visible = false
		UIBackground.PagesCollections.RightBtn.Visible = false
	else
		UIBackground.PagesCollections.RightBtn.Visible = true
		UIBackground.PagesCollections.MaxRightBtn.Visible = true
	end

	
	--Destroy content after repopulate for refresh ui data
	ToolsModule.DepopulateTypeOfItemFrom("Frame", ScrollingFrame)
	
	--Set list with all horses collection
	for index, data in pairs(AvailableCreaturesCollection) do
		--Make sure to not find horse already create in liste ui
		if not ScrollingFrame:FindFirstChild(index) then
			--Make horse item for list based on template ui
			local cloneItem = HorsesCollectionGui.Template.ItemViewportTemplate:Clone()
			cloneItem.Visible = true
			cloneItem.Name = data["CreatureName"]
			cloneItem.Parent = ScrollingFrame
			cloneItem.LayoutOrder = -data["TimeObtained"]

			cloneItem.ItemName.Text = data["CreatureName"]
			
			--check icons horse preview
			cloneItem.IconsInfo.LockExpImg.Visible = data["LockExp"]
			if not data.InSelling then
				cloneItem.IconsInfo.AuctionHouseCartImg.Visible = false
			else
				cloneItem.IconsInfo.AuctionHouseCartImg.Visible = true
			end
			
			--Update color stroke with rarity of creature (allow to see in list rarity by color of creature)
			cloneItem.Rarity.Image = GameDataModule.RarityIconsBorderless[data.Rating]
			--cloneItem.ItemImgBtn.UIStroke.Color = ToolsModule.RarityColor[data.Rating]

			local ViewportFrame = cloneItem.ViewportFrame
			ViewportFrame.Name = index

			local CreatureModel = ToolsModule.MakeCreatureModelForRender(data, AvailableGenesCollection, ViewportFrame)

			--Populate UI Horse data when button clicked for horse linked to this connect
			cloneItem.ItemImgBtn.Activated:Connect(function()
				--for have only one HorseModel ref just clone horse model use for preview horse into emplacmenet where 3D model get the model to show
				--so we have now just one model create here for preview and if player click to see 3D model, we clone it (not create another model)
				--destroy the previous model if exist
				local exist = UIDetailsHorse.ViewportFrame.WorldModel:FindFirstChildWhichIsA("Model")
				if exist then
					exist:Destroy()
				end

				local c = CreatureModel:Clone()
				c.Parent = UIDetailsHorse.ViewportFrame.WorldModel
				
				SetUIDataOfHorse(index, data)
			end)
		end
	end

	-- If slots are availables, setup the visual free slots with other creatures collection and number of slot we can show in list calculate before
	if slotsAvailables then
		for i=1, nbSlotToMake do
			--Make horse item for list based on template ui
			local cloneItem = HorsesCollectionGui.Template.ItemViewportTemplate:Clone()
			cloneItem.Visible = true
			cloneItem.Name = "FreeSlot"
			cloneItem.Parent = ScrollingFrame
			cloneItem.LayoutOrder = 0
			cloneItem.ItemImgBtn.ImageTransparency = 0
			--cloneItem.ItemImgBtn.Image = ""

			cloneItem.ItemName.Text = "Free Slot"
			cloneItem.ItemImgBtn.UIStroke.Color = Color3.fromRGB(255,255,255)
		end
	end

	-- Check if is last page for show item adding slot
	if #ScrollingFrame:GetChildren()-2 < CreaturesCollectionNbElementByPage then
		lastPage = true
	end

	-- If last we create abutton to add slots in collection
	if lastPage and game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") and ToolsModule.LengthOfDic(filters) < 1 then
		--Make horse item for list based on template ui
		local cloneItem = HorsesCollectionGui.Template.ItemViewportTemplate:Clone()
		cloneItem.Visible = true
		cloneItem.Name = "AddingSlots"
		cloneItem.Parent = ScrollingFrame
		cloneItem.LayoutOrder = 0
		cloneItem.ItemImgBtn.ImageTransparency = 0
		--cloneItem.ItemImgBtn.Image = ""

		cloneItem.ItemName.Text = "+"
		cloneItem.ItemImgBtn.UIStroke.Color = Color3.fromRGB(0,255,0)
		cloneItem.ItemImgBtn.Activated:Connect(function()
			game:GetService("MarketplaceService"):PromptProductPurchase(game.Players.LocalPlayer, 1519228137)
		end)
	end
end

--########## PAGES BUTTONS UI ##########
UIBackground.PagesCollections.RightBtn.Activated:Connect(function()
	CreaturesCollectionPageInfo += 1
	UIBackground.PagesCollections.PageValue.Text = CreaturesCollectionPageInfo.."/"..CreaturesCollectionPageMaxInfo

	CreaturesCollectionIndexPage += CreaturesCollectionNbElementByPage
	CreaturesCollectionNbValuePage += CreaturesCollectionNbElementByPage
	print("index", CreaturesCollectionIndexPage, "nbvalue", CreaturesCollectionNbValuePage)
	ShowCreatureInCollection()
	UIBackground.PagesCollections.LeftBtn.Visible = true
	UIBackground.PagesCollections.MaxLeftBtn.Visible = true
end)

UIBackground.PagesCollections.MaxRightBtn.Activated:Connect(function()
	UIBackground.PagesCollections.RightBtn.Visible = false
	UIBackground.PagesCollections.MaxRightBtn.Visible = false

	CreaturesCollectionPageInfo = CreaturesCollectionPageMaxInfo
	UIBackground.PagesCollections.PageValue.Text = CreaturesCollectionPageInfo.."/"..CreaturesCollectionPageMaxInfo

	CreaturesCollectionIndexPage = (CreaturesCollectionPageMaxInfo*CreaturesCollectionNbElementByPage) - (CreaturesCollectionNbElementByPage-1)
	CreaturesCollectionNbValuePage = CreaturesCollectionPageMaxInfo*CreaturesCollectionNbElementByPage

	print("index", CreaturesCollectionIndexPage, "nbvalue", CreaturesCollectionNbValuePage)
	ShowCreatureInCollection()

	UIBackground.PagesCollections.LeftBtn.Visible = true
	UIBackground.PagesCollections.MaxLeftBtn.Visible = true
end)

UIBackground.PagesCollections.LeftBtn.Activated:Connect(function()
	if CreaturesCollectionNbValuePage - CreaturesCollectionNbElementByPage <= 1 then
		UIBackground.PagesCollections.LeftBtn.Visible = false
		UIBackground.PagesCollections.MaxLeftBtn.Visible = false
		return
	else
		CreaturesCollectionPageInfo -= 1
		UIBackground.PagesCollections.PageValue.Text = CreaturesCollectionPageInfo.."/"..CreaturesCollectionPageMaxInfo
	
		CreaturesCollectionIndexPage -= CreaturesCollectionNbElementByPage
		CreaturesCollectionNbValuePage -= CreaturesCollectionNbElementByPage
		--print("index", CreaturesCollectionIndexPage, "nbvalue", CreaturesCollectionNbValuePage)
		ShowCreatureInCollection()

		if CreaturesCollectionNbValuePage - CreaturesCollectionNbElementByPage <= 1 then
			UIBackground.PagesCollections.LeftBtn.Visible = false
			UIBackground.PagesCollections.MaxLeftBtn.Visible = false
		end
	end

	if CreaturesCollectionPageInfo >= CreaturesCollectionPageMaxInfo then
		UIBackground.PagesCollections.MaxRightBtn.Visible = false
		UIBackground.PagesCollections.RightBtn.Visible = false
	else
		UIBackground.PagesCollections.RightBtn.Visible = true
		UIBackground.PagesCollections.MaxRightBtn.Visible = true
	end
end)

function MaxLeftBtn()
	UIBackground.PagesCollections.LeftBtn.Visible = false
	UIBackground.PagesCollections.MaxLeftBtn.Visible = false

	CreaturesCollectionPageInfo = 1
	UIBackground.PagesCollections.PageValue.Text = CreaturesCollectionPageInfo.."/"..CreaturesCollectionPageMaxInfo

	CreaturesCollectionIndexPage = 1
	CreaturesCollectionNbValuePage = CreaturesCollectionNbElementByPage
	
	print("index", CreaturesCollectionIndexPage, "nbvalue", CreaturesCollectionNbValuePage)
	ShowCreatureInCollection()

	if CreaturesCollectionPageInfo >= CreaturesCollectionPageMaxInfo then
		UIBackground.PagesCollections.MaxRightBtn.Visible = false
		UIBackground.PagesCollections.RightBtn.Visible = false
	else
		UIBackground.PagesCollections.RightBtn.Visible = true
		UIBackground.PagesCollections.MaxRightBtn.Visible = true
	end
end
UIBackground.PagesCollections.MaxLeftBtn.Activated:Connect(MaxLeftBtn)

--only for competition parade, change page to the first page when ui is close
if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
	UIBackground:GetPropertyChangedSignal("Visible"):Connect(function()
		if not UIBackground.Visible then
			MaxLeftBtn()
		end
	end)
end

--########################################

local function ActiveFilters()
	FilterManager.InitUIFilter("Horses",CreaturesCollectionFilters,false)
	for index, childs in pairs(UIFilterBackground:GetChildren()) do
		if childs.Name:match("DropDown") then
			for _, child in pairs(childs:GetChildren()) do
				if child:IsA("ImageButton") then
					child.Activated:Connect(function()
						task.wait()
						MaxLeftBtn()
					end)
				end
			end
		end
	end
end

local function BackButton()
	ShowCreatureInCollection()
	RenderCreatureModelInWorld(false)

	UIDetailsHorse.Visible = false
	UIDetailsHorse.Infos2Frames.CharacteristicsUI.Visible = false
	UIDetailsHorse.Infos2Frames.EntretienUI.Visible = false
	UIDetailsHorse.Infos2Frames.GenesUI.Visible = false
	UIDetailsHorse.Infos2Frames.AccessoryUI.Visible = false
	
	ScrollingFrame.Visible = true
end

--### RENAME UI PART ###
FilterMessageEvent.OnClientEvent:Connect(function(message, sender, from)
	if sender.UserId == game.Players.LocalPlayer.UserId then
		if from == script.Name then
			UIDetailsHorse.HorseName.Text = message
			local result = RemoteFunction.RenameHorse:InvokeServer(UIDetailsHorse.CreatureID.Value, message)
			print("RENAME HORSE", result)
			if result then
				UIBackground.Visible = true
				RenameFrame.Visible = false
				ShowCreatureInCollection()
				ScrollingFrame.Visible = true
			end
		end
	end
end)

RenameFrame.Valid.Activated:Connect(function()
	local HorseNameInput = RenameFrame.HorseNameInput
	local renameIsOk = false

	if HorseNameInput.Text ~= UIDetailsHorse.HorseName.Text then
		if HorseNameInput.Text == "" then
			RenameFrame.Info.Text = "Name can't null !"
		elseif string.len(HorseNameInput.Text) < 3 then
			RenameFrame.Info.Text = "Name min cara is 3 !"
		else
			renameIsOk = true
		end

		if renameIsOk then
			FilterMessageEvent:FireServer(HorseNameInput.Text, script.Name)
		end
	else
		RenameFrame.Info.Text = "Rename and Name are the same..."
	end
end)

RenameFrame.RandomName.Activated:Connect(function()
	RenameFrame.HorseNameInput.Text = ToolsModule.GenerateRandomName()
end)

RenameFrame.Cancel.Activated:Connect(function()
	ScrollingFrame.Visible = true
	RenameFrame.HorseNameInput.Text = UIDetailsHorse.HorseName.Text
	UIBackground.Visible = true
	RenameFrame.Visible = false
end)

UIDetailsHorse.ActionsButtons.RenameHorse.Activated:Connect(function()
	ScrollingFrame.Visible = false
	RenameFrame.HorseNameInput.Text = UIDetailsHorse.HorseName.Text
	RenameFrame.Visible = true
	UIBackground.Visible = false
end)
--######################

--####### SELL UI PART #######
local function CalculeSaleTaxes(price)
	return math.round((price * 0.15) + 0.5)
end

local function MakeInputNumberOnly(input)
	local CurrentText = input.Text
	CurrentText = CurrentText:gsub("[^%w%s_]+", "")
	CurrentText = CurrentText:gsub("%a", "")
	input.Text = CurrentText
	if CurrentText ~= "" then
		SellFrame.TaxeValue.Text = ToolsModule.DotNumber(CalculeSaleTaxes(CurrentText))
	end
end

SellFrame.HorseSellValueInput:GetPropertyChangedSignal('Text'):Connect(function()
	MakeInputNumberOnly(SellFrame.HorseSellValueInput)
end)

UIDetailsHorse.ActionsButtons.SellHorse.Activated:Connect(function()
	if UIDetailsHorse.ActionsButtons.SellHorse:GetAttribute("SellMode") then
		ScrollingFrame.Visible = false
		SellFrame.Visible = true
		UIBackground.Visible = false
	else
		RemoteFunction.AuctionHouse.BuyHorse:InvokeServer(UIDetailsHorse.CreatureID.Value, true, HorsesCollectionGui)
		SetUIDataOfHorse(UIDetailsHorse.CreatureID.Value, PlayerDataModule.LocalData.CreaturesCollection[UIDetailsHorse.CreatureID.Value])
	end
end)

SellFrame.Cancel.Activated:Connect(function()
	ScrollingFrame.Visible = true
	UIBackground.Visible = true
	SellFrame.Visible = false
	SellFrame.HorseSellValueInput.Text = ""
end)

SellFrame.Valid.Activated:Connect(function()
	local SellValue = SellFrame.HorseSellValueInput.Text
	if SellValue ~= "" and SellValue ~= "0" then
		local result = RemoteFunction.AuctionHouse.SellHorse:InvokeServer(UIDetailsHorse.CreatureID.Value, tonumber(SellValue), CalculeSaleTaxes(tonumber(SellValue)))
		if result then
			--we destroy horse invoked by player who correspond to the selling horse
			RemoteFunction.InvokHorsePlayer:InvokeServer(UIDetailsHorse.CreatureID.Value, true)
		end
		UIBackground.Visible = true
		SellFrame.Visible = false
		SellFrame.HorseSellValueInput.Text = ""
		BackButton()
		ScrollingFrame.Visible = true
	end
end)

--############################

--[[
	Event to catch when button clicked or touched
]]
ShowUiBtn.Activated:Connect(function()
	UIBackground.Visible = not UIBackground.Visible
	if UIBackground.Visible then
		ToolsModule.EnableOtherUI(false, {"HorsesCollectionGui", "FilterGui"})
	else
		ToolsModule.EnableOtherUI(true, {"HorsesCollectionGui"})
	end
end)

UIDetailsHorse.FavouritesBtn.Activated:Connect(function()
	local result = RemoteFunction:WaitForChild("SetHorseFavourites"):InvokeServer(UIDetailsHorse.CreatureID.Value)
	if result == true then
		UIDetailsHorse.FavouritesBtn.Image = FavouritesImg
	elseif result == false then
		UIDetailsHorse.FavouritesBtn.Image = UnFavouritesImg
	end
end)

--[[
	Behavior of button to buy in Robux instant growth creature. Client call remote function InstantGrowthTime server with Id of animal to instant growth.
]]
UIDetailsHorse.GrowthInfoFrame.Frame.BuyInstantGrowth.Activated:Connect(function()
	-- Check if detail animal are a ID setup
	if UIDetailsHorse.CreatureID.Value ~= "" then
		-- Active button to allow server check can buy
		UIDetailsHorse.GrowthInfoFrame.Frame.BuyInstantGrowth.Active = false
		-- Call function server to listen if player buy or not instant growth
		local result = RemoteFunction.InstantGrowthTime:InvokeServer(UIDetailsHorse.CreatureID.Value)
		if result then
			UIDetailsHorse.GrowthInfoFrame.Visible = false
			GrowthModelBabyToAdult()
		end
		UIDetailsHorse.GrowthInfoFrame.Frame.BuyInstantGrowth.Active = true
	end
end)

-- Set Behvavior button refresh collection loaded UI viewport for Accessory
UIDetailsHorse.Infos2Frames.AccessoryUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if not UIDetailsHorse.Infos2Frames.AccessoryUI.Visible then
		ShowCreatureInCollection()
	end
end)

UIBackground:GetPropertyChangedSignal("Visible"):Connect(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not UIBackground.Visible)
	if UIBackground.Visible then
		if SellFrame.Visible or RenameFrame.Visible or PopupDeleteVisible then
			ToolsModule.EnableOtherUI(true, {"HorsesCollectionGui"})
		end
		CameraEnabled = CameraController.GetEnabled()
		CameraController.SetEnabled(false)
		PlayerInfoGui.Enabled = false
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CollectionsHouse.Camera.CFrame

		-- Create a function on render step to continue setup the focus where is the player when enter in collection to avoid bad loading rendering voxel terrain when camera return to player position when leave collection
		RunService:BindToRenderStep("CameraCollectionFocus", Enum.RenderPriority.Camera.Value, function()
			camera.Focus = game.Players.LocalPlayer.Character.PrimaryPart.CFrame
		end)

		ShowCreatureInCollection()
		UIFilterBackground.Position = UDim2.fromScale(0.04, 0.375)
		ActiveFilters()

		ToolsModule.EnableOtherUI(false, {"HorsesCollectionGui", "FilterGui"})
		ShowUiBtn.Visible = false
		WalkSpeedModule.SetControlsPlayerAndCreature(false)

		-- If player have one creature summoned, we show directly this creature in Collections UI when open it
		local exist = workspace.CreaturesFolder:FindFirstChild("Creature_"..game.Players.LocalPlayer.Name)
		if exist then
			ShowSpecificCreatureUI(exist.CreatureID.Value)
		end
	else
		FilterManager.CleanFilters()
		if SellFrame.Visible or RenameFrame.Visible or PopupDeleteVisible then
			ToolsModule.EnableOtherUI(false, {"HorsesCollectionGui"})
			return
		end

		-- Remove from render step the camera focus
		RunService:UnbindFromRenderStep("CameraCollectionFocus")

		RenderCreatureModelInWorld(false)
		InitInterfaceVisibility()
		UIFilterBackground.Position = UDim2.fromScale(0.5,0.1)
		ToolsModule.EnableOtherUI(true, {"HorsesCollectionGui"})
		ShowUiBtn.Visible = true
		WalkSpeedModule.SetControlsPlayerAndCreature(true)

		PlayerInfoGui.Enabled = true
		if CameraEnabled then
			CameraController.SetEnabled(true)
		else
			local camera = workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end)

--Init Starting
InitInterfaceVisibility()
InitGenesButton()
SetButtonsGenesBehaviour()

--[[
	This event allow to show in Creatures Collection the model of creature selected and show interface data linked to this creature.
]]
RemoteEvent.ShowHorseUI.OnClientEvent:Connect(ShowSpecificCreatureUI)

UIDetailsHorse.InvokeHorse.Activated:Connect(function()
	local player = game.Players.LocalPlayer
	local currentMaterial = player.Character:GetAttribute("EnvironmentMaterial")
	if currentMaterial then
		if string.lower(currentMaterial) == "water" then
			warn("Can't invoke horse in water !")
			return
		end
		if string.lower(currentMaterial) == "crackedlava" then
			warn("Can't invoke horse in CrackedLava !")
			return
		end
	end

	local result = RemoteFunction:WaitForChild("InvokHorsePlayer"):InvokeServer(UIDetailsHorse.CreatureID.Value)
	if result then
		InitInterfaceVisibility()
	end
end)

--[[
	Allow client to lock or unlock exp horse giver. If not lock horse can win exp if lock horse can't win xp
]]
UIDetailsHorse.ActionsButtons.LockExp.Activated:Connect(function()
	local result = RemoteFunction.CreatureLockEXP:InvokeServer(UIDetailsHorse.CreatureID.Value)
	if result == "error" then
		return
	end

	if result then
		UIDetailsHorse.ActionsButtons.LockExp.Image = GameDataModule.Icons.LockExp
	else
		UIDetailsHorse.ActionsButtons.LockExp.Image = GameDataModule.Icons.UnlockExp
	end

	ShowCreatureInCollection()
end)

--[[
	Behavior of delete button to ask server for delete creature actually selected
]]
UIDetailsHorse.DeleteBtn.Activated:Connect(function()
	PopupDeleteVisible = true
	ScrollingFrame.Visible = false
	UIBackground.Visible = false
	RemoteFunction.DeleteCreature:InvokeServer(UIDetailsHorse.CreatureID.Value, UIDetailsHorse.HorseName.Text)
end)

--[[
	Event listener when server confirm delete creature, make update of UI
]]
RemoteFunction.DeleteCreature.OnClientInvoke = function(isSuccess)
	if isSuccess then
		-- Reset UI of collection
		InitInterfaceVisibility()
		InitGenesButton()
		SetButtonsGenesBehaviour()
		
		-- Remove 3D render model of deleted creature
		RenderCreatureModelInWorld(false)
	end

	-- Enable UI
	UIBackground.Visible = true
	ScrollingFrame.Visible = true
	PopupDeleteVisible = false
end

--###### SEPCIAL FUNCTION TEST TO SHOW CREATURE LIST ONLY FOR FUSION SYSTEM ##########
--this is allow to populate with model viewport list of breeding system
CreaturesListForBreeding.Populate.Changed:Connect(function()
	if CreaturesListForBreeding.Populate.Value then
		--Get available horses in collection whith remote function
		local AvailableCreaturesCollection = PlayerDataModule.LocalData.CreaturesCollection
		local AvailableGenesCollection = RemoteFunction:WaitForChild("GetGenesCollection"):InvokeServer()

		-- Remove isDELETE creature from collection
		for index, data in pairs(AvailableCreaturesCollection) do
			if data["isDELETE"] then
				AvailableCreaturesCollection[index] = nil
			end
		end
	
		if AvailableCreaturesCollection == {} then
			return
		end
	
		--Destroy content after repopulate for refresh ui data
		ToolsModule.DepopulateTypeOfItemFrom("Frame", CreaturesListForBreeding)
		
		--Set list with all creature collection
		for index, data in pairs(AvailableCreaturesCollection) do
			--Make sure to not find creature already create in liste ui
			if not CreaturesListForBreeding:FindFirstChild(index) then
				--Make creature item for list based on template ui
				local cloneItem = HorsesCollectionGui.Template.ItemViewportTemplate:Clone()
				cloneItem.Name = data["CreatureName"]
				cloneItem.Parent = CreaturesListForBreeding
				cloneItem.LayoutOrder = -data["TimeObtained"]
				cloneItem.ItemName.Text = data["CreatureName"]
				cloneItem.Rating.Image = GameDataModule.RarityIconsBorderless[data.Rating]
	
				local creatureType = Instance.new("StringValue", cloneItem)
				creatureType.Name = "CreatureType"
				creatureType.Value = data["CreatureType"]
				local creatureGender = Instance.new("StringValue", cloneItem)
				creatureGender.Name = "CreatureGender"
				creatureGender.Value = data["Gender"]
				local creatureGrowth = Instance.new("StringValue", cloneItem)
				creatureGrowth.Name = "CreatureGrowth"
				creatureGrowth.Value = data["Growth"]
	
				local ViewportFrame = cloneItem.ViewportFrame
				ViewportFrame.Name = index

	
				ToolsModule.MakeCreatureModelForRender(data, AvailableGenesCollection, ViewportFrame)
			end
		end
	end
end)

--##################### TEST HIDE/SHOW GENES SYSTEM FOR CREATURES COLLECTION ############################
--[[
	This function is call for return a connection to a click or touch began for player into breeding system to detect when player click or touch a model
	to hide all genes of model target.
]]
function SeeGenesClickBeganOnModel()
	local connection = UserInputService.InputBegan:Connect(function(key,IsTyping)
		if not IsTyping then
			if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
				if Mouse.Target then
					local model = Mouse.Target:FindFirstAncestorWhichIsA("Model")
					if model then
						local parent = model:FindFirstAncestor(RenderCreatureModelFolder.Name)
						if parent then -- here we check the value of gobal show gene to dodge a conflict visibility of gene
							modelGeneClickBegan = model
							for _, child in pairs(model:GetChildren()) do
								if child:IsA("MeshPart") then
									if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
										tempGeneModel[child.Name] = child.TextureID
										child.TextureID = ""
										for _, v in pairs(child:GetChildren()) do
											if v:IsA("Texture") then
												tempTextureModel[v.Name] = v.Texture
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
function SeeGenesClickReleaseOnModel()
	local connection = UserInputService.InputEnded:Connect(function(key,IsTyping)
		if not IsTyping then
			if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
				if modelGeneClickBegan then
					if modelGeneClickBegan:FindFirstAncestor(RenderCreatureModelFolder.Name) then
						for _, child in pairs(modelGeneClickBegan:GetChildren()) do
							if child:IsA("MeshPart") then
								if not string.lower(child.Name):match(string.lower("Eye")) and not string.lower(child.Name):match(string.lower("Wing")) and not string.lower(child.Name):match(string.lower("Nose")) then
									child.TextureID = tempGeneModel[child.Name]
									for _, v in pairs(child:GetChildren()) do
										if v:IsA("Texture") then
											v.Texture = tempTextureModel[v.Name]
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