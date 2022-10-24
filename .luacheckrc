std = "lua51"
max_line_length = false
exclude_files = {
	"libs/",
	"locale/find-locale-strings.lua",
	".luacheckrc"
}

ignore = {
	"11./BINDING_.*", -- Setting an undefined (Keybinding) global variable
	"211", -- Unused local variable
	"211/L", -- Unused local variable "L"
	"212", -- Unused argument
	"213", -- Unused loop variable
	"311", -- Value assigned to a local variable is unused
	"542", -- empty if branch
}

globals = {
	"_G",
	"QuartzDB",
	"CONFIGMODE_CALLBACKS",

	"CastingBarFrame",
	"FocusFrameSpellBar",
	"PetCastingBarFrame",
	"PlayerCastingBarFrame",
	"TargetFrameSpellBar",
}

read_globals = {
	"bit",
	"format",
	"min", "max",
	"sort",
	"wipe",

	-- misc custom, third party libraries
	"LibStub",
	"AceGUIWidgetLSMlists",
	"InFlight", "InFlightBar",

	-- API functions
	"C_TradeSkillUI",
	"CreateFrame",
	"CombatLogGetCurrentEventInfo",
	"GetActiveSpecGroup",
	"GetBuildInfo",
	"GetCombatRatingBonus",
	"GetCorpseRecoveryDelay",
	"GetCVar",
	"GetMirrorTimerInfo",
	"GetMirrorTimerProgress",
	"GetSpellCooldown",
	"GetSpellInfo",
	"GetTalentInfoByID",
	"GetTime",
	"IsInInstance",
	"IsSpellInRange",
	"LoadAddOn",
	"PlaySound",
	"UnitAttackSpeed",
	"UnitBuff",
	"UnitCastingInfo",
	"UnitChannelInfo",
	"UnitClass",
	"UnitDamage",
	"UnitDebuff",
	"UnitHealth",
	"UnitIsEnemy",
	"UnitIsFriend",
	"UnitIsUnit",
	"UnitName",
	"UnitRangedDamage",

	-- FrameXML functions
	"InterfaceOptionsFrame_OpenToCategory",

	-- FrameXML Frames
	"UIParent",

	-- FrameXML Misc
	"StaticPopupDialogs",

	-- FrameXML Constants
	"CR_HASTE_SPELL",
	"COMBATLOG_FILTER_ME",
	"COMBATLOG_OBJECT_CONTROL_NPC",
	"COMBATLOG_OBJECT_REACTION_FRIENDLY",
	"MIRRORTIMER_NUMTIMERS",
	"READY_CHECK",
	"SPELLINTERRUPTOTHERSELF",
	"SOUNDKIT",
	"UNKNOWN",
	"WOW_PROJECT_ID",
	"WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
	"WOW_PROJECT_CLASSIC",
	"WOW_PROJECT_MAINLINE",
	"WOW_PROJECT_WRATH_CLASSIC",

}
