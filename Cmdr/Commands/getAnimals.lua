return {
	Name = "getAnimals";
	Aliases = {};
	Description = "Get a supranimals of type wanted";
	Args = {
		{
			Type = "string";
			Name = "type";
			Description = "The name of type animals needed (Cat or Horse)";
		},
		{
			Type = "boolean";
			Name = "pretty";
			Description = "true or false for make a pretty animals";
		},
	};
}