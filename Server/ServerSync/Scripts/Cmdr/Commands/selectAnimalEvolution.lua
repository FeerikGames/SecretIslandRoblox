return {
	Name = "selectAnimalEvolution";
	Aliases = {};
	Description = "Make evolution needed for your summoned Animal !";
	Args = {
        {
			Type = "string";
			Name = "evolution";
			Description = "Evolution : Normal, Ground, Fire, Ice, Light, Water, Celestial";
		},
		{
			Type = "string";
			Name = "username";
			Description = "The player's username";
			Optional = true;
		},
	};
}