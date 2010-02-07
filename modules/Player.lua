--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >

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
local _G = getfenv(0)
local LibStub = _G.LibStub

local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = "Player"
local Player = Quartz3:NewModule(MODNAME, "AceEvent-3.0")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local math_min = _G.math.min
local unpack = _G.unpack
local tonumber = _G.tonumber
local format = _G.string.format
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local UnitName = _G.UnitName
local GetTime = _G.GetTime
local castTimeFormatString

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent
local locked = true

local db, getOptions

local defaults = {
	profile = {
		hideblizz = true,
		showticks = true,
		--x =  -- applied automatically in applySettings()
		y = 180,
		h = 25,
		w = 250,
		scale = 1,
		texture = "Blizzard",
		hideicon = false,
		alpha = 1,
		iconalpha = 0.9,
		iconposition = "left",
		icongap = 4,
		hidenametext = false,
		nametextposition = "left",
		timetextposition = "right", 
		font = "Friz Quadrata TT",
		fontsize = 14,
		hidetimetext = false,
		hidecasttime = false,
		casttimeprecision = 1,
		timefontsize = 12,
		targetname = false,
		spellrank = false,
		spellrankstyle = "roman", 
		border = "Blizzard Tooltip",
		nametextx = 3,
		nametexty = 0,
		timetextx = 3,
		timetexty = 0,
	}
}


local sparkfactory = {
	__index = function(t,k)
		local spark = castBar:CreateTexture(nil, 'OVERLAY')
		t[k] = 	spark
		spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		spark:SetBlendMode('ADD')
		spark:SetWidth(20)
		spark:SetHeight(db.h*2.2)
		return spark
	end
}
local barticks = setmetatable({}, sparkfactory)

local function setBarTicks(ticknum)
	if( ticknum and ticknum > 0) then
		local delta = ( db.w / ticknum )
		for k = 1,ticknum do
			local t = barticks[k]
			t:ClearAllPoints()
			t:SetPoint("CENTER", castBar, "LEFT", delta * k, 0 )
			t:Show()
		end
	else
		barticks[1].Hide = nil
		for _, v in ipairs(barticks) do
			v:Hide()
		end
	end
end

do 
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
	
	local function setOpt(info, value)
		db[info[#info]] = value
		Player:ApplySettings()
	end
	
	local function getOpt(info)
		return db[info[#info]]
	end

	local options
	function getOptions()
		if not options then
			 options = {
				type = "group",
				name = L["Player"],
				get = getOpt,
				set = setOpt,
				args = {
					lock = {
						type = "toggle",
						name = L["Lock"],
						desc = L["Toggle Cast Bar lock"],
						get = function(info)
							return locked
						end,
						set = function(info, v)
							if v then
								castBarParent.Hide = nil
								castBarParent:EnableMouse(false)
								castBarParent:SetScript("OnDragStart", nil)
								castBarParent:SetScript("OnDragStop", nil)
								if not (Player.channeling or Player.casting) then
									castBarParent:Hide()
								end
							else
								castBarParent:Show()
								castBarParent:EnableMouse(true)
								castBarParent:SetScript("OnDragStart", dragstart)
								castBarParent:SetScript("OnDragStop", dragstop) 
								castBarParent:SetAlpha(1)
								castBarParent.Hide = nothing
								castBarIcon:SetTexture("Interface\\Icons\\Temp")
							end
							locked = v
						end,
						order = 100,
					},
					hideblizz = {
						type = "toggle",
						name = L["Disable Blizzard Cast Bar"],
						desc = L["Disable and hide the default UI's casting bar"],
						order = 101,
					},
					showticks = {
						type = "toggle",
						name = L["Show channeling ticks"],
						desc = L["Show damage / mana ticks while channeling spells like Drain Life or Blizzard"],
						order = 102,
					},
					h = {
						type = "range",
						name = L["Height"],
						desc = L["Height"],
						min = 10, max = 50, step = 1,
						order = 200,
					},
					w = {
						type = "range",
						name = L["Width"],
						desc = L["Width"],
						min = 50, max = 1500, bigStep = 5,
						order = 200,
					},
					x = {
						type = "range",
						name = L["X"],
						desc = L["Set an exact X value for this bar's position."],
						min = -2560, max = 2560, bigStep = 1,
						order = 200,
					},
					y = {
						type = "range",
						name = L["Y"],
						desc = L["Set an exact Y value for this bar's position."],
						min = -1600, max = 1600, bigStep = 1,
						order = 200,
					},
					scale = {
						type = "range",
						name = L["Scale"],
						desc = L["Scale"],
						min = 0.2, max = 1, bigStep = 0.025,
						order = 201,
					},
					alpha = {
						type = "range",
						name = L["Alpha"],
						desc = L["Alpha"],
						isPercent = true,
						min = 0.1, max = 1, bigStep = 0.025,
						order = 202,
					},
					icon = {
						type = "header",
						name = L["Icon"],
						order = 300,
					},
					hideicon = {
						type = "toggle",
						name = L["Hide Icon"],
						desc = L["Hide Spell Cast Icon"],
						order = 301,
					},
					iconposition = {
						type = "select",
						name = L["Icon Position"],
						desc = L["Set where the Spell Cast icon appears"],
						disabled = hideiconoptions,
						values = {["left"] = L["Left"], ["right"] = L["Right"]},
						order = 301,
					},
					iconalpha = {
						type = "range",
						name = L["Icon Alpha"],
						desc = L["Set the Spell Cast icon alpha"],
						isPercent = true,
						min = 0.1, max = 1, bigStep = 0.025,
						order = 302,
						disabled = hideiconoptions,
					},
					icongap = {
						type = "range",
						name = L["Icon Gap"],
						desc = L["Space between the cast bar and the icon."],
						min = -35, max = 35, bigStep = 1,
						order = 302,
						disabled = hideiconoptions,
					},
					fonthead = {
						type = "header",
						name = L["Font and Text"],
						order = 398,
					},
					font = {
						type = "select",
						dialogControl = "LSM30_Font",
						name = L["Font"],
						desc = L["Set the font used in the Name and Time texts"],
						values = lsmlist.font,
						order = 399,
					},
					nlfont = {
						type = "description",
						name = "",
						order = 400,
					},
					hidenametext = {
						type = "toggle",
						name = L["Hide Spell Name"],
						desc = L["Disable the text that displays the spell name/rank"],
						order = 401,
					},
					targetname = {
						type = "toggle",
						name = L["Show Target Name"],
						desc = L["Display target name of spellcasts after spell name"],
						disabled = hidenametextoptions,
						order = 402,
					},
					nametextposition = {
						type = "select",
						name = L["Spell Name Position"],
						desc = L["Set the alignment of the spell name text"],
						values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"]},
						disabled = hidenametextoptions,
						order = 403,
					},
					fontsize = {
						type = "range",
						name = L["Spell Name Font Size"],
						desc = L["Set the size of the spell name text"],
						min = 7, max = 20, step = 1,
						order = 404,
						disabled = hidenametextoptions,
					},
					nametextx = {
						type = "range",
						name = L["Spell Name X Offset"],
						desc = L["Adjust the X position of the spell name text"],
						min = -35, max = 35, step = 1,
						disabled = hidenametextoptions,
						order = 405,
					},
					nametexty = {
						type = "range",
						name = L["Spell Name Y Offset"],
						desc = L["Adjust the Y position of the name text"],
						min = -35, max = 35, step = 1,
						disabled = hidenametextoptions,
						order = 406,
					},
					spellrank = {
						type = "toggle",
						name = L["Spell Rank"],
						desc = L["Display the rank of spellcasts alongside their name"],
						disabled = hidenametextoptions,
						order = 407,
					},
					spellrankstyle = {
						type = "select",
						name = L["Spell Rank Style"],
						desc = L["Set the display style of the spell rank"],
						disabled = function()
							return db.hidenametext or not db.spellrank
						end,
						values = {["number"] = L["Number"], ["roman"] = L["Roman"], ["full"] = L["Full Text"], ["romanfull"] = L["Roman Full Text"]},
						order = 408,
					},
					hidetimetext = {
						type = "toggle",
						name = L["Hide Time Text"],
						desc = L["Disable the text that displays the time remaining on your cast"],
						order = 411,
					},
					hidecasttime = {
						type = "toggle",
						name = L["Hide Cast Time"],
						desc = L["Disable the text that displays the total cast time"],
						disabled = hidetimetextoptions,
						order = 412,
					},
					casttimeprecision = {
						type = "range",
						name = L["Cast Time Precision"],
						desc = L["Set the precision (i.e. number of decimal places) for the cast time text"],
						min = 1, max = 3, step = 1,
						order = 413,
						disabled = hidecasttimeprecision,
					},
					timefontsize = {
						type = "range",
						name = L["Time Font Size"],
						desc = L["Set the size of the time text"],
						min = 7, max = 20, step = 1,
						order = 414,
						disabled = hidetimetextoptions,
					},
					timetextx = {
						type = "range",
						name = L["Time Text X Offset"],
						desc = L["Adjust the X position of the time text"],
						min = -35, max = 35, step = 1,
						disabled = hidetimetextoptions,
						order = 416,
					},
					timetexty = {
						type = "range",
						name = L["Time Text Y Offset"],
						desc = L["Adjust the Y position of the time text"],
						min = -35, max = 35, step = 1,
						disabled = hidetimetextoptions,
						order = 417,
					},
					timetextposition = {
						type = "select",
						name = L["Time Text Position"],
						desc = L["Set the alignment of the time text"],
						values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"], ["caststart"] = L["Cast Start Side"], ["castend"] = L["Cast End Side"]},
						disabled = hidetimetextoptions,
						order = 418,
					},
					textureheader = {
						type = "header",
						name = L["Texture and Border"],
						order = 450,
					},
					texture = {
						type = "select",
						dialogControl = "LSM30_Statusbar",
						name = L["Texture"],
						desc = L["Set the Cast Bar Texture"],
						values = lsmlist.statusbar,
						order = 451,
					},
					border = {
						type = "select",
						dialogControl = "LSM30_Border",
						name = L["Border"],
						desc = L["Set the border style"],
						values = lsmlist.border,
						order = 452,
					},
					toolheader = {
						type = "header",
						name = L["Tools"],
						order = 500,
					},
					snaptocenter = {
						type = "select",
						name = L["Snap to Center"],
						desc = L["Move the CastBar to center of the screen along the specified axis"],
						get = false,
						set = function(info, v)
							local scale = db.scale
							if v == "horizontal" then
								db.x = (UIParent:GetWidth() / 2 - (db.w * scale) / 2) / scale
							else -- L["Vertical"]
								db.y = (UIParent:GetHeight() / 2 - (db.h * scale) / 2) / scale
							end
							Player:ApplySettings()
						end,
						values = {["horizontal"] = L["Horizontal"], ["vertical"] = L["Vertical"]},
						order = 503,
					},
					copysettings = {
						type = "select",
						name = L["Copy Settings From"],
						desc = L["Select a bar from which to copy settings"],
						get = false,
						set = function(info, v)
								local from = Quartz3:GetModule(v)
								Quartz3:CopySettings(from.db.profile, Player.db.profile)
								Player:ApplySettings()
						end,
						values = {["Target"] = L["Target"], ["Focus"] = L["Focus"], ["Pet"] = L["Pet"]},
						order = 504
					},
				}
			}
		end
		return options
	end
end

local function timenum(num, isCastTime)
	if num <= 60 then
		if isCastTime then
			return castTimeFormatString, num
		else
			return "%.1f", num
		end
	else
		return "%d:%02d", num / 60, num % 60
	end
end

local function OnUpdate()
	local currentTime = GetTime()
	local startTime = Player.startTime
	local endTime = Player.endTime
	local delay = Player.delay
	if Player.casting then
		if currentTime > endTime then
			Player.casting = nil
			Player.fadeOut = true
			Player.stopTime = currentTime
		end
		
		local showTime = math_min(currentTime, endTime)
		
		local perc = (showTime-startTime) / (endTime - startTime)
		castBar:SetValue(perc)
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * db.w, 0)
		
		if delay and delay ~= 0 then
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %s", delay, format(timenum(endTime - showTime)))
			else
				castBarTimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %s / %s", delay, format(timenum(endTime - showTime)), format(timenum(endTime - startTime, true)))
			end
		else
			if db.hidecasttime then
				castBarTimeText:SetFormattedText(timenum(endTime - showTime))
			else
				castBarTimeText:SetFormattedText("%s / %s", format(timenum(endTime - showTime)), format(timenum(endTime - startTime, true)))
			end
		end
	elseif Player.channeling then
		if currentTime > endTime then
			Player.channeling = nil
			Player.fadeOut = true
			Player.stopTime = currentTime
		end
		local remainingTime = endTime - currentTime
		local perc = remainingTime / (endTime - startTime)
		castBar:SetValue(perc)
		castBarTimeText:SetFormattedText("%.1f", remainingTime)
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * db.w, 0)
		
		if delay and delay ~= 0 then
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("|cffFF0000-%.1f|cffffffff %s", delay, format(timenum(remainingTime)))
			else
				castBarTimeText:SetFormattedText("|cffFF0000-%.1f|cffffffff %s / %s", delay, format(timenum(remainingTime)), format(timenum(endTime - startTime, true)))
			end
		else
			if db.hidecasttime then
				castBarTimeText:SetFormattedText(timenum(remainingTime))
			else
				castBarTimeText:SetFormattedText("%s / %s", format(timenum(remainingTime)), format(timenum(endTime - startTime, true)))
			end
		end
	elseif Player.fadeOut then
		castBarSpark:Hide()
		local alpha
		local stopTime = Player.stopTime
		if stopTime then
			alpha = stopTime - currentTime + 1
		else
			alpha = 0
		end
		if alpha >= 1 then
			alpha = 1
		end
		if alpha <= 0 then
			Player.stopTime = nil
			castBarParent:Hide()
		else
			castBarParent:SetAlpha(alpha*db.alpha)
		end
	else
		castBarParent:Hide()
	end
end

Player.OnUpdate = OnUpdate

local function OnHide()
	local Latency = Quartz3:GetModule(L["Latency"],true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
	end
	castBarParent:SetScript("OnUpdate", nil)
end

local function OnShow()
	castBarParent:SetScript("OnUpdate", OnUpdate)
end

local setnametext
do
	local numerals = { -- 25"s enough for now, I think?
	"I", "II", "III", "IV", "V",
	"VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV",
	"XVI", "XVII", "XVIII", "XIX", "XX",
	"XXI", "XXII", "XXIII", "XXIV", "XXV",
	}

	function setnametext(name, rank)
		local mask, arg = nil, nil
		if db.spellrank and rank then
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				local rankstyle = db.spellrankstyle
				if rankstyle == "number" then
					mask, arg = "%s %d", num
				elseif rankstyle == "full" then
					mask, arg = "%s (%s)", rank
				elseif rankstyle == "roman" then
					mask, arg = "%s %s", numerals[num]
				else -- full roman
					mask, arg = "%s (%s)", L["Rank %s"]:format(numerals[num])
				end
			end
		end

		if db.targetname and Player.targetName and (Player.targetName ~= "") then
			if mask then
				mask = mask .. " -> " .. Player.targetName
			else
				name = name .. " -> " .. Player.targetName
			end
		end
		if mask then
			castBarText:SetFormattedText(mask, name, arg)
		else
			castBarText:SetText(name)
		end
	end
end

function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	castBarParent = CreateFrame("Frame", "Quartz3CastBar", UIParent)
	castBarParent:SetFrameStrata("MEDIUM")
	castBarParent:SetScript("OnShow", OnShow)
	castBarParent:SetScript("OnHide", OnHide)
	castBarParent:SetMovable(true)
	castBarParent:RegisterForDrag("LeftButton")
	castBarParent:SetClampedToScreen(true)

	self.Bar = castBarParent

	castBar = CreateFrame("StatusBar", nil, castBarParent)
	castBarText = castBar:CreateFontString(nil, "OVERLAY")
	castBarTimeText = castBar:CreateFontString(nil, "OVERLAY")
	castBarIcon = castBar:CreateTexture(nil, "DIALOG")
	castBarSpark = castBar:CreateTexture(nil, "OVERLAY")

	castBarParent:Hide()

	self.castBarParent = castBarParent
	self.castBar = castBar
	self.castBarText = castBarText
	self.castBarTimeText = castBarTimeText
	self.castBarIcon = castBarIcon
	self.castBarSpark = castBarSpark

	self.playerName = UnitName("player")
end


function Player:OnEnable()
	Player:RegisterEvent("UNIT_SPELLCAST_SENT")
	Player:RegisterEvent("UNIT_SPELLCAST_START")
	Player:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	Player:RegisterEvent("UNIT_SPELLCAST_STOP")
	Player:RegisterEvent("UNIT_SPELLCAST_FAILED")
	Player:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	Player:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	Player:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	Player:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	Player:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTED")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			castBar:SetStatusBarTexture(media:Fetch("statusbar", override))
		end
	end)

	Player:ApplySettings()
end

function Player:OnDisable()
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

function Player:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	if target then
		self.targetName = target
	else
		self.targetName = self.playerName
	end
end

function Player:UNIT_SPELLCAST_START(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)

	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	self.delay = 0
	self.casting = true
	self.channeling = nil
	self.fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
	
	setBarTicks(0)
	
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
	if position == "caststart" then
		castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	elseif position == "castend" then
		castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	end
end

local channelingTicks = {
	-- warlock
	[GetSpellInfo(1120)] = 5, -- drain soul
	[GetSpellInfo(689)] = 5, -- drain life
	[GetSpellInfo(5138)] = 5, -- drain mana
	[GetSpellInfo(5740)] = 4, -- rain of fire
	-- druid
	[GetSpellInfo(740)] = 4, -- Tranquility
	[GetSpellInfo(16914)] = 10, -- Hurricane
	-- priest
	[GetSpellInfo(15407)] = 3, -- mind flay
	[GetSpellInfo(48045)] = 5, -- mind sear
	[GetSpellInfo(47540)] = 2, -- penance
	-- mage
	[GetSpellInfo(5143)] = 5, -- arcane missiles
	[GetSpellInfo(10)] = 5, -- blizzard
	-- hunter
	[GetSpellInfo(1510)] = 6, -- volley
}

local function getChannelingTicks(spell)
	if not db.showticks then
		return 0
	end
	
	return channelingTicks[spell] or 0
end

function Player:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	self.delay = 0
	self.casting = nil
	self.channeling = true
	--FixMe: How do we work this out?
	self.channelingTicks = getChannelingTicks(spell)
	self.fadeOut = nil
	
	setBarTicks(self.channelingTicks)

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
	if position == "caststart" then
		castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	elseif position == "castend" then
		castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	end
end

function Player:UNIT_SPELLCAST_STOP(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	if self.casting then
		self.targetName = nil
		self.casting = nil
		self.fadeOut = true
		self.stopTime = GetTime()
		
		setBarTicks(0)
		castBar:SetValue(1.0)
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function Player:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	if self.channeling then
		self.channeling = nil
		self.fadeOut = true
		self.stopTime = GetTime()
		
		setBarTicks(0)
		castBar:SetValue(0)
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function Player:UNIT_SPELLCAST_FAILED(event, unit)
	if (unit ~= "player" and unit ~= "vehicle") or self.channeling or self.casting then 
		return
	end
	self.targetName = nil
	self.casting = nil
	self.channeling = nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	setBarTicks(0)
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function Player:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	self.targetName = nil
	self.casting = nil
	self.channeling = nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	setBarTicks(0)
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function Player:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime

	self.delay = (self.delay or 0) + (startTime - (oldStart or startTime))
end

function Player:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	
	self.delay = (self.delay or 0) + ((oldStart or startTime) - startTime)
end

do
	local backdrop = { insets = {} }
	local backdrop_insets = backdrop.insets
	
	function Player:ApplySettings()
		db = self.db.profile
		if castBarParent then
			
			castBarParent = self.castBarParent
			castBar = self.castBar
			castBarText = self.castBarText
			castBarTimeText = self.castBarTimeText
			castBarIcon = self.castBarIcon
			castBarSpark = self.castBarSpark
			
			castBarParent:ClearAllPoints()
			if not db.x then
				db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale) / 2) / db.scale
			end
			castBarParent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
			castBarParent:SetWidth(db.w+10)
			castBarParent:SetHeight(db.h+10)
			castBarParent:SetAlpha(db.alpha)
			castBarParent:SetScale(db.scale)
			
			backdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
			backdrop.tile = true
			backdrop.tileSize = 16
			backdrop.edgeFile = media:Fetch("border", db.border)
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
			castBar:SetPoint("CENTER",castBarParent,"CENTER")
			castBar:SetWidth(db.w)
			castBar:SetHeight(db.h)
			castBar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
			castBar:SetMinMaxValues(0, 1)
			
			if db.hidetimetext then
				castBarTimeText:Hide()
			else
				castBarTimeText:Show()
				castBarTimeText:ClearAllPoints()
				castBarTimeText:SetWidth(db.w)
				local position = db.timetextposition
				if position == "left" then
					castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("LEFT")
				elseif position == "center" then
					castBarTimeText:SetPoint("CENTER", castBar, "CENTER", db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("CENTER")
				elseif position == "right" then
					castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("RIGHT")
				end -- L["Cast Start Side"], L["Cast End Side"] --handled at runtime
			end
			castBarTimeText:SetFont(media:Fetch("font", db.font), db.timefontsize)
			castBarTimeText:SetShadowColor( 0, 0, 0, 1)
			castBarTimeText:SetShadowOffset( 0.8, -0.8 )
			castBarTimeText:SetTextColor(unpack(Quartz3.db.profile.timetextcolor))
			castBarTimeText:SetNonSpaceWrap(false)
			castBarTimeText:SetHeight(db.h)
			
			castTimeFormatString = "%."..db.casttimeprecision.."f"
			
			local temptext = castBarTimeText:GetText()
			if db.hidecasttime then
				castBarTimeText:SetFormattedText(timenum(10))
			else
				castBarTimeText:SetFormattedText("%s / %s", format(timenum(10)), format(timenum(10, true)))
			end
			local normaltimewidth = castBarTimeText:GetStringWidth()
			castBarTimeText:SetText(temptext)
			
			if db.hidenametext then
				castBarText:Hide()
			else
				castBarText:Show()
				castBarText:ClearAllPoints()
				local position = db.nametextposition
				if position == "left" then
					castBarText:SetPoint("LEFT", castBar, "LEFT", db.nametextx, db.nametexty)
					castBarText:SetJustifyH("LEFT")
					if db.hidetimetext or db.timetextposition ~= "right" then
						castBarText:SetWidth(db.w)
					else
						castBarText:SetWidth(db.w - normaltimewidth - 5)
					end
				elseif position == "center" then
					castBarText:SetPoint("CENTER", castBar, "CENTER", db.nametextx, db.nametexty)
					castBarText:SetJustifyH("CENTER")
				else -- L["Right"]
					castBarText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.nametextx, db.nametexty)
					castBarText:SetJustifyH("RIGHT")
					if db.hidetimetext or db.timetextposition ~= "left" then
						castBarText:SetWidth(db.w)
					else
						castBarText:SetWidth(db.w - normaltimewidth - 5)
					end
				end
			end
			castBarText:SetFont(media:Fetch("font", db.font), db.fontsize)
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
				if db.iconposition == "left" then
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
			castBarSpark:SetBlendMode("ADD")
			castBarSpark:SetWidth(20)
			castBarSpark:SetHeight(db.h*2.2)
			
			if db.hideblizz then
				CastingBarFrame.RegisterEvent = function() end
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
