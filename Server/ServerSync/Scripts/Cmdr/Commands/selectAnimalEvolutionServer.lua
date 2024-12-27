
return function (context, evolutionSelected)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

    -- Formatt parameter evolution Selected
    evolutionSelected = string.lower(evolutionSelected)
    evolutionSelected = string.upper(string.sub(evolutionSelected, 1, 1))..string.sub(evolutionSelected, 2, -1)

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
    local CreatureEvolutionModule = require("CreatureEvolutionModule")
    local GameDataModule = require("GameDataModule")

    -- Check if evolution selected exist
    if not table.find(GameDataModule.AnimalsRacesList, evolutionSelected) then
        return("Evolution selected not exist, try again ...")
    end

    local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..executor.Name)
    if exist then
        CreatureEvolutionModule.EvolveCreatureCommandeLine(executor, exist.CreatureID.Value, evolutionSelected)
    else
        return ("Not summoned Animals can't cahnge evolution")
    end

    return ("Evolution into "..evolutionSelected.." Successfull")
end