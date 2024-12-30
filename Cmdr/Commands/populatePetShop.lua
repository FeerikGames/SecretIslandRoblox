return {
	Name = "populatePetShop";
	Aliases = {};
	Description = "Allow to create creatures datas not link to a player for Pet Shop";
	Args = {
		{
			Type = "string";
			Name = "CreatureType";
			Description = "The type of creatures to populate : Cat or Horse. Or The name of Model in data to copy";
			Optional = false;
		},
		{
			Type = "number";
			Name = "HowMany";
			Description = "Number of type of this creature you need to populate PetShop or how many do you want to remove from Pet Shop";
			Optional = true;
		},
		{
			Type = "string";
			Name = "ModelID";
			Description = "The name of Model in data to copy";
			Optional = true;
		},
        {
			Type = "string";
			Name = "Remove";
			Description = "This attribute is for say if is remove call. Say Remove or RemoveAll";
			Optional = true;
		},
	};
}