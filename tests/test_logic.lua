-- Run from the workspace root: this suite needs no WoW client.
local Logic = dofile("TrackTargetForever/Logic.lua")
local count = 0
local function check(label, actual, expected)
    count = count + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function names(header, lowerLine)
    return Logic.ExtractNames({lines = {{leftText = header}, {leftText = lowerLine or "Guild Name"}}})
end

check("plain", Logic.CleanName("Thrall"), "Thrall")
check("spaces", Logic.CleanName("  First   Last  "), "First Last")
check("Unicode", Logic.CleanName("Денис Александров"), "Денис Александров")
check("accented", Logic.CleanName("Éowyn"), "Éowyn")
check("apostrophe", Logic.CleanName("Kael'thas"), "Kael'thas")
check("hyphen", Logic.CleanName("First-Last"), "First-Last")
check("period", Logic.CleanName("Dr. Boom"), "Dr. Boom")
check("hex color", Logic.CleanName("|cff00aa22First Last|r"), "First Last")
check("named color", Logic.CleanName("|cnHIGHLIGHT_FONT_COLOR:First Last|r"), "First Last")
check("atlas", Logic.CleanName("|A:UnitFrame-Alliance:16:16|a First Last"), "First Last")
check("texture", Logic.CleanName("|TInterface\\Icons\\INV_Misc:16|t First Last"), "First Last")
check("link", Logic.CleanName("|Hplayer:First Last:1|h[First Last]|h"), "First Last")
check("colored link", Logic.CleanName("|cffaaaaaa|Hplayer:Thrall:1|h[Thrall]|h|r"), "Thrall")
check("nil", Logic.CleanName(nil), nil)
check("number", Logic.CleanName(1234), nil)
check("empty", Logic.CleanName("   "), nil)
check("punctuation", Logic.CleanName("---"), nil)
check("oversize", Logic.CleanName(string.rep("a", 181)), nil)
check("max bytes", #Logic.CleanName(string.rep("a", 180)), 180)
for _, value in ipairs({
    "Name\n/attack", "Name\r/attack", "Name\tOther", "Name\0Other",
    "[combat] Name", "Name; Other", "/targetenemy", "Name\\Other",
    "Name|r|garbage", "<Guild>", "|Tbad\n/attack|tName",
    "|Hplayer:Name\n/attack|h[Name]|h",
}) do
    check("reject unsafe input " .. count, Logic.CleanName(value), nil)
end

local actual = names("First Last\nSecond Last\nFirst Last\nsecond last")
check("overlap count", #actual, 2)
check("overlap first", actual[1], "First Last")
check("overlap second", actual[2], "Second Last")
actual = names("|cff00ff00Thrall|r\n|cffff0000Jaina|r", "Level 60 Mage")
check("overlap color count", #actual, 2)
check("lower lines ignored", actual[3], nil)
check("empty first does not scrape guild", #names("", "Actual Guild"), 0)
check("missing first does not scrape guild", #Logic.ExtractNames({lines = {[2] = {leftText = "Guild"}}}), 0)
check("rightText ignored", #Logic.ExtractNames({lines = {{rightText = "Someone"}}}), 0)
check("malformed top-level", #Logic.ExtractNames(false), 0)
check("malformed lines", #Logic.ExtractNames({lines = false}), 0)
check("malformed line", #Logic.ExtractNames({lines = {42}}), 0)
check("malformed text", #names({}), 0)
actual = names("Name\n/attack\n[combat] Other\nSafe Person")
check("malicious extra lines removed", #actual, 2)
check("valid subsequent candidate", actual[2], "Safe Person")
actual = names("Name\r\nOther\r\n")
check("CRLF count", #actual, 2)

check("macro", Logic.BuildMacro("First Last"), "/targetexact [nocombat] First Last")
check("macro sanitizes", Logic.BuildMacro("|cff00ff00Thrall|r"), "/targetexact [nocombat] Thrall")
check("macro rejects command injection", Logic.BuildMacro("Thrall\n/startattack"), nil)
check("macro rejects options", Logic.BuildMacro("[combat] Thrall"), nil)

check("NPC match", Logic.NamesMatch("Training Dummy", "Training Dummy", nil, false), true)
check("NPC mismatch", Logic.NamesMatch("Training Dummy", "Raider's Training Dummy", nil, false), false)
check("no partial NPC names", Logic.NamesMatch("Dummy", "Training Dummy", nil, false), false)
check("NPC secondary ignored", Logic.NamesMatch("Dummy", "Dummy", "Realm", false), true)
check("single player name", Logic.NamesMatch("Thrall", "Thrall", nil, true), true)
check("empty surname", Logic.NamesMatch("Thrall", "Thrall", "", true), true)
check("case folded", Logic.NamesMatch("THRALL", "Thrall", nil, true), true)
check("surname exact", Logic.NamesMatch("First Last", "First", "Last", true), true)
check("surname hyphen alias", Logic.NamesMatch("First-Last", "First", "Last", true), true)
check("wrong surname", Logic.NamesMatch("First Other", "First", "Last", true), false)
check("first only is ambiguous", Logic.NamesMatch("First", "First", "Last", true), false)
check("first already full", Logic.NamesMatch("First Last", "First Last", "Last", true), true)
check("already full hyphen alias", Logic.NamesMatch("First-Last", "First Last", "Last", true), true)
check("already hyphen full", Logic.NamesMatch("First Last", "First-Last", "Last", true), true)
check("already full still no first-only", Logic.NamesMatch("First", "First Last", "Last", true), false)
check("already full no double surname", Logic.NamesMatch("First Last Last", "First Last", "Last", true), false)
check("unicode surname", Logic.NamesMatch("Денис Александров", "Денис", "Александров", true), true)
check("bad surname", Logic.NamesMatch("First", "First", {}, true), false)
check("bad target", Logic.NamesMatch("First", nil, nil, true), false)

-- The client guards are modeled with secret sentinels. They must never reach
-- parsing, concatenation or target confirmation.
local secret = setmetatable({}, {__tostring = function() error("secret read") end})
issecretvalue = function(value) return value == secret end
check("secret name", Logic.CleanName(secret), nil)
check("secret macro", Logic.BuildMacro(secret), nil)
check("secret header", #names(secret), 0)
check("secret table", #Logic.ExtractNames(secret), 0)
check("secret first line", #Logic.ExtractNames({lines = {secret}}), 0)
check("secret candidate", Logic.NamesMatch(secret, "Name", nil, true), false)
check("secret surname", Logic.NamesMatch("Name", "Name", secret, true), false)
check("secret player flag", Logic.NamesMatch("Name", "Name", nil, secret), false)
issecretvalue = function() error("unreadable") end
check("guard error fails closed", Logic.CleanName("Name"), nil)
issecretvalue = nil

print("PASS: " .. count .. " pure logic checks")
