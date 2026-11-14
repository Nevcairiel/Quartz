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
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = "Tradeskill"
local Tradeskill = Quartz3:NewModule(MODNAME, "AceHook-3.0")
local Player = Quartz3:GetModule("Player")

local WoWRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local WoWForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

local TimeFmt = Quartz3.Util.TimeFormat

local getOptions

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent

local repeattimes, castSpellID, duration, totaltime, starttime, casting, bail, delayed
local completedcasts = 0
local restartdelay = 1

local function tradeskillOnUpdate()
	local currentTime = GetTime()
	if casting then
		if delayed then
			-- the player bar handled the pushback of the current cast and put the bar on a timer for that
			-- cast alone, so take the bar back
			delayed = nil
			castBar:SetMinMaxValues(0, totaltime)
		end
		local elapsed = duration * completedcasts + currentTime - starttime
		castBar:SetValue(elapsed)

		local perc = (currentTime - starttime) / duration
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * castBar:GetWidth(), 0)

		if Player.db.profile.hidecasttime then
			castBarTimeText:SetFormattedText(TimeFmt(totaltime - elapsed))
		else
			castBarTimeText:SetFormattedText("%s / %s", format(TimeFmt(totaltime - elapsed)), format(TimeFmt(totaltime)))
		end
	else
		if (starttime + duration + restartdelay < currentTime) or (completedcasts >= repeattimes) or bail or completedcasts == 0 then
			Player.Bar.fadeOut = true
			Player.Bar.stopTime = currentTime
			castBar:SetValue(duration * repeattimes)
			castBarTimeText:SetText("")
			castBarSpark:Hide()
			castBarParent:SetScript("OnUpdate", Player.Bar.OnUpdate)
			castBar:SetMinMaxValues(0, 1)
		else
			local elapsed = duration * completedcasts
			castBar:SetValue(elapsed)

			castBarSpark:ClearAllPoints()
			castBarSpark:SetPoint("CENTER", castBar, "LEFT", castBar:GetWidth(), 0)

			if Player.db.profile.hidecasttime then
				castBarTimeText:SetFormattedText(TimeFmt(totaltime - elapsed))
			else
				castBarTimeText:SetFormattedText("%s / %s", format(TimeFmt(totaltime - elapsed)), format(TimeFmt(totaltime)))
			end
		end
	end
end

function Tradeskill:OnInitialize()
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Tradeskill Merge"])
end


function Tradeskill:OnEnable()
	self:RawHook(Player, "UNIT_SPELLCAST_START")
	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", nil, "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", nil, "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", nil, "player")
	self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", nil, "player")
	if WoWRetail or WoWForever then
		if ProfessionsFrame then
			self:SecureHook(ProfessionsFrame.CraftingPage, "CreateInternal", "DoTradeSkill")
		else
			self:RegisterEvent("ADDON_LOADED")
		end
	elseif C_TradeSkillUI and C_TradeSkillUI.CraftRecipe then
		self:SecureHook(C_TradeSkillUI, "CraftRecipe", "DoTradeSkillClassic")
	else
		self:SecureHook("DoTradeSkill", "DoTradeSkillClassic")
	end
end

function Tradeskill:OnDisable()
	self:UnregisterAllEvents()
end

function Tradeskill:ADDON_LOADED(event, addon)
	if addon == "Blizzard_Professions" then
		self:SecureHook(ProfessionsFrame.CraftingPage, "CreateInternal", "DoTradeSkill")
	end
end

function Tradeskill:UNIT_SPELLCAST_START(object, bar, unit, guid, spellID)
	if unit ~= "player" then
		return self.hooks[object].UNIT_SPELLCAST_START(object, bar, unit, guid, spellID)
	end
	local spell, displayName, icon, startTime, endTime, isTradeskill = UnitCastingInfo(unit)
	if isTradeskill then
		repeattimes = repeattimes or 1
		duration = (endTime - startTime) / 1000
		totaltime = duration * repeattimes
		starttime = GetTime()
		casting = true
		Player.Bar.fadeOut = nil
		castSpellID = spellID
		bail = nil
		delayed = nil

		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
		castBar:SetMinMaxValues(0, totaltime)

		castBar:SetValue(0)
		castBarParent:Show()
		castBarParent:SetScript("OnUpdate", tradeskillOnUpdate)
		castBarParent:SetAlpha(Player.db.profile.alpha)

		local numleft = repeattimes - completedcasts
		if numleft <= 1 then
			castBarText:SetText(displayName)
		else
			castBarText:SetFormattedText("%s (%s)", displayName, numleft)
		end
		castBarSpark:Show()

		if (icon == "Interface\\Icons\\Temp" or icon == 136235) and Quartz3.db.profile.hidesamwise then
			icon = 136243
		end
		castBarIcon:SetTexture(icon)

		Player:ClearStages(bar)
	else
		return self.hooks[object].UNIT_SPELLCAST_START(object, bar, unit, guid, spellID)
	end
end

function Tradeskill:UNIT_SPELLCAST_STOP(event, unit)
	casting = false
end

function Tradeskill:UNIT_SPELLCAST_SUCCEEDED(event, unit, guid, spell)
	if castSpellID == spell then
		completedcasts = completedcasts + 1
	end
end

function Tradeskill:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	bail = true
end

function Tradeskill:UNIT_SPELLCAST_DELAYED(event, unit)
	if not casting then return end

	local _, _, _, startTime, _, isTradeskill = UnitCastingInfo(unit)
	if isTradeskill and startTime then
		-- pushback moves the start of the cast
		starttime = startTime / 1000
		-- the bar is restored on the next update, after the player bar handled the event as well
		delayed = true
	end
end

function Tradeskill:DoTradeSkill(_, id, num)
	completedcasts = 0
	repeattimes = tonumber(num) or 1
end

function Tradeskill:DoTradeSkillClassic(id, num)
	self:DoTradeSkill(nil, id, num)
end

function Tradeskill:ApplySettings()
	castBarParent = Player.Bar
	castBar = Player.Bar.Bar
	castBarText = Player.Bar.Text
	castBarTimeText = Player.Bar.TimeText
	castBarIcon = Player.Bar.Icon
	castBarSpark = Player.Bar.Spark
end

do
	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Tradeskill Merge"],
				order = 600,
				args = {
					toggle = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enable"],
						get = function()
							return Quartz3:GetModuleEnabled(MODNAME)
						end,
						set = function(info, v)
							Quartz3:SetModuleEnabled(MODNAME, v)
						end,
					},
				},
			}
		end
		return options
	end
end
