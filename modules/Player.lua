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

local MODNAME = "Player"
local Player = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceHook-3.0")

local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo

local WoWRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local WoWClassicEra = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local WoWBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local WoWWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
local WoWCata = (WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC)
local WoWMists = (WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)

local GetSpellName = C_Spell and C_Spell.GetSpellName or GetSpellInfo

----------------------------
-- Upvalues
-- GLOBALS: CastingBarFrame
local unpack = unpack


local db, getOptions, castBar

local defaults = {
	profile = Quartz3:Merge(Quartz3.CastBarTemplate.defaults,
	{
		hideblizz = true,
		showticks = true,
		-- no interrupt is pointless for player, disable all options
		noInterruptBorderChange = false,
		noInterruptColorChange = false,
		noInterruptShield = false,
		targetnamestyle = "default"
	})
}

do
	local function setOpt(info, value)
		db[info[#info]] = value
		Player:ApplySettings()
	end

	local options
	function getOptions()
		if not options then
			options = Player.Bar:CreateOptions()
			options.args.hideblizz = {
				type = "toggle",
				name = L["Disable Blizzard Cast Bar"],
				desc = L["Disable and hide the default UI's casting bar"],
				set = setOpt,
				order = 101,
			}
			options.args.showticks = {
				type = "toggle",
				name = L["Show channeling ticks"],
				desc = L["Show damage / mana ticks while channeling spells like Drain Life or Blizzard"],
				order = 102,
			}
			options.args.nlttargetname = {
				type = "description",
				name = "",
				order = 408.0,
			}
			options.args.targetname = {
				type = "toggle",
				name = L["Show Target Name"],
				desc = L["Display target name of spellcasts after spell name"],
				disabled = function() return db.hidenametext end,
				order = 408.1,
			}
			options.args.targetnamestyle = {
				type = "select",
				name = L["Target Name Style"],
				desc = L["How to display target name of spellcasts after spell name"],
				values = {["default"] = L["Spell -> Target"], ["on"] = L["Spell on Target"]},
				disabled = function() return not db.targetname or db.hidenametext end,
				order = 409,
			}
			options.args.noInterruptGroup = nil
		end
		return options
	end
end

local function OnUpdate(self)
	if self.casting and self.chargeSpell then
		Player:UpdateStage(self)
	end
end

function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	self.Bar = Quartz3.CastBarTemplate:new(self, "player", MODNAME, L["Player"], db)
	castBar = self.Bar.Bar

	self:Hook(self.Bar, "OnUpdate", OnUpdate)
	self.Bar:SetScript("OnUpdate", self.Bar.OnUpdate)
end


function Player:OnEnable()
	if WoWRetail then
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "UpdateChannelingTicks")
		self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateChannelingTicks")
	end

	self.Bar:RegisterEvents()
	self:ApplySettings()

	self:UpdateChannelingTicks()
end

function Player:OnDisable()
	self.Bar:UnregisterEvents()
	self.Bar:Hide()
end

function Player:ApplySettings()
	db = self.db.profile

	-- obey the hideblizz setting no matter if disabled or not
	if PlayerCastingBarFrame then
		if db.hideblizz then
			PlayerCastingBarFrame.RegisterEvent = function() end
			PlayerCastingBarFrame:UnregisterAllEvents()
			PlayerCastingBarFrame:Hide()
		else
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
			PlayerCastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
			PlayerCastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		end
	else
		if db.hideblizz then
			CastingBarFrame.RegisterEvent = function() end
			CastingBarFrame:UnregisterAllEvents()
			CastingBarFrame:Hide()
		else
			CastingBarFrame.RegisterEvent = nil
			CastingBarFrame:UnregisterAllEvents()
			CastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
			CastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
			CastingBarFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
			if WoWRetail then
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
				CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
			end
			CastingBarFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		end
	end

	self.Bar:SetConfig(db)
	if self:IsEnabled() then
		self.Bar:ApplySettings()
	end
end

function Player:Unlock()
	self.Bar:Unlock()
end

function Player:Lock()
	self.Bar:Lock()
end

----------------------------
-- Cast Bar Hooks

function Player:OnHide()
	local Latency = Quartz3:GetModule("Latency", true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
	end
end

local sparkfactory = {
	__index = function(t,k)
		local spark = castBar:CreateTexture(nil, 'OVERLAY')
		t[k] = spark
		spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		spark:SetBlendMode('ADD')
		spark:SetWidth(20)
		spark:SetHeight(db.h*2.2)
		return spark
	end
}
local barticks = setmetatable({}, sparkfactory)

local function setBarTicks(ticknum, duration, ticks)
	if( ticknum and ticknum > 0) then
		local width = castBar:GetWidth()
		for k = 1, ticknum do
			local t = barticks[k]
			t:ClearAllPoints()
			local x = ticks[k] / duration
			t:SetPoint("CENTER", castBar, "RIGHT", -width * x, 0 )
			t:Show()
		end
		for k = ticknum+1,#barticks do
			barticks[k]:Hide()
		end
	else
		barticks[1].Hide = nil
		for i=1,#barticks do
			barticks[i]:Hide()
		end
	end
end

local channelingTicks = WoWWrath and {
	--- Wrath
	-- druid
	[GetSpellName(740)] = 4, -- tranquility
	[GetSpellName(16914)] = 10, -- hurricane
	-- hunter
	[GetSpellName(1510)] = 6, -- volley
	-- mage
	[GetSpellName(10)] = 8, -- blizzard
	[5143] = 3, -- arcane missiles r1
	[5144] = 4, -- arcane missiles r2
	[GetSpellName(5145)] = 5, -- arcane missiles
	-- priest
	[GetSpellName(15407)] = 3, -- mind flay
	[GetSpellName(48045)] = 5, -- mind sear
	[GetSpellName(47540)] = 2, -- penance
	[GetSpellName(64843)] = 4, -- divine hymn
	[GetSpellName(64901)] = 4, -- hymn of hope
	-- warlock
	[GetSpellName(1949)] = 15, -- hellfire
	[GetSpellName(5740)] = 4, -- rain of fire
	[GetSpellName(5138)] = 5, -- drain mana
	[GetSpellName(689)] = 5, -- drain life
	[GetSpellName(1120)] = 5, -- drain soul
	[GetSpellName(755)] = 10, -- health funnel
} or WoWMists and {
	--- Mists
	-- deathknight
	[GetSpellName(42650)] = 8, -- army of the dead
	-- druid
	[GetSpellName(740)] = 4, -- tranquility
	[GetSpellName(16914)] = 10, -- hurricane
	[GetSpellName(127663)] = 10, -- astral communion
	[GetSpellName(106996)] = 10, -- astral storm
	--hunter
	[GetSpellName(120360)] = 15, -- barrage
	-- mage
	[GetSpellName(10)] = 8, -- blizzard
	[GetSpellName(5143)] = 5, -- arcane missiles
	[GetSpellName(12051)] = 3, -- evocation
	-- monk
	[GetSpellName(101546)] = 3, -- spinning crane kick
	[GetSpellName(113656)] = 4, -- fists of fury
	[GetSpellName(115175)] = 8, -- soothing mist
	[GetSpellName(115294)] = 6, -- mana tea
	[GetSpellName(117952)] = 6, -- crackling jade lightning
	-- priest
	[GetSpellName(15407)] = 3, -- mind flay
	[GetSpellName(129197)] = 3, -- mind flay insanity
	[GetSpellName(48045)] = 5, -- mind sear
	[GetSpellName(47540)] = 2, -- penance
	[GetSpellName(64843)] = 4, -- divine hymn
	[GetSpellName(64901)] = 4, -- hymn of hope
	-- warlock
	[GetSpellName(1949)] = 14, -- hellfire
	[GetSpellName(5740)] = 6, -- rain of fire
	[GetSpellName(689)] = 6, -- drain life
	[GetSpellName(1120)] = 6, -- drain soul
	[GetSpellName(755)] = 6, -- health funnel
	[GetSpellName(103103)] = 4, -- malefic grasp
} or WoWCata and {
	--- Wrath
	-- druid
	[GetSpellName(740)] = 4, -- tranquility
	[GetSpellName(16914)] = 10, -- hurricane
	-- mage
	[GetSpellName(10)] = 8, -- blizzard
	[GetSpellName(5143)] = 5, -- arcane missiles
	-- priest
	[GetSpellName(15407)] = 3, -- mind flay
	[GetSpellName(48045)] = 5, -- mind sear
	[GetSpellName(47540)] = 2, -- penance
	[GetSpellName(64843)] = 4, -- divine hymn
	[GetSpellName(64901)] = 4, -- hymn of hope
	-- warlock
	[GetSpellName(1949)] = 15, -- hellfire
	[GetSpellName(5740)] = 4, -- rain of fire
	[GetSpellName(689)] = 5, -- drain life
	[GetSpellName(1120)] = 5, -- drain soul
	[GetSpellName(755)] = 10, -- health funnel
} or WoWBC and {
	--- BCC
	-- druid
	[GetSpellName(740)] = 4, -- tranquility
	[GetSpellName(16914)] = 10, -- hurricane
	-- hunter
	[GetSpellName(1510)] = 6, -- volley
	-- mage
	[GetSpellName(10)] = 8, -- blizzard
	[5143] = 3, -- arcane missiles r1
	[5144] = 4, -- arcane missiles r2
	[GetSpellName(5145)] = 5, -- arcane missiles
	-- priest
	[GetSpellName(15407)] = 3, -- mind flay
	[GetSpellName(10797)] = 5, -- star shards
	-- warlock
	[GetSpellName(1949)] = 15, -- hellfire
	[GetSpellName(5740)] = 4, -- rain of fire
	[GetSpellName(5138)] = 5, -- drain mana
	[GetSpellName(689)] = 5, -- drain life
	[GetSpellName(1120)] = 5, -- drain soul
	[GetSpellName(755)] = 10, -- health funnel
} or WoWClassicEra and {
	-- druid
	[GetSpellName(740)] = 5, -- tranquility
	[GetSpellName(16914)] = 10, -- hurricane
	-- hunter
	[GetSpellName(136)] = 5, -- mend pet
	[GetSpellName(1510)] = 6, -- volley
	-- mage
	[GetSpellName(10)] = 8, -- blizzard
	[GetSpellName(5143)] = 3, -- arcane missiles
	-- priest
	[GetSpellName(15407)] = 3, -- mind flay
	[GetSpellName(10797)] = 6, -- star shards
	-- warlock
	[GetSpellName(1949)] = 15, -- hellfire
	[GetSpellName(5740)] = 4, -- rain of fire
	[GetSpellName(5138)] = 5, -- drain mana
	[GetSpellName(689)] = 5, -- drain life
	[GetSpellName(1120)] = 5, -- drain soul
	[GetSpellName(755)] = 10, -- health funnel
} or WoWRetail and {
	--- Retail
	-- warlock
	[GetSpellName(234153)] = 5, -- drain life
	[GetSpellName(198590)] = 5, -- drain soul
	[GetSpellName(217979)] = 5, -- health funnel
	[GetSpellName(196447)] = 15, -- channel demonfire
	[GetSpellName(417537)] = 3, -- oblivion
	-- druid
	[GetSpellName(740)] = 4, -- tranquility
	[GetSpellName(391528)] = 16, -- convoke the spirits
	-- priest
	[GetSpellName(64843)] = 4, -- divine hymn
	[GetSpellName(15407)] = 6, -- mind flay
	[GetSpellName(391403)] = 4, -- mind flay: insanity
	[GetSpellName(47540)] = 3, -- penance
	[GetSpellName(64901)] = 5, -- symbol of hope
	[GetSpellName(263165)] = 3, -- void torrent
	[GetSpellName(400169)] = 3, -- dark reprimand
	-- mage
	[GetSpellName(5143)] = 5, -- arcane missiles
	[GetSpellName(205021)] = 5, -- ray of frost
	[GetSpellName(12051)] = 6, -- evocation
	[GetSpellName(198100)] = 8, -- kleptomania
	[GetSpellName(382440)] = 4, -- shifting power
	-- monk
	[GetSpellName(117952)] = 4, -- crackling jade lightning
	[GetSpellName(115175)] = 8, -- soothing mist
	[GetSpellName(443028)] = 4, -- celestial conduit
	-- evoker
	[GetSpellName(356995)] = 3, -- disintegrate
	[GetSpellName(370960)] = 5, -- emerald communion
	-- demon hunter
	[GetSpellName(212084)] = 10, -- fel devastation
	[GetSpellName(452486)] = 10, -- fel desolation
} or {}


local function getChannelingTicks(spell, spellid)
	if not db.showticks then
		return 0
	end
	return channelingTicks[spellid] or channelingTicks[spell] or 0
end

local function isTalentKnown(talentID)
	return (select(4, GetTalentInfoByID(19752, GetActiveSpecGroup())))
end

function Player:UpdateChannelingTicks()
	local playerClass = select(2, UnitClass("player"))
	if WoWRetail then
		if playerClass == "PRIEST" then
			-- Castigation talent adds a tick to penance
			channelingTicks[GetSpellName(47540)] = IsPlayerSpell(193134) and 4 or 3
		elseif playerClass == "MAGE" then
			-- Amplification talent adds 3 ticks to Arcane Missiles
			channelingTicks[GetSpellName(5143)] = IsPlayerSpell(236628) and 8 or 5
		elseif playerClass == "DRUID" then
			-- Several talents remove 4 ticks from Convoke
			channelingTicks[GetSpellName(391528)] = (IsPlayerSpell(391548) or IsPlayerSpell(393991) or IsPlayerSpell(393414) or IsPlayerSpell(393371)) and 12 or 16
		elseif playerClass == "EVOKER" then
			-- Azure Celerity adds a tick to Disintegrate
			channelingTicks[GetSpellName(356995)] = IsPlayerSpell(1219723) and 4 or 3
		end
	end
end

function Player:UNIT_SPELLCAST_START(bar, unit)
	if bar.channeling then
		local spell, _, _, _, _, _, _, spellid = UnitChannelInfo(unit)
		bar.channelingEnd = bar.endTime
		bar.channelingDuration = bar.endTime - bar.startTime
		bar.channelingTicks = getChannelingTicks(spell, spellid)
		bar.channelingTickTime = bar.channelingTicks > 0 and (bar.channelingDuration / bar.channelingTicks) or 0
		bar.ticks = bar.ticks or {}
		for i = 1, bar.channelingTicks do
			bar.ticks[i] = bar.channelingDuration - (i - 1) * bar.channelingTickTime
		end
		setBarTicks(bar.channelingTicks, bar.channelingDuration, bar.ticks)
	else
		setBarTicks(0)
		bar.channelingDuration = nil
	end

	if bar.casting and bar.chargeSpell and bar.numStages and bar.numStages > 1 then
		self:AddStages(bar, bar.numStages)
	else
		self:ClearStages(bar)
	end
end

function Player:UNIT_SPELLCAST_STOP(bar, unit)
	setBarTicks(0)
	bar.channelingDuration = nil
end

function Player:UNIT_SPELLCAST_FAILED(bar, unit)
	setBarTicks(0)
	bar.channelingDuration = nil
end

function Player:UNIT_SPELLCAST_INTERRUPTED(bar, unit)
	setBarTicks(0)
	bar.channelingDuration = nil
end

function Player:UNIT_SPELLCAST_DELAYED(bar, unit)
	if bar.channeling and bar.endTime > bar.channelingEnd then
		local duration = bar.endTime - bar.startTime
		if bar.channelingDuration and duration > bar.channelingDuration and bar.channelingTicks > 0 then
			local extraTime = (duration - bar.channelingDuration)
			for i = 1, bar.channelingTicks do
				bar.ticks[i] = bar.ticks[i] + extraTime
			end
			while bar.ticks[bar.channelingTicks] > bar.channelingTickTime do
				bar.channelingTicks = bar.channelingTicks + 1
				bar.ticks[bar.channelingTicks] = bar.ticks[bar.channelingTicks-1] - bar.channelingTickTime
			end
			bar.channelingDuration = duration
			bar.channelingEnd = bar.endTime
			setBarTicks(bar.channelingTicks, bar.channelingDuration, bar.ticks)
		end
	end
end

function Player:GetStageDuration(bar, stage)
	if stage == bar.NumStages then
		return GetUnitEmpowerHoldAtMaxTime(bar.unit)
	else
		return GetUnitEmpowerStageDuration(bar.unit, stage-1)
	end
end

function Player:AddStages(bar, numStages)
	bar.CurrSpellStage = -1
	bar.NumStages = numStages + 1
	bar.StagePoints = {}
	bar.StagePips = {}
	bar.StageTiers = {}

	local sumDuration = 0
	local stageMaxValue = (bar.endTime - bar.startTime) * 1000

	local castBarLeft = bar.Bar:GetLeft()
	local castBarRight = bar.Bar:GetRight()
	local castBarWidth = castBarRight - castBarLeft

	for i = 1, bar.NumStages-1, 1 do
		local duration = self:GetStageDuration(bar, i)
		if duration > -1 then
			sumDuration = sumDuration + duration
			local portion = sumDuration / stageMaxValue
			local offset = castBarWidth * portion
			bar.StagePoints[i] = sumDuration

			local stagePipName = "StagePip" .. i
			local stagePip = bar[stagePipName]
			if not stagePip then
				stagePip = CreateFrame("FRAME", nil, bar.Bar, false and "CastingBarFrameStagePipFXTemplate" or "CastingBarFrameStagePipTemplate")
				bar[stagePipName] = stagePip
			end

			if stagePip then
				table.insert(bar.StagePips, stagePip)
				stagePip:ClearAllPoints()
				stagePip:SetPoint("TOP", bar.Bar, "TOPLEFT", offset, -1)
				stagePip:SetPoint("BOTTOM", bar.Bar, "BOTTOMLEFT", offset, 1)
				stagePip:Show()
				stagePip.BasePip:SetShown(i ~= bar.NumStages)
			end
		end
	end

	for i = 1, bar.NumStages-1, 1 do
		local chargeTierName = "ChargeTier" .. i
		local chargeTier = bar[chargeTierName]
		if not chargeTier then
			chargeTier = CreateFrame("FRAME", nil, bar.Bar, "CastingBarFrameStageTierTemplate")
			bar[chargeTierName] = chargeTier
		end

		if chargeTier then
			local leftStagePip = bar.StagePips[i]
			local rightStagePip = bar.StagePips[i+1]

			if leftStagePip then
				chargeTier:SetPoint("TOPLEFT", leftStagePip, "TOP", 0, 0)
			end
			if rightStagePip then
				chargeTier:SetPoint("BOTTOMRIGHT", rightStagePip, "BOTTOM", 0, 0)
			else
				chargeTier:SetPoint("BOTTOMRIGHT", bar.Bar, "BOTTOMRIGHT", 0, 1)
			end

			local chargeTierLeft = chargeTier:GetLeft()
			local chargeTierRight = chargeTier:GetRight()

			local left = (chargeTierLeft - castBarLeft) / castBarWidth
			local right = 1.0 - ((castBarRight - chargeTierRight) / castBarWidth)

			chargeTier.FlashAnim:Stop()
			chargeTier.FinishAnim:Stop()

			chargeTier.Normal:SetAtlas(("ui-castingbar-tier%d-empower"):format(i))
			chargeTier.Disabled:SetAtlas(("ui-castingbar-disabled-tier%d-empower"):format(i))
			chargeTier.Glow:SetAtlas(("ui-castingbar-glow-tier%d-empower"):format(i))

			chargeTier.Normal:SetTexCoord(left, right, 0, 1)
			chargeTier.Disabled:SetTexCoord(left, right, 0, 1)
			chargeTier.Glow:SetTexCoord(left, right, 0, 1)

			chargeTier.Normal:SetShown(false)
			chargeTier.Disabled:SetShown(true)
			chargeTier.Glow:SetAlpha(0)

			chargeTier:Show()
			table.insert(bar.StageTiers, chargeTier)
		end
	end
end

function Player:UpdateStage(bar)
	local maxStage = 0;
	local stageValue = bar.Bar:GetValue() * (bar.endTime - bar.startTime) * 1000
	for i = 1, bar.NumStages do
		if bar.StagePoints[i] then
			if stageValue > bar.StagePoints[i] then
				maxStage = i
			else
				break
			end
		end
	end

	if (maxStage ~= bar.CurrSpellStage and maxStage > -1 and maxStage <= bar.NumStages) then
		bar.CurrSpellStage = maxStage
		if maxStage < bar.NumStages then
			local stagePip = bar.StagePips[maxStage]
			if stagePip and stagePip.StageAnim then
				stagePip.StageAnim:Play()
			end
		end

		local chargeTierName = "ChargeTier" .. bar.CurrSpellStage
		local chargeTier = bar[chargeTierName]
		if chargeTier then
			chargeTier.Normal:SetShown(true)
			chargeTier.Disabled:SetShown(false)
			chargeTier.FlashAnim:Play()
		end
	end
end

function Player:ClearStages(bar)
	if bar.ChargeGlow then
		bar.ChargeGlow:SetShown(false)
	end

	if bar.StagePips then
		for _, stagePip in pairs(bar.StagePips) do
			local maxStage = bar.NumStages
			for i = 1, maxStage do
				local stageAnimName = "Stage" .. i
				local stageAnim = stagePip[stageAnimName]
				if stageAnim then
					stageAnim:Stop()
				end
			end
			stagePip:Hide()
		end
	end

	if bar.StageTiers then
		for _, stageTier in pairs(bar.StageTiers) do
			stageTier:Hide()
		end
	end

	bar.NumStages = 0
end
