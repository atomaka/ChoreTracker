ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker', 'AceConsole-3.0', 'AceEvent-3.0')
local core = ChoreTracker
local LibQTip
local db

local trackedInstances = {
	['Baradin Hold'] = 'BH',
	['Firelands'] = 'FL',
	['The Bastion of Twilight'] = 'BoT',
	['Blackwing Descent'] = 'BWD',
	['Throne of the Four Winds'] = '4W',
}

local defaults = {
	global = {},
	--[[profile = {
		instances = {},
	},]]--
}

--local options_setter = function(info, v) local t=core.db.profile for k=1,#info-1 do t=t[info[k]] end t[info[#info]]=v end
--local options_getter = function(info) local t=core.db.profile for k=1,#info-1 do t=t[info[k]] end return t[info[#info]] end
--[[local options = {
	name = 'ChoreTracker',
	type = 'group',
	set = options_setter,
	get = options_getter,
	args = {
		enabled = {
			name = 'Toggle Instances',
			type = 'group',
			order = 10,
			args = {},
		}
	}
}]]--

local classColors = {}
local flagColors = {}

function core:OnInitialize()
	--prepare the database if necessary
	self.db = LibStub('AceDB-3.0'):New('ChoreTrackerDB', defaults, 'Default')
	
	local level = UnitLevel('player')
	local realm = GetRealmName()
	local name = UnitName('player')
	if self.db.global[realm] == nil then
		self.db.global[realm] = {}
	end
	
	if self.db.global[realm][name] == nil and level == 85 then
		self.db.global[realm][name] = {}
		
		local class = UnitClass('player')
		class = class:lower()
		if class == 'deathknight' then
			class = 'death knight'
		end
		
		self.db.global[realm][name].class = class
		self.db.global[realm][name].valorPoints = {
			valorPoints = 0,
			resetTime = 0,
		}
		self.db.global[realm][name].lockouts = {}
	end
	
	-- Generate our options and add them to Blizzard Interface
	--[[LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable('ChoreTracker', options)
	local ACD = LibStub('AceConfigDialog-3.0')
	ACD:AddToBlizOptions('ChoreTracker', 'ChoreTracker')]]--
end

function core:OnEnable()
	LibQTip = LibStub('LibQTip-1.0')

	self:RegisterChatCommand('ct', 'ViewChores');
	
	local level = UnitLevel('player')
	if level == 85 then
		self:RegisterEvent('UPDATE_INSTANCE_INFO', 'UpdateChores')
		self:RegisterEvent('CALENDAR_UPDATE_EVENT_LIST', 'UpdateChores')
		self:RegisterEvent('CHAT_MSG_CURRENCY', 'UpdateChores')
		--self:RegisterEvent('PLAYER_LEAVING_WORLD', 'UpdateChores')
		
	end
	LoadAddOn("Blizzard_Calendar")
	
	
	
	core:CreateChoreFrame()
	
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
	
	--reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()
end

function core:ViewChores()

end

function core:UpdateChores()
	--reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()

	local realm = GetRealmName()
	local name = UnitName('player')
	
	local vpReset = core:GetNextVPReset()
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)

	--store Valor Points
	if vpReset ~= nil then
		self.db.global[realm][name].valorPoints = {}
		self.db.global[realm][name].valorPoints.points = earnedThisWeek
		self.db.global[realm][name].valorPoints.resetTime = vpReset
	end

	--store Saved Instances
	local savedInstances = GetNumSavedInstances()
	for i = 1, savedInstances do
		local instanceName, _, instanceReset, _, _, _, _, _, _, _, _, defeatedBosses = GetSavedInstanceInfo(i)
		
		if trackedInstances[instanceName] ~= nil then
			if instanceReset > 0 then
				self.db.global[realm][name].lockouts[instanceName] = {}
				self.db.global[realm][name].lockouts[instanceName].defeatedBosses = defeatedBosses
				self.db.global[realm][name].lockouts[instanceName].resetTime = time() + instanceReset
			else
				self.db.global[realm][name].lockouts[instanceName] = nil
			end
		end
	end
end

function core:ResetInstances()
	for realm,realmTable in pairs(self.db.global) do
		for name in pairs(realmTable) do
			for instance,instanceTable in pairs(self.db.global[realm][name].lockouts) do
				if instanceTable.resetTime < time() then
					self.db.global[realm][name].lockouts[instance] = nil
				end
			end
		end
	end
end

function core:ResetValorPoints()
	for realm,realmTable in pairs(self.db.global) do
		for name in pairs(realmTable) do
			if self.db.global[realm][name].valorPoints.resetTime < time() then
				self.db.global[realm][name].valorPoints = {
					valorPoints = 0,
					resetTime = 0,					
				}
			end
		end
	end
end

function core:GetNextVPReset()
	--prepare calendar
	local currentCalendarSetting = GetCVar('calendarShowResets') -- get current value and store
	SetCVar('calendarShowResets', 1) -- set it to what we want

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

			if title == 'Baradin Hold' then
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
	SetCVar('calendarShowResets', currentCalendarSetting)
	
	--and combine for the reset timestamp
	if(resetDate ~= nil) then
		resetDate.hour = resetTime.hour
		resetDate.min = resetTime.min
		resetDate.sec = resetTime.sec

		return time(resetDate)
	else
		return nil
	end
end

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
		self.tooltip:SetCell(1, nextColumn, abbreviation, nil, 'CENTER')
		nextColumn = nextColumn + 1
	end
	
	for realm in pairs(self.db.global) do
		for name in pairs(self.db.global[realm]) do
			local characterLine = self.tooltip:AddLine('')
			local class = self.db.global[realm][name].class
			self.tooltip:SetCell(characterLine, 1, name, classColors[class], 'LEFT')
			
			local valorPoints, valorPointColor
			valorPoints = self.db.global[realm][name].valorPoints.points
			if valorPoints == nil then
				valorPoints = 0
			end
			if valorPoints == 980 then
				valorPointColor = flagColors['red']
			else
				valorPointColor = flagColors['green']
			end
			self.tooltip:SetCell(characterLine, 2, valorPoints, valorPointColor, 'RIGHT')
			
			local nextColumn = 3
			for instance,abbreviation in pairs(trackedInstances) do
				if self.db.global[realm][name].lockouts[instance] ~= nil then
					local defeatedBosses = self.db.global[realm][name].lockouts[instance].defeatedBosses
					self.tooltip:SetCell(characterLine, nextColumn, defeatedBosses, flagColors['red'], 'RIGHT')
				else
					self.tooltip:SetCell(characterLine, nextColumn, '0', flagColors['green'], 'RIGHT')
				end
				nextColumn = nextColumn + 1
			end
		end
	end
	
	self.tooltip:SmartAnchorTo(self)
	self.tooltip:Show()
end

local function anchor_OnLeave(self)
	LibQTip:Release(self.tooltip)
	self.tooltip = nil
end

function core:CreateChoreFrame()
	local ChoresDisplay = CreateFrame('Frame', 'ChoreTrackerFrame', UIParent)
	ChoresDisplay:SetPoint('TOPLEFT')
	ChoresDisplay.background = ChoresDisplay:CreateTexture(nil, 'BACKGROUND')
	ChoresDisplay.background:SetAllPoints(true)
	ChoresDisplay.background:SetTexture('Interface\\AddOns\\ChoreTracker\\icon')
	ChoresDisplay:SetHeight(32)
	ChoresDisplay:SetWidth(32)
	ChoresDisplay:Show()
	
	ChoresDisplay:EnableMouse(true)
	ChoresDisplay:SetMovable(true)
	ChoresDisplay:RegisterForDrag('LeftButton')
	
	ChoresDisplay:SetScript('OnDragStart', ChoresDisplay.StartMoving)
	ChoresDisplay:SetScript('OnDragStop', ChoresDisplay.StopMovingOrSizing)
	ChoresDisplay:SetScript('OnHide', ChoresDisplay.StopMovingOrSizing)
	ChoresDisplay:SetScript('OnEnter', anchor_OnEnter)
	ChoresDisplay:SetScript('OnLeave', anchor_OnLeave)
end