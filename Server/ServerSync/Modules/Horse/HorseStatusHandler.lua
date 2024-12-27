local HorseStatusHandler = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local GetRemoteEvent = require("GetRemoteEvent")
local PlayerDataModule = require("PlayerDataModule")
local HorseEffectModule = require("HorseEffect")
local ToolsModule = require("ToolsModule")
local HorseLoader = require("HorseLoader")
local WalkSpeedModule = require("WalkSpeedModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction
local HorseEvents = ReplicatedStorage.SharedSync.HorseEvents

local InteractionEvent = GetRemoteEvent("InteractionEvent")
local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")
local Effects = ReplicatedStorage.SharedSync.Assets.Effects

local playersMounted = {}

--Health are alaway the last we check because he need check before all other passive maintenance
local PassiveMaintenance = {
	"Cleanness",
	"Happyness",
	"Health"
}

local ActiveMaintenance = {
	"Fed",
	"Scrape",
	"Brushed"
}

local maintenanceRatio = {
	Cleanness = {
		Scrape = 0.5;
		Brushed = 0.5;
	},
	Happyness = {
		Fed = 0.4;
		Scrape = 0.3;
		Brushed = 0.3;
	},
	Health = {
		Cleanness = 0.3;
		Happyness = 0.3;
		Fed = 0.4;
	}
}

local SafePointInProgress = false
local WaitSafePointTimer = 1

--[[
	This function allow to return the last safe point save by client. Target can be a player character or player on creature model.
	Check before change CFrame of target if we move player or creature with player mounted.
]]
local function GetToSafePoint(player, horse, isHorse)
	local target
	if isHorse then
		target = horse
	else
		target = player.Character
	end

	local SafePointCFrame =  RemoteFunction.GetLastSafePointCFrame:InvokeClient(player)
	target:PivotTo(SafePointCFrame)
end

local function ExitHorse(player, horse)
	while horse.PrimaryPart.Velocity.Y > 1 do
		task.wait(0.1)
	end
	RemoteEvent.ExitedHorse:FireClient(player)
	HorseEffectModule.UpdatePlayerSparks(player, false)
end

--[[
	This function allow to setup the value of passive maintenance give in parameter based on ratio of other maintenance type (can be passive or active).
	We can found at the top of this module, the table of ratio maintenance and active and passive maintenance type.
	This function are call when increase or decrease maintenance is call to update value maintenance passive.
]]
local function CalculateCreaturePassiveMaintenance(player, maintenanceType, creatureData, creatureID)
	local originValue = maintenanceType == "Health" and creatureData[maintenanceType].Value or creatureData.Maintenance[maintenanceType].Value
	local valueCalculated = 0
	-- Get Values from maintenance values of the horse and apply them a ratio to calculate the final health value.
	for maintenanceName, maintenanceData in pairs(creatureData.Maintenance) do
		if maintenanceRatio[maintenanceType][maintenanceName] then
			valueCalculated += maintenanceData.Value * maintenanceRatio[maintenanceType][maintenanceName]
		end
	end
	
	if maintenanceType == "Health" then
		creatureData[maintenanceType].Value = math.clamp(math.round(valueCalculated), 0, creatureData[maintenanceType].Max)
		--InteractionEvent:FireClient(player, false, maintenanceType, nil, creatureData[maintenanceType].Value, creatureData[maintenanceType].Max, originValue, creatureID)
	else
		creatureData.Maintenance[maintenanceType].Value = math.clamp(math.round(valueCalculated), 0, creatureData.Maintenance[maintenanceType].Max)
		--InteractionEvent:FireClient(player, false, maintenanceType, nil, creatureData.Maintenance[maintenanceType].Value, creatureData.Maintenance[maintenanceType].Max, originValue, creatureID)
	end

	return creatureData
end

--[[
	Extract in function behavior who allow to apply decrement value on maintenance and send it to client ui
	ratioDecrease -> call for directly use this function to decrement without timer maintenance (exemple when creature burn), pass nbIntervalPassed to nil and give the ratio decrease
	tolerance -> this value is number and determine tolerance to <<show health UI>> when we want check health status, if 0, trigger when Health creature reach 0, if 10 trigger when
	health are 10 ...
]]
local function ApplyMaintenanceDecrement(player, creatureID, dataCreature, nbIntervalPassed, ratioDecrease, tolerance)
	for index, data in pairs(dataCreature["Maintenance"]) do
		--check to decrease only active maintenance because other mainteance are based on ratio on active maintenance
		if table.find(ActiveMaintenance, index) then
			--Make value to decrease based on rate of data and nb interval passed and round this
			local originProgress = data.Value
			local result = math.floor((data.RateDecrease * (nbIntervalPassed or ratioDecrease)) + 0.5)
			if data.Value -  result > 0 then
				data.Value -= result
			else
				data.Value = 0
			end
			InteractionEvent:FireClient(player, false, index, nil, data.Value, data.Max, originProgress, creatureID)
		end
	end

	--check to passive maintenance updated value after change a active maintenance
	for _, v in pairs(PassiveMaintenance) do
		dataCreature = CalculateCreaturePassiveMaintenance(player, v, dataCreature, creatureID)
	end

	--check value of Health, if critical, show UI to take care of creature invoked if exist
	HorseStatusHandler.CheckHealthStatus(player, creatureID, dataCreature["Health"].Value, tolerance)
end

local function calculateAndApplyMaintenaceDecrement(player, creatureID, dataCreature, maintenance_interval, actualTime, tablePopupToSend)
	--Calculate time passed since last time decrease value
	local timePassed = os.difftime(actualTime, dataCreature["LastTimeDecreaseMaintenance"])
	--Calculate how many interval is passed during last time
	local nbIntervalPassed = timePassed/maintenance_interval
	dataCreature["LastTimeDecreaseMaintenance"] = actualTime
	if nbIntervalPassed > 0 then
		ApplyMaintenanceDecrement(player, creatureID, dataCreature, nbIntervalPassed, nil, 0)

		--check status of maintenance Happyness to make a popup alert if needed
		if dataCreature["Maintenance"].Happyness.Value <= 0 then
			--save the name of horse need care
			table.insert(tablePopupToSend, dataCreature["CreatureName"])
		end
	end
end

local function countJobHorseInHorseCollection(Job, creaturesCollection, player, maintenance_interval, actualTime, tablePopupToSend)
	local countjob = 0
	for creatureID, dataCreature in pairs(creaturesCollection) do
		if string.match(string.lower(dataCreature.Genes.Job), Job) then
			calculateAndApplyMaintenaceDecrement(player, creatureID, dataCreature, maintenance_interval, actualTime, tablePopupToSend)
			if dataCreature.Stamina.Value >= 50 and dataCreature["Maintenance"].Happyness.Value >= 70 and dataCreature["Maintenance"].Fed.Value >= 70 and dataCreature["Maintenance"].Cleanness.Value >= 70 then
				countjob += 1000
				dataCreature.Stamina.Value -= 50
			elseif dataCreature.Stamina.Value < 50 then
				warn("Horse is too exhaused to do his job, let him recover his stamina.")
			end
		end
	end
	return countjob
end

local function jobMaintenance(countWasher, countFarmer, player, maintenance_interval, actualTime, creaturesCollection, tablePopupToSend)
	for creatureID, dataCreature in pairs(creaturesCollection) do -- As Long as Farmers and washer value > 0 feed and wash horse => giving happyness
		calculateAndApplyMaintenaceDecrement(player, creatureID, dataCreature, maintenance_interval, actualTime, tablePopupToSend)
		if countWasher > 0 and not string.match(string.lower(dataCreature.Genes.Job), "medic") then
			dataCreature["Maintenance"].Cleanness.Value = dataCreature["Maintenance"].Cleanness.Max
			dataCreature["Maintenance"].Happyness.Value += dataCreature["Maintenance"].Happyness.Max/2
			dataCreature["Maintenance"].Happyness.Value = math.clamp(dataCreature["Maintenance"].Happyness.Value, 0, dataCreature["Maintenance"].Happyness.Max)
			countWasher -= 100
		end
		if countFarmer > 0 and not string.match(string.lower(dataCreature.Genes.Job), "farmer") then
			local used = dataCreature["Maintenance"].Fed.Max - dataCreature["Maintenance"].Fed.Value
			if countFarmer - used < 0 then
				used = countFarmer
			end
			dataCreature["Maintenance"].Fed.Value += used
			dataCreature["Maintenance"].Fed.Value = math.clamp(dataCreature["Maintenance"].Fed.Value, 0, dataCreature["Maintenance"].Fed.Max)
			dataCreature["Maintenance"].Happyness.Value += used/2
			dataCreature["Maintenance"].Happyness.Value = math.clamp(dataCreature["Maintenance"].Happyness.Value, 0, dataCreature["Maintenance"].Happyness.Max)
			countFarmer -= used
		end
		PlayerDataModule:Set(player, dataCreature, "CreaturesCollection."..creatureID)
	end
end

--Little animation function with particle fire to animate teleportation when player or creature player are teleport can't touch CrackLava floor
local function PlayTPAnim(target, mat, t)
	local clone
	if mat == Enum.Material.CrackedLava then
		clone = Effects.OnFireParticle:Clone()
	elseif mat == Enum.Material.Water then
		clone = Effects.OnWaterParticle:Clone()
	elseif mat == Enum.Material.Ice then
		clone = Effects.OnIceParticle:Clone()
	end

	clone.Parent = target
	clone.Enabled = true
	task.wait(t)
	clone.Enabled = false
	task.spawn(function()
		task.wait(1.5)
		clone:Destroy()
	end)
end

--[[
	This function allow to call ApplyMaintenanceDecrement and save data in PlayerDataModule directly after make maintenance to dodge conflict with
	auto maintenance system based on time.
	After this we can determine with tolerance health if we teleport or not creature player.
]]
local function DecreaseQuicklyMaintenancesStatus(player, isHorse, material, creatureID, creatureData, ratioDecrease, tolerance)
	ApplyMaintenanceDecrement(player, creatureID, creatureData, nil, ratioDecrease, tolerance)
	PlayerDataModule:Set(player, creatureData, "CreaturesCollection."..playersMounted[player.UserId].CreatureID)

	PlayTPAnim(playersMounted[player.UserId].Creature.PrimaryPart, material, WaitSafePointTimer)

	if creatureData.Health.Value <= tolerance then
		SafePointInProgress = true
		GetToSafePoint(player,playersMounted[player.UserId].Creature, isHorse)
		WalkSpeedModule.ApplyBlockedMalus(playersMounted[player.UserId].Creature, 0)
		PlayTPAnim(playersMounted[player.UserId].Creature.PrimaryPart, material, WaitSafePointTimer)
		WalkSpeedModule.ApplyBlockedMalus(playersMounted[player.UserId].Creature, 1)
		SafePointInProgress = false
	end
end

local function GroundMaterialChange(player, NewMaterial, isHorse)
	if SafePointInProgress then
		return
	end

	--if not horse so human can't walk on Cracked Lava, check ground for player and tp last save point if needed
	if not isHorse then
		local stringMaterial, num = string.sub(tostring(NewMaterial), 15, -1)
		player.Character:SetAttribute("EnvironmentMaterial", stringMaterial)

		if NewMaterial == Enum.Material.CrackedLava or NewMaterial == Enum.Material.Water or NewMaterial == Enum.Material.Ice then
			player.Character.Humanoid:TakeDamage(5)
			PlayTPAnim(player.Character.PrimaryPart, NewMaterial, WaitSafePointTimer)
			if player.Character.Humanoid.Health <= 10 then
				SafePointInProgress = true
				player.Character.Humanoid.Health = 50
				GetToSafePoint(player,nil,isHorse)
				local t = player.Character.Humanoid.WalkSpeed
				player.Character.Humanoid.WalkSpeed = 0
				PlayTPAnim(player.Character.PrimaryPart, NewMaterial, WaitSafePointTimer)
				player.Character.Humanoid.WalkSpeed = t
				SafePointInProgress = false
			end
		end
		return
	end

	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	local creatureData = creaturesCollection[playersMounted[player.UserId].CreatureID]
	if NewMaterial == Enum.Material.Water then
		if playersMounted[player.UserId].CurrentMaterial ~= NewMaterial then
			--new material detected apply talent speed from terrain material
			if creatureData.Talents["WaterSpeed"] then
				RemoteEvent.WalkSpeed.ApplyTalentBonus:FireClient(player, playersMounted[player.UserId].Creature, true, creatureData.Talents["WaterSpeed"])
				print("TEST APPLY TALENT WATER SPEED")
			end
		end

		playersMounted[player.UserId].CurrentMaterial = Enum.Material.Water

		if creatureData.Race ~= "Water" then
			--check talent creature for ratio
			local ratio = 0.5
			if creatureData.Talents["WaterWalker"] then
				ratio -= ratio * (creatureData.Talents["WaterWalker"]/100)
				print("TEST APPLY TALENT WATER WALKER", ratio)
			end
			--decrease quickly value of creature in water
			DecreaseQuicklyMaintenancesStatus(player, isHorse, NewMaterial, playersMounted[player.UserId].CreatureID, creatureData, ratio, 0)
		end
	elseif NewMaterial == Enum.Material.CrackedLava or NewMaterial == Enum.Material.Ice then
		playersMounted[player.UserId].CurrentMaterial = NewMaterial

        if playersMounted[player.UserId].CurrentMaterial ~= NewMaterial then
            if NewMaterial == Enum.Material.CrackedLava then
                --new material detected apply talent speed from terrain material
                if creatureData.Talents["FireSpeed"] then
                    RemoteEvent.WalkSpeed.ApplyTalentBonus:FireClient(player, playersMounted[player.UserId].Creature, true, creatureData.Talents["FireSpeed"])
                    print("TEST APPLY TALENT FIRE SPEED")
                end
            end
        end

        if NewMaterial == Enum.Material.CrackedLava then
            if creatureData.Race ~= "Fire" then
                local ratio = 2
                if creatureData.Talents["FireWalker"] then
                    ratio -= ratio * (creatureData.Talents["FireWalker"]/100)
                end
                --decrease quickly value of creature in fire
                DecreaseQuicklyMaintenancesStatus(player, isHorse, NewMaterial, playersMounted[player.UserId].CreatureID, creatureData, ratio, 0)
            end
        elseif NewMaterial == Enum.Material.Ice then -- Check if material is Ice (send by damage area Ice in mountain)
            if creatureData.Race ~= "Ice" then
                local ratio = 2
                --decrease quickly value of creature in mountain frost ice
                DecreaseQuicklyMaintenancesStatus(player, isHorse, NewMaterial, playersMounted[player.UserId].CreatureID, creatureData, ratio, 0)
            end
        end
	else
		if playersMounted[player.UserId].CurrentMaterial ~= NewMaterial then
			--new material detected but not water or crackedlava so remove bonus talent apply by this element
			for talentId, value  in pairs(creatureData.Talents) do
				if CreaturesTalentsModule.TalentsTable[talentId].TalentType == CreaturesTalentsModule.GetTalentsType().Speed then
					print("TEST REMOVE SPEED OF TALENT", talentId)
					RemoteEvent.WalkSpeed.ApplyTalentBonus:FireClient(player, playersMounted[player.UserId].Creature, false, value)
				end
			end
		end
		playersMounted[player.UserId].CurrentMaterial = Enum.Material.Grass
	end

	local stringMaterial, num = string.sub(tostring(playersMounted[player.UserId].CurrentMaterial), 15, -1)
	playersMounted[player.UserId].Creature.EnvironmentMaterial.Value = stringMaterial
end

local function LightStateChange(player, lightState)
	local creaturesCollection = PlayerDataModule:Get(player, "CreaturesCollection")
	local creatureRace = creaturesCollection[playersMounted[player.UserId].CreatureID].Race
	if creatureRace == "Light" then
		playersMounted[player.UserId].Creature.HumanoidRootPart.Light.Enabled = lightState
	else
		playersMounted[player.UserId].Creature.HumanoidRootPart.Light.Enabled = false
	end
end

local function stockVelocity(deltaTime)
	for _, player in pairs(playersMounted) do
		if player.playerMounted.Character then
			if player.Creature.PrimaryPart then
				local velocity = player.Creature.PrimaryPart.Velocity.Magnitude * deltaTime
				if velocity/deltaTime < 1 then
					player.restCumuled += 100 * deltaTime
				else
					player.velocityCumuled += 100 * deltaTime
				end
			end
		end
	end
end

--[[
	This method allows you to increase the maintenance value of a specific horse that the player owns by ID.
]]
function HorseStatusHandler.IncreaseMaintenanceValuesOfHorse(player, creatureData, creatureID, maintenanceType, amount)
	if not creatureData then
		return
	end
	
	local maintenancesValue = creatureData["Maintenance"][maintenanceType].Value
	maintenancesValue += amount
	maintenancesValue = math.clamp(maintenancesValue, 0, 100)
	creatureData["Maintenance"][maintenanceType].Value = maintenancesValue

	--check to passive maintenance updated value after change a active maintenance
	for _, v in pairs(PassiveMaintenance) do
		creatureData = CalculateCreaturePassiveMaintenance(player, v, creatureData, creatureID)
	end

	PlayerDataModule:Set(player, creatureData, "CreaturesCollection."..creatureID)

	-- When Increase maintenance have successfully, we reward player with little golds
	-- We check if player have gamepass x2 ecus and make gold reward value depending of that
	local gold = BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.GoldsX2.ProductID) and GameDataModule.RewardCareAnimal * 2 or GameDataModule.RewardCareAnimal
	PlayerDataModule:Increment(player, gold, "Ecus")
end

--[[
	This method get all horses and decrease value of maintenance data based on the last time when are decrease
	the actual time and interval of checkup.
	This method is call when the player enter in game and when timer localplayer need check. We use time to check who many time passed since last
	decrease maintenance and apply the decrease value with this paramters.

	Method was improve to better perf with lot of data horses. We make check into coroutine and with little wait and by number give to improve performance of
	check data and not make freeze player during decrease maintenance. Popup are stack into table and create and call after maintenance to show max 99 popup to
	give info player 99 first horse need care.
]]
function HorseStatusHandler.DecreaseMaintenanceValuesOfCreatures(player, maintenance_interval, actualTime)
	local index = 1
	local nbGetRef = 50
	local nbGet = nbGetRef

	--this table stack the name of horse need care by player
	local tablePopupToSend = {}

	local function recursive()
		--print("Changement decrease recursive", index, nbGet)
		local creaturesCollection, MaxElements = PlayerDataModule:GetNbData(player, "CreaturesCollection", nbGet, index)
		if not creaturesCollection then
			return
		end
		
		--Count Medic and farmer horse present in data.
		local countWasher = countJobHorseInHorseCollection("medic", creaturesCollection, player, maintenance_interval, actualTime, tablePopupToSend)
		local countFarmer = countJobHorseInHorseCollection("farmer", creaturesCollection, player, maintenance_interval, actualTime, tablePopupToSend)
		local harvests = PlayerDataModule:Get(player, "TotalHarvests")
		local remainingHarvest = harvests - countFarmer
		if remainingHarvest <= 0 then
			countFarmer += remainingHarvest
			remainingHarvest = 0
		end
		PlayerDataModule:Set(player, remainingHarvest, "TotalHarvests")

		--How many horses are taken care of
		--don't decrease their food and health value.
		jobMaintenance(countWasher, countFarmer, player, maintenance_interval, actualTime, creaturesCollection, tablePopupToSend)

		
		if nbGet <= MaxElements then
			nbGet += nbGetRef
			index += nbGetRef
			task.wait()
			recursive()
		else
			--print("TABLE POPUP", tablePopupToSend)
			--print("End Decrease maintenance, create max popup")
			--when decrease is end, take only 99 first element of table to create popup. Not need more popup because player can't take care of +100 horses if he have already
			--99 horses to care. So not create popup not need and if horse is ok, the next time it's not make into tablePopup and let another horse bad care popup player.
			for i=1, #tablePopupToSend >= 99 and 99 or #tablePopupToSend, 1 do
				BindableEvent.ShowPopupAlert:Fire(
					player,
					"Happyness is very low",
					"Be careful Happyness for "..tablePopupToSend[i].." are dangerous decrease to 0 !!!",
					ToolsModule.AlertPriority.ExtremlyHigh,
					nil,
					ToolsModule.AlertTypeButton.OK
				)
			end
		end
	end
	coroutine.wrap(recursive)()
end

--[[
	This function allow to check if player have summon a creature we check status Health, if < or equals to 0, we slow movement of player and force show Maintenance UI
]]
function HorseStatusHandler.CheckHealthStatus(player, creatureID, health, tolerance)
	if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
		return
	end
	if creatureID then
		--check if player ismounted or not
		local Creature = HorseLoader:GetCreatureWithPlayer(player)
		if Creature then
			--check if creature check is the mounted creature
			if Creature.ID == creatureID then
				local Health = health or PlayerDataModule:Get(player, "CreaturesCollection."..creatureID).Health.Value
				if Health <= tolerance then
					ExitHorse(player, playersMounted[player.UserId].Creature)
					RemoteEvent.OpenCreatureMenu:FireClient(player, playersMounted[player.UserId].Creature, "Maintenance")
				end
			end
		end
	end
end

function HorseStatusHandler:SetUpdateStatusCreature(player, isMounting, creatureID)
    if not isMounting then
		playersMounted[player.UserId] = nil
		return
	end

	local horseInstance
	for _, horse in pairs(CreaturesFolder:GetChildren()) do
		if string.match(horse.Name, player.Name) then
			horseInstance = horse
		end
	end

	playersMounted[player.UserId] = {
		playerMounted = player;
		Creature = horseInstance;
		CreatureID = creatureID;
		CurrentMaterial = nil;
		velocityCumuled = 0;
		horseDecreaseRatio = 1;
		horseRecoveryRatio = 1;
		restCumuled = 0;
	}
end

--if not on the place Parade Competition we can use update system
if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
	RunService.Stepped:Connect(function(time, deltaTime)
		stockVelocity(deltaTime)
	end)
end

--For this event we make check id place into event because some client try to fire it and if not exist we have many error request fail, so event exist but
--function executed only if not on Competition Parade
RemoteEvent.GroundMaterialChange.OnServerEvent:Connect(function(player, NewMaterial, isHorse)
	if game.PlaceId ~= EnvironmentModule.GetPlaceId("FashionShow") then
		GroundMaterialChange(player, NewMaterial, isHorse)
	end
end)

RemoteEvent.LightStateChange.OnServerEvent:Connect(function(player, lightState)
	LightStateChange(player, lightState)
end)

return HorseStatusHandler