ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker', 'AceConsole-3.0', 'AceEvent-3.0')
local core = ChoreTracker
local LibQTip

local trackedInstances = {
	['Baradin Hold'] = 'BH',
	['Firelands'] = 'FL',
}

local defaults = {
	global = {
		classes = {},
		valorPoints = {},
		lockouts = {},
	}
}

local classColors = {}
local flagColors = {}

local function anchor_OnEnter(self)
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB', defaults, 'Default')
	local columnCount = 2
	for instance,abbreviation in pairs(trackedInstances) do
		columnCount = columnCount + 1
	end
	
	self.tooltip =  LibQTip:Acquire('ChoreTrackerTooltip', columnCount, 'LEFT', 'CENTER', 'RIGHT')

	--create the tooltip header
	self.tooltip:AddHeader('')
	local valorPointColumn = self.tooltip:AddColumn('LEFT')
	self.tooltip:SetCell(1, 1, '')
	self.tooltip:SetCell(1, 2, 'VP')
	local nextColumn = 3
	for instance,abbreviation in pairs(trackedInstances) do
		self.tooltip:SetCell(1, nextColumn, abbreviation, nil, 'LEFT')
		nextColumn = nextColumn + 1
	end
	--go through all stored raiders
	for character,instancesTable in pairs(self.db.global.lockouts) do
		local characterLine = self.tooltip:AddLine('')

		local class = self.db.global.classes[character]
		self.tooltip:SetCell(characterLine, 1, character, classColors[class], 'LEFT')
		
		local valorPointColor,valorPoints
		if self.db.global.valorPoints[character] == nil then
			valorPoints = 0
		else
			valorPoints = self.db.global.valorPoints[character].points
		end
		
		if valorPoints == 980 then
			valorPointColor = flagColors['red']
		else
			valorPointColor = flagColors['green']
		end
		self.tooltip:SetCell(characterLine, 2, valorPoints, valorPointColor, 'LEFT')
		
		local nextColumn = 3
		for instance,abbreviation in pairs(trackedInstances) do
			if self.db.global.lockouts[character][instance] ~= nil then
				self.tooltip:SetCell(characterLine, nextColumn, self.db.global.lockouts[character][instance].defeatedBosses, flagColors['red'], 'LEFT')
			else
				self.tooltip:SetCell(characterLine, nextColumn, '0', flagColors['green'], 'LEFT')
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
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB', defaults, 'Default')
	
	local ChoresDisplay = CreateFrame('Frame', 'ChoreTrackerFrame', UIParent)
	ChoresDisplay:SetPoint('TOPLEFT')
	ChoresDisplay.background = ChoresDisplay:CreateTexture(nil, 'BACKGROUND')
	ChoresDisplay.background:SetAllPoints(true)
	ChoresDisplay.background:SetTexture(1, 0.5, 0, 0.5)
	ChoresDisplay:SetHeight(50)
	ChoresDisplay:SetWidth(50)
	ChoresDisplay:Show()
	
	ChoresDisplay:EnableMouse(true)
	ChoresDisplay:SetMovable(true)
	ChoresDisplay:RegisterForDrag('LeftButton')
	
	ChoresDisplay:SetScript('OnDragStart', ChoresDisplay.StartMoving)
	ChoresDisplay:SetScript('OnDragStop', ChoresDisplay.StopMovingOrSizing)
	ChoresDisplay:SetScript('OnHide', ChoresDisplay.StopMovingOrSizing)
	ChoresDisplay:SetScript('OnEnter', anchor_OnEnter)
	ChoresDisplay:SetScript('OnLeave', anchor_OnLeave)
	
	for class,color in pairs(RAID_CLASS_COLORS) do
		class = class:lower()
		if class == 'deathknight' then
			class = 'death knight'
		end
		
		classColors[class] = CreateFont('ClassFont' .. class)
		classColors[class]:CopyFontObject(GameTooltipText)
		classColors[class]:SetTextColor(color.r, color.g, color.b)
	end
	
	flagColors['green'] = CreateFont('FlagFontGreen')
	flagColors['green']:CopyFontObject(GameTooltipText)
	flagColors['green']:SetTextColor(0, 255, 0)
	
	flagColors['red'] = CreateFont('FlagFontRed')
	flagColors['red']:CopyFontObject(GameTooltipText)
	flagColors['red']:SetTextColor(255, 0, 0)
end

function core:OnEnable()
	LibQTip = LibStub('LibQTip-1.0')
	local name = UnitName('player')

	if self.db.global.lockouts[name] == nil then
		self.db.global.lockouts[name] = {}
	end
	if self.db.global.valorPoints[name] == nil then
		self.db.global.valorPoints[name] = {}
	end
	
	self:RegisterChatCommand('ct', 'ViewChores');
	self:RegisterEvent('UPDATE_INSTANCE_INFO', 'UpdateChores')
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
		
		--set class if not already set
		local class = UnitClass('player')
		self.db.global.classes[name] = class:lower()
		local vpReset = core:GetNextVPReset()
		
		--store Valor Points
		self.db.global.valorPoints[name] = {}
		self.db.global.valorPoints[name].points = earnedThisWeek
		self.db.global.valorPoints[name].resetTime = vpReset

		--store Saved Instances
		local savedInstances = GetNumSavedInstances()
		for i = 1, savedInstances do
			local instanceName, _, instanceReset, _, _, _, _, _, _, _, _, defeatedBosses = GetSavedInstanceInfo(i)
			
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
	for k,v in pairs(self.db.global.valorPoints) do
		if v.resetTime ~= nil then 
			if v.resetTime < time() then
				self.db.global.valorPoints[k] = nil
			end
		end
	end
end

function core:GetNextVPReset()
	--prepare calendar
	local currentCalendarSetting = GetCVar('calendarShowResets') -- get current value and store
	SetCVar('calendarShowResets',1) -- set it to what we want

	--figure out what time the server resets daily information
	local questReset = GetQuestResetTime()
	local resetTime = date('*t', time() + questReset)
	
	--figure out reset day using next BH lockout
	local _, month, day, year = CalendarGetDate()
	
	local monthOffset = 0
	local resetDate = nil
	while resetDate == nil do
		local todaysEvents = CalendarGetNumDayEvents(monthOffset, day)

		for i = 1,todaysEvents do
			if todaysEvents == 0 then 
				break 
			end

			local title,hour,minute = CalendarGetDayEvent(monthOffset, day, i)

			if(title == 'Baradin Hold') then
				resetDate = { year = year, month = month + monthOffset, day = day }
			end
		end
		
		day = day + 1
		if day > 31 then
			if monthOffset == 1 then break end
			day = 1
			monthOffset = 1
		end
	end
	
	--return calendar
	SetCVar('calendarShowResets',currentCalendarSetting)
	
	--and combine for the reset timestamp
	resetDate.hour = resetTime.hour
	resetDate.min = resetTime.min
	resetDate.sec = resetTime.sec

	return time(resetDate)
end