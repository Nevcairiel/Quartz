--[[
	Development-only tests for Quartz3:CreateStatusBar.

	/qtest       run the tests; results are printed and stored in QuartzTestDB
	/qtest hide  hide the comparison bars

	The tests compare the native StatusBar returned by Quartz3:CreateStatusBar against
	the previous hand-rolled implementation, which is kept below as the reference.
	After a run, /reload writes QuartzTestDB to WTF/Account/<account>/SavedVariables/Quartz_Tests.lua
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

----------------------------
-- Reference: the implementation QuartzStatusBar.lua had before the switch to a native StatusBar

local CreateReferenceBar
do
	local Reference = CreateFrame("Frame")
	local MetaTable = {__index = Reference}

	Reference.__min = 0
	Reference.__max = 100
	Reference.__value = 0

	local function UpdateBarValue(self)
		local perc = 0
		if self.__max ~= self.__min then
			perc = (self.__value - self.__min) / (self.__max - self.__min)
		end
		perc = min(max(perc, 0), 1)
		local width = self:GetWidth()
		self.__texture:SetPoint("RIGHT", self, "LEFT", perc * width, 0)
		self.__texture:SetTexCoord(0, perc, 0, 1)
	end

	local function DrawBar(self)
		self.__texture:ClearAllPoints()
		self.__texture:SetPoint("TOPLEFT", self, "TOPLEFT")
		self.__texture:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
		local r, g, b, a = 1, 1, 1, 1
		if self.__color then
			if #self.__color == 3 then
				r, g, b = unpack(self.__color)
			elseif #self.__color == 4 then
				r, g, b, a = unpack(self.__color)
			end
		end
		self.__texture:SetVertexColor(r, g, b, a)
		UpdateBarValue(self)
	end

	function Reference:SetMinMaxValues(minValue, maxValue)
		self.__min = tonumber(minValue)
		self.__max = tonumber(maxValue)
		UpdateBarValue(self)
	end

	function Reference:SetValue(value)
		self.__value = tonumber(value)
		UpdateBarValue(self)
	end

	function Reference:SetStatusBarColor(r, g, b, a)
		self.__color = {r, g, b, a}
		DrawBar(self)
	end

	function Reference:GetStatusBarTexture()
		return self.__texture
	end

	function Reference:SetStatusBarTexture(texture)
		self.__texture:SetTexture(texture)
		self.__texture:SetDrawLayer("ARTWORK")
	end

	function CreateReferenceBar(name, parent)
		local bar = setmetatable(CreateFrame("Frame", name, parent, "BackdropTemplate"), MetaTable)
		bar.__texture = bar:CreateTexture(nil, "ARTWORK")
		bar.__texture:SetTexture([[Interface\TargetingFrame\UI-StatusBar]])
		DrawBar(bar)
		return bar
	end
end

----------------------------
-- Harness

local WIDTH, HEIGHT = 200, 20
local TOLERANCE = 0.5 -- pixels
local TEX_PLAIN = [[Interface\TargetingFrame\UI-StatusBar]]
local TEX_PATTERN = [[Interface\Icons\INV_Misc_QuestionMark]] -- non-uniform, shows cropping vs stretching

local holder, ref, new
local results
local running

local function add(name, pass, detail)
	local status = "INFO"
	if pass ~= nil then
		status = pass and "PASS" or "FAIL"
	end
	results[#results + 1] = { name = name, status = status, detail = detail ~= nil and tostring(detail) or nil }
end

local function try(name, func)
	local ok, err = pcall(func)
	if not ok then
		add(name, false, "error: " .. tostring(err))
	end
end

local function near(a, b, tolerance)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tolerance or 0.001)
end

-- width of the visible fill, in the bar's coordinate space
local function fillWidth(bar)
	local tex = bar:GetStatusBarTexture()
	if not tex or not tex:IsShown() then return 0 end
	local left, right = tex:GetLeft(), tex:GetRight()
	if not left or not right then return 0 end
	return right - left
end

-- left and right horizontal texture coordinates of the fill
local function fillCoords(bar)
	local ULx, _, _, _, URx = bar:GetStatusBarTexture():GetTexCoord()
	return ULx, URx
end

local function createBars()
	if holder then holder:Hide() end

	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(WIDTH + 80, HEIGHT * 2 + 30)
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, 220)

	local function label(bar, text)
		local fs = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		fs:SetPoint("RIGHT", bar, "LEFT", -6, 0)
		fs:SetText(text)
	end

	ref = CreateReferenceBar(nil, holder)
	ref:SetSize(WIDTH, HEIGHT)
	ref:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
	label(ref, "old")

	new = Quartz3:CreateStatusBar(nil, holder)
	-- defaults must be read before anything else touches the bar
	try("defaults", function()
		local minValue, maxValue = new:GetMinMaxValues()
		add("default min/max is 0/100", minValue == 0 and maxValue == 100, ("%s/%s"):format(tostring(minValue), tostring(maxValue)))
		add("default value is 0", new:GetValue() == 0, new:GetValue())
		add("object type is StatusBar", new:GetObjectType() == "StatusBar", new:GetObjectType())
		local tex = new:GetStatusBarTexture()
		add("has a texture after creation", tex ~= nil)
		add("texture draw layer is ARTWORK", tex and tex:GetDrawLayer() == "ARTWORK", tex and tex:GetDrawLayer())
		add("default orientation", nil, new:GetOrientation())
		add("default fill style", nil, new:GetFillStyle())
	end)
	new:SetSize(WIDTH, HEIGHT)
	new:SetPoint("TOPRIGHT", ref, "BOTTOMRIGHT", 0, -10)
	label(new, "new")

	for _, bar in ipairs({ref, new}) do
		bar:SetStatusBarTexture(TEX_PLAIN)
		bar:SetStatusBarColor(0.2, 0.8, 0.2)
	end
end

local function immediateChecks()
	try("backdrop", function()
		add("SetBackdrop exists on the bar", type(new.SetBackdrop) == "function")
		new:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		new:SetBackdropColor(0, 0, 0)
		ref:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		ref:SetBackdropColor(0, 0, 0)
		add("SetBackdrop/SetBackdropColor run without error", true)
	end)

	try("color", function()
		new:SetStatusBarColor(0.2, 0.4, 0.6)
		local r, g, b, a = new:GetStatusBarColor()
		add("GetStatusBarColor round-trips rgb", near(r, 0.2) and near(g, 0.4) and near(b, 0.6), ("%s %s %s %s"):format(tostring(r), tostring(g), tostring(b), tostring(a)))
		add("alpha defaults to 1", near(a, 1), a)
		local tr, tg, tb, ta = new:GetStatusBarTexture():GetVertexColor()
		add("texture vertex color follows bar color", near(tr, 0.2) and near(tg, 0.4) and near(tb, 0.6), ("%s %s %s %s"):format(tostring(tr), tostring(tg), tostring(tb), tostring(ta)))
		new:SetStatusBarColor(0.2, 0.4, 0.6, 0.5)
		-- colors are stored with 8 bits per channel, so 0.5 comes back as 128/255
		add("alpha argument is applied", near(select(4, new:GetStatusBarColor()), 0.5, 1/255), select(4, new:GetStatusBarColor()))
		new:SetStatusBarColor(0.2, 0.8, 0.2, 1)
	end)

	try("texture swap", function()
		local before = new:GetStatusBarTexture()
		new:SetStatusBarColor(0.2, 0.4, 0.6, 1)
		local success = new:SetStatusBarTexture(TEX_PATTERN)
		local after = new:GetStatusBarTexture()
		add("SetStatusBarTexture return value", nil, success)
		add("texture object is kept across SetStatusBarTexture", before == after)
		add("draw layer is kept across SetStatusBarTexture", after:GetDrawLayer() == "ARTWORK", after:GetDrawLayer())
		local r, g, b = after:GetVertexColor()
		add("color is kept across SetStatusBarTexture", near(r, 0.2) and near(g, 0.4) and near(b, 0.6), ("%s %s %s"):format(tostring(r), tostring(g), tostring(b)))
		new:SetStatusBarTexture(TEX_PLAIN)
		new:SetStatusBarColor(0.2, 0.8, 0.2, 1)
	end)

	try("value storage", function()
		new:SetMinMaxValues(0, 1)
		new:SetValue(0.25)
		add("GetValue returns the set value", near(new:GetValue(), 0.25), new:GetValue())
		new:SetValue(1.5)
		add("GetValue after setting above max", nil, new:GetValue())
		new:SetValue(-0.5)
		add("GetValue after setting below min", nil, new:GetValue())
	end)

	-- how the native widget reacts to input the old implementation tolerated
	add("SetValue(NaN) raises an error", nil, not pcall(new.SetValue, new, 0/0))
	add("SetValue('0.5') raises an error", nil, not pcall(new.SetValue, new, "0.5"))
	add("SetMinMaxValues(1, 0) raises an error", nil, not pcall(new.SetMinMaxValues, new, 1, 0))
	new:SetMinMaxValues(0, 1)
	new:SetValue(0)
end

-- each case: setup now, check after the layout had time to settle
local function buildCases()
	local cases = {}

	local function sweep(minValue, maxValue, value, note)
		local name = ("fill min=%s max=%s value=%s%s"):format(tostring(minValue), tostring(maxValue), tostring(value), note and (" (" .. note .. ")") or "")
		cases[#cases + 1] = {
			name = name,
			setup = function()
				for _, bar in ipairs({ref, new}) do
					bar:SetMinMaxValues(minValue, maxValue)
					bar:SetValue(value)
				end
			end,
			check = function()
				local refWidth, newWidth = fillWidth(ref), fillWidth(new)
				add(name .. ": width", near(refWidth, newWidth, TOLERANCE), ("old %.2f new %.2f"):format(refWidth, newWidth))
				if refWidth > 0 and newWidth > 0 then
					local refL, refR = fillCoords(ref)
					local newL, newR = fillCoords(new)
					add(name .. ": texcoords", near(refL, newL, 0.005) and near(refR, newR, 0.005), ("old %.3f-%.3f new %.3f-%.3f"):format(refL, refR, newL, newR))
				end
			end,
		}
	end

	-- cast bars, swing: 0-1 range
	for _, value in ipairs({0, 0.1, 0.25, 0.5, 0.75, 1}) do
		sweep(0, 1, value)
	end
	sweep(0, 1, -0.5, "below min")
	sweep(0, 1, 1.5, "above max")
	-- tradeskill: 0-total range
	sweep(0, 37.5, 12.5)
	-- arbitrary offset range
	sweep(10, 20, 15)
	sweep(10, 20, 5, "below min")
	sweep(10, 20, 25, "above max")
	-- buff, mirror and enemy bars use GetTime() based ranges; large values stress number precision
	local now = GetTime()
	sweep(now, now + 10, now + 3.3, "GetTime range")
	sweep(now, now + 1.5, now + 0.5, "GetTime range, short")
	sweep(2000000, 2000001.5, 2000000.5, "large uptime, short")
	-- empty ranges
	sweep(5, 5, 5, "zero range")
	sweep(0, 0, 0, "zero range at zero")

	cases[#cases + 1] = {
		name = "resize",
		setup = function()
			new:SetMinMaxValues(0, 1)
			new:SetValue(0.5)
			new:SetWidth(WIDTH + 100)
		end,
		check = function()
			local width = fillWidth(new)
			add("fill follows a width change", near(width, (WIDTH + 100) / 2, TOLERANCE), ("%.2f, expected %.2f"):format(width, (WIDTH + 100) / 2))
			new:SetWidth(WIDTH)
		end,
	}

	-- the real player cast bar, driven with synthetic casts
	local ok, err = pcall(ns.AddCastBarCases, cases, add, near)
	if not ok then
		add("cast bar tests", false, "error: " .. tostring(err))
	end

	-- leave both bars half full with a non-uniform texture for a visual comparison
	cases[#cases + 1] = {
		name = "visual",
		setup = function()
			for _, bar in ipairs({ref, new}) do
				bar:SetStatusBarTexture(TEX_PATTERN)
				bar:SetStatusBarColor(1, 1, 1)
				bar:SetMinMaxValues(0, 1)
				bar:SetValue(0.5)
			end
		end,
		check = function()
			local refL, refR = fillCoords(ref)
			local newL, newR = fillCoords(new)
			add("half-full pattern texture is cropped, not stretched", near(refL, newL, 0.005) and near(refR, newR, 0.005), ("old %.3f-%.3f new %.3f-%.3f"):format(refL, refR, newL, newR))
		end,
	}

	return cases
end

local function finish()
	local counts = { PASS = 0, FAIL = 0, INFO = 0 }
	for _, result in ipairs(results) do
		counts[result.status] = counts[result.status] + 1
		if result.status ~= "PASS" then
			local color = result.status == "FAIL" and "|cffff4040" or "|cffffd040"
			print(("%s%s|r %s%s"):format(color, result.status, result.name, result.detail and (": " .. result.detail) or ""))
		end
	end
	print(("|cff40c0ffQuartz tests:|r %d passed, %d failed, %d info. /reload to write the results to disk, /qtest hide to remove the bars."):format(counts.PASS, counts.FAIL, counts.INFO))

	local version, build, _, interface = GetBuildInfo()
	QuartzTestDB = QuartzTestDB or {}
	QuartzTestDB.statusbar = {
		client = ("%s (%s) interface %s"):format(tostring(version), tostring(build), tostring(interface)),
		date = date("%Y-%m-%d %H:%M:%S"),
		passed = counts.PASS,
		failed = counts.FAIL,
		info = counts.INFO,
		results = results,
	}
	running = nil
end

local function runCases(cases, index)
	local case = cases[index]
	if not case then
		return finish()
	end
	local ok, err = pcall(case.setup)
	if not ok then
		add(case.name, false, "setup error: " .. tostring(err))
		return runCases(cases, index + 1)
	end
	C_Timer.After(0.1, function()
		try(case.name, case.check)
		runCases(cases, index + 1)
	end)
end

local function run()
	if running then
		print("|cff40c0ffQuartz tests:|r already running.")
		return
	end
	running = true
	results = {}
	print("|cff40c0ffQuartz tests:|r running, this takes a few seconds...")

	local ok, err = pcall(createBars)
	if not ok then
		add("create bars", false, "error: " .. tostring(err))
		return finish()
	end
	immediateChecks()
	-- give the new frames one layout pass before measuring
	C_Timer.After(0.1, function()
		runCases(buildCases(), 1)
	end)
end

SLASH_QUARTZTEST1 = "/qtest"
SlashCmdList["QUARTZTEST"] = function(msg)
	msg = (msg or ""):lower():trim()
	if msg == "hide" then
		if holder then holder:Hide() end
		if ns.HideProbe then ns.HideProbe() end
	elseif msg == "" then
		run()
	elseif ns.commands and ns.commands[msg] then
		ns.commands[msg]()
	else
		print("|cff40c0ffQuartz tests:|r /qtest, /qtest probe, /qtest record, /qtest gcd, /qtest sent, /qtest aura, /qtest swing, /qtest baseline, /qtest hide")
	end
end
