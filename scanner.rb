require 'auction_house'
require 'snipe_presets'
require 'utilities'
include WowArmory::AuctionHouse::Utilities

def setup
	ah = WowArmory::AuctionHouse::Scanner.new
	if ah.login! then
		puts colorize("Logged in!", "1;32;40")
	else	
		puts colorize("Invalid credentials or Armory not available", "1;31;40")
		Kernel.exit
	end
	
	ah.flush_config
	return ah
end

ah = setup

if AUCTION_QUERIES.length == 0
	puts colorize("Failed to load any auction queries.", "1;31;40")
	return
else
	puts "Using queries: #{AUCTION_QUERIES.keys.join(", ")}"
end

ah.snipe(AUCTION_QUERIES)
