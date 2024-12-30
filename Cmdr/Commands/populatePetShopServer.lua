return function (context, CreatureType, HowMany, ModelID, Remove)

	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end
 	
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

	local AuctionHouseDataModule = require("AuctionHouseDataModule")

    if Remove then
        AuctionHouseDataModule.DeleteCreatureForAuctionHouse(HowMany, Remove=="RemoveAll")
    else
        for i = 1, HowMany, 1 do
            if not ModelID then
                ModelID = ""
            end
            AuctionHouseDataModule.CreateCreatureForAuctionHouse(CreatureType, ModelID)
            task.wait(.5)
        end
    end

	return "Done"
end