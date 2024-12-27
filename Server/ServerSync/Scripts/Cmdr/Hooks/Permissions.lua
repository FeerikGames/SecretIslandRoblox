return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		if context.Group == "Owner" and context.Executor:GetRankInGroup(12349377) < 255 then
			return "You don't have permission to run this command"
		end

		if context.Group == "SuperAdmin" and context.Executor:GetRankInGroup(12349377) < 254 then
			return "You don't have permission to run this command"
		end

		if context.Group == "Admin" and context.Executor:GetRankInGroup(12349377) < 128 then
			return "You don't have permission to run this command"
		end
	end)
end