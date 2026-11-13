--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010-2017 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >

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

-- Event handling for the modules of Quartz.
--
-- Every object that registers events gets a frame of its own, which allows events to be registered
-- for specific units only. Those are filtered by the client, instead of being delivered for every unit.
--
-- The functions are available on every module. A module has to unregister its events when it is disabled:
--   function Module:OnDisable()
--       self:UnregisterAllEvents()
--   end
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

local Events = {}

local CreateFrame = CreateFrame
local type, error, wipe = type, error, wipe

-- the event frame of every object
local frames = {}

local function OnEvent(frame, event, ...)
	local handler = frame.handlers[event]
	if not handler then return end

	local object = frame.object
	if type(handler) == "string" then
		object[handler](object, event, ...)
	else
		handler(object, event, ...)
	end
end

local function GetFrame(object)
	local frame = frames[object]
	if not frame then
		frame = CreateFrame("Frame")
		frame.object = object
		frame.handlers = {}
		frame:SetScript("OnEvent", OnEvent)
		frames[object] = frame
	end
	return frame
end

-- The handler of an event is a method of the object, by default the one named like the event, or a function.
-- Both are called with the object, the event and its arguments.
local function SetHandler(frame, event, handler, usage)
	if type(event) ~= "string" then
		error(usage .. ": 'event' - string expected.", 3)
	end
	handler = handler or event
	if type(handler) == "string" then
		if type(frame.object[handler]) ~= "function" then
			error(usage .. ": 'handler' - method '" .. handler .. "' not found.", 3)
		end
	elseif type(handler) ~= "function" then
		error(usage .. ": 'handler' - string or function expected.", 3)
	end
	frame.handlers[event] = handler
end

--- Register an event
-- @param event The event to register
-- @param handler The method or function to call, the method named like the event if omitted
function Events:RegisterEvent(event, handler)
	local frame = GetFrame(self)
	SetHandler(frame, event, handler, "Usage: RegisterEvent(event[, handler])")

	-- replaces a registration for units
	frame:UnregisterEvent(event)
	frame:RegisterEvent(event)
end

--- Register an event for up to two units, it is not delivered for any other unit
-- @param event The event to register
-- @param handler The method or function to call, the method named like the event if nil
-- @param unit1 The unit to register the event for
-- @param unit2 An optional second unit
function Events:RegisterUnitEvent(event, handler, unit1, unit2)
	if type(unit1) ~= "string" then
		error("Usage: RegisterUnitEvent(event, handler, unit1[, unit2]): 'unit1' - string expected.", 2)
	end
	local frame = GetFrame(self)
	SetHandler(frame, event, handler, "Usage: RegisterUnitEvent(event, handler, unit1[, unit2])")

	-- replaces a previous registration, for all or other units
	frame:UnregisterEvent(event)
	if unit2 then
		frame:RegisterUnitEvent(event, unit1, unit2)
	else
		frame:RegisterUnitEvent(event, unit1)
	end
end

--- Unregister an event
function Events:UnregisterEvent(event)
	local frame = frames[self]
	if frame then
		frame.handlers[event] = nil
		frame:UnregisterEvent(event)
	end
end

--- Unregister all events
function Events:UnregisterAllEvents()
	local frame = frames[self]
	if frame then
		wipe(frame.handlers)
		frame:UnregisterAllEvents()
	end
end

-- make the functions available on all modules
Quartz3:SetDefaultModulePrototype(Events)
