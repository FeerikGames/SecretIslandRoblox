local RaceHandler = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))
local EnvironmentModule = require("EnvironmentModule")

--Don"t setup race function if its competition parade server
if game.PlaceId == EnvironmentModule.GetPlaceId("FashionShow") then
	return RaceHandler
end
local PlayerService = game:GetService("Players")
local SpatialUtils = require("SpatialUtils")
local RaceAIHandler = require("RaceAIHandler")
local HorsePathfinding = require("HorsePathfinding")
local ToolsModule = require("ToolsModule")

local PlayerDataModule = require("PlayerDataModule")
local RaceDataModule = require("RaceDataModule")
local StartingZoneModule = require("StartingZoneModule")
local GamePanelModule = require("GamePanelModule")
local GameBonusModule = require("GameBonusModule")

local GetRemoteEvent = require("GetRemoteEvent")
local RaceDataEvent = GetRemoteEvent("RaceDataEvent")

local RunService = game:GetService("RunService")
local RacesFolder = workspace:WaitForChild("Races")
local CreaturesFolder = workspace:WaitForChild("CreaturesFolder")

local Assets = ReplicatedStorage:WaitForChild("SharedSync"):WaitForChild("Assets")

--Events
local RemoteEventFolder = ReplicatedStorage.SharedSync.RemoteEvent
local RE_RaceSoloState = RemoteEventFolder:WaitForChild("RaceSoloState")
local RE_RaceUiState = RemoteEventFolder:WaitForChild("RaceUiState")
local RE_RaceClearInfo = RemoteEventFolder:WaitForChild("RaceClearInfo")
local RE_RaceBlockCompetitors = RemoteEventFolder:WaitForChild("RaceBlockCompetitors")
local RE_RaceGiveUp = RemoteEventFolder:WaitForChild("RaceGiveUp")

local remoteFunctionFolder = ReplicatedStorage.SharedSync.RemoteFunction
local RF_GetRaces = remoteFunctionFolder.GetRaces
local RF_SetRace = remoteFunctionFolder.SetRace

local Races = {}

-- Properties

local PanelStudsDistance = 1

function RaceHandler:GetRaces()
	return Races
end

function Round(Number: number, Precision: number?) : number
	local Places = (Precision) and (10^Precision) or 1
	return (((Number * Places) + 0.5 - ((Number * Places) + 0.5) % 1)/Places)
end

function RaceHandler:SetRaceData(raceId, raceValue)
	if Races[raceId] then
		Races[raceId] = raceValue
		Races[raceId].Model:SetAttribute("playerNeeded", Races[raceId].playerNeeded)
		return true
	else
		warn("Race not iniciated")
		return false
	end

end

function RaceHandler:ResetRaces()
	Races = {}
end

local function fillStartRaceInfo(panel, players)
	for _, playerItem in pairs(players) do
		playerItem.Info = playerItem.Timing
	end
	GamePanelModule:fillPanelInfo(panel, players)
end

local function fillEndRaceInfo(RaceInfo, panel)
	local playerClassement = {}
	for _, PlayerData in pairs(RaceInfo.Model.classement:GetChildren()) do
		local playerName, playerUserId
		if PlayerData.Value.Name then
			playerName = PlayerData.Value.Name
			playerUserId = PlayerData.Value.UserId
		else
			playerName = PlayerData.Value
			playerUserId = nil
		end
		playerClassement[playerName] = {}
		playerClassement[playerName].Player = {}
		playerClassement[playerName].Player.name = playerName
		playerClassement[playerName].Player.userId = playerUserId
		playerClassement[playerName].Placement = PlayerData.CurrentPlacement.Value
		playerClassement[playerName].Info = Round(PlayerData.CurrentTime.Value, 2)
	end
	GamePanelModule:fillPanelInfo(panel, playerClassement)
end

local function deleteEndPanels(RaceData)
	for _, EndPanel in pairs(RaceData.Model.Start:GetChildren()) do
		if EndPanel.Name == "endPanelInfo" then
			EndPanel:Destroy()
		end
	end
end

local function setupRaceEndPanel(RaceData)
	local StartPart = RaceData.Model.Start
	local panelSize, PoleSize = GamePanelModule:GetPanelSizes()
	if #RaceData.Checkpoints <= 0 then
		return
	end
	local checkpointProperties = RaceData.Checkpoints[#RaceData.Checkpoints].Properties
	local raceStartModif = checkpointProperties.CFrame.RightVector * checkpointProperties.Size.X / 2
	local groundModif = Vector3.new(0,checkpointProperties.Size.Y/2 - PoleSize.Y/2,0)
	local panelModif = checkpointProperties.CFrame.RightVector * Vector3.new(panelSize.X/2 - PanelStudsDistance,0,0).X
	local modif = - ( raceStartModif + panelModif + groundModif)
    local panelCFrame = checkpointProperties.CFrame + modif

	local TitleText = RaceData.DisplayName
	local MessageText = "Last race results :"
	local endPanel = GamePanelModule:MakePanelInfo(panelCFrame, StartPart, TitleText, MessageText)
	endPanel.Name = "endPanelInfo"
	return endPanel
end

local function setupRaceStartPanel(RaceData)
	local StartPart = RaceData.Model.Start
	local panelSize, PoleSize = GamePanelModule:GetPanelSizes()
	local raceStartModif = StartPart.CFrame.RightVector * StartPart.Size.X / 2
	local groundModif = Vector3.new(0,StartPart.Size.Y/2 - PoleSize.Y/2,0)
	local panelModif = StartPart.CFrame.RightVector * Vector3.new(panelSize.X/2,0,0).X
	local modif = - (raceStartModif + panelModif + groundModif)
    local position = StartPart.CFrame + modif
	local panelCFrame = position * CFrame.Angles(0,math.rad(180),0)

	local TitleText = RaceData.DisplayName
	local MessageText = RaceData.playerNeeded .. " players needed"
	if RaceData.playerNeeded == 1 then
		MessageText = RaceData.playerNeeded .. " player needed"
	end
	local startPanel = GamePanelModule:MakePanelInfo(panelCFrame, StartPart, TitleText, MessageText)
	startPanel.Name = "startPanelInfo"
	local raceClassement = RaceDataModule.GetRaceData(RaceData)
	for _, playerItem in pairs(raceClassement.PlayerClassement) do
		playerItem.Info = playerItem.Timing
		playerItem.Timing = nil
	end
	GamePanelModule:fillPanelInfo(startPanel, raceClassement.PlayerClassement)
	return startPanel
end

--[[
	This function setup race start object for custom races players
]]
function RaceHandler:MakeStart(PlayerId, StartPart, playerNeeded)
	local playerRaces = RaceHandler:CheckIfPlayerHaveRaces(PlayerId)
	local raceLink = StartPart:GetAttribute("RaceLink")
	local raceModel = Instance.new("Model", workspace.Races)
	if not playerNeeded then
		playerNeeded = 1
	end 
	raceModel:SetAttribute("playerNeeded", playerNeeded)
	local checkPointFolder = Instance.new("Folder", raceModel)
	checkPointFolder.Name = "Checkpoints"

	StartPart.Parent = raceModel
	StartPart.CanQuery = true
	raceModel.PrimaryPart = StartPart

	if raceLink == "" then
		local playerName
		if RunService:IsStudio() then
			playerName = "Test"..PlayerId
		else
			playerName = game.Players:GetNameFromUserIdAsync(PlayerId) --not work in studio with fake player test
		end

		if playerRaces then
			local i=1
			--sort table compared to number of race
			table.sort(playerRaces, function(A, B)
				local NumberA = tonumber(A.RaceLink:sub(#A.RaceLink, #A.RaceLink))
				local NumberB = tonumber(B.RaceLink:sub(#B.RaceLink, #B.RaceLink))
				return NumberA < NumberB
			end)
			--check what the smallest number missing and increment i for get the good number assign to the next name of start race object
			for _, race in pairs(playerRaces) do
				print("RACE", race.RaceLink)
				local nb = tonumber(race.RaceLink:sub(#race.RaceLink, #race.RaceLink))
				if nb==i then
					i+=1
				end
			end
			raceLink = playerName.." Race "..i
		else
			raceLink = playerName.." Race 1"
		end
	end
	raceModel.Name = raceLink
	StartPart:SetAttribute("RaceLink", raceLink)

	local RaceData = InitRaceData(raceModel, raceLink, PlayerId)
	Races[raceLink] = RaceData

	setupRaceStartPanel(RaceData)
	InitRaceFolder(RaceData)
	local player = PlayerService:GetPlayerByUserId(PlayerId)
	StartingZoneModule:ActiveGameStartPartToPlayer(player, RaceData, true)
	--RaceHandler:InitStartPartDetection(RaceData, RaceData.RaceName)
	StartingZoneModule:InitZoneDetection(RaceData.Model.Start, RaceData, RaceData.DisplayName, SetupRaceStart, LaunchSoloRace)
	warn("Made start!")
end

function RaceHandler:SetRaceEnd(PlayerId)
	local RacesData = RaceHandler:CheckIfPlayerHaveRaces(PlayerId)
	if RacesData then
		for _, RaceData in pairs(RacesData) do
			setupRaceEndPanel(RaceData)
			InitRaceVisibility(RaceData)
			StartingZoneModule:InitZoneDetection(RaceData.Model.Start, RaceData, RaceData.DisplayName, SetupRaceStart, LaunchSoloRace)
		end
	end
end

local function CheckpointSort(A,B)
	local NumberA = A.NumberCheckpoint
	local NumberB = B.NumberCheckpoint
	if NumberA == NumberB then
		--check here why A is a nil value and make error because try to Get full name of nil value
		--warn("Two of the same checkpoints! ",A:GetFullName())
	end
	if NumberA < NumberB then
		return true
	end
	return false
end


function RaceHandler:SetCheckpoint(PlayerId,CheckpointPart)
	local RacesData = RaceHandler:CheckIfPlayerHaveRaces(PlayerId)
	if not RacesData then
		warn("User doesnt own a race.")
		return
	end
	for _, RaceData in pairs(RacesData) do
		local CheckpointID = CheckpointPart:GetAttribute("NumberCheckpoint")
		local RaceLink = CheckpointPart:GetAttribute("RaceLink")
		if RaceData.RaceLink ~= RaceLink then
			continue
		end
		if not CheckpointID then
			warn("Provided checkpoint has no 'NumberCheckpoint' attribute!")
			break
		end
		table.insert(RaceData.Checkpoints,CheckpointID,{
			Properties = {
				Name = CheckpointPart.Name,
				Position = CheckpointPart.Position,
				CFrame = CheckpointPart.CFrame,
				Size = CheckpointPart.Size,
			},
			Instance = CheckpointPart,
			NumberCheckpoint = CheckpointID
		})
		CheckpointPart.Parent = RaceData.Model.Checkpoints
		if RaceData.Checkpoints[CheckpointID+1] then
			for i=CheckpointID+1, #RaceData.Checkpoints do
				RaceData.Checkpoints[i].NumberCheckpoint += 1
			end
		end
		table.sort(RaceData.Checkpoints,CheckpointSort)
		print("RACES AFTER ADD CHECKPOINT", Races)
		print("Added checkpoint!")
		deleteEndPanels(RaceData)
		if RaceData.Checkpoints[#RaceData.Checkpoints] then
			setupRaceEndPanel(RaceData)
		end
		break
	end
end

function RaceHandler:CheckIfPlayerHaveRaces(PlayerId)
	local playerRacesData = {}
	for _, Data in pairs(Races) do
		if Data.Owner == PlayerId then
			print("123456 race of player : ", Data.RaceLink)
			table.insert(playerRacesData, Data)
		end
	end
	if #playerRacesData > 0 then
		return playerRacesData
	end

	return false
end

--Update datas of checkpoints when they are modified (If the player changes the location, size or number of the checkpoint for example)
function RaceHandler:UpdateCheckpoints(PlayerId)
	local newCheckpoints = RaceHandler:GetAllCheckpoints(PlayerId)
	local RacesData = RaceHandler:CheckIfPlayerHaveRaces(PlayerId)
	if RacesData then
		for _, RaceData in pairs(RacesData) do
			for _, newCheckpoint in pairs(newCheckpoints) do
				for _, checkpoint in pairs(RaceData.Checkpoints) do
					if checkpoint.Instance == newCheckpoint then
						--update value of checkpoint in RaceData with new value of checkpoint in game
						checkpoint.Properties.Name = newCheckpoint.Name
						checkpoint.Properties.Position = newCheckpoint.Position
						checkpoint.Properties.CFrame = newCheckpoint.CFrame
						checkpoint.Properties.Size = newCheckpoint.Size
						checkpoint.Instance = newCheckpoint
						checkpoint.NumberCheckpoint = newCheckpoint:GetAttribute("NumberCheckpoint")
					end
				end
			end
			--data have change so resort theres to have a good order of checkpoint
			table.sort(RaceData.Checkpoints,CheckpointSort)
			--RaceData.Paths = HorsePathfinding.PathfindCheckpoints(RaceData.Model.Start, RaceData.Checkpoints),
			RaceHandler:UpdateInfoPanels(RaceData)
		end
	end
end

--[[ This function allow to remove a checkpoint given from the race data ]]
function RaceHandler:RemoveCheckpoint(PlayerId, checkpointRemove)
	local RacesData = RaceHandler:CheckIfPlayerHaveRaces(PlayerId)

	if RacesData then
		for _, RaceData in pairs(RacesData) do
			for index, checkpoint in pairs(RaceData.Checkpoints) do	
				if checkpoint.Instance == checkpointRemove then
					table.remove(RaceData.Checkpoints, index)
					break
				end
			end
		end
	end
end

--Get all checkpoints objects placed and return a table of there
function RaceHandler:GetAllCheckpoints(PlayerId, RaceLink)
	local checkpoints = {}
	for _, object in pairs(game.Workspace.Races:GetChildren()) do
		if object.Name == RaceLink then
			for _, checkpoint in pairs(object.Checkpoints:GetChildren()) do
				if checkpoint:GetAttribute("RaceCreator") == PlayerId then
					table.insert(checkpoints, checkpoint)
				end
			end
		elseif not RaceLink then
			for _, checkpoint in pairs(object.Checkpoints:GetChildren()) do
				if checkpoint:GetAttribute("RaceCreator") == PlayerId then
					table.insert(checkpoints, checkpoint)
				end
			end
		end
	end
	--Sort checkpoint in order
	table.sort(checkpoints, function(A, B)
		local NumberA = 0
		local NumberB = 0
		NumberA = tonumber(A:GetAttribute("NumberCheckpoint"))
		NumberB = tonumber(B:GetAttribute("NumberCheckpoint"))
		return NumberA < NumberB
	end)
	return checkpoints
end

function RaceHandler:UpdateInfoPanels(raceInfo)
	deleteEndPanels(raceInfo)
	if raceInfo.Checkpoints[#raceInfo.Checkpoints] then
		setupRaceEndPanel(raceInfo)
	end
	raceInfo.Model.Start.startPanelInfo.Panel.Gui.message.Text = raceInfo.playerNeeded .. " players needed"
	if raceInfo.playerNeeded == 1 then
		raceInfo.Model.Start.startPanelInfo.Panel.Gui.message.Text = raceInfo.playerNeeded .. " player needed"
	end
end

function  RaceHandler:DeleteRace(PlayerId, RaceLink, model)
	--getall checkpoint for the race selected to delete
	local checkpoints = RaceHandler:GetAllCheckpoints(PlayerId, RaceLink)
	for _, checkpoint in pairs(checkpoints) do
		checkpoint:Destroy()
	end
	model:Destroy()
	for index, race in pairs(Races) do
		if race.RaceLink == RaceLink then
			Races[index] = nil
			print("RACE DELETED", Races)
		end
	end
end


local function clearRaceInfoOfPlayer(panel, player)
    for _, playerItem in pairs(panel.Participants:GetChildren()) do
        if playerItem:IsA("Frame") then
            if playerItem.Name == player.Name then
                playerItem:Destroy()
            end
        end
    end
end

function InitRaceData(RaceModel, raceLink, owner)
	local Checkpoints = {}
		for _,CheckpointPart in ipairs(RaceModel:WaitForChild("Checkpoints"):GetChildren()) do
			local numCheckpoint = tonumber(CheckpointPart:GetAttribute("NumberCheckpoint"))
			table.insert(Checkpoints,{
				Properties = {
					Name = CheckpointPart.Name,
					Position = CheckpointPart.Position,
					CFrame = CheckpointPart.CFrame,
					Size = CheckpointPart.Size,
				},
				NumberCheckpoint = numCheckpoint
			})
			CheckpointPart:Destroy()
		end
		local RaceData = {
			DisplayName = RaceModel.Name,
			RaceLink = raceLink,
			Owner = owner and owner or nil,
			GameName = "Race",
			playerNeeded = RaceModel:GetAttribute("playerNeeded"),
			Connections = {},
			Players = {},
			lastPlayersEnded = {},
			Model = RaceModel,
			Ongoing = false,
			isCountDown = false,
			isEventRunning = false,
			EventTimeInSec = 40,
			EventCurrentTime = 0,
			WaitingForMorePlayers = false,
			WaitForOthersTimeInSec = 10,
			WaitForOthersCountDown = 0,
			countDownTimeInSec = 3,
			Checkpoints = Checkpoints,
			Paths = nil,
			StartTime = nil,
			ActiveData = {
				Results = {}
			}
		}
		table.sort(RaceData.Checkpoints,CheckpointSort)
		return RaceData
end

-- Instantiate race's folders (participants allowed and classement)
function InitRaceFolder(RaceData)
	local playerFolder = Instance.new("Folder", RaceData.Model)
	playerFolder.Name = "participants"
	local playerFolder = Instance.new("Folder", RaceData.Model)
	playerFolder.Name = "Allowed"
	local classementFolder = Instance.new("Folder", RaceData.Model)
	classementFolder.Name = "classement"
end

function InitRaceVisibility(RaceData)
	if game.PlaceId == EnvironmentModule.GetPlaceId("MyFarm") then
		return
	end

	local startPanel = RaceData.Model.Start.startPanelInfo
	local endPanel = RaceData.Model.Start.endPanelInfo
	startPanel.Panel.Transparency = 1
	startPanel.Panel.Gui.Enabled = false
	startPanel.pole.Transparency = 1
	endPanel.Panel.Transparency = 1
	endPanel.Panel.Gui.Enabled = false
	endPanel.pole.Transparency = 1
	RaceData.Model.Start.Transparency = 1

	for _, particle in pairs(RaceData.Model.Start.ParticlePart:GetDescendants()) do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = false
		end
	end

	-- Disable Beam temporary because we not need it (delete if we never need again)
	--[[ for _, beam in pairs(RaceData.Model.Start.Beam:GetChildren()) do
		beam.Transparency = NumberSequence.new(1)
	end ]]
end

function RaceHandler:InitRace(RaceModel)
	local RaceData = InitRaceData(RaceModel, RaceModel.Name)
	Races[RaceData.DisplayName] = RaceData

	setupRaceEndPanel(RaceData)
	setupRaceStartPanel(RaceData)
	InitRaceFolder(RaceData)
	InitRaceVisibility(RaceData)
	--RaceHandler:InitStartPartDetection(RaceData, RaceData.RaceName)
	StartingZoneModule:InitZoneDetection(RaceData.Model.Start, RaceData, RaceData.DisplayName, SetupRaceStart, LaunchSoloRace)
end

function RaceHandler:Init()
	for Index,RaceModel in ipairs(RacesFolder:GetChildren()) do
		RaceHandler:InitRace(RaceModel)
	end
end

--#region Race processing functions

function LaunchSoloRace(Race, Player)
	RE_RaceSoloState:FireClient(Player, Race)
end

--#region Player Data

local function SetPlayersPlacement(Race)
	local playerPlacements = {}
	for index, playerData in pairs(Race.Players) do
		table.insert(playerPlacements, {
			NextCheckpointIndex = playerData.NextCheckpointIndex,
			UserId = index,
		})
	end
	table.sort(playerPlacements, function(a,b)
		return a.NextCheckpointIndex >= b.NextCheckpointIndex
	end)
	for index, playerPlacement in pairs(playerPlacements) do
		Race.Players[playerPlacement.UserId].CurrentPlacement = index
	end
end

local function GetPlayersPlacement(Race)
	local playerPlacements = {}
	for index, playerData in pairs(Race.Players) do
		table.insert(playerPlacements, {
			NextCheckpointIndex = playerData.NextCheckpointIndex,
			UserId = index,
		})
	end
	table.sort(playerPlacements, function(a,b)
		return a.NextCheckpointIndex >= b.NextCheckpointIndex
	end)
	return playerPlacements
end

-- Set the player's data in the race's data
-- Called by : InitStartPartDetection when entering start part and player choosed multi.
local function SetPlayerData(Race, player, horse)
	Race.Players[player.UserId] = {
		player = player,
		Horse = horse,
		NextCheckpointIndex = 1,
		Finished = false,
		Stuck = false,
		CurrentPlacement = 0,
		LastPosition = horse.PrimaryPart.Position
	}
end

local function SetPlayersData(Race, players)
	Race.Players = {}
	for _, playerInstance in pairs(players) do
		SetPlayerData(Race, playerInstance.player, playerInstance.creature)
	end
end

--#endregion

--#region SETUP RACE START

local function CountDown(Race)
	local countDown = Race.countDownTimeInSec
	
	for _, playerData in pairs(Race.Players) do 
		RE_RaceBlockCompetitors:FireClient(playerData.player, Race.Model.Start, true)
	end
	for competitor, competitorInfo in pairs(Race.Players) do
		RE_RaceUiState:FireClient(competitorInfo.player, Race, "CountDown", "Get Ready !")
	end
	task.wait(1)
	for i = 1, Race.countDownTimeInSec, 1 do
		for competitor, competitorInfo in pairs(Race.Players) do
			RE_RaceUiState:FireClient(competitorInfo.player, Race, "CountDown", countDown)
		end
		countDown -= 1
		task.wait(1)
	end
	for competitor, competitorInfo in pairs(Race.Players) do
		RE_RaceUiState:FireClient(competitorInfo.player, Race, "CountDown", "Go !")
	end
	for competitor, competitorInfo in pairs(Race.Players) do
		RE_RaceUiState:FireClient(competitorInfo.player, Race, "DoneCounting")
	end
	for _, playerData in pairs(Race.Players) do 
		RE_RaceBlockCompetitors:FireClient(playerData.player, Race.Model.Start, false)
	end
	
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
	if not Race.Paths then
		--no IA for now (KEEP IT FOR LATER)
		--Race.Paths = HorsePathfinding.PathfindCheckpoints(Race.Model.Start,Race.Checkpoints)
	end
	
	for _, playerVal in pairs(Race.Model.classement:GetChildren()) do
		if playerVal:IsA("ObjectValue") then
			playerVal:Destroy()
		end
	end
end

local function setupIA(Race, AIs)
	for Index,AI in pairs(AIs) do
		AI.Horse:PivotTo(Race.Model.Start.CFrame * CFrame.new((Race.Model.Start.Size.X/3) * AI.CheckpointOffset,0,0) )
		Race.Players[Index] = AI
		Race.Players[Index].NextCheckpointIndex = 1
		Race.Players[Index].LastPosition = AI.Horse.PrimaryPart.Position
		--Race.Players[Index]:Next(AI.Horse.PrimaryPart,Race.Checkpoints[1].Properties,Race.Paths[1])
		AI.Data.MovementAI:SetTarget(Race.Checkpoints[1].Properties.CFrame * CFrame.new(0,0,-4),Race.Paths[1])
		--[[AI.Data.BumpHandler.BumpStateChanged:Connect(function(State,Data)
			if State == true and Race.Players[Index] and Race.Checkpoints[Race.Players[Index].NextCheckpointIndex] then
				AI.Data.MovementAI:SetTarget(Race.Checkpoints[Race.Players[Index].NextCheckpointIndex].Properties.CFrame * CFrame.new(0,0,-4))
			end
		end)]]
	end
end

local function ShowRaceStart(Race, doShow)
	for _, competitorInfo in pairs(Race.Model.Allowed:GetChildren()) do
		local UserId = competitorInfo.Name
		if not doShow and not Race.Players[tonumber(UserId)] then
			continue
		end
		local player = PlayerService:GetPlayerByUserId(UserId)
		StartingZoneModule:ActivateGame(player, Race, doShow)
	end
end

-- Function that setup the race Start and launch the race (countdown, playerdata, checkpoints, Ia)
function SetupRaceStart(Race, players)
	Race.Ongoing = true
	SetPlayersData(Race, players)
	
	Race.isCountDown = true
	
	CountDown(Race)

	ShowRaceStart(Race, false)

	for competitor, competitorInfo in pairs(Race.Players) do
		RE_RaceUiState:FireClient(competitorInfo.player, Race, "Start")
	end
	
	SetRaceStartData(Race)
	
	local AIs,ParentFolder = {} --RaceAIHandler:Generate(Race,10)
	for competitor, competitorInfo in pairs(Race.Players)  do
		RaceDataEvent:FireClient(competitorInfo.player,"RaceStart",{RaceModel = Race.Model, AI_Folder = ParentFolder})
		local isLastCheckpoint = not Race.Checkpoints[2]
		RaceDataEvent:FireClient(competitorInfo.player,"NewCheckpoint",{Checkpoint = Race.Checkpoints[1]}, isLastCheckpoint)
	end
	
	setupIA(Race, AIs)

	Race.isCountDown = false
end
--#endregion

--#region In Race

-- Set the player classement (in player classement folder of race) values to display in each player uis
-- Called by : RaceEnd
local function SetPlayerClassementValue(Race, Player, PlayerData, IsIA)
	local existingClassement = Race.Model.classement:FindFirstChild(PlayerData.player.Name)
	if existingClassement then
		existingClassement:Destroy()
	end

	local playerValue
	if not IsIA then
		if Race.Model.classement:FindFirstChild(PlayerData.player.Name) == nil then
			playerValue = Instance.new("ObjectValue", Race.Model.classement)
			playerValue.Value = PlayerData.player
			playerValue.Name = PlayerData.player.Name
		end
	else
		--IA
		if Race.Model.classement:FindFirstChild(Player) == nil then
			playerValue = Instance.new("StringValue", Race.Model.classement)
			playerValue.Value = Player
			playerValue.Name = Player
		end
	end
	local Creature = Instance.new("ObjectValue", playerValue)
	Creature.Value = PlayerData.Horse
	Creature.Name = "Creature"
	local CurrentPlacement = Instance.new("IntValue", playerValue)
	CurrentPlacement.Value = #Race.Model.classement:GetChildren()
	CurrentPlacement.Name = "CurrentPlacement"
	local CurrentTime = Instance.new("NumberValue", playerValue)
	CurrentTime.Value = time() - Race.StartTime
	CurrentTime.Name = "CurrentTime"

end

local function GetFinishedPlayerNumber(Race)
	local finishedCount = 0
	for _, playerData in pairs(Race.Players) do
		if not Race.Checkpoints[playerData.NextCheckpointIndex] then
			finishedCount += 1
		end
	end
	return finishedCount
end

-- Set the race data with the results (best scores) then fill start/end panels and terminate IAs and players data and reset checkpoints.
-- Called by : RaceEnd when the last player finished the race.
local function RaceFinished(Race)
	Race.Ongoing = false
	print("RACE Finished")
	print("Race results: ", Race.ActiveData.Results)
	RaceDataModule.SetRaceDataPlayers(Race, Race.lastPlayersEnded)

	local raceClassement = RaceDataModule.GetRaceData(Race)
	fillStartRaceInfo(Race.Model.Start.startPanelInfo, raceClassement.PlayerClassement)
	if ToolsModule.LengthOfDic(Race.ActiveData.Results) > 0 then
		fillEndRaceInfo(Race, Race.Model.Start.endPanelInfo)
	end
	for Index,Data in pairs(Race.Players) do
		if Data and Data.IsAI then
			Data.Data:Terminate()
		end
		Race.Players[Index] = nil
	end
	--[[for _,Horse in pairs(game.Workspace:FindFirstChild("AI_Holder"):FindFirstChild(tostring(Race.RaceLink)):GetChildren()) do
		Horse:Destroy()
	end]]
	for _,Checkpoint in pairs(Race.Checkpoints) do
		if Checkpoint.Instance then -- not executed
			Checkpoint.Instance.Parent = Checkpoint.OldParent
			Checkpoint.OldParent = nil
		end
	end
end

-- Set the player calssement and result data then if there's no more players call RaceFinished to end the race and fill results.
-- Called by : InitNextCheckpointDetection when player passed the last checkpoint.
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
	SetPlayerClassementValue(Race, Player, PlayerData, isIa)
	
	print(Race.Model.classement:GetChildren())
	RaceDataEvent:FireClient(Player,"RaceFinished")
	RE_RaceUiState:FireClient(Player, Race, "Finish")
	Race.lastPlayersEnded[Player.UserId] = {
		player = Player;
		Placement = 0;
		Timing = time() - Race.StartTime;
	}

	table.insert(Race.ActiveData.Results,Player)
	StartingZoneModule:EndPlayerCurrentGame(Race, Player)
	StartingZoneModule:ActivateGame(Player, Race, true)
	local playerFinishedNum = GetFinishedPlayerNumber(Race)
	if playerFinishedNum == ToolsModule.LengthOfDic(Race.Players) then
		RaceFinished(Race)
	end
end

-- This function will set all the players placements and give a bonus to the current player bassed on its placement.
-- Arguments : current Race, current player.
local function SetCurrentPlayerPlacementAndGiveBonus(Race, player)
	SetPlayersPlacement(Race)
	local playerClassements = GetPlayersPlacement(Race)
	local totPlayer = ToolsModule.LengthOfDic(Race.Players)
	local numberOfCheckpointsBehind = playerClassements[1].NextCheckpointIndex - Race.Players[player.UserId].NextCheckpointIndex
	-- calculating the ratio of checkpoint late from the first player to the last player.
	local PlacementRatio = (numberOfCheckpointsBehind) / (playerClassements[1].NextCheckpointIndex - playerClassements[#playerClassements].NextCheckpointIndex)
	if totPlayer == 1 then
		PlacementRatio = 0
	end
	GameBonusModule:ApplyBonusToPlayer(player, "RatioAndNumber", PlacementRatio, numberOfCheckpointsBehind)
end

-- Sets the next checkpoint in client and its detection plus increment all player race data. if there's no more checkpoint : end race
-- Called by : remote event fired from ClientRaceHandler when player enter a checkpoint (event Touched)
function RaceHandler:InitNextCheckpointDetection(player, checkpointIndex)
	local raceName = StartingZoneModule:GetPlayerCurrentGame(player)
	if not raceName then
		return
	end
	raceName = raceName.gameName
	if not raceName or not Races[raceName] then
		return
	end
	local Race = Races[raceName]
	local playerData = Race.Players[player.UserId]
	if not playerData or checkpointIndex ~= playerData.NextCheckpointIndex then
		return
	end
	playerData.NextCheckpointIndex += 1
	if Race.Checkpoints[playerData.NextCheckpointIndex] then
		SetCurrentPlayerPlacementAndGiveBonus(Race, player)
		local isLastCheckpoint = not Race.Checkpoints[playerData.NextCheckpointIndex+1]
		RaceDataEvent:FireClient(playerData.player ,"NewCheckpoint",{Checkpoint = Race.Checkpoints[playerData.NextCheckpointIndex]}, isLastCheckpoint)
		local currentTime = time() - Race.StartTime
		RE_RaceUiState:FireClient(playerData.player, Race, "CheckPoint", nil, currentTime)
	else
		RaceEnd(Race, playerData.player, playerData)
	end
end

RaceDataEvent.OnServerEvent:Connect(function(player, checkpointIndex)
	RaceHandler:InitNextCheckpointDetection(player, checkpointIndex)
end)
--#endregion

-- For the player to leave the race prematuraly : set its data back to normal (so that he can take a race again) if player isn't in a server race : call event to leave solo race
-- Called by : Remote Event fired by RaceCoreUi when clicking on the give up button
local function LeaveRace(Player)
	local raceName = StartingZoneModule:GetPlayerCurrentGame(Player).gameName
	if raceName and Races[raceName] then
		Races[raceName].Players[Player.UserId] = nil
		StartingZoneModule:EndPlayerCurrentGame(Races[raceName], Player)
		RaceDataEvent:FireClient(Player,"RaceFinished")
		StartingZoneModule:ActivateGame(Player, Races[raceName], true)
		local playerFinishedNum = GetFinishedPlayerNumber(Races[raceName])
		if playerFinishedNum == ToolsModule.LengthOfDic(Races[raceName].Players) then
			RaceFinished(Races[raceName])
		end
	else
		print("NOT IN RACE, testing solo race")
		StartingZoneModule:EndPlayerCurrentGame(nil, Player)
		RE_RaceGiveUp:FireClient(Player)
	end
end

--#endregion

-- Function Launching game if conditions are good
function RaceHandler:LaunchGame(Race)
	local players = ToolsModule.deepCopy(Race.Players)
	Race.Players = {}
	SetupRaceStart(Race, players)
end


RF_GetRaces.OnServerInvoke = function()
	return RaceHandler.GetRaces()
end

RF_SetRace.OnServerInvoke = function(player, raceId, RaceValue)
	RaceHandler:SetRaceData(raceId, RaceValue)
	RaceHandler:UpdateInfoPanels(Races[raceId])
	return true
end

RE_RaceSoloState.OnServerEvent:Connect(function(Player, Race, Reason, data, time)
	if Reason == "Ended" then
		RaceDataModule.SetRaceDataPlayers(Race, Race.lastPlayersEnded)
		local raceClassement = RaceDataModule.GetRaceData(Race)
		fillStartRaceInfo(Race.Model.Start.startPanelInfo, raceClassement.PlayerClassement)
		fillEndRaceInfo(Race, Race.Model.Start.endPanelInfo)
		StartingZoneModule:EndPlayerCurrentGame(Race, Player)
		return
	end
	RE_RaceUiState:FireClient(Player, Race, Reason, data, time)
end)

RE_RaceGiveUp.OnServerEvent:Connect(function(Player)
	LeaveRace(Player)
end)

return RaceHandler
