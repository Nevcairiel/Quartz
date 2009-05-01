--[[
	Copyright (C) 2006-2007 Nymbia

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
]]
local mod = Quartz3:NewModule("Player", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")
mod.modName = L["Player"]

local db
local media = LibStub("LibSharedMedia-3.0")

local math_min = math.min
local unpack = unpack
local tonumber = tonumber
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetTime = GetTime
local castTimeFormatString

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent, db

local function set(field, value)
	db[field] = value
	mod.ApplySettings()
end

local function get(field)
	return db[field]
end


local defaults = {
	profile = {
	hideblizz = true,

	--x =  -- applied automatically in applySettings()
	y = 180,
	h = 25,
	w = 250,
	scale = 1,
	
	texture = 'Blizzard',
	
	hideicon = false,
	
	alpha = 1,
	iconalpha = 0.9,
	iconposition = L["Left"],
	icongap = 4,
	
	hidenametext = false,
	nametextposition = L["Left"],
	timetextposition = L["Right"], -- L["Left"], L["Center"], L["Cast Start Side"], L["Cast End Side"]
	font = 'Friz Quadrata TT',
	fontsize = 14,
	hidetimetext = false,
	hidecasttime = false,
	casttimeprecision = 1,
	timefontsize = 12,
	targetname = false,
	spellrank = false,
	spellrankstyle = L["Roman"], --L["Full Text"], L["Number"], L["Roman Full Text"]
	
	border = 'Blizzard Tooltip', -- L["None"]
	
	nametextx = 3,
	nametexty = 0,
	timetextx = 3,
	timetexty = 0,
	}
}

local options = {
	lock = {
		type = 'toggle',
		name = L["Lock"],
		desc = L["Toggle Cast Bar lock"],
		get = function()
			return locked
		end,
		set = function(v)
			if v then
				castBarParent.Hide = nil
				castBarParent:EnableMouse(false)
				castBarParent:SetScript('OnDragStart', nil)
				castBarParent:SetScript('OnDragStop', nil)
				if not (mod.channeling or mod.casting) then
					castBarParent:Hide()
				end
			else
				castBarParent:Show()
				castBarParent:EnableMouse(true)
				castBarParent:SetScript('OnDragStart', dragstart)
				castBarParent:SetScript('OnDragStop', dragstop)
				castBarParent:SetAlpha(1)
				castBarParent.Hide = nothing
				castBarIcon:SetTexture("Interface\\Icons\\Temp")
			end
			locked = v
		end,
		order = 100,
	},
	hideblizz = {
		type = 'toggle',
		name = L["Disable Blizzard Cast Bar"],
		desc = L["Disable and hide the default UI's casting bar"],
		get = get,
		set = set,
		--passValue = 'hideblizz',
		order = 101,
	},
	h = {
		type = 'range',
		name = L["Height"],
		desc = L["Height"],
		min = 10,
		max = 50,
		step = 1,
		order = 200,
		get = get,
		set = set,
		--passValue = 'h',
	},
	w = {
		type = 'range',
		name = L["Width"],
		desc = L["Width"],
		min = 50,
		max = 1500,
		step = 5,
		order = 200,
		get = get,
		set = set,
		--passValue = 'w',
	},
	x = {
		type = 'input',
		name = L["X"],
		desc = L["Set an exact X value for this bar's position."],
		get = get,
		set = set,
		--passValue = 'x',
		order = 200,
		validate = function(v)
			return tonumber(v) and true
		end,
		--usage = L["Number"],
	},
	y = {
		type = 'input',
		name = L["Y"],
		desc = L["Set an exact Y value for this bar's position."],
		get = get,
		set = set,
		--passValue = 'y',
		order = 200,
		validate = function(v)
			return tonumber(v) and true
		end,
		--usage = L["Number"],
	},
	scale = {
		type = 'range',
		name = L["Scale"],
		desc = L["Scale"],
		min = 0.2,
		max = 1,
		step = 0.025,
		order = 201,
		get = get,
		set = set,
		--passValue = 'scale',
	},
	alpha = {
		type = 'range',
		name = L["Alpha"],
		desc = L["Alpha"],
		isPercent = true,
		min = 0.1,
		max = 1,
		step = 0.025,
		order = 202,
		get = get,
		set = set,
		--passValue = 'alpha',
	},
	hideicon = {
		type = 'toggle',
		name = L["Hide Icon"],
		desc = L["Hide Spell Cast Icon"],
		get = get,
		set = set,
		--passValue = 'hideicon',
		order = 301,
	},
	iconalpha = {
		type = 'range',
		name = L["Icon Alpha"],
		desc = L["Set the Spell Cast icon alpha"],
		isPercent = true,
		min = 0.1,
		max = 1,
		step = 0.025,
		order = 301,
		get = get,
		set = set,
		disabled = hideiconoptions,
		--passValue = 'iconalpha',
	},
	iconposition = {
		type = 'select',
		name = L["Icon Position"],
		desc = L["Set where the Spell Cast icon appears"],
		get = get,
		set = set,
		disabled = hideiconoptions,
		--passValue = 'iconposition',
		values = {L["Left"], L["Right"]},
		order = 301,
	},
	icongap = {
		type = 'range',
		name = L["Icon Gap"],
		desc = L["Space between the cast bar and the icon."],
		min = -35,
		max = 35,
		step = 1,
		order = 301,
		get = get,
		set = set,
		disabled = hideiconoptions,
		--passValue = 'icongap',
	},
	texture = {
		type = 'select',
		dialogControl = 'LSM30_Statusbar',
		name = L["Texture"],
		desc = L["Set the Cast Bar Texture"],
		values = AceGUIWidgetLSMlists.statusbar,
		order = 302,
		get = get,
		set = set,
		--passValue = 'texture',
	},
	font = {
		type = 'select',
		dialogControl = 'LSM30_Font',
		name = L["Font"],
		desc = L["Set the font used in the Name and Time texts"],
		values = AceGUIWidgetLSMlists.font,
		order = 400,
		get = get,
		set = set,
		--passValue = 'font',
	},
	hidenametext = {
		type = 'toggle',
		name = L["Hide Name Text"],
		desc = L["Disable the text that displays the spell name/rank"],
		get = get,
		set = set,
		--passValue = 'hidenametext',
		order = 401,
	},
	nametextposition = {
		type = 'select',
			name = L["Name Text Position"],
			desc = L["Set the alignment of the spell name text"],
			get = get,
			set = set,
			--passValue = 'nametextposition',
			values = {L["Left"], L["Right"], L["Center"]},
			disabled = hidenametextoptions,
			order = 402,
		},
		nametextx = {
			type = 'range',
			name = L["Name Text X Offset"],
			desc = L["Adjust the X position of the name text"],
			get = get,
			set = set,
			--passValue = 'nametextx',
			min = -35,
			max = 35,
			step = 1,
			disabled = hidenametextoptions,
			order = 402,
		},
		nametexty = {
			type = 'range',
			name = L["Name Text Y Offset"],
			desc = L["Adjust the Y position of the name text"],
			get = get,
			set = set,
			--passValue = 'nametexty',
			min = -35,
			max = 35,
			step = 1,
			disabled = hidenametextoptions,
			order = 402,
		},
		namefontsize = {
			type = 'range',
			name = L["Name Text Font Size"],
			desc = L["Set the size of the spell name text"],
			min = 7,
			max = 20,
			step = 1,
			order = 403,
			get = get,
			set = set,
			disabled = hidenametextoptions,
			--passValue = 'fontsize',
		},
		targetname = {
			type = 'toggle',
			name = L["Target Name"],
			desc = L["Display target name of spellcasts after spell name"],
			get = get,
			set = set,
			--passValue = 'targetname',
			order = 404,
		},			
		spellrank = {
			type = 'toggle',
			name = L["Spell Rank"],
			desc = L["Display the rank of spellcasts alongside their name"],
			get = get,
			set = set,
			disabled = hidenametextoptions,
			--passValue = 'spellrank',
			order = 405,
		},
		spellrankstyle = {
			type = 'select',
			name = L["Spell Rank Style"],
			desc = L["Set the display style of the spell rank"],
			get = get,
			set = set,
			disabled = function()
				return db.hidenametext or not db.spellrank
			end,
			--passValue = 'spellrankstyle',
			values = {L["Number"], L["Roman"], L["Full Text"], L["Roman Full Text"]},
			order = 406,
		},
		hidetimetext = {
			type = 'toggle',
			name = L["Hide Time Text"],
			desc = L["Disable the text that displays the time remaining on your cast"],
			get = get,
			set = set,
			--passValue = 'hidetimetext',
			order = 411,
		},
		hidecasttime = {
			type = 'toggle',
			name = L["Hide Cast Time"],
			desc = L["Disable the text that displays the total cast time"],
			get = get,
			set = set,
			--passValue = 'hidecasttime',
			disabled = hidetimetextoptions,
			order = 412,
		},
		casttimeprecision = {
			type = 'range',
			name = L["Cast Time Precision"],
			desc = L["Set the precision (i.e. number of decimal places) for the cast time text"],
			min = 1,
			max = 3,
			step = 1,
			order = 413,
			get = get,
			set = set,
			disabled = hidecasttimeprecision,
			--passValue = 'casttimeprecision',
		},
		timefontsize = {
			type = 'range',
			name = L["Time Font Size"],
			desc = L["Set the size of the time text"],
			min = 7,
			max = 20,
			step = 1,
			order = 414,
			get = get,
			set = set,
			disabled = hidetimetextoptions,
			--passValue = 'timefontsize',
		},
		timetextposition = {
			type = 'select',
			name = L["Time Text Position"],
			desc = L["Set the alignment of the time text"],
			get = get,
			set = set,
			--passValue = 'timetextposition',
			values = {L["Left"], L["Right"], L["Center"], L["Cast Start Side"], L["Cast End Side"]},
			disabled = hidetimetextoptions,
			order = 415,
		},
		timetextx = {
			type = 'range',
			name = L["Time Text X Offset"],
			desc = L["Adjust the X position of the time text"],
			get = get,
			set = set,
			--passValue = 'timetextx',
			min = -35,
			max = 35,
			step = 1,
			disabled = hidetimetextoptions,
			order = 416,
		},
		timetexty = {
			type = 'range',
			name = L["Time Text Y Offset"],
			desc = L["Adjust the Y position of the time text"],
			get = get,
			set = set,
			--passValue = 'timetexty',
			min = -35,
			max = 35,
			step = 1,
			disabled = hidetimetextoptions,
			order = 417,
		},
		border = {
			type = 'select',
			dialogControl = 'LSM30_Border',
			name = L["Border"],
			desc = L["Set the border style"],
			get = get,
			set = set,
			--passValue = 'border',
			values = AceGUIWidgetLSMlists.border,
			order = 418,
		},
		snaptocenter = {
			type = 'select',
			name = L["Snap to Center"],
			desc = L["Move the CastBar to center of the screen along the specified axis"],
			get = false,
			set = function(v)
				local scale = db.scale
				if v == L["Horizontal"] then
					db.x = (UIParent:GetWidth() / 2 - (db.w * scale) / 2) / scale
				else -- L["Vertical"]
					db.y = (UIParent:GetHeight() / 2 - (db.h * scale) / 2) / scale
				end
				mod.ApplySettings()
			end,
			values = {L["Horizontal"], L["Vertical"]},
			order = 503,
		},
	copysettings = {
		type = 'select',
		name = L["Copy Settings From"],
		desc = L["Select a bar from which to copy settings"],
		get = false,
		set = function(v)
			local from = Quartz3:AcquireDBNamespace(v)
			Quartz3:CopySettings(from.profile, mod.db.profile)
			mod.ApplySettings()
		end,
		values = {L["Target"], L["Focus"], L["Pet"]},
		order = 504
	},
}

local function timenum(num, isCastTime)
	if num <= 60 then
	if isCastTime then
		return (castTimeFormatString):format(num)
	else
		return ('%.1f'):format(num)
	end
	else
	return ('%d:%02d'):format(num / 60, num % 60)
	end
end

local function OnUpdate()
	local currentTime = GetTime()
	local startTime = mod.startTime
	local endTime = mod.endTime
	local delay = mod.delay
	if mod.casting then
	if currentTime > endTime then
		mod.casting = nil
		mod.fadeOut = true
		mod.stopTime = currentTime
	end
	
	local showTime = math_min(currentTime, endTime)
	
	local perc = (showTime-startTime) / (endTime - startTime)
	castBar:SetValue(perc)
	castBarSpark:ClearAllPoints()
	castBarSpark:SetPoint('CENTER', castBar, 'LEFT', perc * db.w, 0)
	
	if delay and delay ~= 0 then
		if db.hidecasttime then
			castBarTimeText:SetText(("|cffff0000+%.1f|cffffffff %s"):format(delay, timenum(endTime - showTime)))
		else
			castBarTimeText:SetText(("|cffff0000+%.1f|cffffffff %s / %s"):format(delay, timenum(endTime - showTime), timenum(endTime - startTime, true)))
		end
	else
		if db.hidecasttime then
			castBarTimeText:SetText(timenum(endTime - showTime))
		else
			castBarTimeText:SetText(("%s / %s"):format(timenum(endTime - showTime), timenum(endTime - startTime, true)))
		end
	end
	elseif mod.channeling then
	if currentTime > endTime then
		mod.channeling = nil
		mod.fadeOut = true
		mod.stopTime = currentTime
	end
	local remainingTime = endTime - currentTime
	local perc = remainingTime / (endTime - startTime)
	castBar:SetValue(perc)
	castBarTimeText:SetText(("%.1f"):format(remainingTime))
	castBarSpark:ClearAllPoints()
	castBarSpark:SetPoint('CENTER', castBar, 'LEFT', perc * db.w, 0)
	
	if delay and delay ~= 0 then
		if db.hidecasttime then
			castBarTimeText:SetText(("|cffFF0000-%.1f|cffffffff %s"):format(delay, timenum(remainingTime)))
		else
			castBarTimeText:SetText(("|cffFF0000-%.1f|cffffffff %s / %s"):format(delay, timenum(remainingTime), timenum(endTime - startTime, true)))
		end
	else
		if db.hidecasttime then
			castBarTimeText:SetText(timenum(remainingTime))
		else
			castBarTimeText:SetText(("%s / %s"):format(timenum(remainingTime), timenum(endTime - startTime, true)))
		end
	end
	elseif mod.fadeOut then
	castBarSpark:Hide()
	local alpha
	local stopTime = mod.stopTime
	if stopTime then
		alpha = stopTime - currentTime + 1
	else
		alpha = 0
	end
	if alpha >= 1 then
		alpha = 1
	end
	if alpha <= 0 then
		mod.stopTime = nil
		castBarParent:Hide()
	else
		castBarParent:SetAlpha(alpha*db.alpha)
	end
	else
	castBarParent:Hide()
	end
end

mod.OnUpdate = OnUpdate

local function OnHide()
	local ql = Quartz3:GetModule("Latency", true)
	if ql then
		if ql:IsEnabled() and ql.lagbox then
			ql.lagbox:Hide()
			ql.lagtext:Hide()
		end
	end
	castBarParent:SetScript('OnUpdate', nil)
end

local function OnShow()
	castBarParent:SetScript('OnUpdate', OnUpdate)
end

local setnametext
do
	local numerals = { -- 25's enough for now, I think?
	'I', 'II', 'III', 'IV', 'V',
	'VI', 'VII', 'VIII', 'IX', 'X',
	'XI', 'XII', 'XIII', 'XIV', 'XV',
	'XVI', 'XVII', 'XVIII', 'XIX', 'XX',
	'XXI', 'XXII', 'XXIII', 'XXIV', 'XXV',
	}

	function setnametext(name, rank)
	if db.spellrank and rank then
		local rankstyle = db.spellrankstyle
		if rankstyle == L["Number"] then
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				castBarText:SetText(("%s %d"):format(name, num))
			else
				castBarText:SetText(name)
			end
		elseif rankstyle == L["Full Text"] then
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				castBarText:SetText(("%s (%s)"):format(name, rank))
			else
				castBarText:SetText(name)
			end
		elseif rankstyle == L["Roman"] then
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				castBarText:SetText(("%s %s"):format(name, numerals[num]))
			else
				castBarText:SetText(name)
			end
		else -- L["Roman Full Text"]
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				castBarText:SetText(("%s (%s)"):format(name, L["Rank %s"]:format(numerals[num])))
			else
				castBarText:SetText(("%s (%s)"):format(name, rank))
			end
		end
	else
		castBarText:SetText(name)
	end
	
	if db.targetname and mod.targetName and (mod.targetName ~= '') then
		local castText = castBarText:GetText() or nil
		if castText then castBarText:SetText(castText .. " -> " .. mod.targetName) end
	end
	end
end

function mod:GetOptions()
	return options
end

function mod:OnInitialize()
	mod.db = Quartz3.db:RegisterNamespace("Player", defaults)
	db = mod.db.profile

	castBarParent = CreateFrame('Frame', 'Quartz3CastBar', UIParent)
	castBarParent:SetFrameStrata('MEDIUM')
	castBarParent:SetScript('OnShow', OnShow)
	castBarParent:SetScript('OnHide', OnHide)
	castBarParent:SetMovable(true)
	castBarParent:RegisterForDrag('LeftButton')
	castBarParent:SetClampedToScreen(true)
	
	castBar = CreateFrame("StatusBar", nil, castBarParent)
	castBarText = castBar:CreateFontString(nil, 'OVERLAY')
	castBarTimeText = castBar:CreateFontString(nil, 'OVERLAY')
	castBarIcon = castBar:CreateTexture(nil, 'DIALOG')
	castBarSpark = castBar:CreateTexture(nil, 'OVERLAY')
	
	castBarParent:Hide()
	
	mod.castBarParent = castBarParent
	mod.castBar = castBar
	mod.castBarText = castBarText
	mod.castBarTimeText = castBarTimeText
	mod.castBarIcon = castBarIcon
	mod.castBarSpark = castBarSpark
	
	mod.playerName = UnitName("player");
end


function mod:OnEnable()
	mod:RegisterEvent("UNIT_SPELLCAST_SENT")
	mod:RegisterEvent("UNIT_SPELLCAST_START")
	mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	mod:RegisterEvent("UNIT_SPELLCAST_STOP")
	mod:RegisterEvent("UNIT_SPELLCAST_FAILED")
	mod:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	mod:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	mod:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTED")
	media.RegisterCallback(mod, "LibSharedMedia_SetGlobal", function(mtype, override)
	if mtype == "statusbar" then
		castBar:SetStatusBarTexture(media:Fetch("statusbar", override))
	end
	end)

	mod:ApplySettings()
end

function mod:OnDisable()
	CastingBarFrame.RegisterEvent = nil
	CastingBarFrame:UnregisterAllEvents()
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
end

function mod:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
	if unit ~= 'player' then
	return
	end
	if target then
	mod.targetName = target;
	else
	mod.targetName = mod.playerName;
	end
end

function mod:UNIT_SPELLCAST_START(event, unit)
	if unit ~= 'player' then
	return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)

	startTime = startTime / 1000
	endTime = endTime / 1000
	mod.startTime = startTime
	mod.endTime = endTime
	mod.delay = 0
	mod.casting = true
	mod.channeling = nil
	mod.fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
	
	castBar:SetValue(0)
	castBarParent:Show()
	castBarParent:SetAlpha(db.alpha)
	
	setnametext(displayName, rank)
	
	castBarSpark:Show()
	
	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
	icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.timetextposition
	if position == L["Cast Start Side"] then
	castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.timetextx, db.timetexty)
	castBarTimeText:SetJustifyH("LEFT")
	elseif position == L["Cast End Side"] then
	castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.timetextx, db.timetexty)
	castBarTimeText:SetJustifyH("RIGHT")
	end
end

function mod:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	if unit ~= 'player' then
	return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	
	startTime = startTime / 1000
	endTime = endTime / 1000
	mod.startTime = startTime
	mod.endTime = endTime
	mod.delay = 0
	mod.casting = nil
	mod.channeling = true
	mod.fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.channelingcolor))
	
	castBar:SetValue(1)
	castBarParent:Show()
	castBarParent:SetAlpha(db.alpha)

	setnametext(spell, rank)
	
	castBarSpark:Show()
	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
	icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.timetextposition
	if position == L["Cast Start Side"] then
	castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.timetextx, db.timetexty)
	castBarTimeText:SetJustifyH("RIGHT")
	elseif position == L["Cast End Side"] then
	castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.timetextx, db.timetexty)
	castBarTimeText:SetJustifyH("LEFT")
	end
end

function mod:UNIT_SPELLCAST_STOP(event, unit)
	if unit ~= 'player' then
	return
	end
	if mod.casting then
	mod.targetName = nil
	mod.casting = nil
	mod.fadeOut = true
	mod.stopTime = GetTime()
	
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
	
	castBarTimeText:SetText("")
	end
end

function mod:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
	if unit ~= 'player' then
	return
	end
	if mod.channeling then
	mod.channeling = nil
	mod.fadeOut = true
	mod.stopTime = GetTime()
	
	castBar:SetValue(0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
	
	castBarTimeText:SetText("")
	end
end

function mod:UNIT_SPELLCAST_FAILED(event, unit)
	if unit ~= 'player' or mod.channeling or mod.casting then 
	return
	end
	mod.targetName = nil
	mod.casting = nil
	mod.channeling = nil
	mod.fadeOut = true
	if not mod.stopTime then
	mod.stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function mod:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= 'player' then
	return
	end
	mod.targetName = nil
	mod.casting = nil
	mod.channeling = nil
	mod.fadeOut = true
	if not mod.stopTime then
	mod.stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function mod:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= 'player' then
	return
	end
	local oldStart = mod.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not startTime then
	return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	mod.startTime = startTime
	mod.endTime = endTime

	mod.delay = (mod.delay or 0) + (startTime - (oldStart or startTime))
end

function mod:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	if unit ~= 'player' then
	return
	end
	local oldStart = mod.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	if not startTime then
	return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	mod.startTime = startTime
	mod.endTime = endTime
	
	mod.delay = (mod.delay or 0) + ((oldStart or startTime) - startTime)
end

do
	local backdrop = { insets = {} }
	local backdrop_insets = backdrop.insets
	
	function mod:ApplySettings()
	if castBarParent then
		local db = mod.db.profile
		
		castBarParent = mod.castBarParent
		castBar = mod.castBar
		castBarText = mod.castBarText
		castBarTimeText = mod.castBarTimeText
		castBarIcon = mod.castBarIcon
		castBarSpark = mod.castBarSpark
		
		castBarParent:ClearAllPoints()
		if not db.x then
			db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale) / 2) / db.scale
		end
		castBarParent:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', db.x, db.y)
		castBarParent:SetWidth(db.w+9)
		castBarParent:SetHeight(db.h+10)
		castBarParent:SetAlpha(db.alpha)
		castBarParent:SetScale(db.scale)
		
		backdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
		backdrop.tile = true
		backdrop.tileSize = 16
		backdrop.edgeFile = media:Fetch('border', db.border)
		backdrop.edgeSize = 16
		backdrop_insets.left = 4
		backdrop_insets.right = 4
		backdrop_insets.top = 4
		backdrop_insets.bottom = 4
		
		castBarParent:SetBackdrop(backdrop)
		local r,g,b = unpack(Quartz3.db.profile.bordercolor)
		castBarParent:SetBackdropBorderColor(r,g,b, Quartz3.db.profile.borderalpha)
		r,g,b = unpack(Quartz3.db.profile.backgroundcolor)
		castBarParent:SetBackdropColor(r,g,b, Quartz3.db.profile.backgroundalpha)
		
		castBar:ClearAllPoints()
		castBar:SetPoint('CENTER',castBarParent,'CENTER')
		castBar:SetWidth(db.w)
		castBar:SetHeight(db.h)
		castBar:SetStatusBarTexture(media:Fetch('statusbar', db.texture))
		castBar:SetMinMaxValues(0, 1)
		
		if db.hidetimetext then
			castBarTimeText:Hide()
		else
			castBarTimeText:Show()
			castBarTimeText:ClearAllPoints()
			castBarTimeText:SetWidth(db.w)
			local position = db.timetextposition
			if position == L["Left"] then
				castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("LEFT")
			elseif position == L["Center"] then
				castBarTimeText:SetPoint('CENTER', castBar, 'CENTER', db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("CENTER")
			elseif position == L["Right"] then
				castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("RIGHT")
			end -- L["Cast Start Side"], L["Cast End Side"] --handled at runtime
		end
		castBarTimeText:SetFont(media:Fetch('font', db.font), db.timefontsize)
		castBarTimeText:SetShadowColor( 0, 0, 0, 1)
		castBarTimeText:SetShadowOffset( 0.8, -0.8 )
		castBarTimeText:SetTextColor(unpack(Quartz3.db.profile.timetextcolor))
		castBarTimeText:SetNonSpaceWrap(false)
		castBarTimeText:SetHeight(db.h)
		
		castTimeFormatString = '%.'..db.casttimeprecision..'f'
		
		local temptext = castBarTimeText:GetText()
		if db.hidecasttime then
			castBarTimeText:SetText(("%s"):format(timenum(10)))
		else
			castBarTimeText:SetText(("%s / %s"):format(timenum(10), timenum(10, true)))
		end
		local normaltimewidth = castBarTimeText:GetStringWidth()
		castBarTimeText:SetText(temptext)
		
		if db.hidenametext then
			castBarText:Hide()
		else
			castBarText:Show()
			castBarText:ClearAllPoints()
			local position = db.nametextposition
			if position == L["Left"] then
				castBarText:SetPoint('LEFT', castBar, 'LEFT', db.nametextx, db.nametexty)
				castBarText:SetJustifyH("LEFT")
				if db.hidetimetext or db.timetextposition ~= L["Right"] then
					castBarText:SetWidth(db.w)
				else
					castBarText:SetWidth(db.w - normaltimewidth - 5)
				end
			elseif position == L["Center"] then
				castBarText:SetPoint('CENTER', castBar, 'CENTER', db.nametextx, db.nametexty)
				castBarText:SetJustifyH("CENTER")
			else -- L["Right"]
				castBarText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.nametextx, db.nametexty)
				castBarText:SetJustifyH("RIGHT")
				if db.hidetimetext or db.timetextposition ~= L["Left"] then
					castBarText:SetWidth(db.w)
				else
					castBarText:SetWidth(db.w - normaltimewidth - 5)
				end
			end
		end
		castBarText:SetFont(media:Fetch('font', db.font), db.fontsize)
		castBarText:SetShadowColor( 0, 0, 0, 1)
		castBarText:SetShadowOffset( 0.8, -0.8 )
		castBarText:SetTextColor(unpack(Quartz3.db.profile.spelltextcolor))
		castBarText:SetNonSpaceWrap(false)
		castBarText:SetHeight(db.h)
		
		if db.hideicon then
			castBarIcon:Hide()
		else
			castBarIcon:Show()
			castBarIcon:ClearAllPoints()
			if db.iconposition == L["Left"] then
				castBarIcon:SetPoint("RIGHT", castBar, "LEFT", -1 * db.icongap, 0)
			else --L["Right"]
				castBarIcon:SetPoint("LEFT", castBar, "RIGHT", db.icongap, 0)
			end
			castBarIcon:SetWidth(db.h)
			castBarIcon:SetHeight(db.h)
			castBarIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			castBarIcon:SetAlpha(db.iconalpha)
		end
		
		castBarSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		castBarSpark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		castBarSpark:SetBlendMode('ADD')
		castBarSpark:SetWidth(20)
		castBarSpark:SetHeight(db.h*2.2)
		
		if db.hideblizz then
			CastingBarFrame.RegisterEvent = nothing
			CastingBarFrame:UnregisterAllEvents()
			CastingBarFrame:Hide()
		else
			CastingBarFrame.RegisterEvent = nil
			CastingBarFrame:UnregisterAllEvents()
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		end
	end
	end
end

do
	local locked = true
	local function dragstart()
	castBarParent:StartMoving()
	end
	local function dragstop()
	db.x = castBarParent:GetLeft()
	db.y = castBarParent:GetBottom()
	castBarParent:StopMovingOrSizing()
	end
	local function nothing()
	castBarParent:SetAlpha(db.alpha)
	end
	local function hideiconoptions()
	return db.hideicon
	end
	local function hidetimetextoptions()
	return db.hidetimetext
	end
	local function hidecasttimeprecision()
	return db.hidetimetext or db.hidecasttime
	end
	local function hidenametextoptions()
	return db.hidenametext
	end
end
