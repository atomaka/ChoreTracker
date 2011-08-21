ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker','AceConsole-3.0','AceEvent-3.0')
local core = ChoreTracker

local trackedInstances = {
	['Baradin Hold'] = true,
	['Firelands'] = true,
}


local defaults = {
	profile = {
		valorPoints = {},
		lockouts = {},
		updated = {},
	}
}

function core:OnInitialize()	
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB',defaults,'Default')
end

function core:OnEnable()
	local name = UnitName('player')

	if self.db.profile.lockouts[name] == nil then
		self.db.profile.lockouts[name] = {}
	end
	
	self:RegisterEvent('UPDATE_INSTANCE_INFO','StoreChores')
end

function core:StoreChores()
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)
	local name = UnitName('player')
	local level = UnitLevel('player')
	
	if(level == 85) then
		self.db.profile.valorPoints[name] = earnedThisWeek

		local savedInstances = GetNumSavedInstances()
		
		for i = 0, savedInstances do
			local instanceName,_,instanceReset,_,_,_,_,_,_,_,_,defeatedBosses = GetSavedInstanceInfo(i)
			
			if trackedInstances[instanceName] == true then	
				if instanceReset > 0 then
					self.db.profile.lockouts[name][instanceName] = defeatedBosses
				else
					self.db.profile.lockouts[name][instanceName] = nil
				end
			end
		end
		
	end
end