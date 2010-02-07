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
local _G = getfenv(0)
local LibStub = _G.LibStub

local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = "Focus"
local Focus = Quartz3:NewModule(MODNAME, "AceEvent-3.0")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local GetTime = _G.GetTime
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local UnitExists = _G.UnitExists
local UnitIsEnemy = _G.UnitIsEnemy
local UnitIsFriend = _G.UnitIsFriend
local UnitIsUnit = _G.UnitIsUnit
local tonumber = _G.tonumber
local unpack = _G.unpack
local math_min = _G.math.min

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent
local startTime, endTime, delay, fadeOut, stopTime, casting, channeling, lastNotInterruptible

local noInterruptBackdrop = { insets = {} }
local interruptBackdrop = { insets = {} }
local noInterruptBorderColor = {}
local interruptBorderColor = {}
local interruptBorderAlpha, noInterruptBorderAlpha

local db, getOptions

local defaults = {
	profile = {
		--x =  -- applied automatically in :ApplySettings()
		y = 250,
		h = 18,
		w = 200,
		scale = 1,
		
		texture = "LiteStep",
		hideicon = false,
		
		alpha = 1,
		iconalpha = 0.9,
		iconposition = "left",
		icongap = 4,
		
		hidenametext = false,
		nametextposition = "left",
		timetextposition = "right", -- L["Left"], L["Center"], L["Cast Start Side"], L["Cast End Side"]
		font = "Friz Quadrata TT",
		fontsize = 14,
		hidetimetext = false,
		hidecasttime = false,
		timefontsize = 12,
		spellrank = false,
		spellrankstyle = "roman", --L["Full Text"], L["Number"], L["Roman Full Text"]
		
		border = "Blizzard Tooltip",
		nametextx = 3,
		nametexty = 0,
		timetextx = 3,
		timetexty = 0,
		
		showfriendly = true,
		showhostile = true,
		showtarget = true,
		
		noInterruptBorder = "Tooltip enlarged",
		noInterruptBorderColor = {0.71, 0.73, 0.71}, -- Default color chosen by playing around with settings, rounded to 2 significant digits
		noInterruptBorderAlpha = 1,
	}
}

local function OnUpdate()
	local currentTime = GetTime()
	if casting then
		if currentTime > endTime then
			casting = nil
			fadeOut = true
			stopTime = currentTime
		end
		local showTime = math_min(currentTime, endTime)
		
		local perc = (showTime-startTime) / (endTime - startTime)
		castBar:SetValue(perc)
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * db.w, 0)
		
		if delay and delay ~= 0 then
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %.1f", delay, endTime - showTime)
			else
				castBarTimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %.1f / %.1f", delay, endTime - showTime, endTime - startTime)
			end
		else
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("%.1f", endTime - showTime)
			else
				castBarTimeText:SetFormattedText("%.1f / %.1f", endTime - showTime, endTime - startTime)
			end
		end
	elseif channeling then
		if currentTime > endTime then
			channeling = nil
			fadeOut = true
			stopTime = currentTime
		end
		local remainingTime = endTime - currentTime
		local perc = remainingTime / (endTime - startTime)
		castBar:SetValue(perc)
		castBarTimeText:SetFormattedText("%.1f", remainingTime)
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint("CENTER", castBar, "LEFT", perc * db.w, 0)
		if delay and delay ~= 0 then
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("|cffFF0000-%.1f|cffffffff %.1f", delay, remainingTime)
			else
				castBarTimeText:SetFormattedText("|cffFF0000-%.1f|cffffffff %.1f / %.1f", delay, remainingTime, endTime - startTime)
			end
		else
			if db.hidecasttime then
				castBarTimeText:SetFormattedText("%.1f", remainingTime)
			else
				castBarTimeText:SetFormattedText("%.1f / %.1f", remainingTime, endTime - startTime)
			end				
		end
	elseif fadeOut then
		castBarSpark:Hide()
		local alpha
		if stopTime then
			alpha = stopTime - currentTime + 1
		else
			alpha = 0
		end
		if alpha >= 1 then
			alpha = 1
		end
		if alpha <= 0 then
			stopTime = nil
			castBarParent:Hide()
		else
			castBarParent:SetAlpha(alpha*db.alpha)
		end
	else
		castBarParent:Hide()
	end
end

local function OnHide()
	castBarParent:SetScript("OnUpdate", nil)
end
local function OnShow()
	castBarParent:SetScript("OnUpdate", OnUpdate)
end

local setnametext
do
	local numerals = { -- 25"s enough for now, I think?
		"I", "II", "III", "IV", "V",
		"VI", "VII", "VIII", "IX", "X",
		"XI", "XII", "XIII", "XIV", "XV",
		"XVI", "XVII", "XVIII", "XIX", "XX",
		"XXI", "XXII", "XXIII", "XXIV", "XXV",
	}
	function setnametext(name, rank)
		local mask, arg = nil, nil
		if db.spellrank and rank then
			local num = tonumber(rank:match(L["Rank (%d+)"]))
			if num and num > 0 then
				local rankstyle = db.spellrankstyle
				if rankstyle == "number" then
					mask, arg = "%s %d", num
				elseif rankstyle == "full" then
					mask, arg = "%s (%s)", rank
				elseif rankstyle == "roman" then
					mask, arg = "%s %s", numerals[num]
				else -- full roman
					mask, arg = "%s (%s)", L["Rank %s"]:format(numerals[num])
				end
			end
		end
		
		if mask then
			castBarText:SetFormattedText(mask, name, arg)
		else
			castBarText:SetText(name)
		end
	end
end

local function setCastNotInterruptable(notInterruptible)
	if notInterruptible then
		castBarParent:SetBackdrop(noInterruptBackdrop)
		castBarParent:SetBackdropBorderColor(noInterruptBorderColor.r, noInterruptBorderColor.g, noInterruptBorderColor.b, noInterruptBorderAlpha)
	else
		castBarParent:SetBackdrop(interruptBackdrop)
		castBarParent:SetBackdropBorderColor(interruptBorderColor.r, interruptBorderColor.g, interruptBorderColor.b, interruptBorderAlpha)
	end
	lastNotInterruptible = notInterruptible
	local r,g,b = unpack(Quartz3.db.profile.backgroundcolor)
	castBarParent:SetBackdropColor(r, g, b, Quartz3.db.profile.backgroundalpha)
end

function Focus:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Focus"])

end

function Focus:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	-- maybe only register PLAYER_TARGET_CHANGED if the db.showtarget option is false and also do register/unregister in the set() func?
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			castBar:SetStatusBarTexture(media:Fetch("statusbar", override))
		end
	end)
	if not castBarParent then
		castBarParent = CreateFrame("Frame", "Quartz3FocusBar", UIParent)
		castBarParent:SetFrameStrata("MEDIUM")
		castBarParent:SetScript("OnShow", OnShow)
		castBarParent:SetScript("OnHide", OnHide)
		castBarParent:SetMovable(true)
		castBarParent:RegisterForDrag("LeftButton")
		castBarParent:SetClampedToScreen(true)
		
		castBar = CreateFrame("StatusBar", nil, castBarParent)
		castBarText = castBar:CreateFontString(nil, "OVERLAY")
		castBarTimeText = castBar:CreateFontString(nil, "OVERLAY")
		castBarIcon = castBar:CreateTexture(nil, "DIALOG")
		castBarSpark = castBar:CreateTexture(nil, "OVERLAY")
		
		castBarParent:Hide()
	end
	Focus.Bar = castBarParent
	lastNotInterruptible = false
	Focus:ApplySettings()
end

function Focus:OnDisable()
	castBarParent:Hide()
end
function Focus:UNIT_SPELLCAST_START(event, unit)
	if unit ~= "focus" then
		return
	end
	if not db.showfriendly then
		if UnitIsFriend("player", "focus") then
			return
		end
	end
	if not db.showhostile then
		if UnitIsEnemy("player", "focus") then
			return
		end
	end
	if not db.showtarget then
		if UnitIsUnit("target", "focus") then
			return
		end
	end
	local spell, rank, displayName, icon, isTradeSkill, castID, notInterruptible
	spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	delay = 0
	casting = true
	channeling = nil
	fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
	
	castBar:SetValue(0)
	castBarParent:Show()
	castBarParent:SetAlpha(db.alpha)
	
	setnametext(displayName, rank)
	
	castBarSpark:Show()
	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
		icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.timetextposition
	if position == "caststart" then
		castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	elseif position == "castend" then
		castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	end
	
	setCastNotInterruptable(notInterruptible)
end

function Focus:UNIT_SPELLCAST_CHANNEL_START(event, unit)
	if unit ~= "focus" then
		return
	end
	if not db.showfriendly then
		if UnitIsFriend("player", "focus") then
			return
		end
	end
	if not db.showhostile then
		if UnitIsEnemy("player", "focus") then
			return
		end
	end
	if not db.showtarget then
		if UnitIsUnit("target", "focus") then
			return
		end
	end
	local spell, rank, displayName, icon, isTradeSkill, notInterruptible
	spell, rank, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	delay = 0
	casting = nil
	channeling = true
	fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.channelingcolor))
	
	castBar:SetValue(1)
	castBarParent:Show()
	castBarParent:SetAlpha(db.alpha)

	setnametext(spell, rank)
	
	castBarSpark:Show()
	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
		icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.timetextposition
	if position == "caststart" then
		castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	elseif position == "castend" then
		castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	end

	setCastNotInterruptable(notInterruptible)
end

function Focus:UNIT_SPELLCAST_STOP(event, unit)
	if unit ~= "focus" then
		return
	end
	if casting then
		casting = nil
		fadeOut = true
		stopTime = GetTime()
		
		castBar:SetValue(1.0)
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function Focus:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
	if unit ~= "focus" then
		return
	end
	if channeling then
		channeling = nil
		fadeOut = true
		stopTime = GetTime()
		
		castBar:SetValue(0)
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function Focus:UNIT_SPELLCAST_FAILED(event, unit)
	if unit ~= "focus" or channeling then
		return
	end
	casting = nil
	channeling = nil
	fadeOut = true
	if not stopTime then
		stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function Focus:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= "focus" then
		return
	end
	casting = nil
	channeling = nil
	fadeOut = true
	if not stopTime then
		stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function Focus:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= "focus" then
		return
	end
	if not db.showfriendly then
		if UnitIsFriend("player", "focus") then
			return
		end
	end
	if not db.showhostile then
		if UnitIsEnemy("player", "focus") then
			return
		end
	end
	if not db.showtarget then
		if UnitIsUnit("target", "focus") then
			return
		end
	end
	local oldStart = startTime
	local spell, rank, displayName, icon
	spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000

	delay = (delay or 0) + (startTime - (oldStart or startTime))
end

function Focus:UNIT_SPELLCAST_CHANNEL_UPDATE(event, unit)
	if unit ~= "focus" then
		return
	end
	local oldStart = startTime
	local spell, rank, displayName, icon
	spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	
	delay = (delay or 0) + ((oldStart or startTime) - startTime)
end

function Focus:PLAYER_FOCUS_CHANGED()
	if not UnitExists("focus") then
		castBarParent:Hide()
		return
	end
	if not db.showfriendly then
		if UnitIsFriend("player", "focus") then
			castBarParent:Hide()
			return
		end
	end
	if not db.showhostile then
		if UnitIsEnemy("player", "focus") then
			castBarParent:Hide()
			return
		end
	end
	if not db.showtarget then
		if UnitIsUnit("target", "focus") then
			castBarParent:Hide()
			return
		end
	end
	local spell, rank, displayName, icon, isTradeSkill, castID, notInterruptible
	spell, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("focus")
	if spell then
		startTime = startTime / 1000
		endTime = endTime / 1000
		delay = 0
		casting = true
		channeling = nil
		fadeOut = nil
		
		castBar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
		
		castBar:SetValue(0)
		castBarParent:Show()
		castBarParent:SetAlpha(db.alpha)
		
		setnametext(displayName, rank)
		
		castBarSpark:Show()
		if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
			icon = nil
		end
		castBarIcon:SetTexture(icon)
		
		local position = db.timetextposition
		if position == "caststart" then
			castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
			castBarTimeText:SetJustifyH("LEFT")
		elseif position == "castend" then
			castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
			castBarTimeText:SetJustifyH("RIGHT")
		end
		
		setCastNotInterruptable(notInterruptible)
	else
		spell, rank, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo("focus")
		if spell then
			startTime = startTime / 1000
			endTime = endTime / 1000
			delay = 0
			casting = nil
			channeling = true
			fadeOut = nil
			
			castBar:SetStatusBarColor(unpack(Quartz3.db.profile.channelingcolor))
			
			castBar:SetValue(1)
			castBarParent:Show()
			castBarParent:SetAlpha(db.alpha)
			
			setnametext(spell, rank)
			if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
				icon = nil
			end
			castBarIcon:SetTexture(icon)
			
			local position = db.timetextposition
			if position == "caststart" then
				castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("RIGHT")
			elseif position == "castend" then
				castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("LEFT")
			end
			
			setCastNotInterruptable(notInterruptible)
		else
			castBarParent:Hide()
		end
	end
end

function Focus:UNIT_SPELLCAST_INTERRUPTIBLE(event, unit)
	if unit ~= "focus" then
		return
	end
	setCastNotInterruptable(false)
end

function Focus:UNIT_SPELLCAST_NOT_INTERRUPTIBLE(event, unit)
	if unit ~= "focus" then
		return
	end
	setCastNotInterruptable(true)
end

do
	function Focus:ApplySettings()
		db = self.db.profile
		if not castBarParent or not self:IsEnabled() then return end

		castBarParent:ClearAllPoints()
		if not db.x then
			db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale)) / db.scale - 5
		end
		castBarParent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
		castBarParent:SetWidth(db.w+10)
		castBarParent:SetHeight(db.h+10)
		castBarParent:SetAlpha(db.alpha)
		castBarParent:SetScale(db.scale)
		
		interruptBackdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
		interruptBackdrop.tile = true
		interruptBackdrop.tileSize = 16
		interruptBackdrop.edgeFile = media:Fetch('border', db.border)
		interruptBackdrop.edgeSize = 16
		interruptBackdrop.insets.left = 4
		interruptBackdrop.insets.right = 4
		interruptBackdrop.insets.top = 4
		interruptBackdrop.insets.bottom = 4

		noInterruptBackdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
		noInterruptBackdrop.tile = true
		noInterruptBackdrop.tileSize = 16
		noInterruptBackdrop.edgeFile = media:Fetch('border', db.noInterruptBorder)
		noInterruptBackdrop.edgeSize = 16
		noInterruptBackdrop.insets.left = 4
		noInterruptBackdrop.insets.right = 4
		noInterruptBackdrop.insets.top = 4
		noInterruptBackdrop.insets.bottom = 4
		
		local r,g,b = unpack(Quartz3.db.profile.bordercolor)
		interruptBorderColor.r = r
		interruptBorderColor.g = g
		interruptBorderColor.b = b
		interruptBorderAlpha = Quartz3.db.profile.borderalpha
		
		r,g,b = unpack(db.noInterruptBorderColor)
		noInterruptBorderColor.r = r
		noInterruptBorderColor.g = g
		noInterruptBorderColor.b = b
		noInterruptBorderAlpha = db.noInterruptBorderAlpha
		if lastNotInterruptible then
			castBarParent:SetBackdrop(noInterruptBackdrop)
				castBarParent:SetBackdropBorderColor(noInterruptBorderColor.r, noInterruptBorderColor.g, noInterruptBorderColor.b, noInterruptBorderAlpha)
		else
			castBarParent:SetBackdrop(interruptBackdrop)
			castBarParent:SetBackdropBorderColor(interruptBorderColor.r, interruptBorderColor.g, interruptBorderColor.b, interruptBorderAlpha)
		end
		r,g,b = unpack(Quartz3.db.profile.backgroundcolor)
		castBarParent:SetBackdropColor(r,g,b, Quartz3.db.profile.backgroundalpha)
		
		castBar:ClearAllPoints()
		castBar:SetPoint("CENTER",castBarParent,"CENTER")
		castBar:SetWidth(db.w)
		castBar:SetHeight(db.h)
		castBar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
		castBar:SetMinMaxValues(0,1)
		
		if db.hidetimetext then
			castBarTimeText:Hide()
		else
			castBarTimeText:Show()
			castBarTimeText:ClearAllPoints()
			castBarTimeText:SetWidth(db.w)
			local position = db.timetextposition
			if position == "left" then
				castBarTimeText:SetPoint("LEFT", castBar, "LEFT", db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("LEFT")
			elseif position =="center" then
				castBarTimeText:SetPoint("CENTER", castBar, "CENTER", db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("CENTER")
			elseif position =="right" then
				castBarTimeText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.timetextx, db.timetexty)
				castBarTimeText:SetJustifyH("RIGHT")
			end -- L["Cast Start Side"], L["Cast End Side"] --handled at runtime
		end
		castBarTimeText:SetFont(media:Fetch("font", db.font), db.timefontsize)
		castBarTimeText:SetShadowColor( 0, 0, 0, 1)
		castBarTimeText:SetShadowOffset( 0.8, -0.8 )
		castBarTimeText:SetTextColor(unpack(Quartz3.db.profile.timetextcolor))
		castBarTimeText:SetNonSpaceWrap(false)
		castBarTimeText:SetHeight(db.h)
		
		local temptext = castBarTimeText:GetText()
		if db.hidecasttime then
			castBarTimeText:SetText("10.0")
		else
			castBarTimeText:SetText("10.0 / 10.0")
		end
		local normaltimewidth = castBarTimeText:GetStringWidth()
		castBarTimeText:SetText(temptext)
		
		if db.hidenametext then
			castBarText:Hide()
		else
			castBarText:Show()
			castBarText:ClearAllPoints()
			local position = db.nametextposition
			if position == "left" then
				castBarText:SetPoint("LEFT", castBar, "LEFT", db.nametextx, db.nametexty)
				castBarText:SetJustifyH("LEFT")
				if db.hidetimetext or db.timetextposition ~= "right" then
					castBarText:SetWidth(db.w)
				else
					castBarText:SetWidth(db.w - normaltimewidth - 5)
				end
			elseif position == "center" then
				castBarText:SetPoint("CENTER", castBar, "CENTER", db.nametextx, db.nametexty)
				castBarText:SetJustifyH("CENTER")
			else -- L["Right"]
				castBarText:SetPoint("RIGHT", castBar, "RIGHT", -1 * db.nametextx, db.nametexty)
				castBarText:SetJustifyH("RIGHT")
				if db.hidetimetext or db.timetextposition ~= "left" then
					castBarText:SetWidth(db.w)
				else
					castBarText:SetWidth(db.w - normaltimewidth - 5)
				end
			end
		end
		castBarText:SetFont(media:Fetch("font", db.font), db.fontsize)
		castBarText:SetShadowColor( 0, 0, 0, 1)
		castBarText:SetShadowOffset( 0.8, -0.8 )
		castBarText:SetTextColor(unpack(Quartz3.db.profile.spelltextcolor))
		castBarText:SetNonSpaceWrap(false)
		castBarText:SetHeight(db.h)
		
		if db.hideicon then
			castBarIcon:Hide()
		else
			castBarIcon:Show()
			castBarIcon:ClearAllPoints()
			if db.iconposition == "left" then
				castBarIcon:SetPoint("RIGHT", castBar, "LEFT", -1 * db.icongap, 0)
			else --L["Right"]
				castBarIcon:SetPoint("LEFT", castBar, "RIGHT", db.icongap, 0)
			end
			castBarIcon:SetWidth(db.h)
			castBarIcon:SetHeight(db.h)
			castBarIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			castBarIcon:SetAlpha(db.iconalpha)
		end
		
		castBarSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		castBarSpark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		castBarSpark:SetBlendMode("ADD")
		castBarSpark:SetWidth(20)
		castBarSpark:SetHeight(db.h*2.2)
	end
end
do
	local locked = true
	local function dragstart()
		castBarParent:StartMoving()
	end
	local function dragstop()
		db.x = castBarParent:GetLeft()
		db.y = castBarParent:GetBottom()
		castBarParent:StopMovingOrSizing()
	end
	local function nothing()
		castBarParent:SetAlpha(db.alpha)
	end
	local function hideiconoptions()
		return db.hideicon
	end
	local function hidetimetextoptions()
		return db.hidetimetext
	end
	local function hidenametextoptions()
		return db.hidenametext
	end

	local function setOpt(info, value)
		db[info[#info]] = value
		Focus:ApplySettings()
	end

	local function getOpt(info)
		return db[info[#info]]
	end

	local function setColor(info, ...)
		setOpt(info, {...})
	end

	local function getColor(info)
		return unpack(getOpt(info))
	end

	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Focus"],
				order = 600,
				get = getOpt,
				set = setOpt,
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
						order = 99,
					},
					lock = {
						type = "toggle",
						name = L["Lock"],
						desc = L["Toggle Cast Bar lock"],
						get = function(info)
							return locked
						end,
						set = function(info, v)
							if v then
								castBarParent.Hide = nil
								castBarParent:EnableMouse(false)
								castBarParent:SetScript("OnDragStart", nil)
								castBarParent:SetScript("OnDragStop", nil)
								if not (channeling or casting) then
									castBarParent:Hide()
								end
							else
								castBarParent:Show()
								castBarParent:EnableMouse(true)
								castBarParent:SetScript("OnDragStart", dragstart)
								castBarParent:SetScript("OnDragStop", dragstop) 
								castBarParent:SetAlpha(1)
								castBarParent.Hide = nothing
								castBarIcon:SetTexture("Interface\\Icons\\Temp")
							end
							locked = v
						end,
						order = 100,
					},
					showfriendly = {
						type = "toggle",
						name = L["Show for Friends"],
						desc = L["Show this castbar for friendly units"],
						order = 101,
					},
					showhostile = {
						type = "toggle",
						name = L["Show for Enemies"],
						desc = L["Show this castbar for hostile units"],
						order = 101,
					},
					showtarget = {
						type = "toggle",
						name = L["Show if Target"],
						desc = L["Show this castbar if focus is also target"],
						order = 101,
					},
					nlshow = {
						type = "description",
						name = "",
						order = 199,
					},
					h = {
						type = "range",
						name = L["Height"],
						desc = L["Height"],
						min = 10, max = 50, step = 1,
						order = 200,
					},
					w = {
						type = "range",
						name = L["Width"],
						desc = L["Width"],
						min = 50, max = 1500, bigStep = 5,
						order = 200,
					},
					x = {
						type = "range",
						name = L["X"],
						desc = L["Set an exact X value for this bar's position."],
						min = -2560, max = 2560, bigStep = 1,
						order = 200,
					},
					y = {
						type = "range",
						name = L["Y"],
						desc = L["Set an exact Y value for this bar's position."],
						min = -1600, max = 1600, bigStep = 1,
						order = 200,
					},
					scale = {
						type = "range",
						name = L["Scale"],
						desc = L["Scale"],
						min = 0.2, max = 1, bigStep = 0.025,
						order = 201,
					},
					alpha = {
						type = "range",
						name = L["Alpha"],
						desc = L["Alpha"],
						isPercent = true,
						min = 0.1, max = 1, bigStep = 0.025,
						order = 202,
					},
					icon = {
						type = "header",
						name = L["Icon"],
						order = 300,
					},
					hideicon = {
						type = "toggle",
						name = L["Hide Icon"],
						desc = L["Hide Spell Cast Icon"],
						order = 301,
					},
					iconposition = {
						type = "select",
						name = L["Icon Position"],
						desc = L["Set where the Spell Cast icon appears"],
						disabled = hideiconoptions,
						values = {["left"] = L["Left"], ["right"] = L["Right"]},
						order = 301,
					},
					iconalpha = {
						type = "range",
						name = L["Icon Alpha"],
						desc = L["Set the Spell Cast icon alpha"],
						isPercent = true,
						min = 0.1, max = 1, bigStep = 0.025,
						order = 302,
						disabled = hideiconoptions,
					},
					icongap = {
						type = "range",
						name = L["Icon Gap"],
						desc = L["Space between the cast bar and the icon."],
						min = -35, max = 35, bigStep = 1,
						order = 302,
						disabled = hideiconoptions,
					},
					fonthead = {
						type = "header",
						name = L["Font and Text"],
						order = 398,
					},
					font = {
						type = "select",
						dialogControl = "LSM30_Font",
						name = L["Font"],
						desc = L["Set the font used in the Name and Time texts"],
						values = lsmlist.font,
						order = 399,
					},
					nlfont = {
						type = "description",
						name = "",
						order = 400,
					},
					hidenametext = {
						type = "toggle",
						name = L["Hide Spell Name"],
						desc = L["Disable the text that displays the spell name/rank"],
						order = 401,
						width = "full",
					},
					nametextposition = {
						type = "select",
						name = L["Spell Name Position"],
						desc = L["Set the alignment of the spell name text"],
						values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"]},
						disabled = hidenametextoptions,
						order = 403,
					},
					fontsize = {
						type = "range",
						name = L["Spell Name Font Size"],
						desc = L["Set the size of the spell name text"],
						min = 7, max = 20, step = 1,
						order = 404,
						disabled = hidenametextoptions,
					},
					nametextx = {
						type = "range",
						name = L["Spell Name X Offset"],
						desc = L["Adjust the X position of the spell name text"],
						min = -35, max = 35, step = 1,
						disabled = hidenametextoptions,
						order = 405,
					},
					nametexty = {
						type = "range",
						name = L["Spell Name Y Offset"],
						desc = L["Adjust the Y position of the name text"],
						min = -35, max = 35, step = 1,
						disabled = hidenametextoptions,
						order = 406,
					},
					spellrank = {
						type = "toggle",
						name = L["Spell Rank"],
						desc = L["Display the rank of spellcasts alongside their name"],
						disabled = hidenametextoptions,
						order = 407,
					},
					spellrankstyle = {
						type = "select",
						name = L["Spell Rank Style"],
						desc = L["Set the display style of the spell rank"],
						disabled = function()
							return db.hidenametext or not db.spellrank
						end,
						values = {["number"] = L["Number"], ["roman"] = L["Roman"], ["full"] = L["Full Text"], ["romanfull"] = L["Roman Full Text"]},
						order = 408,
					},
					hidetimetext = {
						type = "toggle",
						name = L["Hide Time Text"],
						desc = L["Disable the text that displays the time remaining on your cast"],
						order = 411,
					},
					hidecasttime = {
						type = "toggle",
						name = L["Hide Cast Time"],
						desc = L["Disable the text that displays the total cast time"],
						disabled = hidetimetextoptions,
						order = 412,
					},
					timefontsize = {
						type = "range",
						name = L["Time Font Size"],
						desc = L["Set the size of the time text"],
						min = 7, max = 20, step = 1,
						order = 414,
						disabled = hidetimetextoptions,
					},
					timetextx = {
						type = "range",
						name = L["Time Text X Offset"],
						desc = L["Adjust the X position of the time text"],
						min = -35, max = 35, step = 1,
						disabled = hidetimetextoptions,
						order = 416,
					},
					timetexty = {
						type = "range",
						name = L["Time Text Y Offset"],
						desc = L["Adjust the Y position of the time text"],
						min = -35, max = 35, step = 1,
						disabled = hidetimetextoptions,
						order = 417,
					},
					timetextposition = {
						type = "select",
						name = L["Time Text Position"],
						desc = L["Set the alignment of the time text"],
						values = {["left"] = L["Left"], ["right"] = L["Right"], ["center"] = L["Center"], ["caststart"] = L["Cast Start Side"], ["castend"] = L["Cast End Side"]},
						disabled = hidetimetextoptions,
						order = 418,
					},
					textureheader = {
						type = "header",
						name = L["Texture and Border"],
						order = 440,
					},
					texture = {
						type = "select",
						dialogControl = "LSM30_Statusbar",
						name = L["Texture"],
						desc = L["Set the Cast Bar Texture"],
						values = lsmlist.statusbar,
						order = 451,
					},
					border = {
						type = "select",
						dialogControl = "LSM30_Border",
						name = L["Border"],
						desc = L["Set the border style"],
						values = lsmlist.border,
						order = 452,
					},
					noInterruptGroup = {
						name = L["No interrupt cast bars"],
						dialogInline = true,
						type = "group",
						order = 455,
						args = {
							noInterruptBorder = {
								type = "select",
								name = L["Border"],
								desc = L["Set the border style for no interrupt casting bars"],
								dialogControl = "LSM30_Border",
								values = lsmlist.border,
								order = 1,
							},
							noInterruptBorderColor = {
								type = "color",
								name = L["Border Color"],
								desc = L["Set the color of the no interrupt casting bar border"],
								get = getColor,
								set = setColor,
								order = 2,
							},
							noInterruptBorderAlpha = {
								type = "range",
								name = L["Border Alpha"],
								desc = L["Set the alpha of the no interrupt casting bar border"],
								isPercent = true,
								min = 0, max = 1, bigStep = 0.025,
								order = 3,
							},
						},
					},
					toolheader = {
						type = "header",
						name = L["Tools"],
						order = 500,
					},
					snaptocenter = {
						type = "select",
						name = L["Snap to Center"],
						desc = L["Move the CastBar to center of the screen along the specified axis"],
						get = false,
						set = function(info, v)
							local scale = db.scale
							if v == "horizontal" then
								db.x = (UIParent:GetWidth() / 2 - (db.w * scale) / 2) / scale
							else -- L["Vertical"]
								db.y = (UIParent:GetHeight() / 2 - (db.h * scale) / 2) / scale
							end
							Focus:ApplySettings()
						end,
						values = {["horizontal"] = L["Horizontal"], ["vertical"] = L["Vertical"]},
						order = 503,
					},
					copysettings = {
						type = "select",
						name = L["Copy Settings From"],
						desc = L["Select a bar from which to copy settings"],
						get = false,
						set = function(info, v)
								local from = Quartz3:GetModule(v)
								Quartz3:CopySettings(from.db.profile, Focus.db.profile)
								Focus:ApplySettings()
						end,
						values = {["Target"] = L["Target"], ["Player"] = L["Player"], ["Pet"] = L["Pet"]},
						order = 504
					},
				},
			}
		end
		return options
	end
end
