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

-- The Buff module for clients where aura information is secret.
--
-- The bars are provided by Blizzards AuraContainer. It creates a button for every aura, which we fill with
-- the pieces of a bar. The container then drives those pieces from the aura, we never get to see the aura
-- ourselves. That also means the buttons can only be touched while auras are not secret, any change of the
-- look of the bars during combat is applied once combat is over.
local MODNAME = "Buff"
local Buff = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceTimer-3.0")
local Player = Quartz3:GetModule("Player")
local Focus = Quartz3:GetModule("Focus", true)
local Target = Quartz3:GetModule("Target", true)

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = AceGUIWidgetLSMlists

----------------------------
-- Upvalues
local CreateFrame, UIParent = CreateFrame, UIParent
local unpack, pairs, ipairs = unpack, pairs, ipairs

local UNITS = { "target", "focus" }
local GROUPS = { "buffs", "debuffs" }
local FILTERS = { buffs = "HELPFUL|PLAYER", debuffs = "HARMFUL|PLAYER" }

-- Auras without a duration are not shown, which is what any maximum duration does to them
local MAX_DURATION = 365 * 24 * 60 * 60

-- the aura container of a unit
local containers = {}
-- a frame to move the bars of a unit with, while they are unlocked
local movers = {}
-- the pieces of every bar the containers created
local bars = {}

local locked = { target = true, focus = true }

-- set if the look of the bars has to be applied once auras are no longer secret
local stylePending = false

local db

local defaults = {
	profile = {
		target = true,
		targetbuffs = true,
		targetdebuffs = true,
		targeticons = true,
		targeticonside = "right",

		targetanchor = "player",--L["Free"], L["Target"], L["Focus"]
		targetx = 500,
		targety = 350,
		targetgrowdirection = "up", --L["Down"]
		targetposition = "topright",

		targetgap = 1,
		targetspacing = 1,
		targetoffset = 3,

		targetwidth = 120,
		targetheight = 12,

		focus = true,
		focusbuffs = true,
		focusdebuffs = true,
		focusicons = true,
		focusiconside = "left",

		focusanchor = "player",--L["Free"], L["Target"], L["Focus"]
		focusx = 400,
		focusy = 350,
		focusgrowdirection = "up", --L["Down"]
		focusposition = "bottomleft",

		focusgap = 1,
		focusspacing = 1,
		focusoffset = 3,

		focuswidth = 120,
		focusheight = 12,

		buffnametext = true,
		bufftimetext = true,

		bufftexture = "LiteStep",
		bufffont = "Friz Quadrata TT",
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
	}
}

local getOptions
do
	local positions = {
		["bottom"] = L["Bottom"],
		["top"] = L["Top"],
		["topleft"] = L["Top Left"],
		["topright"] = L["Top Right"],
		["bottomleft"] = L["Bottom Left"],
		["bottomright"] = L["Bottom Right"],
		["leftup"] = L["Left (grow up)"],
		["leftdown"] = L["Left (grow down)"],
		["rightup"] = L["Right (grow up)"],
		["rightdown"] = L["Right (grow down)"],
	}

	local function hidedebuffsbytype()
		return not db.debuffsbytype
	end

	local function hidedebuffsnottype()
		return db.debuffsbytype
	end

	local function gettargetfreeoptionshidden()
		return db.targetanchor ~= "free"
	end

	local function gettargetnotfreeoptionshidden()
		return db.targetanchor == "free"
	end

	local function getfocusfreeoptionshidden()
		return db.focusanchor ~= "free"
	end
	local function getfocusnotfreeoptionshidden()
		return db.focusanchor == "free"
	end
	local function setOpt(info, value)
		db[info.arg or info[#info]] = value
		Buff:ApplySettings()
	end

	local function getOpt(info)
		return db[info.arg or info[#info]]
	end

	local function setOptFocus(info, value)
		db[info.arg or ("focus"..info[#info])] = value
		Buff:ApplySettings()
	end

	local function getOptFocus(info)
		return db[info.arg or ("focus"..info[#info])]
	end

	local function setOptTarget(info, value)
		db[info.arg or ("target"..info[#info])] = value
		Buff:ApplySettings()
	end

	local function getOptTarget(info)
		return db[info.arg or ("target"..info[#info])]
	end

	local function getColor(info)
		return unpack(getOpt(info))
	end

	local function setColor(info, r, g, b, a)
		setOpt(info, {r, g, b, a})
	end

	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Buff"],
				order = 600,
				get = getOpt,
				set = setOpt,
				childGroups = "tab",
				args = {
					toggle = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enable"],
						get = function()
							return Quartz3:GetModuleEnabled(MODNAME)
						end,
						set = function(info, v)
							Quartz3:SetModuleEnabled(MODNAME, v)
						end,
						order = 100,
					},
					focus = {
						type = "group",
						name = L["Focus"],
						desc = L["Focus"],
						order = 101,
						get = getOptFocus,
						set = setOptFocus,
						args = {
							show = {
								type = "toggle",
								name = L["Enable %s"]:format(L["Focus"]),
								desc = L["Show buffs/debuffs for your %s"]:format(L["Focus"]),
								arg = "focus",
								order = 90,
								width = "full",
								disabled = false,
							},
							buffs = {
								type = "toggle",
								name = L["Enable Buffs"],
								desc = L["Show buffs for your %s"]:format(L["Focus"]),
								order = 91,
							},
							debuffs = {
								type = "toggle",
								name = L["Enable Debuffs"],
								desc = L["Show debuffs for your %s"]:format(L["Focus"]),
								order = 92,
							},
							nlf = {
								type = "description",
								name = "",
								order = 100,
							},
							width = {
								type = "range",
								name = L["Buff Bar Width"],
								desc = L["Set the width of the buff bars"],
								min = 50, max = 300, step = 1,
								order = 101,
							},
							height = {
								type = "range",
								name = L["Buff Bar Height"],
								desc = L["Set the height of the buff bars"],
								min = 4, max = 25, step = 1,
								order = 101,
							},
							anchor = {
								type = "select",
								name = L["Anchor Frame"],
								desc = L["Select where to anchor the %s bars"]:format(L["Focus"]),
								values = {["player"] = L["Player"], ["free"] = L["Free"], ["target"] = L["Target"], ["focus"] = L["Focus"]},
								order = 102,
							},
							-- free
							focuslock = {
								type = "toggle",
								name = L["Lock"],
								desc = L["Toggle %s bar lock"]:format(L["Focus"]),
								get = function()
									return locked.focus
								end,
								set = function(info, v)
									Buff:SetLocked("focus", v)
								end,
								hidden = getfocusfreeoptionshidden,
								order = 103,
							},
							x = {
								type = "range",
								name = L["X"],
								desc = L["Set an exact X value for this bar's position."],
								min = 0, max = 2560, step = 1,
								hidden = getfocusfreeoptionshidden,
								order = 104,
							},
							y = {
								type = "range",
								name = L["Y"],
								desc = L["Set an exact Y value for this bar's position."],
								min = 0, max = 1600, step = 1,
								hidden = getfocusfreeoptionshidden,
								order = 104,
							},
							growdirection = {
								type = "select",
								name = L["Grow Direction"],
								desc = L["Set the grow direction of the %s bars"]:format(L["Focus"]),
								values = {["up"] = L["Up"], ["down"] = L["Down"]},
								hidden = getfocusfreeoptionshidden,
								order = 105,
							},
							-- anchored to a cast bar
							position = {
								type = "select",
								name = L["Position"],
								desc = L["Position the bars for your %s"]:format(L["Focus"]),
								values = positions,
								hidden = getfocusnotfreeoptionshidden,
								order = 103,
							},
							gap = {
								type = "range",
								name = L["Gap"],
								desc = L["Tweak the vertical position of the bars for your %s"]:format(L["Focus"]),
								min = -35, max = 35, step = 1,
								hidden = getfocusnotfreeoptionshidden,
								order = 104,
							},
							offset = {
								type = "range",
								name = L["Offset"],
								desc = L["Tweak the horizontal position of the bars for your %s"]:format(L["Focus"]),
								min = -35, max = 35,step = 1,
								hidden = getfocusnotfreeoptionshidden,
								order = 106,
							},
							spacing = {
								type = "range",
								name = L["Spacing"],
								desc = L["Tweak the space between bars for your %s"]:format(L["Focus"]),
								min = -35, max = 35, step = 1,
								order = 107,
							},
							nli = {
								type = "description",
								name = "",
								order = 108,
							},
							icons = {
								type = "toggle",
								name = L["Show Icons"],
								desc = L["Show icons on buffs and debuffs for your %s"]:format(L["Focus"]),
								order = 109,
							},
							iconside = {
								type = "select",
								name = L["Icon Position"],
								desc = L["Set the side of the buff bar that the icon appears on"],
								values = {["left"] = L["Left"], ["right"] = L["Right"]},
								order = 110,
							},
						},
					},
					target = {
						type = "group",
						name = L["Target"],
						desc = L["Target"],
						order = 102,
						get = getOptTarget,
						set = setOptTarget,
						args = {
							show = {
								type = "toggle",
								name = L["Enable %s"]:format(L["Target"]),
								desc = L["Show buffs/debuffs for your %s"]:format(L["Target"]),
								arg = "target",
								disabled = false,
								width = "full",
								order = 90,
							},
							buffs = {
								type = "toggle",
								name = L["Enable Buffs"],
								desc = L["Show buffs for your %s"]:format(L["Target"]),
								order = 91,
							},
							debuffs = {
								type = "toggle",
								name = L["Enable Debuffs"],
								desc = L["Show debuffs for your %s"]:format(L["Target"]),
								order = 92,
							},
							nlf = {
								type = "description",
								name = "",
								order = 100,
							},
							width = {
								type = "range",
								name = L["Buff Bar Width"],
								desc = L["Set the width of the buff bars"],
								min = 50, max = 300, step = 1,
								order = 101,
							},
							height = {
								type = "range",
								name = L["Buff Bar Height"],
								desc = L["Set the height of the buff bars"],
								min = 4, max = 25, step = 1,
								order = 101,
							},
							anchor = {
								type = "select",
								name = L["Anchor Frame"],
								desc = L["Select where to anchor the %s bars"]:format(L["Target"]),
								values = {["player"] = L["Player"], ["free"] = L["Free"], ["target"] = L["Target"], ["focus"] = L["Focus"]},
								order = 102,
							},
							-- free
							targetlock = {
								type = "toggle",
								name = L["Lock"],
								desc = L["Toggle %s bar lock"]:format(L["Target"]),
								get = function()
									return locked.target
								end,
								set = function(info, v)
									Buff:SetLocked("target", v)
								end,
								hidden = gettargetfreeoptionshidden,
								order = 103,
							},
							x = {
								type = "range",
								name = L["X"],
								desc = L["Set an exact X value for this bar's position."],
								min = 0, max = 2560, bigStep = 1,
								hidden = gettargetfreeoptionshidden,
								order = 104,
							},
							y = {
								type = "range",
								name = L["Y"],
								desc = L["Set an exact Y value for this bar's position."],
								min = 0, max = 1600, bigStep = 1,
								hidden = gettargetfreeoptionshidden,
								order = 104,
							},
							growdirection = {
								type = "select",
								name = L["Grow Direction"],
								desc = L["Set the grow direction of the %s bars"]:format(L["Target"]),
								values = {["up"] = L["Up"], ["down"] = L["Down"]},
								hidden =  gettargetfreeoptionshidden,
								order = 105,
							},
							-- anchored to a cast bar
							position = {
								type = "select",
								name = L["Position"],
								desc = L["Position the bars for your %s"]:format(L["Target"]),
								values = positions,
								hidden = gettargetnotfreeoptionshidden,
								order = 103,
							},
							gap = {
								type = "range",
								name = L["Gap"],
								desc = L["Tweak the vertical position of the bars for your %s"]:format(L["Target"]),
								min = -35, max = 35, step = 1,
								hidden = gettargetnotfreeoptionshidden,
								order = 104,
							},
							offset = {
								type = "range",
								name = L["Offset"],
								desc = L["Tweak the horizontal position of the bars for your %s"]:format(L["Target"]),
								min = -35, max = 35, step = 1,
								hidden = gettargetnotfreeoptionshidden,
								order = 106,
							},
							spacing = {
								type = "range",
								name = L["Spacing"],
								desc = L["Tweak the space between bars for your %s"]:format(L["Target"]),
								min = -35, max = 35, step = 1,
								order = 107,
							},
							nli = {
								type = "description",
								name = "",
								order = 108,
							},
							icons = {
								type = "toggle",
								name = L["Show Icons"],
								desc = L["Show icons on buffs and debuffs for your %s"]:format(L["Target"]),
								order = 109,
							},
							iconside = {
								type = "select",
								name = L["Icon Position"],
								desc = L["Set the side of the buff bar that the icon appears on"],
								values = {["left"] = L["Left"], ["right"] = L["Right"]},
								order = 110,
							},
						},
					},
					settings = {
						type = "group",
						name = L["Settings"],
						order = 1,
						args = {
							timesort = {
								type = "toggle",
								name = L["Sort by Remaining Time"],
								desc = L["Sort the buffs and debuffs by time remaining.  If unchecked, they will be sorted alphabetically."],
								order = 103,
								width = "full",
							},
							buffnametext = {
								type = "toggle",
								name = L["Buff Name Text"],
								desc = L["Display the names of buffs/debuffs on their bars"],
								order = 106,
							},
							bufftimetext = {
								type = "toggle",
								name = L["Buff Time Text"],
								desc = L["Display the time remaining on buffs/debuffs on their bars"],
								order = 107,
							},
							bufffont = {
								type = "select",
								dialogControl = "LSM30_Font",
								name = L["Font"],
								desc = L["Set the font used in the buff bars"],
								values = lsmlist.font,
								order = 108,
							},
							bufftexture = {
								type = "select",
								dialogControl = "LSM30_Statusbar",
								name = L["Texture"],
								desc = L["Set the buff bar Texture"],
								values = lsmlist.statusbar,
								order = 109,
							},
							bufftextcolor = {
								type = "color",
								name = L["Text Color"],
								desc = L["Set the color of the text for the buff bars"],
								order = 110,
								width = "full",
								get = getColor,
								set = setColor,
							},
							bufffontsize = {
								type = "range",
								name = L["Font Size"],
								desc = L["Set the font size for the buff bars"],
								min = 3, max = 15, step = 1,
								order = 111,
							},
							buffalpha = {
								type = "range",
								name = L["Alpha"],
								desc = L["Set the alpha of the buff bars"],
								min = 0.05, max = 1, step = 0.05,
								isPercent = true,
								order = 112,
							},
						},
					},
					colors = {
						type = "group",
						name = L["Colors"],
						desc = L["Colors"],
						order = -1,
						args = {
							buffcolor = {
								type = "color",
								name = L["Buff Color"],
								desc = L["Set the color of the bars for buffs"],
								get = getColor,
								set = setColor,
							},
							debuffsbytype = {
								type = "toggle",
								name = L["Debuffs by Type"],
								desc = L["Color debuff bars according to their dispel type"],
								order = 101,
							},
							debuffcolor = {
								type = "color",
								name = L["Debuff Color"],
								desc = L["Set the color of the bars for debuffs"],
								get = getColor,
								set = setColor,
								disabled = hidedebuffsnottype,
								order = 102,
							},
							physcolor = {
								type = "color",
								name = L["Undispellable Color"],
								desc = L["Set the color of the bars for undispellable debuffs"],
								get = getColor,
								set = setColor,
								arg = "debuffcolor",
								disabled = hidedebuffsbytype,
								order = 102,
							},
							Curse = {
								type = "color",
								name = L["Curse Color"],
								desc = L["Set the color of the bars for curses"],
								get = getColor,
								set = setColor,
								disabled = hidedebuffsbytype,
								order = 103,
							},
							Disease = {
								type = "color",
								name = L["Disease Color"],
								desc = L["Set the color of the bars for diseases"],
								get = getColor,
								set = setColor,
								disabled = hidedebuffsbytype,
								order = 104,
							},
							Magic = {
								type = "color",
								name = L["Magic Color"],
								desc = L["Set the color of the bars for magic"],
								get = getColor,
								set = setColor,
								disabled = hidedebuffsbytype,
								order = 105,
							},
							Poison = {
								type = "color",
								name = L["Poison Color"],
								desc = L["Set the color of the bars for poisons"],
								get = getColor,
								set = setColor,
								disabled = hidedebuffsbytype,
								order = 106,
							},
						},
					},
				}
			}
		end
		return options
	end
end

----------------------------
-- Bars

-- measures text, which can not be done on the texts of the bars
local measureText

local function GetTimeTextWidth()
	if not measureText then
		measureText = UIParent:CreateFontString(nil, "OVERLAY")
		measureText:Hide()
	end
	measureText:SetFont(media:Fetch("font", db.bufffont), db.bufffontsize)
	measureText:SetText("10.0")
	return measureText:GetStringWidth()
end

local function CreateDebuffColor(color)
	return CreateColor(color[1], color[2], color[3], color[4] or 1)
end

-- colors of debuff bars by the dispel type of the debuff, which the container picks from
local function GetDebuffColors()
	local debuffColor = CreateDebuffColor(db.debuffcolor)
	local colors = {
		None = debuffColor,
		Magic = debuffColor,
		Curse = debuffColor,
		Disease = debuffColor,
		Poison = debuffColor,
		Bleed = debuffColor,
	}
	if db.debuffsbytype then
		colors.Magic = CreateDebuffColor(db.Magic)
		colors.Curse = CreateDebuffColor(db.Curse)
		colors.Disease = CreateDebuffColor(db.Disease)
		colors.Poison = CreateDebuffColor(db.Poison)
	end
	return colors
end

local function StyleText(text, height)
	text:SetFont(media:Fetch("font", db.bufffont), db.bufffontsize)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(0.8, -0.8)
	text:SetTextColor(unpack(db.bufftextcolor))
	text:SetNonSpaceWrap(false)
	text:SetHeight(height)
end

-- Applies the settings to a bar. This is only possible while auras are not secret.
local function StyleBar(bar, timeTextWidth, debuffColors)
	local unit = bar.unit
	local width, height = db[unit .. "width"], db[unit .. "height"]

	bar.button:SetSize(width, height)

	local statusBar = bar.statusBar
	statusBar:SetStatusBarTexture(media:Fetch("statusbar", db.bufftexture))
	if bar.group == "buffs" then
		statusBar:SetStatusBarColor(unpack(db.buffcolor))
	else
		-- the container colors the bar by the dispel type of the debuff
		bar.button:ClearDispelTypeTextures()
		bar.button:AddDispelTypeTexture(statusBar:GetStatusBarTexture(), {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showAlways = true,
			customDispelColorMap = debuffColors,
		})
	end

	local timeText = bar.timeText
	StyleText(timeText, height)
	timeText:ClearAllPoints()
	timeText:SetPoint("RIGHT", statusBar, "RIGHT", -2, 0)
	timeText:SetJustifyH("RIGHT")
	timeText:SetShown(db.bufftimetext)
	bar.button:SetDurationText(timeText, { textFormatter = Quartz3.Util.GetTimeFormatter() })

	-- the name and the number of applications are hidden through their alpha, the container shows and hides them
	local nameAlpha = db.buffnametext and 1 or 0
	local textWidth = db.bufftimetext and (width - timeTextWidth) or width

	local countText = bar.countText
	StyleText(countText, height)
	countText:ClearAllPoints()
	countText:SetPoint("RIGHT", statusBar, "LEFT", textWidth - 2, 0)
	countText:SetJustifyH("RIGHT")
	countText:SetAlpha(nameAlpha)

	local nameText = bar.nameText
	StyleText(nameText, height)
	nameText:ClearAllPoints()
	nameText:SetPoint("LEFT", statusBar, "LEFT", 2, 0)
	nameText:SetJustifyH("LEFT")
	nameText:SetWidth(textWidth)
	nameText:SetAlpha(nameAlpha)

	local icon = bar.icon
	icon:SetSize(height - 1, height - 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:ClearAllPoints()
	if db[unit .. "iconside"] == "left" then
		icon:SetPoint("RIGHT", statusBar, "LEFT", -1, 0)
	else
		icon:SetPoint("LEFT", statusBar, "RIGHT", 1, 0)
	end
	icon:SetAlpha(db[unit .. "icons"] and 1 or 0)
end

local function StyleBars()
	local timeTextWidth, debuffColors = GetTimeTextWidth(), GetDebuffColors()
	for _, bar in ipairs(bars) do
		StyleBar(bar, timeTextWidth, debuffColors)
	end
end

-- Called by the container for every button it creates, to fill it with the pieces of a bar.
-- The container creates buttons whenever it runs out of them, which can also be during combat.
local function InitializeBar(unit, group, button)
	local bar = { unit = unit, group = group, button = button }
	bars[#bars + 1] = bar

	-- the buttons show a tooltip of the aura otherwise
	button:EnableMouse(false)

	local statusBar = Quartz3:CreateStatusBar(nil, button)
	statusBar:SetAllPoints(button)
	statusBar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	statusBar:SetBackdropColor(0, 0, 0)
	bar.statusBar = statusBar

	bar.icon = statusBar:CreateTexture(nil, "ARTWORK")
	bar.nameText = statusBar:CreateFontString(nil, "OVERLAY")
	bar.countText = statusBar:CreateFontString(nil, "OVERLAY")
	bar.timeText = statusBar:CreateFontString(nil, "OVERLAY")

	-- a text needs a font before it can be given to the container
	local font, fontSize = media:Fetch("font", db.bufffont), db.bufffontsize
	bar.nameText:SetFont(font, fontSize)
	bar.countText:SetFont(font, fontSize)
	bar.timeText:SetFont(font, fontSize)

	-- hand the pieces to the container
	button:SetDurationBar(statusBar, { direction = Enum.StatusBarTimerDirection.RemainingTime })
	button:SetIcon(bar.icon)
	button:SetSpellName(bar.nameText)
	button:SetApplicationCount(bar.countText)

	StyleBar(bar, GetTimeTextWidth(), GetDebuffColors())
end

----------------------------
-- Containers

local function CreateContainer(unit)
	local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
	container:SetFrameStrata("MEDIUM")
	container:SetEditModePreviewEnabled(false)
	container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Vertical)
	container:SetUnit(unit)

	-- buffs are shown before debuffs
	for index, group in ipairs(GROUPS) do
		container:AddAuraGroup(group, FILTERS[group], {
			initializeFrame = function(button)
				InitializeBar(unit, group, button)
			end,
			candidateFilters = { maxDuration = MAX_DURATION },
			layout = { layoutIndex = index },
		})
	end

	return container
end

-- Positions a container like the first bar of the unit. Returns 1 if the bars grow up, or -1 if they grow down.
local function AnchorContainer(unit, container)
	local qpdb = Player.db.profile

	local position, gap, offset = db[unit .. "position"], db[unit .. "gap"], db[unit .. "offset"]
	local anchor, x, y, grow = db[unit .. "anchor"], db[unit .. "x"], db[unit .. "y"], db[unit .. "growdirection"]
	local height, icons, iconside = db[unit .. "height"], db[unit .. "icons"], db[unit .. "iconside"]

	local direction
	container:ClearAllPoints()
	if anchor == "free" then
		-- the position is the bottom left corner of the first bar
		if grow == "up" then
			direction = 1
			container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		else --L["Down"]
			direction = -1
			container:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y + height)
		end
	else
		local anchorframe
		if anchor == "focus" and Focus and Focus.Bar then
			anchorframe = Focus.Bar
		elseif anchor == "target" and Target and Target.Bar then
			anchorframe = Target.Bar
		else -- L["Player"]
			anchorframe = Player.Bar
		end

		if position == "top" then
			direction = 1
			container:SetPoint("BOTTOM", anchorframe, "TOP", 0, gap)
		elseif position == "bottom" then
			direction = -1
			container:SetPoint("TOP", anchorframe, "BOTTOM", 0, -1 * gap)
		elseif position == "topright" then
			direction = 1
			container:SetPoint("BOTTOMRIGHT", anchorframe, "TOPRIGHT", -1 * offset, gap)
		elseif position == "bottomright" then
			direction = -1
			container:SetPoint("TOPRIGHT", anchorframe, "BOTTOMRIGHT", -1 * offset, -1 * gap)
		elseif position == "topleft" then
			direction = 1
			container:SetPoint("BOTTOMLEFT", anchorframe, "TOPLEFT", offset, gap)
		elseif position == "bottomleft" then
			direction = -1
			container:SetPoint("TOPLEFT", anchorframe, "BOTTOMLEFT", offset, -1 * gap)
		elseif position == "leftup" then
			if iconside == "right" and icons then
				offset = offset + height
			end
			if qpdb.iconposition == "left" and not qpdb.hideicon then
				offset = offset + qpdb.h
			end
			direction = 1
			container:SetPoint("BOTTOMRIGHT", anchorframe, "BOTTOMLEFT", -1 * offset, gap)
		elseif position == "leftdown" then
			if iconside == "right" and icons then
				offset = offset + height
			end
			if qpdb.iconposition == "left" and not qpdb.hideicon then
				offset = offset + qpdb.h
			end
			direction = -1
			container:SetPoint("TOPRIGHT", anchorframe, "TOPLEFT", -3 * offset, -1 * gap)
		elseif position == "rightup" then
			if iconside == "left" and icons then
				offset = offset + height
			end
			if qpdb.iconposition == "right" and not qpdb.hideicon then
				offset = offset + qpdb.h
			end
			direction = 1
			container:SetPoint("BOTTOMLEFT", anchorframe, "BOTTOMRIGHT", offset, gap)
		else -- rightdown
			if iconside == "left" and icons then
				offset = offset + height
			end
			if qpdb.iconposition == "right" and not qpdb.hideicon then
				offset = offset + qpdb.h
			end
			direction = -1
			container:SetPoint("TOPLEFT", anchorframe, "TOPRIGHT", offset, -1 * gap)
		end
	end
	return direction
end

local function ApplyContainerSettings(unit, container)
	local enabled = Buff:IsEnabled() and db[unit] and true or false
	container:SetEnabled(enabled)
	container:SetShown(enabled)

	local sortMethod = db.timesort and AuraContainerSortMethod.ExpirationOnly or AuraContainerSortMethod.NameOnly
	local spacing = db[unit .. "spacing"]
	for index, group in ipairs(GROUPS) do
		container:SetAuraGroupEnabled(group, db[unit .. group] and true or false)
		container:SetAuraGroupSortMethod(group, sortMethod, AuraContainerSortDirection.Normal)
		container:SetAuraGroupLayout(group, { elementSpacing = spacing, groupSpacing = spacing, layoutIndex = index })
	end

	container:SetScale(Player.db.profile.scale)
	container:SetAlpha(db.buffalpha)

	-- the bars are stacked from the anchor of the container
	local direction = AnchorContainer(unit, container)
	if direction == 1 then
		container:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
		container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
	else
		container:SetFlowLayoutAnchorPoint("TOPLEFT")
		container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
	end
end

----------------------------
-- Movers

-- The position of a container is secret and its bars can not be dragged, so a stand-in for the
-- first bar is moved instead, and the container is positioned from the settings afterwards.
local function GetMover(unit)
	local mover = movers[unit]
	if not mover then
		mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		mover:SetFrameStrata("HIGH")
		mover:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
		mover:SetBackdropColor(0, 0, 0, 0.8)
		mover:SetMovable(true)
		mover:SetClampedToScreen(true)
		mover:EnableMouse(true)
		mover:RegisterForDrag("LeftButton")
		mover:SetScript("OnDragStart", mover.StartMoving)
		mover:SetScript("OnDragStop", function(self)
			db[unit .. "x"] = self:GetLeft()
			db[unit .. "y"] = self:GetBottom()
			self:StopMovingOrSizing()
			Buff:ApplySettings()
		end)

		mover.text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		mover.text:SetPoint("CENTER")
		mover.text:SetText(unit == "focus" and L["Focus"] or L["Target"])

		mover:Hide()
		movers[unit] = mover
	end
	return mover
end

local function UpdateMover(unit)
	-- only bars which are not anchored to a cast bar can be moved
	if db[unit .. "anchor"] ~= "free" or not Buff:IsEnabled() or not db[unit] then
		locked[unit] = true
	end

	if locked[unit] then
		if movers[unit] then
			movers[unit]:Hide()
		end
	else
		local mover = GetMover(unit)
		mover:SetSize(db[unit .. "width"], db[unit .. "height"])
		mover:SetScale(Player.db.profile.scale)
		mover:ClearAllPoints()
		mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db[unit .. "x"], db[unit .. "y"])
		mover:Show()
	end
end

function Buff:SetLocked(unit, v)
	locked[unit] = v
	UpdateMover(unit)
end

----------------------------
-- Module

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "UNIT_AURA" then
		local container = containers[unit]
		if container then
			container:UpdateAllAuras()
		end
	else
		-- Auras of our casts and channels are not always removed from the container when they end.
		-- Their removal can also arrive after the cast stopped, so look again a moment later.
		Buff:UpdateBars()
		Buff:ScheduleTimer("UpdateBars", 0.2)
	end
end)

function Buff:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	-- fix broken buff text color
	if type(db.bufftextcolor) ~= "table" then
		db.bufftextcolor = {1,1,1}
	end

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Buff"])
end

function Buff:OnEnable()
	if not containers.target then
		for _, unit in ipairs(UNITS) do
			containers[unit] = CreateContainer(unit)
		end
	end

	-- The containers update themselves from the auras of their unit, but they do not notice when
	-- their unit changes, and miss the removal of some auras. So they are told to look again whenever
	-- something happened, and every few seconds, which is cheap, they only note that they need to update.
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateBars")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED", "UpdateBars")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "UpdateBars")
	eventFrame:RegisterUnitEvent("UNIT_AURA", "target", "focus")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "player")
	self.updateTimer = self:ScheduleRepeatingTimer("UpdateBars", 3)

	local function mediaChanged(event, mtype)
		if mtype == "statusbar" or mtype == "font" then
			self:ApplySettings()
		end
	end
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", mediaChanged)
	media.RegisterCallback(self, "LibSharedMedia_Registered", mediaChanged)

	self:ApplySettings()
end

function Buff:OnDisable()
	eventFrame:UnregisterAllEvents()
	self:CancelAllTimers()
	self.updateTimer = nil

	media.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
	media.UnregisterCallback(self, "LibSharedMedia_Registered")

	for _, unit in ipairs(UNITS) do
		if containers[unit] then
			containers[unit]:SetEnabled(false)
			containers[unit]:Hide()
		end
		UpdateMover(unit)
	end
end

function Buff:UpdateBars()
	-- the look of the bars could not be changed while auras were secret
	if stylePending then
		self:ApplyStyle()
	end
	for _, container in pairs(containers) do
		container:UpdateAllAuras()
	end
end

-- Applies the look to all bars, now or once auras are no longer secret
function Buff:ApplyStyle()
	if C_Secrets.ShouldAurasBeSecret() then
		stylePending = true
	else
		stylePending = false
		StyleBars()
	end
end

function Buff:ApplySettings()
	db = self.db.profile
	if not containers.target then return end

	for _, unit in ipairs(UNITS) do
		ApplyContainerSettings(unit, containers[unit])
		UpdateMover(unit)
	end
	if self:IsEnabled() then
		self:ApplyStyle()
		self:UpdateBars()
	end
end
