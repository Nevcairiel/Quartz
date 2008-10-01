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
if Quartz:HasModule('Player') then
	return
end
local QuartzPlayer = Quartz:NewModule('Player')
local self = QuartzPlayer

local media = LibStub("LibSharedMedia-3.0")

local math_min = math.min
local unpack = unpack
local tonumber = tonumber
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local GetTime = GetTime
local castTimeFormatString

local castBar, castBarText, castBarTimeText, castBarIcon, castBarSpark, castBarParent, db

local function timenum(num, isCastTime)
	if num <= 60 then
		if isCastTime then
			return (castTimeFormatString):format(num)
		else
			return ('%.1f'):format(num)
		end
	else
		return ('%d:%02d'):format(num / 60, num % 60)
	end
end
local function OnUpdate()
	local currentTime = GetTime()
	local startTime = self.startTime
	local endTime = self.endTime
	local delay = self.delay
	if self.casting then
		if currentTime > endTime then
			self.casting = nil
			self.fadeOut = true
			self.stopTime = currentTime
		end
		
		local showTime = math_min(currentTime, endTime)
		
		local perc = (showTime-startTime) / (endTime - startTime)
		castBar:SetValue(perc)
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint('CENTER', castBar, 'LEFT', perc * db.profile.w, 0)
		
		if delay and delay ~= 0 then
			if db.profile.hidecasttime then
				castBarTimeText:SetText(("|cffff0000+%.1f|cffffffff %s"):format(delay, timenum(endTime - showTime)))
			else
				castBarTimeText:SetText(("|cffff0000+%.1f|cffffffff %s / %s"):format(delay, timenum(endTime - showTime), timenum(endTime - startTime, true)))
			end
		else
			if db.profile.hidecasttime then
				castBarTimeText:SetText(timenum(endTime - showTime))
			else
				castBarTimeText:SetText(("%s / %s"):format(timenum(endTime - showTime), timenum(endTime - startTime, true)))
			end
		end
	elseif self.channeling then
		if currentTime > endTime then
			self.channeling = nil
			self.fadeOut = true
			self.stopTime = currentTime
		end
		local remainingTime = endTime - currentTime
		local perc = remainingTime / (endTime - startTime)
		castBar:SetValue(perc)
		castBarTimeText:SetText(("%.1f"):format(remainingTime))
		castBarSpark:ClearAllPoints()
		castBarSpark:SetPoint('CENTER', castBar, 'LEFT', perc * db.profile.w, 0)
		
		if delay and delay ~= 0 then
			if db.profile.hidecasttime then
				castBarTimeText:SetText(("|cffFF0000-%.1f|cffffffff %s"):format(delay, timenum(remainingTime)))
			else
				castBarTimeText:SetText(("|cffFF0000-%.1f|cffffffff %s / %s"):format(delay, timenum(remainingTime), timenum(endTime - startTime, true)))
			end
		else
			if db.profile.hidecasttime then
				castBarTimeText:SetText(timenum(remainingTime))
			else
				castBarTimeText:SetText(("%s / %s"):format(timenum(remainingTime), timenum(endTime - startTime, true)))
			end
		end
	elseif self.fadeOut then
		castBarSpark:Hide()
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
			castBarParent:Hide()
		else
			castBarParent:SetAlpha(alpha*db.profile.alpha)
		end
	else
		castBarParent:Hide()
	end
end
QuartzPlayer.OnUpdate = OnUpdate
local function OnHide()
	if Quartz:HasModule('Latency') and Quartz:IsModuleActive('Latency') then
		local ql = Quartz:GetModule('Latency')
		if ql.lagbox then
			ql.lagbox:Hide()
			ql.lagtext:Hide()
		end
	end
	castBarParent:SetScript('OnUpdate', nil)
end
local function OnShow()
	castBarParent:SetScript('OnUpdate', OnUpdate)
end
local setnametext
do
	local numerals = { -- 25's enough for now, I think?
		'I', 'II', 'III', 'IV', 'V',
		'VI', 'VII', 'VIII', 'IX', 'X',
		'XI', 'XII', 'XIII', 'XIV', 'XV',
		'XVI', 'XVII', 'XVIII', 'XIX', 'XX',
		'XXI', 'XXII', 'XXIII', 'XXIV', 'XXV',
	}
	function setnametext(name, rank)
		if db.profile.spellrank and rank then
			local rankstyle = db.profile.spellrankstyle
			if rankstyle == L["Number"] then
				local num = tonumber(rank:match(L["Rank (%d+)"]))
				if num and num > 0 then
					castBarText:SetText(("%s %d"):format(name, num))
				else
					castBarText:SetText(name)
				end
			elseif rankstyle == L["Full Text"] then
				local num = tonumber(rank:match(L["Rank (%d+)"]))
				if num and num > 0 then
					castBarText:SetText(("%s (%s)"):format(name, rank))
				else
					castBarText:SetText(name)
				end
			elseif rankstyle == L["Roman"] then
				local num = tonumber(rank:match(L["Rank (%d+)"]))
				if num and num > 0 then
					castBarText:SetText(("%s %s"):format(name, numerals[num]))
				else
					castBarText:SetText(name)
				end
			else -- L["Roman Full Text"]
				local num = tonumber(rank:match(L["Rank (%d+)"]))
				if num and num > 0 then
					castBarText:SetText(("%s (%s)"):format(name, L["Rank %s"]:format(numerals[num])))
				else
					castBarText:SetText(("%s (%s)"):format(name, rank))
				end
			end
		else
			castBarText:SetText(name)
		end
		
		if db.profile.targetname and self.targetName and (self.targetName ~= '') then
			local castText = castBarText:GetText() or nil
			if castText then castBarText:SetText(castText .. " -> " .. self.targetName) end
		end
	end
end


function QuartzPlayer:OnInitialize()
	db = Quartz:AcquireDBNamespace("Player")
	self.db = db
	Quartz:RegisterDefaults("Player", "profile", {
		hideblizz = true,
		
		--x =  -- applied automatically in applySettings()
		y = 180,
		h = 25,
		w = 250,
		scale = 1,
		
		texture = 'LiteStep',
		
		hideicon = false,
		
		alpha = 1,
		iconalpha = 0.9,
		iconposition = L["Left"],
		icongap = 4,
		
		hidenametext = false,
		nametextposition = L["Left"],
		timetextposition = L["Right"], -- L["Left"], L["Center"], L["Cast Start Side"], L["Cast End Side"]
		font = 'Friz Quadrata TT',
		fontsize = 14,
		hidetimetext = false,
		hidecasttime = false,
		casttimeprecision = 1,
		timefontsize = 12,
		targetname = false,
		spellrank = false,
		spellrankstyle = L["Roman"], --L["Full Text"], L["Number"], L["Roman Full Text"]
		
		border = 'Blizzard Tooltip', -- L["None"]
		
		nametextx = 3,
		nametexty = 0,
		timetextx = 3,
		timetexty = 0,
	})
	castBarParent = CreateFrame('Frame', 'QuartzCastBar', UIParent)
	castBarParent:SetFrameStrata('MEDIUM')
	castBarParent:SetScript('OnShow', OnShow)
	castBarParent:SetScript('OnHide', OnHide)
	castBarParent:SetMovable(true)
	castBarParent:RegisterForDrag('LeftButton')
	castBarParent:SetClampedToScreen(true)
	
	castBar = CreateFrame("StatusBar", nil, castBarParent)
	castBarText = castBar:CreateFontString(nil, 'OVERLAY')
	castBarTimeText = castBar:CreateFontString(nil, 'OVERLAY')
	castBarIcon = castBar:CreateTexture(nil, 'DIALOG')
	castBarSpark = castBar:CreateTexture(nil, 'OVERLAY')
	
	castBarParent:Hide()
	
	self.castBarParent = castBarParent
	self.castBar = castBar
	self.castBarText = castBarText
	self.castBarTimeText = castBarTimeText
	self.castBarIcon = castBarIcon
	self.castBarSpark = castBarSpark
	
	self.playerName = UnitName("player");
end


function QuartzPlayer:OnEnable()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_INTERRUPTED", "UNIT_SPELLCAST_INTERRUPTED")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			castBar:SetStatusBarTexture(media:Fetch("statusbar", override))
		end
	end)
	Quartz.ApplySettings()
end

function QuartzPlayer:UNIT_SPELLCAST_SENT(unit, spell, rank, target)
	if unit ~= 'player' then
		return
	end
	if target then
		self.targetName = target;
	else
		self.targetName = self.playerName;
	end
end

function QuartzPlayer:UNIT_SPELLCAST_START(unit)
	if unit ~= 'player' then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)

	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	self.delay = 0
	self.casting = true
	self.channeling = nil
	self.fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz.db.profile.castingcolor))
	
	castBar:SetValue(0)
	castBarParent:Show()
	castBarParent:SetAlpha(db.profile.alpha)
	
	setnametext(displayName, rank)
	
	castBarSpark:Show()
	
	if icon == "Interface\\Icons\\Temp" and Quartz.db.profile.hidesamwise then
		icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.profile.timetextposition
	if position == L["Cast Start Side"] then
		castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.profile.timetextx, db.profile.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	elseif position == L["Cast End Side"] then
		castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.profile.timetextx, db.profile.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	end
end

function QuartzPlayer:UNIT_SPELLCAST_CHANNEL_START(unit)
	if unit ~= 'player' then
		return
	end
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	self.delay = 0
	self.casting = nil
	self.channeling = true
	self.fadeOut = nil

	castBar:SetStatusBarColor(unpack(Quartz.db.profile.channelingcolor))
	
	castBar:SetValue(1)
	castBarParent:Show()
	castBarParent:SetAlpha(db.profile.alpha)

	setnametext(spell, rank)
	
	castBarSpark:Show()
	if icon == "Interface\\Icons\\Temp" and Quartz.db.profile.hidesamwise then
		icon = nil
	end
	castBarIcon:SetTexture(icon)
	
	local position = db.profile.timetextposition
	if position == L["Cast Start Side"] then
		castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.profile.timetextx, db.profile.timetexty)
		castBarTimeText:SetJustifyH("RIGHT")
	elseif position == L["Cast End Side"] then
		castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.profile.timetextx, db.profile.timetexty)
		castBarTimeText:SetJustifyH("LEFT")
	end
end

function QuartzPlayer:UNIT_SPELLCAST_STOP(unit)
	if unit ~= 'player' then
		return
	end
	if self.casting then
		self.targetName = nil
		self.casting = nil
		self.fadeOut = true
		self.stopTime = GetTime()
		
		castBar:SetValue(1.0)
		castBar:SetStatusBarColor(unpack(Quartz.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function QuartzPlayer:UNIT_SPELLCAST_CHANNEL_STOP(unit)
	if unit ~= 'player' then
		return
	end
	if self.channeling then
		self.channeling = nil
		self.fadeOut = true
		self.stopTime = GetTime()
		
		castBar:SetValue(0)
		castBar:SetStatusBarColor(unpack(Quartz.db.profile.completecolor))
		
		castBarTimeText:SetText("")
	end
end

function QuartzPlayer:UNIT_SPELLCAST_FAILED(unit)
	if unit ~= 'player' or self.channeling then
		return
	end
	self.targetName = nil
	self.casting = nil
	self.channeling = nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function QuartzPlayer:UNIT_SPELLCAST_INTERRUPTED(unit)
	if unit ~= 'player' then
		return
	end
	self.targetName = nil
	self.casting = nil
	self.channeling = nil
	self.fadeOut = true
	if not self.stopTime then
		self.stopTime = GetTime()
	end
	castBar:SetValue(1.0)
	castBar:SetStatusBarColor(unpack(Quartz.db.profile.failcolor))
	
	castBarTimeText:SetText("")
end

function QuartzPlayer:UNIT_SPELLCAST_DELAYED(unit)
	if unit ~= 'player' then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime

	self.delay = (self.delay or 0) + (startTime - (oldStart or startTime))
end

function QuartzPlayer:UNIT_SPELLCAST_CHANNEL_UPDATE(unit)
	if unit ~= 'player' then
		return
	end
	local oldStart = self.startTime
	local spell, rank, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
	if not startTime then
		return castBarParent:Hide()
	end
	startTime = startTime / 1000
	endTime = endTime / 1000
	self.startTime = startTime
	self.endTime = endTime
	
	self.delay = (self.delay or 0) + ((oldStart or startTime) - startTime)
end
do
	local backdrop = { insets = {} }
	local backdrop_insets = backdrop.insets
	
	function QuartzPlayer:ApplySettings()
		if castBarParent then
			local db = db.profile
			
			castBarParent = self.castBarParent
			castBar = self.castBar
			castBarText = self.castBarText
			castBarTimeText = self.castBarTimeText
			castBarIcon = self.castBarIcon
			castBarSpark = self.castBarSpark
			
			castBarParent:ClearAllPoints()
			if not db.x then
				db.x = (UIParent:GetWidth() / 2 - (db.w * db.scale) / 2) / db.scale
			end
			castBarParent:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', db.x, db.y)
			castBarParent:SetWidth(db.w+9)
			castBarParent:SetHeight(db.h+10)
			castBarParent:SetAlpha(db.alpha)
			castBarParent:SetScale(db.scale)
			
			

			backdrop.bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
			backdrop.tile = true
			backdrop.tileSize = 16
			backdrop.edgeFile = media:Fetch('border', db.border)
			backdrop.edgeSize = 16
			backdrop_insets.left = 4
			backdrop_insets.right = 4
			backdrop_insets.top = 4
			backdrop_insets.bottom = 4
			
			castBarParent:SetBackdrop(backdrop)
			local r,g,b = unpack(Quartz.db.profile.bordercolor)
			castBarParent:SetBackdropBorderColor(r,g,b, Quartz.db.profile.borderalpha)
			r,g,b = unpack(Quartz.db.profile.backgroundcolor)
			castBarParent:SetBackdropColor(r,g,b, Quartz.db.profile.backgroundalpha)
			
			castBar:ClearAllPoints()
			castBar:SetPoint('CENTER',castBarParent,'CENTER')
			castBar:SetWidth(db.w)
			castBar:SetHeight(db.h)
			castBar:SetStatusBarTexture(media:Fetch('statusbar', db.texture))
			castBar:SetMinMaxValues(0, 1)
			
			if db.hidetimetext then
				castBarTimeText:Hide()
			else
				castBarTimeText:Show()
				castBarTimeText:ClearAllPoints()
				castBarTimeText:SetWidth(db.w)
				local position = db.timetextposition
				if position == L["Left"] then
					castBarTimeText:SetPoint('LEFT', castBar, 'LEFT', db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("LEFT")
				elseif position == L["Center"] then
					castBarTimeText:SetPoint('CENTER', castBar, 'CENTER', db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("CENTER")
				elseif position == L["Right"] then
					castBarTimeText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.timetextx, db.timetexty)
					castBarTimeText:SetJustifyH("RIGHT")
				end -- L["Cast Start Side"], L["Cast End Side"] --handled at runtime
			end
			castBarTimeText:SetFont(media:Fetch('font', db.font), db.timefontsize)
			castBarTimeText:SetShadowColor( 0, 0, 0, 1)
			castBarTimeText:SetShadowOffset( 0.8, -0.8 )
			castBarTimeText:SetTextColor(unpack(Quartz.db.profile.timetextcolor))
			castBarTimeText:SetNonSpaceWrap(false)
			castBarTimeText:SetHeight(db.h)
			
			castTimeFormatString = '%.'..db.casttimeprecision..'f'
			
			local temptext = castBarTimeText:GetText()
			if db.hidecasttime then
				castBarTimeText:SetText(("%s"):format(timenum(10)))
			else
				castBarTimeText:SetText(("%s / %s"):format(timenum(10), timenum(10, true)))
			end
			local normaltimewidth = castBarTimeText:GetStringWidth()
			castBarTimeText:SetText(temptext)
			
			if db.hidenametext then
				castBarText:Hide()
			else
				castBarText:Show()
				castBarText:ClearAllPoints()
				local position = db.nametextposition
				if position == L["Left"] then
					castBarText:SetPoint('LEFT', castBar, 'LEFT', db.nametextx, db.nametexty)
					castBarText:SetJustifyH("LEFT")
					if db.hidetimetext or db.timetextposition ~= L["Right"] then
						castBarText:SetWidth(db.w)
					else
						castBarText:SetWidth(db.w - normaltimewidth - 5)
					end
				elseif position == L["Center"] then
					castBarText:SetPoint('CENTER', castBar, 'CENTER', db.nametextx, db.nametexty)
					castBarText:SetJustifyH("CENTER")
				else -- L["Right"]
					castBarText:SetPoint('RIGHT', castBar, 'RIGHT', -1 * db.nametextx, db.nametexty)
					castBarText:SetJustifyH("RIGHT")
					if db.hidetimetext or db.timetextposition ~= L["Left"] then
						castBarText:SetWidth(db.w)
					else
						castBarText:SetWidth(db.w - normaltimewidth - 5)
					end
				end
			end
			castBarText:SetFont(media:Fetch('font', db.font), db.fontsize)
			castBarText:SetShadowColor( 0, 0, 0, 1)
			castBarText:SetShadowOffset( 0.8, -0.8 )
			castBarText:SetTextColor(unpack(Quartz.db.profile.spelltextcolor))
			castBarText:SetNonSpaceWrap(false)
			castBarText:SetHeight(db.h)
			
			if db.hideicon then
				castBarIcon:Hide()
			else
				castBarIcon:Show()
				castBarIcon:ClearAllPoints()
				if db.iconposition == L["Left"] then
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
			castBarSpark:SetVertexColor(unpack(Quartz.db.profile.sparkcolor))
			castBarSpark:SetBlendMode('ADD')
			castBarSpark:SetWidth(20)
			castBarSpark:SetHeight(db.h*2.2)
			
			if db.hideblizz then
				CastingBarFrame.RegisterEvent = nothing
				CastingBarFrame:UnregisterAllEvents()
				CastingBarFrame:Hide()
			else
				CastingBarFrame.RegisterEvent = nil
				CastingBarFrame:UnregisterAllEvents()
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
			end
		end
	end
end

do
	local function set(field, value)
		db.profile[field] = value
		Quartz.ApplySettings()
	end
	local function get(field)
		return db.profile[field]
	end
	local locked = true
	local function dragstart()
		castBarParent:StartMoving()
	end
	local function dragstop()
		db.profile.x = castBarParent:GetLeft()
		db.profile.y = castBarParent:GetBottom()
		castBarParent:StopMovingOrSizing()
	end
	local function nothing()
		castBarParent:SetAlpha(db.profile.alpha)
	end
	local function hideiconoptions()
		return db.profile.hideicon
	end
	local function hidetimetextoptions()
		return db.profile.hidetimetext
	end
	local function hidecasttimeprecision()
		return db.profile.hidetimetext or db.profile.hidecasttime
	end
	local function hidenametextoptions()
		return db.profile.hidenametext
	end
	Quartz.options.args.Player = {
		type = 'group',
		name = L["Player"],
		desc = L["Player"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Player')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Player', v)
				end,
				order = 99,
			},
			lock = {
				type = 'toggle',
				name = L["Lock"],
				desc = L["Toggle Cast Bar lock"],
				get = function()
					return locked
				end,
				set = function(v)
					if v then
						castBarParent.Hide = nil
						castBarParent:EnableMouse(false)
						castBarParent:SetScript('OnDragStart', nil)
						castBarParent:SetScript('OnDragStop', nil)
						if not (self.channeling or self.casting) then
							castBarParent:Hide()
						end
					else
						castBarParent:Show()
						castBarParent:EnableMouse(true)
						castBarParent:SetScript('OnDragStart', dragstart)
						castBarParent:SetScript('OnDragStop', dragstop)
						castBarParent:SetAlpha(1)
						castBarParent.Hide = nothing
						castBarIcon:SetTexture("Interface\\Icons\\Temp")
					end
					locked = v
				end,
				order = 100,
			},
			hideblizz = {
				type = 'toggle',
				name = L["Disable Blizzard Cast Bar"],
				desc = L["Disable and hide the default UI's casting bar"],
				get = get,
				set = set,
				passValue = 'hideblizz',
				order = 101,
			},
			h = {
				type = 'range',
				name = L["Height"],
				desc = L["Height"],
				min = 10,
				max = 50,
				step = 1,
				order = 200,
				get = get,
				set = set,
				passValue = 'h',
			},
			w = {
				type = 'range',
				name = L["Width"],
				desc = L["Width"],
				min = 50,
				max = 1500,
				step = 5,
				order = 200,
				get = get,
				set = set,
				passValue = 'w',
			},
			x = {
				type = 'text',
				name = L["X"],
				desc = L["Set an exact X value for this bar's position."],
				get = get,
				set = set,
				passValue = 'x',
				order = 200,
				validate = function(v)
					return tonumber(v) and true
				end,
				usage = L["Number"],
			},
			y = {
				type = 'text',
				name = L["Y"],
				desc = L["Set an exact Y value for this bar's position."],
				get = get,
				set = set,
				passValue = 'y',
				order = 200,
				validate = function(v)
					return tonumber(v) and true
				end,
				usage = L["Number"],
			},
			scale = {
				type = 'range',
				name = L["Scale"],
				desc = L["Scale"],
				min = 0.2,
				max = 1,
				step = 0.025,
				order = 201,
				get = get,
				set = set,
				passValue = 'scale',
			},
			alpha = {
				type = 'range',
				name = L["Alpha"],
				desc = L["Alpha"],
				isPercent = true,
				min = 0.1,
				max = 1,
				step = 0.025,
				order = 202,
				get = get,
				set = set,
				passValue = 'alpha',
			},
			header2 = {
				type = 'header',
				order = 203,
			},
			hideicon = {
				type = 'toggle',
				name = L["Hide Icon"],
				desc = L["Hide Spell Cast Icon"],
				get = get,
				set = set,
				passValue = 'hideicon',
				order = 301,
			},
			iconalpha = {
				type = 'range',
				name = L["Icon Alpha"],
				desc = L["Set the Spell Cast icon alpha"],
				isPercent = true,
				min = 0.1,
				max = 1,
				step = 0.025,
				order = 301,
				get = get,
				set = set,
				disabled = hideiconoptions,
				passValue = 'iconalpha',
			},
			iconposition = {
				type = 'text',
				name = L["Icon Position"],
				desc = L["Set where the Spell Cast icon appears"],
				get = get,
				set = set,
				disabled = hideiconoptions,
				passValue = 'iconposition',
				validate = {L["Left"], L["Right"]},
				order = 301,
			},
			icongap = {
				type = 'range',
				name = L["Icon Gap"],
				desc = L["Space between the cast bar and the icon."],
				min = -35,
				max = 35,
				step = 1,
				order = 301,
				get = get,
				set = set,
				disabled = hideiconoptions,
				passValue = 'icongap',
			},
			texture = {
				type = 'text',
				name = L["Texture"],
				desc = L["Set the Cast Bar Texture"],
				validate = media:List('statusbar'),
				order = 302,
				get = get,
				set = set,
				passValue = 'texture',
			},
			font = {
				type = 'text',
				name = L["Font"],
				desc = L["Set the font used in the Name and Time texts"],
				validate = media:List('font'),
				order = 400,
				get = get,
				set = set,
				passValue = 'font',
			},
			hidenametext = {
				type = 'toggle',
				name = L["Hide Name Text"],
				desc = L["Disable the text that displays the spell name/rank"],
				get = get,
				set = set,
				passValue = 'hidenametext',
				order = 401,
			},
			nametextposition = {
				type = 'text',
				name = L["Name Text Position"],
				desc = L["Set the alignment of the spell name text"],
				get = get,
				set = set,
				passValue = 'nametextposition',
				validate = {L["Left"], L["Right"], L["Center"]},
				disabled = hidenametextoptions,
				order = 402,
			},
			nametextx = {
				type = 'range',
				name = L["Name Text X Offset"],
				desc = L["Adjust the X position of the name text"],
				get = get,
				set = set,
				passValue = 'nametextx',
				min = -35,
				max = 35,
				step = 1,
				disabled = hidenametextoptions,
				order = 402,
			},
			nametexty = {
				type = 'range',
				name = L["Name Text Y Offset"],
				desc = L["Adjust the Y position of the name text"],
				get = get,
				set = set,
				passValue = 'nametexty',
				min = -35,
				max = 35,
				step = 1,
				disabled = hidenametextoptions,
				order = 402,
			},
			namefontsize = {
				type = 'range',
				name = L["Name Text Font Size"],
				desc = L["Set the size of the spell name text"],
				min = 7,
				max = 20,
				step = 1,
				order = 403,
				get = get,
				set = set,
				disabled = hidenametextoptions,
				passValue = 'fontsize',
			},
			targetname = {
				type = 'toggle',
				name = L["Target Name"],
				desc = L["Display target name of spellcasts after spell name"],
				get = get,
				set = set,
				passValue = 'targetname',
				order = 404,
			},			
			spellrank = {
				type = 'toggle',
				name = L["Spell Rank"],
				desc = L["Display the rank of spellcasts alongside their name"],
				get = get,
				set = set,
				disabled = hidenametextoptions,
				passValue = 'spellrank',
				order = 405,
			},
			spellrankstyle = {
				type = 'text',
				name = L["Spell Rank Style"],
				desc = L["Set the display style of the spell rank"],
				get = get,
				set = set,
				disabled = function()
					return db.profile.hidenametext or not db.profile.spellrank
				end,
				passValue = 'spellrankstyle',
				validate = {L["Number"], L["Roman"], L["Full Text"], L["Roman Full Text"]},
				order = 406,
			},
			hidetimetext = {
				type = 'toggle',
				name = L["Hide Time Text"],
				desc = L["Disable the text that displays the time remaining on your cast"],
				get = get,
				set = set,
				passValue = 'hidetimetext',
				order = 411,
			},
			hidecasttime = {
				type = 'toggle',
				name = L["Hide Cast Time"],
				desc = L["Disable the text that displays the total cast time"],
				get = get,
				set = set,
				passValue = 'hidecasttime',
				disabled = hidetimetextoptions,
				order = 412,
			},
			casttimeprecision = {
				type = 'range',
				name = L["Cast Time Precision"],
				desc = L["Set the precision (i.e. number of decimal places) for the cast time text"],
				min = 1,
				max = 3,
				step = 1,
				order = 413,
				get = get,
				set = set,
				disabled = hidecasttimeprecision,
				passValue = 'casttimeprecision',
			},
			timefontsize = {
				type = 'range',
				name = L["Time Font Size"],
				desc = L["Set the size of the time text"],
				min = 7,
				max = 20,
				step = 1,
				order = 414,
				get = get,
				set = set,
				disabled = hidetimetextoptions,
				passValue = 'timefontsize',
			},
			timetextposition = {
				type = 'text',
				name = L["Time Text Position"],
				desc = L["Set the alignment of the time text"],
				get = get,
				set = set,
				passValue = 'timetextposition',
				validate = {L["Left"], L["Right"], L["Center"], L["Cast Start Side"], L["Cast End Side"]},
				disabled = hidetimetextoptions,
				order = 415,
			},
			timetextx = {
				type = 'range',
				name = L["Time Text X Offset"],
				desc = L["Adjust the X position of the time text"],
				get = get,
				set = set,
				passValue = 'timetextx',
				min = -35,
				max = 35,
				step = 1,
				disabled = hidetimetextoptions,
				order = 416,
			},
			timetexty = {
				type = 'range',
				name = L["Time Text Y Offset"],
				desc = L["Adjust the Y position of the time text"],
				get = get,
				set = set,
				passValue = 'timetexty',
				min = -35,
				max = 35,
				step = 1,
				disabled = hidetimetextoptions,
				order = 417,
			},
			header4 = {
				type = 'header',
				order = 418,
			},
			border = {
				type = 'text',
				name = L["Border"],
				desc = L["Set the border style"],
				get = get,
				set = set,
				passValue = 'border',
				validate = media:List('border'),
				order = 418,
			},
			header6 = {
				type = 'header',
				order = 501,
			},
			snaptocenter = {
				type = 'text',
				name = L["Snap to Center"],
				desc = L["Move the CastBar to center of the screen along the specified axis"],
				get = false,
				set = function(v)
					local scale = db.profile.scale
					if v == L["Horizontal"] then
						db.profile.x = (UIParent:GetWidth() / 2 - (db.profile.w * scale) / 2) / scale
					else -- L["Vertical"]
						db.profile.y = (UIParent:GetHeight() / 2 - (db.profile.h * scale) / 2) / scale
					end
					Quartz.ApplySettings()
				end,
				validate = {L["Horizontal"], L["Vertical"]},
				order = 503,
			},
			copysettings = {
				type = 'text',
				name = L["Copy Settings From"],
				desc = L["Select a bar from which to copy settings"],
				get = false,
				set = function(v)
					local from = Quartz:AcquireDBNamespace(v)
					Quartz:CopySettings(from.profile, db.profile)
					Quartz.ApplySettings()
				end,
				validate = {L["Target"], L["Focus"], L["Pet"]},
				order = 504
			},
			header6 = {
				type = 'header',
				order = 505,
			},
		},
	}
end
