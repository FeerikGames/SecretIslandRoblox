local PlayerDataModule = nil

return function (context, harvest)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

 	if PlayerDataModule == nil then
		PlayerDataModule = _G.require("PlayerDataModule")
	end

	PlayerDataModule:Increment(context.Executor, harvest, "TotalHarvests")

	return ("Successfully increment player's harvest of "..harvest.." !")
end