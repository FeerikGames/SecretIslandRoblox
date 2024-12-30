
return function (context, quantity)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

	if quantity < 0 then
		return "Quantity to increment need minimum 1"
	end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
    local CreatureEvolutionModule = require("CreatureEvolutionModule")

    local exist = workspace:WaitForChild("CreaturesFolder"):FindFirstChild("Creature_"..executor.Name)
    if exist then
        CreatureEvolutionModule.GiveNbEXP(executor, exist.CreatureID.Value, quantity)
    else
        return ("Not summoned Animals can't give EXP")
    end

    return ("Give "..quantity.." EXP Successfull")
end