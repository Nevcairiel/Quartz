--[[
	Development-only tests that drive the real Quartz player cast bar with synthetic casts,
	to check the cast bar template against the native StatusBar. Run as part of /qtest.
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

-- puts a cast bar into the state UNIT_SPELLCAST_START would, without a real cast
function ns.StartSyntheticCast(bar, kind, duration, elapsed)
	local timer = C_DurationUtil.CreateDuration()
	timer:SetTimeFromStart(GetTime() - elapsed, duration)
	bar.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
	bar:StartTimer(timer, kind == "channel")
	bar.Text:SetText("Quartz test")
	bar:Show()
	bar:SetAlpha(1)
	bar.Spark:Show()
end

function ns.StopSyntheticCast(bar)
	bar.casting, bar.channeling, bar.chargeSpell = nil, nil, nil
	bar.fadeOut = nil
	bar.stopTime = nil
	bar.TimeText:SetText("")
	bar:Hide()
end

function ns.AddCastBarCases(cases, add, near)
	for name, castBar in pairs(Quartz3.CastBarTemplate.bars) do
		local objectType = castBar.Bar:GetObjectType()
		add(("cast bar %s uses a StatusBar"):format(name), objectType == "StatusBar", objectType)
	end

	local Player = Quartz3:GetModule("Player", true)
	if not Player or not Player:IsEnabled() then
		add("player cast bar tests", nil, "skipped, Player module is not enabled")
		return
	end

	local bar = Player.Bar
	if bar.casting or bar.channeling then
		add("player cast bar tests", nil, "skipped, the player is casting")
		return
	end

	local layer = bar.Bar:GetStatusBarTexture():GetDrawLayer()
	add("player bar fill is on ARTWORK after ApplySettings", layer == "ARTWORK", layer)

	local Latency = Quartz3:GetModule("Latency", true)
	if Latency and Latency:IsEnabled() and Latency.lagbox then
		add("latency box is a region of the status bar", Latency.lagbox:GetParent() == bar.Bar)
		add("latency box draw layer", nil, Latency.lagbox:GetDrawLayer())
	end

	local function start(kind, duration, elapsed) ns.StartSyntheticCast(bar, kind, duration, elapsed) end
	local function stop() ns.StopSyntheticCast(bar) end

	-- fraction of the bar that is filled
	local function fillFraction()
		local tex = bar.Bar:GetStatusBarTexture()
		if not tex:IsShown() or not tex:GetLeft() or not tex:GetRight() then return 0 end
		return (tex:GetRight() - tex:GetLeft()) / bar.Bar:GetWidth()
	end

	local function checkFill(name, expected)
		local fill = fillFraction()
		add(name .. ": fill", near(fill, expected, 0.01), ("%.3f, expected %.3f"):format(fill, expected))
	end

	local function checkProgress(name, expected)
		checkFill(name, expected)

		local width = bar.Bar:GetWidth()
		local sparkX = bar.Spark:GetCenter() - bar.Bar:GetLeft()
		add(name .. ": spark sits on the fill edge", near(sparkX, fillFraction() * width, 0.5), ("spark %.2f fill %.2f"):format(sparkX, fillFraction() * width))
		add(name .. ": spark is visible", bar.Spark:IsVisible())

		local text = bar.TimeText:GetText()
		add(name .. ": time text is set", text ~= nil and text ~= "", text)
		add(name .. ": the bar runs on its duration", bar.Bar:GetTimerDuration() == bar.duration)
	end

	-- the time formatter replaces Quartz3.Util.TimeFormat
	do
		local precision = Quartz3.db.profile.casttimeprecision
		local decimals = "%." .. precision .. "f"
		local remaining, total = Quartz3.Util.GetTimeFormatter(), Quartz3.Util.GetTimeFormatter(true)
		local function checkFormat(formatter, label, value, expected)
			local actual = formatter:FormatNumber(value)
			add(("time formatter (%s) formats %s"):format(label, tostring(value)), actual == expected, ("'%s', expected '%s'"):format(tostring(actual), expected))
		end
		checkFormat(remaining, "remaining", 5, decimals:format(5))
		checkFormat(remaining, "remaining", 0, decimals:format(0))
		checkFormat(remaining, "remaining", 12.7, "12")
		checkFormat(remaining, "remaining", 59.9, "59")
		checkFormat(remaining, "remaining", 75, "1:15")
		checkFormat(remaining, "remaining", 3725, "1:02")
		checkFormat(total, "total", 45.5, decimals:format(45.5))
		checkFormat(total, "total", 100, "1:40")
		add("time formatters are cached", Quartz3.Util.GetTimeFormatter() == remaining and Quartz3.Util.GetTimeFormatter(true) == total)
	end

	cases[#cases + 1] = {
		name = "cast bar: cast",
		setup = function() start("cast", 100, 25) end,
		check = function()
			checkProgress("cast at 25%", 0.25)
			local db = bar.config
			if not db.hidecasttime and not db.casttimecountup and not db.hidetimetext then
				local text = bar.TimeText:GetText()
				add("cast at 25%: time text", text == "1:15 / 1:40" or text == "1:14 / 1:40", text)
			end
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: channel",
		setup = function() start("channel", 100, 25) end,
		check = function() checkProgress("channel with 75% left", 0.75) end,
	}

	-- other modules hook the callbacks the cast bar makes into the Player module, none of them may stop the bar
	cases[#cases + 1] = {
		name = "cast bar: module callbacks",
		setup = function()
			start("cast", 100, 25)
			Player:UNIT_SPELLCAST_START(bar, "player")
			Player:UNIT_SPELLCAST_DELAYED(bar, "player")
		end,
		check = function() checkProgress("cast after the module callbacks ran", 0.25) end,
	}

	-- pushback replaces the duration of a running cast
	cases[#cases + 1] = {
		name = "cast bar: replaced duration",
		setup = function()
			start("cast", 100, 25)
			local timer = C_DurationUtil.CreateDuration()
			timer:SetTimeFromStart(GetTime() - 50, 100)
			bar:SetDuration(timer)
		end,
		check = function() checkProgress("cast after its duration was replaced", 0.5) end,
	}

	-- the latency module shifts the duration of a running cast
	cases[#cases + 1] = {
		name = "cast bar: shifted duration",
		setup = function()
			start("cast", 100, 25)
			local timer = bar.duration
			timer:SetTimeSpan(timer:GetStartTime() - 25, timer:GetEndTime() - 25)
		end,
		check = function() checkProgress("cast after its duration was shifted", 0.5) end,
	}

	cases[#cases + 1] = {
		name = "cast bar: settings applied during a cast",
		setup = function()
			start("cast", 100, 25)
			bar:ApplySettings()
		end,
		check = function() checkProgress("cast after ApplySettings", 0.25) end,
	}

	cases[#cases + 1] = {
		name = "cast bar: cast stops",
		setup = function()
			start("cast", 100, 25)
			bar:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_STOP", "player")
		end,
		check = function()
			checkFill("stopped cast is full", 1)
			add("stopped cast fades out", bar.casting == nil and bar.fadeOut == true)
			add("stopped cast no longer runs on a duration", bar.Bar:GetTimerDuration() == nil)
			local text = bar.TimeText:GetText()
			add("stopped cast clears the time text", text == nil or text == "", text)
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: channel stops",
		setup = function()
			start("channel", 100, 25)
			bar:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_CHANNEL_STOP", "player")
		end,
		check = function()
			checkFill("stopped channel is empty", 0)
			add("stopped channel fades out", bar.channeling == nil and bar.fadeOut == true)
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: cast is interrupted",
		setup = function()
			start("cast", 100, 25)
			bar:UNIT_SPELLCAST_INTERRUPTED("UNIT_SPELLCAST_INTERRUPTED", "player")
		end,
		check = function()
			checkFill("interrupted cast is full", 1)
			add("interrupted cast fades out", bar.casting == nil and bar.fadeOut == true)
			local r, g, b = bar.Bar:GetStatusBarColor()
			local fr, fg, fb = unpack(Quartz3.db.profile.failcolor)
			add("interrupted cast uses the fail color", near(r, fr, 0.01) and near(g, fg, 0.01) and near(b, fb, 0.01), ("%.2f %.2f %.2f"):format(r, g, b))
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: zero-length cast",
		setup = function() start("cast", 0, 0) end,
		check = function()
			local ok, err = pcall(bar.OnUpdate, bar)
			add("zero-length cast updates without error", ok, err)
			checkFill("zero-length cast is full", 1)
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: zero-length channel",
		setup = function() start("channel", 0, 0) end,
		check = function()
			local ok, err = pcall(bar.OnUpdate, bar)
			add("zero-length channel updates without error", ok, err)
			checkFill("zero-length channel is empty", 0)
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: completion",
		setup = function() start("cast", 1, 5) end,
		check = function()
			add("a finished cast starts fading out", bar.casting == nil and bar.fadeOut == true)
			checkFill("a finished cast is full", 1)
		end,
	}

	-- the flight module runs its timer on the player bar
	local Flight = Quartz3:GetModule("Flight", true)
	if Flight then
		cases[#cases + 1] = {
			name = "cast bar: flight timer",
			setup = function()
				ns.StopSyntheticCast(bar)
				Flight:BeginFlight(100, "Quartz test flight")
			end,
			check = function()
				add("flight timer runs on the player bar", (bar.casting or bar.channeling) and bar.Bar:GetTimerDuration() == bar.duration)
				local fill = fillFraction()
				add("flight timer just started", near(fill, bar.channeling and 1 or 0, 0.02), ("%.3f"):format(fill))
				add("flight timer shows its destination", bar.Text:GetText() == "Quartz test flight", bar.Text:GetText())
			end,
		}
	end

	cases[#cases + 1] = {
		name = "cast bar: cleanup",
		setup = function() stop() end,
		check = function() end,
	}
end
