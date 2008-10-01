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

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent

local Quartz = Quartz
if Quartz:HasModule('Tradeskill') then
	return
end
local QuartzTradeskill = Quartz:NewModule('Tradeskill', 'AceHook-2.1')
local QuartzPlayer = Quartz:GetModule('Player')

local repeattimes, castname, duration, totaltime, starttime, casting, bail
local completedcasts = 0
local restartdelay = 1
local function timenum(num)
	if num <= 10 then
		return ('%.1f'):format(num)
	elseif num <= 60 then
		return ('%d'):format(num)
	else
		return ('%d:%02d'):format(num / 60, num % 60)
	end
end
local function tradeskillOnUpdate()
	local currentTime = GetTime()
	if casting then
		local elapsed = duration * completedcasts + currentTime - starttime
		castBar:SetValue(elapsed)
		
		local perc = (currentTime - starttime) / duration
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint('CENTER', castBar, 'LEFT', perc * QuartzPlayer.db.profile.w, 0)
		
		if QuartzPlayer.db.profile.hidecasttime then
			castBarTimeText:SetText(timenum(totaltime - elapsed))
		else
			castBarTimeText:SetText(("%s / %s"):format(timenum(totaltime - elapsed), timenum(totaltime)))
		end
	else
		if (starttime + duration + restartdelay < currentTime) or (completedcasts >= repeattimes) or bail or completedcasts == 0 then
			QuartzPlayer.fadeOut = true
			QuartzPlayer.stopTime = currentTime
			castBar:SetValue(duration * repeattimes)
			castBarTimeText:SetText('')
			castBarSpark:Hide()
			castBarParent:SetScript('OnUpdate', QuartzPlayer.OnUpdate)
			castBar:SetMinMaxValues(0, 1)
		else
			local elapsed = duration * completedcasts
			castBar:SetValue(elapsed)
			
			castBarSpark:ClearAllPoints()
			castBarSpark:SetPoint('CENTER', castBar, 'LEFT', QuartzPlayer.db.profile.w, 0)
			
			if QuartzPlayer.db.profile.hidecasttime then
				castBarTimeText:SetText(timenum(totaltime - elapsed))
			else
				castBarTimeText:SetText(("%s / %s"):format(timenum(totaltime - elapsed), timenum(totaltime)))
			end
		end
	end
end
function QuartzTradeskill:OnEnable()
	self:Hook(QuartzPlayer, "UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:Hook("DoTradeSkill", true)
end
function QuartzTradeskill:UNIT_SPELLCAST_START(object, unit)
	if unit ~= 'player' then
		return self.hooks[object].UNIT_SPELLCAST_START(object, unit)
	end
	local spell, _, displayName, icon, startTime, endTime, isTradeskill = UnitCastingInfo(unit)
	if isTradeskill then
		repeattimes = repeattimes or 1
		duration = (endTime - startTime) / 1000
		totaltime = duration * (repeattimes or 1)
		starttime = GetTime()
		casting = true
		QuartzPlayer.fadeOut = nil
		castname = spell
		bail = nil
		QuartzPlayer.endTime = nil
		
		castBar:SetStatusBarColor(unpack(Quartz.db.profile.castingcolor))
		castBar:SetMinMaxValues(0, totaltime)
		
		castBar:SetValue(0)
		castBarParent:Show()
		castBarParent:SetScript('OnUpdate', tradeskillOnUpdate)
		castBarParent:SetAlpha(QuartzPlayer.db.profile.alpha)
		
		local numleft = repeattimes - completedcasts
		if numleft <= 1 then
			castBarText:SetText(displayName)
		else
			castBarText:SetText(displayName..' ('..numleft..')')
		end
		castBarSpark:Show()
		castBarIcon:SetTexture(icon)
	else
		castBar:SetMinMaxValues(0, 1)
		return self.hooks[object].UNIT_SPELLCAST_START(object, unit)
	end
end
function QuartzTradeskill:UNIT_SPELLCAST_STOP(unit)
	if unit ~= 'player' then
		return
	end
	casting = false
end
function QuartzTradeskill:UNIT_SPELLCAST_SUCCEEDED(unit, spell)
	if unit ~= 'player' then
		return
	end
	if castname == spell then
		completedcasts = completedcasts + 1
	end
end
function QuartzTradeskill:UNIT_SPELLCAST_INTERRUPTED(unit)
	if unit ~= 'player' then
		return
	end
	bail = true
end
function QuartzTradeskill:DoTradeSkill(index, num)
	completedcasts = 0
	repeattimes = tonumber(num) or 1
	return self.hooks.DoTradeSkill(index, num)
end
function QuartzTradeskill:ApplySettings()
	castBarParent = QuartzPlayer.castBarParent
	castBar = QuartzPlayer.castBar
	castBarText = QuartzPlayer.castBarText
	castBarTimeText = QuartzPlayer.castBarTimeText
	castBarIcon = QuartzPlayer.castBarIcon
	castBarSpark = QuartzPlayer.castBarSpark
end
do
	local function set(field, value)
		db.profile[field] = value
		applySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	Quartz.options.args.Tradeskill = {
		type = 'group',
		name = L["Tradeskill Merge"],
		desc = L["Tradeskill Merge"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Tradeskill')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Tradeskill', v)
				end,
			},
		},
	}
end