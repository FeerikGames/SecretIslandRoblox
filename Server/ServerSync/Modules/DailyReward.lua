local DailyReward = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")
local GameDataModule = require("GameDataModule")

if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
    return DailyReward
end

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent

local HTTPService = game:GetService("HttpService")
--To determine the type of data to work on
local dataType = "Test9"

--Setup variables datastore of game
--This variable allow to reset datatable for daily reward all month for use it in name of DS.
local TimeForResetMonthly = os.date("!*t").month..os.date("!*t").year -- heure UTC
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ds_timeReward = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.Player.DailyRewardTime.Name..GameDataModule.DatastoreVariables.Player.DailyRewardTime.Version..TimeForResetMonthly)
local ds_days = DataStoreService:GetDataStore(GameDataModule.DatastoreVariables.Player.Days.Name..GameDataModule.DatastoreVariables.Player.Days.Version..TimeForResetMonthly)

--Require Modules
local PlayerDataModule = require("PlayerDataModule")
local GameDataModule = require("GameDataModule")

--Remote Event
local DailyRewardEvent = RemoteEvent.DailyReward

--The time until you can claim the next reward in hours
local TIME_REWARD = 10
--Variable to save for each player their advance on recovery time for reward
local savedTimeReward = {}

--Enum for the type of reward
local RewardType = {
	Ecu = "Ecus",
	Feez = "Feez"
}

--[[
	Daily Reward Data Dictionary.
	It contains information about a reward, the type, the quantity and whether the reward
	is already claimed by the player.
	It is possible to add as many rewards as you want in this dictionary, the interface
	interface adapts to the number of rewards.
]]
local DailyRewardsDico = {
	Day1 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 100
	};
	Day2 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 200
	};
	Day3 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 300
	};
	Day4 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 50
	};
	Day5 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.PinkBackground,
		RewardType = RewardType.Ecu,
		Quantity = 800
	};
	Day6 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 400
	};
	Day7 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 450
	};
	Day8 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 100
	};
	Day9 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 500
	};
	Day10 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.PinkBackground,
		RewardType = RewardType.Ecu,
		Quantity = 3000
	};
	Day11 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 600
	};
	Day12 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 650
	};
	Day13 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 700
	};
	Day14 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 250
	};
	Day15 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.PinkBackground,
		RewardType = RewardType.Ecu,
		Quantity = 1500
	};
	Day16 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 250
	};
	Day17 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 250
	};
	Day18 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 1200
	};
	Day19 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.BlueBackground,
		RewardType = RewardType.Ecu,
		Quantity = 1200
	};
	Day20 = {
		Claimed = false,
		Image = GameDataModule.DailyRewardImage.Background.PinkBackground,
		RewardType = RewardType.Ecu,
		Quantity = 10000
	};
}

--This method allows a player's data to be uploaded to the reward validation system.
function DailyReward.LoadDays(player)
	local key = player.UserId
	local data 
	local success, err = pcall(function()
		data = ds_days:GetAsync(key)
	end)

	if not success then
		data = DailyReward.LoadDays(player)
	end

	return data
end

--[[
	This method retrieves the time os.time() at the time of the reward recovery
	to allow the server to check, even if the player disconnects, when he can claim the next
	the next reward.
]]
function DailyReward.LoadSavedTime(player)
	local key = player.UserId
	local data 
	local success, err = pcall(function()
		data = ds_timeReward:GetAsync(key)
	end)

	if not success then
		data = DailyReward.LoadDays(player)
	end

	return data
end

--[[
	This method allows to initialize all the data necessary for the operation
	of the Daily Reward system. Whether it is the rewards, the timer for the rewards etc
	which will be found on the Player in Players.
	
]]
function DailyReward.InitData(player)
	local WaitTimerReward = Instance.new("IntValue", player)
	WaitTimerReward.Name = "WaitTimerReward"
	
	local TimerExist = Instance.new("BoolValue", player)
	TimerExist.Name = "TimerExist"
	TimerExist.Value = false
	

	local dayActual = Instance.new("StringValue", player)
	dayActual.Name = "DayActual"
	dayActual.Value = "Day1"

	local days = Instance.new("Folder", player)
	days.Name = "Days"
	
	local data_decoded
	savedTimeReward[player.UserId] = DailyReward.LoadSavedTime(player)
	local data = DailyReward.LoadDays(player)
	if data then
		data_decoded = HTTPService:JSONDecode(data)
	end
	
	for day, data in pairs(DailyRewardsDico) do
		local f = Instance.new("Folder", days)
		f.Name = day
		
		local d = Instance.new("BoolValue", f)
		d.Name = "Claimed"
		
		local r = Instance.new("NumberValue", f)
		r.Name = "QuantityValue"
		r.Value = data.Quantity
		
		local t = Instance.new("StringValue", f)
		t.Name = "TypeValue"
		t.Value = data.RewardType

		local i = Instance.new("StringValue", f)
		i.Name = "BackgroundValue"
		i.Value = data.Image
		
		if data_decoded then
			d.Value = data_decoded[day]
		else
			d.Value = data.Claimed
		end
	end
end

--[[
	This method allows you to check where the player is in the process of collecting the Daily Reward
	of the Daily Reward. It checks and defines the reward to be collected. It calculates if the player
	can collect his reward or not according to the time spent.
]]
function DailyReward.CheckDailyRewardStatus(player)
	--To check if this is the first time the player has collected his rewards
	local firstTime = false
	local WaitTimerReward = player:WaitForChild("WaitTimerReward")

	if not savedTimeReward[player.UserId] then
		firstTime = true
	end

	if savedTimeReward[player.UserId] then
		local dayActual = player:FindFirstChild("DayActual")
		
		local days = player.Days:GetChildren()
		for i=1, #days do
			local day = player.Days:FindFirstChild("Day"..i)
			if day["Claimed"].Value then
				dayActual.Value = day.Name
			end
		end
		
		if (os.time() - savedTimeReward[player.UserId])/3600 >= TIME_REWARD then
			--PEUT RECUP LA RECOMPENSE

			-- Set good next day can collect
			for i=1, #days do
				local day = player.Days:FindFirstChild("Day"..i)
				if not day["Claimed"].Value then
					dayActual.Value = day.Name
					break
				end
			end

			-- Set value wait timer
			WaitTimerReward.Value = 0
			DailyRewardEvent.ClaimDailyReward:FireClient(player)
		end
	elseif firstTime then
		firstTime = false
		
		--PEUT RECUPER LA RECOMPENSE
		WaitTimerReward.Value = 0
		DailyRewardEvent.ClaimDailyReward:FireClient(player)
	end
end

--[[
	This method saves player data, whether it be rewards or time
	when he recovers his reward in order to use them and to initialize correctly the interfaces and
	data when the player reconnects to the game.
]]
function DailyReward.Save(player)
	local key = player.UserId

	local data = {}
	for _, d in pairs(player.Days:GetChildren()) do
		data[d.Name] = d["Claimed"].Value
	end
	local data_encoded = HTTPService:JSONEncode(data)

	savedTimeReward[player.UserId] = os.time()

	local success, err = pcall(function()
		ds_days:SetAsync(key, data_encoded)		
		ds_timeReward:SetAsync(key, savedTimeReward[player.UserId])
	end)

	if success then
		print(player.Name.. "'s daily reward save!")
	else
		DailyReward.Save(player)
	end
end

--Player login event to initiate data initialization and check at the player connexion can get or not Daily Reward
game.Players.PlayerAdded:Connect(function(player)
	DailyReward.InitData(player)
	if  not (game.PlaceId == EnvironmentModule.GetPlaceId("MainPlace")) then
		return
	end
	DailyReward.CheckDailyRewardStatus(player)
	DailyRewardEvent.UpdateUI:FireClient(player)
end)

--[[
	Event listener that is triggered when the client wants to collect the reward.
	This method will first check if the client can recover the reward or not
	by checking if the reward to be retrieved is already retrieved or not and that the time has expired.
	Then, if the checks are good, the server rewards the player by giving him the amount
	defined by the reward, saves the data and starts the timer by sending back the information
	necessary to the client to display the right information on its side.
]]
DailyRewardEvent.ClickOnClaimReward.OnServerEvent:Connect(function(player)
	local reward = player.Days:FindFirstChild(player.DayActual.Value)	
	if not reward.Claimed.Value and player.WaitTimerReward.Value <= 0 then
		reward.Claimed.Value = true

		local rewardDico = DailyRewardsDico[reward.Name]
		if rewardDico.RewardType == RewardType.Ecu then
			PlayerDataModule:Increment(player, rewardDico.Quantity, "Ecus")

		elseif rewardDico.RewardType == RewardType.Feez then
			PlayerDataModule:Increment(player, rewardDico.Quantity, "Feez")
		end	

		player.WaitTimerReward.Value = (TIME_REWARD * 3600)
		DailyReward.Save(player)
		DailyRewardEvent.UpdateUI:FireClient(player)
		DailyReward.CheckDailyRewardStatus(player)
	end
end)

--[[
	Event listener that allows the client to check the elapsed time for the next reward.
]]
DailyRewardEvent.GiveTimerReward.OnServerEvent:Connect(function(player)
	pcall(function()
		player.WaitTimerReward.Value = (TIME_REWARD * 3600) - (os.time()-savedTimeReward[player.UserId])
		DailyRewardEvent.UpdateUI:FireClient(player)
	end)
end)

return DailyReward
