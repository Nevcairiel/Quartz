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
local _G = getfenv(0)
local LibStub = _G.LibStub

local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = L["Latency"]
local Latency = Quartz3:NewModule(MODNAME, "AceEvent-3.0")
local Player = Quartz3:GetModule(L["Player"])

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = _G.AceGUIWidgetLSMlists

local unpack = _G.unpack
local GetTime = _G.GetTime

local lagbox, lagtext, db, timeDiff, sendTime, castBar, alignoutside

local getOptions

local defaults = {
	profile = {
		lagcolor = {1, 0, 0},
		lagalpha = 0.6,
		lagtext = true,
		lagfont = 'Friz Quadrata TT',
		lagfontsize = 7,
		lagtextcolor = {0.7, 0.7, 0.7, 0.8},
		lagtextalignment = L["Center"], -- L["Left"], L["Right"]
		lagtextposition = L["Bottom"], --L["Top"], L["Above"], L["Below"]
		
		-- With "embed", the lag indicator is placed on the left hand side of the bar instead of right for normal casting 
		-- and the castbar time is shifted so that the end of the time accounting for lag lines up with the right hand side of the castbar
		-- For channeled spells, the lag indicator is shown on the right, and the cast bar is adjusted down from there 
		-- lagpadding is applied only if lagembed is enabled
		lagembed = false,
		lagpadding = 0.0,
	}
}

function Latency:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, MODNAME)
end

function Latency:OnEnable()
	self:Hook(Player, "UNIT_SPELLCAST_START")
	self:Hook(Player, "UNIT_SPELLCAST_DELAYED")
	
	self:Hook(Player, "UNIT_SPELLCAST_CHANNEL_START")
	self:Hook(Player, "UNIT_SPELLCAST_CHANNEL_UPDATE")
	
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			lagbox:SetTexture(media:Fetch("statusbar", override))
		end
	end)
	if not lagbox then
		castBar = Player.castBar
		lagbox = castBar:CreateTexture(nil, 'BACKGROUND')
		lagtext = castBar:CreateFontString(nil, 'OVERLAY')
		self.lagbox = lagbox
		self.lagtext = lagtext
	end
	Quartz3.ApplySettings()
end
function Latency:OnDisable()
	lagbox:Hide()
	lagtext:Hide()
end
function Latency:UNIT_SPELLCAST_SENT(event, unit)
	if unit ~= 'player' then
		return
	end
	sendTime = GetTime()
end
function Latency:UNIT_SPELLCAST_START(object, unit)
	self.hooks[object].UNIT_SPELLCAST_START(object, unit)
	if unit ~= 'player' or not sendTime then
		return
	end
	local startTime = Player.startTime
	local endTime = Player.endTime
	if not endTime then
		return
	end
	timeDiff = GetTime() - sendTime
	
	local castlength = endTime - startTime
	timeDiff = timeDiff > castlength and castlength or timeDiff
	local perc = timeDiff / castlength 
	
	lagbox:ClearAllPoints()
	local side
	if db.profile.lagembed then
		side = 'LEFT'
		lagbox:SetTexCoord(0,perc,0,1)
		
		startTime = startTime - timeDiff + db.profile.lagpadding
		Player.startTime = startTime
		endTime = endTime - timeDiff + db.profile.lagpadding
		Player.endTime = endTime
	else
		side = 'RIGHT'
		lagbox:SetTexCoord(1-perc,1,0,1)
	end
	lagbox:SetDrawLayer(side == 'LEFT' and "OVERLAY" or "BACKGROUND")
	lagbox:SetPoint(side, castBar, side)
	lagbox:SetWidth(Player.db.profile.w * perc)
	lagbox:Show()
	
	if db.profile.lagtext then
		if alignoutside then
			lagtext:SetJustifyH(side)
			lagtext:ClearAllPoints()
			local lagtextposition = db.profile.lagtextposition
			local point, relpoint
			if lagtextposition == L["Bottom"] then
				point = 'BOTTOM'
				relpoint = 'BOTTOM'
			elseif lagtextposition == L["Top"] then
				point = 'TOP'
				relpoint = 'TOP'
			elseif lagtextposition == L["Above"] then
				point = 'BOTTOM'
				relpoint = 'TOP'
			else --L["Below"]
				point = 'TOP'
				relpoint = 'BOTTOM'
			end
			if side == 'LEFT' then
				lagtext:SetPoint(point..'LEFT', lagbox, relpoint..'LEFT', 1, 0)
			else
				lagtext:SetPoint(point..'RIGHT', lagbox, relpoint..'RIGHT', -1, 0)
			end
		end
		lagtext:SetText(L["%dms"]:format(timeDiff*1000))
		lagtext:Show()
	else
		lagtext:Hide()
	end
end
function Latency:UNIT_SPELLCAST_DELAYED(object, unit)
	self.hooks[object].UNIT_SPELLCAST_DELAYED(object, unit)
	if unit ~= 'player' then
		return
	end
	
	if db.profile.lagembed then
		local startTime = Player.startTime - timeDiff + db.profile.lagpadding
		Player.startTime = startTime
		local endTime = Player.endTime - timeDiff + db.profile.lagpadding
		Player.endTime = endTime
	end
end
function Latency:UNIT_SPELLCAST_CHANNEL_START(object, unit)
	self.hooks[object].UNIT_SPELLCAST_CHANNEL_START(object, unit)
	if unit ~= 'player' or not sendTime then
		return
	end

	local startTime = Player.startTime
	local endTime = Player.endTime
	timeDiff = GetTime() - sendTime
	
	local castlength = endTime - startTime
	timeDiff = timeDiff > castlength and castlength or timeDiff
	local perc = timeDiff / castlength
	
	lagbox:ClearAllPoints()
	local side
	if db.profile.lagembed then
		side = 'RIGHT'
		lagbox:SetTexCoord(1-perc,1,0,1)
		
		startTime = startTime - timeDiff + db.profile.lagpadding
		Player.startTime = startTime
		endTime = endTime - timeDiff + db.profile.lagpadding
		Player.endTime = endTime
	else
		side = 'LEFT'
		lagbox:SetTexCoord(perc,1,0,1)
	end
	lagbox:SetDrawLayer(side == 'LEFT' and "OVERLAY" or "BACKGROUND")
	lagbox:SetPoint(side, castBar, side)
	lagbox:SetWidth(Player.db.profile.w * perc)
	lagbox:Show()
	
	if db.profile.lagtext then
		if alignoutside then
			lagtext:SetJustifyH(side)
			lagtext:ClearAllPoints()
			local lagtextposition = db.profile.lagtextposition
			local point, relpoint
			if lagtextposition == L["Bottom"] then
				point = 'BOTTOM'
				relpoint = 'BOTTOM'
			elseif lagtextposition == L["Top"] then
				point = 'TOP'
				relpoint = 'TOP'
			elseif lagtextposition == L["Above"] then
				point = 'BOTTOM'
				relpoint = 'TOP'
			else --L["Below"]
				point = 'TOP'
				relpoint = 'BOTTOM'
			end
			if side == 'LEFT' then
				lagtext:SetPoint(point..'LEFT', lagbox, relpoint..'LEFT', 1, 0)
			else
				lagtext:SetPoint(point..'RIGHT', lagbox, relpoint..'RIGHT', -1, 0)
			end
		end
		lagtext:SetText(L["%dms"]:format(timeDiff*1000))
		lagtext:Show()
	else
		lagtext:Hide()
	end
end
function Latency:UNIT_SPELLCAST_CHANNEL_UPDATE(object, unit)
	self.hooks[object].UNIT_SPELLCAST_CHANNEL_UPDATE(object, unit)
	if unit ~= 'player' then
		return
	end
	
	if db.profile.lagembed then
		local startTime = Player.startTime - timeDiff + db.profile.lagpadding
		Player.startTime = startTime
		local endTime = Player.endTime - timeDiff + db.profile.lagpadding
		Player.endTime = endTime
	end
end
function Latency:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit == 'player' then
		lagbox:Hide()
		lagtext:Hide()
	end
end
function Latency:ApplySettings()
	if lagbox and Quartz3:GetModuleEnabled(MODNAME) then
		castBar = Player.castBar
		
		local db = db.profile
		lagbox:SetHeight(castBar:GetHeight())
		lagbox:SetTexture(media:Fetch('statusbar', Player.db.profile.texture))
		lagbox:SetAlpha(db.lagalpha)
		lagbox:SetVertexColor(unpack(db.lagcolor))
		
		lagtext:SetFont(media:Fetch('font', db.lagfont), db.lagfontsize)
		lagtext:SetShadowColor( 0, 0, 0, 1)
		lagtext:SetShadowOffset( 0.8, -0.8 )
		lagtext:SetTextColor(unpack(db.lagtextcolor))
		lagtext:SetNonSpaceWrap(false)
		
		local lagtextposition = db.lagtextposition
		local point, relpoint
		if lagtextposition == L["Bottom"] then
			point = 'BOTTOM'
			relpoint = 'BOTTOM'
		elseif lagtextposition == L["Top"] then
			point = 'TOP'
			relpoint = 'TOP'
		elseif lagtextposition == L["Above"] then
			point = 'BOTTOM'
			relpoint = 'TOP'
		else --L["Below"]
			point = 'TOP'
			relpoint = 'BOTTOM'
		end
		local lagtextalignment = db.lagtextalignment
		if lagtextalignment == L["Center"] then
			lagtext:SetJustifyH("CENTER")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point, lagbox, relpoint)
			alignoutside = false
		elseif lagtextalignment == L["Right"] then
			lagtext:SetJustifyH("RIGHT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point..'RIGHT', lagbox, relpoint..'RIGHT', -1, 0)
			alignoutside = false
		elseif lagtextalignment == L["Left"] then
			lagtext:SetJustifyH("LEFT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point..'LEFT', lagbox, relpoint..'LEFT', 1, 0)
			alignoutside = false
		else -- ["Outside"] is set on cast start
			alignoutside = true
		end
	end
end

do
	local function set(field, value)
		db.profile[field] = value
		Quartz3.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz3.ApplySettings()
	end
	local function getcolor(field)
		return unpack(db.profile[field])
	end
	local function hidelagtextoptions()
		return not db.profile.lagtext
	end

	local options
	function getOptions()
		options = options or {
		type = 'group',
		name = L["Latency"],
		desc = L["Latency"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz3:GetModuleEnabled(MODNAME)
				end,
				set = function(v)
					Quartz3:SetModuleEnabled(MODNAME, v)
				end,
				order = 100,
			},
			lagembed = {
				type = 'toggle',
				name = L["Embed"],
				desc = L["Include Latency time in the displayed cast bar."],
				get = get,
				set = set,
				order = 101,
				--passValue = 'lagembed',
			},
			lagpadding = {
				type = 'range',
				name = L["Embed Safety Margin"],
				desc = L["Embed mode will decrease it's lag estimates by this amount.  Ideally, set it to the difference between your highest and lowest ping amounts.  (ie, if your ping varies from 200ms to 400ms, set it to 0.2)"],
				min = 0,
				max = 1,
				step = 0.05,
				get = get,
				set = set,
				--passValue = 'lagpadding',
				disabled = function()
					return not db.profile.lagembed
				end,
				order = 102,
			},
			lagcolor = {
				type = 'color',
				name = L["Bar Color"],
				desc = L["Set the color of the %s"]:format(L["Latency Bar"]),
				get = getcolor,
				set = setcolor,
				--passValue = 'lagcolor',
				order = 111,
			},
			lagalpha ={
				type = 'range',
				name = L["Alpha"],
				desc = L["Set the alpha of the latency bar"],
				min = 0.05,
				max = 1,
				step = 0.05,
				isPercent = true,
				get = get,
				set = set,
				--passValue = 'lagalpha',
				order = 112,
			},
			header = {
				type = 'header',
				order = 113,
			},
			lagtext = {
				type = 'toggle',
				name = L["Show Text"],
				desc = L["Display the latency time as a number on the latency bar"],
				get = get,
				set = set,
				--passValue = 'lagtext',
				order = 114,
			},
			lagfont = {
				type = 'select',
				dialogControl = "LSM30_Font",
				name = L["Font"],
				desc = L["Set the font used for the latency text"],
				values = lsmlist.font,
				get = get,
				set = set,
				--passValue = 'lagfont',
				disabled = hidelagtextoptions,
				order = 115,
			},
			lagfontsize = {
				type = 'range',
				name = L["Font Size"],
				desc = L["Set the size of the latency text"],
				min = 3,
				max = 15,
				step = 1,
				get = get,
				set = set,
				--passValue = 'lagfontsize',
				disabled = hidelagtextoptions,
				order = 116,
			},
			lagtextcolor = {
				type = 'color',
				name = L["Text Color"],
				desc = L["Set the color of the latency text"],
				get = getcolor,
				set = setcolor,
				--passValue = 'lagtextcolor',
				disabled = hidelagtextoptions,
				hasAlpha = true,
				order = 117,
			},
			lagtextalignment = {
				type = 'select',
				name = L["Text Alignment"],
				desc = L["Set the position of the latency text"],
				values = {["center"] = L["Center"], ["left"] = L["Left"], ["right"] = L["Right"], ["outside"] = L["Outside"]},
				get = get,
				set = set,
				--passValue = 'lagtextalignment',
				disabled = hidelagtextoptions,
				order = 118,
			},
			lagtextposition = {
				type = 'select',
				name = L["Text Position"],
				desc = L["Set the vertical position of the latency text"],
				values = {["above"] = L["Above"], ["top"] = L["Top"], ["bottom"] = L["Bottom"], ["below"] = L["Below"]},
				get = get,
				set = set,
				--passValue = 'lagtextposition',
				disabled = hidelagtextoptions,
				order = 119,
			},
		},
	}
	return options
	end
end
