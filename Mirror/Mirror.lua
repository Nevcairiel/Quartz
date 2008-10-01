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
local media = LibStub("LibSharedMedia-3.0")
local L = AceLibrary("AceLocale-2.2"):new("Quartz")

local Quartz = Quartz
if Quartz:HasModule('Mirror') then
	return
end
local QuartzMirror = Quartz:NewModule('Mirror', 'AceHook-2.1')
local self = QuartzMirror
local new, del = Quartz.new, Quartz.del

local GetTime = GetTime
local table_sort = table.sort
local math_ceil = math.ceil

local GetMirrorTimerProgress = GetMirrorTimerProgress
local GetMirrorTimerInfo = GetMirrorTimerInfo

local db
local _G = getfenv(0)

local gametimebase, gametimetostart
local locked = true

local icons = {
	BREATH = 'Interface\\Icons\\Spell_Shadow_DemonBreath',
	EXHAUSTION = 'Interface\\Icons\\Ability_Suffocate',
	FEIGNDEATH = 'Interface\\Icons\\Ability_Rogue_FeignDeath',
	CAMP = 'Interface\\Icons\\INV_Misc_GroupLooking',
	DEATH = 'Interface\\Icons\\Ability_Vanish',
	QUIT = 'Interface\\Icons\\INV_Misc_GroupLooking',
	DUEL_OUTOFBOUNDS = 'Interface\\Icons\\Ability_Rogue_Sprint',
	INSTANCE_BOOT = 'Interface\\Icons\\INV_Misc_Rune_01',
	CONFIRM_SUMMON = 'Interface\\Icons\\Spell_Shadow_Twilight',
	AREA_SPIRIT_HEAL = 'Interface\\Icons\\Spell_Holy_Resurrection',
	REZTIMER = '',
	RESURRECT_NO_SICKNESS = '',
	PARTY_INVITE = '',
	DUEL_REQUESTED = '',
	GAMESTART = '',
}
local popups = {
	CAMP = L["Logout"],
	DEATH = L["Release"],
	QUIT = L["Quit"],
	DUEL_OUTOFBOUNDS = L["Forfeit Duel"],
	INSTANCE_BOOT = L["Instance Boot"],
	CONFIRM_SUMMON = L["Summon"],
	AREA_SPIRIT_HEAL = L["AOE Rez"],
	REZTIMER = L["Resurrect Timer"], --GetCorpseRecoveryDelay
	RESURRECT_NO_SICKNESS = L["Resurrect"], --only show if timeleft < delay
	RESURRECT_NO_TIMER = L["Resurrect"],
	PARTY_INVITE = L["Party Invite"],
	DUEL_REQUESTED = L["Duel Request"],
	GAMESTART = L["Game Start"],
}
local timeoutoverrides = {
	DEATH = 360,
	AREA_SPIRIT_HEAL = 30,
	INSTANCE_BOOT = 60,
	CONFIRM_SUMMON = 120,
	GAMESTART = 60,
}

QuartzMirror.ExternalTimers = setmetatable({}, {__index = function(t,k)
	local v = new()
	t[k] = v
	return v
	--[[
	startTime
	endTime
	icon
	color
	]]
end})

local mirrorOnUpdate, fakeOnUpdate
do
	local function timenum(num)
		if num <= 10 then
			return ('%.1f'):format(num)
		elseif num <= 60 then
			return ('%d'):format(num)
		elseif num <= 3600 then
			return ('%d:%02d'):format(num / 60, num % 60)
		else
			return ('%d:%02d'):format(num / 3600, (num % 3600) / 60)
		end
	end
	function mirrorOnUpdate(frame)
		local progress = GetMirrorTimerProgress(frame.mode) / 1000
		local duration = frame.duration
		progress = progress > duration and duration or progress
		frame:SetValue(progress)
		frame.timetext:SetText(timenum(progress))
	end
	function fakeOnUpdate(frame)
		local currentTime = GetTime()
		local endTime = frame.endTime
		
		local frame_num = frame.framenum
		if frame_num > 0 then
			local popup = _G["StaticPopup"..frame_num] -- hate to do this, but I can't think of a better way.
			if popup.which ~= frame.which or not popup:IsVisible() then
				return self:UpdateBars()
			end
		end
		
		if currentTime > endTime then
			self:UpdateBars()
		else
			local remaining = (currentTime - frame.startTime)
			frame:SetValue(endTime - remaining)
			frame.timetext:SetText(timenum(endTime - currentTime))
		end
	end
end
local function OnHide(frame)
	frame:SetScript('OnUpdate', nil)
end
local mirrorbars = setmetatable({}, {
	__index = function(t,k)
		local bar = CreateFrame('StatusBar', nil, UIParent)
		t[k] = bar
		bar:SetFrameStrata('MEDIUM')
		bar:Hide()
		bar:SetScript('OnHide', OnHide)
		bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		bar:SetBackdropColor(0,0,0)
		bar.text = bar:CreateFontString(nil, 'OVERLAY')
		bar.timetext = bar:CreateFontString(nil, 'OVERLAY')
		bar.icon = bar:CreateTexture(nil, 'DIALOG')
		if k == 1 then
			bar:SetMovable(true)
			bar:RegisterForDrag('LeftButton')
			bar:SetClampedToScreen(true)
		end
		self:ApplySettings()
		return bar
	end
})

function QuartzMirror:OnInitialize()
	db = Quartz:AcquireDBNamespace("Mirror")
	Quartz:RegisterDefaults("Mirror", "profile", {
		mirroricons = true,
		mirroriconside = L["Left"],
		
		mirroranchor = L["Player"],--L["Free"], L["Target"], L["Focus"]
		
		mirrorx = 500,
		mirrory = 700,
		mirrorgrowdirection = L["Up"], --L["Down"]
		
		mirrorposition = L["Top Left"],
		
		mirrorgap = 1,
		mirrorspacing = 1,
		mirroroffset = 3,
		
		mirrornametext = true,
		mirrortimetext = true,
		
		mirrortexture = 'LiteStep',
		mirrorwidth = 120,
		mirrorheight = 12,
		mirrorfont = 'Friz Quadrata TT',
		mirrorfontsize = 9,
		mirroralpha = 1,
		
		mirrortextcolor = {1, 1, 1},
		BREATH = {0, 0.5, 1},
		EXHAUSTION = {1.00, 0.9, 0},
		FEIGNDEATH = {1, 0.7, 0},
		CAMP = {1, 0.7, 0},
		DEATH = {1, 0.1, 0.1},
		QUIT = {1, 0.7, 0},
		DUEL_OUTOFBOUNDS = {0.2, 0.8, 0.2},
		INSTANCE_BOOT = {1, 0, 0},
		CONFIRM_SUMMON = {1, 0.3, 1},
		AREA_SPIRIT_HEAL = {0, 0.22, 1},
		REZTIMER = {1, 0, 0.5},
		RESURRECT_NO_SICKNESS = {0.47, 1, 0},
		RESURRECT_NO_TIMER = {0.47, 1, 0},
		PARTY_INVITE = {1, 0.9, 0},
		DUEL_REQUESTED = {1, 0.13, 0},
		GAMESTART = {0,1,0},
		
		hideblizzmirrors = true,
		
		showmirror = true,
		showstatic = true,
		showpvp = true,
	})
end
function QuartzMirror:OnEnable()
	self:RegisterEvent("MIRROR_TIMER_PAUSE", "UpdateBars")
	self:RegisterEvent("MIRROR_TIMER_START", "UpdateBars")
	self:RegisterEvent("MIRROR_TIMER_STOP", "UpdateBars")
	self:RegisterEvent("PLAYER_UNGHOST", "UpdateBars")
	self:RegisterEvent("PLAYER_ALIVE", "UpdateBars")
	self:RegisterEvent("QuartzMirror_UpdateCustom", "UpdateBars")
	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
	self:SecureHook("StaticPopup_Show", "UpdateBars")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			for i, v in pairs(mirrorbars) do
				v:SetStatusBarTexture(media:Fetch("statusbar", override))
			end
		end
	end)
	Quartz.ApplySettings()
end
function QuartzMirror:OnDisable()
	mirrorbars[1].Hide = nil
	mirrorbars[1]:EnableMouse(false)
	mirrorbars[1]:SetScript('OnDragStart', nil)
	mirrorbars[1]:SetScript('OnDragStop', nil)
	for _, v in pairs(mirrorbars) do
		v:Hide()
	end
	for i = 1, 3 do
		_G['MirrorTimer'..i]:RegisterEvent("MIRROR_TIMER_PAUSE")
		_G['MirrorTimer'..i]:RegisterEvent("MIRROR_TIMER_STOP")
	end
	UIParent:RegisterEvent("MIRROR_TIMER_START")
end
do
	local function sort(a,b)
		return a.name < b.name
	end
	local tmp = {}
	local reztimermax = 0
	local function update()
		local db = db.profile
		local currentTime = GetTime()
		for k in pairs(tmp) do
			tmp[k] = del(tmp[k])
		end
		
		if db.showpvp then
			if gametimebase then
				local endTime = gametimebase + gametimetostart
				if endTime > currentTime then
					local which = 'GAMESTART'
					local t = new()
					tmp[#tmp+1] = t
					t.name = popups[which]
					t.texture = icons[which]
					t.mode = which
					t.startTime = endTime - timeoutoverrides[which]
					t.endTime = endTime
					t.isfake = true
					t.framenum = 0
				else
					gametimebase = nil
					gametimetostart = nil
				end
			end
		end
		
		if db.showmirror then
			for i = 1, MIRRORTIMER_NUMTIMERS do
				local timer, value, maxvalue, scale, paused, label = GetMirrorTimerInfo(i)
				if timer ~= 'UNKNOWN' then
					local t = new()
					tmp[#tmp+1] = t
					t.name = label
					t.texture = icons[timer]
					t.mode = timer
					t.duration = maxvalue / 1000
					t.isfake = false
				end
			end
		end
		
		if db.showstatic then
			local recoverydelay = GetCorpseRecoveryDelay()
			if recoverydelay > 0 and UnitHealth('player') < 2 then
				if reztimermax == 0 then
					reztimermax = recoverydelay
				end
				local which = 'REZTIMER'
				local t = new()
				tmp[#tmp+1] = t
				t.name = popups[which]
				t.texture = icons[which]
				t.mode = which
				t.startTime = currentTime - (reztimermax - recoverydelay)
				t.endTime = currentTime + recoverydelay
				t.isfake = true
				t.framenum = 0
			else
				reztimermax = 0
			end
			
			for i = 1, 4 do
				local popup = _G["StaticPopup"..i]
				local which = popup.which
				local timeleft = popup.timeleft
				local name = popups[which]
				
				--special case for a timered rez
				if which == 'RESURRECT_NO_SICKNESS' then
					if timeleft > 60 then
						name = nil
					end
				end
				
				if popup:IsVisible() and name and timeleft and timeleft > 0 then
					local t = new()
					tmp[#tmp+1] = t
					t.name = name
					t.texture = icons[which]
					t.mode = which
					local timeout = StaticPopupDialogs[which].timeout
					if not timeout or timeout == 0 then
						timeout = timeoutoverrides[which]
					end
					--!!delete this check eventually
					if not timeout then
						error(which..' has no timeout value set, tell nymbia!')
					end
					--
					t.startTime = currentTime - (timeout - timeleft)
					t.endTime = currentTime + timeleft
					t.isfake = true
					t.framenum = i
				end
			end
		end
		
		local external = self.ExternalTimers
		for name, v in pairs(external) do
			local endTime = v.endTime
			if not v.startTime or not endTime then
				error('bad custom table')
			end
			if endTime > currentTime then
				local t = new()
				tmp[#tmp+1] = t
				t.name = name
				t.texture = v.icon or icons[name]
				t.startTime = v.startTime
				t.endTime = v.endTime
				t.isfake = true
				t.framenum = 0
				if v.color then
					t.color = v.color
				end
			else
				external[name] = del(v)
			end
		end
		
		table_sort(tmp, sort)
		local maxindex = 0
		for k,v in ipairs(tmp) do
			maxindex = k
			local bar = mirrorbars[k]
			bar.text:SetText(v.name)
			bar.icon:SetTexture(v.texture)
			bar.mode = v.mode
			if v.isfake then
				local startTime, endTime = v.startTime, v.endTime
				bar:SetMinMaxValues(startTime, endTime)
				bar.startTime = startTime
				bar.endTime = endTime
				bar.framenum = v.framenum
				bar.which = v.mode
				bar:Show()
				bar:SetScript('OnUpdate', fakeOnUpdate)
				if v.mode then
					bar:SetStatusBarColor(unpack(db[v.mode]))
				elseif v.color then
					bar:SetStatusBarColor(unpack(v.color))
				else
					bar:SetStatusBarColor(1,1,1) --!! add option
				end
			else
				local duration = v.duration
				bar:SetMinMaxValues(0, duration)
				bar.duration = duration
				bar:Show()
				bar:SetScript('OnUpdate', mirrorOnUpdate)
				bar:SetStatusBarColor(unpack(db[v.mode]))
			end
		end
		for i = maxindex+1, #mirrorbars do
			mirrorbars[i]:Hide()
		end
	end
	function QuartzMirror:UpdateBars()
		if not self:IsEventScheduled('QuartzMirrorUpdate') then
			self:ScheduleEvent('QuartzMirrorUpdate', update, 0) -- API funcs don't return helpful crap until after the event.
		end
	end
end
function QuartzMirror:CHAT_MSG_BG_SYSTEM_NEUTRAL(msg)
	if msg:match(L["1 minute"]) or msg:match(L["One minute until"]) then
		gametimebase = GetTime()
		gametimetostart = 60
	elseif msg:match(L["30 seconds"]) or msg:match(L["Thirty seconds until"]) then
		gametimebase = GetTime()
		gametimetostart = 30
	elseif msg:match(L["15 seconds"]) or msg:match(L["Fifteen seconds until"]) then
		gametimebase = GetTime()
		gametimetostart = 15
	end
	self:UpdateBars()
end
do
	local function apply(i, bar, db, direction)
		local position, showicons, iconside, gap, spacing, offset
		local qpdb = Quartz:AcquireDBNamespace("Player").profile
		
		position = db.mirrorposition
		showicons = db.mirroricons
		iconside = db.mirroriconside
		gap = db.mirrorgap
		spacing = db.mirrorspacing
		offset = db.mirroroffset
		
		bar:ClearAllPoints()
		bar:SetStatusBarTexture(media:Fetch('statusbar', db.mirrortexture))
		bar:SetWidth(db.mirrorwidth)
		bar:SetHeight(db.mirrorheight)
		bar:SetScale(qpdb.scale)
		bar:SetAlpha(db.mirroralpha)
		
		if db.mirroranchor == L["Free"] then
			if i == 1 then
				bar:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', db.mirrorx, db.mirrory)
				if db.mirrorgrowdirection == L["Up"] then
					direction = 1
				else --L["Down"]
					direction = -1
				end
			else
				if direction == 1 then
					bar:SetPoint('BOTTOMRIGHT', mirrorbars[i-1], 'TOPRIGHT', 0, spacing)
				else -- -1
					bar:SetPoint('TOPRIGHT', mirrorbars[i-1], 'BOTTOMRIGHT', 0, -1 * spacing)
				end
			end
		else
			if i == 1 then
				local anchorframe
				local anchor = db.mirroranchor
				if anchor == L["Focus"] and QuartzFocusBar then
					anchorframe = QuartzFocusBar
				elseif anchor == L["Target"] and QuartzTargetBar then
					anchorframe = QuartzTargetBar
				else -- L["Player"]
					anchorframe = QuartzCastBar
				end
				
				if position == L["Top"] then
					direction = 1
					bar:SetPoint('BOTTOM', anchorframe, 'TOP', 0, gap)
				elseif position == L["Bottom"] then
					direction = -1
					bar:SetPoint('TOP', anchorframe, 'BOTTOM', 0, -1 * gap)
				elseif position == L["Top Right"] then
					direction = 1
					bar:SetPoint('BOTTOMRIGHT', anchorframe, 'TOPRIGHT', -1 * offset, gap)
				elseif position == L["Bottom Right"] then
					direction = -1
					bar:SetPoint('TOPRIGHT', anchorframe, 'BOTTOMRIGHT', -1 * offset, -1 * gap)
				elseif position == L["Top Left"] then
					direction = 1
					bar:SetPoint('BOTTOMLEFT', anchorframe, 'TOPLEFT', offset, gap)
				elseif position == L["Bottom Left"] then
					direction = -1
					bar:SetPoint('TOPLEFT', anchorframe, 'BOTTOMLEFT', offset, -1 * gap)
				elseif position == L["Left (grow up)"] then
					if iconside == L["Right"] and showicons then
						offset = offset + db.mirrorheight
					end
					if qpdb.iconposition == L["Left"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = 1
					bar:SetPoint('BOTTOMRIGHT', anchorframe, 'BOTTOMLEFT', -1 * offset, gap)
				elseif position == L["Left (grow down)"] then
					if iconside == L["Right"] and showicons then
						offset = offset + db.mirrorheight
					end
					if qpdb.iconposition == L["Left"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = -1
					bar:SetPoint('TOPRIGHT', anchorframe, 'TOPLEFT', -3 * offset, -1 * gap)
				elseif position == L["Right (grow up)"] then
					if iconside == L["Left"] and showicons then
						offset = offset + db.mirrorheight
					end
					if qpdb.iconposition == L["Right"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = 1
					bar:SetPoint('BOTTOMLEFT', anchorframe, 'BOTTOMRIGHT', offset, gap)
				elseif position == L["Right (grow down)"] then
					if iconside == L["Left"] and showicons then
						offset = offset + db.mirrorheight
					end
					if qpdb.iconposition == L["Right"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = -1
					bar:SetPoint('TOPLEFT', anchorframe, 'TOPRIGHT', offset, -1 * gap)
				end
			else
				if direction == 1 then
					bar:SetPoint('BOTTOMRIGHT', mirrorbars[i-1], 'TOPRIGHT', 0, spacing)
				else -- -1
					bar:SetPoint('TOPRIGHT', mirrorbars[i-1], 'BOTTOMRIGHT', 0, -1 * spacing)
				end
			end
		end
		
		local timetext = bar.timetext
		if db.mirrortimetext then
			timetext:Show()
			timetext:ClearAllPoints()
			timetext:SetWidth(db.mirrorwidth)
			timetext:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
			timetext:SetJustifyH("RIGHT")
		else
			timetext:Hide()
		end
		timetext:SetFont(media:Fetch('font', db.mirrorfont), db.mirrorfontsize)
		timetext:SetShadowColor( 0, 0, 0, 1)
		timetext:SetShadowOffset( 0.8, -0.8 )
		timetext:SetTextColor(unpack(db.mirrortextcolor))
		timetext:SetNonSpaceWrap(false)
		timetext:SetHeight(db.mirrorheight)
		
		local temptext = timetext:GetText()
		timetext:SetText('10.0')
		local normaltimewidth = timetext:GetStringWidth()
		timetext:SetText(temptext)
		
		local text = bar.text
		if db.mirrornametext then
			text:Show()
			text:ClearAllPoints()
			text:SetPoint("LEFT", bar, "LEFT", 2, 0)
			text:SetJustifyH("LEFT")
			if db.mirrortimetext then
				text:SetWidth(db.mirrorwidth - normaltimewidth)
			else
				text:SetWidth(db.mirrorwidth)
			end
		else
			text:Hide()
		end
		text:SetFont(media:Fetch('font', db.mirrorfont), db.mirrorfontsize)
		text:SetShadowColor( 0, 0, 0, 1)
		text:SetShadowOffset( 0.8, -0.8 )
		text:SetTextColor(unpack(db.mirrortextcolor))
		text:SetNonSpaceWrap(false)
		text:SetHeight(db.mirrorheight)
		
		local icon = bar.icon
		if showicons then
			icon:Show()
			icon:SetWidth(db.mirrorheight-1)
			icon:SetHeight(db.mirrorheight-1)
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			icon:ClearAllPoints()
			if iconside == L["Left"] then
				icon:SetPoint('RIGHT', bar, "LEFT", -1, 0)
			else
				icon:SetPoint('LEFT', bar, "RIGHT", 1, 0)
			end
		else
			icon:Hide()
		end
		
		return direction
	end
	function QuartzMirror:ApplySettings()
		if Quartz:IsModuleActive('Mirror') and db then
			local db = db.profile
			local direction
			if db.mirroranchor ~= L["Free"] then
				mirrorbars[1].Hide = nil
				mirrorbars[1]:EnableMouse(false)
				mirrorbars[1]:SetScript('OnDragStart', nil)
				mirrorbars[1]:SetScript('OnDragStop', nil)
			end
			for i, v in pairs(mirrorbars) do
				direction = apply(i, v, db, direction)
			end
			if db.hideblizzmirrors then
				for i = 1, 3 do
					_G['MirrorTimer'..i]:UnregisterAllEvents()
					_G['MirrorTimer'..i]:Hide()
				end
				UIParent:UnregisterEvent("MIRROR_TIMER_START")
			else
				for i = 1, 3 do
					_G['MirrorTimer'..i]:RegisterEvent("MIRROR_TIMER_PAUSE")
					_G['MirrorTimer'..i]:RegisterEvent("MIRROR_TIMER_STOP")
				end
				UIParent:RegisterEvent("MIRROR_TIMER_START")
			end
			db.RESURRECT_NO_TIMER = db.RESURRECT_NO_SICKNESS
			self:UpdateBars()
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
	local function setcolor(field, ...)
		db.profile[field] = {...}
		Quartz.ApplySettings()
	end
	local function getcolor(field)
		return unpack(db.profile[field])
	end
	local function getmirrorhidden()
		return not db.profile.showmirror
	end
	local function getstatichidden()
		return not db.profile.showstatic
	end
	local function getpvphidden()
		return not db.profile.showpvp
	end
	local function getfreeoptionshidden()
		return db.profile.mirroranchor ~= L["Free"]
	end
	local function getnotfreeoptionshidden()
		return db.profile.mirroranchor == L["Free"]
	end
	local function dragstart()
		mirrorbars[1]:StartMoving()
	end
	local function dragstop()
		db.profile.mirrorx = mirrorbars[1]:GetLeft()
		db.profile.mirrory = mirrorbars[1]:GetBottom()
		mirrorbars[1]:StopMovingOrSizing()
	end
	local function nothing()
		mirrorbars[1]:SetAlpha(db.profile.mirroralpha)
	end
	local positions = {
		L["Bottom"],
		L["Top"],
		L["Top Left"],
		L["Top Right"],
		L["Bottom Left"],
		L["Bottom Right"],
		L["Left (grow up)"],
		L["Left (grow down)"],
		L["Right (grow up)"],
		L["Right (grow down)"],
	}
	Quartz.options.args.Mirror = {
		type = 'group',
		name = L["Mirror"],
		desc = L["Mirror"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Mirror')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Mirror', v)
				end,
				order = 99,
			},
			mirroranchor = {
				type = 'text',
				name = L["Anchor Frame"],
				desc = L["Select where to anchor the mirror bars"],
				get = get,
				set = set,
				validate = {L["Player"], L["Free"], L["Target"], L["Focus"]},
				passValue = 'mirroranchor',
			},
			-- free
			mirrorlock = {
				type = 'toggle',
				name = L["Lock"],
				desc = L["Toggle mirror bar lock"],
				get = function()
					return locked
				end,
				set = function(v)
					if v then
						mirrorbars[1].Hide = nil
						mirrorbars[1]:EnableMouse(false)
						mirrorbars[1]:SetScript('OnDragStart', nil)
						mirrorbars[1]:SetScript('OnDragStop', nil)
						self:UpdateBars()
					else
						mirrorbars[1]:Show()
						mirrorbars[1]:EnableMouse(true)
						mirrorbars[1]:SetScript('OnDragStart', dragstart)
						mirrorbars[1]:SetScript('OnDragStop', dragstop)
						mirrorbars[1]:SetAlpha(1)
						mirrorbars[1].Hide = nothing
					end
					locked = v
				end,
				hidden = getfreeoptionshidden,
				order = 102,
			},
			mirrorgrowdirection = {
				type = 'text',
				name = L["Grow Direction"],
				desc = L["Set the grow direction of the mirror bars"],
				get = get,
				set = set,
				validate = {L["Up"], L["Down"]},
				passValue = 'mirrorgrowdirection',
				hidden = getfreeoptionshidden,
				order = 103,
			},
			x = {
				type = 'text',
				name = L["X"],
				desc = L["Set an exact X value for this bar's position."],
				get = get,
				set = set,
				passValue = 'mirrorx',
				order = 103,
				validate = function(v)
					return tonumber(v) and true
				end,
				hidden = getfreeoptionshidden,
				usage = L["Number"],
			},
			y = {
				type = 'text',
				name = L["Y"],
				desc = L["Set an exact Y value for this bar's position."],
				get = get,
				set = set,
				passValue = 'mirrory',
				order = 103,
				validate = function(v)
					return tonumber(v) and true
				end,
				hidden = getfreeoptionshidden,
				usage = L["Number"],
			},
			-- anchored to a cast bar
			mirrorposition = {
				type = 'text',
				name = L["Position"],
				desc = L["Position the mirror bars"],
				get = get,
				set = set,
				validate = positions,
				passValue = 'mirrorposition',
				hidden = getnotfreeoptionshidden,
				order = 101,
			},
			mirrorgap = {
				type = 'range',
				name = L["Gap"],
				desc = L["Tweak the vertical position of the mirror bars"],
				min = -35,
				max = 35,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirrorgap',
				hidden = getnotfreeoptionshidden,
				order = 102,
			},
			mirroroffset = {
				type = 'range',
				name = L["Offset"],
				desc = L["Tweak the horizontal position of the mirror bars"],
				min = -35,
				max = 35,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirroroffset',
				hidden = getnotfreeoptionshidden,
				order = 103,
			},
			mirrorspacing = {
				type = 'range',
				name = L["Spacing"],
				desc = L["Tweak the space between mirror bars"],
				min = -35,
				max = 35,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirrorspacing',
				order = 104,
			},
			mirroricons = {
				type = 'toggle',
				name = L["Show Icons"],
				desc = L["Show icons on mirror bars"],
				get = get,
				set = set,
				passValue = 'mirroricons',
				order = 110,
			},
			mirroriconside = {
				type = 'text',
				name = L["Icon Position"],
				desc = L["Set the side of the mirror bar that the icon appears on"],
				get = get,
				set = set,
				validate = {L["Left"], L["Right"]},
				passValue = 'mirroriconside',
				order = 111,
			},
			mirrortexture = {
				type = 'text',
				name = L["Texture"],
				desc = L["Set the mirror bar Texture"],
				validate = media:List('statusbar'),
				order = 112,
				get = get,
				set = set,
				passValue = 'mirrortexture',
			},
			mirrorwidth = {
				type = 'range',
				name = L["Mirror Bar Width"],
				desc = L["Set the width of the mirror bars"],
				min = 50,
				max = 300,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirrorwidth',
				order = 113,
			},
			mirrorheight = {
				type = 'range',
				name = L["Mirror Bar Height"],
				desc = L["Set the height of the mirror bars"],
				min = 4,
				max = 25,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirrorheight',
				order = 114,
			},
			mirroralpha = {
				type = 'range',
				name = L["Alpha"],
				desc = L["Set the alpha of the mirror bars"],
				min = 0.05,
				max = 1,
				step = 0.05,
				isPercent = true,
				get = get,
				set = set,
				passValue = 'mirroralpha',
				order = 115,
			},
			mirrornametext = {
				type = 'toggle',
				name = L["Mirror Name Text"],
				desc = L["Display the names of Mirror Bar Types on their bars"],
				get = get,
				set = set,
				passValue = 'mirrornametext',
				order = 120,
			},
			mirrortimetext = {
				type = 'toggle',
				name = L["Mirror Time Text"],
				desc = L["Display the time remaining on mirror bars"],
				get = get,
				set = set,
				passValue = 'mirrortimetext',
				order = 121,
			},
			mirrorfont = {
				type = 'text',
				name = L["Font"],
				desc = L["Set the font used in the mirror bars"],
				validate = media:List('font'),
				get = get,
				set = set,
				passValue = 'mirrorfont',
				order = 122,
			},
			mirrorfontsize = {
				type = 'range',
				name = L["Font Size"],
				desc = L["Set the font size for the mirror bars"],
				min = 3,
				max = 15,
				step = 1,
				get = get,
				set = set,
				passValue = 'mirrorfontsize',
				order = 123,
			},
			mirrortextcolor = {
				type = 'color',
				name = L["Text Color"],
				desc = L["Set the color of the text for the mirror bars"],
				get = getcolor,
				set = setcolor,
				passValue = 'mirrortextcolor',
				order = 124,
			},
			hideblizzmirrors = {
				type = 'toggle',
				name = L["Hide Blizz Mirror Bars"],
				desc = L["Hide Blizzard's mirror bars"],
				get = get,
				set = set,
				passValue = 'hideblizzmirrors',
				order = 130,
			},
			colors = {
				type = 'group',
				name = L["Colors"],
				desc = L["Colors"],
				order = -1,
				args = {
					-- mirror
					showmirror = {
						type = 'toggle',
						name = L["Show Mirror"],
						desc = L["Show mirror bars such as breath and feign death"],
						get = get,
						set = set,
						passValue = 'showmirror',
						order = 100,
					},
					BREATH = {
						type = 'color',
						name = L["%s Color"]:format(L["Breath"]),
						desc = L["Set the color of the bars for %s"]:format(L["Breath"]),
						get = getcolor,
						set = setcolor,
						passValue = 'BREATH',
						disabled = getmirrorhidden,
						order = 101,
					},
					EXHAUSTION = {
						type = 'color',
						name = L["%s Color"]:format(L["Exhaustion"]),
						desc = L["Set the color of the bars for %s"]:format(L["Exhaustion"]),
						get = getcolor,
						set = setcolor,
						passValue = 'EXHAUSTION',
						disabled = getmirrorhidden,
						order = 101,
					},
					FEIGNDEATH = {
						type = 'color',
						name = L["%s Color"]:format(L["Feign Death"]),
						desc = L["Set the color of the bars for %s"]:format(L["Feign Death"]),
						get = getcolor,
						set = setcolor,
						passValue = 'FEIGNDEATH',
						disabled = getmirrorhidden,
						order = 101,
					},
					-- static
					showstatic = {
						type = 'toggle',
						name = L["Show Static"],
						desc = L["Show bars for static popup items such as rez and summon timers"],
						get = get,
						set = set,
						passValue = 'showstatic',
						order = 200,
					},
					CAMP = {
						type = 'color',
						name = L["%s Color"]:format(L["Logout"]),
						desc = L["Set the color of the bars for %s"]:format(L["Logout"]),
						get = getcolor,
						set = setcolor,
						passValue = 'CAMP',
						disabled = getstatichidden,
						order = 201,
					},
					DEATH = {
						type = 'color',
						name = L["%s Color"]:format(L["Release"]),
						desc = L["Set the color of the bars for %s"]:format(L["Release"]),
						get = getcolor,
						set = setcolor,
						passValue = 'DEATH',
						disabled = getstatichidden,
						order = 201,
					},
					QUIT = {
						type = 'color',
						name = L["%s Color"]:format(L["Quit"]),
						desc = L["Set the color of the bars for %s"]:format(L["Quit"]),
						get = getcolor,
						set = setcolor,
						passValue = 'QUIT',
						disabled = getstatichidden,
						order = 201,
					},
					DUEL_OUTOFBOUNDS = {
						type = 'color',
						name = L["%s Color"]:format(L["Forfeit Duel"]),
						desc = L["Set the color of the bars for %s"]:format(L["Forfeit Duel"]),
						get = getcolor,
						set = setcolor,
						passValue = 'DUEL_OUTOFBOUNDS',
						disabled = getstatichidden,
						order = 201,
					},
					INSTANCE_BOOT = {
						type = 'color',
						name = L["%s Color"]:format(L["Instance Boot"]),
						desc = L["Set the color of the bars for %s"]:format(L["Instance Boot"]),
						get = getcolor,
						set = setcolor,
						passValue = 'INSTANCE_BOOT',
						disabled = getstatichidden,
						order = 201,
					},
					CONFIRM_SUMMON = {
						type = 'color',
						name = L["%s Color"]:format(L["Summon"]),
						desc = L["Set the color of the bars for %s"]:format(L["Summon"]),
						get = getcolor,
						set = setcolor,
						passValue = 'CONFIRM_SUMMON',
						disabled = getstatichidden,
						order = 201,
					},
					AREA_SPIRIT_HEAL = {
						type = 'color',
						name = L["%s Color"]:format(L["AOE Rez"]),
						desc = L["Set the color of the bars for %s"]:format(L["AOE Rez"]),
						get = getcolor,
						set = setcolor,
						passValue = 'AREA_SPIRIT_HEAL',
						disabled = getstatichidden,
						order = 201,
					},
					REZTIMER = {
						type = 'color',
						name = L["%s Color"]:format(L["Resurrect Timer"]),
						desc = L["Set the color of the bars for %s"]:format(L["Resurrect Timer"]),
						get = getcolor,
						set = setcolor,
						passValue = 'REZTIMER',
						disabled = getstatichidden,
						order = 201,
					},
					RESURRECT_NO_SICKNESS = {
						type = 'color',
						name = L["%s Color"]:format(L["Resurrect"]),
						desc = L["Set the color of the bars for %s"]:format(L["Resurrect"]),
						get = getcolor,
						set = setcolor,
						passValue = 'RESURRECT_NO_SICKNESS',
						disabled = getstatichidden,
						order = 201,
					},
					PARTY_INVITE = {
						type = 'color',
						name = L["%s Color"]:format(L["Party Invite"]),
						desc = L["Set the color of the bars for %s"]:format(L["Party Invite"]),
						get = getcolor,
						set = setcolor,
						passValue = 'PARTY_INVITE',
						disabled = getstatichidden,
						order = 201,
					},
					DUEL_REQUESTED = {
						type = 'color',
						name = L["%s Color"]:format(L["Duel Request"]),
						desc = L["Set the color of the bars for %s"]:format(L["Duel Request"]),
						get = getcolor,
						set = setcolor,
						passValue = 'DUEL_REQUESTED',
						disabled = getstatichidden,
						order = 201,
					},
					--pvp
					showpvp = {
						type = 'toggle',
						name = L["Show PvP"],
						desc = L["Show bar for start of arena and battleground games"],
						get = get,
						set = set,
						passValue = 'showpvp',
						order = 300,
					},
					GAMESTART = {
						type = 'color',
						name = L["%s Color"]:format(L["Game Start"]),
						desc = L["Set the color of the bars for %s"]:format(L["Game Start"]),
						get = getcolor,
						set = setcolor,
						passValue = 'GAMESTART',
						disabled = getpvphidden,
						order = 301,
					},
				},
			},
		},
	}
end
