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
	local function setOpt(info, value)
		db[info[#info]] = value
		Player:ApplySettings()
	end

	local options
	function getOptions()
		if not options then
			options = Player.Bar:CreateOptions()
			options.args.hideblizz = {
				type = "toggle",
				name = L["Disable Blizzard Cast Bar"],
				desc = L["Disable and hide the default UI's casting bar"],
				set = setOpt,
				order = 101,
			}
			options.args.showticks = {
				type = "toggle",
				name = L["Show channeling ticks"],
				desc = L["Show damage / mana ticks while channeling spells like Drain Life or Blizzard"],
				order = 102,
			}
		end
		return options
	end
end

function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	self.Bar = Quartz3.CastBarTemplate:new(self, "player", MODNAME, L["Player"], db)
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

----------------------------
-- Cast Bar Hooks

function Player:OnHide()
	local Latency = Quartz3:GetModule(L["Latency"],true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
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
