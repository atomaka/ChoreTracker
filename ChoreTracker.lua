ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker', 'AceConsole-3.0', 'AceEvent-3.0')
local core = ChoreTracker
local LQT, LDB, LDBIcon, LBZ
local db, tooltip, zones, trackedInstances, vpResetTime

local defaults = {
	global = {},
	profile = {
		minimap = {
			hide = false,
		},
		sortType = 1,
		sortDirection = 1,
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
			get = function(info) return db.profile.minimap.hide end,
			set = function(info, value) db.profile.minimap.hide = value LDBIcon[value and 'Hide' or 'Show'](LDBIcon, 'ChoreTracker') end,
		},
		sortType = {
			name = 'Sort Field',
			desc = 'Field to sort the tooltip by.',
			type = 'select',
			values = { 'character', 'vp' },
			get = function(info) return db.profile.sortType end,
			set = function(info, value) db.profile.sortType = value end,
		},
		sortingDirection = {
			name = 'Sorting Direction',
			desc = 'Which direction to sort.',
			type = 'select',
			values = { 'ascending', 'descending' },
			get = function(info) return db.profile.sortDirection end,
			set = function(info, value) db.profile.sortDirection = value end,
		},
	}
}

local classColors = {}
local flagColors = {}

function core:OnInitialize()
	-- Prepare the database if necessary
	db = LibStub('AceDB-3.0'):New('ChoreTrackerDB', defaults, 'Default')
	
	local level = UnitLevel('player')
	local realm = GetRealmName()
	local name = UnitName('player')
	if db.global[realm] == nil then
		db.global[realm] = {}
	end
	
	if db.global[realm][name] == nil and level == 85 then
		db.global[realm][name] = {}
		
		local class = UnitClass('player')
		class = class:lower()
		if class == 'deathknight' then
			class = 'death knight'
		end
		
		db.global[realm][name].class = class
		db.global[realm][name].valorPoints = {
			valorPoints = 0,
			resetTime = 0,
		}
		db.global[realm][name].lockouts = {}
	end
	
	-- Register events (here for now; track data regardless of whether it is displayed?)
	local level = UnitLevel('player')
	if level == 85 then
		self:RegisterEvent('CALENDAR_UPDATE_EVENT_LIST','GetNextVPReset')
		self:RegisterEvent('UPDATE_INSTANCE_INFO', 'UpdateChores')
		self:RegisterEvent('CHAT_MSG_CURRENCY', 'UpdateChores')
	end
	
	-- Get calendar events information
	OpenCalendar()
	
	-- Reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()
end

function core:OnEnable()
	LQT = LibStub('LibQTip-1.0')
	LBZ = LibStub('LibBabble-Zone-3.0')

	-- Setup font strings for later.  (RAID_CLASS_COLORS always indexed in English?)
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
	
	-- Setup LDB
	LDB = LibStub('LibDataBroker-1.1'):NewDataObject('ChoreTracker', {
		type = 'data source',
		text = 'ChoreTracker',
		icon = 'Interface\\AddOns\\ChoreTracker\\icon',
		OnClick = function() 
				if LibStub("AceConfigDialog-3.0").OpenFrames['ChoreTracker'] then
					LibStub('AceConfigDialog-3.0'):Close('ChoreTracker')
				else
					LibStub('AceConfigDialog-3.0'):Open('ChoreTracker')
				end
		end,
		OnEnter = function(self)
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
	LDBIcon = LibStub('LibDBIcon-1.0')
	LDBIcon:Register('ChoreTracker', LDB, db.profile.minimap)
	
	if db.profile.minimap.hide then
		LDBIcon:Hide('ChoreTracker')
	else
		LDBIcon:Show('ChoreTracker')
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
	-- Reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()

	local realm = GetRealmName()
	local name = UnitName('player')
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)

	--store Valor Points
	if vpResetTime ~= nil then
		db.global[realm][name].valorPoints = {}
		db.global[realm][name].valorPoints.points = earnedThisWeek
		db.global[realm][name].valorPoints.resetTime = vpResetTime
	end

	--store Saved Instances
	local savedInstances = GetNumSavedInstances()
	for i = 1, savedInstances do
		local instanceName, _, instanceReset, _, _, _, _, _, _, _, _, defeatedBosses = GetSavedInstanceInfo(i)
		
		if trackedInstances[instanceName] ~= nil then
			if instanceReset > 0 then
				db.global[realm][name].lockouts[instanceName] = {}
				db.global[realm][name].lockouts[instanceName].defeatedBosses = defeatedBosses
				db.global[realm][name].lockouts[instanceName].resetTime = time() + instanceReset
			else
				db.global[realm][name].lockouts[instanceName] = nil
			end
		end
	end
end

function core:ResetInstances()
	for realm,realmTable in pairs(db.global) do
		for name in pairs(realmTable) do
			for instance,instanceTable in pairs(db.global[realm][name].lockouts) do
				if instanceTable.resetTime < time() then
					db.global[realm][name].lockouts[instance] = nil
				end
			end
		end
	end
end

function core:ResetValorPoints()
	for realm,realmTable in pairs(db.global) do
		for name in pairs(realmTable) do
			if db.global[realm][name].valorPoints.resetTime < time() then
				db.global[realm][name].valorPoints = {
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
	local columnCount = 2
	for instance,abbreviation in pairs(trackedInstances) do
		columnCount = columnCount + 1
	end
	tooltip =  LQT:Acquire('ChoreTrackerTooltip', columnCount, 'LEFT', 'CENTER', 'RIGHT') 

	-- Populate a table with the information we want for our tooltip
	local tooltipTable = {}
	for realm in pairs(db.global) do
		for name in pairs(db.global[realm]) do
			local valorPoints = db.global[realm][name].valorPoints.points
			local class = db.global[realm][name].class
			
			if valorPoints == nil then
				valorPoints = 0
			end
			local characterTable = { name = name, realm = realm, class = class, valorPoints = valorPoints }
			
			for instance in pairs(trackedInstances) do
				local defeatedBosses
				if db.global[realm][name].lockouts[instance] ~= nil then
					defeatedBosses = db.global[realm][name].lockouts[instance].defeatedBosses
				else
					defeatedBosses = 0
				end
				characterTable[instance] = defeatedBosses
			end
			
			table.insert(tooltipTable,characterTable)
		end
	end
	
	local sortTooltip = function(a, b)
		if db.profile.sortType == 1 then
			if db.profile.sortDirection == 1 then
				return a.name:lower() < b.name:lower()
			else
				return a.name:lower() > b.name:lower()
			end
		elseif db.profile.sortType == 2 then
			if db.profile.sortDirection == 1 then
				return a.valorPoints < b.valorPoints
			else
				return a.valorPoints > b.valorPoints
			end
		end
	end
		
	-- Sort by name for now
	table.sort(tooltipTable, sortTooltip )
	
	
	-- Draw the tooltip
	tooltip:AddHeader('')
	tooltip:SetScale(1)
	local valorPointColumn = tooltip:AddColumn('LEFT')
	tooltip:SetCell(1, 1, '')
	tooltip:SetCell(1, 2, 'VP')
	local nextColumn = 3
	for instance,abbreviation in pairs(trackedInstances) do
		tooltip:SetCell(1, nextColumn, abbreviation, nil, 'CENTER')
		nextColumn = nextColumn + 1
	end
	
	for _,information in pairs(tooltipTable) do
		local characterLine = tooltip:AddLine('')
		tooltip:SetCell(characterLine, 1, information.name, classColors[information.class], 'LEFT')
		
		local valorPointColor
		if information.valorPoints == 980 then
			valorPointColor = flagColors['red']
		else
			valorPointColor = flagColors['green']
		end
		tooltip:SetCell(characterLine, 2, information.valorPoints, valorPointColor, 'RIGHT')
		
		local nextColumn = 3
		for instance, abbreviation in pairs(trackedInstances) do
			local instanceColor
			if information[instance] == 0 then
				instanceColor = flagColors['green']
			else
				instanceColor = flagColors['red']
			end
			tooltip:SetCell(characterLine, nextColumn, information[instance], instanceColor, 'RIGHT')
			
			nextColumn = nextColumn + 1
		end
	end
end