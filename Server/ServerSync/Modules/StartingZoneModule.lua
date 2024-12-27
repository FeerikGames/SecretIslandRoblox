local StartingZoneModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")

local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local ToolsModule = require("ToolsModule")
local EnvironmentModule = require("EnvironmentModule")

local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")

local Assets = ReplicatedStorage.SharedSync.Assets

local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_ZoneUiState = RemoteEventFolder:WaitForChild("ZoneUiState")
local RE_ZoneUiWaiting = RemoteEventFolder.ZoneUiWaiting
local RE_ActivateGame = RemoteEventFolder.ActivateGame

local remoteFunctionFolder = ReplicatedStorage.SharedSync.RemoteFunction
local RF_ZoneChoice = remoteFunctionFolder.ZoneChoice

-- Properties
local LightRayStudsDistance = 1
local CompabilityTable = {
	
}

local playerIsInGame = {}

function StartingZoneModule:ActivateGame(player, GameData, Active)
	RE_ActivateGame:FireClient(player, GameData, Active)
end

-- Active the game start part to the passed player (will show the panels, start part, and add player to allowed players)
function StartingZoneModule:ActiveGameStartPartToPlayer(player, GameData, Active)
	RE_ActivateGame:FireClient(player, GameData, Active)

	if not Active then
		local playerValue = GameData.Model.Allowed:FindFirstChild(player.UserId)
		if playerValue then
			playerValue:Destroy()
		end
	else
		local playerValue = GameData.Model.Allowed:FindFirstChild(player.UserId)
		if not playerValue then
			playerValue = Instance.new("BoolValue", GameData.Model.Allowed)
			playerValue.Value = true
			playerValue.Name = player.UserId
		end
	end
end

--[[ 
	Setup behavior of button for mini game or race. Search button part and init a clickdetector instance.
	If system need to activate are already active, disable it and play action of exit player.
	If system are not active, we active it and launch first time function enter in system event.
		This launch are make because when player click system appear but already in zone of mini game or race so we launch function for auto enter in game when activate button if player is in zone when activate it
]]
function StartingZoneModule.SetupButtonBehavior(GameData, StartFunction, SoloFunction)
	local button = GameData.Model:FindFirstChild("Button", true)

	-- If not found button not make setup of it
	if not button then
		return
	end

	local clickDetector = Instance.new("ClickDetector", button)
	clickDetector.MaxActivationDistance = 50
	
	clickDetector.MouseClick:Connect(function(playerWhoClicked)
		-- Check if player are already register in activation mini game
		local playerValue = GameData.Model.Allowed:FindFirstChild(playerWhoClicked.UserId)

		-- If register and click disable mini game, else activate mini game
		if playerValue then
			StartingZoneModule:ActiveGameStartPartToPlayer(playerWhoClicked, GameData, false)
			if GameData.GameName ~= "Race" then
				StartingZoneModule.PlayerExitZone(playerWhoClicked.Character.PrimaryPart, GameData, GameData.GameName)
			end
		else
			StartingZoneModule:ActiveGameStartPartToPlayer(playerWhoClicked, GameData, true)
			if GameData.GameName ~= "Race" then
				StartingZoneModule.SetDataAccordingToConditionsAndLaunchGame(playerWhoClicked.Character.PrimaryPart, GameData, GameData.GameName, StartFunction, SoloFunction)
			end
		end
	end)
end

-- Get the player and the creature from the player's rootpart or Creature Part (primarypart)
-- Called by : InitStartPartDetection when entering start part
local function GetPlayerAndCreatureFromPartTouched(PartTouched)
	local player, creature
	local ModelTouched = PartTouched:FindFirstAncestorWhichIsA("Model")
	-- get model out of part
	if ModelTouched == workspace or PartTouched ~= ModelTouched.PrimaryPart then
		return
	end
	local PlayerTouched = PlayerService:GetPlayerFromCharacter(ModelTouched)
	local isCreatureTouched = ModelTouched:FindFirstAncestor("CreaturesFolder")
	-- get player or creature from model
	if not PlayerTouched and not isCreatureTouched then
		return
	end
	player = PlayerTouched
	-- if had the player or the creature apply the other then return them
	if isCreatureTouched then
		creature = ModelTouched
		player = creature.Seat.Rider.Value
	else
		local playerCreature = CreaturesFolder:FindFirstChild("Creature_"..PlayerTouched.Name)
		if not playerCreature or not playerCreature.Seat or not playerCreature.Seat:FindFirstChild("Rider") then
			return player
		end
		local Rider = playerCreature.Seat.Rider.Value
		if not Rider then
			return player
		end
		creature = playerCreature
	end
	return player, creature
end

-- Send Remote Function on player to choose between a solo and multi race then return the result and apply the playerIsInRace value accordingly
-- Called by : InitStartPartDetection when entering start part
local function ChooseSoloMultiplayer(GameData, Player, Index, SoloFunction)
	playerIsInGame[Player] = {
		gameName = "Choosing"..Index,
		gameType = GameData.GameType,
	}
	-- Remote function waiting for player to choose btwn solo/multi
	local isSolo = RF_ZoneChoice:InvokeClient(Player, GameData.Model.Name)--change it

	-- depending on the answer set the PlayerIsInRace data and return or launch solo race with solo function
	if playerIsInGame[Player] == nil then
		GameData.Players[Player] = nil
		return false
	end
	if isSolo == "abort" then
		playerIsInGame[Player] = nil
		GameData.Players[Player] = nil
		return false
	end
	if isSolo then
		playerIsInGame[Player] = {
			gameName = "Solo"..Index,
			gameType = GameData.GameType,
		}
		SoloFunction(GameData, Player)
		return false
	else
		playerIsInGame[Player] = {
			gameName = Index,
			gameType = GameData.GameType,
		}
		return true
	end
end

-- Set the player's participant value in the Participants folder in the race model to displaya and get info on the local side
-- Called by : InitStartPartDetection when entering start part and player choosed multi.
local function SetRaceParticipantValue(GameData, Player, creature)
	local playerValue = Instance.new("ObjectValue", GameData.Model.participants)
	playerValue.Value = Player
	playerValue.Name = Player.Name
	local CreatureValue = Instance.new("ObjectValue", playerValue)
	CreatureValue.Value = creature
	CreatureValue.Name = "Creature"
end

local function HideCountingUi(GameData)
	for competitor, competitorInfo in pairs(GameData.Players) do
		RE_ZoneUiState:FireClient(competitorInfo.player, GameData, "DoneCounting")
	end
end


local function WaitingForMorePlayers(GameData)
	GameData.WaitingForMorePlayers = true
	GameData.WaitForOthersCountDown = GameData.WaitForOthersTimeInSec
	while GameData.WaitForOthersCountDown > 0 do
		-- if players are less than needed then return and deactivate waitingForMorePlayers
		if ToolsModule.LengthOfDic(GameData.Players) < GameData.playerNeeded then
			GameData.WaitingForMorePlayers = false
			return
		end
		for competitor, competitorInfo in pairs(GameData.Players) do
			-- waiting for more players Ui
			RE_ZoneUiState:FireClient(competitorInfo.player, GameData, "WaitingForMorePlayers", GameData.WaitForOthersCountDown)
		end
		GameData.WaitForOthersCountDown -= 1
		task.wait(1)
	end
	GameData.WaitingForMorePlayers = false
end


local function MakeLightRay(GameData)
	local Button = GameData.Model:FindFirstChild("Button", true)
	if not Button then
		return
	end
	local lightRay = Assets.LightRay:Clone()
	local primaryPart = GameData.Model.PrimaryPart
	lightRay.Parent = primaryPart
	lightRay.Size += Vector3.new(0,-25,-25)
	lightRay.Position = Button.Position + Vector3.new(0, lightRay.Size.X/2 + Button.Size.Y/2 + LightRayStudsDistance,0)
	lightRay.Transparency = 1
	return lightRay
end

--  Shows this race's light ray and apply the color phase to it.
-- Arguments : race's data with model, phase of race : 1 = waiting needed players, 2 = waiting for more players, 3 = event waiting.
function StartingZoneModule:ShowLightRay(GameData, phase)
	local lightRay = GameData.Model.PrimaryPart:FindFirstChild("LightRay")
	if not lightRay then
		lightRay = MakeLightRay(GameData)
	end
	if lightRay then
		lightRay.Transparency = 0
		if phase == 1 then
			lightRay.Color = Color3.fromRGB(255,255,0)
		elseif phase == 2 then
			lightRay.Color = Color3.fromRGB(255, 72, 0)
		elseif phase == 3 then
			lightRay.Color = Color3.fromRGB(23, 189, 255)
		end
	end
end

function StartingZoneModule:HideLightRay(GameData)
	local lightRay = GameData.Model.PrimaryPart:FindFirstChild("LightRay")
	if not lightRay then
		lightRay = MakeLightRay(GameData)
	end
	if lightRay then
		lightRay.Transparency = 1
	end
end

-- Send remote event to show waiting for Game to end uis.
-- Called by : InitStartPartDetection when entering start part during ongiong race
local function ShowUiToPlayersWaitingForGameEnd(GameData, player)
	RE_ZoneUiWaiting:FireClient(player, GameData.Model.Name, true)
end


local function ResetDataAndUiAndLightRay(player, GameData)
	-- UI
	RE_ZoneUiState:FireClient(player, GameData, "DoneCounting")
	RE_ZoneUiState:FireClient(player, GameData, "Out")
	RE_ZoneUiWaiting:FireClient(player, GameData.Model.Name, false)
	-- Data
	GameData.Players[player.UserId] = nil
	local playerCount = ToolsModule.LengthOfDic(GameData.Players)
	GameData.Model:SetAttribute("playerNum", playerCount)
	local participantValue = GameData.Model.participants:FindFirstChild(player.Name)
	if participantValue then
		participantValue:Destroy()
	end
	-- Light Ray
	if playerCount <= 0 and not GameData.isEventRunning then
		StartingZoneModule:HideLightRay(GameData)
	elseif playerCount < GameData.playerNeeded and not GameData.isEventRunning then
		StartingZoneModule:ShowLightRay(GameData, 1)
	end
end

-- When a player enter the Zone
function StartingZoneModule.SetDataAccordingToConditionsAndLaunchGame(PartTouched, GameData, Index, StartFunction, SoloFunction)
	local player, creature = GetPlayerAndCreatureFromPartTouched(PartTouched)
	-- if the player is not in a creature or is not a player at all = return
	if not player or not creature then
		return
	end

	local isPlayerAllowed = game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") and true or (GameData.Model.Allowed:FindFirstChild(player.UserId) ~= nil)
	-- if the player is in the game and it's Ongoing or if the player is in another game = return
	if GameData.Ongoing and GameData.Players[player.UserId] or playerIsInGame[player] or not isPlayerAllowed and not GameData.isEventRunning then
		return
	end

	if GameData.Ongoing then
		-- Only if Tag mini game are OnGoing a player can join the party game
		if GameData.GameName == "Tag" then
			playerIsInGame[player] = {
				gameName = Index,
				gameType = GameData.GameType,
			}
			
			-- Setup player data for mini game
			GameData.Players[player.UserId] = {
				creature = creature,
				player = player,
			}

			-- Set up player to participant of mini game
			SetRaceParticipantValue(GameData, player, creature)
			local playerCount = ToolsModule.LengthOfDic(GameData.Players)
			GameData.Model:SetAttribute("playerNum", playerCount)

			-- Start game for player want to join current game
			StartFunction(GameData, {GameData.Players[player.UserId]})
		else
			-- Setup player to waiting folder for launch autmatique in the next game when available
			local playerValue = Instance.new("ObjectValue", GameData.Model.waiting)
			playerValue.Value = player
			playerValue.Name = player.Name

			-- if the game is already started display a waiting screen to the player
			ShowUiToPlayersWaitingForGameEnd(GameData, player)
		end
		return
	end

	if SoloFunction then
		-- if the solofunction (callback function to launch game on solo) is passed then display choice
		local isMulti = ChooseSoloMultiplayer(GameData, player, Index, SoloFunction)
		if not isMulti then
			return
		end
	else
		-- if there's no solo function then just setup the playerIsInGame data
		playerIsInGame[player] = {
			gameName = Index,
			gameType = GameData.GameType,
		}
	end

	if GameData.WaitingForMorePlayers then
		-- if the game is waiting for more players reset its countdown to its maximum
		GameData.WaitForOthersCountDown = GameData.WaitForOthersTimeInSec
	end

	RE_ZoneUiWaiting:FireClient(player, GameData.Model.Name, false)

	-- set player data (will be returned to the start function for it to setup its playerdata)
	GameData.Players[player.UserId] = {
		creature = creature,
		player = player,
	}
	
	-- participant value and playercount setup to replicate to the client the players waiting or ingame to display them
	SetRaceParticipantValue(GameData, player, creature)
	local playerCount = ToolsModule.LengthOfDic(GameData.Players)
	GameData.Model:SetAttribute("playerNum", playerCount)

	-- Remove player from waiting list if exist in
	if GameData.Model:FindFirstChild("waiting") then
		local exist = GameData.Model.waiting:FindFirstChild(player.Name)
		if exist then
			exist:Destroy()
		end
	end

	if GameData.WaitingForMorePlayers or GameData.isEventRunning then
		-- if waiting for more players or isEvent then return (because the start and the setup of the game is made by the last needed player or the event)
		warn("Event is running / waiting more player")
		return
	end

	if playerCount < GameData.playerNeeded then
		-- if not enough player : show lightray and display player list and waiting panel
		StartingZoneModule:ShowLightRay(GameData, 1)
		RE_ZoneUiState:FireClient(player, GameData, "Waiting" , nil)
		return
	end

	-- start because all players needed present
	StartingZoneModule:ShowLightRay(GameData, 2)
	-- waiting for mare players to join before launching
	WaitingForMorePlayers(GameData)
	HideCountingUi(GameData)
	
	if ToolsModule.LengthOfDic(GameData.Players) < GameData.playerNeeded then
		-- if players leaved during the waiting for more players
		for competitor, competitorInfo in pairs(GameData.Players) do
			RE_ZoneUiState:FireClient(competitorInfo.player, GameData, "Waiting" , nil)
		end
		return
	end

	-- setup player dictionnary passed to the start function and reset the players of the game. (to allow the game to specificely set the players data)
	local players = ToolsModule.deepCopy(GameData.Players)
	GameData.Players = {}
	StartingZoneModule:HideLightRay(GameData)
	
	-- this will call callback the function passed by the game to start it
	StartFunction(GameData, players)
end

-- When player Exit the Zone delete race data according to the race state
function StartingZoneModule.PlayerExitZone(PartTouched, GameData, Index)
	-- if the player is not in a creature or is not a player at all = return
	local player, creature = GetPlayerAndCreatureFromPartTouched(PartTouched)
	if not player then
		return
	end
	if GameData.Ongoing and GameData.Players[player.UserId] then
		-- if game ongoing = return
		return
	end
	if playerIsInGame[player] and string.match(playerIsInGame[player].gameName, Index) and not string.match(playerIsInGame[player].gameName, "Solo") then
		-- if is in this game but not in a solo one = set playerIsInGame to nil
		playerIsInGame[player] = nil
	end

	-- Player leave zone if in waiting list remove it
	if GameData.Model:FindFirstChild("waiting") then
		local exist = GameData.Model.waiting:FindFirstChild(player.Name)
		if exist then
			exist:Destroy()
		end
	end

	-- Reset datas and ui and light ray
	ResetDataAndUiAndLightRay(player, GameData)
end

-- Init the race in parameters detection of players (set up their race data) and launch the race.
-- Called by : RaceHandle:Init + when set up player race
function StartingZoneModule:InitZoneDetection(Zone, GameData, GameName, StartFunction, SoloFunction)
	StartingZoneModule.SetupButtonBehavior(GameData, StartFunction, SoloFunction)

	-- List of player enter in field race to make good check with magnitude distance
	local playerEnter = {}
	
	-- RunService event to replace Touch event by event where Race check player distance and status enter field or not and make good behavior to call function enter ou exit field depending mangitude position
	RunService.Heartbeat:Connect(function(deltaTime)
		for _, player in pairs(game.Players:GetChildren()) do
			if player.Character then
				if (player.Character.PrimaryPart.Position - Zone.Bounds.Middle.Position).magnitude <= 30 then
					if not table.find(playerEnter, player) then
						table.insert(playerEnter, player)
					end
					StartingZoneModule.SetDataAccordingToConditionsAndLaunchGame(player.Character.PrimaryPart, GameData, GameName, StartFunction, SoloFunction)
				else
					local find = table.find(playerEnter, player)
					if find then
						table.remove(playerEnter, find)
						StartingZoneModule.PlayerExitZone(player.Character.PrimaryPart, GameData, GameName)
					end
				end
			end
		end
	end)
end

function StartingZoneModule:GetPlayerCurrentGame(player)
	return playerIsInGame[player]
end

function StartingZoneModule:EndPlayerCurrentGame(GameData, player)
	playerIsInGame[player] = nil
	if not GameData then
		return
	end
	local participantValue = GameData.Model.participants:FindFirstChild(player.Name)
	if participantValue then
		participantValue:Destroy()
	end
end

return StartingZoneModule