local AchievementsDataModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local playerService = game:GetService("Players")
local require = require(ReplicatedStorage.SharedSync.Modules:WaitForChild("RequireModule"))

local ServerStorage = game.ServerStorage.ServerStorageSync
local RemoteEvent = ReplicatedStorage.SharedSync.RemoteEvent
local RemoteFunction = ReplicatedStorage.SharedSync.RemoteFunction
local BindableEvent = ReplicatedStorage.SharedSync.BindableEvent


--Require Modules
local PlayerDataModule = require("PlayerDataModule")
local DataManagerModule = require("DataManagerModule")
local ToolsModule = require("ToolsModule")

--Event
local RE_AchievementProgress = RemoteEvent.AchievementProgress
local RE_AchievementReset = RemoteEvent.AchievementReset
local RE_AchievementActivate = RemoteEvent.AchievementActivate
local RE_AchievementRefreshUI = RemoteEvent.AchievementRefreshUI
local RE_ShowUiPanel = RemoteEvent.ShowUiPanel
local RE_Notif = RemoteEvent.ShowNotification
local ShowPopupBindableEvent = BindableEvent.ShowPopupAlert
local BE_AchievementProgress = BindableEvent.AchievementProgress

--Data structure for an achievement
local AchievementStruct = {
	Title = "";
	Description = "";
	Goal = 5;
	Progress = 0;
	EcusReward = 0;
	FeezReward = 0;
	Active = false;
	Following = false;
	NextAchievement = nil;
	Done = false; 
}

--[[
	This will be our database of achievements that we want to set up for the game.
	These will be used to add to the players who will then have their own life
	with the players. This database structure is used to initialize the existing
	achievements for the players.
]]
local AchievementsData = {
	Achievement1 = {
		Title = "Mon premier compagnon";
		Description = "Obtenez votre premier cheval !";
		Goal = 1;
		Progress = 0;
		Needed = "cheval";
		EcusReward = 50;
		FeezReward = 5;
		Active = true;
		Following = false;
		NextAchievement = "Achievement2";
		Done = false;
	};
	Achievement2 = {
		Title = "Obtenir une gène";
		Description = "Obtenez votre première gène pour reçevoir 25 Ecus !";
		Goal = 1;
		Progress = 0;
		Needed = "gène";
		EcusReward = 25;
		FeezReward = 5;
		Active = false;
		Following = false;
		NextAchievement = "Achievement3";
		Done = false;
	};
	Achievement3 = {
		Title = "Obtenir 250 Ecus";
		Description = "Obtenez votre première richesse et gagner 100 Ecus !";
		Goal = 250;
		Progress = 0;
		Needed = "ecus";
		EcusReward = 100;
		FeezReward = 10;
		Active = false;
		Following = false;
		NextAchievement = "Achievement4";
		Done = false;
	};	
	Achievement4 = {
		Title = "Mon chez moi !";
		Description = "Découvrez votre ferme rien qu'à vous !";
		Goal = 1;
		Progress = 0;
		Needed = "ferme";
		EcusReward = 50;
		FeezReward = 5;
		Active = false;
		Following = false;
		NextAchievement = "Achievement5";
		Done = false;
	};
	Achievement5 = {
		Title = "Le pouvoir de l'amitié";
		Description = "Obtenez 5 chevaux, On est mieux à plusieurs !";
		Goal = 5;
		Progress = 0;
		Needed = "chevaux";
		EcusReward = 150;
		FeezReward = 25;
		Active = false;
		Following = false;
		NextAchievement = "Achievement6";
		Done = false;
	};
	Achievement6 = {
		Title = "L'union fait la force";
		Description = "Créez ou rejoignez un clan !";
		Goal = 1;
		Progress = 0;
		Needed = "clan";
		EcusReward = 75;
		FeezReward = 20;
		Active = false;
		Following = false;
		NextAchievement = "Achievement7";
		Done = false;
	};
	Achievement7 = {
		Title = "Obtenir 5.000 Ecus";
		Description = "Vous avez obtenu une sacré Fortune !";
		Goal = 5000;
		Progress = 0;
		Needed = "ecus";
		EcusReward = 500;
		FeezReward = 50;
		Active = false;
		Following = false;
		NextAchievement = "Achievement8";
		Done = false;
	};
	Achievement8 = {
		Title = "Ma première Naissance";
		Description = "Utiliser la Nursery et faite naître votre premier Poulain !";
		Goal = 1;
		Progress = 0;
		Needed = "naissance";
		EcusReward = 100;
		FeezReward = 25;
		Active = false;
		Following = false;
		NextAchievement = "Achievement9";
		Done = false;
	};
	Achievement9 = {
		Title = "Ça grandit à foison";
		Description = "Faire grandir 10 poulains en chevaux !";
		Goal = 10;
		Progress = 0;
		Needed = "chevaux";
		EcusReward = 300;
		FeezReward = 35;
		Active = false;
		Following = false;
		NextAchievement = "Achievement10";
		Done = false;
	};
	Achievement10 = {
		Title = "Le plus grand des écuris céleste !";
		Description = "Obtenir une centaine de chevaux de type Céleste";
		Goal = 100;
		Progress = 0;
		Needed = "chevaux célestes";
		EcusReward = 10000;
		FeezReward = 350;
		Active = false;
		Following = false;
		NextAchievement = nil;
		Done = false;
	};
}

local function ShowUi(player)
	RE_ShowUiPanel:FireClient(player, "Achievements")
end

--Set Achievements Data for player data module with the datas of achievements list
PlayerDataModule.SetInitAchievementsData(AchievementsData)

function AchievementsDataModule.GetAchievements()
	return AchievementsData
end

--[[
	This method allow to set a specific value of stat in achievement structure.
	Example : Change a achievement statut done to true, we call this method with the index
	of achievement to done, the achievementStat is Done and value is true.
]]
function AchievementsDataModule.SetAchievementValueOfStat(player, achievementIndex, achievementStat, value)
	PlayerDataModule:Set(player, value, "Achievements."..achievementIndex.."."..achievementStat)
	--[[ local AchievementsPlayer = PlayerDataModule:Get(player, "Achievements")
	if AchievementsPlayer then
		for index, achiv in pairs(AchievementsPlayer) do
			if index == achievementIndex then
				achiv[achievementStat] = value
				break
			end
		end
		
		PlayerDataModule:Set(player, AchievementsPlayer, "Achievements")
	end ]]
end


--[[
	This method increment by number passed in parameter "increment" the progress value of achievement
	given with index "achievementIndex"
]]
function AchievementsDataModule.IncrementProgress(player, achievementIndex, increment)
	local AchievementsPlayer = PlayerDataModule:Get(player, "Achievements")
	if not AchievementsPlayer or not AchievementsPlayer[achievementIndex].Active then
		return
	end
	if AchievementsPlayer[achievementIndex].Progress < AchievementsData[achievementIndex].Goal then
		AchievementsPlayer[achievementIndex].Progress += increment
		
		--Check if with the increment Progress do not higher to Goal
		--if it is, make Progress equal Goal because goal are reach and can't be higher
		if AchievementsPlayer[achievementIndex].Progress > AchievementsData[achievementIndex].Goal then
			AchievementsPlayer[achievementIndex].Progress = AchievementsData[achievementIndex].Goal
		end
		if AchievementsPlayer[achievementIndex].Progress == AchievementsData[achievementIndex].Goal then
			RE_Notif:FireClient(
				player,
				"Achievement Done",
				AchievementsData[achievementIndex].Title.."\n\nDon't forget to collect your reward."
			)
			ShowPopupBindableEvent:Fire(
				player,
				"Achievement Done",
				AchievementsData[achievementIndex].Title.."\n\nDon't forget to collect your reward.",
				ToolsModule.AlertPriority.Annoucement,
				"ok",
				"Check Achievement",
				nil,
				nil,
				ShowUi,
				{player}
			)
			if AchievementsData[achievementIndex].NextAchievement then
				AchievementsPlayer[AchievementsData[achievementIndex].NextAchievement].Active = true
			end
		end
	end
	PlayerDataModule:Set(player, AchievementsPlayer, "Achievements")
	RE_AchievementRefreshUI:FireClient(player, achievementIndex, nil, AchievementsPlayer[achievementIndex].Progress, AchievementsData[achievementIndex].Goal)
end

function AchievementsDataModule.ResetAchievement(player)
	local AchievementsPlayer = PlayerDataModule:Get(player, "Achievements")
	if AchievementsPlayer then

		RE_Notif:FireClient(
			player,
			"Achievement Reseted",
			"All your achievements have been reset."
		)
		AchievementsPlayer = AchievementsData
		PlayerDataModule:Set(player, AchievementsPlayer, "Achievements")
	end
end


function AchievementsDataModule.ActivateAchievement(player, achievementIndex)
	local AchievementsPlayer = PlayerDataModule:Get(player, "Achievements")
	AchievementsPlayer[achievementIndex].Active = true
	PlayerDataModule:Set(player, AchievementsPlayer, "Achievements")
end


RE_AchievementProgress.OnServerEvent:Connect(AchievementsDataModule.IncrementProgress)
BE_AchievementProgress.Event:Connect(AchievementsDataModule.IncrementProgress)
RE_AchievementActivate.OnServerEvent:Connect(AchievementsDataModule.ActivateAchievement)
RE_AchievementReset.OnServerEvent:Connect(AchievementsDataModule.ResetAchievement)


return AchievementsDataModule