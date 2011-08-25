ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker','AceConsole-3.0','AceEvent-3.0')
local core = ChoreTracker

local trackedInstances = {
	['Baradin Hold'] = true,
	['Firelands'] = true,
}


local defaults = {
	global = {
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
	local ChoresDisplay = CreateFrame('Frame','ChoreTrackerFrame',UIParent)
	ChoresDisplay:SetPoint('CENTER')
	ChoresDisplay:EnableMouse(true)
	ChoresDisplay:SetMovable(true)
	ChoresDisplay:RegisterForDrag('LeftButton')
	
	ChoresDisplay:SetScript('OnDragStart',ChoresDisplay.StartMoving)
	ChoresDisplay:SetScript('OnDragStop',ChoresDisplay.StopMovingOrSizing)
	ChoresDisplay:SetScript('OnHide',ChoresDisplay.StopMovingOrSizing)
	
	ChoresDisplay.background = ChoresDisplay:CreateTexture(nil,'BACKGROUND')
	ChoresDisplay.background:SetAllPoints(true)
	ChoresDisplay.background:SetTexture(1,0.5,0,0.5)
	
	ChoresDisplay.lines = {}
	local lineCount = 1
	for k,v in pairs(self.db.global.valorPoints) do
		local line = ChoresDisplay:CreateFontString(nil,'OVERLAY','GameFontNormal')
		ChoresDisplay.lines[lineCount] = line
		
		if lineCount > 1 then
			line:SetPoint('TOPLEFT',ChoresDisplay.lines[lineCount - 1],'BOTTOMLEFT',0,0)
			line:SetPoint('TOPRIGHT',ChoresDisplay.lines[lineCount - 1],'BOTTOMRIGHT',0,0)
		else
			line:SetPoint('TOPLEFT',ChoresDisplay,'TOPLEFT',5,-5)
			line:SetPoint('TOPRIGHT',ChoresDisplay,'TOPRIGHT',5,-5)
		end
		
		line:SetFormattedText("%s - %d",k,v)
		lineCount = lineCount + 1
	end
	
	local height = select(2,GameFontNormal:GetFont())
	ChoresDisplay:SetHeight(height * lineCount)
	ChoresDisplay:SetWidth(300)
	
	ChoresDisplay:Show()
end

function core:UpdateChores()
	local level = UnitLevel('player')
	
	--reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()
	
	if(level == 85) then
		local _,_,_,earnedThisWeek = GetCurrencyInfo(396)
		local name = UnitName('player')
		
		--store Valor Points
		self.db.global.valorPoints[name] = earnedThisWeek

		--store Saved Instances
		local savedInstances = GetNumSavedInstances()
		for i = 1, savedInstances do
			local instanceName,_,instanceReset,_,_,_,_,_,_,_,_,defeatedBosses = GetSavedInstanceInfo(i)
			
			if trackedInstances[instanceName] == true then	
				if instanceReset > 0 then
					self.db.global.lockouts[name][instanceName] = {}
					self.db.global.lockouts[name][instanceName].defeatedBosses = defeatedBosses
					self.db.global.lockouts[name][instanceName].resetTime = time() + instanceReset
				else
					self.db.global.lockouts[name][instanceName] = nil
				end
			end
		end
		
	end
end

function core:ResetInstances()
	for k,v in pairs(self.db.global.lockouts) do
		for x,y in pairs(self.db.global.lockouts[k]) do
			if y.resetTime < time() then
				self.db.global.lockouts[k][x] = nil
			end
		end
	end
end

function core:ResetValorPoints()

end