-- PixProEmboss.applescript
-- Version 2.4.0 (2026-08-10)
-- Copyright (c) 2026 Tim McCoy. All rights reserved.
-- Developed with assistance from Claude (Anthropic).
--
-- New in 2.4.0: targets whichever Pixelmator build is actually in use,
--   resolved at run time by bundle id (see pixTarget). Since the Creator
--   Studio rebrand there are two installs -- com.apple.pixelmator (Creator
--   Studio 4.x) and com.pixelmatorteam.pixelmator.x (Pixelmator Pro 3.x) --
--   and `tell application "Pixelmator Pro"` bound to a fixed path at compile
--   time, so a document open in the other build looked like no document at
--   all. Prefers the frontmost build, then any running build with a document.
--
-- New in 2.3.0: settings moved from ~/.transparenttext_defaults.plist to
--   ~/.pixproemboss_defaults.plist. The old file was inherited from the
--   retired PixProTransparentText project, which has been removed; the
--   name outlived it by a year. Saved distance / blur / angle were
--   migrated across, and the dead fontName / fontSize / theText keys
--   (never read by this script) were dropped.
--
-- New in 2.2.2: fixed duplicate-name handling. Shaped text / multiple
--   shape layers are often all named "Shape"; the by-name layer lookup
--   then re-found the FIRST match and re-embossed it, cascading into
--   stacks of duplicate Shape.light / Shape.dark groups. Each selected
--   layer is now given a UNIQUE temporary name before embossing, and the
--   finished group is renamed back to its original name.
--
-- New in 2.2.1: removed the final "finished" confirmation dialog (no OK
--   click needed); a non-blocking notification still reports the count.
--
-- Emboss script for Pixelmator Pro. Embosses the selected TOP-LEVEL
-- layer(s): plain text, single shapes, or groups / shaped text.
-- Screen blend on the light layer, Multiply on the dark layer.
-- Settings saved to ~/.pixproemboss_defaults.plist.
--
-- Works on TOP-LEVEL layers. To emboss a layer that is inside a group,
-- drag it out to the top level first; you can move the result back
-- wherever you want afterward.

property scriptVersion : "2.7.3"

property kPixIDs : {"com.apple.pixelmator", "com.pixelmatorteam.pixelmator.x"}

-- ============================================================
-- UPDATE CHECK (reports only, never downloads)
-- ============================================================
-- Asks GitHub for the newest published tag and adds a line to the prompt when
-- this build is behind. It never downloads or replaces anything: a running
-- bundle cannot safely overwrite its own files, and getting that wrong costs
-- the app.
--
-- Checked once a day at most and capped at three seconds, so a slow or absent
-- network barely shows. The tag and the day it was fetched are kept in the
-- same defaults file as the settings.
--
-- The JSON is picked apart with grep and cut rather than a parser: a stranger's
-- Mac is not guaranteed to have python3, and the tag is the only field wanted.
property kSlug : "pixproemboss"
property kDefaults : "$HOME/.pixproemboss_defaults"

on versionParts(v)
	set out to {}
	set AppleScript's text item delimiters to "."
	set pieces to text items of v
	set AppleScript's text item delimiters to ""
	repeat with piece in pieces
		set digits to ""
		repeat with c in (characters of (piece as text))
			if c is in "0123456789" then set digits to digits & c
		end repeat
		if digits is "" then set digits to "0"
		set end of out to digits as integer
	end repeat
	return out
end versionParts

on isNewer(tag, mine)
	-- Compared as integers, so 3.10.0 comes out above 3.9.0 rather than below.
	set a to my versionParts(tag)
	set b to my versionParts(mine)
	repeat with i from 1 to 3
		set x to 0
		set y to 0
		if i ≤ (count a) then set x to item i of a
		if i ≤ (count b) then set y to item i of b
		if x > y then return true
		if x < y then return false
	end repeat
	return false
end isNewer

on latestTag()
	set today to do shell script "/bin/date +%Y-%m-%d"
	set lastDay to ""
	try
		set lastDay to do shell script "defaults read " & kDefaults & " updateCheckedOn 2>/dev/null"
	end try
	if lastDay is today then
		try
			return do shell script "defaults read " & kDefaults & " updateLatestTag 2>/dev/null"
		end try
		return ""
	end if
	try
		set tag to do shell script "/usr/bin/curl -sL --max-time 3 -H \"Accept: application/vnd.github+json\" https://api.github.com/repos/spurious-cox/" & kSlug & "/releases/latest | /usr/bin/grep -o '\"tag_name\": *\"[^\"]*\"' | /usr/bin/head -1 | /usr/bin/cut -d'\"' -f4"
		do shell script "defaults write " & kDefaults & " updateLatestTag " & quoted form of tag
		do shell script "defaults write " & kDefaults & " updateCheckedOn " & quoted form of today
		return tag
	on error
		return ""
	end try
end latestTag

on updateNotice(mine)
	set tag to my latestTag()
	if tag is "" then return ""
	if not (my isNewer(tag, mine)) then return ""
	set t to tag
	if t starts with "v" then set t to text 2 thru -1 of t
	return return & return & "Update available: " & t & "  —  brew upgrade --cask " & kSlug
end updateNotice



-- Resolved once at run start by pixTarget(); a property so the handlers can
-- see it. Every `tell application pixApp` below depends on this being set.
property pixApp : ""

-- ============================================================
-- READ ME
-- The README is copied into this applet's OWN Contents/Resources at build
-- time and found with `path to resource`, so it travels inside the bundle.
-- Nothing here depends on ~/My_Applications, or on any other external path:
-- move or copy the app anywhere and the Read Me button still works.
-- ============================================================
on showReadMe()
	try
		set rmRef to (path to resource "PixProEmboss-README.txt")
		do shell script "open -e " & quoted form of (POSIX path of rmRef)
	on error
		tell me to activate
		display dialog "The Read Me is missing from the app bundle." buttons {"OK"} default button "OK"
	end try
end showReadMe


-- Returns the bundle id of the Pixelmator build to drive: the one with a
-- document open, preferring the frontmost. Since the Creator Studio rebrand
-- `tell application "Pixelmator Pro"` can bind to whichever build macOS picks,
-- which is not necessarily the one the user is looking at.
on pixTarget()
	set rawPaths to {}
	try
		set psOut to do shell script "/bin/ps -Axo args= | /usr/bin/grep '/Contents/MacOS/Pixelmator' | /usr/bin/grep -v grep | /usr/bin/sed 's|/Contents/MacOS/.*||' | /usr/bin/sort -u"
		-- `do shell script` separates lines with RETURN, not linefeed. Split on
		-- the wrong one and every path arrives glued into a single string.
		set AppleScript's text item delimiters to return
		set rawPaths to text items of psOut
		set AppleScript's text item delimiters to ""
	end try

	-- Keep only genuine Pixelmator Pro builds, identified by the bundle id in
	-- each app's OWN Info.plist. Nothing here depends on what the app is
	-- called or where it lives, so this works on any Mac: renamed bundles,
	-- App Store or Setapp copies, apps in ~/Applications, all fine. It also
	-- excludes the classic Pixelmator (com.pixelmatorteam.pixelmator), whose
	-- dictionary is different and which would fail halfway through.
	set candidates to {}
	repeat with rp in rawPaths
		set p to rp as text
		if p is not "" then
			try
				set theID to do shell script "/usr/bin/defaults read " & quoted form of (p & "/Contents/Info") & " CFBundleIdentifier"
				if theID is in kPixIDs then set end of candidates to p
			end try
		end if
	end repeat
	if candidates is {} then return ""

	-- Which of them, if any, is frontmost. The frontmost process's pid maps
	-- back to its bundle path through ps.
	set frontPath to ""
	try
		-- Bounded: asking System Events which app is frontmost needs Automation
		-- permission, and on a first run that call sits there waiting for a
		-- consent prompt. If the prompt does not appear — and for a freshly
		-- built applet it may not — the app hangs with no window and nothing
		-- to click. Five seconds, then carry on: the frontmost check only
		-- orders the candidates, it does not find them.
		with timeout of 5 seconds
			tell application "System Events"
				set fpid to unix id of (first application process whose frontmost is true)
			end tell
		end timeout
		set frontPath to do shell script "/bin/ps -p " & fpid & " -o args= | /usr/bin/sed 's|/Contents/MacOS/.*||'"
	end try

	set ordered to {}
	repeat with c in candidates
		set cc to c as text
		if cc is equal to frontPath then set end of ordered to cc
	end repeat
	repeat with c in candidates
		set cc to c as text
		if cc is not equal to frontPath then set end of ordered to cc
	end repeat

	repeat with c in ordered
		set cc to c as text
		try
			using terms from application "Pixelmator Pro"
				tell application cc
					if (count of documents) > 0 then return cc
				end tell
			end using terms from
		end try
	end repeat
	return item 1 of ordered
end pixTarget


-- ============================================================
-- APPLY EMBOSS EFFECT
-- Locates the layer by its (unique, temporary) name, duplicates it to a
-- light + dark pixel layer, sets shadows/fills, converts to pixels, sets
-- blend modes, locks/hides the original, groups the three, and names the
-- group with finalName (the layer's original display name).
-- ============================================================
on applyEffect(theName, finalName, lightAngle, darkAngle, shadowDistance, shadowBlur)
	using terms from application "Pixelmator Pro"
	tell application pixApp
		tell front document
			set origIdx to -1
			repeat with i from 1 to count of layers
				if name of layer (i) is theName then
					set origIdx to i
					exit repeat
				end if
			end repeat
			if origIdx is -1 then error "Layer not found: " & finalName
			if locked of layer (origIdx) then error "Layer is locked, skipping: " & finalName

			-- Duplicate for light shadow
			duplicate layer (origIdx)
			set name of layer (origIdx) to finalName & ".light"

			-- Duplicate original for dark shadow
			duplicate layer (origIdx + 1)
			set name of layer (origIdx + 1) to finalName & ".dark"

			-- Set black on copies only
			try
				tell text content of layer (origIdx)
					set its color to {0, 0, 0}
				end tell
			end try
			try
				set fill color of styles of layer (origIdx) to {0, 0, 0}
				set fill opacity of styles of layer (origIdx) to 100
			end try
			try
				tell text content of layer (origIdx + 1)
					set its color to {0, 0, 0}
				end tell
			end try
			try
				set fill color of styles of layer (origIdx + 1) to {0, 0, 0}
				set fill opacity of styles of layer (origIdx + 1) to 100
			end try

			-- Light shadow (#DFDFDF)
			set shadow opacity of styles of layer (origIdx) to 100
			set shadow angle of styles of layer (origIdx) to lightAngle
			set shadow distance of styles of layer (origIdx) to shadowDistance
			set shadow blur of styles of layer (origIdx) to shadowBlur
			set shadow color of styles of layer (origIdx) to {57311, 57311, 57311}

			-- Dark shadow (#050505) + white fill
			set shadow opacity of styles of layer (origIdx + 1) to 100
			set shadow angle of styles of layer (origIdx + 1) to darkAngle
			set shadow distance of styles of layer (origIdx + 1) to shadowDistance
			set shadow blur of styles of layer (origIdx + 1) to shadowBlur
			set shadow color of styles of layer (origIdx + 1) to {1285, 1285, 1285}
			set fill color of styles of layer (origIdx + 1) to {65535, 65535, 65535}
			set fill opacity of styles of layer (origIdx + 1) to 100

			-- Convert to pixels
			tell layer (origIdx) to convert into pixels
			tell layer (origIdx + 1) to convert into pixels

			-- Blend modes
			set blend mode of layer (origIdx) to screen
			set blend mode of layer (origIdx + 1) to multiply

			-- Lock and hide the original, then include it in the group
			set locked of layer (origIdx + 2) to true
			set visible of layer (origIdx + 2) to false
			set name of layer (origIdx + 2) to finalName

			-- Group light, dark and original together
			set theGroup to make group from {layer (origIdx), layer (origIdx + 1), layer (origIdx + 2)}
			set name of theGroup to finalName
		end tell
	end tell
	end using terms from
end applyEffect

-- ============================================================
-- LOAD SAVED DEFAULTS
-- ============================================================
set defaultDistance to "10"
set defaultBlur to "5"
set defaultAngle to "135"
try
	set defaultDistance to do shell script "defaults read $HOME/.pixproemboss_defaults shadowDistance 2>/dev/null"
end try
try
	set defaultBlur to do shell script "defaults read $HOME/.pixproemboss_defaults shadowBlur 2>/dev/null"
end try
try
	set defaultAngle to do shell script "defaults read $HOME/.pixproemboss_defaults lightAngle 2>/dev/null"
end try

-- ============================================================
-- PICK THE PIXELMATOR BUILD (see pixTarget above)
-- ============================================================
set pixApp to pixTarget()
if pixApp is "" then
	tell me to activate
	display dialog "Pixelmator Pro is not running. Open Pixelmator Pro and a document, select a layer, and try again." buttons {"OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
	error number -128
end if

-- ============================================================
-- FOCUS
-- ============================================================
using terms from application "Pixelmator Pro"
tell application pixApp
	activate
end tell
end using terms from
delay 1
tell me to activate
delay 1

-- ============================================================
-- NO-SELECTION GUARD (count only; layers are renamed later)
-- ============================================================
set selCount to 0
using terms from application "Pixelmator Pro"
tell application pixApp
	if (count of documents) is 0 then
		tell me to activate
		display dialog "No document is open in Pixelmator Pro. Open a document, select a layer, and try again." buttons {"OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
		error number -128
	end if
	tell front document
		repeat with i from 1 to count of layers
			if selected of layer (i) then set selCount to selCount + 1
		end repeat
	end tell
end tell
end using terms from
if selCount is 0 then
	tell me to activate
	display dialog "No top-level layer is selected." & return & return & "PixProEmboss works on layers at the TOP LEVEL of the Layers list. If the layer you want is inside a group, drag it out to the top level first, then run again. You can move the embossed result back wherever you want afterward." buttons {"OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
	error number -128
end if

-- ============================================================
-- COMBINED SETTINGS PROMPT - angle / depth / blur
-- ============================================================
repeat
	set settingsResult to display dialog "PixProEmboss v" & scriptVersion & return & return & "Enter settings as:  angle / depth / blur" & return & return & "- Angle (0-359): direction of the light / emboss highlight." & return & "- Depth: shadow offset distance; larger = more raised look." & return & "- Blur: softness of the shadow edge; larger = softer." & my updateNotice(scriptVersion) default answer (defaultAngle & " / " & defaultDistance & " / " & defaultBlur) buttons {"Read Me", "Cancel", "OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
	if button returned of settingsResult is "Read Me" then
		my showReadMe()
	else
		try
			set settingsText to text returned of settingsResult
			set AppleScript's text item delimiters to "/"
			set settingsParts to text items of settingsText
			set AppleScript's text item delimiters to ""
			if (count of settingsParts) < 3 then error "Need three values"
			set lightAngle to (item 1 of settingsParts) as real
			set shadowDistance to (item 2 of settingsParts) as real
			set shadowBlur to (item 3 of settingsParts) as real
			if lightAngle >= 0 and lightAngle <= 359 then exit repeat
			display dialog "Angle must be between 0 and 359." buttons {"OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
		on error
			display dialog "Please enter three numbers separated by /  (e.g. 135 / 10 / 5)." buttons {"OK"} default button "OK" with title ("PixProEmboss v" & scriptVersion)
		end try
	end if
end repeat
set darkAngle to lightAngle + 180
if darkAngle >= 360 then set darkAngle to darkAngle - 360

do shell script "defaults write $HOME/.pixproemboss_defaults shadowDistance " & shadowDistance
do shell script "defaults write $HOME/.pixproemboss_defaults shadowBlur " & shadowBlur
do shell script "defaults write $HOME/.pixproemboss_defaults lightAngle " & lightAngle

-- ============================================================
-- TAG SELECTED LAYER(S) WITH UNIQUE TEMP NAMES, THEN EMBOSS
-- Unique temp names defeat the duplicate-"Shape" collision that made the
-- by-name lookup re-emboss the first match over and over.
-- ============================================================
using terms from application "Pixelmator Pro"
tell application pixApp
	activate
end tell
end using terms from
set embossJobs to {}
using terms from application "Pixelmator Pro"
tell application pixApp
	tell front document
		set jobNum to 0
		repeat with i from 1 to count of layers
			if selected of layer (i) then
				set jobNum to jobNum + 1
				set origName to (name of layer (i)) as text
				set tmpName to "PPEMB__" & jobNum & "__" & (random number from 100000 to 999999)
				set name of layer (i) to tmpName
				set end of embossJobs to {tmpName, origName}
			end if
		end repeat
	end tell
end tell
end using terms from

set convCount to 0
repeat with job in embossJobs
	set tmpN to item 1 of job
	set finN to item 2 of job
	try
		my applyEffect(tmpN, finN, lightAngle, darkAngle, shadowDistance, shadowBlur)
		set convCount to convCount + 1
	on error
		-- emboss failed for this layer: restore its original name so we
		-- never leave a PPEMB__ temp name behind
		try
			using terms from application "Pixelmator Pro"
			tell application pixApp
				tell front document
					repeat with i from 1 to count of layers
						if name of layer (i) is tmpN then
							set name of layer (i) to finN
							exit repeat
						end if
					end repeat
				end tell
			end tell
			end using terms from
		end try
	end try
end repeat

display notification "Finished! " & convCount & " conversion(s) embossed." with title ("PixProEmboss v" & scriptVersion)
