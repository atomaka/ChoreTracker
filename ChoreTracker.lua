ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker','AceConsole-3.0','AceEvent-3.0')
local LibQTip = LibStub('LibQTip-1.0')
local core = ChoreTracker

local trackedInstances = {
	['Baradin Hold'] = 'BH',
	['Firelands'] = 'FL',
}


local defaults = {
	global = {
		valorPoints = {},
		lockouts = {},
	}
}

local function anchor_OnEnter(self)
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB',defaults,'Default')
	local columnCount = 2
	for instance,abbreviation in pairs(trackedInstances) do
		columnCount = columnCount + 1
	end
	
	self.tooltip =  LibQTip:Acquire('ChoreTrackerTooltip',columnCount,'LEFT','CENTER','RIGHT')

	--create the tooltip header
	self.tooltip:AddHeader('')
	local valorPointColumn = self.tooltip:AddColumn('LEFT')
	self.tooltip:SetCell(1,1,'Chore')
	self.tooltip:SetCell(1,2,'VP')
	local nextColumn = 3
	for instance,abbreviation in pairs(trackedInstances) do
		self.tooltip:SetCell(1,nextColumn,abbreviation,nil,'LEFT')
		nextColumn = nextColumn + 1
	end
	--go through all stored raiders
	for character,instancesTable in pairs(self.db.global.lockouts) do
		local characterLine = self.tooltip:AddLine('')
		self.tooltip:SetCell(characterLine,1,character,nil,'LEFT')
		self.tooltip:SetCell(characterLine,2,self.db.global.valorPoints[character],nil,'LEFT')
		
		local nextColumn = 3
		for instance,abbreviation in pairs(trackedInstances) do
			if self.db.global.lockouts[character][instance] ~= nil then
				self.tooltip:SetCell(characterLine,nextColumn,self.db.global.lockouts[character][instance].defeatedBosses,nil,'LEFT')
			else
				self.tooltip:SetCell(characterLine,nextColumn,'0',nil,'LEFT')
			end
			nextColumn = nextColumn + 1
		end
	end
	
	self.tooltip:SmartAnchorTo(self)
	self.tooltip:Show()
end

local function anchor_OnLeave(self)
	LibQTip:Release(self.tooltip)
	self.tooltip = nil
end

function core:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB',defaults,'Default')
	
	local ChoresDisplay = CreateFrame('Frame','ChoreTrackerFrame',UIParent)
	ChoresDisplay:SetPoint('CENTER')
	ChoresDisplay.background = ChoresDisplay:CreateTexture(nil,'BACKGROUND')
	ChoresDisplay.background:SetAllPoints(true)
	ChoresDisplay.background:SetTexture(1,0.5,0,0.5)
	ChoresDisplay:SetHeight(50)
	ChoresDisplay:SetWidth(50)
	ChoresDisplay:Show()
	
	self.ChoresDisplay = ChoresDisplay
	
	ChoresDisplay:SetScript('OnEnter', anchor_OnEnter)
	ChoresDisplay:SetScript('OnLeave', anchor_OnLeave)
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
			
			if trackedInstances[instanceName] ~= nil then
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