return {
	Name = "addCrystals";
	Aliases = {};
	Description = "Add amount of type Crystal give in parameter";
	Args = {
		{
			Type = "string";
			Name = "TypeOfCrystal";
			Description = "Give name of type Crystal want add like Fire, Water, Normal, Ground, Light, Celestial, Ice OR ALL for get all crystal";
		},
        {
			Type = "integer";
			Name = "quantity";
			Description = "Give quantity of adding crystal type you want";
		},
	};
}