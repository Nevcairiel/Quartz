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

Quartz3 = LibStub("AceAddon-3.0"):NewAddon("Quartz3", "AceEvent-3.0", "AceConsole-3.0", "AceHook-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local media = LibStub("LibSharedMedia-3.0")

local options = {
	type = 'group',
	name = L["Quartz"],
	desc = L["Quartz"],
	args = {
		hidesamwise = {
			type = 'toggle',
			name = L["Hide Samwise Icon"],
			desc = L["Hide the icon for spells with no icon"],
			get = get,
			set = set,
			passValue = 'hidesamwise',
			order = 101,
		},
		colors = {
			type = 'group',
			name = L["Colors"],
			desc = L["Colors"],
			order = 450,
			args = {
				spelltextcolor = {
					type = 'color',
					name = L["Spell Text"],
					desc = L["Set the color of the %s"]:format(L["Spell Text"]),
					order = 98,
					get = getcolor,
					set = setcolor,
					passValue = 'spelltextcolor',
				},
				timetextcolor = {
					type = 'color',
					name = L["Time Text"],
					desc = L["Set the color of the %s"]:format(L["Time Text"]),
					order = 98,
					get = getcolor,
					set = setcolor,
					passValue = 'timetextcolor',
				},
				header = {
					type = 'header',
					order = 99,
				},
				castingcolor = {
					type = 'color',
					name = L["Casting"],
					desc = L["Set the color of the cast bar when %s"]:format(L["Casting"]),
					get = getcolor,
					set = setcolor,
					passValue = 'castingcolor',
				},
				channelingcolor = {
					type = 'color',
					name = L["Channeling"],
					desc = L["Set the color of the cast bar when %s"]:format(L["Channeling"]),
					get = getcolor,
					set = setcolor,
					passValue = 'channelingcolor',
				},
				completecolor = {
					type = 'color',
					name = L["Complete"],
					desc = L["Set the color of the cast bar when %s"]:format(L["Complete"]),
					get = getcolor,
					set = setcolor,
					passValue = 'completecolor',
				},
				failcolor = {
					type = 'color',
					name = L["Failed"],
					desc = L["Set the color of the cast bar when %s"]:format(L["Failed"]),
					get = getcolor,
					set = setcolor,
					passValue = 'failcolor',
				},
				sparkcolor = {
					type = 'color',
					name = L["Spark Color"],
					desc = L["Set the color of the casting bar spark"],
					get = getcolor,
					set = setcolor,
					hasAlpha = true,
					passValue = 'sparkcolor',
				},
				backgroundcolor = {
					type = 'color',
					name = L["Background"],
					desc = L["Set the color of the casting bar background"],
					get = getcolor,
					set = setcolor,
					passValue = 'backgroundcolor',
					order = 101,
				},
				backgroundalpha = {
					type = 'range',
					name = L["Background Alpha"],
					desc = L["Set the alpha of the casting bar background"],
					isPercent = true,
					min = 0,
					max = 1,
					step = 0.025,
					get = get,
					set = set,
					passValue = 'backgroundalpha',
					order = 102,
				},
				bordercolor = {
					type = 'color',
					name = L["Border"],
					desc = L["Set the color of the casting bar border"],
					get = getcolor,
					set = setcolor,
					passValue = 'bordercolor',
					order = 103,
				},
				borderalpha = {
					type = 'range',
					name = L["Border Alpha"],
					desc = L["Set the alpha of the casting bar border"],
					isPercent = true,
					min = 0,
					max = 1,
					step = 0.025,
					get = get,
					set = set,
					passValue = 'borderalpha',
					order = 104,
				},
			},
		}
	},
}

Quartz3.options = options

local defaults = {
	profile = {
		hidesamwise = true,
		
		sparkcolor = {1,1,1,0.5},
		spelltextcolor = {1, 1, 1},
		timetextcolor = {1, 1, 1},
		castingcolor = {1.0,0.49, 0},
		channelingcolor = {0.32,0.3, 1},
		completecolor = {0.12, 0.86, 0.15},
		failcolor = {1.0, 0.09, 0},
		backgroundcolor = {0, 0, 0},
		bordercolor = {0,0,0},
		
		backgroundalpha = 1,
		borderalpha = 1,
		},
	}

local optionFrames = {}
local ACD3 = LibStub("AceConfigDialog-3.0")

function Quartz3:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("Quartz3", defaults)
	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("Quartz3", options)

	self:RegisterChatCommand("quartz3", function() ACD3:Open("Quartz3") end)

	for k, v in self:IterateModules() do
		options.args.modules.args[k:gsub(" ", "_")] = {
			type = "group",
			name = (v.modName or k),
			args = nil
		}
		local t
		if v.GetOptions then
			t = v:GetOptions()
			t.settingsHeader = {
				type = "header",
				name = L["Settings"],
				order = 12
			}		
		end
		t = t or {}
		t.toggle = {
			type = "toggle", 
			name = v.toggleLabel or (L["Enable "] .. (v.modName or k)), 
			width = "double",
			desc = v.Info and v:Info() or (L["Enable "] .. (v.modName or k)), 
			order = 11,
			get = function()
				return Quartz3.db.profile.modules[k] ~= false or false
			end,
			set = function(info, v)
				Quartz3.db.profile.modules[k] = v
				if v then
					Quartz3:EnableModule(k)
					Quartz3:Print(L["Enabled"], k, L["Module"])
				else
					Quartz3:DisableModule(k)
					Quartz3:Print(L["Disabled"], k, L["Module"])
				end
			end
		}
		t.header = {
			type = "header",
			name = v.modName or k,
			order = 9
		}
		if v.Info then
			t.description = {
				type = "description",
				name = v:Info() .. "\n\n",
				order = 10
			}
		end
		options.args.modules.args[k:gsub(" ", "_")].args = t
	end	
	
	local moduleList = {}
	local moduleNames = {}
	for k, v in pairs(options.args.modules.args) do
		moduleList[v.name] = k
		tinsert(moduleNames, v.name)
	end
	table.sort(moduleNames)
	for _, name in ipairs(moduleNames) do
		ACD3:AddToBlizOptions("Quartz3Modules", name, "Quartz3", moduleList[name])
	end
	
	self.db.RegisterCallback(self, "OnProfileChanged", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileCopied", "ApplySettings")
	self.db.RegisterCallback(self, "OnProfileReset", "ApplySettings")

        media.RegisterCallback(self, "LibSharedMedia_Registered", "ApplySettings")
        media.RegisterCallback(self, "LibSharedMedia_SetGlobal", "ApplySettings")

	media:Register("statusbar", "Frost", "Interface\\AddOns\\Quartz3\\textures\\Frost")
	media:Register("statusbar", "Healbot", "Interface\\AddOns\\Quartz3\\textures\\Healbot")
	media:Register("statusbar", "LiteStep", "Interface\\AddOns\\Quartz3\\textures\\LiteStep")
	media:Register("statusbar", "Rocks", "Interface\\AddOns\\Quartz3\\textures\\Rocks")
	media:Register("statusbar", "Runes", "Interface\\AddOns\\Quartz3\\textures\\Runes")
	media:Register("statusbar", "Xeon", "Interface\\AddOns\\Quartz3\\textures\\Xeon")
end

function Quartz3:OnEnable()
	for k, v in self:IterateModules() do
		if self.db.profile.modules[k] ~= false then
			v:Enable()
		end
	end

	if not self.profilesRegistered then
		self:RegisterModuleOptions("Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db), L["Profiles"])
		self.profilesRegistered = true
	end
end

function Quartz3:ApplySettings()
	for k, v in self:IterateModules() do
		if v:IsEnabled() then
			v:Disable()
			v:Enable()
		end
	end
end

function Quartz3:OnDisable()
end

function Quartz3:RegisterModuleOptions(name, optionTbl, displayName)
	options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	if not optionFrames.default then
		optionFrames.default = ACD3:AddToBlizOptions("Quartz3", nil, nil, name)
	else
		optionFrames[name] = ACD3:AddToBlizOptions("Quartz3", displayName, "Quartz3", name)
	end
end

