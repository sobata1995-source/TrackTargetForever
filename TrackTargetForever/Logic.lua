-- TrackTarget Forever: deterministic tooltip/name handling.
-- This file has no frame, target, chat or SavedVariables side effects.
local addonName, ns = ...
ns = ns or {}

local Logic = {}
ns.Logic = Logic

local MAX_NAME_BYTES = 180

-- Secret values must be rejected before concatenation, comparison or parsing.
-- A failed guard is treated as unreadable data, never as permission to use it.
local function IsSecret(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then
            return true
        end
    end
    return false
end

local function IsReadableString(value)
    return not IsSecret(value) and type(value) == "string"
end

local function Trim(value)
    return (value:gsub("^ +", ""):gsub(" +$", ""))
end

local function StripMarkup(value)
    -- Only actual hyperlink wrappers may supply decorative outer brackets.
    -- Bare brackets are rejected below because they are macro condition syntax.
    value = value:gsub("|H[^|]*|h(.-)|h", function(label)
        if label:sub(1, 1) == "[" and label:sub(-1) == "]" then
            label = label:sub(2, -2)
        end
        return label
    end)
    value = value:gsub("|T.-|t", "")
    value = value:gsub("|A.-|a", "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|cn[%w_]+:", "")
    value = value:gsub("|r", "")
    return value
end

function Logic.CleanName(value)
    if not IsReadableString(value) then
        return nil
    end
    -- Controls are never valid in one command argument. Do this before markup
    -- removal so a hidden newline in a texture/link cannot enter a macro.
    if value:find("[%c]") then
        return nil
    end
    value = Trim(StripMarkup(value)):gsub(" +", " ")
    if value == "" or #value > MAX_NAME_BYTES then
        return nil
    end
    -- Preserve Unicode, apostrophes, hyphens and ordinary NPC punctuation.
    -- Reject macro options/separators, command prefixes and leftover escapes.
    if value:find("[%[%];/\\|<>]") then
        return nil
    end
    -- A name made solely of punctuation cannot identify a useful target.
    if not value:find("[%w\128-\255]") then
        return nil
    end
    return value
end

local function ReadHeader(data)
    if IsSecret(data) or type(data) ~= "table" then
        return nil
    end
    local lines = data.lines
    if IsSecret(lines) or type(lines) ~= "table" then
        return nil
    end
    local firstLine = lines[1]
    if IsSecret(firstLine) or type(firstLine) ~= "table" then
        return nil
    end
    local header = firstLine.leftText
    if not IsReadableString(header) then
        return nil
    end
    return header
end

function Logic.ExtractNames(tooltipData)
    local names = {}
    -- The client may return unreadable tooltip fields or a malformed response.
    -- Reading only the first header prevents guild/level/description text from
    -- being interpreted as additional targets.
    local ok, header = pcall(ReadHeader, tooltipData)
    if not ok or not header then
        return names
    end
    header = header:gsub("\r\n", "\n")
    local seen = {}
    for line in (header .. "\n"):gmatch("(.-)\n") do
        local name = Logic.CleanName(line)
        if name then
            local key = name:lower()
            if not seen[key] then
                seen[key] = true
                names[#names + 1] = name
            end
        end
    end
    return names
end

function Logic.BuildMacro(name)
    name = Logic.CleanName(name)
    if not name then
        return nil
    end
    -- The condition is also a last-line guard against a pre-combat click
    -- reaching the secure action after combat has begun.
    return "/targetexact [nocombat] " .. name
end

local function SameName(a, b)
    return a:lower() == b:lower()
end

function Logic.NamesMatch(candidate, first, surname, isPlayer)
    candidate = Logic.CleanName(candidate)
    first = Logic.CleanName(first)
    if not candidate or not first or IsSecret(isPlayer) then
        return false
    end
    if IsSecret(surname) then
        return false
    end
    -- NPCs have a single name; a secondary API return is irrelevant to them.
    if not isPlayer then
        return SameName(candidate, first)
    end

    local hasSurname = IsReadableString(surname) and Trim(surname) ~= ""
    if not hasSurname then
        -- Unexpected nonempty/non-string secondary data cannot establish a
        -- player's identity. nil/empty is the documented no-surname case.
        if surname ~= nil and surname ~= "" then
            return false
        end
        return SameName(candidate, first)
    end
    surname = Logic.CleanName(surname)
    if not surname then
        return false
    end

    -- Some callers already provide a full first return alongside the surname.
    -- Accept that full form only when its suffix really is this surname.
    local lowerFirst = first:lower()
    local lowerSurname = surname:lower()
    local spaceSuffix = " " .. lowerSurname
    local hyphenSuffix = "-" .. lowerSurname
    if lowerFirst:sub(-#spaceSuffix) == spaceSuffix then
        local given = first:sub(1, #first - #spaceSuffix)
        return SameName(candidate, first) or SameName(candidate, given .. "-" .. surname)
    end
    if lowerFirst:sub(-#hyphenSuffix) == hyphenSuffix then
        local given = first:sub(1, #first - #hyphenSuffix)
        return SameName(candidate, first) or SameName(candidate, given .. " " .. surname)
    end
    return SameName(candidate, first .. " " .. surname)
        or SameName(candidate, first .. "-" .. surname)
end

return Logic
