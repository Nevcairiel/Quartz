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
local Quartz3 = LibStub("AceAddon-3.0"):NewAddon("Quartz3", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")
local media = LibStub("LibSharedMedia-3.0")
local db

local defaults = {
	profile = {
		modules = { ["*"] = true },
		hidesamwise = true,
		sparkcolor = {1, 1, 1, 0.5},
		spelltextcolor = {1, 1, 1},
		timetextcolor = {1, 1, 1},
		castingcolor = {1.0, 0.49, 0},
		channelingcolor = {0.32, 0.3, 1},
		completecolor = {0.12, 0.86, 0.15},
		failcolor = {1.0, 0.09, 0},
		backgroundcolor = {0, 0, 0},
		bordercolor = {0, 0, 0},
		backgroundalpha = 1,
		borderalpha = 1,
	},
}

media:Register("statusbar", "Frost", "Interface\\AddOns\\Quartz\\textures\\Frost")
media:Register("statusbar", "Healbot", "Interface\\AddOns\\Quartz\\textures\\Healbot")
media:Register("statusbar", "LiteStep", "Interface\\AddOns\\Quartz\\textures\\LiteStep")
media:Register("statusbar", "Rocks", "Interface\\AddOns\\Quartz\\textures\\Rocks")
media:Register("statusbar", "Runes", "Interface\\AddOns\\Quartz\\textures\\Runes")
media:Register("statusbar", "Xeon", "Interface\\AddOns\\Quartz\\textures\\Xeon")
media:Register("border", "Tooltip enlarged", "Interface\\AddOns\\Quartz\\textures\\Tooltip-BigBorder")

function Quartz3:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("Quartz3DB", defaults, true)
	db = self.db.profile

	self:SetupOptions()
end

function Quartz3:OnEnable()
	if QuartzDB then
		QuartzDB = nil
		LibStub("AceTimer-3.0").ScheduleTimer(self, function()
			self:Print(L["Congratulations! You've just upgraded Quartz from the old Ace2-based version to the new Ace3 version!"])
			self:Print(L["Sadly, this also means your configuration was lost. You'll have to reconfigure Quartz using the new options integrated into the Interface Options Panel, quickly accessible with /quartz"])
			self:Print(L["Sorry for the inconvenience, and thanks for using Quartz!"])
		end, 1)
	end
	self.db.RegisterCallback(self, "OnProfileChanged", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ApplySettings")

	media.RegisterCallback(self, "LibSharedMedia_Registered", "ApplySettings")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", "ApplySettings")

	self:ApplySettings()
end

function Quartz3:ApplySettings()
	db = self.db.profile

	for k,v in self:IterateModules() do
		if self:GetModuleEnabled(k) and not v:IsEnabled() then
			self:EnableModule(k)
		elseif not self:GetModuleEnabled(k) and v:IsEnabled() then
			self:DisableModule(k)
		end
		if type(v.ApplySettings) == "function" then
			v:ApplySettings()
		end
	end
end

local copyExclude = {
	x = true,
	y = true,
}

function Quartz3:CopySettings(from, to)
	for k,v in pairs(from) do
		if to[k] and not copyExclude[k] and type(v) ~= "table" then
			to[k] = v
		end
	end
end

function Quartz3:GetModuleEnabled(module)
	return db.modules[module]
end

function Quartz3:SetModuleEnabled(module, value)
	local old = db.modules[module]
	db.modules[module] = value
	if old ~= value then
		if value then
			self:EnableModule(module)
		else
			self:DisableModule(module)
		end
	end
end
