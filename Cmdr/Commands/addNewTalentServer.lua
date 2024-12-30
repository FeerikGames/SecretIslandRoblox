local TalentsGeneratorModule = nil

return function (context, talentName)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

 	if TalentsGeneratorModule == nil then
		TalentsGeneratorModule = _G.require("TalentsGeneratorModule")
	end

    local Creature = workspace.CreaturesFolder:FindFirstChild("Creature_"..executor.Name)
    if not Creature then
        return ("Fail adding talent! No Supra found for exectuor!")
    end
	TalentsGeneratorModule.GenerateNewTalent(executor, Creature.CreatureID.Value, talentName)

	return ("Successfully adding talent "..talentName.." to actual Supra!")
end