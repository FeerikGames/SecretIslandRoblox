local WorldTeleportationModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local RemoteEvent:Folder = ReplicatedStorage.SharedSync.RemoteEvent
local BindableEvent:Folder = ReplicatedStorage.SharedSync.BindableEvent
local RemoteFunction:Folder = ReplicatedStorage.SharedSync.RemoteFunction
local BindableFunction:Folder = ReplicatedStorage.SharedSync.BindableFunction

local PlayerDataModule = require("PlayerDataModule")
local ToolsModule = require("ToolsModule")
local TeleportModule = require("TeleportModule")
local GameDataModule = require("GameDataModule")
local EnvironmentModule = require("EnvironmentModule")

-- RemoteFunction
local PurchaseWorldTeleport:RemoteFunction = Instance.new("RemoteFunction", RemoteFunction)
PurchaseWorldTeleport.Name = "PurchaseWorldTeleport"
local SetGamepassTeleport:RemoteFunction = Instance.new("RemoteFunction", RemoteFunction)
SetGamepassTeleport.Name = "SetGamepassTeleport"

-- RemoteEvent
local ValidPurchaseWorldTeleport:RemoteEvent = Instance.new("RemoteEvent", RemoteEvent)
ValidPurchaseWorldTeleport.Name = "ValidPurchaseWorldTeleport"

local LocalTeleport = game.Workspace:FindFirstChild("LocalTeleport") or Instance.new("Folder", workspace)
LocalTeleport.Name = "LocalTeleport"

--[[
	Function to check and init data of player if have purchase Teleport Gamepass. It call by remote function when client side make
	init data of teleport gui.
]]
local function SetPlayerGamepassTeleport(player)
	if BindableFunction.CheckPlayerHasGamepass:Invoke(player, GameDataModule.Gamepasses.AllTeleportation.ProductID) then
		local WorldTeleportUnlocked = PlayerDataModule:Get(player, "WorldTeleportUnlocked")

		for _, area in pairs(LocalTeleport:GetChildren()) do
			if area:IsA("Folder") then
				for _, spawn in pairs(area:GetChildren()) do
					if not table.find(WorldTeleportUnlocked, spawn.Name) then
						table.insert(WorldTeleportUnlocked, spawn.Name)
					end
				end
			end
		end

		PlayerDataModule:Set(player, WorldTeleportUnlocked, "WorldTeleportUnlocked")
	end
end

--[[
    
]]
local function CallbackTeleport(player, spawnPlaceID:number, spawnName:string)
    player:SetAttribute("Teleporting", true)
    local teleportOptions = Instance.new("TeleportOptions")
    local teleportData = {
        mapId = spawnPlaceID,
        mapName = spawnName
    }
    teleportOptions:SetTeleportData(teleportData)
    -- Teleport the player to private server (true = private, false = not private server)
    TeleportModule.teleportWithRetry(spawnPlaceID, {player}, true, false, teleportOptions)
end

-- Remote function call for check and valid by server to unlock a world teleport selected by player
PurchaseWorldTeleport.OnServerInvoke = function(player, areaName, spawnName)
    local areaServerSide = LocalTeleport[areaName]
	local spawnServerSide = areaServerSide[spawnName]
	if spawnServerSide then
		-- Spawn founded on Server Side, check value and make purchase for player call it
		local price:number = spawnServerSide:GetAttribute("Price")
        local currencyType:string = spawnServerSide:GetAttribute("CurrencyType")

		local function Callback(player)
			local result = PlayerDataModule:Decrement(player, price, string.match(currencyType, "Crystal") and "Crystals."..currencyType or currencyType)
			if result then
				local WorldTeleportUnlocked = PlayerDataModule:Get(player, "WorldTeleportUnlocked")
				table.insert(WorldTeleportUnlocked, spawnName)
				PlayerDataModule:Set(player, WorldTeleportUnlocked, "WorldTeleportUnlocked")
                ValidPurchaseWorldTeleport:FireClient(player, areaServerSide)
			else
				warn("Error during purchase spawn "..spawnName.." !")
				BindableEvent.ShowPopupAlert:Fire(
					player,
					"Fail Unlock",
					"You don't have enough "..currencyType.." ...",
					ToolsModule.AlertPriority.Annoucement,
					nil,
					ToolsModule.AlertTypeButton.OK
				)
			end
		end

        player.PlayerGui.StarterGuiSync.WorldTeleportationGui.Background.Visible = false

		BindableEvent.ShowPopupAlert:Fire(
			player,
			"Unlock ?",
			"Are you sure you want to buy Spawn: "..spawnServerSide:GetAttribute("DisplayName").." of Area "..areaServerSide:GetAttribute("DisplayName").." for "..ToolsModule.DotNumber(price).." "..currencyType.." ?",
			ToolsModule.AlertPriority.Annoucement,
			ToolsModule.AlertTypeButton.NO,
			ToolsModule.AlertTypeButton.YES,
			nil,nil,
			Callback,
			{player}
		)
	else
		warn("Spawn "..spawnName.." not found on Server Side !")
	end
end

RemoteEvent.TeleportEvent.OnServerEvent:Connect(function(player, isOk, areaName, spawnName)
    local areaServerSide = LocalTeleport[areaName]
	local spawnServerSide = areaServerSide[spawnName]
	if spawnServerSide and isOk then
        if player and not player:GetAttribute("Teleporting") then
            BindableEvent.ShowPopupAlert:Fire(
				player,
				"Teleport",
				"Would you like to join "..spawnServerSide:GetAttribute("DisplayName").."?",
				ToolsModule.AlertPriority.Annoucement,
				ToolsModule.AlertTypeButton.NO,
				ToolsModule.AlertTypeButton.YES,
				nil,nil,
				CallbackTeleport,{EnvironmentModule.GetPlaceId(spawnServerSide:GetAttribute("PlaceIDName")), spawnServerSide.Name}
			)
        end
    end
end)

SetGamepassTeleport.OnServerInvoke = SetPlayerGamepassTeleport

return WorldTeleportationModule