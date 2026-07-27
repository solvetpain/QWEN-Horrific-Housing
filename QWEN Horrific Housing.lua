--[[
    HORRIFIC HELPER  —  Matcha LuaVM edition
    Game: Horrific Housing (roblox.com/games/263761432)
    UI:   INS-ui library
    Menu: F7

    ─────────────────────────────────────────────────────────────
    WHY THE OLD AUTO SWING DID NOTHING
    ─────────────────────────────────────────────────────────────
    Matcha is not an executor. Its Instance API is a fixed list:

        Name ClassName Parent Address FindFirstChild FindFirstChildOfClass
        FindFirstChildWhichIsA GetChildren GetDescendants GetFullName
        GetAttribute GetAttributes SetAttribute IsA IsDescendantOf WaitForChild

    There is NO Tool:Activate(), NO Tool.Enabled, NO :Destroy(),
    NO FireServer, NO fireclickdetector. Calls to them fail silently.
    Only these BasePart fields are writable:

        Size Position Transparency Color Velocity
        AssemblyLinearVelocity CanCollide

    So every "action" here is real mouse/keyboard input, and every
    "removal" is a property change or a teleport -- never :Destroy().

    Two bugs that made swinging look broken:
      1. press+release fired in the same tick, so Roblox never saw a
         click. There is now a real hold time between them.
      2. INS-ui calls setrobloxinput(false) while the menu is open,
         which blocks input to the game. Swinging now pauses while
         the menu is open and tells you so.
--]]

------------------------------------------------------------------
-- 0. BOOTSTRAP
------------------------------------------------------------------

if _G.NadoMatchaCleanup then pcall(_G.NadoMatchaCleanup) end

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")

local LP, tries = nil, 0
while not LP and tries < 50 do
    tries = tries + 1
    pcall(function() LP = Players.LocalPlayer end)
    if not LP then task.wait(0.1) end
end
if not LP then
    warn("[Nado] No LocalPlayer. Run the script after the game has loaded.")
    return
end

pcall(function() setrobloxinput(true) end)

local Running = true

------------------------------------------------------------------
-- 1. STATE
------------------------------------------------------------------

local SAVE_FILE = "NadoHorrific.json"

local State = {
    -- Event handlers
    AntiWater   = false,
    AntiBomb    = false,
    AntiVoid    = false,
    HoverHeight = 12,
    PushDist    = 28,

    -- Appearance (INS-ui handles the rest in its own Theme tab)
    Theme       = "",     -- empty = keep whatever the library/config already has
    ConfigName  = "default",
    AutoSaveUI  = true,

    -- Role ESP (Murder Mystery event)
    RoleESP     = false,
    ESPBox      = true,
    ESPName     = true,
    ESPRole     = true,
    ESPLine     = false,
    ESPOnlyRole = false,   -- draw only murderer / sheriff
    ESPRange    = 2000,

    -- Loadout window (separate floating box)
    LoadoutBox  = false,
    BoxSortRole = true,   -- murderer / sheriff first
    BoxHideIdle = false,  -- hide players holding nothing
    BoxX        = 20,
    BoxY        = 200,

    -- Misc
    ScanRate    = 4,      -- workspace scans per 10 seconds (was 10: too heavy)
    LowSpec     = false,  -- halve every refresh rate on weak machines
    ESPRate     = 15,     -- ESP redraws per second
}

local function SaveSettings()
    local ok, enc = pcall(function() return HttpService:JSONEncode(State) end)
    if ok and enc then pcall(function() writefile(SAVE_FILE, enc) end) end
end

local function LoadSettings()
    if type(isfile) ~= "function" or not isfile(SAVE_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if State[k] ~= nil and type(State[k]) == type(v) then State[k] = v end
        end
    end
end
LoadSettings()
-- Clamp anything an older config might hold too high for the VM.
if type(State.ScanRate) ~= "number" or State.ScanRate > 10 then State.ScanRate = 4 end
if type(State.ESPRate)  ~= "number" or State.ESPRate  > 30 then State.ESPRate  = 15 end

------------------------------------------------------------------
-- 2. HELPERS
------------------------------------------------------------------

local function GetChar()
    local ok, c = pcall(function() return LP.Character end)
    if ok then return c end
    return nil
end

local function GetHRP()
    local char = GetChar()
    if not char then return nil end
    local ok, p = pcall(function() return char:FindFirstChild("HumanoidRootPart") end)
    if ok then return p end
    return nil
end

-- healthReadable stays false when Matcha cannot read the Humanoid, so an
-- unreadable health value is never mistaken for "you are dead".
local healthReadable = false

local function GetHealth()
    local char = GetChar()
    if not char then return 0 end
    local ok, hum = pcall(function() return char:FindFirstChildOfClass("Humanoid") end)
    if not ok or not hum then healthReadable = false return 0 end
    local h, got = 0, false
    pcall(function() h = hum.Health got = type(h) == "number" end)
    healthReadable = got
    if not got then return 0 end
    return h
end

local function IsAlive()
    local h = GetHealth()
    if not healthReadable then return true end
    return h > 0
end

local function SetPosition(part, v)
    if not part then return false end
    if pcall(function() part.Position = v end) then return true end
    return pcall(function() part.CFrame = CFrame.new(v.X, v.Y, v.Z) end)
end

local function lower(s) return string.lower(tostring(s)) end

local function matchAny(name, words)
    local n = lower(name)
    for _, w in ipairs(words) do
        if string.find(n, w, 1, true) then return true end
    end
    return false
end

-- Position of a part or of a model's primary/any part
local function PosOf(inst)
    local p
    pcall(function() p = inst.Position end)
    if p then return p end
    pcall(function()
        if inst:IsA("Model") then
            local pp = inst.PrimaryPart
            if pp then p = pp.Position end
        end
    end)
    if p then return p end
    pcall(function()
        local h = inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart")
        if h then p = h.Position end
    end)
    return p
end


------------------------------------------------------------------
-- 2b. PLAYER CACHE  (one shared scan instead of many per frame)
------------------------------------------------------------------
--[[
    Every property read in Matcha is a cross-process memory read. The old code
    re-walked every player's character in ESPStep AND again in TargetInRange
    on every tick, which is what kept freezing the VM.

    Now a single background thread refreshes one table a few times per second,
    and everything else just reads that table.
--]]

local PlayerInfo = {}      -- array of { plr, name, root, pos, hp, tool, role }
local infoBuiltAt = -math.huge

local ROLE_MURDER  = { "murderer", "murder", "knife", "dagger", "machete", "cleaver" }
local ROLE_SHERIFF = { "sheriff", "revolver", "peacemaker", "pistol", "gun" }
local ROLE_ARMED   = {
    "sword", "blade", "illumina", "darkheart", "katana", "saber", "lightsaber",
    "scythe", "axe", "hammer", "bonk", "gauntlet", "launcher", "sniper",
    "staff", "flute", "note",
}

-- Collect EVERY tool a player owns, not just the equipped one.
-- Character  = equipped. Backpack = carried but not out.
-- Backpack is usually only readable for the local player, so for others we
-- fall back to the equipped item; that limit is stated in the UI.
local function ToolsOfPlayer(plr, char)
    local held, bag = nil, {}

    pcall(function()
        local kids = char and char:GetChildren()
        if not kids then return end
        for _, o in pairs(kids) do
            local cls
            pcall(function() cls = o.ClassName end)
            if cls == "Tool" then held = o.Name return end
            if cls ~= "Part" and cls ~= "MeshPart" and cls ~= "Humanoid" and
               cls ~= "Accessory" and cls ~= "Shirt" and cls ~= "Pants" and
               cls ~= "Folder" and cls ~= "BodyColors" and cls ~= "Animator" then
                local h
                pcall(function() h = o:FindFirstChild("Handle") end)
                if h then held = o.Name return end
            end
        end
    end)

    pcall(function()
        local bp = plr:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local kids = bp:GetChildren()
        if not kids then return end
        for _, o in pairs(kids) do
            local nm
            pcall(function() nm = o.Name end)
            if nm then bag[#bag + 1] = nm end
        end
    end)

    -- Roblox usually hides other players' Backpack from us, so if we found
    -- nothing there, look for role-revealing accessories and welded parts on
    -- the character itself. A drawn knife or gun is often a child part.
    if not held and #bag == 0 and char then
        pcall(function()
            local kids = char:GetChildren()
            if not kids then return end
            for _, o in pairs(kids) do
                local nm, cls
                pcall(function() nm = o.Name cls = o.ClassName end)
                if nm and cls ~= "Humanoid" and cls ~= "Shirt" and cls ~= "Pants" then
                    if matchAny(nm, ROLE_MURDER) or matchAny(nm, ROLE_SHERIFF) then
                        held = nm
                        return
                    end
                end
            end
        end)
    end

    return held, bag
end

local function ToolOfChar(char)
    if not char then return nil end
    local found
    pcall(function()
        local kids = char:GetChildren()
        if not kids then return end
        for _, o in pairs(kids) do
            local cls
            pcall(function() cls = o.ClassName end)
            if cls == "Tool" then found = o.Name return end
            if cls ~= "Part" and cls ~= "MeshPart" and cls ~= "Humanoid" and
               cls ~= "Accessory" and cls ~= "Shirt" and cls ~= "Pants" and
               cls ~= "Folder" and cls ~= "BodyColors" and cls ~= "Animator" then
                local h
                pcall(function() h = o:FindFirstChild("Handle") end)
                if h then found = o.Name return end
            end
        end
    end)
    return found
end

local function ClassifyTool(toolName)
    if not toolName then return "none" end
    if matchAny(toolName, ROLE_MURDER)  then return "murderer" end
    if matchAny(toolName, ROLE_SHERIFF) then return "sheriff"  end
    if matchAny(toolName, ROLE_ARMED)   then return "armed"    end
    return "holding"
end

-- Per player persistent record. Name, DisplayName and the Character
-- model barely ever change, so they are read ONCE and reused. Only the
-- things that actually move (position, health) are re-read every pass.
local infoByPlayer = {}
local slowTick = 0

local function RefreshPlayerInfo()
    local players
    local ok = pcall(function() players = Players:GetPlayers() end)
    if not ok or not players then return end

    slowTick = slowTick + 1
    local doSlow = (slowTick % 5 == 0)   -- tools/backpack ~1x per second

    local out, alive = {}, {}

    for _, plr in pairs(players) do
        if plr ~= LP then
            alive[plr] = true
            local e = infoByPlayer[plr]

            if not e then
                -- first sighting: read the static fields a single time
                e = { plr = plr, name = "?", hp = 0, maxhp = 100 }
                pcall(function() e.name = plr.Name end)
                pcall(function()
                    if plr.DisplayName then e.display = plr.DisplayName end
                end)
                infoByPlayer[plr] = e
                e.charStamp = nil
            end

            local char
            pcall(function() char = plr.Character end)

            if char ~= e.char then
                -- respawned: the part references we cached are now dead
                e.char = char
                e.root, e.head = nil, nil
                e.tool, e.bag, e.role = nil, nil, "none"
                if char then
                    pcall(function() e.root = char:FindFirstChild("HumanoidRootPart") end)
                    pcall(function() e.head = char:FindFirstChild("Head") end)
                    pcall(function() e.hum = char:FindFirstChildOfClass("Humanoid") end)
                else
                    e.hum = nil
                end
            end

            if e.root then
                -- the only field that truly must be fresh every pass
                pcall(function() e.pos = e.root.Position end)
            else
                e.pos = nil
            end

            if e.hum then
                pcall(function() e.hp = e.hum.Health end)
            else
                e.hp = 0
            end

            -- tools change rarely; scanning them 5x a second was the
            -- single most expensive thing this script did
            -- a brand new player (or a fresh respawn) is scanned at once,
            -- otherwise a murderer could stay unlabelled for a second
            if char and (doSlow or e.tool == nil) then
                local held, bag = ToolsOfPlayer(plr, char)
                e.tool = held
                e.bag  = bag
                e.role = ClassifyTool(held)
                if e.role == "none" or e.role == "holding" then
                    for _, itemName in ipairs(bag or {}) do
                        local c = ClassifyTool(itemName)
                        if c == "murderer" or c == "sheriff" then e.role = c break end
                    end
                end
            end

            out[#out + 1] = e
        end
    end

    -- drop records for players who left
    for plr in pairs(infoByPlayer) do
        if not alive[plr] then infoByPlayer[plr] = nil end
    end

    PlayerInfo = out
end

------------------------------------------------------------------
-- 3. WORKSPACE SCANNER (shared by every event handler)
------------------------------------------------------------------

local DANGER = {
    Water   = { flag = "AntiWater",   mode = "hover",
                words = { "water", "flood", "tsunami", "wave", "ocean" } },
    Bomb    = { flag = "AntiBomb",    mode = "push",
                words = { "bomb", "nuke", "missile", "rocket", "explos",
                          "tnt", "dynamite", "mine" } },
}

-- Names that merely CONTAIN a danger word but are harmless. Without this
-- "Fireplace" decor or a "FireExtinguisher" gear would shove you around
-- forever, which is what made Anti-Fire feel broken.
local DANGER_IGNORE = {
    "extinguisher", "fireplace", "firework", "fireflies", "campfirelog",
    "firetruck", "waterfall", "watermelon", "lavalamp", "beehiveornament",
}

local dangerCache = {}
local lastScanAt, scanCount, scanCost = 0, 0, 0

local function AnyDangerOn()
    for _, d in pairs(DANGER) do
        if State[d.flag] then return true end
    end
    return false
end

-- Scanning the whole map in one go took ~8ms on a busy server, which is
-- longer than a frame. Whatever you clicked during that window was simply
-- never processed, which felt like "the menu ignores me".
-- The work is now split into chunks with a yield between them, so input
-- always gets a turn.
-- Resumable scan.
--
-- The previous version called wait() inside the loop, but the worker calls
-- this through pcall, and Lua cannot yield across a pcall boundary. The
-- scan therefore died on its very first chunk with a silent error, which
-- is why hazard features stopped reacting.
--
-- Now the work is spread across calls instead: each call processes a slice
-- and remembers where it stopped. No yielding, same smooth behaviour.
local scanList, scanPos, scanAcc = nil, 1, {}
local SCAN_CHUNK = 400

local function ScanWorkspace()
    local t0 = tick()

    if not AnyDangerOn() then
        dangerCache, scanList, scanPos, scanAcc = {}, nil, 1, {}
        return
    end

    -- start a fresh pass
    if not scanList then
        local ok, list = pcall(function() return Workspace:GetDescendants() end)
        if not ok or not list then return end
        scanList, scanPos, scanAcc = list, 1, {}
    end

    local total = #scanList
    local stop = scanPos + SCAN_CHUNK - 1
    if stop > total then stop = total end

    for idx = scanPos, stop do
        local o = scanList[idx]
        local nm
        pcall(function() nm = o.Name end)
        if nm then
            local isPart = false
            pcall(function() isPart = o:IsA("BasePart") end)
            if isPart and not matchAny(nm, DANGER_IGNORE) then
                for tag, def in pairs(DANGER) do
                    if State[def.flag] and matchAny(nm, def.words) then
                        scanAcc[#scanAcc + 1] = { inst = o, tag = tag, mode = def.mode }
                        break
                    end
                end
            end
        end
    end

    scanPos = stop + 1

    -- finished the whole map: publish the result and reset
    if scanPos > total then
        dangerCache = scanAcc
        scanList, scanPos, scanAcc = nil, 1, {}
        scanCount = scanCount + 1
        scanCost  = math.floor((tick() - t0) * 1000)
    end
end



------------------------------------------------------------------
-- 4. EVENT REACTIONS
------------------------------------------------------------------

local lastSafePos  = nil
local hoverActive  = false
local eventStatus  = "idle"
local reactions    = 0

local lastDangerAt = -math.huge

local function DangerStep()
    -- Cheapest possible exit: if nothing is enabled we must not touch
    -- tick(), the character, or anything else. This runs every frame.
    if not (State.AntiVoid or #dangerCache > 0) then
        if hoverActive then hoverActive = false end
        return
    end

    local nowD = tick()
    if nowD - lastDangerAt < 0.05 then return end
    lastDangerAt = nowD

    local hrp = GetHRP()
    if not hrp or not IsAlive() then hoverActive = false return end

    local myPos
    pcall(function() myPos = hrp.Position end)
    if not myPos then return end

    if myPos.Y > -5 then lastSafePos = myPos end

    -- Anti-Void first: it does not need the scanner
    if State.AntiVoid and myPos.Y < -30 and lastSafePos then
        SetPosition(hrp, Vector3.new(lastSafePos.X, lastSafePos.Y + 18, lastSafePos.Z))
        pcall(function() hrp.Velocity = Vector3.new(0, 0, 0) end)
        eventStatus = "anti-void: pulled you back"
        reactions = reactions + 1
        return
    end

    if #dangerCache == 0 then
        hoverActive = false
        return
    end

    local bestHover, bestHoverY, bestHoverTag = nil, nil, nil
    local pushX, pushZ, pushTag, pushClose = 0, 0, nil, nil

    for _, d in ipairs(dangerCache) do
        local inst = d.inst
        local p, sz
        pcall(function() p = inst.Position sz = inst.Size end)
        if p and sz then
            local dx, dz = myPos.X - p.X, myPos.Z - p.Z
            local flat = math.sqrt(dx * dx + dz * dz)
            -- A spinner blade is long and thin. Using its LONG side as the
            -- danger radius made it trigger from 30+ studs away, which felt
            -- like it was doing nothing useful. Use the short side instead,
            -- because that is the part that actually sweeps through you.
            local longSide  = math.max(sz.X, sz.Z)
            local shortSide = math.min(sz.X, sz.Z)
            local reach
            if longSide > shortSide * 4 then
                reach = longSide * 0.5 + 4      -- thin blade: keep full length
            else
                reach = longSide * 0.5 + 6      -- ordinary plate
            end

            if d.mode == "hover" then
                local topY = p.Y + sz.Y * 0.5

                -- HYSTERESIS.
                -- The old check re-triggered only below (top + HoverHeight),
                -- so the moment we teleported to exactly that height the test
                -- failed, gravity pulled us down, and it fired again next
                -- frame: a permanent bounce that never actually protected you.
                -- Now we hold anywhere inside a band around the target height.
                local target = topY + State.HoverHeight
                local band   = math.max(4, State.HoverHeight * 0.5)
                -- A spinner sits at player height, so "am I below its top"
                -- is not enough: we must also react when we are level with it.
                local levelWith = math.abs(myPos.Y - p.Y) < (sz.Y * 0.5 + 6)
                if flat < reach and (myPos.Y < target + band or levelWith) then
                    if not bestHoverY or topY > bestHoverY then
                        bestHoverY   = topY
                        bestHover    = inst
                        bestHoverTag = d.tag
                    end
                end
            else
                -- PUSH.
                -- Radius used to be (part size + PushDist), so a 4 stud
                -- campfire owned a 30 stud circle and you could never stand
                -- anywhere. Now PushDist IS the distance we keep from its edge.
                local edge   = math.max(sz.X, sz.Z) * 0.5
                local radius = edge + State.PushDist
                if flat < radius and flat > 0.1 then
                    local w = (radius - flat) / radius
                    pushX = pushX + (dx / flat) * w
                    pushZ = pushZ + (dz / flat) * w
                    pushTag = d.tag
                    if not pushClose or flat < pushClose then pushClose = flat end
                end
            end
        end
    end

    if bestHover then
        local want = bestHoverY + State.HoverHeight
        -- only move when we are actually off target, so we stop jittering
        if math.abs(myPos.Y - want) > 1.5 then
            SetPosition(hrp, Vector3.new(myPos.X, want, myPos.Z))
        end
        -- cancel the fall instead of fighting it every frame
        pcall(function() hrp.Velocity = Vector3.new(0, 0, 0) end)
        if not hoverActive then reactions = reactions + 1 end
        hoverActive = true
        eventStatus = "hovering over " .. tostring(bestHoverTag)
        return
    end

    hoverActive = false

    if pushTag then
        local len = math.sqrt(pushX * pushX + pushZ * pushZ)
        if len > 0.01 then
            -- Step size now scales with how close the danger is: a gentle
            -- nudge far away, a hard shove when you are inside it. The old
            -- fixed 4 stud jump looked like teleport stutter.
            local step = 2
            if pushClose then
                if pushClose < 6 then step = 6
                elseif pushClose < 14 then step = 4 end
            end
            SetPosition(hrp, Vector3.new(
                myPos.X + (pushX / len) * step,
                myPos.Y,
                myPos.Z + (pushZ / len) * step))
            reactions = reactions + 1
            eventStatus = "backing away from " .. tostring(pushTag)
            return
        end
    end

    if eventStatus ~= "idle" and not hoverActive then eventStatus = "watching" end
end

------------------------------------------------------------------
-- 6. AUTO SWING  (real input -- the only option in Matcha)
------------------------------------------------------------------

local gcCache, gcRefreshAt, gcHits = nil, 0, 0
local menuIsOpen = function() return false end

------------------------------------------------------------------
-- 7c. ROLE ESP  (murderer / sheriff detection)
------------------------------------------------------------------
--[[
    Horrific Housing event: "A murderer is out! Will the sheriff stop him?"
      * Murderer gets the Murderer's Knife
      * Sheriff  gets the Sheriff's Gun

    A Tool moves INTO the character model when equipped, and Matcha can read
    child names, so the equipped tool is a reliable role signal client-side.
    A murderer hiding an unequipped knife cannot be seen -- no executor can
    read the backpack here -- but the moment they pull it out, they light up.
--]]

local espObjs, espReady = {}, false
local espFont
local roleCounts = { murderer = 0, sheriff = 0, armed = 0 }

local function espMake(kind, props)
    local ok, o = pcall(function() return Drawing.new(kind) end)
    if not ok or not o then return nil end
    if kind == "Text" then
        if espFont then pcall(function() o.Font = espFont end) end
        pcall(function() o.FontSize = 13 end)
        pcall(function() o.Size = 13 end)
        pcall(function() o.Center = true end)
        pcall(function() o.Outline = true end)
    end
    pcall(function() o.Transparency = 1 end)
    for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
    return o
end

local function BuildESP()
    if espReady then return end
    pcall(function()
        espFont = Drawing.Fonts and (Drawing.Fonts.SystemBold or Drawing.Fonts.System)
    end)
    espReady = true
end

local function espSlot(plr)
    local set = espObjs[plr]
    if set then return set end
    set = {
        box  = espMake("Square", { Filled = false, Thickness = 1, Visible = false, ZIndex = 6 }),
        name = espMake("Text",   { Visible = false, ZIndex = 8 }),
        role = espMake("Text",   { Visible = false, ZIndex = 8 }),
        line = espMake("Line",   { Thickness = 1, Visible = false, ZIndex = 5 }),
    }
    if not set.box then return nil end
    espObjs[plr] = set
    return set
end

-- Direct property write with its own pcall. Cheaper than wrapping a whole
-- block in pcall(function() ... end), which allocates a closure every call
-- and was running hundreds of times per second inside the ESP loop.
-- Remember the last value written to every Drawing property. Re-writing an
-- identical value still costs a full cross-process write, and most frames
-- change almost nothing, so this skips the majority of them.
local propCache = setmetatable({}, { __mode = "k" })

local function SameDrawingValue(a, b)
    if a == b then return true end

    -- Matcha exposes Roblox datatypes as userdata, not tables. Compare their
    -- public fields so fresh Vector2/Color3 objects with the same value do not
    -- cause another expensive Drawing write every ESP tick.
    local ax, ay, az, bx, by, bz
    if pcall(function()
        ax, ay = a.X, a.Y
        bx, by = b.X, b.Y
    end) and ax ~= nil and bx ~= nil then
        pcall(function() az, bz = a.Z, b.Z end)
        if az ~= nil or bz ~= nil then return ax == bx and ay == by and az == bz end
        return ax == bx and ay == by
    end

    local ar, ag, ab, br, bg, bb
    if pcall(function()
        ar, ag, ab = a.R, a.G, a.B
        br, bg, bb = b.R, b.G, b.B
    end) and ar ~= nil and br ~= nil then
        return ar == br and ag == bg and ab == bb
    end

    return false
end

local function SetProp(o, prop, val)
    if not o then return end
    local c = propCache[o]
    if not c then c = {} propCache[o] = c end
    local prev = c[prop]
    if prev ~= nil and SameDrawingValue(prev, val) then return end
    c[prop] = val
    pcall(function() o[prop] = val end)
end

-- Writing Visible on an already-hidden object still costs a cross-process
-- write, so remember the last state and only write on a real change.
local espVis = {}

local function espHide(set)
    if not set then return end
    if espVis[set] == false then return end
    espVis[set] = false

    -- Use SetProp, not a raw `o.Visible = false`. Raw writes left the property
    -- cache thinking the object was still visible; the next SetProp(..., true)
    -- could then be skipped and ESP stayed invisible forever after one hide.
    for _, o in pairs(set) do SetProp(o, "Visible", false) end
end

local lastESPAt = -math.huge

local function RoleStyle(role, toolName)
    if role == "murderer" then return Color3.fromRGB(255, 70, 70),  "MURDERER" end
    if role == "sheriff"  then return Color3.fromRGB(80, 170, 255), "SHERIFF"  end
    if role == "armed"    then return Color3.fromRGB(250, 190, 60), toolName or "ARMED" end
    if role == "holding"  then return Color3.fromRGB(190, 195, 205), toolName or "" end
    return Color3.fromRGB(150, 155, 165), ""
end

local espWasOn = false

local function ESPStep()
    if not espReady then return end

    if not State.RoleESP then
        -- Hide once on the switch-off frame, then do nothing at all.
        if espWasOn then
            espWasOn = false
            for _, set in pairs(espObjs) do espHide(set) end
            roleCounts.murderer, roleCounts.sheriff, roleCounts.armed = 0, 0, 0
        end
        return
    end
    espWasOn = true

    local nowT = tick()
    local espRate = State.ESPRate or 15
    if espRate < 1 then espRate = 1 end
    if State.LowSpec then espRate = espRate / 2 end
    if nowT - lastESPAt < (1 / espRate) then return end
    lastESPAt = nowT

    local myPos
    local hrp = GetHRP()
    pcall(function() if hrp then myPos = hrp.Position end end)

    local vw, vh = 1920, 1080
    pcall(function()
        local vp = Workspace.CurrentCamera.ViewportSize
        if vp and vp.X > 0 then vw, vh = vp.X, vp.Y end
    end)

    local mc, sc, ac = 0, 0, 0
    local seen = {}

    for _, e in ipairs(PlayerInfo) do
        local plr = e.plr
        seen[plr] = true
        local set = espSlot(plr)
        if not set then break end

        if e.role == "murderer" then mc = mc + 1
        elseif e.role == "sheriff" then sc = sc + 1
        elseif e.role == "armed" then ac = ac + 1 end

        if not e.pos or not e.head or e.hp <= 0 then
            espHide(set)
        else
            -- Cheap reject first: role filter costs nothing, and squared
            -- distance avoids a sqrt per player per frame.
            local skip = false
            if State.ESPOnlyRole and e.role ~= "murderer" and e.role ~= "sheriff" then
                skip = true
            end

            local dist = 0
            if not skip and myPos then
                local dx = e.pos.X - myPos.X
                local dy = e.pos.Y - myPos.Y
                local dz = e.pos.Z - myPos.Z
                local d2 = dx * dx + dy * dy + dz * dz
                local rng = State.ESPRange
                if d2 > rng * rng then
                    skip = true            -- out of range: never project it
                else
                    dist = math.sqrt(d2)
                end
            end

            if skip then
                espHide(set)
            else
                local hp2
                pcall(function() hp2 = e.head.Position end)
                if not hp2 then
                    espHide(set)
                else
                    local top, onTop = WorldToScreen(hp2 + Vector3.new(0, 1.6, 0))
                    local bot, onBot = WorldToScreen(e.pos - Vector3.new(0, 3.2, 0))

                    if not onTop and not onBot then
                        espHide(set)
                    else
                        espVis[set] = true
                        local col, label = RoleStyle(e.role, e.tool)
                        local h = math.abs(bot.Y - top.Y)
                        if h < 8 then h = 8 end
                        local w = h * 0.52
                        local x = top.X - w / 2

                        if State.ESPBox then
                            SetProp(set.box, "Position", Vector2.new(x, top.Y))
                            SetProp(set.box, "Size", Vector2.new(w, h))
                            SetProp(set.box, "Color", col)
                            SetProp(set.box, "Visible", true)
                        else SetProp(set.box, "Visible", false) end

                        if State.ESPName then
                            SetProp(set.name, "Text",
                                (e.display or e.name) .. "  " .. math.floor(dist) .. "m")
                            SetProp(set.name, "Position", Vector2.new(top.X, top.Y - 16))
                            SetProp(set.name, "Color", col)
                            SetProp(set.name, "Visible", true)
                        else SetProp(set.name, "Visible", false) end

                        if State.ESPRole and label ~= "" then
                            SetProp(set.role, "Text", label)
                            SetProp(set.role, "Position", Vector2.new(top.X, bot.Y + 2))
                            SetProp(set.role, "Color", col)
                            SetProp(set.role, "Visible", true)
                        else SetProp(set.role, "Visible", false) end

                        local drawLine = State.ESPLine
                        if drawLine and State.ESPOnlyRole and
                           e.role ~= "murderer" and e.role ~= "sheriff" then
                            drawLine = false
                        end
                        if drawLine then
                            SetProp(set.line, "From", Vector2.new(vw / 2, vh))
                            SetProp(set.line, "To", Vector2.new(top.X, bot.Y))
                            SetProp(set.line, "Color", col)
                            SetProp(set.line, "Visible", true)
                        else SetProp(set.line, "Visible", false) end
                    end
                end
            end
        end
    end

    for plr, set in pairs(espObjs) do
        if not seen[plr] then espHide(set) espObjs[plr] = nil end
    end

    roleCounts.murderer, roleCounts.sheriff, roleCounts.armed = mc, sc, ac
end



------------------------------------------------------------------
-- 8. UI LIBRARY
------------------------------------------------------------------

local Lib
do
    local URL   = "https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"
    local CACHE = "insui_cache.lua"

    local function tryLoad(b)
        if type(b) ~= "string" or #b < 500 then return nil end

        -- Matcha-specific: loadstring() drops top-level return values.
        -- INS-ui also publishes itself as global INSui / INSuiUI, so after
        -- executing the chunk we must read the global instead of relying only
        -- on `return Lib`.
        local fn
        local okCompile = pcall(function() fn = loadstring(b) end)
        if not okCompile or type(fn) ~= "function" then return nil end

        local okRun, r = pcall(function() return fn() end)
        if okRun and type(r) == "table" then return r end

        local g
        pcall(function() g = INSui end)
        if type(g) == "table" then return g end
        pcall(function() g = _G and _G.INSui end)
        if type(g) == "table" then return g end
        pcall(function()
            local env = getfenv and getfenv()
            if type(env) == "table" then g = env.INSui end
        end)
        if type(g) == "table" then return g end

        return nil
    end

    if type(readfile) == "function" then
        pcall(function()
            local b
            if type(isfile) ~= "function" or isfile(CACHE) then b = readfile(CACHE) end
            local r = tryLoad(b)
            if r then Lib = r end
        end)
    end

    if type(Lib) ~= "table" then
        local last
        for _ = 1, 8 do
            local b
            pcall(function() b = game:HttpGet(URL) end)
            if type(b) == "string" and #b > 1000 then
                last = b
                local r = tryLoad(b)
                if r then Lib = r break end
            end
            task.wait(0.4)
        end
        if type(Lib) == "table" and type(last) == "string" and type(writefile) == "function" then
            pcall(function() writefile(CACHE, last) end)
        end
    end

    if type(Lib) ~= "table" then pcall(function() Lib = INSui end) end
end

------------------------------------------------------------------
-- 9. CLEANUP GUARD (re-run safe, not a user button)
------------------------------------------------------------------

-- Forward-declared here so the cleanup closure below removes the actual
-- inventory window created later. A `local loadoutBox` declared after the
-- closure would be a different variable and cleanup would silently miss it.
local loadoutBox, loadoutLines = nil, {}

local mainConn = nil

_G.NadoMatchaCleanup = function()
    Running = false
    pcall(function()
        if loadoutBox then
            if loadoutBox.SetVisible then loadoutBox:SetVisible(false) end
            if loadoutBox.Remove then loadoutBox:Remove() end
        end
    end)
    for _, set in pairs(espObjs) do
        for _, o in pairs(set) do pcall(function() o.Visible = false o:Remove() end) end
    end
    pcall(SaveSettings)
    pcall(function() if mainConn then mainConn:Disconnect() end end)
    pcall(function() if Lib and Lib.Destroy then Lib:Destroy() end end)
    _G.NadoMatchaCleanup = nil
end


------------------------------------------------------------------
-- 7d. LOADOUT WINDOW  (separate floating box: who is holding what)
------------------------------------------------------------------
--[[
    Uses the library's CreateBox, so it is a real second window: it stays on
    screen with the main menu closed and does not block game input.

    It reads the shared PlayerInfo cache, so it costs nothing extra.
    "Inventory" here means the EQUIPPED item -- a backpack cannot be read
    from outside the Roblox process.
--]]

-- loadoutBox/loadoutLines are forward-declared above so cleanup can see them.
local BOX_ROWS = 20
local lastBoxAt = -math.huge

local ROLE_ORDER = { murderer = 1, sheriff = 2, armed = 3, holding = 4, none = 5 }
local INV_BOX_WIDTH, INV_BOX_MARGIN = 290, 20

local function GetInventoryTopRightPos()
    local vw, vh = 1920, 1080
    pcall(function()
        local vp = Workspace.CurrentCamera.ViewportSize
        if vp and vp.X > 0 then vw, vh = vp.X, vp.Y end
    end)
    local bx = vw - INV_BOX_WIDTH - INV_BOX_MARGIN
    if bx < INV_BOX_MARGIN then bx = INV_BOX_MARGIN end
    return bx, INV_BOX_MARGIN
end

local function ForceLoadoutTopRight()
    local bx, by = GetInventoryTopRightPos()
    State.BoxX, State.BoxY = bx, by
    pcall(function()
        if loadoutBox and loadoutBox._box then
            loadoutBox._box.x, loadoutBox._box.y = bx, by
        end
    end)
    return bx, by
end

local function BuildLoadoutBox()
    if loadoutBox or not Lib then return end

    -- Always start the inventory box in the top-right corner.
    -- Saved BoxX/BoxY are ignored on purpose so an old off-screen config
    -- cannot hide the window.
    local bx, by = GetInventoryTopRightPos()
    State.BoxX, State.BoxY = bx, by

    local ok = pcall(function()
        loadoutBox = Lib:CreateBox({
            title    = "INVENTORY",
            position = Vector2.new(bx, by),
            width    = INV_BOX_WIDTH,
            visible  = false,
        })
    end)
    if not ok or not loadoutBox then return end
    for i = 1, BOX_ROWS do
        local okL, line = pcall(function() return loadoutBox:Text("", Color3.fromRGB(150, 155, 165)) end)
        loadoutLines[i] = (okL and line) or nil
    end
end

local function LoadoutStep()
    if not loadoutBox then return end

    if not State.LoadoutBox then
        pcall(function() loadoutBox:SetVisible(false) end)
        return
    end

    local now = tick()
    if now - lastBoxAt < 0.3 then return end
    lastBoxAt = now

    -- Keep it top-right every time it opens/refreshes.
    ForceLoadoutTopRight()
    pcall(function() loadoutBox:SetVisible(true) end)

    local myPos
    local hrp = GetHRP()
    pcall(function() if hrp then myPos = hrp.Position end end)

    local rows = {}
    for _, e in ipairs(PlayerInfo) do
        if e.hp and e.hp > 0 then
            local role = e.role or "none"
            local bagN = e.bag and #e.bag or 0
            if not (State.BoxHideIdle and not e.tool and bagN == 0) then
                local d = 0
                if myPos and e.pos then d = (myPos - e.pos).Magnitude end
                rows[#rows + 1] = {
                    name = e.display or e.name,
                    tool = e.tool,
                    bag  = e.bag or {},
                    role = role,
                    dist = d,
                }
            end
        end
    end

    if State.BoxSortRole then
        table.sort(rows, function(a, b)
            local ra = ROLE_ORDER[a.role] or 9
            local rb = ROLE_ORDER[b.role] or 9
            if ra ~= rb then return ra < rb end
            return a.dist < b.dist
        end)
    else
        table.sort(rows, function(a, b) return a.dist < b.dist end)
    end

    -- Render: one header line per player, then one line per inventory item.
    local out = {}
    for _, r in ipairs(rows) do
        if #out >= BOX_ROWS then break end

        local col = RoleStyle(r.role, r.tool)
        local mark = ""
        if r.role == "murderer" then mark = "[M] "
        elseif r.role == "sheriff" then mark = "[S] " end

        local nm = r.name
        if #nm > 14 then nm = string.sub(nm, 1, 13) .. "." end

        out[#out + 1] = {
            text = string.format("%s%-14s %3dm", mark, nm, math.floor(r.dist)),
            col  = col,
        }

        -- equipped item first, marked so it is obvious it is in their hands
        if r.tool and #out < BOX_ROWS then
            local it = r.tool
            if #it > 20 then it = string.sub(it, 1, 19) .. "." end
            out[#out + 1] = { text = "    > " .. it, col = col }
        end

        -- everything else they carry
        for _, itemName in ipairs(r.bag) do
            if #out >= BOX_ROWS then break end
            local it = itemName
            if #it > 20 then it = string.sub(it, 1, 19) .. "." end
            out[#out + 1] = {
                text = "    - " .. it,
                col  = Color3.fromRGB(150, 155, 165),
            }
        end

        if not r.tool and #r.bag == 0 and #out < BOX_ROWS then
            out[#out + 1] = {
                text = "    (empty)",
                col  = Color3.fromRGB(110, 114, 122),
            }
        end
    end

    for i = 1, BOX_ROWS do
        local line = loadoutLines[i]
        if line then
            local row = out[i]
            if row then
                pcall(function() line:Set(row.text) line:SetColor(row.col) end)
            else
                pcall(function() line:Set("") end)
            end
        end
    end

    pcall(function()
        loadoutBox:SetTitle("INVENTORY  (" .. #rows .. ")")
    end)
end

------------------------------------------------------------------
-- 10. INTERFACE
------------------------------------------------------------------

local UIRef = { t = {} }

if Lib then
    -- Preset names differ between library versions (older builds have Mint/Indigo,
    -- newer ones Mocha/Catppuccin/Tokyo Night). Only apply a saved theme if that
    -- exact name exists in THIS build, and never override the user's own choice.
    local availablePresets = {}
    pcall(function()
        local list = Lib:ThemePresets()
        if type(list) == "table" then availablePresets = list end
    end)

    local function presetExists(name)
        if type(name) ~= "string" or name == "" then return false end
        for _, v in ipairs(availablePresets) do
            if v == name then return true end
        end
        return false
    end

    if presetExists(State.Theme) then
        pcall(function() Lib:ApplyThemePreset(State.Theme) end)
    end

    local window = Lib:CreateWindow({
        title      = "Horrific Helper",
        subtitle   = "Horrific Housing",
        size       = Vector2.new(600, 500),
        badge      = "v6",
        menuKey    = "f7",
        gameInput  = "always",
        startOpen  = false,
        configName = State.ConfigName,
        autoSave   = State.AutoSaveUI,
    })

    menuIsOpen = function()
        local o = false
        pcall(function() o = Lib:IsOpen() end)
        return o == true
    end

    local function PushStateToUI()
        pcall(function()
            for n, w in pairs(UIRef.t) do
                if w and w.Set and State[n] ~= nil then w:Set(State[n]) end
            end
        end)
    end

    ---------------------------------------------------------------
    -- COMBAT
    ---------------------------------------------------------------
    ---------------------------------------------------------------
    -- EVENTS
    ---------------------------------------------------------------
    local tabE = window:Tab("Events", "activity")

    local haz = tabE:Section("Hazard Events", "Left", "auto react to round events")

    UIRef.t.AntiWater = haz:Toggle("Anti-Flood / Tsunami", State.AntiWater, function(v)
        State.AntiWater = v SaveSettings()
    end, "Keeps you above rising water")

    UIRef.t.AntiBomb = haz:Toggle("Anti-Bomb / Nuke", State.AntiBomb, function(v)
        State.AntiBomb = v SaveSettings()
    end, "Walks you out of bomb, nuke, mine and missile blast range")

    UIRef.t.AntiVoid = haz:Toggle("Anti-Void", State.AntiVoid, function(v)
        State.AntiVoid = v SaveSettings()
    end, "Pulls you back if you fall off the map")

    UIRef.t.HoverHeight = haz:Slider("Hover Height", State.HoverHeight, 1, 4, 40, "studs", function(v)
        State.HoverHeight = math.floor(v) SaveSettings()
    end, "How high Anti-Water holds you above the danger")

    UIRef.t.PushDist = haz:Slider("Bomb Keep Distance", State.PushDist, 1, 5, 80, "studs", function(v)
        State.PushDist = math.floor(v) SaveSettings()
    end, "How far Anti-Bomb tries to keep you from explosives")

    ---------------------------------------------------------------
    -- ESP
    ---------------------------------------------------------------
    local tabP = window:Tab("ESP", "activity")
    local pe = tabP:Section("Role ESP", "Left", "murder mystery event")

    UIRef.t.RoleESP = pe:Toggle("Role ESP", State.RoleESP, function(v)
        State.RoleESP = v SaveSettings()
    end, "Red = murderer (knife), blue = sheriff (gun), yellow = other weapon")
    pcall(function() UIRef.t.RoleESP:AddKeybind("g", "Toggle") end)

    UIRef.t.ESPOnlyRole = pe:Toggle("Only Murderer / Sheriff", State.ESPOnlyRole, function(v)
        State.ESPOnlyRole = v SaveSettings()
    end, "Hide everyone who is not holding a knife or a gun")

    UIRef.t.ESPBox = pe:Toggle("Boxes", State.ESPBox, function(v)
        State.ESPBox = v SaveSettings()
    end)
    UIRef.t.ESPName = pe:Toggle("Names + Distance", State.ESPName, function(v)
        State.ESPName = v SaveSettings()
    end)
    UIRef.t.ESPRole = pe:Toggle("Role Label", State.ESPRole, function(v)
        State.ESPRole = v SaveSettings()
    end, "Prints MURDERER / SHERIFF or the weapon name")
    UIRef.t.ESPLine = pe:Toggle("Tracer Lines", State.ESPLine, function(v)
        State.ESPLine = v SaveSettings()
    end)
    UIRef.t.ESPRange = pe:Slider("ESP Range", State.ESPRange, 50, 100, 5000, "studs", function(v)
        State.ESPRange = v SaveSettings()
    end)

    local lb = tabP:Section("Inventory Window", "Right", "separate window: who has what")

    UIRef.t.LoadoutBox = lb:Toggle("Show Inventory Window", State.LoadoutBox, function(v)
        State.LoadoutBox = v SaveSettings()
    end, "Separate window with each nickname and their items")
    pcall(function() UIRef.t.LoadoutBox:AddKeybind("h", "Toggle") end)

    UIRef.t.BoxSortRole = lb:Toggle("Sort By Role", State.BoxSortRole, function(v)
        State.BoxSortRole = v SaveSettings()
    end, "Murderer and sheriff on top, then by distance")

    UIRef.t.BoxHideIdle = lb:Toggle("Hide Empty Hands", State.BoxHideIdle, function(v)
        State.BoxHideIdle = v SaveSettings()
    end, "Skip players with nothing at all")

    lb:Button("Move To Top Right", function()
        ForceLoadoutTopRight()
        pcall(function()
            if loadoutBox and loadoutBox._box then loadoutBox._box.visible = true end
        end)
        State.LoadoutBox = true
        pcall(function() UIRef.t.LoadoutBox:Set(true) end)
        SaveSettings()
        pcall(function() Lib:Notify("Inventory", "Window moved to the top right", 4, "info") end)
    end, "Inventory now always opens in the top-right corner")

    ---------------------------------------------------------------
    -- SETTINGS
    ---------------------------------------------------------------
    local tabCfg = window:Tab("Settings", "cog")
    local cfg = tabCfg:Section("Config", "Left", "save and restore")

    cfg:Button("Save Settings", function()
        SaveSettings()
        pcall(function() Lib:Notify("Config", "Saved", 3, "success") end)
    end)
    cfg:Button("Load Settings", function()
        LoadSettings() PushStateToUI()
        pcall(function() Lib:Notify("Config", "Loaded", 3, "success") end)
    end)
    cfg:Button("Reset To Defaults", function()
        State.AntiWater, State.AntiBomb                  = false, false
        State.AntiVoid                                  = false
        State.HoverHeight, State.PushDist, State.ScanRate  = 12, 28, 4
        State.ESPRate, State.LowSpec                       = 15, false
        State.RoleESP, State.ESPOnlyRole                   = false, false
        State.ESPBox, State.ESPName, State.ESPRole         = true, true, true
        State.ESPLine, State.ESPRange                      = false, 2000
        State.LoadoutBox, State.BoxSortRole                = false, true
        State.BoxHideIdle                                  = false
        -- Theme / ConfigName / AutoSaveUI intentionally preserved
        PushStateToUI() SaveSettings()
        pcall(function() Lib:Notify("Config", "Reset", 3, "info") end)
    end)

    ---------------------------------------------------------------
    -- APPEARANCE  (quick picks; full control lives in the Theme tab)
    ---------------------------------------------------------------
    local look = tabCfg:Section("Appearance", "Left", "colors, font, effects")

    local presets = availablePresets
    if #presets == 0 then presets = { "Default" } end
    local themeDefault = presetExists(State.Theme) and State.Theme or presets[1]

    look:Dropdown("Color Preset", { themeDefault }, presets, false, function(sel)
        local pick = type(sel) == "table" and sel[1] or sel
        if pick then
            State.Theme = pick
            pcall(function() Lib:ApplyThemePreset(pick) end)
            SaveSettings()
        end
    end, "Same presets as the Theme tab", true)

    -- Signature is Colorpicker(label, Color3, callback, alpha).
    -- Passing raw r,g,b numbers stores a number where a Color3 is expected,
    -- the renderer then throws and the library tears the whole UI down.
    look:Colorpicker("Accent 1", Color3.fromRGB(126, 217, 163), function(c)
        pcall(function() Lib:SetAccent(c, nil) end)
    end, 1)
    look:Colorpicker("Accent 2", Color3.fromRGB(70, 160, 115), function(c)
        pcall(function() Lib:SetAccent(nil, c) end)
    end, 1)

    local fonts = { "Default" }
    pcall(function()
        local f = Lib:FontChoices()
        if type(f) == "table" and #f > 0 then fonts = f end
    end)
    look:Dropdown("Font", { "Default" }, fonts, false, function(sel)
        local pick = type(sel) == "table" and sel[1] or sel
        if pick then pcall(function() Lib:SetFont(pick) end) end
    end, nil, true)

    local fx = { "Off" }
    pcall(function()
        local e = Lib:BackgroundEffects()
        if type(e) == "table" and #e > 0 then fx = e end
    end)
    look:Dropdown("Background FX", { "Off" }, fx, false, function(sel)
        local pick = type(sel) == "table" and sel[1] or sel
        if pick then pcall(function() Lib:SetBackgroundEffect(pick) end) end
    end, nil, true)

    look:Slider("Menu Opacity", 98, 1, 40, 100, "%", function(v)
        pcall(function() Lib:SetOpacity(v) end)
    end)
    look:Slider("Corner Radius", 100, 5, 0, 250, "%", function(v)
        pcall(function() Lib:SetRounding(v) end)
    end)

    look:Button("Open Full Theme Tab", function()
        pcall(function() Lib:OpenSettings() end)
    end, "Presets, rainbow, background, text color, layout")

    look:Button("Re-center Window", function()
        pcall(function() Lib:Center() end)
    end)

    look:Button("Update UI Library", function()
        if type(delfile) == "function" then
            pcall(function() delfile("insui_cache.lua") end)
            pcall(function()
                Lib:Notify("UI", "Cache cleared. Re-run the script for the newest themes.", 7, "info")
            end)
        end
    end, "Clears the cached UI library so the latest theme presets are downloaded")

    -- The library ships a full Theme tab (presets, accent pickers, rainbow,
    -- background FX, fonts, layout, configs). Enable it instead of reinventing it.
    pcall(function() window:AddSettingsTab("cog") end)

    pcall(function()
        Lib:Notify("Horrific Helper", "Loaded  -  F7 for the menu", 5, "success")
    end)
else
    warn("[Nado] UI library failed to load.")
    warn("[Nado] Enable Http Requests in Matcha settings and run again.")
    pcall(function() notify("UI failed - enable Http Requests", "Nado", 6) end)
end

------------------------------------------------------------------
-- 11. MAIN LOOP
------------------------------------------------------------------

-- no separate HUD builder in this build
pcall(BuildESP)
pcall(BuildLoadoutBox)
-- ONE background worker instead of four separate timer threads.
-- Fewer independent yields means far less scheduler churn inside Matcha.
task.spawn(function()
    local tickN = 0
    local lastScanAtW = -math.huge
    while Running do
        tickN = tickN + 1

        -- player cache: every pass (5 Hz) when something needs it
        if State.RoleESP or State.LoadoutBox then
            local slowDown = State.LowSpec or menuIsOpen()
            if not (slowDown and tickN % 2 == 1) then
                pcall(RefreshPlayerInfo)
            end
        elseif #PlayerInfo > 0 then
            PlayerInfo = {}
        end

        -- inventory window: every other pass (~2.5 Hz)
        if tickN % 2 == 0 then
            pcall(LoadoutStep)
        end

        -- While the menu is open the library is busy tracking the cursor and
        -- redrawing widgets. Running a full map scan in that window is what
        -- made buttons need a second press, so heavy work waits.
        local uiBusy = menuIsOpen()

        -- workspace hazard scan: on its own slower schedule
        if AnyDangerOn() and not uiBusy then
            local rate = State.ScanRate
            if rate < 1 then rate = 1 end
            if rate > 10 then rate = 10 end
            local due = 10 / rate
            local nowW = tick()

            -- If a scan is already in progress, continue the next chunk on
            -- every worker tick. The old scheduler waited the full `due`
            -- delay between chunks, so a large workspace could take 10+ sec
            -- to publish hazards and Anti-Sweeper/Anti-Bomb felt dead.
            if scanList or nowW - lastScanAtW >= due then
                if not scanList then lastScanAtW = nowW end
                pcall(ScanWorkspace)
                if not scanList then lastScanAtW = tick() end
            end
        elseif #dangerCache > 0 or scanList then
            dangerCache, scanList, scanPos, scanAcc = {}, nil, 1, {}
        end

        -- Idle much slower when nothing is enabled: 5 Hz of pointless
        -- wakeups was a measurable chunk of the frame budget.
        if State.RoleESP or State.LoadoutBox or AnyDangerOn() then
            wait(0.2)
        else
            wait(1.0)
        end
    end
end)


-- Master gate. When every visual/reactive feature is off there is nothing
-- for the renderer to do, so we skip the whole frame with ONE table lookup
-- instead of calling four functions that each re-check their own flags.
local function NeedsFrame()
    if State.RoleESP then return true end
    if State.AntiVoid then return true end
    if #dangerCache > 0 then return true end
    return false
end

local idleFrames = 0

local function Frame()
    if not Running then return end

    -- Give the whole frame to the UI while it is open. ESP boxes behind a
    -- fullscreen menu are not worth a single dropped click.
    if menuIsOpen() then
        if State.AntiVoid or #dangerCache > 0 then pcall(DangerStep) end
        return
    end

    if not NeedsFrame() then
        -- one tidy-up pass, then genuinely nothing
        if idleFrames == 0 then
            pcall(ESPStep)
        end
        idleFrames = idleFrames + 1
        return
    end
    idleFrames = 0

    -- these check their own flags and cost nothing when off
    pcall(DangerStep)
    pcall(ESPStep)
end

local okConn = pcall(function()
    mainConn = RunService.RenderStepped:Connect(Frame)
end)

if not okConn or not mainConn then
    task.spawn(function()
        while Running do Frame() task.wait() end
    end)
end

print("[Nado] Loaded. F7 for the menu." .. (Lib and "" or "  WARNING: no UI."))
