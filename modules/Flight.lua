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
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = L["Flight"]
local Flight = Quartz3:NewModule(MODNAME, "AceHook-3.0", "AceEvent-3.0")
local Player = Quartz3:GetModule(L["Player"])
local self = Flight

local db

local defaults = {
	profile = {
		color = {0.7, 1, 0.7},
		deplete = false,
		},
	}

local getOptions
local options
do
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz3.ApplySettings()
	end
	local function getcolor(field)
		return unpack(db.profile[field])
	end
	local function set(field, value)
		db.profile[field] = value
		Quartz3.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end

	function getOptions() 
	options = options or {
		type = 'group',
		name = L["Flight"],
		desc = L["Flight"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz3:IsModuleActive('Flight')
				end,
				set = function(v)
					Quartz3:ToggleModuleActive('Flight', v)
				end,
				order = 100,
			},
			color = {
				type = 'color',
				name = L["Flight Map Color"],
				desc = L["Set the color to turn the cast bar when taking a flight path"],
				get = getcolor,
				set = setcolor,
				passValue = 'color',
				order = 101,
			},
			deplete = {
				type = 'toggle',
				name = L["Deplete"],
				desc = L["Deplete"],
				get = get,
				set = set,
				passValue = 'deplete',
				order = 102,
			},
		},
	}
	return options
	end
end


function Flight:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, MODNAME)
end

if InFlight then
	function Flight:OnEnable()
		LoadAddOn('InFlight') --!!delete
		self:Hook(InFlight, "StartTimer")
	end
	function Flight:StartTimer(object, ...)
		self.hooks[object].StartTimer(object, ...)
		
		local f = InFlightBar
		local _, duration = f:GetMinMaxValues()
		local _, locText = f:GetRegions()
		local destination = locText:GetText()

		self:BeginFlight(duration, destination)
	end

elseif ToFu then
	function Flight:OnEnable()
		self:RegisterEvent("ToFu_StartFlight")
	end
	function Flight:ToFu_StartFlight(start, destination, duration)
		if duration and duration > 0 then
			self:BeginFlight(duration, destination)
		end
	end
elseif FlightMapTimes_BeginFlight then
	function Flight:OnEnable()
		self:Hook("FlightMapTimes_BeginFlight")
	end
	function Flight:FlightMapTimes_BeginFlight(duration, destination)
		if duration and duration > 0 then
			self:BeginFlight(duration, destination)
		end
		return self.hooks.FlightMapTimes_BeginFlight(duration, destination)
	end
end
function Flight:BeginFlight(duration, destination)
	Player.casting = true
	Player.startTime = GetTime()
	Player.endTime = GetTime() + duration
	Player.delay = 0
	Player.fadeOut = nil
	if db.profile.deplete then
		Player.casting = nil
		Player.channeling = true
	else
		Player.casting = true
		Player.channeling = nil
	end
	
	Player.castBar:SetStatusBarColor(unpack(db.profile.color))
	
	Player.castBar:SetValue(0)
	Player.castBarParent:Show()
	Player.castBarParent:SetAlpha(Player.db.profile.alpha)
	
	Player.castBarSpark:Show()
	Player.castBarIcon:SetTexture(nil)
	Player.castBarText:SetText(destination)
	
	local position = Player.db.profile.timetextposition
	if position == L["Cast Start Side"] then
		Player.castBarTimeText:SetPoint('LEFT', Player.castBar, 'LEFT', Player.db.profile.timetextx, Player.db.profile.timetexty)
		Player.castBarTimeText:SetJustifyH("LEFT")
	elseif position == L["Cast End Side"] then
		Player.castBarTimeText:SetPoint('RIGHT', Player.castBar, 'RIGHT', -1 * Player.db.profile.timetextx, Player.db.profile.timetexty)
		Player.castBarTimeText:SetJustifyH("RIGHT")
	end
end
