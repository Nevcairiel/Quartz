--[[
	Development-only frame-by-frame recording of the player cast bar during synthetic casts.

	/qtest baseline   runs a 2 second cast and a 2 second channel and samples the bar every frame

	Each sample is compared against what the cast bar should show at that moment, computed from
	the cast's start and end time. The summary is stored in QuartzTestDB.baseline, so a run before
	and a run after a change to the cast bar can be compared.
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

ns.commands = ns.commands or {}

local DURATION = 2
local sampler = CreateFrame("Frame")
local running

-- the text CastBarTemplate's OnUpdate produces for a cast without pushback
local function expectedText(bar, remaining, total)
	local TimeFmt = Quartz3.Util.TimeFormat
	local db = bar.config
	local value = db.casttimecountup and (total - remaining) or remaining
	if db.hidecasttime then
		return format(TimeFmt(value))
	end
	return ("%s / %s"):format(format(TimeFmt(value)), format(TimeFmt(total, true)))
end

local function recordCast(bar, kind, done)
	local startTime = GetTime()
	local endTime = startTime + DURATION
	ns.StartSyntheticCast(bar, kind, DURATION, 0)

	local result = {
		kind = kind,
		samples = 0,
		maxFillError = 0, -- pixels between the fill and where it should be
		maxSparkError = 0, -- pixels between the spark and the fill edge
		textMismatches = 0,
		roundingDifferences = 0, -- time text that differs by one step in its last digit
		firstTextMismatch = nil,
		trace = {}, -- a few samples for eyeballing
	}
	local previousExpectedText
	local lastFrameTime = startTime

	sampler:SetScript("OnUpdate", function()
		local now = GetTime()
		if now >= endTime or not (bar.casting or bar.channeling) then
			sampler:SetScript("OnUpdate", nil)
			result.barWidth = bar.Bar:GetWidth()
			return done(result)
		end
		-- the first frame may run before the bar has laid out and updated once
		if now == startTime then return end

		local width = bar.Bar:GetWidth()
		local elapsedPerc = (now - startTime) / DURATION
		local expectedPerc = kind == "cast" and elapsedPerc or (1 - elapsedPerc)
		local frameTime = now - lastFrameTime
		lastFrameTime = now

		local tex = bar.Bar:GetStatusBarTexture()
		local fill = 0
		if tex:IsShown() and tex:GetLeft() and tex:GetRight() then
			fill = tex:GetRight() - tex:GetLeft()
		end
		local sparkX = bar.Spark:GetCenter() - bar.Bar:GetLeft()

		-- this sampler may run before or after the bar's own update within a frame,
		-- so one frame's worth of movement is not an error
		local slack = (frameTime / DURATION) * width
		local fillError = math.max(0, math.abs(fill - expectedPerc * width) - slack)
		local sparkError = math.abs(sparkX - fill)
		result.maxFillError = math.max(result.maxFillError, fillError)
		result.maxSparkError = math.max(result.maxSparkError, sparkError)

		local text = bar.TimeText:GetText()
		local expected = expectedText(bar, endTime - now, DURATION)
		if text ~= expected and text ~= previousExpectedText then
			-- the time formatter rounds half-way values up where TimeFormat rounds them down,
			-- and switches format exactly at 10 and 60 seconds; one step in the last digit is not a mismatch
			local shown, shownRest = tostring(text):match("^(%-?[%d.]+)(.*)$")
			local wanted, wantedRest = expected:match("^(%-?[%d.]+)(.*)$")
			local step = 10 ^ -Quartz3.db.profile.casttimeprecision
			if shown and wanted and shownRest == wantedRest and math.abs(tonumber(shown) - tonumber(wanted)) <= step * 1.001 then
				result.roundingDifferences = result.roundingDifferences + 1
			else
				result.textMismatches = result.textMismatches + 1
				result.firstTextMismatch = result.firstTextMismatch or ("shown '%s', expected '%s'"):format(tostring(text), expected)
			end
		end
		previousExpectedText = expected

		result.samples = result.samples + 1
		if result.samples % 15 == 1 then
			result.trace[#result.trace + 1] = ("t=%.3f fill=%.2f expected=%.2f spark=%.2f text='%s'"):format(now - startTime, fill, expectedPerc * width, sparkX, tostring(text))
		end
	end)
end

local function baseline()
	if running then
		print("|cff40c0ffQuartz baseline:|r already running.")
		return
	end
	local Player = Quartz3:GetModule("Player", true)
	if not Player or not Player:IsEnabled() then
		print("|cff40c0ffQuartz baseline:|r the Player module is not enabled.")
		return
	end
	local bar = Player.Bar
	if bar.casting or bar.channeling then
		print("|cff40c0ffQuartz baseline:|r the player is casting, try again afterwards.")
		return
	end

	running = true
	print("|cff40c0ffQuartz baseline:|r recording a cast and a channel, about five seconds...")
	local results = {}

	local function report(result)
		results[#results + 1] = result
		print(("|cff40c0ffQuartz baseline:|r %s: %d samples, fill off by at most %.2fpx, spark off by at most %.2fpx, %d text mismatches, %d rounding differences"):format(
			result.kind, result.samples, result.maxFillError, result.maxSparkError, result.textMismatches, result.roundingDifferences))
	end

	recordCast(bar, "cast", function(castResult)
		report(castResult)
		ns.StopSyntheticCast(bar)
		C_Timer.After(0.2, function()
			recordCast(bar, "channel", function(channelResult)
				report(channelResult)
				ns.StopSyntheticCast(bar)
				QuartzTestDB = QuartzTestDB or {}
				QuartzTestDB.baseline = QuartzTestDB.baseline or {}
				local runs = QuartzTestDB.baseline
				runs[#runs + 1] = { date = date("%Y-%m-%d %H:%M:%S"), results = results }
				print(("|cff40c0ffQuartz baseline:|r stored as run %d. /reload to write it to disk."):format(#runs))
				running = nil
			end)
		end)
	end)
end
ns.commands.baseline = baseline
