return function (context)
	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
    local HorsesDataModule =  require("HorsesDataModule")
	local PlayerDataModule = require("PlayerDataModule")

	-- Check if player have slots available
	local slotsAvailables, nbMaxSlotsAvailables, nbCreatures = PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(executor, true)
	if not slotsAvailables then
		return ("You don't have availables slots in your Animals collections...")
	end

	local result = HorsesDataModule.CreatePrettyAnimal(executor, "", true)
    if not result then
        return ("Don't found your Custom Supra. Maybe you don't have any Custom Supra link to your ID!")
    end

	return ("Successfully obtains your Custom SUPRA!!")
end