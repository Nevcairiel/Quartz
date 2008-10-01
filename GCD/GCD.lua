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

local unpack = unpack

local Quartz = Quartz
if Quartz:HasModule('GCD') then
	return
end
local QuartzGCD = Quartz:NewModule('GCD')
local QuartzPlayer = Quartz:GetModule('Player')

local GetTime = GetTime

local gcdbar, gcdbar_width, gcdspark, db
local starttime, duration, warned, spell1id, spell2id, usingspell

local BOOKTYPE_SPELL = BOOKTYPE_SPELL

local function OnUpdate()
	gcdspark:ClearAllPoints()
	local perc = (GetTime() - starttime) / duration
	if perc > 1 then
		return gcdbar:Hide()
	else
		if db.profile.deplete then
			gcdspark:SetPoint('CENTER', gcdbar, 'LEFT', gcdbar_width * (1-perc), 0)
		else
			gcdspark:SetPoint('CENTER', gcdbar, 'LEFT', gcdbar_width * perc, 0)
		end
	end
end
local function OnHide()
	gcdbar:SetScript('OnUpdate', nil)
	usingspell = nil
end
local function OnShow()
	gcdbar:SetScript('OnUpdate', OnUpdate)
end

function QuartzGCD:OnInitialize()
	db = Quartz:AcquireDBNamespace("GCD")
	Quartz:RegisterDefaults("GCD", "profile", {
		sparkcolor = {1, 1, 1},
		gcdalpha = 0.9,
		gcdheight = 4,
		gcdposition = L["Bottom"],
		gcdgap = -4,
		
		deplete = false,
		
		x = 500,
		y = 300,
	})
	Quartz:RegisterDefaults("GCD", "char", {
		spell = '',
		backupspell = '',
	})
end
function QuartzGCD:OnEnable()
	self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
	self:RegisterEvent("SPELLS_CHANGED", "ApplySettings")
	if not gcdbar then
		gcdbar = CreateFrame('Frame', 'QuartzGCDBar', UIParent)
		gcdbar:SetFrameStrata('HIGH')
		gcdbar:SetScript('OnShow', OnShow)
		gcdbar:SetScript('OnHide', OnHide)
		gcdbar:SetMovable(true)
		gcdbar:RegisterForDrag('LeftButton')
		gcdbar:SetClampedToScreen(true)
		
		gcdspark = gcdbar:CreateTexture(nil, 'DIALOG')
		gcdbar:Hide()
	end
	Quartz.ApplySettings()
end
function QuartzGCD:OnDisable()
	gcdbar:Hide()
end

function QuartzGCD:ACTIONBAR_UPDATE_COOLDOWN()
	if spell1id then
		local start, dur = GetSpellCooldown(spell1id, BOOKTYPE_SPELL)
		if dur > 0 and dur <= 2 then
			usingspell = 1
			starttime = start
			duration = dur
			gcdbar:Show()
			return
		elseif usingspell == 1 and dur == 0 then
			gcdbar:Hide()
		end
	end
	if spell2id then
		local start, dur = GetSpellCooldown(spell2id, BOOKTYPE_SPELL)
		if dur > 0 and dur <= 2 then
			usingspell = 2
			starttime = start
			duration = dur
			gcdbar:Show()
			return
		elseif usingspell == 2 and dur == 0 then
			gcdbar:Hide()
		end
	end
end
function QuartzGCD:ApplySettings()
	if gcdbar and Quartz:IsModuleActive('GCD') then
		local ldb = db.profile
		gcdbar:ClearAllPoints()
		gcdbar:SetHeight(ldb.gcdheight)
		gcdbar_width = QuartzCastBar:GetWidth() - 8
		gcdbar:SetWidth(gcdbar_width)
		gcdbar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		gcdbar:SetBackdropColor(0,0,0)
		gcdbar:SetAlpha(ldb.gcdalpha)
		gcdbar:SetScale(QuartzPlayer.db.profile.scale)
		if ldb.gcdposition == L["Bottom"] then
			gcdbar:SetPoint("TOP", QuartzCastBar, "BOTTOM", 0, -1 * ldb.gcdgap)
		elseif ldb.gcdposition == L["Top"] then
			gcdbar:SetPoint("BOTTOM", QuartzCastBar, "TOP", 0, ldb.gcdgap)
		else -- L["Free"]
			gcdbar:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', ldb.x, ldb.y)
		end
		
		gcdspark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		gcdspark:SetVertexColor(unpack(ldb.sparkcolor))
		gcdspark:SetBlendMode('ADD')
		gcdspark:SetWidth(25)
		gcdspark:SetHeight(ldb.gcdheight*2.5)
		
		if db.char.spell == '' then
			if not warned then
				Quartz:Print(L["Spell_Warning"])
				warned = true
			end
		else
			spell1id = nil
			spell2id = nil
			for tab = 1, 4 do
				local _, _, offset, numSpells = GetSpellTabInfo(tab)
				for i = (1+offset), (offset+numSpells) do
					local spell = GetSpellName(i, BOOKTYPE_SPELL)
					if spell == db.char.spell then
						spell1id = i
					elseif spell == db.char.backupspell then
						spell2id = i
					end
				end
			end
		end
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
	local function setspell(field, value)
		for tab = 1, 4 do
			local _, _, offset, numSpells = GetSpellTabInfo(tab)
			for i = (1+offset), (offset+numSpells) do
				local spell = GetSpellName(i, BOOKTYPE_SPELL)
				if spell:lower() == value:lower() then
					db.char[field] = spell
					return
				end
			end
		end
		Quartz:Print(L["Invalid Spell"])
		db.char[field] = ''
		Quartz.ApplySettings()
	end
	local function getspell(field)
		return db.char[field]
	end
	local function nothing()
	end
	local function dragstart()
		gcdbar:StartMoving()
	end
	local function dragstop()
		db.profile.x = gcdbar:GetLeft()
		db.profile.y = gcdbar:GetBottom()
		gcdbar:StopMovingOrSizing()
	end
	Quartz.options.args.GCD = {
		type = 'group',
		name = L["Global Cooldown"],
		desc = L["Global Cooldown"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('GCD')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('GCD', v)
				end,
				order = 100,
			},
			spell = {
				type = 'text',
				name = L["%s Spell"]:format(L["Primary"]),
				desc = L["%s spell to check for the Global Cooldown"]:format(L["Primary"]),
				get = getspell,
				set = setspell,
				passValue = 'spell',
				usage = L["<Spell Name>"],
				order = 101,
			},
			backupspell = {
				type = 'text',
				name = L["%s Spell"]:format(L["Backup"]),
				desc = L["%s spell to check for the Global Cooldown"]:format(L["Backup"]),
				get = getspell,
				set = setspell,
				passValue = 'backupspell',
				usage = L["<Spell Name>"],
				order = 102,
			},
			gcdcolor = {
				type = 'color',
				name = L["Spark Color"],
				desc = L["Set the color of the GCD bar spark"],
				get = getcolor,
				set = setcolor,
				passValue = 'sparkcolor',
				order = 103,
			},
			gcdheight = {
				type = 'range',
				name = L["Height"],
				desc = L["Set the height of the GCD bar"],
				min = 1,
				max = 30,
				step = 1,
				get = get,
				set = set,
				passValue = 'gcdheight',
				order = 104,
			},
			gcdalpha = {
				type = 'range',
				name = L["Alpha"],
				desc = L["Set the alpha of the GCD bar"],
				min = 0.05,
				max = 1,
				step = 0.05,
				isPercent = true,
				get = get,
				set = set,
				passValue = 'gcdalpha',
				order = 105,
			},
			gcdposition = {
				type = 'text',
				name = L["Bar Position"],
				desc = L["Set the position of the GCD bar"],
				get = get,
				set = set,
				passValue = 'gcdposition',
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
						gcdbar.Hide = nil
						gcdbar:EnableMouse(false)
						gcdbar:SetScript('OnDragStart', nil)
						gcdbar:SetScript('OnDragStop', nil)
						gcdbar:Hide()
					else
						gcdbar:Show()
						gcdbar:EnableMouse(true)
						gcdbar:SetScript('OnDragStart', dragstart)
						gcdbar:SetScript('OnDragStop', dragstop)
						gcdbar:SetAlpha(1)
						gcdbar.Hide = nothing
					end
					locked = v
				end,
				hidden = function()
					return db.profile.gcdposition ~= L["Free"]
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
					return db.profile.gcdposition ~= L["Free"]
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
					return db.profile.gcdposition ~= L["Free"]
				end,
				usage = L["Number"],
			},
			gcdgap = {
				type = 'range',
				name = L["Gap"],
				desc = L["Tweak the distance of the GCD bar from the cast bar"],
				min = -35,
				max = 35,
				step = 1,
				get = get,
				set = set,
				passValue = 'gcdgap',
				order = 109,
			},
			deplete = {
				type = 'toggle',
				name = L["Deplete"],
				desc = L["Reverses the direction of the GCD spark, causing it to move right-to-left"],
				get = get,
				set = set,
				passValue = 'deplete',
				order = 110,
			},
		},
	}
end