return function (context)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) <= 128 then
		return "You don't have permission to run this command"
	end

	executor.PlayerGui.StarterGuiSync.ShopItemsGui.StockItemsFrame.Visible = true

    return
end