local ClientRaceHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
    return ClientRaceHandler
end

local PlayerService = game:GetService("Players")

local ToolsModule = require("ToolsModule")
local HorseBumpHandler = require("HorseBumpHandler")
local HorseController = require("HorseController")

--Events
local GetRemoteEvent = require("GetRemoteEvent")
local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_ActivateGame = RemoteEventFolder:WaitForChild("ActivateGame")
local RE_RaceSoloState = RemoteEventFolder:WaitForChild("RaceSoloState")
local RE_RaceClearInfo = RemoteEventFolder:WaitForChild("RaceClearInfo")
local RE_RaceBlockCompetitors = RemoteEventFolder:WaitForChild("RaceBlockCompetitors")
local RE_RaceGiveUp = RemoteEventFolder:WaitForChild("RaceGiveUp")
local RaceDataEvent = GetRemoteEvent("RaceDataEvent")

local remoteFunctionFolder = ReplicatedStorage.SharedSync.RemoteFunction


local RunService = game:GetService("RunService")
local RacesFolder = workspace:WaitForChild("Races")
local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")

local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets")
local CheckpointVisualModel = Assets.CheckpointVisual
local RaceFinishVisualModel = Assets.RaceFinish

local Player = PlayerService.LocalPlayer

local CurrentRace = nil
local CurrentCheckpointPart = nil
local CurrentCheckpointConnection = nil

local CheckpointBaseSize = Vector3.new(35, 13.5, 1)

local function MakeCheckpointVisual(CheckPoint, isLastCheckpoint)
	local checkpointVisual
	if isLastCheckpoint then
		checkpointVisual = RaceFinishVisualModel:Clone()
		checkpointVisual.CFrame = CheckPoint.CFrame
	else
		checkpointVisual = CheckpointVisualModel:Clone()
		checkpointVisual:PivotTo(CheckPoint.CFrame)
		local size = CheckPoint.Size.X / CheckpointBaseSize.X
		ToolsModule.ResizeModel(checkpointVisual, size)
	end
	checkpointVisual.Parent = CheckPoint
end

local function MakeCheckpointPart(CheckpointInfo, isLastCheckpoint)
	if CurrentCheckpointPart then
		CurrentCheckpointPart:Destroy()
	end
	CurrentCheckpointPart = Instance.new("Part")
	for Property,Value in pairs(CheckpointInfo.Properties) do
		CurrentCheckpointPart[Property] = Value
	end
	CurrentCheckpointPart.Anchored = true
	CurrentCheckpointPart.CanCollide = false
	CurrentCheckpointPart.CanQuery = false
	CurrentCheckpointPart.Transparency = 1
	MakeCheckpointVisual(CurrentCheckpointPart, isLastCheckpoint)
	return CurrentCheckpointPart
end


local function GetPlayerAndHorseFromPartTouched(PartTouched)
	local player, horse
	local ModelTouched = PartTouched:FindFirstAncestorWhichIsA("Model")
	if ModelTouched == workspace or PartTouched ~= ModelTouched.PrimaryPart then
		return
	end
	local PlayerTouched = PlayerService:GetPlayerFromCharacter(ModelTouched)
	local isHorseTouched = ModelTouched:FindFirstAncestor("CreaturesFolder")
	if not PlayerTouched and not isHorseTouched then
		return
	end
	player = PlayerTouched
	if isHorseTouched then
		horse = ModelTouched
		player = horse.Seat.Rider.Value
	else
		local playerHorse = CreaturesFolder:FindFirstChild("Creature_"..PlayerTouched.Name)
		if not playerHorse or not playerHorse.Seat or not playerHorse.Seat:FindFirstChild("Rider") then
			return player
		end
		local Rider = playerHorse.Seat.Rider.Value
		if not Rider then
			return player
		end
		horse = playerHorse
	end
	return player, horse
end

local function SetCheckpointDetection(checkpoint, CheckpointData, isLocal)
	if CurrentCheckpointConnection then
		CurrentCheckpointConnection:Disconnect()
	end
	CurrentCheckpointConnection = checkpoint.Touched:Connect(function(partTouched)
		local player, horse = GetPlayerAndHorseFromPartTouched(partTouched)
		if player and player == Player then
			if horse then
				if isLocal then
					InitNextCheckpointDetection(CheckpointData.NumberCheckpoint)
					return
				end
				RaceDataEvent:FireServer(CheckpointData.NumberCheckpoint)
			end
		end
	end)
end

function ClientRaceHandler:RaceDataEvent(Reason,Data, isLastCheckpoint, isLocal)
	if Reason == "RaceStart" then
		--HorseBumpHandler:Enable(HorseController.Creature,Data.AI_Folder)
	elseif Reason == "NewCheckpoint" then
		local Checkpoint = Data.Checkpoint
		local Part = MakeCheckpointPart(Checkpoint, isLastCheckpoint)
		Part.Parent = workspace
		Part.Color = Color3.fromRGB(0,255,0)
		SetCheckpointDetection(Part, Checkpoint, isLocal)
	elseif Reason == "RaceFinished" then
		if CurrentCheckpointPart then
			if CurrentCheckpointConnection then
				CurrentCheckpointConnection:Disconnect()
			end
			CurrentCheckpointPart:Destroy()
		end
		--HorseBumpHandler:Enable(HorseController.Creature)
	end
end

function ClientRaceHandler:Init()
	local CurrentRace = nil
	local NextCheckpoint = nil
	
	
	RaceDataEvent.OnClientEvent:Connect(function(Reason,Data, isLastCheckpoint)
		ClientRaceHandler:RaceDataEvent(Reason,Data, isLastCheckpoint)
	end)	
end

--#region Module Functions

local function ClearRaceInfo(Race)
	local playerValue = Race.Model.classement:FindFirstChild(Player.Name)
	if not playerValue then
		return
	end
	playerValue:Destroy()
end

local function ShowPanels(RaceModel, transparency)
	local startPanelInfo = RaceModel.Start:FindFirstChild("startPanelInfo")
	local endPanelInfo = RaceModel.Start:FindFirstChild("endPanelInfo")
	if not startPanelInfo or not endPanelInfo then
		return
	end
	startPanelInfo.Panel.Transparency = transparency
	startPanelInfo.Panel.Gui.Enabled = transparency == 0
	startPanelInfo.pole.Transparency = transparency
	
	endPanelInfo.Panel.Transparency = transparency
	endPanelInfo.Panel.Gui.Enabled = transparency == 0
	endPanelInfo.pole.Transparency = transparency
end

function ClientRaceHandler:ActivateRace(GameData, Status)
    if not (GameData.GameName == "Race") then
		return
	end
	local transparency = Status and 0 or 1
	GameData.Model.Start.Transparency = Status and 0.95 or 1
	ShowPanels(GameData.Model, transparency)

	for _, particle in pairs(GameData.Model.Start.ParticlePart:GetDescendants()) do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = Status
		end
	end

	-- Disable Beam temporary because we not need it (delete if we never need again)
	--[[ if not GameData.Model.Start:FindFirstChild("Beam") then
		return
	end
	for _, beam in pairs(GameData.Model.Start.Beam:GetChildren()) do
		beam.Transparency = NumberSequence.new(transparency)
	end ]]
end

local function blockCompetitors(StartPart, blocking)
	for _, bound in pairs(StartPart.Bounds:GetChildren()) do
		if bound.Name == "Middle" then
			continue
		end
		bound.CanCollide = blocking
	end
	StartPart.Bounds:PivotTo(StartPart.CFrame)
	if not blocking then
		return
	end
	local Horse = CreaturesFolder:FindFirstChild("Creature_"..Player.Name)
	Horse:PivotTo(StartPart.CFrame + Vector3.new(math.random(-2,2),-1,math.random(-2,2)))
end


--#region Local Race


local function SetPlayerData(Race, Player)
	Race.lastPlayersEnded[tostring(Player.UserId)] = nil
	local Horse = CreaturesFolder:FindFirstChild("Creature_"..Player.Name)
	Race.Players[Player.UserId] = {
		player = Player,
		Horse = Horse,
		NextCheckpointIndex = 1,
		Finished = false,
		Stuck = false,
		CurrentPlacement = 0,
		LastPosition = Horse.PrimaryPart.Position
	}
end

--#region SETUP RACE START

local function CountDown(Race)
	local countDown = Race.countDownTimeInSec
	blockCompetitors(Race.Model.Start, true)
	RE_RaceSoloState:FireServer(Race, "CountDown", "Get Ready !")
	task.wait(1)
	for i = 1, Race.countDownTimeInSec, 1 do
		RE_RaceSoloState:FireServer(Race, "CountDown", countDown)
		countDown -= 1
		task.wait(1)
	end
	RE_RaceSoloState:FireServer(Race, "CountDown", "Go !")
	RE_RaceSoloState:FireServer(Race, "DoneCounting")
	blockCompetitors(Race.Model.Start, false)
end


local function SetRaceStartData(Race)
	Race.StartTime = time()
	Race.ActiveData.Results = {}
	for _,Checkpoint in pairs(Race.Checkpoints) do
		if Checkpoint.Instance then
			Checkpoint.OldParent = Checkpoint.Instance.Parent
			Checkpoint.Instance.Parent = nil
		end
	end
	for _, playerVal in pairs(Race.Model.classement:GetChildren()) do
		if playerVal:IsA("ObjectValue") then
			playerVal:Destroy()
		end
	end
end


function SetupRaceStart(Race)
	Race.Ongoing = true

	SetPlayerData(Race, Player)
	
	Race.isCountDown = true
	
	CountDown(Race)

	ClientRaceHandler:ActivateRace(Race, false)

	RE_RaceSoloState:FireServer(Race, "Start")
	
	SetRaceStartData(Race)
	
	local AIs,ParentFolder = {} --RaceAIHandler:Generate(Race,10)
	for competitor, competitorInfo in pairs(Race.Players)  do
		ClientRaceHandler:RaceDataEvent("RaceStart",{RaceModel = Race.Model, AI_Folder = ParentFolder})
		local isLastCheckpoint = not Race.Checkpoints[2]
		ClientRaceHandler:RaceDataEvent("NewCheckpoint", {Checkpoint = Race.Checkpoints[1]}, isLastCheckpoint, true)
	end
	

	Race.isCountDown = false
end


--#endregion

--#region In Race

local function SetPlayerClassementValue(Race, Player, PlayerData)
	local PlayerClassement = {}
	PlayerClassement[Player.UserId] = {
		Creature = PlayerData.Horse,
		CurrentPlacement = 1,
		CurrentTime = time() - Race.StartTime,
	}
	return PlayerClassement
end

local function RaceEnd(Race, Player, PlayerData)
	local isIa = false
	if PlayerData.IsAI then
		--IA
		-- isIa = true
		-- SetPlayerClassementValue(Race, Player, PlayerData, isIa)
		-- if Race.Players[Player].Data.MovementAI then
		-- 	Race.Players[Player].Data.MovementAI:Terminate()
		-- end
		-- Race.Players[Player].Data:Terminate()
		-- table.insert(Race.ActiveData.Results,Player)
		-- Race.Players[Player] = nil
		-- return
	end
	local PlayerClassement = SetPlayerClassementValue(Race, Player, PlayerData, isIa)
	
	print(Race.Model.classement:GetChildren())
	ClientRaceHandler:RaceDataEvent("RaceFinished")
	RE_RaceSoloState:FireServer(Race, "Finish", PlayerClassement)
	Race.lastPlayersEnded[tostring(Player.UserId)] = {
		player = Player;
		Placement = 0;
		Timing = time() - Race.StartTime;
	}

	table.insert(Race.ActiveData.Results,Player)
	Race.Players[Player.UserId].Finished = true
	
	
	for _,Checkpoint in pairs(Race.Checkpoints) do
		if Checkpoint.Instance then -- not executed
			Checkpoint.Instance.Parent = Checkpoint.OldParent
			Checkpoint.OldParent = nil
		end
	end

	RE_RaceSoloState:FireServer(Race, "Ended")
	for Index,Data in pairs(Race.Players) do
		if Data and Data.IsAI then
			Data.Data:Terminate()
		end
		Race.Players[Index] = nil
	end
	ClientRaceHandler:ActivateRace(Race, true)
	CurrentRace = nil
end

function InitNextCheckpointDetection(checkpointIndex)
	local playerData = CurrentRace.Players[Player.UserId]
	if not playerData or checkpointIndex ~= playerData.NextCheckpointIndex then
		return
	end
	playerData.NextCheckpointIndex += 1
	if CurrentRace.Checkpoints[playerData.NextCheckpointIndex] then
		--SetCurrentPlayerPlacementAndGiveBonus(CurrentRace, Player)
		local isLastCheckpoint = not CurrentRace.Checkpoints[playerData.NextCheckpointIndex+1]
		ClientRaceHandler:RaceDataEvent("NewCheckpoint", {Checkpoint = CurrentRace.Checkpoints[playerData.NextCheckpointIndex]}, isLastCheckpoint, true)
		local currentTime = time() - CurrentRace.StartTime
		RE_RaceSoloState:FireServer(CurrentRace, "CheckPoint", nil, currentTime)
	else
		RaceEnd(CurrentRace, playerData.player, playerData)
	end
end

--#endregion

local function LeaveRace()
	if CurrentRace then
		CurrentRace.Players[Player.UserId].Finished = true
		ClientRaceHandler:RaceDataEvent("RaceFinished")
		RE_RaceSoloState:FireServer(CurrentRace, "Ended")
		ClientRaceHandler:ActivateRace(CurrentRace, true)
		CurrentRace = nil
	else
		print("local NOT IN RACE")
	end
end

function ClientRaceHandler:LaunchLocalRace(Race, Index)
	local race = ToolsModule.deepCopy(Race)
	CurrentRace = race
	SetupRaceStart(race)
end

--#endregion

--#endregion

--remote Events/Functions
RE_RaceSoloState.OnClientEvent:Connect(function(Race)
	ClientRaceHandler:LaunchLocalRace(Race)
end)

RE_ActivateGame.OnClientEvent:Connect(function(RaceModel, Status)
    ClientRaceHandler:ActivateRace(RaceModel, Status)
end)

RE_RaceClearInfo.OnClientEvent:Connect(function(Race)
	ClearRaceInfo(Race)
end)

RE_RaceBlockCompetitors.OnClientEvent:Connect(function(StartPart, Blocking)
	blockCompetitors(StartPart, Blocking)
end)

RE_RaceGiveUp.OnClientEvent:Connect(function()
	LeaveRace()
end)

return ClientRaceHandler
