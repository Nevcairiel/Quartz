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
local _G = getfenv(0)
local LibStub = _G.LibStub

local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = L["Swing"]
local Swing = Quartz3:NewModule(MODNAME, "AceEvent-3.0")
local Player = Quartz3:GetModule(L["Player"])

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local playerclass
local bit_bor = _G.bit.bor
local bit_band = _G.bit.band
local math_abs = _G.math.abs
local GetSpellInfo = _G.GetSpellInfo
local GetTime = _G.GetTime
local UnitAttackSpeed = _G.UnitAttackSpeed
local UnitClass = _G.UnitClass
local UnitDamage = _G.UnitDamage
local UnitRangedDamage = _G.UnitRangedDamage
local unpack = _G.unpack
local tonumber = _G.tonumber

local BOOKTYPE_SPELL = _G.BOOKTYPE_SPELL
local COMBATLOG_OBJECT_AFFILIATION_MINE = _G.COMBATLOG_OBJECT_AFFILIATION_MINE
local COMBATLOG_OBJECT_CONTROL_PLAYER = _G.COMBATLOG_OBJECT_CONTROL_PLAYER
local COMBATLOG_OBJECT_REACTION_FRIENDLY = _G.COMBATLOG_OBJECT_REACTION_FRIENDLY
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER

local autoshotname = GetSpellInfo(75)
local resetspells = {
	[GetSpellInfo(845)] = true, -- Cleave
	[GetSpellInfo(78)] = true, -- Heroic Strike
	[GetSpellInfo(6807)] = true, -- Maul
	[GetSpellInfo(2973)] = true, -- Raptor Strike
	[GetSpellInfo(1464)] = true, -- Slam
	[GetSpellInfo(56815)] = true, -- Rune Strike
}

local resetautoshotspells = {
	[GetSpellInfo(19434)] = true, -- Aimed Shot
}

local swingbar, swingbar_width, swingstatusbar, remainingtext, durationtext, db
local swingmode -- nil is none, 0 is meleeing, 1 is autoshooting
local starttime, duration

local db, getOptions

local defaults = {
	profile = {
		barcolor = {1, 1, 1},
		swingalpha = 1,
		swingheight = 4,
		swingposition = L["Top"],
		swinggap = -4,
		
		durationtext = true,
		remainingtext = true,
		
		x = 300,
		y = 300,
	}
}

local function OnUpdate()
	if starttime then
		local spent = GetTime() - starttime
		remainingtext:SetText(('%.1f'):format(duration - spent))
		local perc = spent / duration
		if perc > 1 then
			return swingbar:Hide()
		else
			swingstatusbar:SetValue(perc)
		end
	end
end

local function OnHide()
	swingbar:SetScript('OnUpdate', nil)
end

local function OnShow()
	swingbar:SetScript('OnUpdate', OnUpdate)
end

function Swing:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, MODNAME)

end
function Swing:OnEnable()
	local _, c = UnitClass('player')
	playerclass = playerclass or c
	-- fired when autoattack is enabled/disabled.
	self:RegisterEvent("PLAYER_ENTER_COMBAT")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT")
	-- fired when autoshot (or autowand) is enabled/disabled
	self:RegisterEvent("START_AUTOREPEAT_SPELL")
	self:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	
	self:RegisterEvent("UNIT_ATTACK")
	if not swingbar then
		swingbar = CreateFrame('Frame', 'Quartz3SwingBar', UIParent)
		swingbar:SetFrameStrata('HIGH')
		swingbar:SetScript('OnShow', OnShow)
		swingbar:SetScript('OnHide', OnHide)
		swingbar:SetMovable(true)
		swingbar:RegisterForDrag('LeftButton')
		swingbar:SetClampedToScreen(true)
		
		swingstatusbar = CreateFrame("StatusBar", nil, swingbar)
		
		durationtext = swingstatusbar:CreateFontString(nil, 'OVERLAY')
		remainingtext = swingstatusbar:CreateFontString(nil, 'OVERLAY')
		swingbar:Hide()
	end
	Quartz3.ApplySettings()
end

function Swing:OnDisable()
	swingbar:Hide()
end

function Swing:PLAYER_ENTER_COMBAT()
	local _,_,offhandlow, offhandhigh = UnitDamage('player')
	if math_abs(offhandlow - offhandhigh) <= 0.1 or playerclass == "DRUID" then
		swingmode = 0 -- shouldn't be dual-wielding
	end
end

function Swing:PLAYER_LEAVE_COMBAT()
	if not swingmode or swingmode == 0 then
		swingmode = nil
	end
end

function Swing:START_AUTOREPEAT_SPELL()
	swingmode = 1
end

function Swing:STOP_AUTOREPEAT_SPELL()
	if not swingmode or swingmode == 1 then
		swingmode = nil
	end
end

-- blizzard screws that global up, double usage in CombatLog.lua and GlobalStrings.lua, so we create it ourselves
local COMBATLOG_FILTER_ME = bit_bor(
				COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001,
				COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010,
				COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100,
				COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
				)

do
	local swordspecproc = false
	function Swing:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatevent, srcGUID, srcName, srcFlags, dstName, dstGUID, dstFlags, spellID, spellName)
		if (combatevent == "SPELL_EXTRA_ATTACKS") and spellName == "Sword Specialization" and (bit_band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) then
			swordspecproc = true
		elseif (combatevent == "SWING_DAMAGE" or combatevent == "SWING_MISSED") and (bit_band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) and swingmode == 0 then
			if (swordspecproc) then
				swordspecproc = false
			else
				self:MeleeSwing()
			end
		end
	end
end

function Swing:UNIT_SPELLCAST_SUCCEEDED(event, unit, spell)
	if swingmode == 0 then
		if resetspells[spell] then
			self:MeleeSwing()
		end
	elseif swingmode == 1 then
		if spell == autoshotname then
			self:Shoot()
		end
	end
	if resetautoshotspells[spell] then
		swingmode = 1
		self:Shoot()
	end
end
function Swing:UNIT_ATTACK(event, unit)
	if unit == 'player' then
		if not swingmode then
			return
		elseif swingmode == 0 then
			duration = UnitAttackSpeed('player')
		else
			duration = UnitRangedDamage('player')
		end
		durationtext:SetText(('%.1f'):format(duration))
	end
end
function Swing:MeleeSwing()
	duration = UnitAttackSpeed('player')
	durationtext:SetText(('%.1f'):format(duration))
	starttime = GetTime()
	swingbar:Show()
end
function Swing:Shoot()
	duration = UnitRangedDamage('player')
	durationtext:SetText(('%.1f'):format(duration))
	starttime = GetTime()
	swingbar:Show()
end
function Swing:ApplySettings()
	if swingbar and Quartz3:GetModuleEnabled(MODNAME) then
		swingbar:ClearAllPoints()
		swingbar:SetHeight(db.swingheight)
		swingbar_width = Player.Bar:GetWidth() - 8
		swingbar:SetWidth(swingbar_width)
		swingbar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		swingbar:SetBackdropColor(0,0,0)
		swingbar:SetAlpha(db.swingalpha)
		swingbar:SetScale(Player.db.profile.scale)

		if db.swingposition == L["Bottom"] then
			swingbar:SetPoint("TOP", Player.Bar, "BOTTOM", 0, -1 * db.swinggap)
		elseif db.swingposition == L["Top"] then
			swingbar:SetPoint("BOTTOM", Player.Bar, "TOP", 0, db.swinggap)
		else -- L["Free"]
			swingbar:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', db.x, db.y)
		end
		
		swingstatusbar:SetAllPoints(swingbar)
		swingstatusbar:SetStatusBarTexture(media:Fetch('statusbar', Player.db.profile.texture))
		swingstatusbar:SetStatusBarColor(unpack(db.barcolor))
		swingstatusbar:SetMinMaxValues(0, 1)
		
		if db.durationtext then
			durationtext:Show()
			durationtext:ClearAllPoints()
			durationtext:SetPoint('BOTTOMLEFT', swingbar, 'BOTTOMLEFT')
			durationtext:SetJustifyH("LEFT")
		else
			durationtext:Hide()
		end
		durationtext:SetFont(media:Fetch('font', Player.db.profile.font), 9)
		durationtext:SetShadowColor( 0, 0, 0, 1)
		durationtext:SetShadowOffset( 0.8, -0.8 )
		durationtext:SetTextColor(1,1,1)
		durationtext:SetNonSpaceWrap(false)
		durationtext:SetWidth(swingbar_width)
		
		if db.remainingtext then
			remainingtext:Show()
			remainingtext:ClearAllPoints()
			remainingtext:SetPoint('BOTTOMRIGHT', swingbar, 'BOTTOMRIGHT')
			remainingtext:SetJustifyH("RIGHT")
		else
			remainingtext:Hide()
		end
		remainingtext:SetFont(media:Fetch('font', Player.db.profile.font), 9)
		remainingtext:SetShadowColor( 0, 0, 0, 1)
		remainingtext:SetShadowOffset( 0.8, -0.8 )
		remainingtext:SetTextColor(1,1,1)
		remainingtext:SetNonSpaceWrap(false)
		remainingtext:SetWidth(swingbar_width)
	end
end

do
	local locked = true
	local function set(field, value)
		db.profile[field] = value
		Quartz3.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz3.ApplySettings()
	end
	local function getcolor(field)
		return unpack(db.profile[field])
	end
	local function nothing()
	end
	local function dragstart()
		swingbar:StartMoving()
	end
	local function dragstop()
		db.profile.x = swingbar:GetLeft()
		db.profile.y = swingbar:GetBottom()
		swingbar:StopMovingOrSizing()
	end
	local options
	function getOptions()
		options = options or {
		type = 'group',
		name = L["Swing"],
		desc = L["Swing"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz3:GetModuleEnabled(MODNAME)
				end,
				set = function(v)
					Quartz3:SetModuleEnabled(MODNAME, v)
				end,
				order = 100,
			},
			barcolor = {
				type = 'color',
				name = L["Bar Color"],
				desc = L["Set the color of the swing timer bar"],
				get = getcolor,
				set = setcolor,
				--passValue = 'barcolor',
				order = 103,
			},
			swingheight = {
				type = 'range',
				name = L["Height"],
				desc = L["Set the height of the swing timer bar"],
				min = 1,
				max = 20,
				step = 1,
				get = get,
				set = set,
				--passValue = 'swingheight',
				order = 104,
			},
			swingalpha = {
				type = 'range',
				name = L["Alpha"],
				desc = L["Set the alpha of the swing timer bar"],
				min = 0.05,
				max = 1,
				step = 0.05,
				isPercent = true,
				get = get,
				set = set,
				--passValue = 'swingalpha',
				order = 105,
			},
			swingposition = {
				type = 'select',
				name = L["Bar Position"],
				desc = L["Set the position of the swing timer bar"],
				get = get,
				set = set,
				--passValue = 'swingposition',
				values = {["top"] = L["Top"], ["bottom"] = L["Bottom"], ["free"] = L["Free"]},
				order = 106,
			},
			lock = {
				type = 'toggle',
				name = L["Lock"],
				desc = L["Toggle Cast Bar lock"],
				get = function()
					return locked
				end,
				set = function(v)
					if v then
						swingbar.Hide = nil
						swingbar:EnableMouse(false)
						swingbar:SetScript('OnDragStart', nil)
						swingbar:SetScript('OnDragStop', nil)
						if not swingmode then
							swingbar:Hide()
						end
					else
						swingbar:Show()
						swingbar:EnableMouse(true)
						swingbar:SetScript('OnDragStart', dragstart)
						swingbar:SetScript('OnDragStop', dragstop)
						swingbar:SetAlpha(1)
						swingbar.Hide = nothing
					end
					locked = v
				end,
				hidden = function()
					return db.profile.swingposition ~= L["Free"]
				end,
				order = 107,
			},
			x = {
				type = 'range',
				name = L["X"],
				desc = L["Set an exact X value for this bar's position."],
				get = get,
				set = set,
				min = -2560,
				max = 2560,
				--passValue = 'x',
				order = 108,
--				validate = function(v)
--					return tonumber(v) and true
--				end,
				hidden = function()
					return db.profile.swingposition ~= L["Free"]
				end,
				usage = L["Number"],
			},
			y = {
				type = 'range',
				name = L["Y"],
				desc = L["Set an exact Y value for this bar's position."],
				min = -2560,
				max = 2560,
				get = get,
				set = set,
				--passValue = 'y',
				order = 108,
--				validate = function(v)
--					return tonumber(v) and true
--				end,
				hidden = function()
					return db.profile.swingposition ~= L["Free"]
				end,
				usage = L["Number"],
			},
			swinggap = {
				type = 'range',
				name = L["Gap"],
				desc = L["Tweak the distance of the swing timer bar from the cast bar"],
				min = -35,
				max = 35,
				step = 1,
				get = get,
				set = set,
				--passValue = 'swinggap',
				order = 108,
			},
			durationtext = {
				type = 'toggle',
				name = L["Duration Text"],
				desc = L["Toggle display of text showing your total swing time"],
				get = get,
				set = set,
				--passValue = 'durationtext',
				order = 109,
			},
			remainingtext = {
				type = 'toggle',
				name = L["Remaining Text"],
				desc = L["Toggle display of text showing the time remaining until you can swing again"],
				get = get,
				set = set,
				--passValue = 'remainingtext',
				order = 110,
			},
		},
	}
	return options
	end
end
