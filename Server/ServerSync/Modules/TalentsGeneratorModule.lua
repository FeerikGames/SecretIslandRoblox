local TalentsGeneratorModule = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction = ReplicatedStorage.SharedSync.BindableFunction

local PlayerDataModule = require("PlayerDataModule")
local GameDataModule = require("GameDataModule")
local RarityDataModule = require("RarityDataModule")
local ToolsModule = require("ToolsModule")
local CreaturesTalentsModule = require("CreaturesTalentsModule")

-- Remote function call for check and valid by server to unlock system of game
RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature.OnServerEvent:Connect(function(player, creatureID)
    local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
    if CreatureData then
        local talents = CreatureData.Talents
		-- Check if creature have maximum limit of talent
		if ToolsModule.LengthOfDic(talents) >= 4 then
			warn("This creature have already maximum number of talents, can't generate another")
			RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature:FireClient(player, false)
			return
		end

		-- Check if player have all currency to payout
		local canPayout = true
		for costType, value in pairs(GameDataModule.TalentsGeneratorCost[ToolsModule.LengthOfDic(talents)+1]) do
			local playerActualValue = PlayerDataModule:Get(player, string.match(costType, "Crystal") and "Crystals."..costType or costType)
			canPayout = value <= playerActualValue
		end

		-- If player have all currency to pay
		if canPayout then
			-- Decrement player for all currency value of cost operation generate talent
			for costType, value in pairs(GameDataModule.TalentsGeneratorCost[ToolsModule.LengthOfDic(talents)+1]) do
				PlayerDataModule:Decrement(player, value, string.match(costType, "Crystal") and "Crystals."..costType or costType)
			end

			-- Calculate and check if player success to obtain new talent
			local rateSuccess = GameDataModule.TalentsGeneratorLuckSuccess[ToolsModule.LengthOfDic(talents)+1]
			local random = math.random(0,100)
			if random <= rateSuccess then
				-- Generate new random talent
				local newTalent = RarityDataModule.GetRandomTalent(nil,nil, true, CreatureData.Talents)
				for id, value in pairs(newTalent) do
					CreatureData.Talents[id] = value
				end

				-- Save data of creature
				PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)

				RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature:FireClient(player, true, newTalent)
				warn("SUCCESS GENERATE TALENT RANDOM WIN")
			else
				warn("FAIL GENERATE TALENT")
				RemoteEvent.TalentsGeneratorSystem.TryGenerateNewTalentCreature:FireClient(player, false)
			end
		end
    end
end)

-- Remote event for change value of talent player creature randomly
RemoteEvent.TalentsGeneratorSystem.UpgradeTalentCreature.OnServerEvent:Connect(function(player, creatureID, talentID)
	local CreatureData = PlayerDataModule:Get(player, "CreaturesCollection."..creatureID)
    if CreatureData then
        local lastvalue = CreatureData.Talents[talentID]

		-- Check if player have all currency to payout
		local canPayout = true
		for costType, value in pairs(CreaturesTalentsModule.TalentsTable[talentID].UpgradeCost) do
			local playerActualValue = PlayerDataModule:Get(player, string.match(costType, "Crystal") and "Crystals."..costType or costType)
			canPayout = value <= playerActualValue
		end

		-- If player have all currency to pay
		if canPayout then
			-- Decrement player for all currency value of cost operation generate talent
			for costType, value in pairs(CreaturesTalentsModule.TalentsTable[talentID].UpgradeCost) do
				PlayerDataModule:Decrement(player, value, string.match(costType, "Crystal") and "Crystals."..costType or costType)
			end

			-- Calculate new random value for talent selected
			local newValue = RarityDataModule.GetRandomValueOfTalent(talentID)
			if newValue then
				CreatureData.Talents[talentID] = newValue
				
				-- Save data of creature
				PlayerDataModule:Set(player, CreatureData, "CreaturesCollection."..creatureID)
	
				RemoteEvent.TalentsGeneratorSystem.UpgradeTalentCreature:FireClient(player, talentID, newValue, lastvalue)
				warn("SUCCESS RANDOM UPDATE TALENT VALUE")
			end
		end
    end
end)

RemoteEvent.TalentsGeneratorSystem.ActivateSystem.OnServerEvent:Connect(function(player)
	RemoteEvent.TalentsGeneratorSystem.ActivateSystem:FireClient(player)
end)

return TalentsGeneratorModule