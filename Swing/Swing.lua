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
local L = AceLibrary("AceLocale-2.2"):new("Quartz")
local media = LibStub("LibSharedMedia-3.0")
local autoshotname = GetSpellInfo(75)
local resetspells = {
	[GetSpellInfo(845)] = true, -- Cleave
	[GetSpellInfo(78)] = true, -- Heroic Strike
	[GetSpellInfo(6807)] = true, -- Maul
	[GetSpellInfo(2973)] = true, -- Raptor Strike
	[GetSpellInfo(1464)] = true, -- Slam
}
local resetautoshotspells = {
	[GetSpellInfo(19434)] = true, -- Aimed Shot
}
local _, playerclass = UnitClass('player')
local unpack = unpack
local math_abs = math.abs

local Quartz = Quartz
if Quartz:HasModule('Swing') then
	return
end
local QuartzSwing = Quartz:NewModule('Swing')
local QuartzPlayer = Quartz:GetModule('Player')

local GetTime = GetTime

local swingbar, swingbar_width, swingstatusbar, remainingtext, durationtext, db
local swingmode -- nil is none, 0 is meleeing, 1 is autoshooting
local starttime, duration

local BOOKTYPE_SPELL = BOOKTYPE_SPELL

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

function QuartzSwing:OnInitialize()
	db = Quartz:AcquireDBNamespace("Swing")
	Quartz:RegisterDefaults("Swing", "profile", {
		barcolor = {1, 1, 1},
		swingalpha = 1,
		swingheight = 4,
		swingposition = L["Top"],
		swinggap = -4,
		
		durationtext = true,
		remainingtext = true,
		
		x = 300,
		y = 300,
	})
end
function QuartzSwing:OnEnable()
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
		swingbar = CreateFrame('Frame', 'QuartzSwingBar', UIParent)
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
	Quartz.ApplySettings()
end
function QuartzSwing:OnDisable()
	swingbar:Hide()
end
function QuartzSwing:PLAYER_ENTER_COMBAT()
	local _,_,offhandlow, offhandhigh = UnitDamage('player')
	if math_abs(offhandlow - offhandhigh) <= 0.1 or playerclass == "DRUID" then
		swingmode = 0 -- shouldn't be dual-wielding
	end
end
function QuartzSwing:PLAYER_LEAVE_COMBAT()
	if not swingmode or swingmode == 0 then
		swingmode = nil
	end
end
function QuartzSwing:START_AUTOREPEAT_SPELL()
	swingmode = 1
end
function QuartzSwing:STOP_AUTOREPEAT_SPELL()
	if not swingmode or swingmode == 1 then
		swingmode = nil
	end
end

-- blizzard screws that global up, double usage in CombatLog.lua and GlobalStrings.lua, so we create it ourselves
local COMBATLOG_FILTER_ME = bit.bor(
				COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001,
				COMBATLOG_OBJECT_REACTION_FRIENDLY or 0x00000010,
				COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100,
				COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
				)

do
	local swordspecproc = false
	function QuartzSwing:COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, srcGUID, srcName, srcFlags, dstName, dstGUID, dstFlags, ...)
		if (event == "SPELL_EXTRA_ATTACKS") and (select(2, ...) == "Sword Specialization") and (bit.band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) then
			swordspecproc = true
		elseif (event == "SWING_DAMAGE" or event == "SWING_MISSED") and (bit.band(srcFlags, COMBATLOG_FILTER_ME) == COMBATLOG_FILTER_ME) and swingmode == 0 then
			if (swordspecproc) then
				swordspecproc = false
			else
				self:MeleeSwing()
			end
		end
	end
end

function QuartzSwing:UNIT_SPELLCAST_SUCCEEDED(unit, spell)
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
function QuartzSwing:UNIT_ATTACK(unit)
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
function QuartzSwing:MeleeSwing()
	duration = UnitAttackSpeed('player')
	durationtext:SetText(('%.1f'):format(duration))
	starttime = GetTime()
	swingbar:Show()
end
function QuartzSwing:Shoot()
	duration = UnitRangedDamage('player')
	durationtext:SetText(('%.1f'):format(duration))
	starttime = GetTime()
	swingbar:Show()
end
function QuartzSwing:ApplySettings()
	if swingbar and Quartz:IsModuleActive('Swing') then
		local ldb = db.profile
		swingbar:ClearAllPoints()
		swingbar:SetHeight(ldb.swingheight)
		swingbar_width = QuartzCastBar:GetWidth() - 8
		swingbar:SetWidth(swingbar_width)
		swingbar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		swingbar:SetBackdropColor(0,0,0)
		swingbar:SetAlpha(ldb.swingalpha)
		swingbar:SetScale(QuartzPlayer.db.profile.scale)
		if ldb.swingposition == L["Bottom"] then
			swingbar:SetPoint("TOP", QuartzCastBar, "BOTTOM", 0, -1 * ldb.swinggap)
		elseif ldb.swingposition == L["Top"] then
			swingbar:SetPoint("BOTTOM", QuartzCastBar, "TOP", 0, ldb.swinggap)
		else -- L["Free"]
			swingbar:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', ldb.x, ldb.y)
		end
		
		swingstatusbar:SetAllPoints(swingbar)
		swingstatusbar:SetStatusBarTexture(media:Fetch('statusbar', Quartz:GetModule('Player').db.profile.texture))
		swingstatusbar:SetStatusBarColor(unpack(ldb.barcolor))
		swingstatusbar:SetMinMaxValues(0, 1)
		
		if ldb.durationtext then
			durationtext:Show()
			durationtext:ClearAllPoints()
			durationtext:SetPoint('BOTTOMLEFT', swingbar, 'BOTTOMLEFT')
			durationtext:SetJustifyH("LEFT")
		else
			durationtext:Hide()
		end
		durationtext:SetFont(media:Fetch('font', QuartzPlayer.db.profile.font), 9)
		durationtext:SetShadowColor( 0, 0, 0, 1)
		durationtext:SetShadowOffset( 0.8, -0.8 )
		durationtext:SetTextColor(1,1,1)
		durationtext:SetNonSpaceWrap(false)
		durationtext:SetWidth(swingbar_width)
		
		if ldb.remainingtext then
			remainingtext:Show()
			remainingtext:ClearAllPoints()
			remainingtext:SetPoint('BOTTOMRIGHT', swingbar, 'BOTTOMRIGHT')
			remainingtext:SetJustifyH("RIGHT")
		else
			remainingtext:Hide()
		end
		remainingtext:SetFont(media:Fetch('font', QuartzPlayer.db.profile.font), 9)
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
		Quartz.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz.ApplySettings()
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
	Quartz.options.args.Swing = {
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
					return Quartz:IsModuleActive('Swing')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Swing', v)
				end,
				order = 100,
			},
			barcolor = {
				type = 'color',
				name = L["Bar Color"],
				desc = L["Set the color of the swing timer bar"],
				get = getcolor,
				set = setcolor,
				passValue = 'barcolor',
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
				passValue = 'swingheight',
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
				passValue = 'swingalpha',
				order = 105,
			},
			swingposition = {
				type = 'text',
				name = L["Bar Position"],
				desc = L["Set the position of the swing timer bar"],
				get = get,
				set = set,
				passValue = 'swingposition',
				validate = {L["Top"], L["Bottom"], L["Free"]},
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
				type = 'text',
				name = L["X"],
				desc = L["Set an exact X value for this bar's position."],
				get = get,
				set = set,
				passValue = 'x',
				order = 108,
				validate = function(v)
					return tonumber(v) and true
				end,
				hidden = function()
					return db.profile.swingposition ~= L["Free"]
				end,
				usage = L["Number"],
			},
			y = {
				type = 'text',
				name = L["Y"],
				desc = L["Set an exact Y value for this bar's position."],
				get = get,
				set = set,
				passValue = 'y',
				order = 108,
				validate = function(v)
					return tonumber(v) and true
				end,
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
				passValue = 'swinggap',
				order = 108,
			},
			durationtext = {
				type = 'toggle',
				name = L["Duration Text"],
				desc = L["Toggle display of text showing your total swing time"],
				get = get,
				set = set,
				passValue = 'durationtext',
				order = 109,
			},
			remainingtext = {
				type = 'toggle',
				name = L["Remaining Text"],
				desc = L["Toggle display of text showing the time remaining until you can swing again"],
				get = get,
				set = set,
				passValue = 'remainingtext',
				order = 110,
			},
		},
	}
end