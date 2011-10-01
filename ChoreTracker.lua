ChoreTracker = LibStub('AceAddon-3.0'):NewAddon('ChoreTracker', 'AceConsole-3.0', 'AceEvent-3.0')
local core = ChoreTracker
local LQT, LDB, LDBIcon, LBZ
local db, tooltip, vpResetTime
local fontObjects = { }

-- Localization
local L = LibStub('AceLocale-3.0'):GetLocale('ChoreTracker')

-- Get localized instances
LBZ = LibStub('LibBabble-Zone-3.0')
local Z = LBZ:GetLookupTable()

local defaults = {
	global = {},
	profile = {
		minimap = {
			hide = false,
		},
		sortType = 1,
		sortDirection = 1,
		currentOnTop = false,
		instances = {
			[Z['Baradin Hold']] = { abbreviation = 'BH', enable = true, removed = false, }, 
			[Z['Firelands']] = { abbreviation = 'FL', enable = true, removed = false, }, 
			[Z['The Bastion of Twilight']] = { abbreviation = 'BoT', enable = true, removed = false, }, 
			[Z['Blackwing Descent']] = { abbreviation = 'BWD', enable = true, removed = false, }, 
			[Z['Throne of the Four Winds']] = { abbreviation = '4W', enable = true, removed = false, }, 
		},
	},
}

local options = {
	name = 'ChoreTracker',
	type = 'group',
	args = {
		general = {
			name = L['Settings'],
			type = 'group',
			order = 1,
			args = {
				minimap = {
					name = L['Hide Minimap Icon'],
					desc = L['Removes the icon from your minimap.'],
					type = 'toggle',
					order = 1,
					get = function(info) return db.profile.minimap.hide end,
					set = function(info, value) db.profile.minimap.hide = value LDBIcon[value and 'Hide' or 'Show'](LDBIcon, 'ChoreTracker') end,
				},
				verticalHeader = {
					name = L['Vertical Sorting'],
					type = 'header',
					order = 2,
				},
				currentOnTop = {
					name = L['Current Character On Top'],
					desc = L['Place the character you are currently logged in as on the top of the list.'],
					type = 'toggle',
					width = 'full',
					order = 3,
					get = function(info) return db.profile.currentOnTop end,
					set = function(info, value) db.profile.currentOnTop = value end,
				},
				sortType = {
					name = L['Sort Field'],
					desc = L['Field to sort the tooltip by.'],
					type = 'select',
					order = 5,
					values = { L['Character'], L['Valor Points'], L['Class'] },
					get = function(info) return db.profile.sortType end,
					set = function(info, value) db.profile.sortType = value end,
				},
				sortingDirection = {
					name = L['Sorting Direction'],
					desc = L['Which direction to sort.'],
					type = 'select',
					order = 6,
					values = { L['Ascending'], L['Descending'] },
					get = function(info) return db.profile.sortDirection end,
					set = function(info, value) db.profile.sortDirection = value end,
				},
			},
		},
		instances = {
			name = L['Instances'],
			type = 'group',
			order = 2,
			args = { },
		}
	},
}

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
end

function core:OnEnable()
	LQT = LibStub('LibQTip-1.0')

	-- Setup font strings for later.  (RAID_CLASS_COLORS always indexed in English?)
	for class,color in pairs(RAID_CLASS_COLORS) do
		class = class:lower()
		if class == 'deathknight' then
			class = 'death knight'
		end
		
		fontObjects[class] = CreateFont('ClassFont' .. class)
		fontObjects[class]:CopyFontObject(GameTooltipText)
		fontObjects[class]:SetTextColor(color.r, color.g, color.b)
	end
	
	fontObjects['green'] = CreateFont('FlagFontGreen')
	fontObjects['green']:CopyFontObject(GameTooltipText)
	fontObjects['green']:SetTextColor(0, 255, 0)
	
	fontObjects['red'] = CreateFont('FlagFontRed')
	fontObjects['red']:CopyFontObject(GameTooltipText)
	fontObjects['red']:SetTextColor(255, 0, 0)
	
	-- Setup LDB
	LDB = LibStub('LibDataBroker-1.1'):NewDataObject('ChoreTracker', {
		type = 'data source',
		text = 'ChoreTracker',
		icon = 'Interface\\AddOns\\ChoreTracker\\icon',
		OnClick = function(self, button)
			if button == 'RightButton' then
				if LibStub("AceConfigDialog-3.0").OpenFrames['ChoreTracker'] then
					LibStub('AceConfigDialog-3.0'):Close('ChoreTracker')
				else
					LibStub('AceConfigDialog-3.0'):Open('ChoreTracker')
				end
			else
				-- Cycle through our sort options
				if db.profile.sortType == 1 then
					db.profile.sortType = 2
					core:DrawTooltip()
				elseif db.profile.sortType == 2 then
					db.profile.sortType = 3
					core:DrawTooltip()
				else
					db.profile.sortType = 1
					core:DrawTooltip()
				end
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
	
	-- Setup instance stuff for options
	core:DrawInstanceOptions()
	
	-- Add options to Interface Panel
	LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable('ChoreTracker', options)
	local ACD = LibStub('AceConfigDialog-3.0')
	ACD:AddToBlizOptions('ChoreTracker', 'ChoreTracker')
	options.args.profile = LibStub('AceDBOptions-3.0'):GetOptionsTable(db)
	
	-- Register events
	local level = UnitLevel('player')
	if level == 85 then
		self:RegisterEvent('CALENDAR_UPDATE_EVENT_LIST')
		self:RegisterEvent('UPDATE_INSTANCE_INFO')
		self:RegisterEvent('CHAT_MSG_CURRENCY')
		-- Need another event to catch instance lockouts.  CHAT_MSG_CURRENCY will not fire if you
		-- receive no currency (ie. are Valor Point capped).
	end
	
	-- Get calendar events information
	OpenCalendar()
	
	-- Reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()
end




--[[		EVENTS		]]--
function core:CALENDAR_UPDATE_EVENT_LIST()
	core:GetNextVPReset()
end

function core:UPDATE_INSTANCE_INFO()
	core:UpdateChores()
end

function core:CHAT_MSG_CURRENCY()
	RequestRaidInfo()
end




--[[		FUNCTIONS		]]--
function core:DrawInstanceOptions()
	-- Redraw our instance options everytime they are updated.
	options.args.instances.args = { 
		instance = {
			name = L['Add instance to track.'],
			desc = L['Enter an instance on a lockout that you would like ChoreTracker to track.'],
			type = 'input',
			order = 1,
			set = function(info, value) 
				if core:VerifyInstance(value) then 
					print('Adding',value)
					db.profile.instances[value] = { }
					db.profile.instances[value].abbreviation = string.sub(value,0,1)
					db.profile.instances[value].enable = true
					db.profile.instances[value].removed = false
					core:DrawInstanceOptions()
				else 
					print('Invalid instance') 
				end
			end,
		},
		instancesHeader = {
			name = L['Instances'],
			type = 'header',
			order = 2,
		},
	}
	local i = 1
	for instance, abbreviation in pairs(db.profile.instances) do
		if db.profile.instances[instance].removed == false then
			options.args.instances.args[instance .. 'Enable'] = {
				type = 'toggle',
				name = instance,
				order = 4 * i,
				get = function(info) return db.profile.instances[instance].enable end,
				set = function(info, value) 
					db.profile.instances[instance].enable = value
					core:DrawInstanceOptions()
				end,
			}
			options.args.instances.args[instance] = {
				type = 'input',
				name = '',
				order = 4 * i + 1,
				width = 'half',
				get = function(info) return db.profile.instances[instance].abbreviation end,
				set = function(info, value) db.profile.instances[instance].abbreviation = value end,
			}
			options.args.instances.args[instance .. 'Remove'] = {
				type = 'execute',
				name = L['Remove'],
				order = 4 * i + 2,
				width = 'half',
				confirm = true,
				func = function() 
					db.profile.instances[instance].removed = true 
					core:DrawInstanceOptions()
				end,
			}
			options.args.instances.args[instance .. 'Spacer'] = {
				type = 'description',
				name = '',
				order = 4 * i + 3,
			}
			i = i + 1
		end
	end
end

function core:UpdateChores()
	-- Reset data if necessary
	core:ResetInstances()
	core:ResetValorPoints()

	local realm = GetRealmName()
	local name = UnitName('player')
	local _,_,_,earnedThisWeek = GetCurrencyInfo(396)

	-- Store Valor Points if we were able to establish a reset time.
	-- Try to alleviate issues with vpResetTime not getting set
	-- by updating vp regardless and assuming previous time is still
	-- correct.
	if db.global[realm][name].valorPoints == nil then
		db.global[realm][name].valorPoints = {}
	end
	db.global[realm][name].valorPoints.points = earnedThisWeek
	if vpResetTime ~= nil then
		db.global[realm][name].valorPoints.resetTime = vpResetTime
	end

	-- Store Saved Instances; sometimes, there can be two lockouts to the same instance
	local savedInstances = GetNumSavedInstances()
	for i = 1, savedInstances do
		local instanceName, _, instanceReset, _, _, _, _, _, _, _, _, defeatedBosses = GetSavedInstanceInfo(i)
		
		if db.profile.instances[instanceName] ~= nil then
			if instanceReset > 0 then
				db.global[realm][name].lockouts[instanceName] = {}
				db.global[realm][name].lockouts[instanceName].defeatedBosses = defeatedBosses
				db.global[realm][name].lockouts[instanceName].resetTime = time() + instanceReset
			-- Let's not delete instances with no lockout for now.  ResetInstances() should take care of this
			-- and it solves an issue with two lockouts to the same instance being listed.
			--else
			--	db.global[realm][name].lockouts[instanceName] = nil
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
	-- We need to have access to the instance lockouts on the calendar.
	local currentCalendarSetting = GetCVar('calendarShowResets')
	SetCVar('calendarShowResets', 1)

	-- Figure out what time the server resets daily information
	local questReset = GetQuestResetTime()
	local resetTime = date('*t', time() + questReset)
	
	-- Figure out reset day using next BH lockout
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

			if title == Z['Baradin Hold'] then
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
	
	-- Reset the calendar to the original settings
	SetCVar('calendarShowResets', currentCalendarSetting)
	
	-- And combine for the reset timestamp
	if(resetDate ~= nil) then
		resetDate.hour = resetTime.hour
		resetDate.min = resetTime.min
		resetDate.sec = resetTime.sec

		vpResetTime = time(resetDate)
		print(vpResetTime)
	else
		print('No Time')
		vpResetTime = nil
	end
end

function core:VerifyInstance(instance)
	-- Use a method similar to GetNextVPReset() to make sure the instance
	-- has a lockout on the calendar
	local currentCalendarSetting = GetCVar('calendarShowResets')
	SetCVar('calendarShowResets', 1)
	
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

			if title == instance then
				return true
			end
		end
		
		day = day + 1
		if day > 31 then
			if monthOffset == 1 then break end
			day = 1
			monthOffset = 1
		end
	end
	
	-- Reset the calendar to the original settings
	SetCVar('calendarShowResets', currentCalendarSetting)
	
	return false
end

function core:DrawTooltip()
	-- UpdateChores before we show the tooltip to make sure we have the most recent data
	core:UpdateChores()
	
	if tooltip then
		tooltip:ClearAllPoints()
		tooltip:Clear()
		tooltip = nil 
	end
	local columnCount = 2
	for instance in pairs(db.profile.instances) do
		if db.profile.instances[instance].enable == true and db.profile.instances[instance].removed == false then
			columnCount = columnCount + 1
		end
	end
	tooltip =  LQT:Acquire('ChoreTrackerTooltip', columnCount, 'LEFT', 'CENTER', 'RIGHT') 

	-- Populate a table with the information we want for our tooltip
	local tooltipTable = {}
	local currentTable = {}
	for realm in pairs(db.global) do
		for name in pairs(db.global[realm]) do
			local valorPoints = db.global[realm][name].valorPoints.points
			local class = db.global[realm][name].class
			
			if valorPoints == nil then
				valorPoints = 0
			end
			local characterTable = { name = name, realm = realm, class = class, valorPoints = valorPoints }
			
			for instance in pairs(db.profile.instances) do
				local defeatedBosses
				if db.global[realm][name].lockouts[instance] ~= nil then
					defeatedBosses = db.global[realm][name].lockouts[instance].defeatedBosses
				else
					defeatedBosses = 0
				end
				characterTable[instance] = defeatedBosses
			end

			if name == UnitName('player') and db.profile.currentOnTop == true then
				currentTable = characterTable
			else
				table.insert(tooltipTable, characterTable)
			end
		end
	end
	
	-- Sort table according to options.
	local sortTooltip = function(a, b)
		local aValue, bValue
		if db.profile.sortType == 1 then
			aValue = a.name:lower()
			bValue = b.name:lower()
		elseif db.profile.sortType == 2 then
			aValue = a.valorPoints
			bValue = b.valorPoints
		elseif db.profile.sortType == 3 then
			aValue = a.class
			bValue = b.class
		end
		
		if db.profile.sortDirection == 1 then
			return aValue < bValue
		else
			return aValue > bValue
		end
	end
	table.sort(tooltipTable, sortTooltip )
	
	-- Toss the current character on top if it is set that way
	if db.profile.currentOnTop == true then
		table.insert(tooltipTable, 1, currentTable)
	end
	
	-- Create a table for the header; vpPos to decide where to place Valor Points column
	-- Draw tooltip table then looped through.
	
	-- Draw the tooltip
	tooltip:AddHeader('')
	tooltip:SetScale(1)
	local valorPointColumn = tooltip:AddColumn('LEFT')
	tooltip:SetCell(1, 1, '')
	tooltip:SetCell(1, 2, 'VP')
	
	-- Build and sort our headers
	local headerTable = { }
	--headerTable['Valor Points'] = { abbreviation = 'VP', enable = true, removed = false, }
	for instance, instanceInfo in pairs(db.profile.instances) do
		if db.profile.instances[instance].enable == true and db.profile.instances[instance].removed == false then
			table.insert(headerTable,instanceInfo)
		end
	end
	
	local nextColumn = 3
	for instance,instanceInfo in pairs(headerTable) do
		tooltip:SetCell(1, nextColumn, instanceInfo.abbreviation, nil, 'CENTER')
		nextColumn = nextColumn + 1
	end
	
	for _,information in pairs(tooltipTable) do
		local characterLine = tooltip:AddLine('')
		tooltip:SetCell(characterLine, 1, information.name, fontObjects[information.class], 'LEFT')
		
		local valorPointColor
		if information.valorPoints == 980 then
			valorPointColor = fontObjects['red']
		else
			valorPointColor = fontObjects['green']
		end
		tooltip:SetCell(characterLine, 2, information.valorPoints, valorPointColor, 'RIGHT')
		
		local nextColumn = 3
		for instance, abbreviation in pairs(db.profile.instances) do
			if db.profile.instances[instance].enable == true and db.profile.instances[instance].removed == false then
				local instanceColor
				if information[instance] == 0 then
					instanceColor = fontObjects['green']
				else
					instanceColor = fontObjects['red']
				end
				tooltip:SetCell(characterLine, nextColumn, information[instance], instanceColor, 'RIGHT')
				
				nextColumn = nextColumn + 1
			end
		end
	end
end