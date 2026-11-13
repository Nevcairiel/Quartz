--[[
	Development-only tests that drive the real Quartz player cast bar with synthetic casts,
	to check the cast bar template against the native StatusBar. Run as part of /qtest.
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

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

	-- puts the bar into the state UNIT_SPELLCAST_START would, without a real cast
	local function start(kind, duration, elapsed)
		bar.casting = (kind == "cast") or nil
		bar.channeling = (kind == "channel") or nil
		bar.chargeSpell = nil
		bar.startTime = GetTime() - elapsed
		bar.endTime = bar.startTime + duration
		bar.delay = 0
		bar.fadeOut = nil
		bar.stopTime = nil
		bar.Bar:SetMinMaxValues(0, 1)
		bar.Bar:SetStatusBarColor(unpack(Quartz3.db.profile.castingcolor))
		bar.Text:SetText("Quartz test")
		bar:Show()
		bar:SetAlpha(1)
		bar.Spark:Show()
	end

	local function stop()
		bar.casting, bar.channeling, bar.chargeSpell = nil, nil, nil
		bar.fadeOut = nil
		bar.stopTime = nil
		bar.TimeText:SetText("")
		bar:Hide()
	end

	local function checkProgress(name, expected)
		local width = bar.Bar:GetWidth()
		local value = bar.Bar:GetValue()
		add(name .. ": value", near(value, expected, 0.01), ("%.3f, expected %.3f"):format(value, expected))

		local tex = bar.Bar:GetStatusBarTexture()
		local fill = tex:GetRight() - tex:GetLeft()
		add(name .. ": fill width", near(fill, expected * width, 1), ("%.2f, expected %.2f"):format(fill, expected * width))

		local sparkX = bar.Spark:GetCenter() - bar.Bar:GetLeft()
		add(name .. ": spark sits on the fill edge", near(sparkX, fill, 1.5), ("spark %.2f fill %.2f"):format(sparkX, fill))
		add(name .. ": spark is visible", bar.Spark:IsVisible())

		local text = bar.TimeText:GetText()
		add(name .. ": time text is set", text ~= nil and text ~= "", text)
	end

	cases[#cases + 1] = {
		name = "cast bar: cast",
		setup = function() start("cast", 100, 25) end,
		check = function() checkProgress("cast at 25%", 0.25) end,
	}

	cases[#cases + 1] = {
		name = "cast bar: channel",
		setup = function() start("channel", 100, 25) end,
		check = function() checkProgress("channel with 75% left", 0.75) end,
	}

	-- a cast whose start and end time are equal must not feed NaN into the bar
	cases[#cases + 1] = {
		name = "cast bar: zero-length cast",
		setup = function()
			start("cast", 0, -1000)
		end,
		check = function()
			local ok, err = pcall(bar.OnUpdate, bar)
			add("zero-length cast updates without error", ok, err)
			add("zero-length cast shows a full bar", near(bar.Bar:GetValue(), 1), bar.Bar:GetValue())
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: zero-length channel",
		setup = function()
			start("channel", 0, -1000)
		end,
		check = function()
			local ok, err = pcall(bar.OnUpdate, bar)
			add("zero-length channel updates without error", ok, err)
			add("zero-length channel shows an empty bar", near(bar.Bar:GetValue(), 0), bar.Bar:GetValue())
		end,
	}

	cases[#cases + 1] = {
		name = "cast bar: completion",
		setup = function() start("cast", 1, 5) end,
		check = function()
			add("a finished cast starts fading out", bar.casting == nil and bar.fadeOut == true)
			add("a finished cast leaves the bar full", near(bar.Bar:GetValue(), 1), bar.Bar:GetValue())
			stop()
		end,
	}
end
