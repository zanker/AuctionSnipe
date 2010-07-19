AUCTION_TYPES = {:faction => 1, :neutral => 2}
AUCTION_NAMES = {1 => "faction", 2 => "neutral"}

#{"auc":852360063,"n":"Accurate Ametrine","icon":"inv_jewelcrafting_gem_39","buy":746000,"bid":745000,"nbid":745000,"seller":"Porps","time":2,"id":40162,"qual":4,"quan":1,"req":1,"ilvl":80,"seed":1818733184,"charges":0}
AUCTION_QUERIES = {
	"Epics" => {
		:requires => 'auction["buy"] <= 50000 && ( env_tbl.include?(auction["n"]) || ( auction["qual"] >= 4 && ( auction["ilvl"] >= 80 || auction["ilvl"] <= 60 ) ) )',
		:env_tbl => ["Parrot Cage (Green Wing Macaw)", "Mulgore Hatchling", "Ammen Vale Lashling", "Durator Scorpion", "Elwynn Lamb", "Enchanted Broom", "Mechanopeep", "Sen'jin Fetish", "Teldrassil Sproutling", "Tirisfal Batling", "Captured Firefly", "Cat Carrier (White Kitten)", "Cat Carrier (Black Tabby)", "Dark Whelpling", "Darting Hatchling", "Deviate Hatchling", "Disgusting Oozling", "Gundrak Hatchling", "Leaping Hatchling", "Lil' Smoky", "Lifelike Mechanical Toad", "Mechanical Chicken", "Mechanical Squirrel Box", "Pet Bombling", "Ravasaur Hatchling", "Razormaw Hatchling", "Razzashi Hatchling", "Tiny Crimson Whelpling", "y Emerald Whelpling", "Cobra Hatchling", "X-51 Nether-Rocket X-TREME", "Teebu's Blazing Longsword", "Abyssal Scepter", "Big Battle Bear", "Battered Hilt", "Parrot Cage (Hyacinth Macaw)", ""],
		#:filters => {"qual" => 4},
		:blacklist => ["Nexus Crystal", "Iceblade Arrow", "Void Crystal", "Mysterious Arrow", "The Macho Gnome's Arrow", "Timeless Arrow", "Mysterious Shell", "Shatter Rounds", "The Sarge's Bullet", "Timeless Shell", "Staff of Jordan", "Fiery War Axe"],
		:run_at => AUCTION_TYPES[:neutral],
	},
	#{
	#	:name => "Pets",
	#	:requires => 'auction["buy"] <= 50000',
	#	:filters => {"filterId" => "10%2C91", "qual" => 0}, # Should be Misc -> Pets
	#	:only_at => AUCTION_TYPES[:neutral],
	#},
}