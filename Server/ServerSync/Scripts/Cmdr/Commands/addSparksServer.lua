local PlayerDataModule = nil

return function (context, sparks)
	local executor:Player = context.Executor

	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

	if sparks < 0 then
		return "Sparks to increment need minimum 1"
	end

 	if PlayerDataModule == nil then
		PlayerDataModule = _G.require("PlayerDataModule")
	end

	PlayerDataModule:Increment(context.Executor, sparks, "Sparks")

	return ("Successfully increment player's "..sparks.." Sparks!")
end