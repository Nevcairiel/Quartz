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

local WotLK = select(4, GetBuildInfo()) >= 30000

local media = LibStub("LibSharedMedia-3.0")
local L = AceLibrary("AceLocale-2.2"):new("Quartz")

local Quartz = Quartz
if Quartz:HasModule('Buff') then
	return
end
local QuartzBuff = Quartz:NewModule('Buff')
local self = QuartzBuff

local GetTime = GetTime
local table_sort = table.sort
local math_ceil = math.ceil

local db
local targetlocked = true
local focuslocked = true

local new, del = Quartz.new, Quartz.del
local OnUpdate
do
	local min = L["%dm"]
	local function timenum(num)
		if num <= 10 then
			return ('%.1f'):format(num)
		elseif num <= 60 then
			return ('%d'):format(num)
		else
			return min:format(math_ceil(num / 60))
		end
	end
	function OnUpdate(frame)
		local currentTime = GetTime()
		local endTime = frame.endTime
		if currentTime > endTime then
			self:UpdateBars()
		else
			local remaining = (currentTime - frame.startTime)
			frame:SetValue(endTime - remaining)
			frame.timetext:SetText(timenum(endTime - currentTime))
		end
		
	end
end
local function OnShow(frame)
	frame:SetScript('OnUpdate', OnUpdate)
end
local function OnHide(frame)
	frame:SetScript('OnUpdate', nil)
end

local framefactory = {
	__index = function(t,k)
		local bar = CreateFrame('StatusBar', nil, UIParent)
		t[k] = bar
		bar:SetFrameStrata('MEDIUM')
		bar:Hide()
		bar:SetScript('OnShow', OnShow)
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
}
local targetbars = setmetatable({}, framefactory)
local focusbars = setmetatable({}, framefactory)

function QuartzBuff:OnInitialize()
	db = Quartz:AcquireDBNamespace("Buff")
	Quartz:RegisterDefaults("Buff", "profile", {
		target = true,
		targetbuffs = true,
		targetdebuffs = true,
		targeticons = true,
		targeticonside = L["Right"],
		
		targetanchor = L["Player"],--L["Free"], L["Target"], L["Focus"]
		targetx = 500,
		targety = 350,
		targetgrowdirection = L["Up"], --L["Down"]
		targetposition = L["Top Right"],
		
		targetgap = 1,
		targetspacing = 1,
		targetoffset = 3,
		
		targetwidth = 120,
		targetheight = 12,
		
		focus = true,
		focusbuffs = true,
		focusdebuffs = true,
		focusicons = true,
		focusiconside = L["Left"],
		
		focusanchor = L["Player"],--L["Free"], L["Target"], L["Focus"]
		focusx = 400,
		focusy = 350,
		focusgrowdirection = L["Up"], --L["Down"]
		focusposition = L["Bottom Left"],
		
		focusgap = 1,
		focusspacing = 1,
		focusoffset = 3,
		
		focuswidth = 120,
		focusheight = 12,
		
		buffnametext = true,
		bufftimetext = true,
		
		bufftexture = 'LiteStep',
		bufffont = 'Friz Quadrata TT',
		bufffontsize = 9,
		buffalpha = 1,
		
		buffcolor = {0,0.49, 1},
		
		debuffsbytype = true,
		debuffcolor = {1.0, 0.7, 0},
		Poison = {0, 1, 0},
		Magic = {0, 0, 1},
		Disease = {.55, .15, 0},
		Curse = {1, 0, 1},
		
		bufftextcolor = {1,1,1},
		
		timesort = true,
	})
end
function QuartzBuff:OnEnable()
	self:RegisterBucketEvent("UNIT_AURA", 0.5)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateBars")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateBars")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			for i, v in pairs(targetbars) do
				v:SetStatusBarTexture(media:Fetch("statusbar", override))
			end
			for i, v in pairs(focusbars) do
				v:SetStatusBarTexture(media:Fetch("statusbar", override))
			end
		end
	end)
	Quartz.ApplySettings()
end
function QuartzBuff:OnDisable()
	targetbars[1].Hide = nil
	targetbars[1]:EnableMouse(false)
	targetbars[1]:SetScript('OnDragStart', nil)
	targetbars[1]:SetScript('OnDragStop', nil)
	for _, v in pairs(targetbars) do
		v:Hide()
	end
	focusbars[1].Hide = nil
	focusbars[1]:EnableMouse(false)
	focusbars[1]:SetScript('OnDragStart', nil)
	focusbars[1]:SetScript('OnDragStop', nil)
	for _, v in pairs(focusbars) do
		v:Hide()
	end
end
function QuartzBuff:UNIT_AURA(units)
	for unit in pairs(units) do
		if unit == 'target' then
			self:UpdateTargetBars()
		end
		if unit == 'focus' or UnitIsUnit('focus', unit) then
			self:UpdateFocusBars()
		end
	end
end
function QuartzBuff:CheckForUpdate()
	if targetbars[1]:IsShown() then
		self:UpdateTargetBars()
	end
	if focusbars[1]:IsShown() then
		self:UpdateFocusBars()
	end
end
function QuartzBuff:UpdateBars()
	self:UpdateTargetBars()
	self:UpdateFocusBars()
end
do
	local function sort(a,b)
		if db.profile.timesort then
			if a.isbuff == b.isbuff then
				return a.remaining < b.remaining
			else
				return a.isbuff
			end
		else
			if a.isbuff == b.isbuff then
				return a.name < b.name
			else
				return a.isbuff
			end
		end
	end
	local tmp = {}
	local called = false -- prevent recursive calls when new bars are created.
	function QuartzBuff:UpdateTargetBars()
		if called then
			return
		end
		called = true
		local db = db.profile
		if db.target then
			local currentTime = GetTime()
			for k in pairs(tmp) do
				tmp[k] = del(tmp[k])
			end
			if db.targetbuffs then
				for i = 1, 32 do
					local name, texture, applications, duration, remaining, _
					if WotLK then
						-- name, rank, icon, count, debuffType, duration, expirationTime, isMine, isStealable = UnitAura
						local expirationTime, isMine
						name, _, texture, applications, _, duration, expirationTime, isMine = UnitBuff('target', i)
						if not isMine then
							duration = nil
						end
						remaining = expirationTime and (expirationTime - GetTime()) or nil
					else
						name, _, texture, applications, duration, remaining = UnitBuff('target', i)
					end
					if not name then
						break
					end
					if duration and duration > 0 then
						local t = new()
						tmp[#tmp+1] = t
						t.name = name
						t.texture = texture
						t.duration = duration
						t.remaining = remaining
						t.isbuff = true
						t.applications = applications
					end
				end
			end
			if db.targetdebuffs then
				for i = 1, 40 do
					local name, _, texture, applications, dispeltype, duration, remaining
					if WotLK then
						local expirationTime, isMine
						name, _, texture, applications, dispeltype, duration, expirationTime, isMine = UnitDebuff('target', i)
						if not isMine then
							duration = nil
						end
						remaining =  expirationTime and (expirationTime - GetTime()) or nil
					else
						name, _, texture, applications, dispeltype, duration, remaining = UnitDebuff('target', i)
					end
					if not name then
						break
					end
					if duration and duration > 0 then
						local t = new()
						tmp[#tmp+1] = t
						t.name = name
						t.texture = texture
						t.duration = duration
						t.remaining = remaining
						t.dispeltype = dispeltype
						t.applications = applications
					end
				end
			end
			table_sort(tmp, sort)
			local maxindex = 0
			for k,v in ipairs(tmp) do
				maxindex = k
				local bar = targetbars[k]
				if v.applications > 1 then
					bar.text:SetText(('%s (%s)'):format(v.name, v.applications))
				else
					bar.text:SetText(v.name)
				end
				bar.icon:SetTexture(v.texture)
				local elapsed = (v.duration - v.remaining)
				local startTime, endTime = (currentTime - elapsed), (currentTime + v.remaining)
				bar.startTime = startTime
				bar.endTime = endTime
				bar:SetMinMaxValues(startTime, endTime)
				bar:Show()
				if v.isbuff then
					bar:SetStatusBarColor(unpack(db.buffcolor))
				else
					if db.debuffsbytype then
						local dispeltype = v.dispeltype
						if dispeltype then
							bar:SetStatusBarColor(unpack(db[dispeltype]))
						else
							bar:SetStatusBarColor(unpack(db.debuffcolor))
						end
					else
						bar:SetStatusBarColor(unpack(db.debuffcolor))
					end
				end
			end
			for i = maxindex+1, #targetbars do
				targetbars[i]:Hide()
			end
		else
			targetbars[1].Hide = nil
			targetbars[1]:EnableMouse(false)
			targetbars[1]:SetScript('OnDragStart', nil)
			targetbars[1]:SetScript('OnDragStop', nil)
			for _, v in ipairs(targetbars) do
				v:Hide()
			end
		end
		if targetbars[1]:IsShown() then
			if not self:IsEventScheduled('Quartz_Buff-AutoUpdate') then
				self:ScheduleRepeatingEvent('Quartz_Buff-AutoUpdate', self.CheckForUpdate, 3, self)
			end
		elseif not focusbars[1]:IsShown() then
			if self:IsEventScheduled('Quartz_Buff-AutoUpdate') then
				self:CancelScheduledEvent('Quartz_Buff-AutoUpdate')
			end
		end
		called = false
	end
	function QuartzBuff:UpdateFocusBars()
		if called then
			return
		end
		called = true
		local db = db.profile
		if db.focus then
			local currentTime = GetTime()
			for k in pairs(tmp) do
				tmp[k] = del(tmp[k])
			end
			if db.focusbuffs then
				for i = 1, 32 do
					local name, _, texture, applications, duration, remaining = UnitBuff('focus', i)
					if not name then
						break
					end
					if duration and duration > 0 then
						local t = new()
						tmp[#tmp+1] = t
						t.name = name
						t.texture = texture
						t.duration = duration
						t.remaining = remaining
						t.isbuff = true
						t.applications = applications
					end
				end
			end
			if db.focusdebuffs then
				for i = 1, 40 do
					local name, _, texture, applications, dispeltype, duration, remaining = UnitDebuff('focus', i)
					if not name then
						break
					end
					if duration and duration > 0 then
						local t = new()
						tmp[#tmp+1] = t
						t.name = name
						t.texture = texture
						t.duration = duration
						t.remaining = remaining
						t.dispeltype = dispeltype
						t.applications = applications
					end
				end
			end
			table_sort(tmp, sort)
			local maxindex = 0
			for k,v in ipairs(tmp) do
				maxindex = k
				local bar = focusbars[k]
				if v.applications > 1 then
					bar.text:SetText(('%s (%s)'):format(v.name, v.applications))
				else
					bar.text:SetText(v.name)
				end
				bar.icon:SetTexture(v.texture)
				local elapsed = (v.duration - v.remaining)
				local startTime, endTime = (currentTime - elapsed), (currentTime + v.remaining)
				bar.startTime = startTime
				bar.endTime = endTime
				bar:SetMinMaxValues(startTime, endTime)
				bar:Show()
				if v.isbuff then
					bar:SetStatusBarColor(unpack(db.buffcolor))
				else
					if db.debuffsbytype then
						local dispeltype = v.dispeltype
						if dispeltype then
							bar:SetStatusBarColor(unpack(db[dispeltype]))
						else
							bar:SetStatusBarColor(unpack(db.debuffcolor))
						end
					else
						bar:SetStatusBarColor(unpack(db.debuffcolor))
					end
				end
			end
			for i = maxindex+1, #focusbars do
				focusbars[i]:Hide()
			end
		else
			focusbars[1].Hide = nil
			focusbars[1]:EnableMouse(false)
			focusbars[1]:SetScript('OnDragStart', nil)
			focusbars[1]:SetScript('OnDragStop', nil)
			for _, v in ipairs(focusbars) do
				v:Hide()
			end
		end
		if focusbars[1]:IsShown() then
			if not self:IsEventScheduled('Quartz_Buff-AutoUpdate') then
				self:ScheduleRepeatingEvent('Quartz_Buff-AutoUpdate', self.CheckForUpdate, 3, self)
			end
		elseif not targetbars[1]:IsShown() then
			if self:IsEventScheduled('Quartz_Buff-AutoUpdate') then
				self:CancelScheduledEvent('Quartz_Buff-AutoUpdate')
			end
		end
		called = false
	end
end
do
	local function apply(unit, i, bar, db, direction)
		local bars, position, icons, iconside, gap, spacing, offset, anchor, x, y, grow, height, width
		local qpdb = Quartz:AcquireDBNamespace("Player").profile
		if unit == 'target' then
			bars = targetbars
			position = db.targetposition
			icons = db.targeticons
			iconside = db.targeticonside
			gap = db.targetgap
			spacing = db.targetspacing
			offset = db.targetoffset
			anchor = db.targetanchor
			x = db.targetx
			y = db.targety
			grow = db.targetgrowdirection
			width = db.targetwidth
			height = db.targetheight
		else
			bars = focusbars
			position = db.focusposition
			icons = db.focusicons
			iconside = db.focusiconside
			gap = db.focusgap
			spacing = db.focusspacing
			offset = db.focusoffset
			anchor = db.focusanchor
			x = db.focusx
			y = db.focusy
			grow = db.focusgrowdirection
			width = db.focuswidth
			height = db.focusheight
		end
		bar:ClearAllPoints()
		bar:SetStatusBarTexture(media:Fetch('statusbar', db.bufftexture))
		bar:SetWidth(width)
		bar:SetHeight(height)
		bar:SetScale(qpdb.scale)
		bar:SetAlpha(db.buffalpha)
		
		if anchor == L["Free"] then
			if i == 1 then
				bar:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', x, y)
				if grow == L["Up"] then
					direction = 1
				else --L["Down"]
					direction = -1
				end
			else
				if direction == 1 then
					bar:SetPoint('BOTTOMRIGHT', bars[i-1], 'TOPRIGHT', 0, spacing)
				else -- -1
					bar:SetPoint('TOPRIGHT', bars[i-1], 'BOTTOMRIGHT', 0, -1 * spacing)
				end
			end
		else
			if i == 1 then
				local anchorframe
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
						offset = offset + height
					end
					if qpdb.iconposition == L["Left"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = 1
					bar:SetPoint('BOTTOMRIGHT', anchorframe, 'BOTTOMLEFT', -1 * offset, gap)
				elseif position == L["Left (grow down)"] then
					if iconside == L["Right"] and showicons then
						offset = offset + height
					end
					if qpdb.iconposition == L["Left"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = -1
					bar:SetPoint('TOPRIGHT', anchorframe, 'TOPLEFT', -3 * offset, -1 * gap)
				elseif position == L["Right (grow up)"] then
					if iconside == L["Left"] and showicons then
						offset = offset + height
					end
					if qpdb.iconposition == L["Right"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = 1
					bar:SetPoint('BOTTOMLEFT', anchorframe, 'BOTTOMRIGHT', offset, gap)
				elseif position == L["Right (grow down)"] then
					if iconside == L["Left"] and showicons then
						offset = offset + height
					end
					if qpdb.iconposition == L["Right"] and not qpdb.hideicon then
						offset = offset + qpdb.h
					end
					direction = -1
					bar:SetPoint('TOPLEFT', anchorframe, 'TOPRIGHT', offset, -1 * gap)
				end
			else
				if direction == 1 then
					bar:SetPoint('BOTTOMRIGHT', bars[i-1], 'TOPRIGHT', 0, spacing)
				else -- -1
					bar:SetPoint('TOPRIGHT', bars[i-1], 'BOTTOMRIGHT', 0, -1 * spacing)
				end
			end
		end
		
		local timetext = bar.timetext
		if db.bufftimetext then
			timetext:Show()
			timetext:ClearAllPoints()
			timetext:SetWidth(width)
			timetext:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
			timetext:SetJustifyH("RIGHT")
		else
			timetext:Hide()
		end
		timetext:SetFont(media:Fetch('font', db.bufffont), db.bufffontsize)
		timetext:SetShadowColor( 0, 0, 0, 1)
		timetext:SetShadowOffset( 0.8, -0.8 )
		timetext:SetTextColor(unpack(db.bufftextcolor))
		timetext:SetNonSpaceWrap(false)
		timetext:SetHeight(height)
		
		local temptext = timetext:GetText()
		timetext:SetText('10.0')
		local normaltimewidth = timetext:GetStringWidth()
		timetext:SetText(temptext)
		
		local text = bar.text
		if db.buffnametext then
			text:Show()
			text:ClearAllPoints()
			text:SetPoint("LEFT", bar, "LEFT", 2, 0)
			text:SetJustifyH("LEFT")
			if db.bufftimetext then
				text:SetWidth(width - normaltimewidth)
			else
				text:SetWidth(width)
			end
		else
			text:Hide()
		end
		text:SetFont(media:Fetch('font', db.bufffont), db.bufffontsize)
		text:SetShadowColor( 0, 0, 0, 1)
		text:SetShadowOffset( 0.8, -0.8 )
		text:SetTextColor(unpack(db.bufftextcolor))
		text:SetNonSpaceWrap(false)
		text:SetHeight(height)
		
		local icon = bar.icon
		if icons then
			icon:Show()
			icon:SetWidth(height-1)
			icon:SetHeight(height-1)
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
	function QuartzBuff:ApplySettings()
		if Quartz:IsModuleActive('Buff') and db then
			local db = db.profile
			local direction
			if db.targetanchor ~= L["Free"] then
				targetbars[1].Hide = nil
				targetbars[1]:EnableMouse(false)
				targetbars[1]:SetScript('OnDragStart', nil)
				targetbars[1]:SetScript('OnDragStop', nil)
			end
			if db.focusanchor ~= L["Free"] then
				focusbars[1].Hide = nil
				focusbars[1]:EnableMouse(false)
				focusbars[1]:SetScript('OnDragStart', nil)
				focusbars[1]:SetScript('OnDragStop', nil)
			end
			for i, v in pairs(targetbars) do
				direction = apply('target', i, v, db, direction)
			end
			direction = nil
			for i, v in pairs(focusbars) do
				direction = apply('focus', i, v, db, direction)
			end
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
	local function hidefocusoptions()	
		return not db.profile.focus
	end
	local function hidetargetoptions()
		return not db.profile.target
	end
	local function hidedebuffsbytype()
		return not db.profile.debuffsbytype
	end
	local function hidedebuffsnottype()
		return db.profile.debuffsbytype
	end
	local function gettargetfreeoptionshidden()
		return db.profile.targetanchor ~= L["Free"] or not db.profile.target
	end
	local function gettargetnotfreeoptionshidden()
		return db.profile.targetanchor == L["Free"] or not db.profile.target
	end
	local function targetdragstart()
		targetbars[1]:StartMoving()
	end
	local function targetdragstop()
		db.profile.targetx = targetbars[1]:GetLeft()
		db.profile.targety = targetbars[1]:GetBottom()
		targetbars[1]:StopMovingOrSizing()
	end
	local function targetnothing()
		targetbars[1]:SetAlpha(db.profile.buffalpha)
	end
	local function getfocusfreeoptionshidden()
		return db.profile.focusanchor ~= L["Free"] or not db.profile.focus
	end
	local function getfocusnotfreeoptionshidden()
		return db.profile.focusanchor == L["Free"] or not db.profile.focus
	end
	local function focusdragstart()
		focusbars[1]:StartMoving()
	end
	local function focusdragstop()
		db.profile.focusx = focusbars[1]:GetLeft()
		db.profile.focusy = focusbars[1]:GetBottom()
		focusbars[1]:StopMovingOrSizing()
	end
	local function focusnothing()
		focusbars[1]:SetAlpha(db.profile.buffalpha)
	end
	Quartz.options.args.Buff = {
		type = 'group',
		name = L["Buff"],
		desc = L["Buff"],
		order = 600,
		args = {
			toggle = {
				type = 'toggle',
				name = L["Enable"],
				desc = L["Enable"],
				get = function()
					return Quartz:IsModuleActive('Buff')
				end,
				set = function(v)
					Quartz:ToggleModuleActive('Buff', v)
				end,
				order = 100,
			},
			focus = {
				type = 'group',
				name = L["Focus"],
				desc = L["Focus"],
				order = 101,
				args = {
					show = {
						type = 'toggle',
						name = L["Enable %s"]:format(L["Focus"]),
						desc = L["Show buffs/debuffs for your %s"]:format(L["Focus"]),
						get = get,
						set = set,
						passValue = 'focus',
						order = 99,
					},
					buffs = {
						type = 'toggle',
						name = L["Enable Buffs"],
						desc = L["Show buffs for your %s"]:format(L["Focus"]),
						get = get,
						set = set,
						passValue = 'focusbuffs',
						hidden = hidefocusoptions,
					},
					debuffs = {
						type = 'toggle',
						name = L["Enable Debuffs"],
						desc = L["Show debuffs for your %s"]:format(L["Focus"]),
						get = get,
						set = set,
						passValue = 'focusdebuffs',
						hidden = hidefocusoptions,
					},
					buffwidth = {
						type = 'range',
						name = L["Buff Bar Width"],
						desc = L["Set the width of the buff bars"],
						min = 50,
						max = 300,
						step = 1,
						get = get,
						set = set,
						passValue = 'focuswidth',
						order = 101,
					},
					buffheight = {
						type = 'range',
						name = L["Buff Bar Height"],
						desc = L["Set the height of the buff bars"],
						min = 4,
						max = 25,
						step = 1,
						get = get,
						set = set,
						passValue = 'focusheight',
						order = 101,
					},
					focusanchor = {
						type = 'text',
						name = L["Anchor Frame"],
						desc = L["Select where to anchor the %s bars"]:format(L["Focus"]),
						get = get,
						set = set,
						validate = {L["Player"], L["Free"], L["Target"], L["Focus"]},
						hidden = hidefocusoptions,
						passValue = 'focusanchor',
						order = 102,
					},
					-- free
					focuslock = {
						type = 'toggle',
						name = L["Lock"],
						desc = L["Toggle %s bar lock"]:format(L["Focus"]),
						get = function()
							return focuslocked
						end,
						set = function(v)
							local bar = focusbars[1]
							if v then
								bar.Hide = nil
								bar:EnableMouse(false)
								bar:SetScript('OnDragStart', nil)
								bar:SetScript('OnDragStop', nil)
								self:UpdateBars()
							else
								bar:Show()
								bar:EnableMouse(true)
								bar:SetScript('OnDragStart', focusdragstart)
								bar:SetScript('OnDragStop', focusdragstop)
								bar:SetAlpha(1)
								bar.endTime = bar.endTime or 0
								bar.Hide = focusnothing
							end
							focuslocked = v
						end,
						hidden = getfocusfreeoptionshidden,
						order = 103,
					},
					x = {
						type = 'text',
						name = L["X"],
						desc = L["Set an exact X value for this bar's position."],
						get = get,
						set = set,
						hidden = getfocusfreeoptionshidden,
						passValue = 'focusx',
						order = 104,
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
						hidden = getfocusfreeoptionshidden,
						passValue = 'focusy',
						order = 104,
						validate = function(v)
							return tonumber(v) and true
						end,
						usage = L["Number"],
					},
					focusgrowdirection = {
						type = 'text',
						name = L["Grow Direction"],
						desc = L["Set the grow direction of the %s bars"]:format(L["Focus"]),
						get = get,
						set = set,
						validate = {L["Up"], L["Down"]},
						passValue = 'focusgrowdirection',
						hidden = getfocusfreeoptionshidden,
						order = 105,
					},
					-- anchored to a cast bar
					position = {
						type = 'text',
						name = L["Position"],
						desc = L["Position the bars for your %s"]:format(L["Focus"]),
						get = get,
						set = set,
						validate = positions,
						passValue = 'focusposition',
						hidden = getfocusnotfreeoptionshidden,
						order = 103,
					},
					gap = {
						type = 'range',
						name = L["Gap"],
						desc = L["Tweak the vertical position of the bars for your %s"]:format(L["Focus"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'focusgap',
						order = 101,
						hidden = getfocusnotfreeoptionshidden,
						order = 104,
					},
					offset = {
						type = 'range',
						name = L["Offset"],
						desc = L["Tweak the horizontal position of the bars for your %s"]:format(L["Focus"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'focusoffset',
						hidden = getfocusnotfreeoptionshidden,
						order = 106,
					},
					spacing = {
						type = 'range',
						name = L["Spacing"],
						desc = L["Tweak the space between bars for your %s"]:format(L["Focus"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'focusspacing',
						order = 107,
						hidden = hidefocusoptions,
					},
					showicons = {
						type = 'toggle',
						name = L["Show Icons"],
						desc = L["Show icons on buffs and debuffs for your %s"]:format(L["Focus"]),
						get = get,
						set = set,
						passValue = 'focusicons',
						order = 108,
						hidden = hidefocusoptions,
					},
					iconside = {
						type = 'text',
						name = L["Icon Position"],
						desc = L["Set the side of the buff bar that the icon appears on"],
						get = get,
						set = set,
						validate = {L["Left"], L["Right"]},
						passValue = 'focusiconside',
						order = 109,
						hidden = hidefocusoptions,
					},
				},
			},
			target = {
				type = 'group',
				name = L["Target"],
				desc = L["Target"],
				order = 102,
				args = {
					show = {
						type = 'toggle',
						name = L["Enable %s"]:format(L["Target"]),
						desc = L["Show buffs/debuffs for your %s"]:format(L["Target"]),
						get = get,
						set = set,
						passValue = 'target',
						order = 99,
					},
					buffs = {
						type = 'toggle',
						name = L["Enable Buffs"],
						desc = L["Show buffs for your %s"]:format(L["Target"]),
						get = get,
						set = set,
						passValue = 'targetbuffs',
						hidden = hidetargetoptions,
					},
					debuffs = {
						type = 'toggle',
						name = L["Enable Debuffs"],
						desc = L["Show debuffs for your %s"]:format(L["Target"]),
						get = get,
						set = set,
						passValue = 'targetdebuffs',
						hidden = hidetargetoptions,
					},
					buffwidth = {
						type = 'range',
						name = L["Buff Bar Width"],
						desc = L["Set the width of the buff bars"],
						min = 50,
						max = 300,
						step = 1,
						get = get,
						set = set,
						passValue = 'targetwidth',
						order = 101,
					},
					buffheight = {
						type = 'range',
						name = L["Buff Bar Height"],
						desc = L["Set the height of the buff bars"],
						min = 4,
						max = 25,
						step = 1,
						get = get,
						set = set,
						passValue = 'targetheight',
						order = 101,
					},
					targetanchor = {
						type = 'text',
						name = L["Anchor Frame"],
						desc = L["Select where to anchor the %s bars"]:format(L["Target"]),
						get = get,
						set = set,
						validate = {L["Player"], L["Free"], L["Target"], L["Focus"]},
						hidden = hidetargetoptions,
						passValue = 'targetanchor',
						order = 102,
					},
					-- free
					targetlock = {
						type = 'toggle',
						name = L["Lock"],
						desc = L["Toggle %s bar lock"]:format(L["Target"]),
						get = function()
							return targetlocked
						end,
						set = function(v)
							local bar = targetbars[1]
							if v then
								bar.Hide = nil
								bar:EnableMouse(false)
								bar:SetScript('OnDragStart', nil)
								bar:SetScript('OnDragStop', nil)
								self:UpdateBars()
							else
								bar:Show()
								bar:EnableMouse(true)
								bar:SetScript('OnDragStart', targetdragstart)
								bar:SetScript('OnDragStop', targetdragstop)
								bar:SetAlpha(1)
								bar.endTime = bar.endTime or 0
								bar.Hide = targetnothing
							end
							targetlocked = v
						end,
						hidden = gettargetfreeoptionshidden,
						order = 103,
					},
					x = {
						type = 'text',
						name = L["X"],
						desc = L["Set an exact X value for this bar's position."],
						get = get,
						set = set,
						hidden = gettargetfreeoptionshidden,
						passValue = 'targetx',
						order = 104,
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
						hidden = gettargetfreeoptionshidden,
						passValue = 'targety',
						order = 104,
						validate = function(v)
							return tonumber(v) and true
						end,
						usage = L["Number"],
					},
					targetgrowdirection = {
						type = 'text',
						name = L["Grow Direction"],
						desc = L["Set the grow direction of the %s bars"]:format(L["Target"]),
						get = get,
						set = set,
						validate = {L["Up"], L["Down"]},
						passValue = 'targetgrowdirection',
						hidden =  gettargetfreeoptionshidden,
						order = 105,
					},
					-- anchored to a cast bar
					position = {
						type = 'text',
						name = L["Position"],
						desc = L["Position the bars for your %s"]:format(L["Target"]),
						get = get,
						set = set,
						validate = positions,
						passValue = 'targetposition',
						hidden = gettargetnotfreeoptionshidden,
						order = 103,
					},
					gap = {
						type = 'range',
						name = L["Gap"],
						desc = L["Tweak the vertical position of the bars for your %s"]:format(L["Target"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'targetgap',
						order = 101,
						hidden = gettargetnotfreeoptionshidden,
						order = 104,
					},
					offset = {
						type = 'range',
						name = L["Offset"],
						desc = L["Tweak the horizontal position of the bars for your %s"]:format(L["Target"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'targetoffset',
						hidden = gettargetnotfreeoptionshidden,
						order = 106,
					},
					spacing = {
						type = 'range',
						name = L["Spacing"],
						desc = L["Tweak the space between bars for your %s"]:format(L["Target"]),
						min = -35,
						max = 35,
						step = 1,
						get = get,
						set = set,
						passValue = 'targetspacing',
						order = 107,
						hidden = hidetargetoptions,
					},
					showicons = {
						type = 'toggle',
						name = L["Show Icons"],
						desc = L["Show icons on buffs and debuffs for your %s"]:format(L["Target"]),
						get = get,
						set = set,
						passValue = 'targeticons',
						order = 108,
						hidden = hidetargetoptions,
					},
					iconside = {
						type = 'text',
						name = L["Icon Position"],
						desc = L["Set the side of the buff bar that the icon appears on"],
						get = get,
						set = set,
						validate = {L["Left"], L["Right"]},
						passValue = 'targeticonside',
						order = 109,
						hidden = hidetargetoptions,
					},
				},
			},
			timesort = {
				type = 'toggle',
				name = L["Sort by Remaining Time"],
				desc = L["Sort the buffs and debuffs by time remaining.  If unchecked, they will be sorted alphabetically."],
				get = get,
				set = set,
				order = 103,
				passValue = 'timesort',
			},
			bufftexture = {
				type = 'text',
				name = L["Texture"],
				desc = L["Set the buff bar Texture"],
				validate = media:List('statusbar'),
				order = 103,
				get = get,
				set = set,
				passValue = 'bufftexture',
			},
			buffnametext = {
				type = 'toggle',
				name = L["Buff Name Text"],
				desc = L["Display the names of buffs/debuffs on their bars"],
				get = get,
				set = set,
				passValue = 'buffnametext',
				order = 106,
			},
			bufftimetext = {
				type = 'toggle',
				name = L["Buff Time Text"],
				desc = L["Display the time remaining on buffs/debuffs on their bars"],
				get = get,
				set = set,
				passValue = 'bufftimetext',
				order = 107,
			},
			bufffont = {
				type = 'text',
				name = L["Font"],
				desc = L["Set the font used in the buff bars"],
				validate = media:List('font'),
				get = get,
				set = set,
				passValue = 'bufffont',
				order = 108,
			},
			bufftextcolor = {
				type = 'color',
				name = L["Text Color"],
				desc = L["Set the color of the text for the buff bars"],
				get = getcolor,
				set = setcolor,
				passValue = 'bufftextcolor',
				order = 109,
			},
			bufffontsize = {
				type = 'range',
				name = L["Font Size"],
				desc = L["Set the font size for the buff bars"],
				min = 3,
				max = 15,
				step = 1,
				get = get,
				set = set,
				passValue = 'bufffontsize',
				order = 110,
			},
			buffalpha = {
				type = 'range',
				name = L["Alpha"],
				desc = L["Set the alpha of the buff bars"],
				min = 0.05,
				max = 1,
				step = 0.05,
				isPercent = true,
				get = get,
				set = set,
				passValue = 'buffalpha',
				order = 111,
			},
			colors = {
				type = 'group',
				name = L["Colors"],
				desc = L["Colors"],
				order = -1,
				args = {
					buffcolor = {
						type = 'color',
						name = L["Buff Color"],
						desc = L["Set the color of the bars for buffs"],
						get = getcolor,
						set = setcolor,
						passValue = 'buffcolor',
					},
					debuffsbytype = {
						type = 'toggle',
						name = L["Debuffs by Type"],
						desc = L["Color debuff bars according to their dispel type"],
						get = get,
						set = set,
						passValue = 'debuffsbytype',
						order = 101,
					},
					debuffcolor = {
						type = 'color',
						name = L["Debuff Color"],
						desc = L["Set the color of the bars for debuffs"],
						get = getcolor,
						set = setcolor,
						passValue = 'debuffcolor',
						hidden = hidedebuffsnottype,
						order = 102,
					},
					physcolor = {
						type = 'color',
						name = L["Undispellable Color"],
						desc = L["Set the color of the bars for undispellable debuffs"],
						get = getcolor,
						set = setcolor,
						passValue = 'debuffcolor',
						hidden = hidedebuffsbytype,
						order = 102,
					},
					cursecolor = {
						type = 'color',
						name = L["Curse Color"],
						desc = L["Set the color of the bars for curses"],
						get = getcolor,
						set = setcolor,
						passValue = 'Curse',
						hidden = hidedebuffsbytype,
						order = 103,
					},
					diseasecolor = {
						type = 'color',
						name = L["Disease Color"],
						desc = L["Set the color of the bars for diseases"],
						get = getcolor,
						set = setcolor,
						passValue = 'Disease',
						hidden = hidedebuffsbytype,
						order = 104,
					},
					magiccolor = {
						type = 'color',
						name = L["Magic Color"],
						desc = L["Set the color of the bars for magic"],
						get = getcolor,
						set = setcolor,
						passValue = 'Magic',
						hidden = hidedebuffsbytype,
						order = 105,
					},
					poisoncolor = {
						type = 'color',
						name = L["Poison Color"],
						desc = L["Set the color of the bars for poisons"],
						get = getcolor,
						set = setcolor,
						passValue = 'Poison',
						hidden = hidedebuffsbytype,
						order = 106,
					},
				},
			},
		},
	}
end