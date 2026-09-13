=============================================================================
 PixProEmboss — Emboss Effect for Pixelmator Pro Layers
=============================================================================

PixProEmboss is a macOS AppleScript applet that embosses the selected
top-level layer(s) in Pixelmator Pro — plain text, single shapes, or
groups / shaped text — giving them a raised, chiselled appearance.

Applet:   /Applications/PixProEmboss.app   (also the ⌃⌥⌘E shortcut target)
Source:   ~/My_Applications/PixProEmboss/PixProEmboss.applescript
Defaults: ~/.pixproemboss_defaults.plist
Shortcut: Ctrl-Opt-Cmd-E inside Pixelmator Pro, via the "Emboss Layer"
          Quick Action (~/Library/Services/Emboss Layer.workflow)


-----------------------------------------------------------------------------
 HOW TO USE IT
-----------------------------------------------------------------------------

    1. In Pixelmator Pro, open your document and select the layer to
       emboss. It has to be at the TOP LEVEL of the Layers list; select
       several and each one is embossed in turn.

    2. Run PixProEmboss — double-click /Applications/PixProEmboss.app, or
       press Control-Option-Command-E with Pixelmator Pro in front.

    3. Answer the one dialog: angle / depth / blur, for example
       135 / 10 / 5.
           Angle   0-359, the direction the light comes from
           Depth   shadow offset distance; larger = more raised
           Blur    softness of the shadow edge; larger = softer
       The values are saved and offered again next run. Read Me opens
       this file.

    4. Click OK. A notification reports how many layers were embossed.

You get one group per layer, named after the source layer. Your original is
the bottom layer of that group, locked and hidden — delete the group and
unhide it to start over. Nothing is lost by retrying.


-----------------------------------------------------------------------------
 HOW THE EFFECT IS BUILT (techniques)
-----------------------------------------------------------------------------

LIGHT / DARK SHADOW PAIR
    The selected layer is duplicated twice, producing a "light" and a
    "dark" copy. Each copy is filled black, then given a drop shadow —
    the light copy's shadow at the light angle (in white), the dark
    copy's at the opposite angle — using the user's distance and blur
    settings. The shadows, not the fills, are what will remain visible.

SCREEN + MULTIPLY BLENDING
    Both copies are converted into pixels, then blended over the
    original: the light layer is set to SCREEN blend mode (only its
    bright shadow shows, forming the lit edge) and the dark layer to
    MULTIPLY (only its dark shadow shows, forming the shaded edge). Lit
    edge on one side, shaded edge on the other = the embossed illusion.

ORIGINAL PRESERVED
    The original layer is locked, hidden, and kept. The light copy, dark
    copy, and original are grouped, and the group is renamed to the
    original layer's display name. Delete the group's pixel layers and
    unhide the original to undo completely.

UNIQUE-NAME TARGETING (the v2.2.2 lesson)
    Multiple selected layers are processed one at a time. Because
    documents often hold several layers with identical names (shaped
    text pieces are all called "Shape"), each selected layer is first
    tagged with a unique temporary name; the effect engine locates it by
    that name, and the finished group is renamed back to the original
    display name. A per-layer error guard restores the name if an emboss
    fails (e.g. a locked layer), so no temp name is ever left behind.

SETTINGS
    One combined prompt asks for angle / depth / blur, with defaults
    saved between runs. Every dialog and notification title includes the
    version number, so it is always clear which build ran.

SCOPE
    Top-level layers only, by design. To emboss a layer that lives
    inside a group, drag it to the top level first and move the result
    back afterward. (In-group recursion was prototyped in the 2.1.x
    series and deliberately abandoned as not worth the complexity.)


-----------------------------------------------------------------------------
 IF THE RESULT IS NOT WHAT YOU EXPECTED
-----------------------------------------------------------------------------

Multiple layers are created in this process. They are collected into one
group named after the source layer — one such group per layer processed, so
a multi-layer selection produces several.

The BOTTOM layer of each group is your ORIGINAL, untouched. To start over:
drag that bottom layer out of the group to the top level of the Layers list,
then UNLOCK it and make it visible — PixProEmboss both locks and hides the
original when it files it into the group. Delete the group and run
PixProEmboss again with adjusted settings.

Nothing is lost by retrying — the original is never modified.


-----------------------------------------------------------------------------
 VERSION HISTORY (documented milestones)
-----------------------------------------------------------------------------

v1.2.0
    Early working baseline (the "big transparent E" icon era). The icon
    lived in the bundle's legacy resource fork, which blocked code
    signing; it was later extracted into a proper applet.icns.

v2.2.0
    Scope and robustness release: embosses the selected TOP-LEVEL
    layer(s) — text, single shapes, or groups/shaped text — with a
    combined angle/depth/blur prompt and saved defaults. Guards for "no
    document" and "nothing selected" (with advice to drag nested layers
    to the top level). Nested-group support from the 2.1.x experiments
    was dropped intentionally.

v2.2.1
    Removed the final "finished" confirmation dialog; a non-blocking
    notification banner reports the count instead.

v2.2.2  (2026-06-24)
    Fixed the duplicate-name cascade: when several selected layers (and
    their result groups) all shared a name like "Shape", the by-name
    lookup kept re-finding and re-embossing the first match, stacking
    duplicate .light/.dark groups. Selected layers are now iterated by
    index and tagged with unique temporary names before processing (see
    "Unique-name targeting" above). Verified on multi-glyph shaped text.

v2.3.0  (2026-08-10)
    Settings file renamed. PixProEmboss began as a fork of the
    PixProTransparentText project and had gone on using that project's
    ~/.transparenttext_defaults.plist ever since. With PixProTransparentText
    retired and removed, the settings moved to ~/.pixproemboss_defaults.plist.
    The saved distance / blur / angle were migrated across; the three dead
    keys the old file still carried (fontName, fontSize, theText) were
    dropped, as this script never read them. No change to the effect itself.

v2.4.0  (2026-08-10)
    Targets whichever Pixelmator build is actually in use. Since the Creator
    Studio rebrand there are two installs — com.apple.pixelmator (Creator
    Studio 4.x) and com.pixelmatorteam.pixelmator.x (Pixelmator Pro 3.x) —
    and `tell application "Pixelmator Pro"` bound to a fixed app path at
    compile time. A document open in the other build therefore read as no
    document at all. The build is now resolved at run time by bundle id
    (pixTarget): frontmost first, then any running build with a document.

Companion metadata work (2026-06): bundle version + copyright added to
the app's Info.plist (Finder Get Info), blue "biohazard" icon flattened
onto an opaque gray square and embedded, app ad-hoc signed.



v2.5.0  (2026-08-10)
    Read Me button. This README is now copied into the app bundle's own
    Contents/Resources at build time and opened via `path to resource`, so it
    travels inside the app — nothing depends on ~/My_Applications or any other
    external path. The button sits on the angle / depth / blur settings prompt and returns you
    to the prompt after the Read Me opens.

v2.6.0  (2026-08-15)
    Targets the running Pixelmator by BUNDLE PATH instead of by bundle id.
    Several COPIES of one build can be installed and copies share an
    identifier, so `tell application id` could not tell them apart: it
    addressed whichever copy macOS preferred, launched that copy if it was not
    already running, and then failed on the empty one. The path and pid of
    every running Pixelmator process are read from `ps`, which is the one
    thing that distinguishes identical copies, and everything is keyed to
    that.


v2.6.1  (2026-08-19)
    Signing release; no change to the effect. Signed with the Developer ID
    certificate under the hardened runtime and notarized, plus the two things
    osacompile does not put in an applet:

        com.apple.security.automation.apple-events. The hardened runtime
        stops an app from ASKING for Automation, so without this entitlement
        the applet keeps working on a Mac that already granted access and
        fails on a fresh one with "Not authorized to send Apple events"
        (-1743) — with no way for the user to switch it on by hand, because
        it never appears in the Automation list.

        A real CFBundleIdentifier (com.timmccoy.pixproemboss). osacompile writes
        none and drops it again on every rebuild, so codesign had been sealing
        the bundle NAME instead: nothing could address the app with
        `tell application id`, and it could hold no defaults domain.


v2.6.2  (2026-09-13)  — current
    Documentation release; no change to the effect. Adds a HOW TO USE IT
    section — numbered steps from selecting the layer, through every dialog
    field and its units, to what the result group contains — and fills in a
    version history that had stopped one release short of the shipping build.
    The copy inside the bundle was refreshed with it, so the Read Me button
    shows the same text.

    Also corrects the version the app announces: every dialog title is built
    from `scriptVersion`, which still read 2.4.0 while the bundle had moved on
    to 2.6.1.


-----------------------------------------------------------------------------
 Copyright (c) 2026 Tim McCoy. All rights reserved.

 Developed with the support of Claude (Anthropic) — design, code, and
 testing assistance.
=============================================================================
