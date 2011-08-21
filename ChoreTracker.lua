ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker','AceConsole-3.0','AceEvent-3.0')
local core = ChoreTracker

local defaults = {
	profile = {
		valorPoints = {},
		lockouts = {},
	}
}

function core:OnInitialize()	
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB',defaults,'Default')
end

function core:OnEnable()
	self:RegisterEvent('PLAYER_ENTERING_WORLD','StoreValorPoints')
end

function core:StoreValorPoints()
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)
	local name = UnitName('player')
	local level = UnitLevel('player')
	
	if(level == 85) then
		self.db.profile.valorPoints[name] = earnedThisWeek
		print('Storing',earnedThisWeek,'for',name)
	end
end