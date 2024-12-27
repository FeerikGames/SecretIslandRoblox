local PlayerDataModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local GetRemoteEvent = _G.require("GetRemoteEvent")
local GetRemoteFunction = _G.require("GetRemoteFunction")
local DataVersioning = require(script.DataVersioning)
local DataUpdateEvent = GetRemoteEvent("DataUpdateEvent")
local InitDataGet = GetRemoteFunction("DataGetFunction")
local ToolsModule = require("ToolsModule")
local GameDataModule = require("GameDataModule")

--To determine the type of data to work on
local dataType = "Test2"

local SaveDataInStudio = script:GetAttribute("SaveDataInStudio")

local HTTPService = game:GetService("HttpService")
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent

--Setup variables datastore of game
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local PlayerDatastore = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.Player.PlayerData.Name..GameDataModule.DatastoreVariables.Player.PlayerData.Version)


--local PlayerDataFolder = game.ServerStorage.ServerStorageSync.PlayerData
local playersLeft = 0
local AUTOSAVE_INTERVAL = 120

--[[
	This function allow to return size of Dictionnary
]]
local function LengthOfDic(Table)
	local counter = 0 
	for _, v in pairs(Table) do
		counter =counter + 1
	end
	return counter
end

local function deepCopy(original)
	if type(original) == "table" then
		local copy = {}
		for k, v in pairs(original) do
			if type(v) == "table" then
				v = deepCopy(v)
			end
			copy[k] = v
		end
		return copy
	end
	return original
end

-- Data cache
local RawDataCache = {}

local function GetKeyFromIndex(Index)
	local UserId = Index
	if tonumber(Index) then
		UserId = Index
	elseif typeof(Index) == "Instance" then
		UserId = Index.UserId
	else --Maybe do username check? but probably not worth it.
		error("Invalid index")
	end
	return tostring(UserId)
end

PlayerDataModule.DataCache = setmetatable({},{ -- Metatable for data cache
	__index = function(Table,Index)
		local Key = GetKeyFromIndex(Index)
		return Key and RawDataCache[Key] or nil
	end,
	__newindex = function(Table,Index,Value)
		local Key = GetKeyFromIndex(Index)
		if Key then
			RawDataCache[GetKeyFromIndex(Index)] = Value
		end
	end,
	__len = function(Table)
		local TotalCachedData = 0
		for _,_ in pairs(RawDataCache) do
			TotalCachedData += 1
		end
		return TotalCachedData
	end
})

--[[
	This is a recursive method to convert folders and data value into dictionary depending of the number of data need
	Make for Client UI who need nb horses to display into horsesCollection UI. It's use for a system pages with index and next or previous value to show
	This function return the size of datafolder to say at the client what is the max value to not make error out of table.
]]
local function GetNbDataFilter(dataCreaturesCollection, dataToReturn, nbValue, index, filterChoose)

	local dataFiltered = {}
	--if filters are selected we filter horse data to make a datafiltered as datafolder who use for page system. Allow to return datafiltered directly to adapte page system with filter system existing
	if filterChoose then
		if LengthOfDic(filterChoose) > 0 then
			for index, dataCreature in pairs(dataCreaturesCollection) do
				local filterIsOk = true
				--check data corresponding filter or not
				for filterName, filterData in pairs(filterChoose) do
					if tostring(dataCreature[filterName]) ~= filterData then
						filterIsOk = false
					end
				end
				if filterIsOk then
					--adding data if coreresponding all filter selected by player
					dataFiltered[index] = dataCreature
				end
			end
		end
	end

	--were we chose if we use the data filtered or the data folder to get creature datas
	local dataSelected = (filterChoose and LengthOfDic(filterChoose) > 0) and dataFiltered or dataCreaturesCollection

	-- Remove isDELETE creature from dataSelected
	for index, data in pairs(dataSelected) do
		if data["isDELETE"] then
			dataSelected[index] = nil
		end
	end

	local sortedData = {}
	for index, creatureData in pairs(dataSelected) do
		sortedData[#sortedData+1] = {Index = index, CreatureData = creatureData}
	end
	table.sort(sortedData, function(a, b)
		return a.CreatureData.TimeObtained > b.CreatureData.TimeObtained
	end)

	for i=index and index or 1, nbValue and nbValue or #sortedData, 1 do
		local creature = sortedData[i]
		if creature then
			dataToReturn[creature.Index] = creature.CreatureData
		end
	end

	return #sortedData
end

local AchievementsInitData = {}
function PlayerDataModule.SetInitAchievementsData(data)
	AchievementsInitData = deepCopy(data)
	for id, achiev in pairs(AchievementsInitData) do
		for dataID, _ in pairs(achiev) do
			if dataID ~= "Progress" and dataID ~= "Active" and dataID ~= "Following" and dataID ~= "Done" then
				achiev[dataID] = nil
			end
		end
	end
end

--Structure Data Player default
local PlayerDataDefaultStructure = require(script.DefaultDataSchema)

function PlayerDataModule.GetPlayerDataDefaultStructure()
	return PlayerDataDefaultStructure
end

--Method to load data player from datastore and return data encoded
function PlayerDataModule:Load(player)
	local key = GetKeyFromIndex(player)
	local data 
	local success, err = pcall(function()
		data = PlayerDatastore:GetAsync(key)
	end)

	if not success then
		warn("[YEILD] Data failed to load, retrying in 4 seconds. \nReason:",err)
		task.wait(4)
		data = self:Load(player)
	end
	return data
end

local function UpdatePlayerData(data, defaultData)
	for index, value in pairs(defaultData) do
		if data[index] == nil then
			data[index] = value
			continue
		end
		if typeof(value) == "table" then
			UpdatePlayerData(data[index], value)
			continue
		end
	end
end

--Method to setup data loaded and decoded it for set data into server player and check if it's new player use default structure data for init data player
local function SetupData(player)
	local data = PlayerDataModule:Load(player)
	if data then
		DataVersioning:UpdateVersion(data)
		UpdatePlayerData(data, PlayerDataDefaultStructure)
		PlayerDataModule:Set(player, data)
		local Sparks = PlayerDataModule:Get(player, "Sparks")
		PlayerDataModule:Set(player, Sparks, "Sparks")

		-- Init value of leaderstats board player
		player.leaderstats.Ecus.Value = PlayerDataModule:Get(player, "Ecus")
		player.leaderstats.Animals.Value = PlayerDataModule:Get(player, "TotalNumberOfCreatures")

		if data["FirstTime"] then
			--send event to client to init UI and behavior for the first time connection player
			ReplicatedStorage.SharedSync.RemoteEvent.FirstTimePlayed.InitFirstTimeGui:FireClient(player)
		end

		print(player.Name.. " data loaded!", PlayerDataModule.DataCache[player])
	else
		print(player.Name.." is a new player, init data default structure")
		local data = deepCopy(PlayerDataDefaultStructure)
		data.Achievements = AchievementsInitData

		DataVersioning:UpdateVersion(data)
		UpdatePlayerData(data, PlayerDataDefaultStructure)

		PlayerDataModule:Set(player, data)

		--send event to client to init UI and behavior for the first time connection player
		ReplicatedStorage.SharedSync.RemoteEvent.FirstTimePlayed.InitFirstTimeGui:FireClient(player)
	end
end

--Event player connexion for init folder data and setup data player
function PlayerDataModule:Init()
	game.Players.PlayerAdded:Connect(function(player:Player)
		playersLeft += 1
		local staminaInfo = Instance.new("NumberValue")
		staminaInfo.Name = "Stamina"
		staminaInfo.Parent = player
		staminaInfo.Value = 100

		-- Create leaderstats board Roblox in game with Ecus data and Nb Animal data
		local leaderstats = Instance.new("Folder", player)
		leaderstats.Name = "leaderstats"

		local ecus = Instance.new("IntValue", leaderstats)
		ecus.Name = "Ecus"
		ecus.Value = 0

		local nbAnimals = Instance.new("IntValue", leaderstats)
		nbAnimals.Name = "Animals"
		nbAnimals.Value = 0

		--Setup Name over Head GUI
		player.CharacterAdded:Connect(function(character:Model)
			task.wait(5) --TEMP on attend max 5s car on dirait que le character est charger plusieur fois et l'adornee de la head disparait à chaque fois... TODO: fix it
			ToolsModule.CreateOverHeadGuiName(player)
		end)
	end)
	InitDataGet.OnServerInvoke = function(Player)
		print("got request")
		PlayerDataModule:Get(Player)
	end
end
--[[
	Method to set data from dictionnary to folder located at player folder
]]
function PlayerDataModule:Set(player, value, path, isNew)
	local PathTable = string.split(path or "",".")
	local data = PlayerDataModule.DataCache[player]
	local DataSetSuccess = false
	if data and PathTable[1] ~= "" then
		local CurrentReference = data
		for Depth,PathSegment in pairs(PathTable) do
			local PathSegementInt = tonumber(PathSegment)
			PathSegment = PathSegementInt and string.len(PathSegementInt) == string.len(PathSegment) and PathSegementInt or PathSegment
			if CurrentReference[PathSegment] ~= nil or isNew then
				if Depth == #PathTable then
					CurrentReference[PathSegment] = value
					DataSetSuccess = true
				elseif CurrentReference[PathSegment] and type(CurrentReference[PathSegment]) == "table" then
					CurrentReference = CurrentReference[PathSegment]
				else
					warn("Invalid path: Attempted to index a non-table.", path)
				end
			else
				warn("Invalid path:",path)
				break
			end
		end
	elseif PathTable[1] == "" then
		PlayerDataModule.DataCache[player] = value
		print("Set data!", PlayerDataModule.DataCache[player])
		DataSetSuccess = true
	end
	if DataSetSuccess then -- Replicate to client
		local PlayerInstance = typeof(player) == "Instance" and player or Players:GetPlayerByUserId(player)
		if PlayerInstance then
			DataUpdateEvent:FireClient(PlayerInstance,path,value)

			-- When server send sync data to client we make an update of value in player leaderstats board
			PlayerInstance.leaderstats.Ecus.Value = PlayerDataModule:Get(PlayerInstance, "Ecus")
			PlayerInstance.leaderstats.Animals.Value = PlayerDataModule:Get(PlayerInstance, "TotalNumberOfCreatures")
		end
	end
end

--[[
	Parameters : player, Stat to increment, value of incrementation
	Increment a value of the player data by the value !!Only values not insides tables in player data can be incremented!!
]]
function PlayerDataModule:Increment(player, value, path)
	local number = PlayerDataModule:Get(player, path)
	if number and tonumber(number) then
		PlayerDataModule:Set(player,number + value,path)
	else
		error("Cant increment, path returned nil: "..(path or " nil"))
		return false
	end

	return true
end

function PlayerDataModule:Decrement(player, value, stat) -- Not sure why this exists as you could pass a negative value to increment, but we'll make it work anyways
	if PlayerDataModule:Get(player, stat) - value < 0 then
		return false
	else
		return PlayerDataModule:Increment(player,-value,stat)
	end
end

--[[
	Method to get data from folder save to dicitonnary
]]
function PlayerDataModule:Get(player, path)
	local PathTable = string.split(path or "",".")
	local data = self.DataCache[player]
	if data then
		if PathTable[1] ~= "" then
			local CurrentReference = data
			for Depth,PathSegment in pairs(PathTable) do
				local PathSegementInt = tonumber(PathSegment)
				PathSegment = PathSegementInt and string.len(PathSegementInt) == string.len(PathSegment) and PathSegementInt or PathSegment
				if CurrentReference[PathSegment] then
					if Depth == #PathTable then
						return deepCopy(CurrentReference[PathSegment])
					elseif type(CurrentReference[PathSegment]) == "table" then
						CurrentReference = CurrentReference[PathSegment]
					else
						error("Invalid path: Attempted to index a non-table.", path)
					end
				else
					error("Invalid path:",path)
					break
				end
			end
		else
			return deepCopy(data)
		end
	else
		print("loading data")
		SetupData(player)
		return self:Get(player,path)
	end
end

--[[
	This get method as make for the GetCreaturesCollection event with client. Allow to return only the number of data need.
	By default, if no nbvalue give by player, method work as normal Get and return all CreaturesCollection.
]]
function PlayerDataModule:GetNbData(player, stat, nbValue, index, filterChoose)
	local data = self.DataCache[player]
	if data then
		local dataToReturn = {}
		local MaxElement = GetNbDataFilter(data[stat], dataToReturn, nbValue, index, filterChoose)
		return dataToReturn, MaxElement
	end
end

--[[
	This method allow to check if player have slots creature available compared to numbers of availables creature in collection.
	We auto make a popup for player if collection is full and need to buy more slots for collections creatures.

	Return false if any error or fail.
	Return true if slots are available and return nbMaxSlots and nbCreature availables.
]]
function PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(player, callPopup)
	local data = self.DataCache[player]
	if data then
		-- Get all creatures in collection
		local CreaturesCollection = data["CreaturesCollection"]

		-- Remove isDELETE creature from collection
		for index, data in pairs(CreaturesCollection) do
			if data["isDELETE"] then
				CreaturesCollection[index] = nil
			end
		end

		-- Check number of creatures available player have
		local nbCreatures = LengthOfDic(CreaturesCollection)

		if nbCreatures < data.NbMaxSlotsCreature then
			return true, data.NbMaxSlotsCreature, nbCreatures
		else
			local function callback()
				game:GetService("MarketplaceService"):PromptProductPurchase(player, 1519228137)
			end

			if callPopup then
				BindableEvent.ShowPopupAlert:Fire(
					player,
					"Collections Full !",
					"Your animal collection is full! \n Do you want to expand your number of slots ?",
					ToolsModule.AlertPriority.Annoucement,
					ToolsModule.AlertTypeButton.NO,
					ToolsModule.AlertTypeButton.YES,
					nil,
					nil,
					callback,
					{}
				)
			end

			return false, data.NbMaxSlotsCreature, nbCreatures
		end
	end

	return false
end

--[[ function PlayerDataModule.GetAll(player)
	local key = player.UserId
	local data = {}
	DataManagerModule.convertDataToDictionary(PlayerDataFolder[key], data)
	return data
end ]]
--[[
	Method to set directly the value of stat in parameter. Warning, stat should be a value data and not a dictionnary

function PlayerDataModule.SetValueOf(player, stat, value)
	local key = player.UserId
	local statExist = PlayerDataFolder[key]:FindFirstChild(stat)
	if statExist then
		statExist.Value = value
		if player:FindFirstChild(stat) then
			player[stat].Value = PlayerDataModule.GetValueOf(player, stat)
		end
		--print("Set value of "..stat)
		return true
	else
		--print(stat.." not set value because not found !")
		return false
	end
end
]]
--[[
	Method to get directly the value of stat in parameter. Warning, stat should be a value data and not a dictionnary

function PlayerDataModule.GetValueOf(player, stat)
	local key = player.UserId
	local statExist = PlayerDataFolder[key]:FindFirstChild(stat)
	if statExist then
		return statExist.Value
	end
	return nil
end
]]
function PlayerDataModule:Save(player, from)
	local key = player.UserId
	
	self:Set(player, os.time(),"LastDateConnexion")
	
	local dataToSave = PlayerDataModule.DataCache[player]
	if not dataToSave then
		print(player,"no data to save.")
		return
	end
	
	--warn("test player data", dataToSave)
	
	--local data = PlayerDataModule.RecursiveCopy(sessionData[key])
	--local data = {}
	--DataManagerModule.convertDataToDictionary(PlayerDataFolder[key], data)
	
	--print(data)
	
	--local data_encoded = HTTPService:JSONEncode(data)

	if not RunService:IsStudio() or SaveDataInStudio == true then
		local success, err = pcall(function()
			PlayerDatastore:SetAsync(key, dataToSave)-- NOTE: key seems to be an int?
		end)

		if success then
			print(player.Name.. "'s data has been saved!")
		else
			error(err)
			warn("Couldn't save data, retrying in 5 seconds")
			task.delay(5,function()
				self:Save(player)
			end)
		end
	else
		print("Won't save data because SaveDataInStudio is false.")
	end
end

local bindableEvent = Instance.new("BindableEvent")
game.Players.PlayerRemoving:Connect(function(player)
	task.wait(0.5) -- Enough time for other functions to send data in.
	warn(player.Name,"LEFT THE GAME !")
	PlayerDataModule:Save(player, "FROM REMOVING")
	playersLeft -= 1
	bindableEvent:Fire()
	PlayerDataModule.DataCache[player] = nil
end)


local function autoSave()
	while task.wait(AUTOSAVE_INTERVAL) do
		print("Auto-saving data for all players")
		for key, player in pairs(game.Players:GetPlayers()) do
			PlayerDataModule:Save(player, "FROM AUTOSAVE")
		end
	end
end

--Initialize autosave loop
task.spawn(autoSave)

game:BindToClose(function()
	-- this will be trigger upon shutdown
	while playersLeft > 0 do
		bindableEvent.Event:Wait()
	end
end)

--[[
	This Remote Function allow to get data of other player in client side when player need to know specific data of other player.
	Because a LocalPlayer can only see is LocalData, but in specific case we need local player know other player data. Example in InteractionUISystem.
]]
RemoteFunction.GetDataOfPlayer.OnServerInvoke = function(player, otherPlayer, path)
	return PlayerDataModule:Get(otherPlayer, path)
end

PlayerDataModule:Init()

return PlayerDataModule
