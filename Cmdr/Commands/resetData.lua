return {
	Name = "reset";
	Aliases = {};
	Description = "Entirely reset a player's data";
	Args = {
		{
			Type = "string";
			Name = "username";
			Description = "The player's username";
			Optional = true;
		},
		{
			Type = "boolean";
			Name = "resetCurrency";
			Description = "Make yes or true for reset currency";
			Optional = true;
		},
	};
}