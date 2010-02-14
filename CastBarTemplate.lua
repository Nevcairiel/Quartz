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

local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local CastBarTemplate = CreateFrame("Frame")
local CastBarTemplate_MT = {__index = CastBarTemplate}

local TimeFmt, RomanFmt = Quartz3.Util.TimeFormat, Quartz3.Util.ConvertToRomanNumeral

local playerName = UnitName("player")

local function call(obj, method, ...)
	if type(obj.parent[method]) == "function" then
		obj.parent[method](obj.parent, obj, ...)
	end
end

----------------------------
-- Frame Scripts

-- OnShow and OnHide are not used by the template
-- But forward the call to the embeding module, they might use it.
local function OnShow(self)
	call(self, "OnShow")
end

local function OnHide(self)
	call(self, "OnHide")
end

-- OnUpdate handles the bar movement and the text updates
local function OnUpdate(self)
	local currentTime = GetTime()
	local startTime, endTime, delay = self.startTime, self.endTime, self.delay
	local db = self.config
	if self.channeling or self.casting then
		local perc, remainingTime, delayFormat, delayFormatTime
		if self.casting then
			local showTime = min(currentTime, endTime)
			remainingTime = endTime - showTime
			perc = (showTime - startTime) / (endTime - startTime)

			delayFormat, delayFormatTime = "|cffff0000+%.1f|cffffffff %s", "|cffff0000+%.1f|cffffffff %s / %s"
		elseif self.channeling then
			remainingTime = endTime - currentTime
			perc = remainingTime / (endTime - startTime)
			
			delayFormat, delayFormatTime = "|cffff0000-%.1f|cffffffff %s", "|cffff0000-%.1f|cffffffff %s / %s"
		end

		self.Bar:SetValue(perc)
		self.Spark:ClearAllPoints()
		self.Spark:SetPoint("CENTER", self.Bar, "LEFT", perc * db.w, 0)

		if delay and delay ~= 0 then
			if db.hidecasttime then
				self.TimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %s", delay, format(TimeFmt(remainingTime)))
			else
				self.TimeText:SetFormattedText("|cffff0000+%.1f|cffffffff %s / %s", delay, format(TimeFmt(remainingTime)), format(TimeFmt(endTime - startTime, true)))
			end
		else
			if db.hidecasttime then
				self.TimeText:SetFormattedText(TimeFmt(remainingTime))
			else
				self.TimeText:SetFormattedText("%s / %s", format(TimeFmt(remainingTime)), format(TimeFmt(endTime - startTime, true)))
			end
		end

		if currentTime > endTime then
			self.casting, self.channeling = nil, nil
			self.fadeOut = true
			self.stopTime = currentTime
		end
	elseif self.fadeOut then
		self.Spark:Hide()
		local alpha
		local stopTime = self.stopTime
		if stopTime then
			alpha = stopTime - currentTime + 1
		else
			alpha = 0
		end
		if alpha >= 1 then
			alpha = 1
		end
		if alpha <= 0 then
			self.stopTime = nil
			self:Hide()
		else
			self:SetAlpha(alpha*db.alpha)
		end
	else
		self:Hide()
	end
end

local function OnEvent(self, event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

----------------------------
-- Template Methods

local function SetNameText(self, name, rank)
	local mask, arg = nil, nil
	if self.config.spellrank and rank then
		local num = tonumber(rank:match(L["Rank (%d+)"]))
		mask, arg = RomanFmt(rank, self.config.rankstyle)
	end

	if self.config.targetname and self.targetName and self.targetName ~= "" then
		if mask then
			mask = mask .. " -> " .. self.targetName
		else
			name = name .. " -> " .. self.targetName
		end
	end
	if mask then
		self.Text:SetFormattedText(mask, name, arg)
	else
		self.Text:SetText(name)
	end
end

----------------------------
-- Event Handlers

function CastBarTemplate:UNIT_SPELLCAST_SENT(event, unit, spell, rank, target)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	if target then
		self.targetName = target
	else
		-- auto selfcast? is this needed, even?
		self.targetName = playerName
	end

	call(self, "UNIT_SPELLCAST_SENT", unit, spell, rank, target)
end

function CastBarTemplate:UNIT_SPELLCAST_START(event, unit)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	local db = self.config
	if event == "UNIT_SPELLCAST_START" then
		self.casting, self.channeling = true, nil
	else
		self.casting, self.channeling = nil, true
	end

	local spell, rank, displayName, icon, startTime, endTime
	if self.casting then
		spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	else -- self.channeling
		spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	end

	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	self.delay = 0
	self.fadeOut = nil

	self.Bar:SetStatusBarColor(unpack(self.casting and Quartz3.db.profile.castingcolor or Quartz3.db.profile.channelingcolor))

	self.Bar:SetValue(self.casting and 0 or 1)
	self:Show()
	self:SetAlpha(db.alpha)

	SetNameText(self, displayName, rank)

	self.Spark:Show()

	if icon == "Interface\\Icons\\Temp" and Quartz3.db.profile.hidesamwise then
		icon = nil
	end
	self.Icon:SetTexture(icon)

	local position = db.timetextposition
	if position == "caststart" or position == "castend" then
		if (position == "caststart" and self.casting) or (position == "castend" and self.channeling) then
			self.TimeText:SetPoint("LEFT", self.Bar, "LEFT", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("LEFT")
		else
			self.TimeText:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("RIGHT")
		end
	end

	call(self, "UNIT_SPELLCAST_START", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_START = CastBarTemplate.UNIT_SPELLCAST_START

function CastBarTemplate:UNIT_SPELLCAST_STOP(event, unit)
	if not (self.channeling or self.casting) or (unit ~= self.unit and not (self.unit == "player" and unit == "vehicle")) then
		return
	end

	self.Bar:SetValue(self.casting and 1.0 or 0)
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.completecolor))

	self.casting, self.channeling = nil, nil
	self.fadeOut = true
	self.stopTime = GetTime()

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_STOP", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_STOP = CastBarTemplate.UNIT_SPELLCAST_STOP

function CastBarTemplate:UNIT_SPELLCAST_FAILED(event, unit)
	if self.channeling or self.casting or (unit ~= self.unit and not (self.unit == "player" and unit == "vehicle")) then
		return
	end
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	self.Bar:SetValue(1.0)
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_FAILED", unit)
end

function CastBarTemplate:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	self.casting, self.channeling = nil, nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	self.Bar:SetValue(1.0)
	self.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.failcolor))

	self.TimeText:SetText("")

	call(self, "UNIT_SPELLCAST_INTERRUPTED", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_INTERRUPTED = CastBarTemplate.UNIT_SPELLCAST_INTERRUPTED

function CastBarTemplate:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= self.unit and not (self.unit == "player" and unit == "vehicle") then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime
	if self.casting then
		spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	else
		spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	end

	if not startTime then
		return self:Hide()
	end

	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime

	if self.casting then
		self.delay = (self.delay or 0) + (startTime - (oldStart or startTime))
	else
		self.delay = (self.delay or 0) + ((oldStart or startTime) - startTime)
	end

	call(self, "UNIT_SPELLCAST_DELAYED", unit)
end
CastBarTemplate.UNIT_SPELLCAST_CHANNEL_UPDATE = CastBarTemplate.UNIT_SPELLCAST_DELAYED


function CastBarTemplate:ApplySettings(config)
	if config then
		self.config = config
	end
	local db = self.config

	self:ClearAllPoints()
	if not db.x then
		db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale) / 2) / db.scale
	end
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
	self:SetWidth(db.w + 10)
	self:SetHeight(db.h + 10)
	self:SetAlpha(db.alpha)
	self:SetScale(db.scale)

	self.backdrop.edgeFile = media:Fetch("border", db.border)
	self:SetBackdrop(self.backdrop)

	local r,g,b = unpack(Quartz3.db.profile.backgroundcolor)
	self:SetBackdropColor(r,g,b, Quartz3.db.profile.backgroundalpha)

	r,g,b = unpack(Quartz3.db.profile.bordercolor)
	self:SetBackdropBorderColor(r, g, b, Quartz3.db.profile.borderalpha)

	self.Bar:ClearAllPoints()
	self.Bar:SetPoint("CENTER",self,"CENTER")
	self.Bar:SetWidth(db.w)
	self.Bar:SetHeight(db.h)
	self.Bar:SetStatusBarTexture(media:Fetch("statusbar", db.texture))
	self.Bar:SetMinMaxValues(0, 1)

	if db.hidetimetext then
		self.TimeText:Hide()
	else
		self.TimeText:Show()
		self.TimeText:ClearAllPoints()
		self.TimeText:SetWidth(db.w)
		local position = db.timetextposition
		if position == "left" then
			self.TimeText:SetPoint("LEFT", self.Bar, "LEFT", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("LEFT")
		elseif position == "center" then
			self.TimeText:SetPoint("CENTER", self.Bar, "CENTER", db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("CENTER")
		elseif position == "right" then
			self.TimeText:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.timetextx, db.timetexty)
			self.TimeText:SetJustifyH("RIGHT")
		end -- L["Cast Start Side"], L["Cast End Side"] -- handled at runtime
	end
	self.TimeText:SetFont(media:Fetch("font", db.font), db.timefontsize)
	self.TimeText:SetShadowColor( 0, 0, 0, 1)
	self.TimeText:SetShadowOffset( 0.8, -0.8 )
	self.TimeText:SetTextColor(unpack(Quartz3.db.profile.timetextcolor))
	self.TimeText:SetNonSpaceWrap(false)
	self.TimeText:SetHeight(db.h)

	local temptext = self.TimeText:GetText()
	if db.hidecasttime then
		self.TimeText:SetFormattedText(TimeFmt(10))
	else
		self.TimeText:SetFormattedText("%s / %s", format(TimeFmt(10)), format(TimeFmt(10, true)))
	end
	local normaltimewidth = self.TimeText:GetStringWidth()
	self.TimeText:SetText(temptext)

	if db.hidenametext then
		self.Text:Hide()
	else
		self.Text:Show()
		self.Text:ClearAllPoints()
		local position = db.nametextposition
		if position == "left" then
			self.Text:SetPoint("LEFT", self.Bar, "LEFT", db.nametextx, db.nametexty)
			self.Text:SetJustifyH("LEFT")
			if db.hidetimetext or db.timetextposition ~= "right" then
				self.Text:SetWidth(db.w)
			else
				self.Text:SetWidth(db.w - normaltimewidth - 5)
			end
		elseif position == "center" then
			self.Text:SetPoint("CENTER", self.Bar, "CENTER", db.nametextx, db.nametexty)
			self.Text:SetJustifyH("CENTER")
		else -- L["Right"]
			self.Text:SetPoint("RIGHT", self.Bar, "RIGHT", -1 * db.nametextx, db.nametexty)
			self.Text:SetJustifyH("RIGHT")
			if db.hidetimetext or db.timetextposition ~= "left" then
				self.Text:SetWidth(db.w)
			else
				self.Text:SetWidth(db.w - normaltimewidth - 5)
			end
		end
	end
	self.Text:SetFont(media:Fetch("font", db.font), db.fontsize)
	self.Text:SetShadowColor( 0, 0, 0, 1)
	self.Text:SetShadowOffset( 0.8, -0.8 )
	self.Text:SetTextColor(unpack(Quartz3.db.profile.spelltextcolor))
	self.Text:SetNonSpaceWrap(false)
	self.Text:SetHeight(db.h)

	if db.hideicon then
		self.Icon:Hide()
	else
		self.Icon:Show()
		self.Icon:ClearAllPoints()
		if db.iconposition == "left" then
			self.Icon:SetPoint("RIGHT", self.Bar, "LEFT", -1 * db.icongap, 0)
		else --L["Right"]
			self.Icon:SetPoint("LEFT", self.Bar, "RIGHT", db.icongap, 0)
		end
		self.Icon:SetWidth(db.h)
		self.Icon:SetHeight(db.h)
		self.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		self.Icon:SetAlpha(db.iconalpha)
	end

	self.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	self.Spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
	self.Spark:SetBlendMode("ADD")
	self.Spark:SetWidth(20)
	self.Spark:SetHeight(db.h*2.2)
end

function CastBarTemplate:RegisterEvents()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED")

	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			self.Bar:SetStatusBarTexture(media:Fetch("statusbar", override))
		end
	end)
end

function CastBarTemplate:UnregisterEvents()
	self:UnregisterAllEvents()
	media.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
end

Quartz3.CastBarTemplate = {}
Quartz3.CastBarTemplate.template = CastBarTemplate
function Quartz3.CastBarTemplate:new(name, parent, unit, config)
	local bar = setmetatable(CreateFrame("Frame", name, UIParent), CastBarTemplate_MT)
	bar.unit = unit
	bar.parent = parent
	bar.config = config

	bar:SetFrameStrata("MEDIUM")
	bar:SetScript("OnShow", OnShow)
	bar:SetScript("OnHide", OnHide)
	bar:SetScript("OnUpdate", OnUpdate)
	bar:SetScript("OnEvent", OnEvent)
	bar:SetMovable(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetClampedToScreen(true)

	bar.Bar      = CreateFrame("StatusBar", nil, bar)
	bar.Text     = bar.Bar:CreateFontString(nil, "OVERLAY")
	bar.TimeText = bar.Bar:CreateFontString(nil, "OVERLAY")
	bar.Icon     = bar.Bar:CreateTexture(nil, "DIALOG")
	bar.Spark    = bar.Bar:CreateTexture(nil, "OVERLAY")

	bar.backdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	                 tile = true, tileSize = 16, edgeSize = 16, --edgeFile = "", -- set by ApplySettings
	                 insets = {left = 4, right = 4, top = 4, bottom = 4} }
	bar:Hide()

	return bar
end
