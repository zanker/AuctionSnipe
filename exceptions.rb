module WowArmory
	# Armory is under maintenance
	class ArmoryMaintenanceError < RuntimeError; end
	
	# Raised when the armory is temporarily unavailable
	class TemporarilyUnavailableError < RuntimeError; end
end
