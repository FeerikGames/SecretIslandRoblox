local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local RunService = game:GetService("RunService")
local playerService = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")

local CharacterHandler = require("CharacterAndMountHandler")
local HorseController = require("HorseController")
local UIAnimationModule = require("UIAnimationModule")
local PlayerDataModule = require("ReplicatedPlayerData")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService:UserInputService = game:GetService("UserInputService")
local WalkSpeedModule = require("WalkSpeedModule")
local EnvironmentModule = require("EnvironmentModule")

local Assets = ReplicatedStorage.SharedSync.Assets

local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents
local remoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local remoteFunction = ReplicatedStorage.SharedSync.RemoteFunction

local RE_UpdateSparks = remoteEvent.UpdateSparks
local RE_SyncClientSparks = remoteEvent.SyncClientSparks
local RE_ChangeSmokeMaterial = remoteEvent.ChangeSmokeMaterial
local RE_GroundMaterialChange = remoteEvent.GroundMaterialChange
local RE_ExitedHorse = remoteEvent.ExitedHorse
local RE_LightStateChange = remoteEvent.LightStateChange
local RE_SoccerBallHandler = remoteEvent.SoccerBallHandler
local RE_HorseSpeedEffectActivation = remoteEvent.HorseSpeedEffectActivation


local RF_HorseEffectActivation = remoteFunction.HorseEffectActivation
local RF_SetNetworkOwnerOfPart = remoteFunction.SetNetworkOwnerOfPart
local RF_GetLastSafePointCFrame = remoteFunction.GetLastSafePointCFrame
local RF_ApplyMultiPush = remoteFunction.ApplyMultiPush

local player = playerService.LocalPlayer
local pushedFolder = workspace.InteractibleScenery
local currentSparks = PlayerDataModule.LocalData.Sparks
local MultiPushUiModel = Assets.MultiPushUI

local PlayerGui = player:WaitForChild("PlayerGui")
local jumpPressTimeToFly = script:GetAttribute("jumpPressTimeToFly")

local frontTouchedConnection = nil
local backTouchedConnection = nil
local frontTouchEndedConnection = nil
local backTouchEndedConnection = nil

local isSparkFirstFrameChange = true
local isVelocityFirstFrameUp = true
local isSparkZEroFirstFrame = true
local mountingFirstFrame = true
local exitFirstFrame = false
local lastHorseExited = nil
local lastMaterial = nil
local materialFirst = true
local materialDebounce = true
local lightDebounce = true
local lastLightState = nil
local slipStreaming = false

local sparksUseRatio = 0.5
local sparksEffectModifier = 1

local smoke = Assets.Effects.Smoke;
local grass = Assets.Effects.Grass;

local backward = false
local foreWard = false

local pushStrong = 20

local saveSafePointDebounce = false
local saveSafePointDebounceTimeInSec = 2
local safePoints = {}
local homePoint = Vector3.new(0,30,0)

local currentMaterial = Enum.Material.Grass

local objectPushed = {}
local objectsBlocking = {}

local currentfly = false

local isJumpKeyboardPressed = false
local isJumpTouchPressed = false
local jumpPressTime = 0
local Creature = nil
local mobileJumpBinded = false
local jumpForFlyTiming = false

--------------------------------------------------------------------------------------------------------------------------------

local function setEffectsActive(isActive, rate)
	if RF_HorseEffectActivation:InvokeServer(CharacterHandler.Mount.Instance, isActive, rate, currentSparks) >= 1 then
		sparksEffectModifier = 1
	else
		sparksEffectModifier = 0
	end
end

local function jumpMobileButtonDown()
	isJumpTouchPressed = true
end

local function jumpMobileButtonUp()
	isJumpTouchPressed = false
end

UserInputService.InputBegan:Connect(function(InputObject,GP) -- no lol
	if not CharacterHandler.Character or not CharacterHandler.Mount then
		return
	end
	
	 if InputObject.KeyCode == Enum.KeyCode.LeftShift then
		print("Walk")
		CharacterHandler.Mount.Actions.Walk:SetStyle("Walk")
		task.wait(0.1)
		setEffectsActive(true, math.round(math.pow(CharacterHandler.Mount.PrimaryPart.Velocity.Magnitude/16, 6)))
	elseif InputObject.KeyCode == Enum.KeyCode.X then
		if currentfly == false then 
			CharacterHandler.Mount.Actions.Flight:SetStyle("Helicopter")
		else
			CharacterHandler.Mount.Actions.Flight:SetStyle("Glider")
		end
		currentfly = not currentfly
	elseif InputObject.KeyCode == Enum.KeyCode.H then
		CharacterHandler.Mount.Actions.Walk:SetEnabled(false)
		CharacterHandler.Mount.Actions.Flight:SetEnabled(false)
		CharacterHandler.Mount.Actions.Swim:SetEnabled(true)
		CharacterHandler.Mount.Actions.Swim:SetStyle("Swim")
	elseif InputObject.KeyCode == Enum.KeyCode.E then
		WalkSpeedModule.ApplyBlockedMalus(CharacterHandler.Mount.Instance, 1)
		HorseEvents.HorseMountFunction:InvokeServer("Mount")
		materialFirst = true
	elseif InputObject.KeyCode == Enum.KeyCode.W then
		foreWard = true
	elseif InputObject.KeyCode == Enum.KeyCode.S then
		backward = true
	end
end)

UserInputService.InputEnded:Connect(function(InputObject,GP)
	if InputObject.KeyCode == Enum.KeyCode.LeftShift then
		if CharacterHandler.Character then
			if CharacterHandler.Mount and not WalkSpeedModule.CheckIfSlowerMalusIsApply() then
				CharacterHandler.Mount.Actions.Walk:SetStyle("Gallop")
				task.wait(0.1)
				setEffectsActive(true, math.round(math.pow(CharacterHandler.Mount.PrimaryPart.Velocity.Magnitude/16, 6)))
			end
		end
	elseif InputObject.KeyCode == Enum.KeyCode.W then
		foreWard = false
	elseif InputObject.KeyCode == Enum.KeyCode.S then
		backward = false
	end
end)

local function HappynessLowInfluence(Creature)
	if Creature:FindFirstChild("EffectHead") then
		print("Happyness Low Influence")
		local effects = Assets.InteractionAssets.Angry:GetChildren()
		local instanciedEffects = {}
		for _, effect in pairs(effects) do
			instanciedEffects[_] = effect:Clone()
			instanciedEffects[_].Parent = Creature.EffectHead
			instanciedEffects[_].Enabled = true
			task.delay(1, function()
				instanciedEffects[_].Enabled = false
				task.delay(3, function()
					instanciedEffects[_]:Destroy()
				end)
			end)
		end
	end
end

--[[
	Allow to client check periodly status maintenance of horse and ask server to get with the corresponding horse ID, directly data horse.
	Not get all horses data but just get horse with ID know here to check directly data, more speed nad less lag.
]]
local function PeriodlyCheckMaintenanceStatus()
	while task.wait() do
		local Creature = workspace.CreaturesFolder:FindFirstChild("Creature_"..player.Name)
		if not Creature then
			continue
		end

		local CreatureID = Creature:WaitForChild("CreatureID")
		--see event remote function into HorseDataModule allow to get directly data of horse and convert into dictionnary for here get correct value
		local CreatureData = PlayerDataModule.LocalData.CreaturesCollection[CreatureID.Value]
		if not CreatureData then
			task.wait(4)
			continue
		end
		task.wait(4)
		local horseMaintenance = CreatureData.Maintenance
		if horseMaintenance.Happyness.Value <= 30 or CreatureData.Stamina.Value <= 4 then
			HappynessLowInfluence(Creature)
		end
	end
end

local function BlockHorse(isBlocked, ObjectBlocking , entryForward, entryBackward)
	if isBlocked then
		local exist = table.find(objectsBlocking, ObjectBlocking)
		if exist then
			WalkSpeedModule.ApplyBlockedMalus(CharacterHandler.Mount.Instance, 1)
			objectsBlocking[exist] = nil
			return
		end
		CharacterHandler.Mount.PrimaryPart.Velocity = Vector3.new(0,0,0)
		local index = #objectsBlocking+1
		objectsBlocking[index] = ObjectBlocking
		while objectsBlocking[index] do
			local temp
			if not CharacterHandler.Mount then
				temp = 1
				return
			end 
			local directionVector = ObjectBlocking.Position - player.Character.PrimaryPart.Position
			local faceDirection = CharacterHandler.Mount.PrimaryPart.CFrame.LookVector
			local cross = directionVector:Cross(faceDirection)
			cross *= Vector3.new(0,1,0)
			temp = cross.Magnitude / 35
			if temp < 0.4 then
				temp = 0
			end
			if entryBackward and foreWard or entryForward and backward then
				temp = 1
			end
			WalkSpeedModule.ApplyBlockedMalus(CharacterHandler.Mount.Instance, temp)
			task.wait()
			if PlayerDataModule.LocalData.CreaturesCollection[CharacterHandler.Mount.Instance.CreatureID.Value].Race == "Ground" then
				local playersNeeded = ObjectBlocking:GetAttribute("playersNeeded")
				local currentPlayer = ObjectBlocking:GetAttribute("currentPlayers")
				if currentPlayer >= playersNeeded then
					BlockHorse(false, ObjectBlocking , entryForward, entryBackward)
				end
			end
		end
	else
		local exist = table.find(objectsBlocking, ObjectBlocking)
		if exist then
			WalkSpeedModule.ApplyBlockedMalus(CharacterHandler.Mount.Instance, 1)
			objectsBlocking[exist] = nil
		end
	end
end

local function GroundHorsePush(isPushing, objectToPush)
	if isPushing then
		if objectToPush:GetAttribute("GoToDestroy") then
			return
		end
		local exist = table.find(objectPushed, objectToPush)
		if exist then
			return
		end

		local index = #objectPushed+1
		objectPushed[index] = objectToPush
		if not objectToPush:GetAttribute("Local") then
			RF_SetNetworkOwnerOfPart:InvokeServer(objectToPush, player)
		end

		if CharacterHandler.Mount.Instance.CollisionFront:FindFirstChild("Hit") then
			CharacterHandler.Mount.Instance.CollisionFront.Hit:Destroy()
		end
		local hit = objectToPush.Hit:Clone()
		hit.Parent = CharacterHandler.Mount.Instance.CollisionFront

		local timePassed = os.time()
		while objectPushed[index] do
			-- If player push rock we calculate the time passed to push it, if it's okay we destroy and play rewarding of rock
			if os.time() - timePassed >= 2 or (not objectToPush:GetAttribute("playersNeeded") and CharacterHandler.Mount.Instance.PrimaryPart:GetAttribute("SizeEffectActive") or false) then
				local exist = table.find(objectPushed, objectToPush)
				if exist then
					hit:Destroy()
					objectPushed[exist] = nil
					objectToPush:SetAttribute("GoToDestroy", true)
					remoteEvent.RockExplode:FireServer(objectToPush)
					CharacterHandler.Mount.Actions.Walk:SetStyle("Gallop")
					break
				end
			else
				hit.Enabled = true
			end

			local directionVector = objectToPush.Position - player.Character.PrimaryPart.Position
			local AxesRestriction = objectToPush:GetAttribute("AxesRestriction")
			if AxesRestriction == nil then
				AxesRestriction = 1
			end
			objectToPush.Velocity = Vector3.new(directionVector.X, 0, directionVector.Z).Unit * AxesRestriction * pushStrong
			CharacterHandler.Mount.Actions.Walk:SetStyle("Walk")
			local playersNeeded = objectToPush:GetAttribute("playersNeeded")
			local currentPlayer = objectToPush:GetAttribute("currentPlayers")
			if playersNeeded then
				if currentPlayer < playersNeeded then
					GroundHorsePush(false, objectToPush)
				end
			end
			
			task.wait(0.05)
		end
	else
		local exist = table.find(objectPushed, objectToPush)
		if exist then
			if CharacterHandler.Mount.Instance.CollisionFront:FindFirstChild("Hit") then
				CharacterHandler.Mount.Instance.CollisionFront.Hit:Destroy()
			end
			CharacterHandler.Mount.Actions.Walk:SetStyle("Gallop")
			objectPushed[exist] = nil
		end
	end
end
local function ActivatePushUI(partTouched)
	local multiPushUI = MultiPushUiModel:Clone()
	multiPushUI.Parent = partTouched
	multiPushUI.Enabled = true
end

local function DeletePushUI(partTouched)
	local multiPushUI = partTouched:FindFirstChild("MultiPushUI")
	multiPushUI:Destroy()
end


local function UpdatePushUi()
	for _, object in pairs(pushedFolder:GetDescendants()) do
		local pushUi = object:FindFirstChild("MultiPushUI")
		if not pushUi then
			continue
		end
		local playerNeeded = object:GetAttribute("playersNeeded")
		local currentPlayer = object:GetAttribute("currentPlayers")
		pushUi.Main.ProgressBar.Info.Text = currentPlayer .. " / " .. playerNeeded
		pushUi.Main.ProgressBar.Clipping.Size = UDim2.fromScale(currentPlayer / playerNeeded, 1)
	end
end

RF_ApplyMultiPush.OnClientInvoke = function()
	UpdatePushUi()
end

local function ApplyAndCalculateMultiPush(partTouched, added)
	local playersNeeded = partTouched:GetAttribute("playersNeeded")
	if playersNeeded == nil then
		return true
	end
	local currentPlayer = partTouched:GetAttribute("currentPlayers")
	currentPlayer += added
	if added > 0 then
		ActivatePushUI(partTouched)
	else
		DeletePushUI(partTouched)
	end
	partTouched:SetAttribute("currentPlayers", currentPlayer)
	RF_ApplyMultiPush:InvokeServer(partTouched, added)
	if currentPlayer >= playersNeeded then
		return true
	else
		return false
	end
end

local LastKick = tick()
local function ApplyHorseCollisionEffect(partTouched, hasTouched, isFront)
	-- Detect when touching a boulder and apply force to them
	if partTouched:FindFirstAncestor("InteractibleScenery") and CharacterHandler.Mount then
		if partTouched.Name == "Ball" then
			if tick() - LastKick < 0.5 then
				return
			end
		
			LastKick = tick()
			RE_SoccerBallHandler:FireServer()
			--print("KICKING THE SOCCER BALL")
		elseif PlayerDataModule.LocalData.CreaturesCollection[CharacterHandler.Mount.Instance.CreatureID.Value].Race == "Ground" then
			if not hasTouched then
				GroundHorsePush(hasTouched, partTouched)
			end
			local added
			if hasTouched then
				added = 1
			else
				added = -1
			end
			local canPush = ApplyAndCalculateMultiPush(partTouched, added)
			if canPush then
				GroundHorsePush(hasTouched, partTouched)
			else
				BlockHorse(hasTouched, partTouched, isFront, not isFront)
			end
		else
			BlockHorse(hasTouched, partTouched, isFront, not isFront)
		end
	end
end

local function CheckApplySlipStream(partTouched)
	if partTouched.Name ~= "Slipstream" then
		return
	end

	slipStreaming = true
	local slipStreamVelocity = partTouched.AssemblyLinearVelocity
	local currentVelocity = player.Character.PrimaryPart.AssemblyLinearVelocity

	if --[[ slipStreamVelocity.Magnitude <= 0.5 or ]] currentVelocity.Magnitude <= 0.5 then
		return
	end

	if CharacterHandler.Mount then
		RE_HorseSpeedEffectActivation:FireServer(CharacterHandler.Mount.Instance, true)
		WalkSpeedModule.AddSlipStreamBonus(CharacterHandler.Mount.Instance)
	end
end

local function CheckDeleteSlipStream(partTouched)
	if partTouched.Name ~= "Slipstream" then
		return
	end

	slipStreaming = false

	while not slipStreaming and CharacterHandler.Mount do
		local result = WalkSpeedModule.RemoveSlipStreamBonus(CharacterHandler.Mount.Instance)
		if result <= 0 then
			RE_HorseSpeedEffectActivation:FireServer(CharacterHandler.Mount.Instance, false)
			return
		end
		task.wait(0.05)
	end
end

local function DisconnectFrontBackCollisionDetection()
	if frontTouchedConnection then
		frontTouchedConnection:Disconnect()
		frontTouchedConnection = nil
	end

	if frontTouchEndedConnection then
		frontTouchEndedConnection:Disconnect()
		frontTouchEndedConnection = nil
	end

	if backTouchedConnection then
		backTouchedConnection:Disconnect()
		backTouchedConnection = nil
	end

	if backTouchEndedConnection then
		backTouchEndedConnection:Disconnect()
		backTouchEndedConnection = nil
	end
end

function SetupDetection(exited)
	-- Don't setup detection touch behavior of Animals if Place are the Fashion Show
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		return
	end
	-- SETUP ON TOUCH DETECTION
	if exited then
		DisconnectFrontBackCollisionDetection()
		return
	end

	local touch = true
	local touchended = false
	local front = true
	local notFront = false

	if CharacterHandler.Mount then
		-- Front collision Connection
		frontTouchedConnection = CharacterHandler.Mount.Instance.CollisionFront.Touched:Connect(function(partTouched)
			CheckApplySlipStream(partTouched)
			ApplyHorseCollisionEffect(partTouched, touch, front)
		end)
		frontTouchEndedConnection = CharacterHandler.Mount.Instance.CollisionFront.TouchEnded:Connect(function(partTouched)
			CheckDeleteSlipStream(partTouched)
			ApplyHorseCollisionEffect(partTouched, touchended, front)
		end)
	
		-- Back collision Connection
		backTouchedConnection = CharacterHandler.Mount.Instance.CollisionBack.Touched:Connect(function(partTouched)
			ApplyHorseCollisionEffect(partTouched, touch, notFront)
		end)
		backTouchEndedConnection = CharacterHandler.Mount.Instance.CollisionBack.TouchEnded:Connect(function(partTouched)
			ApplyHorseCollisionEffect(partTouched, touchended, notFront)
		end)
	end
end

--[[
	This function allow to detect with Region3 and ReadVoxel, if player are immersed in water or not
	and change the variable CurrentMaterial if are under Water at += 50% of surface used for calculation
	This soltion is make because we can't use FloorMaterial for this behavior.
]]
function SetupPlayerWaterDetection()
	while true do
		if player.Character then
			local primaryPart = player.Character.PrimaryPart
			if primaryPart then
				local min = primaryPart.Position - (.1 * primaryPart.Size)
				local max = primaryPart.Position + (.1 * primaryPart.Size)
				local region = Region3.new(min,max):ExpandToGrid(4)

				--create part region see debug
				--[[ local exist = workspace:FindFirstChild("RegionTest")
				if exist then
					exist:Destroy()
				end
				local p = Instance.new("Part")
				p.Name = "RegionTest"
				p.Anchored = true
				p.Size = region.Size
				p.CFrame = region.CFrame
				p.Parent = game.Workspace
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Transparency = 0.3 ]]

				local material, occupancy = game.Workspace.Terrain:ReadVoxels(region, 4)
				if occupancy[1][1][1] >= 0.5 then
					if material[1][1][1] == Enum.Material.Water then
						--print("test under water")
						currentMaterial = Enum.Material.Water
					else
						--print("test not under water")
						currentMaterial = Enum.Material.Grass
					end
				else
					if material[1][1][1] == Enum.Material.Air then
						--print("test not under water")
						currentMaterial = Enum.Material.Grass
					end
				end
			end
		end
		
		task.wait(.1)
	end
end

--[[
	29/08/22 Same as GetSagePoint, removed raycast part because we dont need it to take a safepoint from cframe player.
]]
local function SaveSafePointCFrame(cFrame)
	--[[ local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist

	if CharacterHandler.Mount then
		overlapParams.FilterDescendantsInstances = {player.Character,CharacterHandler.Mount.Instance, workspace.Terrain}
	else
		overlapParams.FilterDescendantsInstances = {player.Character,workspace.Terrain}
	end

	local closeParts =  workspace:GetPartBoundsInRadius(cFrame.Position, 10, overlapParams)

	if #closeParts > 0 then
		print("TEST SAVE PARTS", closeParts)
		return
	end ]]

	if #safePoints >= 1 then
		safePoints[2] = safePoints[1]
		safePoints[1] = cFrame
	else
		safePoints[#safePoints+1] = cFrame
	end
end

--[[
	29/08/22 Commented all raycast check because normally we don't need this and make the system safe point goodless because
	we return if player have a part around him. If cframe player are save it's ok so donn't need to check this and juste return
	the last safepoint save in table.
]]
local function GetSafePointCFrame()
	--[[ local testedCFrame = safePoints[index]

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist

	if CharacterHandler.Mount then
		overlapParams.FilterDescendantsInstances = {player.Character,CharacterHandler.Mount.Instance, workspace.Terrain}
	else
		overlapParams.FilterDescendantsInstances = {player.Character,workspace.Terrain}
	end

	local closeParts =  workspace:GetPartBoundsInRadius(testedCFrame.Position, 10, overlapParams)
	if #closeParts > 0 then
		if safePoint[index+1] then
			return GetSafePointCFrameIndex(index+1)
		else
			return nil
		end
	end ]]

	return safePoints[1]
end

--[[
	This method are modify to check light of creature, not with Raycast, but with settings Lighting. We check if ambience local are dark and if condition is okay,
	send to server turn on or off light of creature if power is Light
]]
local function CheckLightState(Creature)

	--if creature are given it's we know already creature so don't check if found Mount
	if not Creature then
		if not CharacterHandler.Mount then
			return
		end
	end

	--check if we switch on or off light of creature depending settings light
	local lightState = false
	if game.Lighting.Brightness <= 1 and game.Lighting.Ambient == Color3.new(0,0,0) then
		lightState = true
	end

	if lightState == lastLightState then
		return
	end

	lastLightState = lightState
	RE_LightStateChange:FireServer(lightState)
end

--[[
	This function is call during a RenderStepped for check material floor behind player.
	First we check if player are mounted or not and after we check if we can save actual cframe player if he touch the ground and not is a cracked lava material.
	We send to server with event the material floor touched by player to make behavior need (if player or player on creature)
]]
local function CheckTerrainMaterialChange()
	if not materialDebounce then
		return
	end

	materialDebounce = false
	task.delay(0.2, function()
		materialDebounce = true
	end)

	--check if operation are for player character or creature mouted player model
	local testPart = CharacterHandler.Mount or player.Character

	if typeof(testPart) == "table" and not testPart.Humanoid or typeof(testPart) ~= "table" and not testPart:FindFirstChild("Humanoid") then
		return
	end

	--check if condition are ok to save last cframe position of player
	if not saveSafePointDebounce and not player:GetAttribute("InDamageArea") and testPart.Humanoid.FloorMaterial ~= Enum.Material.Water and testPart.Humanoid.FloorMaterial ~= Enum.Material.CrackedLava and testPart.Humanoid.FloorMaterial ~= Enum.Material.Air and currentMaterial ~= Enum.Material.Water then
		saveSafePointDebounce = true
		task.delay(saveSafePointDebounceTimeInSec, function()
			saveSafePointDebounce = false
		end)
		SaveSafePointCFrame(testPart.PrimaryPart.CFrame)
	end

	--send to server with event the actual floor material touched to let server make actions or not
	if currentMaterial == Enum.Material.Water then
		RE_GroundMaterialChange:FireServer(currentMaterial, CharacterHandler.Mount and true or false)
	else
		-- If player touch ground type CrackedLava make damage and show ui feedback fire
		if testPart.Humanoid.FloorMaterial == Enum.Material.CrackedLava then
			local isMount = CharacterHandler.Mount and true or false
			RE_GroundMaterialChange:FireServer(Enum.Material.CrackedLava, isMount)
			currentMaterial = Enum.Material.CrackedLava
			UIAnimationModule.OnFireFeedbackUI(true, isMount and PlayerDataModule.LocalData.CreaturesCollection[CharacterHandler.Mount.ID].Race == "Fire" or false)
		else
			-- Change ground touched by player only if leave Damage Area
			if not player:GetAttribute("InDamageArea") then
				RE_GroundMaterialChange:FireServer(Enum.Material.Grass, CharacterHandler.Mount and true or false)
				currentMaterial = Enum.Material.Grass
				UIAnimationModule.OnFireFeedbackUI(false, false)
			end
		end

		if CharacterHandler.Mount then
			RE_ChangeSmokeMaterial:FireServer(CharacterHandler.Mount.Instance.Socks.EffectFeet.Smoke, CharacterHandler.Mount.Humanoid.FloorMaterial)
		end
	end
end

CheckTerrainMaterialChange()

local function processFlyMode(deltaTime:number)
	if Creature then
		local CreatureRace = PlayerDataModule.LocalData.CreaturesCollection[Creature.ID].Race
		
		if UserInputService:IsKeyDown(Enum.KeyCode.Space)  then
			isJumpKeyboardPressed = true
		else
			isJumpKeyboardPressed = false
		end

		if  CreatureRace and CreatureRace == "Celestial"  then
				
			if not mobileJumpBinded and  PlayerGui:FindFirstChild("TouchGui") and PlayerGui.TouchGui.TouchControlFrame:FindFirstChild("JumpButton") then
				local jumpButton = PlayerGui.TouchGui.TouchControlFrame.JumpButton

				jumpButton.MouseButton1Down:Connect(jumpMobileButtonDown)
				jumpButton.MouseButton1Up:Connect(jumpMobileButtonUp)
				mobileJumpBinded = true
			end
			 
			
			if not jumpForFlyTiming and (isJumpKeyboardPressed or isJumpTouchPressed) then
				jumpPressTime = 0
				jumpForFlyTiming = true
			elseif jumpForFlyTiming and not (isJumpKeyboardPressed or isJumpTouchPressed) then
				jumpForFlyTiming = false
			elseif jumpForFlyTiming then
				jumpPressTime += deltaTime
			else
				jumpPressTime = 0
			end
				
			if jumpPressTime >= jumpPressTimeToFly and not CharacterHandler.Mount.Actions.Flight.IsEnabled() then
				CharacterHandler.Mount.Actions.Walk:SetEnabled(false)
				CharacterHandler.Mount.Actions.Swim:SetEnabled(false)
				CharacterHandler.Mount.Actions.Flight:SetEnabled(true)
			end
		end
	end
end
	

local function updateSparks(deltaTime)
	if not CharacterHandler.Mount or currentSparks == nil then
		return
	end
	local SparkEffectRateValue = math.round(math.pow(CharacterHandler.Mount.PrimaryPart.Velocity.Magnitude/16, 6))
	local velocityValue = math.round(CharacterHandler.Mount.PrimaryPart.Velocity.Magnitude) * deltaTime
	
	if velocityValue > 0 then
		currentSparks -= sparksUseRatio * sparksEffectModifier * deltaTime
		currentSparks = currentSparks<=0 and 0 or currentSparks
		if isVelocityFirstFrameUp then
			RE_UpdateSparks:FireServer(true)
			isVelocityFirstFrameUp = false
			isSparkFirstFrameChange = true
			setEffectsActive(true, SparkEffectRateValue)
		end
	else
		if isSparkFirstFrameChange then
			RE_UpdateSparks:FireServer(false)
			isVelocityFirstFrameUp = true
			isSparkFirstFrameChange = false
			setEffectsActive(false, 0)
		end
	end
	if currentSparks > 0 then
		isSparkZEroFirstFrame = true
	end
	if currentSparks <= 0 and isSparkZEroFirstFrame then
		currentSparks = 0
		isSparkZEroFirstFrame = false
		setEffectsActive(false, SparkEffectRateValue)
	end
end

local function ExitSpeedHorse(Horse)
	local CollisionParts = CollectionService:GetTagged("PropCollision")
	for _,Part in pairs(CollisionParts) do
		if Part:IsA("BasePart") then
			Part.CanCollide = true
		end
	end
	
	WalkSpeedModule.SetSpeedToPegasus(Horse, true)

	for _,Part in pairs(Horse:GetDescendants()) do
		if Part:IsA("BasePart") or Part:IsA("Texture") or Part:IsA("Decal") then
			Part.LocalTransparencyModifier = 0
		end
	end
end

local function InitSpeedHorse(Creature)
	if PlayerDataModule.LocalData.CreaturesCollection[Creature.CreatureID.Value].Race ~= "Pegasus" then
		ExitSpeedHorse(lastHorseExited)
		return
	end
	local CollisionParts = CollectionService:GetTagged("PropCollision")
	for _,Part in pairs(CollisionParts) do
		if Part:IsA("BasePart") then
			Part.CanCollide = false
		else
			print("what?")
		end
	end
	
	WalkSpeedModule.SetSpeedToPegasus(Creature, false)
end

local function CheckIfMounting()
	if CharacterHandler.Mount and mountingFirstFrame and CharacterHandler.Mount.Instance then
		exitFirstFrame = true
		mountingFirstFrame = false
		lastHorseExited = CharacterHandler.Mount.Instance
		InitSpeedHorse(CharacterHandler.Mount.Instance)
		setEffectsActive(false, 0)
		SetupDetection(false)
	end
	if not CharacterHandler.Mount and exitFirstFrame then
		exitFirstFrame = false
		mountingFirstFrame = true
		ExitSpeedHorse(lastHorseExited)
		SetupDetection(true)
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	processFlyMode(deltaTime)
	updateSparks(deltaTime)
	CheckIfMounting()
	CheckTerrainMaterialChange()
end)

game.Lighting.LightingChanged:Connect(function()
	CheckLightState()
end)

HorseEvents.HorseMountEvent.OnClientEvent:Connect(function(newCreature)
	Creature = newCreature

	--if not creature is a dismount and so if a light is dismount, stat light are forced to false
	if not Creature then
		lastLightState = false
	else
		-- If mount reset stats of bonus slip stream
		RE_HorseSpeedEffectActivation:FireServer(Creature.Instance, false)
		WalkSpeedModule.RemoveSlipStreamBonus(Creature.Instance, true)
	end

	CheckLightState(Creature)

	if newCreature == nil then
		ContextActionService:UnbindAction("FlyMode")
	end
end)

RE_SyncClientSparks.OnClientEvent:Connect(function(Sparks)
	currentSparks = Sparks
end)

RF_GetLastSafePointCFrame.OnClientInvoke = function()
	return GetSafePointCFrame()
	--[[ local safePointIndex = GetSafePointCFrameIndex(1)
	if safePointIndex then
		return safePoints[safePointIndex]
	else
		return homePoint
	end ]]
end

RE_ExitedHorse.OnClientEvent:Connect(function()
	materialFirst = true
	player.Character.PrimaryPart.Velocity = Vector3.new(0,0,0)
end)

remoteEvent.CreatureEvolution.CreatureWasEvolved.OnClientEvent:Connect(function()
	RE_GroundMaterialChange:FireServer(currentMaterial, true)
	if CharacterHandler.Mount then
		InitSpeedHorse(CharacterHandler.Mount.Instance)
	end
end)

if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	task.spawn(function()
		SetupPlayerWaterDetection()
	end)
end


if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	task.spawn(PeriodlyCheckMaintenanceStatus)
end