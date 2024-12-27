return {
	DateSignedUp = DateTime.now():FormatLocalTime("LL", "en-us");
	TotalNumberOfCreatures = 0;
	TotalNumberOfCreaturesType = {
		Horse = {
			Normal = 0;
			Fire = 0;
			Water = 0;
			Light = 0;
			Ground = 0;
			Celestial = 0;
			Ice = 0;
		};
		Cat = {
			Normal = 0;
			Fire = 0;
			Water = 0;
			Light = 0;
			Ground = 0;
			Celestial = 0;
			Ice = 0;
		};
	};
	Sparks = 100;
	MaxSparks = 100;
	Ecus = 0;
	Feez = 0;
	Crystals = {
        NormalCrystal = 0;
        GroundCrystal = 0;
        FireCrystal = 0;
        IceCrystal = 0;
        LightCrystal = 0;
        WaterCrystal = 0;
        CelestialCrystal = 0;
    };
	BabyCreatureInNursery = 0;
	NurseryCollection = {}; --Index is id of mother creature and values are id creature father, baby name, time breedingvalue
	Reputation = 0;
	Ranking = 0;
	GenesCollection = {};
	CreaturesCollection = {};
	Inventory = {}; --here we have information about object in inventory of player use for instanciate at beginning of player connexion
	FavouritesCreatures = {
		Fav1 = "";
		Fav2 = "";
		Fav3 = "";
		Fav4 = "";
		Fav5 = "";
	};
	Farms = {};
	TotalHarvests = 0;
	Club = "";
	Achievements = {};
	Quests = {};
	DailyQuestAvailable = 3;
	DailyMaxQuest = {
		quest1 = 0,
		quest2 = 0,
		quest3 = 0,
	};
	LastDateConnexion = 0;
	PlayerSettings = {
		isSoundActivated = true,
	};
	FirstTime = true;
	CollectableLimit = {
	};
	SystemUnlocked = {
	};
	WorldTeleportUnlocked = {};
	NbMaxSlotsCreature = 20;
	LastCreatureSummoned = "";
}