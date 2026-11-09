-- Mocked integration checks, not an assertion that secure actions work in WoW.
-- Run from the workspace root. The mock preserves the inherited secure OnClick
-- and models one user click, combat visibility and immutable protected frames.
local checks, scenarios = 0, 0
local function expect(label, actual, expected)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function truth(label, actual) expect(label, not not actual, true) end

local function Harness(options)
    scenarios = scenarios + 1
    options = options or {}
    local model = {
        combat = options.combat or false, now = 0, shift = false,
        frames = {}, timers = {}, drivers = {}, messages = {}, macros = {},
        targetChanges = 0, clicks = 0, pings = 0, protectedWrites = 0,
        tracking = options.tracking ~= false, spellID = options.spellID or 19883,
        interface = options.interface or 16001, world = {},
        mapScale = options.mapScale or 1, uiScale = options.uiScale or 1,
        shape = options.shape or "ROUND", tooltipReads = 0,
    }
    local secret = setmetatable({}, {__tostring = function() error("secret read") end})
    model.secret = secret
    issecretvalue = function(value) return value == secret end
    local Frame = {}
    Frame.__index = Frame
    local function Mutation(self, method)
        if self.protected and model.combat then
            model.protectedWrites = model.protectedWrites + 1
            error("protected write in combat: " .. method)
        end
    end
    function Frame:SetScript(event, fn) Mutation(self, "SetScript"); self.scripts[event] = fn end
    function Frame:GetScript(event) return self.scripts[event] end
    function Frame:RegisterEvent(event) self.events[event] = true end
    function Frame:SetAttribute(key, value) Mutation(self, "SetAttribute"); self.attrs[key] = value end
    function Frame:GetAttribute(key) return self.attrs[key] end
    function Frame:Show() Mutation(self, "Show"); self.shown = true end
    function Frame:Hide() Mutation(self, "Hide"); self.shown = false end
    function Frame:IsShown() return self.shown end
    function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function Frame:SetSize(width, height) Mutation(self, "SetSize"); self.width, self.height = width, height end
    function Frame:SetPoint(...) Mutation(self, "SetPoint"); self.point = {...} end
    function Frame:SetAllPoints(other) Mutation(self, "SetAllPoints"); self.allPoints = other end
    function Frame:ClearAllPoints() Mutation(self, "ClearAllPoints"); self.point = nil end
    function Frame:SetFrameStrata(strata) Mutation(self, "SetFrameStrata"); self.strata = strata end
    function Frame:GetFrameStrata() return self.strata or "MEDIUM" end
    function Frame:SetFrameLevel(level) Mutation(self, "SetFrameLevel"); self.level = level end
    function Frame:GetFrameLevel() return self.level or 1 end
    function Frame:GetLeft() return self.left end
    function Frame:GetBottom() return self.bottom end
    function Frame:GetWidth() return self.width end
    function Frame:GetHeight() return self.height end
    function Frame:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
    function Frame:EnableMouse(enabled) Mutation(self, "EnableMouse"); self.mouseEnabled = enabled end
    function Frame:EnableMouseWheel(enabled) Mutation(self, "EnableMouseWheel"); self.wheelEnabled = enabled end
    function Frame:SetPropagateMouseMotion(value) Mutation(self, "SetPropagateMouseMotion"); self.propagateMotion = value end
    function Frame:CanPropagateMouseMotion() return self.propagateMotion end
    function Frame:SetPropagateMouseClicks(value) Mutation(self, "SetPropagateMouseClicks"); self.propagateClicks = value end
    function Frame:SetPassThroughButtons(...) Mutation(self, "SetPassThroughButtons"); self.passThrough = {...} end
    function Frame:RegisterForClicks(...) Mutation(self, "RegisterForClicks"); self.registeredClicks = {...} end
    function Frame:SetBackdrop(value) self.backdrop = value end
    function Frame:SetBackdropColor(...) self.background = {...} end
    function Frame:SetBackdropBorderColor(...) self.border = {...} end
    function Frame:CreateFontString()
        local font = {}
        function font:SetPoint(...) self.point = {...} end
        function font:SetText(text) self.value = text end
        function font:SetTextColor(...) self.color = {...} end
        return font
    end
    local function MakeFrame(kind, name, parent, template)
        local frame = setmetatable({
            kind = kind, name = name, parent = parent, template = template,
            shown = true, scripts = {}, attrs = {}, events = {},
        }, Frame)
        model.frames[#model.frames + 1] = frame
        if name then _G[name] = frame end
        if template and template:find("SecureActionButtonTemplate", 1, true) then
            frame.protected = true
            if parent then parent.protected = true end
            frame.scripts.OnClick = function(self, button, down)
                if button ~= "LeftButton" or down then return end
                if self.attrs["*type1"] ~= "macro" then return end
                local text = self.attrs["*macrotext1"]
                -- This is deliberately a narrow native-action mock. It never
                -- invokes arbitrary Lua or claims to emulate secure WoW code.
                local name = type(text) == "string" and text:match("^/targetexact %[%s*nocombat%s*%] (.+)$")
                if not name or model.combat then return end
                model.macros[#model.macros + 1] = name
                if model.world[name] then
                    local nextTarget = model.world[name]
                    if model.target ~= nextTarget then
                        model.target = nextTarget
                        model.targetChanges = model.targetChanges + 1
                        if not model.deferTargetEvent then model.event("PLAYER_TARGET_CHANGED") end
                    end
                end
            end
            model.nativeSecureOnClick = frame.scripts.OnClick
        end
        return frame
    end
    CreateFrame = MakeFrame
    UIParent = MakeFrame("Frame", "UIParent")
    UIParent.scale = model.uiScale
    Minimap = MakeFrame("Minimap", "Minimap", UIParent)
    Minimap.left, Minimap.bottom = 100, 200
    Minimap.width, Minimap.height = 180, 180
    Minimap.scale = model.mapScale
    Minimap.level = 4
    model.cursorX, model.cursorY = 190 * model.mapScale, 290 * model.mapScale
    GameTooltip = {}
    for _, method in ipairs({"SetOwner", "SetText", "AddLine", "Show", "Hide"}) do
        GameTooltip[method] = function() end
    end
    GetCursorPosition = function() return model.cursorX, model.cursorY end
    GetMinimapShape = function() return model.shape end
    GetMouseFoci = function() return {model.focus or (model.state and model.state.overlay) or Minimap} end
    IsShiftKeyDown = function() return model.shift end
    InCombatLockdown = function() return model.combat end
    GetBuildInfo = function() return "1.60.1", "mock", "2026-11-09", model.interface end
    C_Minimap = {
        GetNumTrackingTypes = function() return 1 end,
        GetTrackingInfo = function() return {active = model.tracking, spellID = model.spellID, name = "Track Humanoids"} end,
    }
    C_TooltipInfo = {
        GetMinimapMouseover = function()
            model.tooltipReads = model.tooltipReads + 1
            if model.tooltipError then error("tooltip unreadable") end
            return model.tooltip
        end,
    }
    C_Timer = {After = function(delay, fn) model.timers[#model.timers + 1] = {due = model.now + delay, fn = fn} end}
    DEFAULT_CHAT_FRAME = {AddMessage = function(self, text) model.messages[#model.messages + 1] = text end}
    RegisterStateDriver = function(frame, attribute, condition)
        Mutation(frame, "RegisterStateDriver")
        model.drivers[#model.drivers + 1] = frame
        frame.driver = {attribute, condition}
    end
    UnitExists = function(unit) return unit == "target" and model.target ~= nil end
    UnitName = function(unit) if model.target then return model.target.first, model.target.surname end end
    UnitIsPlayer = function(unit) return model.target and model.target.player end
    UnitFactionGroup = function(unit) return model.target and model.target.faction end
    SlashCmdList = {}
    TrackTargetForeverDB = options.db
    local ns = {}
    assert(loadfile("TrackTargetForever/Logic.lua"))("TrackTargetForever", ns)
    assert(loadfile("TrackTargetForever/Core.lua"))("TrackTargetForever", ns)
    model.state = ns.State
    model.event = function(event, argument)
        for _, frame in ipairs(model.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, argument) end
        end
    end
    model.tick = function(delta)
        model.now = model.now + delta
        for _, frame in ipairs(model.frames) do
            if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, delta) end
        end
        local progressed = true
        while progressed do
            progressed = false
            for i, timer in ipairs(model.timers) do
                if timer.due <= model.now then
                    table.remove(model.timers, i)
                    timer.fn()
                    progressed = true
                    break
                end
            end
        end
    end
    model.hover = function(header)
        model.tooltip = header and {lines = {{leftText = header}, {leftText = "Guild or descriptive text"}}} or nil
    end
    model.add = function(name, faction, isPlayer, first, surname)
        local target = {first = first or name, surname = surname, faction = faction, player = isPlayer ~= false}
        model.world[name] = target
        return target
    end
    model.command = function(text) SlashCmdList.TRACKTARGETFOREVER(text) end
    model.combatState = function(value)
        model.combat = value
        -- State-driver visibility runs in the client's secure path, not in
        -- an addon handler. It is intentionally not counted as a Lua write.
        for _, frame in ipairs(model.drivers) do frame.shown = not value end
        model.event(value and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    end
    model.click = function(button, duringNative)
        button = button or "LeftButton"
        model.clicks = model.clicks + 1
        local overlay = model.state.overlay
        if not overlay or not overlay:IsVisible() then model.pings = model.pings + 1; return end
        if button ~= "LeftButton" then model.pings = model.pings + 1; return end
        overlay.scripts.PreClick(overlay, button, false)
        if duringNative then duringNative() end
        overlay.scripts.OnClick(overlay, button, false)
        overlay.scripts.PostClick(overlay, button, false)
        if overlay.propagateClicks then model.pings = model.pings + 1 end
    end
    model.event("ADDON_LOADED", "TrackTargetForever")
    model.event("PLAYER_LOGIN")
    return model
end

do
    local m = Harness()
    truth("initialization", m.state.ready)
    expect("secure OnClick retained", m.state.overlay:GetScript("OnClick"), m.nativeSecureOnClick)
    truth("minimap motion propagation", m.state.overlay.propagateMotion)
    expect("no initialization target", #m.macros, 0)
    local target = m.add("Alliance Scout", "Alliance")
    m.hover("Alliance Scout"); m.tick(.05); m.click()
    expect("normal native target", m.target, target)
    expect("one native action", #m.macros, 1)
    expect("Alliance label", m.state.label.text.value, "Ally")
    truth("label shown", m.state.label:IsShown())
    expect("confirmed request cleared", m.state.pending, nil)
end

do
    local m = Harness()
    m.add("Old Hover", "Alliance")
    local fresh = m.add("Fresh Hover", "Horde")
    m.hover("Old Hover"); m.tick(.05)
    expect("old point armed before move", m.state.armedName, "Old Hover")
    m.hover("Fresh Hover"); m.click() -- no OnUpdate between pointer move and click
    expect("click reads fresh target", m.target, fresh)
    expect("stale name never executed", m.macros[1], "Fresh Hover")
    expect("fresh Horde label", m.state.label.text.value, "Horde")
    m.hover("Old Hover"); m.tick(.05)
    m.hover(nil); m.click()
    expect("vanished dot never reuses name", #m.macros, 1)
    expect("vanished dot keeps actual old target", m.target, fresh)
    expect("vanished dot clears action", m.state.overlay:GetAttribute("*type1"), nil)
    truth("empty map click propagates", m.state.overlay.propagateClicks)
end

do
    local m = Harness()
    local previous = m.add("Old Ally", "Alliance")
    m.hover("Old Ally"); m.click()
    m.hover("Far Away Horde"); m.click() -- targetexact fails; old target remains
    expect("failed attempt preserves actual previous target", m.target, previous)
    expect("old faction hidden while awaiting confirmation", m.state.label:IsShown(), false)
    m.tick(.25)
    expect("old faction not falsely attributed", m.state.label.text.value, "?")
    expect("unknown identifies attempted name", m.state.label.title, "Far Away Horde")
    expect("failure request expires", m.state.pending, nil)
end

do
    local m = Harness()
    local person = m.add("First Last", "Horde", true, "First", "Last")
    m.hover("First Last"); m.click()
    expect("full surname selects", m.target, person)
    expect("surname confirms faction", m.state.label.text.value, "Horde")
    m.world["First"] = person
    m.hover("First"); m.click(); m.tick(.25)
    expect("first-only never confirms full surname", m.state.label.text.value, "?")
    m.world["First-Last"] = person
    m.hover("First-Last"); m.click()
    expect("hyphen full alias confirms", m.state.label.text.value, "Horde")
    local npc = m.add("Humanoid Guard", nil, false)
    m.hover("Humanoid Guard"); m.click()
    expect("NPC native target", m.target, npc)
    expect("NPC not called player", m.state.label.text.value, "NPC")
end

do
    local m = Harness({spellID = 5225})
    m.add("One", "Alliance"); m.add("Two", "Horde")
    m.hover("One\nTwo"); m.click(); m.click(); m.click()
    expect("druid tracking recognized", m.state.hasTracking, true)
    expect("one action per physical overlapping click", #m.macros, 3)
    expect("overlap first", m.macros[1], "One")
    expect("overlap second", m.macros[2], "Two")
    expect("overlap wraps", m.macros[3], "One")
    m.hover(nil); m.tick(.05); m.hover("One\nTwo"); m.click()
    expect("leaving point resets overlap cycle", m.macros[4], "One")
end

do
    local m = Harness()
    m.add("Someone", "Alliance"); m.hover("Someone")
    m.command("mode shift"); m.click()
    expect("shift mode plain click no target", #m.macros, 0)
    truth("shift mode plain click propagates", m.state.overlay.propagateClicks)
    m.shift = true; m.click()
    expect("shift click targets once", #m.macros, 1)
    m.click("RightButton")
    expect("right click no target", #m.macros, 1)
    m.command("mode direct"); m.shift = false; m.click()
    expect("direct mode restored", #m.macros, 2)
end

do
    local m = Harness()
    m.add("Someone", "Horde"); m.hover("Someone"); m.tick(.05)
    m.combatState(true)
    expect("secure driver hides root", m.state.root:IsShown(), false)
    m.tick(1); m.click(); m.command("mode shift"); m.command("panel off")
    m.event("MINIMAP_UPDATE_TRACKING"); m.event("PLAYER_TARGET_CHANGED")
    expect("combat no native target", #m.macros, 0)
    expect("combat no protected addon writes", m.protectedWrites, 0)
    expect("settings not applied during combat", m.state.db.mode, "direct")
    m.combatState(false)
    expect("queued mode applied", m.state.db.mode, "shift")
    expect("queued panel applied", m.state.db.panel, false)
    expect("queue consumed", m.state.queued, nil)
    expect("stale combat action cleared", m.state.overlay:GetAttribute("*type1"), nil)
    m.click(); expect("shift setting effective", #m.macros, 0)
    m.shift = true; m.click(); expect("post-combat click resumes", #m.macros, 1)
    expect("disabled panel remains hidden", m.state.label:IsShown(), false)
end

do
    local m = Harness({combat = true})
    expect("reload during combat defers init", m.state.ready, false)
    expect("reload creates no secure overlay", m.state.overlay, nil)
    m.command("mode shift")
    m.tick(1)
    m.combatState(false)
    truth("deferred initialization resumes", m.state.ready)
    expect("deferred setting applied", m.state.db.mode, "shift")
    expect("deferred init zero combat protected writes", m.protectedWrites, 0)
end

do
    local m = Harness()
    m.add("Race Target", "Alliance"); m.hover("Race Target")
    m.click("LeftButton", function() m.combatState(true) end)
    expect("combat race macro condition prevents target", #m.macros, 0)
    expect("combat race no pending stale confirmation", m.state.pending, nil)
    expect("combat race no protected mutations", m.protectedWrites, 0)
end

do
    local m = Harness({mapScale = 1.2, uiScale = .8})
    expect("scaled geometry left", m.state.geometry.x, 150)
    expect("scaled geometry bottom", m.state.geometry.y, 300)
    expect("scaled geometry width", m.state.geometry.w, 270)
    expect("overlay anchored to UIParent", m.state.overlay.point[2], UIParent)
    m.add("Center", "Horde"); m.hover("Center"); m.click()
    expect("scaled cursor targets", #m.macros, 1)
    m.cursorX, m.cursorY = 101 * 1.2, 201 * 1.2
    m.click(); expect("round corner ignored", #m.macros, 1)
    m.shape = "SQUARE"; m.click(); expect("square corner accepted", #m.macros, 2)
    Minimap.width = 240; m.tick(.3)
    expect("resized geometry updates", m.state.geometry.w, 360)
    Minimap.shown = false; m.tick(.3)
    expect("hidden minimap hides overlay", m.state.overlay:IsShown(), false)
    m.click(); expect("hidden minimap no target", #m.macros, 2)
end

do
    local m = Harness({tracking = false})
    m.add("Someone", "Alliance"); m.hover("Someone"); m.click()
    expect("no tracking no target", #m.macros, 0)
    truth("no tracking passthrough", m.state.overlay.propagateClicks)
    m.tracking = true; m.click()
    expect("tracking refreshed at click", #m.macros, 1)
    m.tracking = false; m.click()
    expect("tracking lost never reuses armed name", #m.macros, 1)
    m.tracking, m.spellID = true, 2383; m.click()
    expect("herb tracking ignored", #m.macros, 1)
end

do
    local m = Harness()
    local cluster = CreateFrame("Frame", "MockMinimapCluster", UIParent)
    Minimap.parent = cluster
    m.add("Hidden Map", "Horde"); m.hover("Hidden Map"); m.tick(.05)
    cluster:Hide()
    m.click() -- visibility can change between the regular geometry updates
    expect("hidden minimap ancestor never targets", #m.macros, 0)
    m.tick(.3)
    expect("hidden minimap ancestor hides overlay", m.state.overlay:IsShown(), false)
    cluster:Show(); m.tick(.3); m.click()
    expect("restored minimap ancestor resumes targeting", #m.macros, 1)
end

do
    local m = Harness()
    m.add("Someone", "Alliance"); m.hover("Someone"); m.tick(.05)
    m.focus = CreateFrame("Button", "ForeignMinimapControl", Minimap)
    m.click()
    expect("other control focus not treated as dot", #m.macros, 0)
    m.focus = nil
    m.tooltipError = true; m.click()
    expect("tooltip error fails closed", #m.macros, 0)
    m.tooltipError = false; m.hover(m.secret); m.click()
    expect("secret tooltip fails closed", #m.macros, 0)
    m.add("Hidden Faction", m.secret); m.hover("Hidden Faction"); m.click()
    expect("secret faction becomes unknown", m.state.label.text.value, "?")
    m.add("Hidden Name", "Alliance", true, m.secret); m.hover("Hidden Name"); m.click(); m.tick(.25)
    expect("secret target identity not confirmed", m.state.label.text.value, "?")
end

do
    local m = Harness()
    m.deferTargetEvent = true
    m.add("Deferred", "Alliance"); m.hover("Deferred"); m.click()
    expect("postclick handles target before event delivery", m.state.label.text.value, "Ally")
    m.event("PLAYER_TARGET_CHANGED")
    expect("same target event should retain confirmed faction label", m.state.label:IsShown(), true)
    m.target = {first = "Manual Selection", player = true, faction = "Horde"}
    m.event("PLAYER_TARGET_CHANGED")
    expect("different manual target hides previous faction label", m.state.label:IsShown(), false)
end

do
    local m = Harness()
    m.command("off"); m.add("Someone", "Alliance"); m.hover("Someone"); m.click()
    expect("disabled overlay does not target", #m.macros, 0)
    m.combatState(true); m.combatState(false)
    expect("disabled overlay stays hidden after combat", m.state.overlay:IsShown(), false)
    m.command("on"); m.click()
    expect("reenabled overlay targets", #m.macros, 1)
    m.command("test")
    local before = #m.macros
    m.tick(2); m.tick(2)
    expect("preview never changes target", #m.macros, before)
end

do
    local m = Harness({interface = 120000})
    expect("non-Forever client rejected", m.state.ready, false)
    expect("non-Forever has no secure overlay", m.state.overlay, nil)
end

print("PASS: " .. checks .. " mocked integration checks across " .. scenarios .. " scenarios")
