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
if Quartz:HasModule('Range') then
	return
end
local QuartzRange = Quartz:NewModule('Range')
local QuartzPlayer = Quartz:GetModule('Player')

local GetTime = GetTime
local IsSpellInRange = IsSpellInRange
local f, OnUpdate, db, spell, target, modified, r, g, b, castBar
do
	local refreshtime = 0.25
	local sincelast = 0
	function OnUpdate(frame, elapsed)
		sincelast = sincelast + elapsed
		if sincelast >= refreshtime then
			sincelast = 0
			if not castBar:IsVisible() or QuartzPlayer.fadeOut then
				return f:SetScript('OnUpdate', nil)
			end
			if IsSpellInRange(spell, target) == 0 then
				r, g, b = castBar:GetStatusBarColor()
				modified = true
				castBar:SetStatusBarColor(unpack(db.profile.rangecolor))
			elseif modified then
				castBar:SetStatusBarColor(r,g,b)
				modified, r, g, b = nil, nil, nil, nil
			end
		end
	end
end
function QuartzRange:OnInitialize()
	f = CreateFrame('Frame', nil, UIParent)
	db = Quartz:AcquireDBNamespace("Range")
	Quartz:RegisterDefaults("Range", "profile", {
		rangecolor = {1, 1, 1},
	})
end
function QuartzRange:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
end
function QuartzRange:UNIT_SPELLCAST_START(unit)
	if unit ~= 'player' then
		return
	end
	if not castBar then
		castBar = QuartzPlayer.castBar
	end
	if target then
		spell = UnitCastingInfo(unit)
		modified, r, g, b = nil, nil, nil, nil
		f:SetScript('OnUpdate', OnUpdate)
	end
end
function QuartzRange:UNIT_SPELLCAST_CHANNEL_START(unit)
	if unit ~= 'player' then
		return
	end
	if not castBar then
		castBar = QuartzPlayer.castBar
	end
	if target then
		spell = UnitChannelInfo(unit)
		modified, r, g, b = nil, nil, nil, nil
		f:SetScript('OnUpdate', OnUpdate)
	end
end
function QuartzRange:UNIT_SPELLCAST_SENT(unit, _, _, name)
	if unit ~= 'player' then
		return
	end
	if name then
		if name == UnitName('player') then
			target = 'player'
		elseif name == UnitName('target') then
			target = 'target'
		elseif name == UnitName('focus') then
			target = 'focus'
		else
			target = nil
		end
	else
		target = nil
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
	Quartz.options.args.Range = {
		type = 'group',
		name = L["Range"],
		desc = L["Range"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Range')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Range', v)
				end,
				order = 100,
			},
			rangecolor = {
				type = 'color',
				name = L["Out of Range Color"],
				desc = L["Set the color to turn the cast bar when the target is out of range"],
				get = getcolor,
				set = setcolor,
				passValue = 'rangecolor',
				order = 101,
			},
		},
	}
end