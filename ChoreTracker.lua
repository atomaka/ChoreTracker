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
	}
}

function core:OnInitialize()	
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB',defaults,'Default')
end

function core:OnEnable()
	local name = UnitName('player')

	if self.db.global.lockouts[name] == nil then
		self.db.global.lockouts[name] = {}
	end
	
	self:RegisterChatCommand('ct','ViewChores');
	self:RegisterEvent('UPDATE_INSTANCE_INFO','UpdateChores')
end

function core:ViewChores()
	for k,v in pairs(self.db.global.valorPoints) do
		print(k,'has',v,'Valor Points this week.')
	end
end

function core:UpdateChores()
	--print('Updating Chores.')
	local level = UnitLevel('player')
	
	if(level == 85) then
		local _,_,_,earnedThisWeek = GetCurrencyInfo(396)
		local name = UnitName('player')
		
		--reset data if necessary
		core:ResetInstances()
		core:ResetValorPoints()
		
		--store Valor Points
		--print('Storing',earnedThisWeek,'Valor points for',name)
		self.db.global.valorPoints[name] = earnedThisWeek

		--store Saved Instances
		--print('Storing instances for',name)
		local savedInstances = GetNumSavedInstances()
		for i = 1, savedInstances do
			local instanceName,_,instanceReset,_,_,_,_,_,_,_,_,defeatedBosses = GetSavedInstanceInfo(i)
			
			if trackedInstances[instanceName] == true then	
				if instanceReset > 0 then
					--print('Saving',instanceName,'with',defeatedBosses,'defeated bosses for',name)
					self.db.global.lockouts[name][instanceName] = {}
					self.db.global.lockouts[name][instanceName].defeatedBosses = defeatedBosses
					self.db.global.lockouts[name][instanceName].resetTime = time() + instanceReset
				else
					--print('Resetting',instanceName,'for',name)
					self.db.global.lockouts[name][instanceName] = nil
				end
			end
		end
		
	end
end

function core:ResetInstances()
	for k,v in pairs(self.db.global.lockouts) do
		for x,y in pairs(self.db.global.lockouts[k]) do
			--print('Comparing',x,'for',k,':',y.resetTime,'<',time())
			if y.resetTime < time() then
				--print('Passed resetTime for',k,x)
				--self.db.global.lockouts[k][x] = nil
			end
		end
	end
end

function core:ResetValorPoints()

end