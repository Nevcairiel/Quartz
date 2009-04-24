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

local Quartz = LibStub("AceAddon-3.0"):NewAddon("Quartz", "AceEvent-3.0", "AceConsole-3.0")

local db
local defaults = {
	profile = {
		hidesamwise = true,
		
		sparkcolor = {1,1,1,0.5},
		spelltextcolor = {1, 1, 1},
		timetextcolor = {1, 1, 1},
		castingcolor = {1.0,0.49, 0},
		channelingcolor = {0.32,0.3, 1},
		completecolor = {0.12, 0.86, 0.15},
		failcolor = {1.0, 0.09, 0},
		backgroundcolor = {0, 0, 0},
		bordercolor = {0,0,0},
		
		backgroundalpha = 1,
		borderalpha = 1,
		},
	}


function Quartz:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("QuartzDB", defaults, "Default")
	self.db.RegisterCallback(self, "OnProfileChanged", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ApplySettings")	
	db = self.db.profile

	self:SetupOptions()
end

function Quartz:OnEnable()
end

function Quartz:OnDisable()
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

function Mapster:GetModuleEnabled(module)
        return db.modules[module]
end

function Mapster:SetModuleEnabled(module, value)
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
		
local new, del
do
	local cache = setmetatable({}, {__mode='k'})
	function new()
		local t = next(cache)
		if t then
			cache[t] = nil
			return t
		else
			return {}
		end
	end
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end
		cache[t] = true
		return nil
	end
end

Quartz.new = new
Quartz.del = del
