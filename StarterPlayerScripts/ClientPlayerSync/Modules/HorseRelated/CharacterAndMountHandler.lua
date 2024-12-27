-- Stratiz 9/22/2021
local CharacterHandler = {
	Character = nil,
	Mount = nil
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local BoneTracker = require("BoneTracker")
local HorseAnimator = require("HorseAnimator")
local UtilFunctions = require("UtilFunctions")
local InteractionUISystem = require("InteractionUISystem")
local HorseInteractionModule = require("HorseInteractionModule")
local ToolsModule = require("ToolsModule")
local UIProviderModule = require("UIProviderModule")
local CameraController = require(game:GetService("StarterPlayer").StarterPlayerScripts.ClientPlayerSync.Modules:WaitForChild("CameraController"))
local WalkSpeedModule = require("WalkSpeedModule")
local EnvironmentModule = require("EnvironmentModule")

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction

local HeadReplicationEvent = HorseEvents:WaitForChild("HeadReplicationEvent")
print("LOADED HEADREPLICATIONEVENT: ", HeadReplicationEvent)
local HorseEvent = ReplicatedStorage.SharedSync.HorseEvents:WaitForChild("HorseEvent")
local HorseMountFunction = ReplicatedStorage.SharedSync.HorseEvents:WaitForChild("HorseMountFunction")

local RE_HorseDeloaded = ReplicatedStorage.SharedSync.HorseEvents:WaitForChild("HorseDeloaded")
local RE_UpdateSparks = ReplicatedStorage.SharedSync.RemoteEvent:WaitForChild("UpdateSparks")
local CheckHorseOwnerIsPlayerID = ReplicatedStorage.SharedSync.RemoteFunction:WaitForChild("CheckHorseOwnerIsPlayerID")

local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")
local CharacterFolder = workspace:WaitForChild("CharacterFolder")

local Controllers = {
	Creature = require("HorseController"),
	Human = require("HumanController")
}

local isDisplayed = false
local ProximityDetectionConnection
local UiClosedInProximity = false

local CreatureDataCache = {}

local HumanHumanoid = nil


local function LinkCharacter(Character)
	for _,Controller in pairs(Controllers) do
		Controller:Disable()
	end
	
	if CharacterHandler.Mount then
		Character.PrimaryPart.CFrame = CharacterHandler.Mount.Instance.PrimaryPart.CFrame * CFrame.new(Vector3.new(-3,0,0))
	end

	CharacterHandler.Mount = nil
	CharacterHandler.Character = nil

	if ProximityDetectionConnection then
		ProximityDetectionConnection:Disconnect()
	end

	local Humanoid = Character:WaitForChild("Humanoid",3)
	HumanHumanoid = Humanoid
	HumanHumanoid:ChangeState(Enum.HumanoidStateType.Running)
	local RootPart = Character:WaitForChild("HumanoidRootPart",3)
	if not Humanoid or not RootPart then
		warn("Character will not bind.")
		return
	end

	-- This event connexion is make to replace last touch event for proximity detection player
	ProximityDetectionConnection = RunService.Heartbeat:Connect(function(deltaTime)
		local creature = game.Workspace.CreaturesFolder:FindFirstChild("Creature_"..LocalPlayer.Name)
		if creature then
			--check if we can interact with creature before to setup Close Menu (it's check about competition parade to avoid conflict camera setup)
			if creature:GetAttribute("CanInteractWith") then
				if (creature.PrimaryPart.Position - RootPart.Position).Magnitude < 10 then
					if not UiClosedInProximity then
						CharacterHandler:DisplayInteractionPannel(creature)
					end
				else
					UiClosedInProximity = false
					InteractionUISystem:CloseMenu()
				end
			end
		end
	end)

	Humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,false)
	--Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
	Humanoid.Sit = false
	--Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	CharacterHandler.Character = Controllers.Human:Enable(Character)
	Humanoid.Died:Connect(function()
		for _,Controller in pairs(Controllers) do
			Controller:Disable()
		end
		CharacterHandler.Character = {}
	end)
end

local function ClientHorseMount(Creature)
	if Creature then
		CharacterHandler.Mount = Controllers.Creature:Enable(Creature)
		
		local exist = Creature.RootPart:FindFirstChild("body_general")
		if exist then
			BoneTracker:TrackBones(exist)
		end

		if ProximityDetectionConnection then
			ProximityDetectionConnection:Disconnect()
			InteractionUISystem:CloseMenu()
		end
		
		local Rider = CharacterHandler.Mount.Instance.Seat:WaitForChild("Rider")
		if Rider then
			CharacterHandler.Mount.Connections.RiderChanged = Rider.Changed:Connect(function()
				if Rider.Parent == nil or Rider.Value ~= LocalPlayer then
					print("Dismounted")

					-- Disable camera animal and focus player
					CameraController.SetEnabled(false)
					local camera = workspace.CurrentCamera
					camera.CameraType = Enum.CameraType.Custom

					CharacterHandler.Mount.Instance.CanShowStatus.Value = true
					ToolsModule.EnableOtherUI(true, {"CreatureInteractionGui"})
					LinkCharacter(LocalPlayer.Character)
					--when player dismount we remove owner network of player
					HorseEvents.SetNetworkOwner:FireServer(Creature.ID, false)
				end
			end)

			CharacterHandler.Mount.Connections.Unseated = HumanHumanoid:GetPropertyChangedSignal("Sit"):Connect(function()
				if HumanHumanoid.Sit == false then
					HumanHumanoid.Sit = true
				end
			end)

			if Rider.Value then
				--if here so we mount creature so send to server it's this player take network owner of creature
				--HorseEvents.SetNetworkOwner:FireServer(Creature.ID, true)

				--Send info player mount creature to update current player animation on horse
				CharacterHandler.Mount.Instance.CanShowStatus.Value = false
				HorseEvents.CreatureChangeStyle:FireServer("Mount")
			end
		end
	end
end

--[[
	This function allow to send good event client and server to make a functionnal mount player on creature.
	Remote Function HorseMountFunction call in HorseLoader function creatureMount who setup in server side the different behavior for mount creature.
	Function ClientHorseMount setup behavior on client side to mount creature.
]]
local function ActionMountCreature(Creature, CreatureIsMounted)
	isDisplayed = false
	local Data = HorseMountFunction:InvokeServer("Mount", not CreatureIsMounted and Creature:GetAttribute("ID") or nil)
	if Data then
		ClientHorseMount(Data)
	end
end

--[[
	This function allow to create the ui grid of genes of creature give in parameter otherCreatureData. This UI are put into
	the InteractionUI to show it on the BillboardGui when player click on InteractionTable Gene button.
	Function setup button of gene with image corresponding to the geneID image to show good texture of gene and behavior of button
	is to redirect player click on it into the shop UI at the good item to buy it instant.
]]
local function MakeGeneInteractionPanel(otherCreatureData)
	--We get the creature collection to take the same genes ui of Details Creature and init it for the InteractionUI
	local CreaturesCollectionGui = UIProviderModule:GetUI("HorsesCollectionGui")
	local genesUI = CreaturesCollectionGui.Background.DetailsHorse.Infos2Frames.GenesUI:Clone()
	ToolsModule.DepopulateTypeOfItemFrom("ImageButton",genesUI.Genes)
	
	--Get the InteractionUI and wait it when player have clicked on see genes button and setup clone genesUI into InteractionUI
	local p = LocalPlayer.PlayerGui:WaitForChild("InteractionUI")
	genesUI.Parent = p.Main

	--send main into Screengui to better behavior with UI world
	local CreatureInteractionGui = UIProviderModule:GetUI("CreatureInteractionGui")
	--make adjustement UI of Main Frame before transfer into ScreenGui
	p.Main.Size = UDim2.fromScale(0.2,1)
	p.Main.Position = UDim2.fromScale(0.15,0.75)
	p.Main.Parent = CreatureInteractionGui

	--We get all type of gene to construct properly the UI with all genes emplacement to show what genes have creature
	local TypeOfGene = RemoteFunction.GetTypeOfGenes:InvokeServer()
	if TypeOfGene then
		for _, gene in pairs(TypeOfGene) do
			local btn = CreaturesCollectionGui.Template.GeneButtonTemplate:Clone()
			btn.Visible = true
			btn.Name = gene
			btn:SetAttribute("TextHover", gene)
			btn.Parent = genesUI.Genes

			--with geneID we get the image texture corresponding to nice show
			local geneID = otherCreatureData.Genes[gene]
			if geneID ~= "" then
				btn.Image = RemoteFunction.GetImageOfGeneID:InvokeServer(geneID)

				--setup behavior of button gene when player click on it, we redirect player into ShopUI at the good gene to buy it and close InteractionUI
				btn.Activated:Connect(function()
					RemoteEvent.ShowShopUIForItem:FireServer(geneID)
					p:Destroy()
					isDisplayed = false
				end)
			end
		end
	end

	--here we make ajustement GUI appearence to match properly into InteractionUI
	genesUI.GenesListChoosen:Destroy()
	genesUI.Size = UDim2.fromScale(1,0.5)
	genesUI.Genes.Size = UDim2.fromScale(0.97, 0.85)
	genesUI.Genes.UIGridLayout.CellSize = UDim2.fromScale(0.18,0.2)
	genesUI.Visible = true

	
end

--[[
	This function can display UI Interaction pannel for creature selected. It's work if player and on or not on creature.
	The parameter otherCreatureData :
		if this parameter are not nil, this means that the DisplayInteractionPanel has been made on another creature and
		this parameter contains the creature's data in order to set up the right interface with this data.
]]
function CharacterHandler:DisplayInteractionPannel(Creature, index, otherCreatureData)
	--check if creature not nil and if ui are not already display
	if isDisplayed or not Creature then
		return
	end

	--if place are competition, manage UI are specific so don't make this
	if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
		--if interaction ui is not enable this means some other UI are open, so we don't interrupt other ui and wait
		--other UI are close for trigger signal to enable all UI and so this is enable CreatureInteractionGui and show maintenance to player
		if not UIProviderModule:GetUI("CreatureInteractionGui").Enabled then
			repeat
				task.wait(0.1)
			until UIProviderModule:GetUI("CreatureInteractionGui").Enabled
		end
	end

	isDisplayed = true
	local InteractionTable = {}

	--if it's competition parade place
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		if not otherCreatureData then
			--make the good interaction table for creature OF player only and not for other creature
			InteractionTable = {
				Mount = { func = function(ui,mount)
					ActionMountCreature(Creature, mount)
				end}
			}
		end
	else
		--check type of interaction table we setup, if otherCreatureData exist it's not the player creature so just make show genes interaction
		if otherCreatureData then
			InteractionTable = {
				Genes = { func = function()
					--Make one button to show genes of creature
					MakeGeneInteractionPanel(otherCreatureData)
				end},
			}
		else
			--make the good interaction table for creature OF player only and not for other creature
			InteractionTable = {
				Mount = { func = function(ui,mount)
					ActionMountCreature(Creature, mount)
				end},
				ShowUI = { func = function()
					isDisplayed = false
					RemoteEvent.ShowHorseUI:FireServer(Creature.CreatureID.Value)
				end},
			}

			if Creature:FindFirstChild("CreatureID") and Creature.CreatureID.Value ~= "" then
				InteractionTable.Actions = {
					--[[ Happyness = {
						barName = "Happyness";
						isInteractible = false;
						index = 2;
						folderIndex = 2;
						func = function()
							HorseInteractionModule.Actions.Happyness(Creature)
						end
					}, ]]
					
					Fed = {
						barName = "Fed";
						isInteractible = true;
						index = 3;
						folderIndex = 3;
						func = function(uiInstance, isFull)
							HorseInteractionModule.Actions.Fed(Creature, isFull)
						end
					},

					--[[ Cleanness = {
						barName = "Cleanness";
						isInteractible = false;
						index = 4;
						folderIndex = 2;
						func = function()
							HorseInteractionModule.Actions.Cleanness(Creature)
						end
					}, ]]

					Scrape = {
						barName = "Scrape";
						isInteractible = true;
						index = 5;
						folderIndex = 3;
						func =function()
							HorseInteractionModule.Actions.Scrape(Creature)
						end
					},

					Brushed = {
						barName = "Brushed";
						isInteractible = true;
						index = 6;
						folderIndex = 3;
						func = function()
							HorseInteractionModule.Actions.Brushed(Creature)
						end
					},

					--[[ Mount = {
						index = 7;
						func = function(ui,mount)
							ActionMountCreature(Creature, mount)
						end
					}, ]]
				}
			end

			if not Creature.PrimaryPart:GetAttribute("SizeEffectActive") and CharacterHandler.Mount then
				InteractionTable.PowerSize = { func = function()
					isDisplayed = false
					if not Creature.PrimaryPart:GetAttribute("SizeEffectActive") then
						local result = RemoteFunction.DecrementValueOf:InvokeServer("Feez", 1000)
						if result then
							HorseEvents.CreatureResizeEvent:FireServer(4, 60)
						else
							RemoteEvent.ShowPopupAlert:FireServer(
								"Enought Feez !",
								"You don't have enough Feez ! \n You can collect them in the world or buy them in the store.",
								ToolsModule.AlertPriority.Annoucement,
								nil,
								ToolsModule.AlertTypeButton.OK
							)

							UIProviderModule:GetUI("PurchaseStoreGui").FeezBackground.Visible = true
						end
					end
				end}
			end
		end
	end

	local InteractionObject = InteractionUISystem:Show(Creature.PrimaryPart,InteractionTable, index, otherCreatureData)
	InteractionObject.OnInteractionEnded = function(Reason)
		if Reason == "Return" then
			isDisplayed = true
			--check if player are mouted or not to setup the good camera
			CameraController.SetEnabled(CharacterHandler.Mount and true or false)
			InteractionObject = InteractionUISystem:Show(Creature.PrimaryPart, InteractionTable, nil, otherCreatureData)
			InteractionObject.OnInteractionEnded = function()
				isDisplayed = false
			end
		else
			UiClosedInProximity = true
			isDisplayed = false
		end
	end
end

function CharacterHandler:Init()
	LocalPlayer.CharacterAdded:Connect(LinkCharacter)
	if LocalPlayer.Character then
		LinkCharacter(LocalPlayer.Character)
	end
	print("Starting updater")

	for _,Data in pairs(HorseMountFunction:InvokeServer("GetHorses")) do
		print("found a Creature")
		CreatureDataCache[Data.Instance.CreatureID.Value] = Data
	end

	HorseEvent.OnClientEvent:Connect(function(Reason,Data)
		if Reason == "Add" then
			--InteractionUISystem:InitQuickShowMaintenanceStatus()
			print("New Creature!")
			CreatureDataCache[Data.Instance.CreatureID.Value] = Data
		elseif Reason == "Remove" then
			--[[local TargetIndex
			for Index,CachedData in ipairs(HorseDataCache) do
				if CachedData.Instance == Data.Instance then
					
				end 
			end]]
		elseif Reason == "Health" then
			if CharacterHandler.Mount then
				if Data <= 0 then
					CharacterHandler.Mount.Actions.Walk:SetStyle("Walk")
					WalkSpeedModule.ApplySlowerMalus(CharacterHandler.Mount.Instance, true)
				else
					CharacterHandler.Mount.Actions.Walk:SetStyle("Gallop")
					WalkSpeedModule.ApplySlowerMalus(CharacterHandler.Mount.Instance, false)
				end
			end
		end
	end)
end

RE_HorseDeloaded.OnClientEvent:Connect(function()
	isDisplayed = false
end)

--This event allow other to activate the showing of InteractionPanel. Can come from characterMountHandler when player click on creature.
RemoteEvent.OpenCreatureMenu.OnClientEvent:Connect(function(Creature, index, otherCreatureData)
	if Creature then
		CharacterHandler:DisplayInteractionPannel(Creature, index, otherCreatureData)
	end
end)

--Event call by server to auto mount creature with the good behavior
ReplicatedStorage.SharedSync.HorseEvents.ActionMount.OnClientEvent:Connect(ActionMountCreature)

return CharacterHandler
