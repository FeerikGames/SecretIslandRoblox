return {
	Name = "addNewTalent";
	Aliases = {};
	Description = "Add a talent or random talent to actual summonned Animal";
	Args = {
		{
			Type = "string";
			Name = "talentName";
			Description = "Adding this talent to animal";
            Optional = true;
		},
	};
}