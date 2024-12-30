local PlayerDataModule = nil

return function (context, typeOfCrystal, quantity)
	local executor:Player = context.Executor
	
	if executor:GetRankInGroup(12349377) < 128 then
		return "You don't have permission to run this command"
	end

	if quantity < 0 then
		return "Quantity to increment need minimum 1"
	end

 	if PlayerDataModule == nil then
		PlayerDataModule = _G.require("PlayerDataModule")
	end

    -- Format string of type parameter to have a good value for database
    typeOfCrystal = (string.sub(typeOfCrystal, 1, 1)):upper()..string.sub(typeOfCrystal, 2, -1):lower()

    if typeOfCrystal == "All" then
        local GameDataModule = _G.require("GameDataModule")
        for _, v in pairs(GameDataModule.AnimalsRacesList) do
            -- Check if type of crystal needed exist
            local success, error = pcall(function()
                PlayerDataModule:Get(executor, "Crystals."..v.."Crystal")
            end)
            if success then
                PlayerDataModule:Increment(context.Executor, quantity, "Crystals."..v.."Crystal")
            end
        end

        return ("Successfully increment player's All Crystals by "..quantity.." !")
    else
        -- Check if type of crystal needed exist
        local success, error = pcall(function()
            PlayerDataModule:Get(executor, "Crystals."..typeOfCrystal.."Crystal")
        end)
        if success then
            PlayerDataModule:Increment(context.Executor, quantity, "Crystals."..typeOfCrystal.."Crystal")
            return ("Successfully increment player's "..typeOfCrystal.." Crystal by "..quantity.." !")
        end
    end


    return ("Error with Type Of Crystal give, not exist.")
end