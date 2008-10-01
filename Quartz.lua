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
local L = AceLibrary("AceLocale-2.2"):new("Quartz")

Quartz = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0")
Quartz:SetModuleMixins("AceEvent-2.0")
Quartz:RegisterDB("QuartzDB")
local self = Quartz
Quartz.revision = tonumber(("$Rev: 70806 $"):match("%d+"))
Quartz.version = "0.1." .. (revision or 0)

local media = LibStub("LibSharedMedia-3.0")
media:Register("statusbar", "Frost", "Interface\\AddOns\\Quartz\\textures\\Frost")
media:Register("statusbar", "Healbot", "Interface\\AddOns\\Quartz\\textures\\Healbot")
media:Register("statusbar", "LiteStep", "Interface\\AddOns\\Quartz\\textures\\LiteStep")
media:Register("statusbar", "Rocks", "Interface\\AddOns\\Quartz\\textures\\Rocks")
media:Register("statusbar", "Runes", "Interface\\AddOns\\Quartz\\textures\\Runes")
media:Register("statusbar", "Xeon", "Interface\\AddOns\\Quartz\\textures\\Xeon")

local lodmodules = {}
local new, del
do
	local cache = setmetatable({}, {__mode='k'})
	function new()
		local t = next(cache)
		if t then
			cache[t] = nil
			return t
		else
			return {}
		end
	end
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end
		cache[t] = true
		return nil
	end
end
Quartz.new = new
Quartz.del = del

local function nothing()
end
local options
local function applySettings()
	if not IsLoggedIn() then
		return
	end
	for name, module in self:IterateModules() do
		if module.ApplySettings then
			module:ApplySettings()
		end
	end
end
Quartz.OnProfileEnable = applySettings
Quartz.ApplySettings = applySettings


function Quartz:OnInitialize()
	if AceLibrary:HasInstance("Waterfall-1.0") then
		AceLibrary("Waterfall-1.0"):Register('Quartz',
			'aceOptions', options,
			'title', L["Quartz"],
			'treeLevels', 3,
			'colorR', 0.8, 'colorG', 0.8, 'colorB', 0.8
		)
		self:RegisterChatCommand({"/quartz"}, function()
			AceLibrary("Waterfall-1.0"):Open('Quartz')
		end)
		if AceLibrary:HasInstance("Dewdrop-2.0") then
			self:RegisterChatCommand({"/quartzdd"}, function()
				AceLibrary("Dewdrop-2.0"):Open('Quartz', 'children', function()
					AceLibrary("Dewdrop-2.0"):FeedAceOptionsTable(options)
				end)
			end)
		end
		self:RegisterChatCommand({"/quartzcl"}, options)
	elseif AceLibrary:HasInstance("Dewdrop-2.0") then
		self:RegisterChatCommand({"/quartz"}, function()
			AceLibrary("Dewdrop-2.0"):Open('Quartz', 'children', function()
				AceLibrary("Dewdrop-2.0"):FeedAceOptionsTable(options)
			end)
		end)
		self:RegisterChatCommand({"/quartzcl"}, options)
	else
		self:RegisterChatCommand({"/quartz"}, options)
	end

	self:RegisterDefaults("profile", {
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
	})
	if ( EarthFeature_AddButton ) then
		EarthFeature_AddButton(
			{
				id= "Quartz";
				name= L["Modular casting bar"];
				subtext= "Quartz";
				tooltip = L["Modular casting bar"];
				icon= "Interface\\Icons\\Spell_Nature_ElementalAbsorption";
				callback= function()
					AceLibrary("Waterfall-1.0"):Open('Quartz')
					end;
			}
		);
	end
end

function Quartz:OnEnable(first)
	if first then
		for k, v in pairs(lodmodules) do
			if self:IsModuleActive(k, true) then
				local depends = GetAddOnMetadata('Quartz_'..k, "X-Quartz-RequiredModules")
				if depends then
					for module in depends:gmatch('([^, ]+)') do
						if not self:HasModule(module) then
							local success, reason = LoadAddOn('Quartz_'..module)
							if not success then
								error(k..' requires '..module..' module, which could not load: '..reason)
							end
						end
					end
				end
				LoadAddOn('Quartz_'..k)
			elseif not self:HasModule(k) then
				options.args[k] = {
					type = 'group',
					name = L[k],
					desc = L[k],
					order = 600,
					args = {
						toggle = {
							type = 'toggle',
							name = L["Enable"],
							desc = L["Enable"],
							get = function()
								return Quartz:IsModuleActive(k, true)
							end,
							set = function(v)
								local depends = GetAddOnMetadata('Quartz_'..k, "X-Quartz-RequiredModules")
								if depends then
									for module in depends:gmatch('([^, ]+)') do
										if not self:HasModule(module) then
											local success, reason = LoadAddOn('Quartz_'..module)
											if not success then
												error(k..' requires '..module..' module, which could not load: '..reason)
											end
										end
									end
								end
								LoadAddOn('Quartz_'..k)
								self:ToggleModuleActive(k, true)
							end,
							order = 99,
						},
					},
				}
			end
		end
		lodmodules = nil
	end
	self:RegisterEvent('PLAYER_LOGIN')
	applySettings()
end
function Quartz:OnDisable()
	CastingBarFrame.RegisterEvent = nil
	CastingBarFrame:UnregisterAllEvents()
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	CastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
end
function Quartz:PLAYER_LOGIN()
	applySettings()
end
do
	local exclude = {
		x = true,
		y = true,
	}
	function Quartz:CopySettings(from, to)
		for k,v in pairs(from) do
			if to[k] and not exclude[k] and type(v) ~= 'table' then
				to[k] = v
			end
		end
	end
end
do
	local function set(field, value)
		self.db.profile[field] = value
		applySettings()
	end
	local function get(field)
		return self.db.profile[field]
	end
	
	local function setcolor(field, ...)
		self.db.profile[field] = {...}
		applySettings()
	end
	local function getcolor(field)
		return unpack(self.db.profile[field])
	end
	options = {
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
	Quartz.options = options
end


for i = 1, GetNumAddOns() do
	local metadata = GetAddOnMetadata(i, "X-Quartz-Module")
	if metadata then
		local name, _, _, enabled = GetAddOnInfo(i)
		if enabled then
			lodmodules[metadata] = true
		end
	end
end
