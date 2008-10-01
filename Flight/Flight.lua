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
if Quartz:HasModule('Flight') then
	return
end

local L = AceLibrary("AceLocale-2.2"):new("Quartz")

local Quartz = Quartz
local QuartzFlight = Quartz:NewModule('Flight', 'AceHook-2.1', 'AceEvent-2.0')
local QuartzPlayer = Quartz:GetModule('Player')
local db
function QuartzFlight:OnInitialize()
	db = Quartz:AcquireDBNamespace("Flight")
	Quartz:RegisterDefaults("Flight", "profile", {
		color = {0.7, 1, 0.7},
		deplete = false,
	})
end
if InFlight then
	function QuartzFlight:OnEnable()
		LoadAddOn('InFlight') --!!delete
		self:Hook(InFlight, "StartTimer")
	end
	function QuartzFlight:StartTimer(object, ...)
		self.hooks[object].StartTimer(object, ...)
		
		local f = InFlightBar
		local _, duration = f:GetMinMaxValues()
		local _, locText = f:GetRegions()
		local destination = locText:GetText()

		self:BeginFlight(duration, destination)
	end
elseif ToFu then
	function QuartzFlight:OnEnable()
		self:RegisterEvent("ToFu_StartFlight")
	end
	function QuartzFlight:ToFu_StartFlight(start, destination, duration)
		if duration and duration > 0 then
			self:BeginFlight(duration, destination)
		end
	end
elseif FlightMapTimes_BeginFlight then
	function QuartzFlight:OnEnable()
		self:Hook("FlightMapTimes_BeginFlight")
	end
	function QuartzFlight:FlightMapTimes_BeginFlight(duration, destination)
		if duration and duration > 0 then
			self:BeginFlight(duration, destination)
		end
		return self.hooks.FlightMapTimes_BeginFlight(duration, destination)
	end
end
function QuartzFlight:BeginFlight(duration, destination)
	QuartzPlayer.casting = true
	QuartzPlayer.startTime = GetTime()
	QuartzPlayer.endTime = GetTime() + duration
	QuartzPlayer.delay = 0
	QuartzPlayer.fadeOut = nil
	if db.profile.deplete then
		QuartzPlayer.casting = nil
		QuartzPlayer.channeling = true
	else
		QuartzPlayer.casting = true
		QuartzPlayer.channeling = nil
	end
	
	QuartzPlayer.castBar:SetStatusBarColor(unpack(db.profile.color))
	
	QuartzPlayer.castBar:SetValue(0)
	QuartzPlayer.castBarParent:Show()
	QuartzPlayer.castBarParent:SetAlpha(QuartzPlayer.db.profile.alpha)
	
	QuartzPlayer.castBarSpark:Show()
	QuartzPlayer.castBarIcon:SetTexture(nil)
	QuartzPlayer.castBarText:SetText(destination)
	
	local position = QuartzPlayer.db.profile.timetextposition
	if position == L["Cast Start Side"] then
		QuartzPlayer.castBarTimeText:SetPoint('LEFT', QuartzPlayer.castBar, 'LEFT', QuartzPlayer.db.profile.timetextx, QuartzPlayer.db.profile.timetexty)
		QuartzPlayer.castBarTimeText:SetJustifyH("LEFT")
	elseif position == L["Cast End Side"] then
		QuartzPlayer.castBarTimeText:SetPoint('RIGHT', QuartzPlayer.castBar, 'RIGHT', -1 * QuartzPlayer.db.profile.timetextx, QuartzPlayer.db.profile.timetexty)
		QuartzPlayer.castBarTimeText:SetJustifyH("RIGHT")
	end
end
do
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz.ApplySettings()
	end
	local function getcolor(field)
		return unpack(db.profile[field])
	end
	local function set(field, value)
		db.profile[field] = value
		Quartz.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	Quartz.options.args.Flight = {
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
					return Quartz:IsModuleActive('Flight')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Flight', v)
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
end
