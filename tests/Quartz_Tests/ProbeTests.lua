--[[
	Development-only probes for the duration object APIs. They do not test Quartz, they
	record how the client behaves, to settle questions the API documentation leaves open.

	/qtest probe   synthetic probe of StatusBar:SetTimerDuration, duration objects and
	               the numeric rule formatter. Takes about ten seconds.
	/qtest record  toggles recording of real casts by the player, target and focus.
	               Cast a spell and a channel, target a casting NPC, then /reload.

	Results are stored in QuartzTestDB.probe and QuartzTestDB.record.
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

ns.commands = ns.commands or {}

local issecretvalue = issecretvalue

----------------------------
-- Describing values without touching secrets

local function desc(...)
	if select("#", ...) == 0 then return "<nothing>" end
	local value = ...
	if issecretvalue and issecretvalue(value) then
		return "<secret " .. type(value) .. ">"
	end
	if type(value) == "number" then
		return ("number:%.4f"):format(value)
	end
	return type(value) .. ":" .. tostring(value)
end

local function describeResults(ok, ...)
	if not ok then
		return "ERROR: " .. tostring((...))
	end
	local count = select("#", ...)
	if count == 0 then return "<nothing>" end
	local parts = {}
	for i = 1, count do
		parts[i] = desc((select(i, ...)))
	end
	return table.concat(parts, ", ")
end

-- calls func and describes what it returned, or the error it raised
local function try(func, ...)
	return describeResults(pcall(func, ...))
end

-- calls obj:method(...) and describes the result; indexing happens inside the pcall
local function method(obj, name, ...)
	return describeResults(pcall(function(...) return obj[name](obj, ...) end, ...))
end

local function exists(path)
	local value = _G
	for part in path:gmatch("[^.]+") do
		if type(value) ~= "table" then return "missing" end
		value = value[part]
	end
	return value ~= nil and type(value) or "missing"
end

----------------------------
-- Time formatter candidate, replicating Quartz3.Util.TimeFormat

local function buildFormatter(precision, isCastTime, truncate)
	local formatter = C_StringUtil.CreateNumericRuleFormatter()
	local step = truncate and 1 or nil
	local rounding = truncate and Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Down or nil

	local breakpoints = {
		{ threshold = 0, format = "%." .. precision .. "f" },
	}
	if not isCastTime then
		breakpoints[#breakpoints + 1] = { threshold = 10, format = "%d", step = step, rounding = rounding }
	end
	breakpoints[#breakpoints + 1] = { threshold = 60, format = "%d:%02d", components = {
		{ div = 60, step = step, rounding = rounding },
		{ mod = 60, step = step, rounding = rounding },
	} }
	breakpoints[#breakpoints + 1] = { threshold = 3600, format = "%d:%02d", components = {
		{ div = 3600, step = step, rounding = rounding },
		{ div = 60, mod = 60, step = step, rounding = rounding },
	} }
	formatter:SetBreakpoints(breakpoints)
	return formatter
end
ns.BuildTimeFormatter = buildFormatter

----------------------------
-- Synthetic probe

local probeHolder, bar, spark
local running

local function probe()
	if running then
		print("|cff40c0ffQuartz probe:|r already running.")
		return
	end
	running = true
	print("|cff40c0ffQuartz probe:|r running, this takes about ten seconds...")

	local lines = {}
	local function log(key, value)
		lines[#lines + 1] = key .. " = " .. tostring(value)
	end

	local Direction = Enum.StatusBarTimerDirection
	local Interpolation = Enum.StatusBarInterpolation
	local duration

	local function fillFraction()
		local tex = bar:GetStatusBarTexture()
		if not tex:IsShown() then return 0 end
		local left, right = tex:GetLeft(), tex:GetRight()
		if not left or not right then return 0 end
		return (right - left) / bar:GetWidth()
	end

	local function sparkFraction()
		local x = spark:GetCenter()
		local left = bar:GetLeft()
		if not x or not left then return -1 end
		return (x - left) / bar:GetWidth()
	end

	local function state(label)
		log(label, ("fill %.3f, spark %.3f, value [%s], minmax [%s]"):format(fillFraction(), sparkFraction(), method(bar, "GetValue"), method(bar, "GetMinMaxValues")))
	end

	local function setTimer(direction, label)
		log(label or "SetTimerDuration", method(bar, "SetTimerDuration", duration, Interpolation.Immediate, direction))
	end

	local steps = {
		{ name = "environment", run = function()
			for _, path in ipairs({
				"C_DurationUtil.CreateDuration", "C_DurationUtil.CreateDurationTextBinding", "C_StringUtil.CreateNumericRuleFormatter",
				"UnitCastingDuration", "UnitChannelDuration", "UnitEmpoweredChannelDuration", "UnitEmpoweredStagePercentages",
				"issecretvalue", "canaccessvalue", "C_Secrets.ShouldUnitSpellCastingBeSecret",
				"Enum.StatusBarTimerDirection.ElapsedTime", "Enum.StatusBarTimerDirection.RemainingTime",
				"Enum.StatusBarInterpolation.Immediate", "Enum.NumericRuleFormatRounding.Down",
			}) do
				log("exists " .. path, exists(path))
			end
			log("C_Secrets.HasSecretRestrictions", try(C_Secrets.HasSecretRestrictions))
		end },

		{ name = "setup", wait = 1, run = function()
			if probeHolder then probeHolder:Hide() end
			probeHolder = CreateFrame("Frame", nil, UIParent)
			probeHolder:SetSize(200, 20)
			probeHolder:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
			bar = Quartz3:CreateStatusBar(nil, probeHolder)
			bar:SetAllPoints(probeHolder)
			bar:SetStatusBarColor(0.9, 0.6, 0.1)
			bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
			bar:SetBackdropColor(0, 0, 0)
			spark = bar:CreateTexture(nil, "OVERLAY")
			spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			spark:SetBlendMode("ADD")
			spark:SetSize(20, 44)
			-- anchored once to the fill texture, never repositioned
			spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)

			duration = C_DurationUtil.CreateDuration()
			log("duration object", desc(duration))
			log("new duration IsZero", method(duration, "IsZero"))
			duration:SetTimeFromStart(GetTime(), 4)
			log("HasSecretValues", method(duration, "HasSecretValues"))
			log("GetTotalDuration (expect 4)", method(duration, "GetTotalDuration"))
			log("GetClockTime - GetTime()", try(function() return duration:GetClockTime() - GetTime() end))
			log("GetStartTime - GetTime()", try(function() return duration:GetStartTime() - GetTime() end))

			bar:SetMinMaxValues(0, 1)
			bar:SetValue(0.5)
			setTimer(Direction.ElapsedTime)
			state("immediately after SetTimerDuration (was value 0.5 of 0-1)")
		end },

		{ name = "running", wait = 0.3, run = function()
			state("4s elapsed timer after 1s (expect fill 0.25)")
			log("GetElapsedPercent", method(duration, "GetElapsedPercent"))
			log("GetRemainingDuration", method(duration, "GetRemainingDuration"))
			log("GetInterpolatedValue", method(bar, "GetInterpolatedValue"))
			log("GetTimerDuration", method(bar, "GetTimerDuration"))
			log("GetTimerDuration is the same object", try(function() return bar:GetTimerDuration() == duration end))
			-- does the bar follow later changes to the object?
			duration:SetTimeFromStart(GetTime(), 100)
		end },

		{ name = "mutation", wait = 1, run = function()
			state("0.3s after changing the object to 100s (fill ~0.003: bar follows the object; ~0.33: bar copied it)")
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeFromStart(GetTime(), 0.5)
			setTimer(Direction.ElapsedTime)
		end },

		{ name = "expiry", wait = 0.5, run = function()
			state("0.5s elapsed timer, 0.5s after it expired")
			log("HasExpired", method(duration, "HasExpired"))
			log("IsZero after expiry", method(duration, "IsZero"))
			log("GetRemainingDuration after expiry", method(duration, "GetRemainingDuration"))
			log("GetElapsedPercent after expiry", method(duration, "GetElapsedPercent"))
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeFromStart(GetTime(), 10)
			setTimer(Direction.ElapsedTime)
		end },

		{ name = "SetValue during a timer", wait = 0.5, run = function()
			state("10s elapsed timer after 0.5s (expect fill 0.05)")
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
			state("right after SetMinMaxValues(0,1) and SetValue(1)")
		end },

		{ name = "SetValue cancels?", wait = 0.3, run = function()
			state("0.5s after SetValue(1) (fill 1.0: SetValue cancels the timer; ~0.1: timer still runs)")
			log("GetTimerDuration after SetValue", method(bar, "GetTimerDuration"))
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeFromStart(GetTime(), 10)
			setTimer(Direction.ElapsedTime)
			log("SetTimerDuration(zero duration)", method(bar, "SetTimerDuration", C_DurationUtil.CreateDuration(), Interpolation.Immediate, Direction.ElapsedTime))
		end },

		{ name = "zero duration as cancel", wait = 0.3, run = function()
			state("0.3s after replacing a running timer with a zero duration")
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
		end },

		{ name = "nil as cancel", wait = 1, run = function()
			state("SetValue(1) after the zero duration (expect fill 1.0)")
			log("SetTimerDuration(nil)", method(bar, "SetTimerDuration", nil))
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeFromStart(GetTime(), 4)
			setTimer(Direction.RemainingTime, "SetTimerDuration RemainingTime")
		end },

		{ name = "remaining direction", wait = 0.2, run = function()
			state("4s remaining timer after 1s (expect fill 0.75)")
			local now = GetTime()
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeSpan(now - 25, now + 75)
			setTimer(Direction.ElapsedTime)
		end },

		{ name = "backdated", wait = 0.2, run = function()
			state("time span started 25s ago, 100s long (expect fill 0.25)")
			local now = GetTime()
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeSpan(now, now)
			log("zero-length span IsZero", method(duration, "IsZero"))
			setTimer(Direction.ElapsedTime, "SetTimerDuration zero-length elapsed")
		end },

		{ name = "zero-length elapsed", wait = 0.2, run = function()
			state("zero-length span, elapsed direction")
			setTimer(Direction.RemainingTime, "SetTimerDuration zero-length remaining")
		end },

		{ name = "zero-length remaining", wait = 0.2, run = function()
			state("zero-length span, remaining direction")
			local now = GetTime()
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeSpan(now + 5, now + 10)
			setTimer(Direction.ElapsedTime)
		end },

		{ name = "not started", wait = 0.1, run = function()
			state("time span starting in 5s, elapsed direction")
			log("HasStarted", method(duration, "HasStarted"))
			log("GetElapsedPercent before start", method(duration, "GetElapsedPercent"))
			log("GetRemainingDuration before start", method(duration, "GetRemainingDuration"))
		end },

		{ name = "formatter", run = function()
			local TimeFmt = Quartz3.Util.TimeFormat
			local values = { 0, 0.04, 0.05, 0.94, 0.95, 1.25, 9.94, 9.99, 10, 10.01, 10.5, 10.99, 59.4, 59.9, 60, 60.01, 60.5, 61, 119.9, 125, 3599, 3599.9, 3600, 3600.5, 3601, 3660, 7325, -0.04, -0.5 }
			local precision = 1
			do
				local fmt = TimeFmt(5)
				precision = tonumber(fmt:match("%%%.(%d+)f")) or 1
			end
			log("cast time precision", precision)
			for _, isCastTime in ipairs({ false, true }) do
				for _, truncate in ipairs({ false, true }) do
					local label = ("formatter isCastTime=%s truncate=%s"):format(tostring(isCastTime), tostring(truncate))
					local ok, formatter = pcall(buildFormatter, precision, isCastTime, truncate)
					if not ok then
						log(label, "ERROR building: " .. tostring(formatter))
					else
						local mismatches = 0
						for _, value in ipairs(values) do
							local expected = format(TimeFmt(value, isCastTime))
							local okFormat, actual = pcall(formatter.FormatNumber, formatter, value)
							if not okFormat or actual ~= expected then
								mismatches = mismatches + 1
								log(label .. " value " .. value, ("TimeFormat '%s', formatter '%s'"):format(expected, tostring(actual)))
							end
						end
						log(label, ("%d of %d values differ"):format(mismatches, #values))
					end
				end
			end
			local formatter = buildFormatter(precision, false, true)
			duration = C_DurationUtil.CreateDuration()
			duration:SetTimeFromStart(GetTime(), 75)
			log("FormatRemainingDuration (75s)", method(duration, "FormatRemainingDuration", formatter))
			log("FormatTotalDuration (75s)", method(duration, "FormatTotalDuration", buildFormatter(precision, true, true)))
			log("FormatElapsedDuration (75s)", method(duration, "FormatElapsedDuration", formatter))
		end },
	}

	local index = 0
	local function nextStep()
		index = index + 1
		local step = steps[index]
		if not step then
			QuartzTestDB = QuartzTestDB or {}
			QuartzTestDB.probe = { date = date("%Y-%m-%d %H:%M:%S"), lines = lines }
			print(("|cff40c0ffQuartz probe:|r done, %d lines recorded. /reload to write them to disk."):format(#lines))
			running = nil
			return
		end
		local ok, err = pcall(step.run)
		if not ok then
			log("STEP ERROR in " .. step.name, tostring(err))
		end
		C_Timer.After(step.wait or 0.1, nextStep)
	end
	nextStep()
end
ns.commands.probe = probe

----------------------------
-- Recording real casts

local recorders
local recording = false
local MAX_RECORDS = 30

local function getRecorder(unit, index)
	recorders = recorders or {}
	if recorders[unit] then return recorders[unit] end

	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(200, 16)
	frame:SetPoint("CENTER", UIParent, "CENTER", 320, 180 - index * 30)

	local statusBar = Quartz3:CreateStatusBar(nil, frame)
	statusBar:SetAllPoints(frame)
	statusBar:SetStatusBarColor(0.3, 0.6, 1)
	statusBar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	statusBar:SetBackdropColor(0, 0, 0)
	statusBar:SetMinMaxValues(0, 1)
	frame.bar = statusBar

	frame.spark = statusBar:CreateTexture(nil, "OVERLAY")
	frame.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	frame.spark:SetBlendMode("ADD")
	frame.spark:SetSize(20, 36)
	frame.spark:SetPoint("CENTER", statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)

	frame.label = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.label:SetPoint("LEFT", 3, 0)
	frame.label:SetText(unit)
	frame.text = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.text:SetPoint("RIGHT", -3, 0)

	frame.unit = unit
	recorders[unit] = frame
	return frame
end

local function record(frame, event)
	local unit = frame.unit
	QuartzTestDB = QuartzTestDB or {}
	QuartzTestDB.record = QuartzTestDB.record or {}
	local records = QuartzTestDB.record
	if #records >= MAX_RECORDS then return end

	local lines = {}
	local function log(key, value)
		lines[#lines + 1] = key .. " = " .. tostring(value)
	end
	records[#records + 1] = { unit = unit, event = event, date = date("%H:%M:%S"), lines = lines }

	local isChannel = event ~= "UNIT_SPELLCAST_START"
	local isEmpower = event == "UNIT_SPELLCAST_EMPOWER_START"

	log("ShouldUnitSpellCastingBeSecret", try(C_Secrets.ShouldUnitSpellCastingBeSecret, unit))
	log("UnitIsUnit(unit, player)", try(UnitIsUnit, unit, "player"))
	log(isChannel and "UnitChannelInfo" or "UnitCastingInfo", try(isChannel and UnitChannelInfo or UnitCastingInfo, unit))

	local getter = isEmpower and UnitEmpoweredChannelDuration or (isChannel and UnitChannelDuration or UnitCastingDuration)
	local ok, duration = pcall(getter, unit)
	log("duration getter", ok and desc(duration) or ("ERROR: " .. tostring(duration)))
	-- a truth test is allowed on a secret object, a comparison is not
	if not ok or not duration then return end

	log("duration is itself a secret value", tostring(issecretvalue and issecretvalue(duration) or false))
	for _, name in ipairs({ "HasSecretValues", "IsZero", "GetStartTime", "GetEndTime", "GetTotalDuration", "GetRemainingDuration", "GetElapsedPercent", "HasExpired", "GetModRate" }) do
		log("duration:" .. name, method(duration, name))
	end
	-- do the numbers agree with the classic info functions, where both are readable?
	log("start time difference to info (seconds)", try(function()
		local _, _, _, startTimeMs = (isChannel and UnitChannelInfo or UnitCastingInfo)(unit)
		return duration:GetStartTime() - startTimeMs / 1000
	end))
	log("total duration difference to info (seconds)", try(function()
		local _, _, _, startTimeMs, endTimeMs = (isChannel and UnitChannelInfo or UnitCastingInfo)(unit)
		return duration:GetTotalDuration() - (endTimeMs - startTimeMs) / 1000
	end))
	if isEmpower then
		log("UnitEmpoweredChannelDuration(unit, false)", try(UnitEmpoweredChannelDuration, unit, false))
		log("UnitEmpoweredStagePercentages", try(UnitEmpoweredStagePercentages, unit))
		log("GetUnitEmpowerHoldAtMaxTime", try(GetUnitEmpowerHoldAtMaxTime, unit))
	end

	local statusBar = frame.bar
	local direction = (isChannel and not isEmpower) and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
	log("bar:SetTimerDuration", method(statusBar, "SetTimerDuration", duration, Enum.StatusBarInterpolation.Immediate, direction))
	for _, name in ipairs({ "HasSecretValues", "GetValue", "GetMinMaxValues", "GetWidth", "GetLeft", "IsAnchoringSecret", "GetTimerDuration" }) do
		log("bar:" .. name, method(statusBar, name))
	end
	log("fill texture:GetWidth", method(statusBar:GetStatusBarTexture(), "GetWidth"))
	log("fill texture:IsAnchoringSecret", method(statusBar:GetStatusBarTexture(), "IsAnchoringSecret"))
	log("spark:GetCenter", method(frame.spark, "GetCenter"))
	log("spark:IsAnchoringSecret", method(frame.spark, "IsAnchoringSecret"))
	log("holder frame:GetWidth", method(frame, "GetWidth"))

	-- time text candidates
	log("SetFormattedText('%.1f', GetRemainingDuration())", try(function()
		frame.text:SetFormattedText("%.1f", duration:GetRemainingDuration())
	end))
	log("text:GetText after SetFormattedText", method(frame.text, "GetText"))
	local okFormatter, formatter = pcall(ns.BuildTimeFormatter, 1, false, true)
	if okFormatter then
		log("FormatRemainingDuration(rule formatter)", method(duration, "FormatRemainingDuration", formatter))
		log("FormatTotalDuration(rule formatter)", method(duration, "FormatTotalDuration", formatter))
		log("SetText(FormatRemainingDuration())", try(function()
			frame.text:SetText(duration:FormatRemainingDuration(formatter))
		end))
		log("SetFormattedText('%s / %s', remaining, total)", try(function()
			frame.text:SetFormattedText("%s / %s", duration:FormatRemainingDuration(formatter), duration:FormatTotalDuration(formatter))
		end))
		log("text:GetStringWidth after secret-capable text", method(frame.text, "GetStringWidth"))

		-- keep the text live for the rest of the cast, and note whether a per-frame update ever fails
		frame.updateError = nil
		frame.updates = 0
		frame:SetScript("OnUpdate", function(self)
			local okUpdate, err = pcall(function()
				self.text:SetFormattedText("%s / %s", duration:FormatRemainingDuration(formatter), duration:FormatTotalDuration(formatter))
			end)
			self.updates = self.updates + 1
			if not okUpdate and not self.updateError then
				self.updateError = tostring(err)
			end
		end)
		frame.finish = function()
			log("per-frame text updates", ("%d updates, %s"):format(frame.updates, frame.updateError and ("first error: " .. frame.updateError) or "no errors"))
			log("at stop, bar:GetValue", method(statusBar, "GetValue"))
			log("at stop, duration:HasExpired", method(duration, "HasExpired"))
			log("at stop, duration:GetRemainingDuration", method(duration, "GetRemainingDuration"))
			frame:SetScript("OnUpdate", nil)
			frame.finish = nil
		end
	else
		log("rule formatter", "ERROR building: " .. tostring(formatter))
	end

	print(("|cff40c0ffQuartz record:|r %s %s (%d/%d)"):format(unit, event, #records, MAX_RECORDS))
end

local startEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START" }
local stopEvents = { "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }

local function toggleRecording()
	recording = not recording
	for index, unit in ipairs({ "player", "target", "focus" }) do
		local frame = getRecorder(unit, index)
		if recording then
			-- one frame per unit, so the unit never has to be read from the event payload
			for _, event in ipairs(startEvents) do frame:RegisterUnitEvent(event, unit) end
			for _, event in ipairs(stopEvents) do frame:RegisterUnitEvent(event, unit) end
			frame:SetScript("OnEvent", function(self, event)
				if tContains(startEvents, event) then
					if self.finish then self.finish() end
					local ok, err = pcall(record, self, event)
					if not ok then
						print("|cffff4040Quartz record error:|r " .. tostring(err))
					end
				elseif self.finish then
					self.finish()
				end
			end)
			frame:Show()
		else
			frame:UnregisterAllEvents()
			if frame.finish then frame.finish() end
			frame:Hide()
		end
	end
	if recording then
		QuartzTestDB = QuartzTestDB or {}
		QuartzTestDB.record = {}
		print("|cff40c0ffQuartz record:|r on. Cast a spell and a channel, target or focus something that casts, then /qtest record again and /reload.")
	else
		print("|cff40c0ffQuartz record:|r off. /reload to write the records to disk.")
	end
end
ns.commands.record = toggleRecording

----------------------------
-- Recording the global cooldown

local GCD_SPELL = 61304 -- the spell the client tracks the global cooldown on
local gcdFrame
local gcdRecording = false
local MAX_GCD_RECORDS = 60

local function describeCooldown(log, label, spell)
	local ok, info = pcall(C_Spell.GetSpellCooldown, spell)
	if not ok then
		log(label .. " GetSpellCooldown", "ERROR: " .. tostring(info))
	elseif not info then
		log(label .. " GetSpellCooldown", "<nothing>")
	else
		local parts = {}
		for _, field in ipairs({ "startTime", "duration", "isEnabled", "isActive", "modRate", "activeCategory", "timeUntilEndOfStartRecovery", "isOnGCD" }) do
			parts[#parts + 1] = field .. "=" .. describeResults(pcall(function() return info[field] end))
		end
		log(label .. " GetSpellCooldown", table.concat(parts, ", "))
	end
	log(label .. " ShouldSpellCooldownBeSecret", try(C_Secrets.ShouldSpellCooldownBeSecret, spell))
	log(label .. " GetSpellCooldownSecrecy", try(C_Secrets.GetSpellCooldownSecrecy, spell))

	local okDuration, duration = pcall(C_Spell.GetSpellCooldownDuration, spell)
	if not okDuration then
		log(label .. " GetSpellCooldownDuration", "ERROR: " .. tostring(duration))
	elseif not duration then
		log(label .. " GetSpellCooldownDuration", "<nothing>")
	else
		local parts = {}
		for _, name in ipairs({ "HasSecretValues", "IsZero", "GetTotalDuration", "GetRemainingDuration", "HasExpired" }) do
			parts[#parts + 1] = name .. "=" .. method(duration, name)
		end
		log(label .. " GetSpellCooldownDuration", table.concat(parts, ", "))
	end
	return okDuration and duration or nil
end

local function recordGCD(self, event, ...)
	QuartzTestDB = QuartzTestDB or {}
	QuartzTestDB.gcd = QuartzTestDB.gcd or {}
	local records = QuartzTestDB.gcd
	if #records >= MAX_GCD_RECORDS then return end

	local lines = {}
	local function log(key, value)
		lines[#lines + 1] = key .. " = " .. tostring(value)
	end
	records[#records + 1] = { event = event, time = ("%.3f"):format(GetTime()), lines = lines }

	log("arguments", describeResults(true, ...))
	log("InCombatLockdown", tostring(InCombatLockdown()))
	log("ShouldCooldownsBeSecret", try(C_Secrets.ShouldCooldownsBeSecret))
	local duration = describeCooldown(log, "gcd spell", GCD_SPELL)

	if event ~= "SPELL_UPDATE_COOLDOWN" then
		local _, _, spell = ...
		describeCooldown(log, "cast spell", spell)

		-- drive a bar with the global cooldown, to see that it can be shown
		if duration then
			log("bar:SetTimerDuration", method(self.bar, "SetTimerDuration", duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime))
		end

		-- Can the global cooldown be shown from the cast spell alone, without the global cooldown spell?
		-- The spell's own fields and duration are followed for a while, and compared against the
		-- global cooldown spell, which is readable on retail and gives the true end time.
		local okInfo, spellInfo = pcall(C_Spell.GetSpellCooldown, spell)
		local okGCD, gcdInfo = pcall(C_Spell.GetSpellCooldown, GCD_SPELL)
		if okInfo and spellInfo and spellInfo.isOnGCD == true and okGCD and gcdInfo and not issecretvalue(gcdInfo.duration) and gcdInfo.duration > 0 then
			if self.finishSampling then self.finishSampling() end

			local gcdEnd = gcdInfo.startTime + gcdInfo.duration
			local okSpellDuration, spellDuration = pcall(C_Spell.GetSpellCooldownDuration, spell)
			log("cast spell duration while on gcd", okSpellDuration and desc(spellDuration) or ("ERROR: " .. tostring(spellDuration)))
			if okSpellDuration and spellDuration then
				-- the secret path: the bar runs on the duration of the cast spell
				log("bar:SetTimerDuration(cast spell duration)", method(self.bar, "SetTimerDuration", spellDuration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime))
			end

			if not self.alphaCurve then
				-- alpha 1 for the whole cooldown, fading to 0 over its last 3%
				self.alphaCurve = C_CurveUtil.CreateCurve()
				self.alphaCurve:SetType(Enum.LuaCurveType.Linear)
				self.alphaCurve:AddPoint(0, 0)
				self.alphaCurve:AddPoint(0.03, 1)
				self.alphaCurve:AddPoint(1, 1)
			end
			local curve = self.alphaCurve

			local onGCDEnd, activeEnd, alphaZero, alphaMid, frames, alphaErrors, firstAlphaError = nil, nil, nil, nil, 0, 0, nil
			self.finishSampling = function()
				self:SetScript("OnUpdate", nil)
				self.finishSampling = nil
				self.spark:SetAlpha(1)
				log("sampled frames", frames)
				log("cast spell isOnGCD stopped being true, seconds after the true end", onGCDEnd and ("%.3f"):format(onGCDEnd) or "never within the sample")
				log("cast spell isActive stopped being true, seconds after the true end", activeEnd and ("%.3f"):format(activeEnd) or "never within the sample")
				log("alpha curve on the readable gcd duration, value mid cooldown", alphaMid and ("%.3f"):format(alphaMid) or "not sampled")
				log("alpha curve on the readable gcd duration reached 0, seconds after the true end", alphaZero and ("%.3f"):format(alphaZero) or "never within the sample")
				log("spark:SetAlpha(curve on the cast spell duration)", ("%d errors%s"):format(alphaErrors, firstAlphaError and (", first: " .. firstAlphaError) or ""))
			end

			self:SetScript("OnUpdate", function()
				local now = GetTime()
				frames = frames + 1

				local info = C_Spell.GetSpellCooldown(spell)
				if not onGCDEnd and not (info and info.isOnGCD == true) then onGCDEnd = now - gcdEnd end
				if not activeEnd and not (info and info.isActive == true) then activeEnd = now - gcdEnd end

				if duration then
					local okAlpha, alpha = pcall(duration.EvaluateRemainingPercent, duration, curve)
					if okAlpha and not issecretvalue(alpha) then
						if not alphaMid and now > gcdEnd - gcdInfo.duration / 2 then alphaMid = alpha end
						if not alphaZero and alpha == 0 then alphaZero = now - gcdEnd end
					end
				end

				if okSpellDuration and spellDuration then
					local okSet, err = pcall(function()
						self.spark:SetAlpha(spellDuration:EvaluateRemainingPercent(curve))
					end)
					if not okSet then
						alphaErrors = alphaErrors + 1
						firstAlphaError = firstAlphaError or tostring(err)
					end
				end

				if now > gcdEnd + 1 then self.finishSampling() end
			end)
		end
		print(("|cff40c0ffQuartz gcd:|r %s (%d/%d)"):format(event, #records, MAX_GCD_RECORDS))
	end
end

local function toggleGCDRecording()
	gcdRecording = not gcdRecording
	if not gcdFrame then
		gcdFrame = getRecorder("gcd", 4)
		gcdFrame:SetScript("OnEvent", function(self, event, ...)
			local ok, err = pcall(recordGCD, self, event, ...)
			if not ok then
				print("|cffff4040Quartz gcd error:|r " .. tostring(err))
			end
		end)
	end
	if gcdRecording then
		QuartzTestDB = QuartzTestDB or {}
		QuartzTestDB.gcd = {}
		gcdFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
		gcdFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		gcdFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		gcdFrame:Show()
		print("|cff40c0ffQuartz gcd:|r on. Use an instant spell out of combat, then one in combat, then /qtest gcd again and /reload.")
	else
		gcdFrame:UnregisterAllEvents()
		if gcdFrame.finishSampling then gcdFrame.finishSampling() end
		gcdFrame:Hide()
		print("|cff40c0ffQuartz gcd:|r off. /reload to write the records to disk.")
	end
end
ns.commands.gcd = toggleGCDRecording

function ns.HideProbe()
	if probeHolder then probeHolder:Hide() end
end
