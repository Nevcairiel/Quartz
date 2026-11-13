--[[
	Development-only probe of Blizzard's AuraContainer, to find out if Quartz can build its aura bars on it.

	/qtest aura         creates a container of aura bars for the target and one for the focus
	/qtest aura check   records what an addon can still read and change on the containers and their
	                    buttons right now. Run it once out of combat and once in combat.
	/qtest aura update  calls UpdateAllAuras() on both containers

	Results are stored in QuartzTestDB.aura. Nothing here is part of Quartz itself.
]]
local _, ns = ...
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")

ns.commands = ns.commands or {}

local issecretvalue = issecretvalue

local WIDTH, HEIGHT = 160, 14

local function desc(...)
	if select("#", ...) == 0 then return "<nothing>" end
	local value = ...
	if issecretvalue and issecretvalue(value) then
		return "<secret " .. type(value) .. ">"
	end
	if type(value) == "number" then
		return ("%.2f"):format(value)
	end
	return tostring(value)
end

local function describeResults(ok, ...)
	if not ok then
		return "ERROR: " .. tostring((...))
	end
	local count = select("#", ...)
	if count == 0 then return "ok" end
	local parts = {}
	for i = 1, count do
		parts[i] = desc((select(i, ...)))
	end
	return table.concat(parts, ", ")
end

-- calls obj:method(...) inside a pcall and describes the result
local function call(obj, name, ...)
	return describeResults(pcall(function(...) return obj[name](obj, ...) end, ...))
end

local lines
local function log(key, value)
	if not lines then return end
	lines[#lines + 1] = key .. " = " .. tostring(value)
end

local function save(section)
	QuartzTestDB = QuartzTestDB or {}
	QuartzTestDB.aura = QuartzTestDB.aura or {}
	QuartzTestDB.aura[#QuartzTestDB.aura + 1] = { section = section, date = date("%H:%M:%S"), lines = lines }
	lines = nil
end

local containers = {}
-- the widgets built inside each button, by container key and group
local built = {}

local DISPEL_COLORS = {
	Magic = CreateColor(0.2, 0.4, 1),
	Curse = CreateColor(0.8, 0, 1),
	Disease = CreateColor(0.6, 0.4, 0),
	Poison = CreateColor(0, 0.8, 0),
	None = CreateColor(1, 0.7, 0),
}

-- builds one aura bar inside a button the container created
local function makeInitializer(unit, group)
	local key = unit .. ":" .. group
	built[key] = {}
	local count = 0

	return function(button)
		count = count + 1
		-- everything is logged for the first button of a group only, the others are built the same way
		local first = count == 1
		local function step(name, ...)
			local result = describeResults(pcall(...))
			if first then log(key .. " init " .. name, result) end
			return not result:find("^ERROR")
		end
		if first then
			log(key .. " init called", ("in combat %s, auras secret %s, object type %s"):format(tostring(InCombatLockdown()), desc(C_Secrets.ShouldAurasBeSecret()), call(button, "GetObjectType")))
		end

		local widgets = { button = button }
		built[key][count] = widgets

		step("button:SetSize", button.SetSize, button, WIDTH, HEIGHT)

		local bar
		step("create status bar", function()
			bar = Quartz3:CreateStatusBar(nil, button)
			bar:SetAllPoints(button)
			bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			if group == "buffs" then
				bar:SetStatusBarColor(0, 0.49, 1)
			else
				bar:SetStatusBarColor(1, 0.7, 0)
			end
			bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
			bar:SetBackdropColor(0, 0, 0)
		end)
		if not bar then return end
		widgets.bar = bar
		step("button:SetDurationBar", button.SetDurationBar, button, bar, { direction = Enum.StatusBarTimerDirection.RemainingTime })

		step("icon", function()
			local icon = button:CreateTexture(nil, "ARTWORK")
			icon:SetSize(HEIGHT, HEIGHT)
			icon:SetPoint("RIGHT", button, "LEFT", -1, 0)
			icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			button:SetIcon(icon)
			widgets.icon = icon
		end)

		step("name text", function()
			local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			name:SetPoint("LEFT", bar, "LEFT", 2, 0)
			name:SetWidth(WIDTH - 50)
			name:SetJustifyH("LEFT")
			name:SetWordWrap(false)
			button:SetSpellName(name)
			widgets.name = name
		end)

		step("time text with the Quartz time formatter", function()
			local timeText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			timeText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
			button:SetDurationText(timeText, { textFormatter = Quartz3.Util.GetTimeFormatter() })
			widgets.timeText = timeText
		end)

		step("stack count text", function()
			local stacks = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			stacks:SetPoint("RIGHT", bar, "RIGHT", -34, 0)
			button:SetApplicationCount(stacks)
			widgets.stacks = stacks
		end)

		if group == "debuffs" then
			-- can the fill of the bar itself be colored by dispel type?
			local options = {
				style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
				showAlways = true,
				customDispelColorMap = DISPEL_COLORS,
			}
			local usedFill = step("dispel color on the bar's fill texture", button.AddDispelTypeTexture, button, bar:GetStatusBarTexture(), options)
			if not usedFill then
				step("dispel color on an overlay texture instead", function()
					local overlay = bar:CreateTexture(nil, "ARTWORK", nil, 1)
					overlay:SetAllPoints(bar:GetStatusBarTexture())
					overlay:SetTexture([[Interface\TargetingFrame\UI-StatusBar]])
					button:AddDispelTypeTexture(overlay, options)
					widgets.overlay = overlay
				end)
			end
		end

		-- the buttons show a tooltip on hover, can that be turned off?
		step("button:EnableMouse(false)", button.EnableMouse, button, false)
		step("button:SetScript('OnEnter') from addon code", button.SetScript, button, "OnEnter", function() end)
	end
end

local function createContainer(unit, index)
	local function step(name, ...)
		local result = describeResults(pcall(...))
		log(unit .. " " .. name, result)
		return not result:find("^ERROR")
	end

	local container
	if not step("CreateFrame('AuraContainer', 'CustomAuraContainerTemplate')", function()
		container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
	end) or not container then
		return
	end
	containers[unit] = container

	step("SetPoint", container.SetPoint, container, "BOTTOMLEFT", UIParent, "CENTER", -420 + (index - 1) * (WIDTH + 40), -40)
	step("SetEditModePreviewEnabled(false)", container.SetEditModePreviewEnabled, container, false)
	step("SetFlowLayoutAxis(Vertical)", container.SetFlowLayoutAxis, container, AnchorUtil.FlowLayoutAxis.Vertical)
	step("SetFlowLayoutAnchorPoint('BOTTOMLEFT')", container.SetFlowLayoutAnchorPoint, container, "BOTTOMLEFT")
	step("SetFlowLayoutGrowthDirection(Right, Up)", container.SetFlowLayoutGrowthDirection, container, AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
	step("SetUnit", container.SetUnit, container, unit)

	-- own auras only, with a duration, shortest remaining time first; buffs before debuffs
	step("AddAuraGroup buffs", container.AddAuraGroup, container, "buffs", "HELPFUL|PLAYER", {
		initializeFrame = makeInitializer(unit, "buffs"),
		candidateFilters = { maxDuration = 86400 },
		sortMethod = AuraContainerSortMethod.ExpirationOnly,
		layout = { elementSpacing = 1, groupSpacing = 1, layoutIndex = 1 },
	})
	step("AddAuraGroup debuffs", container.AddAuraGroup, container, "debuffs", "HARMFUL|PLAYER", {
		initializeFrame = makeInitializer(unit, "debuffs"),
		candidateFilters = { maxDuration = 86400 },
		sortMethod = AuraContainerSortMethod.ExpirationOnly,
		layout = { elementSpacing = 1, groupSpacing = 1, layoutIndex = 2 },
	})
	step("Show", container.Show, container)

	local label = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", UIParent, "CENTER", -420 + (index - 1) * (WIDTH + 40), -44)
	label:SetText("Quartz aura probe: " .. unit)
	container.probeLabel = label
end

local function create()
	if next(containers) then
		print("|cff40c0ffQuartz aura:|r the containers already exist. /qtest aura check records their state.")
		return
	end
	lines = {}
	log("in combat", tostring(InCombatLockdown()))
	log("ShouldAurasBeSecret", desc(C_Secrets.ShouldAurasBeSecret()))
	log("Blizzard_AuraContainer loaded", describeResults(pcall(C_AddOns.IsAddOnLoaded, "Blizzard_AuraContainer")))
	createContainer("target", 1)
	createContainer("focus", 2)
	save("create")
	print("|cff40c0ffQuartz aura:|r containers created, left of the screen center. Target and focus units with your own auras, then /qtest aura check out of combat and again in combat.")
end
ns.commands["aura"] = create

local function check()
	if not next(containers) then
		print("|cff40c0ffQuartz aura:|r run /qtest aura first.")
		return
	end
	lines = {}
	log("in combat", tostring(InCombatLockdown()))
	log("ShouldAurasBeSecret", desc(C_Secrets.ShouldAurasBeSecret()))

	for unit, container in pairs(containers) do
		log(unit .. " UnitExists", desc(UnitExists(unit)))
		log(unit .. " container:IsShown", call(container, "IsShown"))
		log(unit .. " container:GetSize", call(container, "GetSize"))
		log(unit .. " container:GetLeft", call(container, "GetLeft"))
		-- can the container still be moved and restyled?
		log(unit .. " container:SetAlpha(1)", call(container, "SetAlpha", 1))
		log(unit .. " container:SetScale(1)", call(container, "SetScale", 1))

		for _, group in ipairs({ "buffs", "debuffs" }) do
			local key = unit .. ":" .. group
			log(key .. " GetAuraGroupFrameCount", call(container, "GetAuraGroupFrameCount", group))
			log(key .. " initialized buttons", #built[key])

			local shown, unreadable = 0, 0
			for _, widgets in ipairs(built[key]) do
				local ok, isShown = pcall(widgets.button.IsShown, widgets.button)
				if not ok or (issecretvalue and issecretvalue(isShown)) then
					unreadable = unreadable + 1
				elseif isShown then
					shown = shown + 1
				end
			end
			log(key .. " buttons shown", ("%d shown, %d not readable"):format(shown, unreadable))

			-- what can still be read and changed on the first button and the widgets inside it?
			local widgets = built[key][1]
			if widgets then
				log(key .. " button:GetSize", call(widgets.button, "GetSize"))
				log(key .. " button:SetSize (restyle)", call(widgets.button, "SetSize", WIDTH, HEIGHT))
				log(key .. " button:GetPoint", call(widgets.button, "GetPoint", 1))
				log(key .. " bar:GetWidth", call(widgets.bar, "GetWidth"))
				log(key .. " bar:GetValue", call(widgets.bar, "GetValue"))
				log(key .. " bar:SetStatusBarTexture (restyle)", call(widgets.bar, "SetStatusBarTexture", [[Interface\TargetingFrame\UI-StatusBar]]))
				log(key .. " bar:SetHeight (restyle)", call(widgets.bar, "SetHeight", HEIGHT))
				if group == "buffs" then
					log(key .. " bar:SetStatusBarColor (restyle)", call(widgets.bar, "SetStatusBarColor", 0, 0.49, 1))
				end
				log(key .. " bar:GetStatusBarColor", call(widgets.bar, "GetStatusBarColor"))
				if widgets.name then
					log(key .. " name:GetText", call(widgets.name, "GetText"))
					log(key .. " name:SetFont (restyle)", call(widgets.name, "SetFont", [[Fonts\FRIZQT__.TTF]], 10, ""))
					log(key .. " name:SetTextColor (restyle)", call(widgets.name, "SetTextColor", 1, 1, 1))
				end
				if widgets.timeText then
					log(key .. " time:GetText", call(widgets.timeText, "GetText"))
					log(key .. " time:SetFont (restyle)", call(widgets.timeText, "SetFont", [[Fonts\FRIZQT__.TTF]], 10, ""))
				end
				if widgets.icon then
					log(key .. " icon:SetSize (restyle)", call(widgets.icon, "SetSize", HEIGHT, HEIGHT))
				end
			end
		end
		-- can the group be reconfigured?
		log(unit .. " SetAuraGroupLayout", call(container, "SetAuraGroupLayout", "buffs", { elementSpacing = 1, groupSpacing = 1, layoutIndex = 1 }))
		log(unit .. " SetAuraGroupSortMethod", call(container, "SetAuraGroupSortMethod", "buffs", AuraContainerSortMethod.ExpirationOnly, AuraContainerSortDirection.Normal))
	end
	save("check")
	print(("|cff40c0ffQuartz aura:|r state recorded (%s). /reload when done to write it to disk."):format(InCombatLockdown() and "in combat" or "out of combat"))
end
ns.commands["aura check"] = check

local function update()
	lines = {}
	for unit, container in pairs(containers) do
		log(unit .. " UpdateAllAuras", call(container, "UpdateAllAuras"))
	end
	save("update")
	print("|cff40c0ffQuartz aura:|r UpdateAllAuras called.")
end
ns.commands["aura update"] = update
