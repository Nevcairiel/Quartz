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

-- Creates a StatusBar with the defaults Quartz relies on:
-- a texture is always present, it sits on the ARTWORK layer, and the range is 0-100.
function Quartz3:CreateStatusBar(name, parent)
	local bar = CreateFrame("StatusBar", name, parent, "BackdropTemplate")
	bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
	bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)

	return bar
end
