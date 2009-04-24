local AceLocale = LibStub:GetLibrary("AceLocale-3.0")
local L = AceLocale:NewLocale("Quartz3", "enUS", true)
if not L then return end

L["Quartz"] = true
L["Latency"] = true
L["Tradeskill Merge"] = true
L["Global Cooldown"] = true
L["Buff"] = true
L["Target"] = true
L["Pet"] = true
L["Focus"] = true
L["Player"] = true
L["Mirror"] = true
L["Timer"] = true
L["Swing"] = true
L["Interrupt"] = true
L["Range"] = true
L["Flight"] = true

L["GCD"] = true
L["Tradeskill"] = true

-- Basic shared stuff
L["Above"] = true
L["Alpha"] = true
L["Background"] = true
L["Below"] = true
L["Border"] = true
L["Bottom"] = true
L["Bottom Left"] = true
L["Bottom Right"] = true
L["Center"] = true
L["Colors"] = true
L["Default"] = true
L["Down"] = true
L["Enable"] = true
L["Font"] = true
L["Font Size"] = true
L["Free"] = true
L["Full Text"] = true
L["Gap"] = true
L["Height"] = true
L["Horizontal"] = true
L["Left"] = true
L["Left (grow down)"] = true
L["Left (grow up)"] = true
L["None"] = true
L["Number"] = true
L["Outside"] = true
L["Right"] = true
L["Right (grow down)"] = true
L["Right (grow up)"] = true
L["Scale"] = true
L["Spacing"] = true
L["Texture"] = true
L["Text Color"] = true
L["Top"] = true
L["Top Left"] = true
L["Top Right"] = true
L["Up"] = true
L["Vertical"] = true
L["X"] = true
L["Y"] = true
L["Width"] = true

-- Option Names

L["Lock"] = true
L["Hide Icon"] = true
L["Icon Alpha"] = true
L["Icon Gap"] = true
L["Name Text Position"] = true
L["Name Text Font Size"] = true
L["Spell Rank"] = true
L["Spell Rank Style"] = true
L["Hide Name Text"] = true
L["Hide Time Text"] = true
L["Hide Cast Time"] = true
L["Cast Time Precision"] = true
L["Time Font Size"] = true
L["Time Text Position"] = true
L["Spell Text"] = true
L["Time Text"] = true
L["Casting"] = true
L["Channeling"] = true
L["Complete"] = true
L["Failed"] = true
L["Spark Color"] = true
L["Background Alpha"] = true
L["Border Alpha"] = true
L["Disable Blizzard Cast Bar"] = true
L["Snap to Center"] = true
L["Icon Position"] = true
L["Text Alignment"] = true
L["Text Position"] = true
L["Copy Settings From"] = true
L["Cast Start Side"] = true
L["Cast End Side"] = true
L["Name Text X Offset"] = true
L["Name Text Y Offset"] = true
L["Time Text X Offset"] = true
L["Time Text Y Offset"] = true
L["Hide Samwise Icon"] = true
L["Show for Friends"] = true
L["Show for Enemies"] = true
L["Show if Target"] = true
L["Target Name"] = true
L["Display target name of spellcasts after spell name"] = true

L["Roman"] = true
L["Roman Full Text"] = true
--Latency
L["Embed"] = true
L["Embed Safety Margin"] = true
L["Bar Color"] = true
L["Show Text"] = true
--GCD
L["Primary"] = true
L["Backup"] = true
L["%s Spell"] = true
L["Bar Position"] = true
L["Deplete"] = true
--Buffs
L["Focus"] = true
L["Target"] = true
L["Enable %s"] = true
L["Enable Buffs"] = true
L["Enable Debuffs"] = true
L["Position"] = true
L["Offset"] = true
L["Show Icons"] = true
L["Buff Bar Width"] = true
L["Buff Bar Height"] = true
L["Buff Name Text"] = true
L["Buff Time Text"] = true
L["Buff Color"] = true
L["Debuff Color"] = true
L["Debuffs by Type"] = true
L["Undispellable Color"] = true
L["Curse Color"] = true
L["Disease Color"] = true
L["Magic Color"] = true
L["Poison Color"] = true
L["Anchor Frame"] = true
L["Grow Direction"] = true
L["Sort by Remaining Time"] = true
--Mirror
L["Mirror Bar Width"] = true
L["Mirror Bar Height"] = true
L["Mirror Name Text"] = true
L["Mirror Time Text"] = true
L["Hide Blizz Mirror Bars"] = true
L["%s Color"] = true
L["Breath"] = true
L["Exhaustion"] = true
L["Feign Death"] = true
L["Show Mirror"] = true
L["Show Static"] = true
L["Show PvP"] = true
--Timer
L["Stop Timer"] = true
L["Make Timer"] = true
L["New Timer Name"] = true
L["New Timer Length"] = true
--Swing
L["Duration Text"] = true
L["Remaining Text"] = true
--Interrupt
L["Interrupt Color"] = true
--Range
L["Out of Range Color"] = true
--Flight
L["Flight Map Color"] = true

-- Option descriptions

L["Toggle Cast Bar lock"] = true
L["Hide Spell Cast Icon"] = true
L["Set the Spell Cast icon alpha"] = true
L["Set where the Spell Cast icon appears"] = true
L["Space between the cast bar and the icon."] = true
L["Set the Cast Bar Texture"] = true
L["Set the font used in the Name and Time texts"] = true
L["Set the alignment of the spell name text"] = true
L["Set the size of the spell name text"] = true
L["Disable the text that displays the time remaining on your cast"] = true
L["Disable the text that displays the total cast time"] = true
L["Set the precision (i.e. number of decimal places) for the cast time text"] = true
L["Disable the text that displays the spell name/rank"] = true
L["Display the rank of spellcasts alongside their name"] = true
L["Set the display style of the spell rank"] = true
L["Set the size of the time text"] = true
L["Set the alignment of the time text"] = true
L["Set the border style"] = true
L["Set the color of the %s"] = true
L["Set the color of the cast bar when %s"] = true
L["Set the color of the casting bar spark"] = true
L["Set the color of the casting bar background"] = true
L["Set the alpha of the casting bar background"] = true
L["Set the color of the casting bar border"] = true
L["Set the alpha of the casting bar border"] = true
L["Disable and hide the default UI's casting bar"] = true
L["Move the CastBar to center of the screen along the specified axis"] = true
L["Select a bar from which to copy settings"] = true
L["Adjust the X position of the name text"] = true
L["Adjust the Y position of the name text"] = true
L["Adjust the X position of the time text"] = true
L["Adjust the Y position of the time text"] = true
L["Hide the icon for spells with no icon"] = true
L["Show this castbar for friendly units"] = true
L["Show this castbar for hostile units"] = true
L["Show this castbar if focus is also target"] = true
L["Set an exact X value for this bar's position."] = true
L["Set an exact Y value for this bar's position."] = true

--Latency
L["Include Latency time in the displayed cast bar."] = true
L["Embed mode will decrease it's lag estimates by this amount.  Ideally, set it to the difference between your highest and lowest ping amounts.  (ie, if your ping varies from 200ms to 400ms, set it to 0.2)"] = true
L["Latency Bar"] = true
L["Set the alpha of the latency bar"] = true
L["Display the latency time as a number on the latency bar"] = true
L["Set the font used for the latency text"] = true
L["Set the size of the latency text"] = true
L["Set the color of the latency text"] = true
L["Set the position of the latency text"] = true
L["Set the vertical position of the latency text"] = true
--GCD
L["%s spell to check for the Global Cooldown"] = true
L["Set the color of the GCD bar spark"] = true
L["Set the height of the GCD bar"] = true
L["Set the alpha of the GCD bar"] = true
L["Set the position of the GCD bar"] = true
L["Tweak the distance of the GCD bar from the cast bar"] = true
L["Reverses the direction of the GCD spark, causing it to move right-to-left"] = true
--Buffs
L["Show buffs/debuffs for your %s"] = true
L["Show buffs for your %s"] = true
L["Show debuffs for your %s"] = true
L["Position the bars for your %s"] = true
L["Tweak the vertical position of the bars for your %s"] = true
L["Tweak the space between bars for your %s"] = true
L["Tweak the horizontal position of the bars for your %s"] = true
L["Show icons on buffs and debuffs for your %s"] = true
L["Set the side of the buff bar that the icon appears on"] = true
L["Set the buff bar Texture"] = true
L["Set the width of the buff bars"] = true
L["Set the height of the buff bars"] = true
L["Display the names of buffs/debuffs on their bars"] = true
L["Display the time remaining on buffs/debuffs on their bars"] = true
L["Set the font used in the buff bars"] = true
L["Set the font size for the buff bars"] = true
L["Set the alpha of the buff bars"] = true
L["Set the color of the bars for buffs"] = true
L["Set the color of the bars for debuffs"] = true
L["Set the color of the text for the buff bars"] = true
L["Color debuff bars according to their dispel type"] = true
L["Set the color of the bars for undispellable debuffs"] = true
L["Set the color of the bars for curses"] = true
L["Set the color of the bars for diseases"] = true
L["Set the color of the bars for magic"] = true
L["Set the color of the bars for poisons"] = true
L["Select where to anchor the %s bars"] = true
L["Toggle %s bar lock"] = true
L["Set the grow direction of the %s bars"] = true
L["Sort the buffs and debuffs by time remaining.  If unchecked, they will be sorted alphabetically."] = true
--Mirror
L["Position the mirror bars"] = true
L["Tweak the vertical position of the mirror bars"] = true
L["Tweak the space between mirror bars"] = true
L["Tweak the horizontal position of the mirror bars"] = true
L["Show icons on mirror bars"] = true
L["Set the side of the mirror bar that the icon appears on"] = true
L["Set the mirror bar Texture"] = true
L["Set the width of the mirror bars"] = true
L["Set the height of the mirror bars"] = true
L["Display the names of Mirror Bar Types on their bars"] = true
L["Display the time remaining on mirror bars"] = true
L["Set the font used in the mirror bars"] = true
L["Set the color of the text for the mirror bars"] = true
L["Set the font size for the mirror bars"] = true
L["Set the alpha of the mirror bars"] = true
L["Hide Blizzard's mirror bars"] = true
L["Set the color of the bars for %s"] = true
L["Show mirror bars such as breath and feign death"] = true
L["Show bars for static popup items such as rez and summon timers"] = true
L["Show bar for start of arena and battleground games"] = true
L["Select where to anchor the mirror bars"] = true
L["Toggle mirror bar lock"] = true
L["Set the grow direction of the mirror bars"] = true
--Timer
L["Make a new timer using the above settings.  NOTE: it may be easier for you to simply use the command line to make timers, /qt"] = true
L["Select a timer to stop"] = true
L["Set a name for the new timer"] = true
L["Length of the new timer, in seconds"] = true
--Swing
L["Set the color of the swing timer bar"] = true
L["Set the height of the swing timer bar"] = true
L["Set the alpha of the swing timer bar"] = true
L["Set the position of the swing timer bar"] = true
L["Tweak the distance of the swing timer bar from the cast bar"] = true
L["Toggle display of text showing your total swing time"] = true
L["Toggle display of text showing the time remaining until you can swing again"] = true
--Interrupt
L["Set the color the cast bar is changed to when you have a spell interrupted"] = true
--Range
L["Set the color to turn the cast bar when the target is out of range"] = true
--Flight
L["Set the color to turn the cast bar when taking a flight path"] = true

-- Other crap
L["Rank (%d+)"] = true
L["Rank %s"] = true
--Latency
L["%dms"] = true
--GCD
L["<Spell Name>"] = true
L["Invalid Spell"] = true
L["Spell_Warning"] = "|cffff3333Warning: You have no spell chosen for Quartz's Global Cooldown module.  Please enter a spell name in the menu (/quartz, then click Global Cooldown). Note, it is recommended to use a spell that cannot have a cooldown other than the global cooldown and cannot be interrupted, such as Find Herbs"
--Buffs
L["%dm"] = true
--Mirror
L["Logout"] = true
L["Release"] = true
L["Logout"] = true
L["Forfeit Duel"] = true
L["Instance Boot"] = true
L["Summon"] = true
L["AOE Rez"] = true
L["Quit"] = true
L["Resurrect"] = true
L["Party Invite"] = true
L["Resurrect Timer"] = true
L["Duel Request"] = true
L["Game Start"] = true
L["1 minute"] = true
L["One minute until"] = true
L["30 seconds"] = true
L["Thirty seconds until"] = true
L["15 seconds"] = true
L["Fifteen seconds until"] = true
--Timer
L['Usage: /quartztimer timername 60 or /quartztimer 60 timername'] = true
L["Timers module currently disabled, re-enable it in the menu"] = true
L["<Time in seconds>"] = true
--Swing
--Interrupt
L["INTERRUPTED (%s)"] = true
--Range
--Flight
--FeatureFrame
L["Modular casting bar"] = true
