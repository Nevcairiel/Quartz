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
					toggle = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enable"],
						get = function()
							return Quartz3:GetModuleEnabled(MODNAME)
						end,
						set = function(info, v)
							Quartz3:SetModuleEnabled(MODNAME, v)
						end,
						order = 99,
					},
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

function Player:OnHide()
	local Latency = Quartz3:GetModule(L["Latency"],true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
	end
end

function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	self.Bar = Quartz3.CastBarTemplate:new("Quart3CastBar", self, "player", db)
end


function Player:OnEnable()
	self.Bar:RegisterEvents()
	self:ApplySettings()
end

function Player:OnDisable()
	self.Bar:UnregisterEvents()
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
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
	CastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
	[GetSpellInfo(12051)] = 4, -- evocation
	-- hunter
	[GetSpellInfo(1510)] = 6, -- volley
}

local function getChannelingTicks(spell)
	if not db.showticks then
		return 0
	end
	
	return channelingTicks[spell] or 0
end

function Player:ApplySettings()
	db = self.db.profile
	
	if self.Bar and self:IsEnabled() then
		self.Bar:ApplySettings(db)
		
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
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
			CastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		end
	end
end
