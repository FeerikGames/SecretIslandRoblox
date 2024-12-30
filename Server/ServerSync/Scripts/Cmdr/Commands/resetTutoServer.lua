return function (context, playerName, resetCurrency)

	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end
 	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

	--Make new reset data with name of player give in parameter (with that, a admin can reset player data of some players of game)
	local TutorialModule = require("TutorialModule")

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
		-- Reset tutorial player data
		TutorialModule.ResetPlayer(playerID)
        
		--wait to see this message in console commandbar before to restart game after reset data to make sur all is fine (player can reset her data because cache are clean too)
		return "TUTO DATA RESET DONE"
	end

	return "Done"
end