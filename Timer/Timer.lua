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

local Quartz = Quartz
if Quartz:HasModule('Timer') then
	return
end
local QuartzTimer = Quartz:NewModule('Timer')
local self = QuartzTimer
local QuartzMirror = Quartz:GetModule('Mirror')
local new, del = Quartz.new, Quartz.del

local GetTime = GetTime
local table_remove = table.remove

local _G = getfenv(0)

local external = QuartzMirror.ExternalTimers
local thistimers = {}

function QuartzTimer:OnInitialize()
	Quartz:RegisterChatCommand({'/qt', '/quartzt', '/quartztimer'}, function(msg)
		if Quartz:IsModuleActive(self) then
			if msg:match('^kill') then
				local name = msg:match('^kill (.+)$')
				if name then
					external[name] = del(external[name])
					for k, v in ipairs(thistimers) do
						if v == name then
							table_remove(thistimers, k)
							break
						end
					end
					self:TriggerEvent("QuartzMirror_UpdateCustom")
				else
					return Quartz:Print(L['Usage: /quartztimer timername 60 or /quartztimer kill timername'])
				end
			else
				local duration = tonumber(msg:match('^(%d+)'))
				local name
				if duration then
					name = msg:match('^%d+ (.+)$')
				else
					duration = tonumber(msg:match('(%d+)$'))
					if not duration then
						return Quartz:Print(L['Usage: /quartztimer timername 60 or /quartztimer 60 timername'])
					end
					name = msg:match('^(.+) %d+$')
				end
				if not name then
					return Quartz:Print(L['Usage: /quartztimer timername 60 or /quartztimer kill timername'])
				end
				local currentTime = GetTime()
				external[name].startTime = currentTime
				external[name].endTime = currentTime + duration
				for k, v in ipairs(thistimers) do
					if v == name then
						table_remove(thistimers, k)
						break
					end
				end
				thistimers[#thistimers+1] = name
				self:TriggerEvent("QuartzMirror_UpdateCustom")
			end
		else
			Quartz:Print(L["Timers module currently disabled, re-enable it in the menu"])
		end
	end)
end
function QuartzTimer:OnDisable()
	for k, v in pairs(thistimers) do
		external[v] = del(external[v])
		thistimers[k] = nil
	end
	self:TriggerEvent("QuartzMirror_UpdateCustom")
end
do
	local newname, newlength
	Quartz.options.args.Timer = {
		type = 'group',
		name = L["Timer"],
		desc = L["Timer"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Timer')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Timer', v)
				end,
				order = 99,
			},
			newtimername = {
				type = 'text',
				name = L["New Timer Name"],
				desc = L["Set a name for the new timer"],
				get = function()
					return newname or ''
				end,
				set = function(v)
					newname = v
				end,
				usage = '',
				order = 100,
			},
			newtimerlength = {
				type = 'text',
				name = L["New Timer Length"],
				desc = L["Length of the new timer, in seconds"],
				get = function()
					return newlength or 0
				end,
				set = function(v)
					newlength = tonumber(v)
				end,
				validate = function(v)
					return tonumber(v)
				end,
				usage = L["<Time in seconds>"],
				order = 101,
			},
			makenewtimer = {
				type = 'execute',
				name = L["Make Timer"],
				desc = L["Make a new timer using the above settings.  NOTE: it may be easier for you to simply use the command line to make timers, /qt"],
				func = function()
					local currentTime = GetTime()
					external[newname].startTime = currentTime
					external[newname].endTime = currentTime + newlength
					for k, v in ipairs(thistimers) do
						if v == newname then
							table_remove(thistimers, k)
							break
						end
					end
					thistimers[#thistimers+1] = newname
					self:TriggerEvent("QuartzMirror_UpdateCustom")
					newname = nil
					newlength = nil
				end,
				disabled = function()
					return not (newname and newlength)
				end,
				order = -2,
			},
			killtimer = {
				type = 'text',
				name = L["Stop Timer"],
				desc = L["Select a timer to stop"],
				get = function()
					return ''
				end,
				set = function(name)
					if name then
						external[name] = del(external[name])
						for k, v in ipairs(thistimers) do
							if v == name then
								table_remove(thistimers, k)
								break
							end
						end
						self:TriggerEvent("QuartzMirror_UpdateCustom")
					end
				end,
				validate = thistimers,
				order = -1,
			},
		},
	}
end