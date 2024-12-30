return function (context, type, isPretty)
	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
    local HorsesDataModule =  require("HorsesDataModule")
	local PlayerDataModule = require("PlayerDataModule")

	if not HorsesDataModule.CreatureType[type] then
		return "Type of Animals need to be Cat or Horse !"
	end

	-- Check if player have slots available
	local slotsAvailables, nbMaxSlotsAvailables, nbCreatures = PlayerDataModule:CheckCreaturesCollectionSlotsAreAvailables(executor, true)
	if not slotsAvailables then
		return ("You don't have availables slots in your Animals collections...")
	end

	if isPretty then
		local result = HorsesDataModule.CreatePrettyAnimal(executor, HorsesDataModule.CreatureType[type])
		if not result then
			return ("Don't found Pretty "..type.." Animals are founds, try another type.")
		end
	else
		HorsesDataModule.CreateHorseDataForTest(executor, HorsesDataModule.CreatureType[type])
	end


	return ("Successfully create "..type.." animals !")
end