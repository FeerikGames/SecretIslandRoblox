return function (context, playerName, resetCurrency)

	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end
 	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

	--Make new reset data with name of player give in parameter (with that, a admin can reset player data of some players of game)
	local PlayerDataModule = require("PlayerDataModule")
	local PlayingRewardModule = require("PlayingRewardModule")
	local DailyReward = require("DailyReward")
	local AuctionHouseDataModule = require("AuctionHouseDataModule")
	local RaceDataModule = require("RaceDataModule")
	local MapsManagerModule = require("MapsManagerModule")
	local TutorialModule = require("TutorialModule")
	local FarmingHandler = require("FarmingHandler")

	local playerID
	local success

	if resetCurrency == nil then
		resetCurrency = true
	end

	if not playerName then
		playerID = context.Executor.UserId
		success = true
	else
		success = pcall(function()
			playerID = game.Players:GetUserIdFromNameAsync(playerName)
		end)
	end

	if success then
		-- Reset entier player data from all Datastore of game
		AuctionHouseDataModule.ResetPlayer(playerID)
		PlayingRewardModule.ResetPlayer(playerID)
		DailyReward.ResetPlayer(playerID)
		TutorialModule.ResetPlayer(playerID)
		RaceDataModule.ResetPlayer(playerID)
		MapsManagerModule.ResetPlayer(playerID)
		PlayerDataModule:ResetData(playerID, resetCurrency)
		FarmingHandler.WasResetPlayer = true
	
		--wait to see this message in console commandbar before to restart game after reset data to make sur all is fine (player can reset her data because cache are clean too)
		return "DATA RESET DONE"
	end

	return "Done"
end