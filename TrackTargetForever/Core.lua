-- TrackTarget Forever 0.1.0-beta
-- Original implementation. Real minimap hover + one physical secure click.
local addonName, ns = ...
local Logic = ns.Logic
local VERSION = "0.1.0-beta"
local HUMANOID_SPELLS = { [19883] = true, [5225] = true }
local eventFrame = CreateFrame("Frame")
local state = {
    ready = false, elapsed = 0, geometryElapsed = 0, trackingElapsed = 0,
    enabled = true, hasTracking = false, serial = 0, cycleIndex = 0,
}
ns.State = state

local function Plain(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    return value
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return Plain(a), Plain(b), Plain(c) end
    return nil
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69c5ffTrackTarget:|r " .. message)
    end
end

local function LoadSettings()
    if type(TrackTargetForeverDB) ~= "table" then TrackTargetForeverDB = {} end
    local db = TrackTargetForeverDB
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if db.mode ~= "direct" and db.mode ~= "shift" then db.mode = "direct" end
    if type(db.panel) ~= "boolean" then db.panel = true end
    state.db = db
    state.enabled = db.enabled
end

local function HideLabel()
    state.labelSerial = (state.labelSerial or 0) + 1
    state.confirmed = nil
    if state.label then state.label:Hide() end
end

local function ShowLabel(text, r, g, b, title, detail)
    if not state.label or not state.db.panel or not state.db.enabled then return end
    state.labelSerial = (state.labelSerial or 0) + 1
    state.label.text:SetText(text)
    state.label.text:SetTextColor(r, g, b)
    state.label.title = title or "TrackTarget Forever"
    state.label.detail = detail or ""
    state.label:Show()
end

local function Unknown(name, detail)
    ShowLabel("?", .7, .7, .7, name or "TrackTarget Forever", detail)
end

local function ModifierReady()
    return state.db.mode ~= "shift" or IsShiftKeyDown()
end

local function RefreshTracking()
    state.hasTracking = false
    state.trackingName = nil
    if not C_Minimap then return end
    local count = Read(C_Minimap.GetNumTrackingTypes)
    if type(count) ~= "number" then return end
    for i = 1, count do
        local info = Read(C_Minimap.GetTrackingInfo, i)
        if type(info) == "table" then
            local ok, active, spellID, name = pcall(function()
                return Plain(info.active), Plain(info.spellID), Plain(info.name)
            end)
            if ok and active and HUMANOID_SPELLS[spellID] then
                state.hasTracking = true
                state.trackingName = type(name) == "string" and name or "Track Humanoids"
                return
            end
        end
    end
end

local function ClearAction()
    if not state.overlay or InCombat() then return end
    -- Never retain a previous point's target when fresh hover data are absent.
    state.overlay:SetAttribute("*type1", nil)
    state.overlay:SetAttribute("*macrotext1", nil)
    state.armedName = nil
end

local function PropagateClicks(allow)
    if not state.overlay or InCombat() or state.propagateClicks == allow then return end
    state.overlay:SetPropagateMouseClicks(allow)
    state.propagateClicks = allow
end

local function ArmName(name)
    if InCombat() then return false end
    local macro = Logic.BuildMacro(name)
    if not macro then ClearAction(); return false end
    if state.armedName ~= name then
        state.overlay:SetAttribute("*macrotext1", macro)
        state.overlay:SetAttribute("*type1", "macro")
        state.armedName = name
    end
    return true
end

local function UpdateGeometry()
    if InCombat() or not state.overlay then return end
    if not state.db.enabled or not Minimap or not Minimap:IsVisible() then
        ClearAction()
        state.overlay:Hide()
        state.geometry = nil
        return
    end
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    local width, height = Minimap:GetWidth(), Minimap:GetHeight()
    local mapScale, uiScale = Minimap:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not left or not bottom or not width or not height or width <= 0 or height <= 0 then
        ClearAction()
        state.overlay:Hide()
        state.geometry = nil
        return
    end
    -- Host at UIParent and copy geometry. Do not make Minimap a protected
    -- ancestor/anchor of our secure action button.
    local x, y = left * mapScale / uiScale, bottom * mapScale / uiScale
    local w, h = width * mapScale / uiScale, height * mapScale / uiScale
    local strata, level = Minimap:GetFrameStrata(), Minimap:GetFrameLevel() + 1
    local old = state.geometry
    if not old or old.x ~= x or old.y ~= y or old.w ~= w or old.h ~= h
        or old.strata ~= strata or old.level ~= level then
        state.overlay:ClearAllPoints()
        state.overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        state.overlay:SetSize(w, h)
        state.overlay:SetFrameStrata(strata)
        state.overlay:SetFrameLevel(level)
        state.geometry = { x = x, y = y, w = w, h = h, strata = strata, level = level }
    end
    state.overlay:Show()
end

local function IsRealMinimapHover()
    if not Minimap or not Minimap:IsVisible() or not state.overlay:IsVisible() then return false end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local left, bottom = Minimap:GetLeft(), Minimap:GetBottom()
    local w, h = Minimap:GetWidth(), Minimap:GetHeight()
    if not x or not y or not left or not bottom or not w or not h or w <= 0 or h <= 0 then return false end
    x, y = x / scale, y / scale
    if x < left or x > left + w or y < bottom or y > bottom + h then return false end
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "ROUND" then
        local dx, dy = (x - left - w / 2) / (w / 2), (y - bottom - h / 2) / (h / 2)
        if dx * dx + dy * dy > 1 then return false end
    end
    -- Other windows, zoom buttons and addon controls must not act as dots.
    if GetMouseFoci then
        local foci = GetMouseFoci()
        local focus = type(foci) == "table" and foci[1]
        if focus and focus ~= state.overlay and focus ~= Minimap then return false end
    end
    return true
end

local function HoverNames()
    if InCombat() or not state.db.enabled or not state.hasTracking or not ModifierReady()
        or not IsRealMinimapHover() then return {} end
    local data = Read(C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover)
    return Logic.ExtractNames(data)
end

local function Signature(names)
    return table.concat(names, "\n")
end

local function NextCandidate(names, commit)
    if #names == 0 then return nil end
    local signature = Signature(names)
    local index = 1
    if signature == state.cycleSignature then
        index = (state.cycleIndex % #names) + 1
    end
    if commit then
        state.cycleSignature, state.cycleIndex = signature, index
    end
    return names[index]
end

local function RefreshHover()
    if not state.ready or InCombat() then return end
    local names = HoverNames()
    state.hoverNames = names
    if #names > 0 then
        ArmName(NextCandidate(names, false))
        PropagateClicks(false)
    else
        ClearAction()
        PropagateClicks(true)
        -- A new point starts at the first name, even if it was seen earlier.
        state.cycleSignature, state.cycleIndex = nil, 0
    end
end

local function ConfirmedTargetIsCurrent()
    local confirmed = state.confirmed
    if not confirmed or not Read(UnitExists, "target") then return false end
    local first, surname = Read(UnitName, "target")
    local isPlayer = Read(UnitIsPlayer, "target")
    if isPlayer ~= confirmed.isPlayer or not Logic.NamesMatch(confirmed.name, first, surname, isPlayer) then
        return false
    end
    local guid = Read(UnitGUID, "target")
    if type(confirmed.guid) == "string" and type(guid) == "string" then
        return confirmed.guid == guid
    end
    return true
end

local function ConfirmTarget(request)
    if state.pending ~= request or InCombat() then return false end
    local exists = Read(UnitExists, "target")
    if not exists then return false end
    local first, surname = Read(UnitName, "target")
    local isPlayer = Read(UnitIsPlayer, "target")
    if type(isPlayer) ~= "boolean" or not Logic.NamesMatch(request.name, first, surname, isPlayer) then
        return false
    end
    state.pending = nil
    state.confirmed = { name = request.name, isPlayer = isPlayer, guid = Read(UnitGUID, "target") }
    if not isPlayer then
        ShowLabel("NPC", .7, .7, .7, request.name, "This tracked humanoid is an NPC.")
        return true
    end
    local faction = Read(UnitFactionGroup, "target")
    if faction == "Alliance" then
        ShowLabel("Ally", .30, .65, 1, request.name, "Alliance player. Selected as your normal WoW target.")
    elseif faction == "Horde" then
        ShowLabel("Horde", 1, .30, .25, request.name, "Horde player. Selected as your normal WoW target.")
    else
        Unknown(request.name, "Target selected. Faction information is unavailable.")
    end
    return true
end

local function PreClick(self, button, down)
    self.ttfRequest = nil
    if InCombat() then return end -- macro has an additional [nocombat] guard
    ClearAction()
    state.pending = nil
    if button ~= "LeftButton" or down then return end
    RefreshTracking()
    -- Re-read at the click itself. An armed target from the previous update
    -- is never used after the pointer has moved or the point disappeared.
    local names = HoverNames()
    if #names == 0 then PropagateClicks(true); return end
    local name = NextCandidate(names, true)
    if not ArmName(name) then return end
    PropagateClicks(false)
    HideLabel()
    state.serial = state.serial + 1
    local request = { name = name, serial = state.serial }
    state.pending, self.ttfRequest = request, request
end

local function PostClick(self, button, down)
    local request = self.ttfRequest
    self.ttfRequest = nil
    if not request or InCombat() or button ~= "LeftButton" or down then return end
    if ConfirmTarget(request) or state.pending ~= request then return end
    C_Timer.After(.20, function()
        if state.pending ~= request or InCombat() then return end
        if not ConfirmTarget(request) then
            state.pending = nil
            Unknown(request.name, "No matching target was confirmed. Move closer and click again. Your previous target may still be selected.")
        end
    end)
end

local function CreateLabel()
    local label = CreateFrame("Frame", "TrackTargetForeverFaction", UIParent, "BackdropTemplate")
    label:SetSize(88, 24)
    label:SetPoint("TOP", Minimap, "BOTTOM", 0, -5)
    label:SetFrameStrata("MEDIUM")
    label:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    label:SetBackdropColor(.025, .035, .055, .88)
    label:SetBackdropBorderColor(.2, .27, .36, .9)
    label:EnableMouse(true)
    label.text = label:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label.text:SetPoint("CENTER")
    label:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.title or "TrackTarget Forever", 1, 1, 1)
        GameTooltip:AddLine(self.detail or "", .8, .8, .8, true)
        GameTooltip:Show()
    end)
    label:SetScript("OnLeave", function() GameTooltip:Hide() end)
    label:Hide()
    state.label = label
end

local function Initialize()
    if state.ready or InCombat() then return end
    if not state.db then LoadSettings() end
    local _, _, _, interface = GetBuildInfo()
    if type(interface) ~= "number" or interface < 16000 or interface >= 17000 then
        if not state.unsupported then Print("This beta is for Blizzard WoW Forever (Interface 16001).") end
        state.unsupported = true
        return
    end
    if not Minimap or not C_TooltipInfo or not C_TooltipInfo.GetMinimapMouseover
        or not C_Minimap or not RegisterStateDriver then
        if not state.unsupported then Print("Required Forever minimap APIs are unavailable. Use /ttf debug.") end
        state.unsupported = true
        return
    end
    -- Only this independent parent is visibility-driven. Manually hidden
    -- children stay hidden when the driver's parent returns after combat.
    local root = CreateFrame("Frame", "TrackTargetForeverSecureRoot", UIParent)
    root:SetAllPoints(UIParent)
    local overlay = CreateFrame("Button", "TrackTargetForeverClick", root, "SecureActionButtonTemplate")
    state.root, state.overlay = root, overlay
    overlay:Hide()
    overlay:EnableMouse(true)
    overlay:EnableMouseWheel(false)
    overlay:SetPropagateMouseMotion(true)
    overlay:SetPropagateMouseClicks(true)
    state.propagateClicks = true
    if overlay.SetPassThroughButtons then
        overlay:SetPassThroughButtons("RightButton", "MiddleButton", "Button4", "Button5")
    end
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:SetAttribute("useOnKeyDown", false)
    overlay:SetScript("PreClick", PreClick)
    overlay:SetScript("PostClick", PostClick)
    -- Keep the template's secure OnClick intact. Never call TargetUnit from
    -- ordinary Lua, and never execute clicks or targeting from a timer.
    RegisterStateDriver(root, "visibility", "[combat] hide; show")
    root:Show()
    CreateLabel()
    state.ready = true
    state.unsupported = nil
    RefreshTracking()
    UpdateGeometry()
    Print("v" .. VERSION .. " ready. Left-click a Track Humanoids dot outside combat. /ttf help")
end

local function ApplySettings()
    if InCombat() then return end
    if not state.db then LoadSettings() end
    if state.queued then
        for key, value in pairs(state.queued) do state.db[key] = value end
        state.queued = nil
    end
    state.enabled = state.db.enabled
    state.pending = nil
    state.cycleSignature, state.cycleIndex = nil, 0
    HideLabel()
    Initialize()
    if state.ready then
        ClearAction()
        PropagateClicks(true)
        RefreshTracking()
        UpdateGeometry()
    end
end

local function SetOption(key, value)
    if InCombat() then
        state.queued = state.queued or {}
        state.queued[key] = value
        Print("Setting queued until combat ends.")
        return
    end
    state.db[key] = value
    ApplySettings()
end

local function Debug()
    local version, build, _, interface = GetBuildInfo()
    Print("v" .. VERSION .. "; client=" .. tostring(version) .. "; build=" .. tostring(build) .. "; interface=" .. tostring(interface))
    Print("ready=" .. tostring(state.ready) .. "; combat=" .. tostring(not not InCombat()) .. "; enabled=" .. tostring(state.db.enabled) .. "; mode=" .. state.db.mode)
    RefreshTracking()
    Print("Track Humanoids=" .. tostring(state.hasTracking) .. "; tooltip API=" .. tostring(C_TooltipInfo and type(C_TooltipInfo.GetMinimapMouseover) == "function"))
    local names = Logic.ExtractNames(Read(C_TooltipInfo and C_TooltipInfo.GetMinimapMouseover))
    Print("Hovered names=" .. (#names > 0 and table.concat(names, " / ") or "none (keep the mouse over a dot)"))
    if state.overlay and state.overlay.CanPropagateMouseMotion then
        Print("Mouse motion passthrough=" .. tostring(state.overlay:CanPropagateMouseMotion()))
    end
end

local function Preview()
    if InCombat() then Print("Run the UI preview outside combat."); return end
    if not state.ready or not state.db.enabled or not state.db.panel then
        Print("Enable the addon and label first: /ttf on and /ttf panel on"); return
    end
    Print("UI preview only: sample Ally / Horde labels. This does not target anyone.")
    HideLabel()
    ShowLabel("Ally", .30, .65, 1, "UI PREVIEW", "Sample only. No player was selected.")
    local token = state.labelSerial
    C_Timer.After(2, function()
        if state.labelSerial ~= token or InCombat() then return end
        ShowLabel("Horde", 1, .30, .25, "UI PREVIEW", "Sample only. No player was selected.")
        local nextToken = state.labelSerial
        C_Timer.After(2, function() if state.labelSerial == nextToken then HideLabel() end end)
    end)
end

SLASH_TRACKTARGETFOREVER1 = "/ttf"
SLASH_TRACKTARGETFOREVER2 = "/tracktarget"
SlashCmdList.TRACKTARGETFOREVER = function(message)
    if not state.db then LoadSettings() end
    local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "on" or command == "off" then
        SetOption("enabled", command == "on")
        if not InCombat() then Print("Addon " .. command .. ".") end
    elseif command == "mode" and (argument == "direct" or argument == "shift") then
        SetOption("mode", argument)
        if not InCombat() then Print(argument == "direct" and "Direct left-click targeting." or "Shift + left-click targeting.") end
    elseif command == "panel" and (argument == "on" or argument == "off") then
        SetOption("panel", argument == "on")
        if not InCombat() then Print("Faction label " .. argument .. ".") end
    elseif command == "reset" then
        if InCombat() then
            state.queued = { enabled = true, mode = "direct", panel = true }
            Print("Reset queued until combat ends.")
        else
            TrackTargetForeverDB = { enabled = true, mode = "direct", panel = true }
            LoadSettings(); ApplySettings(); Print("Default settings restored.")
        end
    elseif command == "debug" then Debug()
    elseif command == "test" then Preview()
    else
        Print("Left-click a Track Humanoids dot on the MINIMAP to select your normal target. Outside combat.")
        Print("/ttf on | off; /ttf mode direct | shift; /ttf panel on | off; /ttf reset; /ttf debug; /ttf test")
        Print("Overlapping names: click again to select the next name. Right-click remains available to the game.")
    end
end

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        LoadSettings()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Initialize()
        if state.ready and not InCombat() then ApplySettings() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Secure parent handles hiding. No protected writes in this handler.
        state.pending = nil
        state.cycleSignature, state.cycleIndex = nil, 0
        HideLabel()
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplySettings()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if state.pending then
            ConfirmTarget(state.pending)
        elseif not ConfirmedTargetIsCurrent() then
            -- Target events can be delivered after PostClick already confirmed
            -- this same target. Retain its label until the target really changes.
            HideLabel()
        end
    elseif event == "MINIMAP_UPDATE_TRACKING" or event == "UPDATE_SHAPESHIFT_FORM" or event == "SPELLS_CHANGED" then
        RefreshTracking()
        if state.ready and not InCombat() then RefreshHover() end
    end
end)

eventFrame:SetScript("OnUpdate", function(self, elapsed)
    if not state.ready or InCombat() then return end
    state.elapsed = state.elapsed + elapsed
    if state.elapsed < .05 then return end
    local delta = state.elapsed
    state.elapsed = 0
    state.geometryElapsed = state.geometryElapsed + delta
    state.trackingElapsed = state.trackingElapsed + delta
    if state.trackingElapsed >= .5 then state.trackingElapsed = 0; RefreshTracking() end
    if state.geometryElapsed >= .25 then state.geometryElapsed = 0; UpdateGeometry() end
    RefreshHover()
end)

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "MINIMAP_UPDATE_TRACKING",
    "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED",
}) do
    eventFrame:RegisterEvent(event)
end
