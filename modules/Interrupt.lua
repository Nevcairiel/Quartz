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

local MODNAME = L["Interrupt"]
local Interrupt = Quartz3:NewModule(MODNAME, "AceEvent-3.0")
local Player = Quartz3:GetModule(L["Player"])

local db, getOptions

local GetTime = _G.GetTime
local unpack = _G.unpack
local SPELLINTERRUPTOTHERSELF = _G.SPELLINTERRUPTOTHERSELF
local UNKNOWN = _G.UNKNOWN

local defaults = {
	profile = {
		interruptcolor = {0,0,0},
	},
}

function Interrupt:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, MODNAME)
end

function Interrupt:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function Interrupt:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, _, sourceName, _, _, _, destFlags)
	if combatEvent == 'SPELL_INTERRUPT' and destFlags == 0x511 then
		Player.Bar.castBarText:SetText(L["INTERRUPTED (%s)"]:format((sourceName or UNKNOWN):upper()))
		Player.Bar.castBar:SetStatusBarColor(unpack(db.profile.interruptcolor))
		Player.Bar.stopTime = GetTime()
	end
end

do
	local options
	function getOptions()
		options = options or {
		type = 'group',
		name = L["Interrupt"],
		desc = L["Interrupt"],
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
			interruptcolor = {
				type = 'color',
				name = L["Interrupt Color"],
				desc = L["Set the color the cast bar is changed to when you have a spell interrupted"],
				set = function(...)
					db.profile.interruptcolor = {...}
				end,
				get = function()
					return unpack(db.profile.interruptcolor)
				end,
				order = 101,
			},
		},
	}
	return options
	end
end
