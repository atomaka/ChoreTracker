ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker', 'AceConsole-3.0', 'AceEvent-3.0')
local core = ChoreTracker
local LQT
local db
local LDB
local LDBIcon
local tooltip
local LBZ
local zones
local trackedInstances
local vpResetTime

local defaults = {
	global = {},
	profile = {
		minimap = {
			hide = false,
		},
		instances = {},
	},
}

local options = {
	name = 'ChoreTracker',
	type = 'group',
	args = {
		minimap = {
			name = 'Hide Minimap Icon',
			desc = 'Removes the icon from your minimap.',
			type = 'toggle',
			get = function(info) return core.db.profile.minimap.hide end,
			set = function(info, value) core.db.profile.minimap.hide = value core.LDBIcon[value and 'Hide' or 'Show'](core.LDBIcon, 'ChoreTracker') end,
		}
	}
}

local classColors = {}
local flagColors = {}

function core:OnInitialize()
	-- Prepare the database if necessary
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
	
	-- Register events (here for now; track data regardless of whether it is displayed?)
	local level = UnitLevel('player')
	if level == 85 then
		self:RegisterEvent('CALENDAR_UPDATE_EVENT_LIST','GetNextVPReset')
		self:RegisterEvent('UPDATE_INSTANCE_INFO', 'UpdateChores')
		self:RegisterEvent('CHAT_MSG_CURRENCY', 'UpdateChores')
	end
end

function core:OnEnable()
	LQT = LibStub('LibQTip-1.0')
	LBZ = LibStub('LibBabble-Zone-3.0')

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
	
	-- Setup LDB
	self.LDB = LibStub('LibDataBroker-1.1'):NewDataObject('ChoreTracker', {
		type = 'data source',
		text = 'ChoreTracker',
		icon = 'Interface\\AddOns\\ChoreTracker\\icon',
		OnClick = function() LibStub("AceConfigDialog-3.0"):Open("ChoreTracker") end,
		OnEnter = function(self) 
			local columnCount = 2
			for instance,abbreviation in pairs(trackedInstances) do
				columnCount = columnCount + 1
			end
			tooltip =  LQT:Acquire('ChoreTrackerTooltip', columnCount, 'LEFT', 'CENTER', 'RIGHT') 
			
			core:DrawTooltip()
			
			tooltip:SmartAnchorTo(self) 
			tooltip:Show() 
		end,
		OnLeave = function(self) 
			LQT:Release(tooltip) 
			tooltip = nil 
		end,		
	})
	
	-- Deal with minimap
	self.LDBIcon = LibStub('LibDBIcon-1.0')
	self.LDBIcon:Register('ChoreTracker', self.LDB, self.db.profile.minimap)
	
	if self.db.profile.minimap.hide then
		self.LDBIcon:Hide('ChoreTracker')
	else
		self.LDBIcon:Show('ChoreTracker')
	end
	
	-- Get instances
	zones = LBZ:GetLookupTable()
	
	trackedInstances = {
		[zones['Baradin Hold']] = 'BH',
		[zones['Firelands']] = 'FL',
		[zones['The Bastion of Twilight']] = 'BoT',
		[zones['Blackwing Descent']] = 'BWD',
		[zones['Throne of the Four Winds']] = '4W',
	}
	
	-- Add options to Interface Panel
	LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable('ChoreTracker', options)
	local ACD = LibStub('AceConfigDialog-3.0')
	ACD:AddToBlizOptions('ChoreTracker', 'ChoreTracker')
end

function core:UpdateChores()
	--reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()

	local realm = GetRealmName()
	local name = UnitName('player')
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)

	--store Valor Points
	if vpReset ~= nil then
		self.db.global[realm][name].valorPoints = {}
		self.db.global[realm][name].valorPoints.points = earnedThisWeek
		self.db.global[realm][name].valorPoints.resetTime = vpResetTime
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

			if title == zones['Baradin Hold'] then
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

		vpResetTime = time(resetDate)
	else
		vpResetTime = nil
	end
end

function core:DrawTooltip()
	--create the tooltip header
	tooltip:AddHeader('')
	local valorPointColumn = tooltip:AddColumn('LEFT')
	tooltip:SetCell(1, 1, '')
	tooltip:SetCell(1, 2, 'VP')
	local nextColumn = 3
	for instance,abbreviation in pairs(trackedInstances) do
		tooltip:SetCell(1, nextColumn, abbreviation, nil, 'CENTER')
		nextColumn = nextColumn + 1
	end
	
	for realm in pairs(self.db.global) do
		for name in pairs(self.db.global[realm]) do
			local characterLine = tooltip:AddLine('')
			local class = self.db.global[realm][name].class
			tooltip:SetCell(characterLine, 1, name, classColors[class], 'LEFT')
			
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
			tooltip:SetCell(characterLine, 2, valorPoints, valorPointColor, 'RIGHT')
			
			local nextColumn = 3
			for instance,abbreviation in pairs(trackedInstances) do
				if self.db.global[realm][name].lockouts[instance] ~= nil then
					local defeatedBosses = self.db.global[realm][name].lockouts[instance].defeatedBosses
					tooltip:SetCell(characterLine, nextColumn, defeatedBosses, flagColors['red'], 'RIGHT')
				else
					tooltip:SetCell(characterLine, nextColumn, '0', flagColors['green'], 'RIGHT')
				end
				nextColumn = nextColumn + 1
			end
		end
	end
end