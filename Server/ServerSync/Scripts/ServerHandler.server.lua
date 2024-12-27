for _, module in pairs(game:GetService("ServerScriptService").ServerSync.Modules:GetChildren()) do
	local loadMod = coroutine.create(function()
		require(module)
	end)

	coroutine.resume(loadMod)
end

--test synchro
local isReserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
print("IS RESERVED SERVER ?", isReserved)

local CmdrFolder = game.ServerScriptService.ServerSync.Scripts.Cmdr
local Cmdr = require(game.ServerScriptService.ServerSync.Cmdr)
Cmdr:RegisterCommandsIn(CmdrFolder.Commands)
Cmdr:RegisterHooksIn(CmdrFolder.Hooks)