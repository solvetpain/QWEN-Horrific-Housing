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
    -- Combat
    AutoSwing   = false,
    SwingCPS    = 12,
    ClickHold   = 35,     -- ms the button stays down (0 = broken clicks)
    CDBypass    = false,  -- OFF: 47 GC writes per swing froze the VM
    RequireTool = false,   -- tool detection is unreliable in Matcha
    AutoEquip   = false,  -- press "1" when hands are empty
    KillAura    = true,   -- only swing when someone is actually in range
    AuraRange   = 15,     -- studs, same as the nado.txt kill aura
    MeleeOnly   = true,   -- do not spam clicks while holding a gun
    NeedFocus   = false,  -- pause when the Roblox window is not focused
    ShowHUD     = true,   -- on-screen status while the menu is closed

    -- Event handlers
    AntiLava    = false,
    AntiSweeper = false,
    AntiWater   = false,
    AntiBomb    = false,
    AntiFire    = false,
    AntiBees    = false,
    AntiVoid    = false,
    HoverHeight = 12,
    PushDist    = 28,

    -- Loot
    AutoLoot    = false,
    LootWeapons = true,
    LootNote    = true,
    LootGear    = true,
    LootRange   = 350,

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
    BoxY        = 320,

    -- Misc
    Noclip      = false,
    ScanRate    = 10,     -- workspace scans per 10 seconds
}

local function SaveSettings()
    local ok, enc = pcall(function() return HttpService:JSONEncode(State) end)
    if ok and enc then pcall(function() writefile(SAVE_FILE, enc) end) end
end

local function LoadSettings()
-- Older configs could hold CPS values high enough to stall the VM.
if State.SwingCPS > 20 then State.SwingCPS = 20 end
if State.ScanRate > 10 then State.ScanRate = 10 end
    if type(isfile) ~= "function" or not isfile(SAVE_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if State[k] ~= nil and type(State[k]) == type(v) then State[k] = v end
        end
    end
end
LoadSettings()

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

-- Matcha does not document a Tool class, so FindFirstChildOfClass("Tool")
-- can return nil even with a sword in hand. Try several ways.
local function GetEquippedTool()
    local char = GetChar()
    if not char then return nil end

    local ok, tool = pcall(function() return char:FindFirstChildOfClass("Tool") end)
    if ok and tool then return tool end

    ok, tool = pcall(function() return char:FindFirstChildWhichIsA("Tool") end)
    if ok and tool then return tool end

    -- last resort: walk the children and look for a Tool-shaped object
    local kids
    ok, kids = pcall(function() return char:GetChildren() end)
    if ok and kids then
        for _, o in pairs(kids) do
            local cls
            pcall(function() cls = o.ClassName end)
            if cls == "Tool" then return o end
            if cls ~= "Part" and cls ~= "MeshPart" and cls ~= "Humanoid" and
               cls ~= "Accessory" and cls ~= "Shirt" and cls ~= "Pants" then
                local handle
                pcall(function() handle = o:FindFirstChild("Handle") end)
                if handle then return o end
            end
        end
    end
    return nil
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
local infoBuiltAt = 0

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

local function RefreshPlayerInfo()
    local out = {}
    local players = {}
    pcall(function() players = Players:GetPlayers() end)

    for _, plr in pairs(players) do
        if plr ~= LP then
            local e = { plr = plr, name = "?", hp = 0 }
            pcall(function() e.name = plr.Name end)
            pcall(function() if plr.DisplayName then e.display = plr.DisplayName end end)

            local char
            pcall(function() char = plr.Character end)
            if char then
                pcall(function() e.root = char:FindFirstChild("HumanoidRootPart") end)
                pcall(function() e.head = char:FindFirstChild("Head") end)
                pcall(function()
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then e.hp = hum.Health end
                end)
                if e.root then pcall(function() e.pos = e.root.Position end) end
                local held, bag = ToolsOfPlayer(plr, char)
                e.tool = held
                e.bag  = bag
                e.role = ClassifyTool(held)
                -- if the murder weapon is only in the backpack, still flag it
                if e.role == "none" or e.role == "holding" then
                    for _, itemName in ipairs(bag) do
                        local c = ClassifyTool(itemName)
                        if c == "murderer" or c == "sheriff" then e.role = c break end
                    end
                end
            end
            out[#out + 1] = e
        end
    end

    PlayerInfo = out
    infoBuiltAt = tick()
end

------------------------------------------------------------------
-- 3. WORKSPACE SCANNER (shared by every event handler)
------------------------------------------------------------------

local DANGER = {
    Lava    = { flag = "AntiLava",    mode = "hover",
                words = { "lava", "magma" } },
    Sweeper = { flag = "AntiSweeper", mode = "hover",
                words = { "sweeper", "spinner", "spin", "laser", "beam",
                          "killbrick", "killpart", "rotor", "blade" } },
    Water   = { flag = "AntiWater",   mode = "hover",
                words = { "water", "flood", "tsunami", "wave", "ocean" } },
    Bomb    = { flag = "AntiBomb",    mode = "push",
                words = { "bomb", "nuke", "missile", "rocket", "explos",
                          "tnt", "dynamite", "mine" } },
    Fire    = { flag = "AntiFire",    mode = "push",
                words = { "campfire", "fire", "flame", "burning" } },
    Bees    = { flag = "AntiBees",    mode = "push",
                words = { "bee", "hive", "beehive" } },
}

local LOOT = {
    Note    = { flag = "LootNote",
                words = { "deathnote", "death note", "note" } },
    Weapons = { flag = "LootWeapons",
                words = { "sword", "blade", "knife", "katana", "illumina",
                          "darkheart", "linkedsword", "saber", "lightsaber",
                          "scythe", "dagger", "axe", "hammer", "bonk",
                          "gauntlet", "pistol", "sniper", "launcher",
                          "staff", "gun", "paintball", "flute", "peacemaker" } },
    Gear    = { flag = "LootGear",
                words = { "coil", "gravity", "speed", "regen", "totem",
                          "banana", "candy", "cola", "potion", "brew",
                          "present", "gift", "chest", "treasure", "loot",
                          "anvil", "extinguisher", "trowel", "jetpack",
                          "fishingrod", "fishing rod", "pizza", "burger" } },
}

local dangerCache, lootCache = {}, {}
local lastScanAt, scanCount, scanCost = 0, 0, 0

local function AnyDangerOn()
    for _, d in pairs(DANGER) do
        if State[d.flag] then return true end
    end
    return false
end

local function ScanWorkspace()
    local t0 = tick()
    local ok, list = pcall(function() return Workspace:GetDescendants() end)
    if not ok or not list then return end

    local dNew, lNew = {}, {}
    local wantDanger = AnyDangerOn()
    local wantLoot   = State.AutoLoot

    for _, o in pairs(list) do
        local nm
        pcall(function() nm = o.Name end)
        if nm then
            if wantDanger then
                local isPart = false
                pcall(function() isPart = o:IsA("BasePart") end)
                if isPart then
                    for tag, def in pairs(DANGER) do
                        if State[def.flag] and matchAny(nm, def.words) then
                            dNew[#dNew + 1] = { inst = o, tag = tag, mode = def.mode }
                            break
                        end
                    end
                end
            end
            if wantLoot then
                local cls
                pcall(function() cls = o.ClassName end)
                if cls == "Tool" or cls == "HopperBin" or cls == "Model" or cls == "Part" or cls == "MeshPart" then
                    for tag, def in pairs(LOOT) do
                        if State[def.flag] and matchAny(nm, def.words) then
                            -- ignore things already in someone's hands
                            local mine = false
                            pcall(function()
                                local ch = GetChar()
                                if ch and o:IsDescendantOf(ch) then mine = true end
                            end)
                            if not mine then
                                lNew[#lNew + 1] = { inst = o, tag = tag, name = nm }
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    dangerCache, lootCache = dNew, lNew
    scanCount = scanCount + 1
    scanCost  = math.floor((tick() - t0) * 1000)
end

------------------------------------------------------------------
-- 4. EVENT REACTIONS
------------------------------------------------------------------

local lastSafePos  = nil
local hoverActive  = false
local eventStatus  = "idle"
local reactions    = 0

local lastDangerAt = 0

local function DangerStep()
    local nowD = tick()
    if nowD - lastDangerAt < 0.05 then return end
    lastDangerAt = nowD

    local hrp = GetHRP()
    if not hrp or not IsAlive() then hoverActive = false return end

    local myPos
    pcall(function() myPos = hrp.Position end)
    if not myPos then return end

    -- remember the last spot that was not over a hazard
    if myPos.Y > -5 then lastSafePos = myPos end

    -- Anti-Void first: it does not need the scanner
    if State.AntiVoid and myPos.Y < -30 and lastSafePos then
        SetPosition(hrp, Vector3.new(lastSafePos.X, lastSafePos.Y + 18, lastSafePos.Z))
        pcall(function() hrp.Velocity = Vector3.zero end)
        eventStatus = "anti-void: pulled you back"
        reactions = reactions + 1
        return
    end

    if #dangerCache == 0 then
        hoverActive = false
        return
    end

    local bestHover, bestHoverY, bestHoverTag = nil, nil, nil
    local pushX, pushZ, pushTag = 0, 0, nil

    for _, d in ipairs(dangerCache) do
        local inst = d.inst
        local p, sz
        pcall(function() p = inst.Position sz = inst.Size end)
        if p and sz then
            local dx, dz = myPos.X - p.X, myPos.Z - p.Z
            local flat = math.sqrt(dx * dx + dz * dz)
            -- horizontal reach of the part plus a margin
            local reach = math.max(sz.X, sz.Z) * 0.5 + 6

            if d.mode == "hover" then
                local topY = p.Y + sz.Y * 0.5
                -- react only if we are inside its footprint and not already above it
                if flat < reach and myPos.Y < topY + State.HoverHeight then
                    if not bestHoverY or topY > bestHoverY then
                        bestHoverY   = topY
                        bestHover    = inst
                        bestHoverTag = d.tag
                    end
                end
            else
                local radius = math.max(sz.X, sz.Z) * 0.5 + State.PushDist
                if flat < radius and flat > 0.1 then
                    local w = (radius - flat) / radius
                    pushX = pushX + (dx / flat) * w
                    pushZ = pushZ + (dz / flat) * w
                    pushTag = d.tag
                end
            end
        end
    end

    if bestHover then
        SetPosition(hrp, Vector3.new(myPos.X, bestHoverY + State.HoverHeight, myPos.Z))
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
            local step = 4
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
-- 5. AUTO LOOT
------------------------------------------------------------------

local lootStatus, lootGrabs, lastLootAt = "off", 0, 0

local function LootStep()
    if not State.AutoLoot then lootStatus = "off" return end
    if not IsAlive() then lootStatus = "dead" return end

    local now = tick()
    if now - lastLootAt < 0.8 then return end

    local hrp = GetHRP()
    if not hrp then return end
    local myPos
    pcall(function() myPos = hrp.Position end)
    if not myPos then return end

    local best, bestD, bestName = nil, State.LootRange, "?"
    for _, l in ipairs(lootCache) do
        local p = PosOf(l.inst)
        if p then
            local d = (p - myPos).Magnitude
            if d < bestD then best, bestD, bestName = p, d, l.name end
        end
    end

    if best then
        lastSafePos = myPos
        SetPosition(hrp, Vector3.new(best.X, best.Y + 3.5, best.Z))
        lastLootAt = now
        lootGrabs  = lootGrabs + 1
        lootStatus = "grabbed " .. bestName
    else
        lootStatus = "nothing in range"
    end
end

------------------------------------------------------------------
-- 6. AUTO SWING  (real input -- the only option in Matcha)
------------------------------------------------------------------

local swingCount, lastToolName = 0, "none"
local swingStatus = "idle"
local gcCache, gcRefreshAt, gcHits = nil, 0, 0
local menuIsOpen = function() return false end

-- Weapon classification, ported from the nado.txt kill aura
local RANGED_KW = {
    "gun", "pistol", "sniper", "launcher", "rocket", "revolver", "peacemaker",
    "paintball", "ray", "famas", "cannon", "staff", "flute", "bow", "blaster",
    "freeze", "extinguisher", "rod",
}
local MELEE_KW = {
    "sword", "blade", "knife", "katana", "dagger", "axe", "scythe", "hammer",
    "bonk", "saber", "lightsaber", "illumina", "darkheart", "linkedsword",
    "machete", "cleaver", "gauntlet", "bat", "candycane", "candy cane",
}

local function IsMeleeTool(tool)
    if not tool then return false end
    local n
    pcall(function() n = string.lower(tool.Name) end)
    if not n then return false end
    for _, k in ipairs(RANGED_KW) do
        if string.find(n, k, 1, true) then return false end
    end
    for _, k in ipairs(MELEE_KW) do
        if string.find(n, k, 1, true) then return true end
    end
    -- unknown tool: treat as melee only if it has a Handle
    local h
    pcall(function() h = tool:FindFirstChild("Handle") end)
    return h ~= nil
end

-- nado.txt logic: is a living player within reach right now?
local auraTarget = nil

local function TargetInRange()
    local hrp = GetHRP()
    if not hrp then return false end
    local myPos
    pcall(function() myPos = hrp.Position end)
    if not myPos then return false end

    local rng = State.AuraRange
    for _, e in ipairs(PlayerInfo) do
        if e.pos and e.hp and e.hp > 0 then
            if (myPos - e.pos).Magnitude <= rng then
                auraTarget = e.name
                return true
            end
        end
    end
    auraTarget = nil
    return false
end

local CD_KEYS = {
    "Cooldown", "cooldown", "CoolDown", "COOLDOWN",
    "Debounce", "debounce", "DeBounce", "canAttack", "CanAttack",
    "canSwing", "CanSwing", "canHit", "CanHit", "canUse", "CanUse",
    "attacking", "Attacking", "swinging", "Swinging", "isSwinging",
    "AttackCooldown", "attackCooldown", "SwingCooldown", "swingCooldown",
    "LastAttack", "lastAttack", "LastSwing", "lastSwing", "lastUse",
    "NextAttack", "nextAttack", "nextSwing", "NextSwing",
    "AttackSpeed", "attackSpeed", "SwingSpeed", "swingSpeed",
    "ToolCooldown", "toolCooldown", "hitDebounce", "Reloading", "reloading",
    "Delay", "delay", "Enabled", "enabled", "Equipped", "equipped",
}

local CD_VALUES = {
    Cooldown = 0, cooldown = 0, CoolDown = 0, COOLDOWN = 0,
    Debounce = false, debounce = false, DeBounce = false,
    canAttack = true, CanAttack = true, canSwing = true, CanSwing = true,
    canHit = true, CanHit = true, canUse = true, CanUse = true,
    attacking = false, Attacking = false,
    swinging = false, Swinging = false, isSwinging = false,
    AttackCooldown = 0, attackCooldown = 0,
    SwingCooldown = 0, swingCooldown = 0,
    LastAttack = 0, lastAttack = 0, LastSwing = 0, lastSwing = 0, lastUse = 0,
    NextAttack = 0, nextAttack = 0, nextSwing = 0, NextSwing = 0,
    AttackSpeed = 0, attackSpeed = 0, SwingSpeed = 0, swingSpeed = 0,
    ToolCooldown = 0, toolCooldown = 0, hitDebounce = false,
    Reloading = false, reloading = false, Delay = 0, delay = 0,
    Enabled = true, enabled = true,
}

-- This used to run on EVERY swing: 47 GC writes x 12 swings a second.
-- That was the biggest remaining stall. Now it is rate limited, and the
-- write is skipped entirely once we learn the game patches values back.
local lastBypassAt, bypassMisses = 0, 0

local function ApplyCooldownBypass()
    if not State.CDBypass then return end
    if type(getgc) ~= "function" or type(applygc) ~= "function" then return end

    local now = tick()
    if now - lastBypassAt < 1.0 then return end   -- at most once per second
    lastBypassAt = now

    if not gcCache or now - gcRefreshAt > 15 then
        local ok, c = pcall(function() return getgc(CD_KEYS) end)
        if ok and c then gcCache = c gcRefreshAt = now end
    end
    if not gcCache then return end

    pcall(function()
        local n = applygc(gcCache, CD_VALUES)
        if type(n) == "number" then
            gcHits = n
            -- nothing to patch means the cooldown is not in client Lua
            if n == 0 then bypassMisses = bypassMisses + 1 else bypassMisses = 0 end
        end
    end)

    -- give up after 10 useless seconds instead of burning CPU forever
    if bypassMisses >= 10 then
        State.CDBypass = false
        bypassMisses = 0
        gcCache = nil
        pcall(function()
            if Lib then
                Lib:Notify("Cooldown Bypass",
                    "No client cooldown found - disabled to stop the lag", 7, "warning")
            end
        end)
    end
end

-- Non-blocking click.
-- The old version did wait() BETWEEN press and release, so the thread was
-- parked mid-hold. At high CPS that is a yield every few ms and Matcha's VM
-- stalls. Now press and release happen on separate passes of one calm loop:
-- the button is never held across a yield we do not control.
local pressedAt, isDown = 0, false

local function PressDown()
    if isDown then return end
    if pcall(function() mouse1press() end) then
        isDown = true
        pressedAt = tick()
    else
        pcall(function() mouse1click() end)
        swingCount = swingCount + 1
    end
end

local function ReleaseUp()
    if not isDown then return end
    pcall(function() mouse1release() end)
    isDown = false
    swingCount = swingCount + 1
end

local function ForceRelease()
    if isDown then
        pcall(function() mouse1release() end)
        isDown = false
    end
end

local function AutoSwingLoop()
    task.spawn(function()
        -- One fixed, calm tick. Never scales with CPS, so the VM keeps up.
        local TICK = 0.03
        local nextSwingAt = 0

        while Running do
            if not State.AutoSwing then
                ForceRelease()
                swingStatus = "idle"
                gcCache, gcHits = nil, 0
                auraTarget = nil
                wait(0.15)
            else
                local now = tick()

                -- finish an open click first, whatever else happens
                if isDown and (now - pressedAt) >= (State.ClickHold / 1000) then
                    ReleaseUp()
                end

                local focused = true
                pcall(function() focused = isrbxactive() end)

                local tool = GetEquippedTool()
                if tool then
                    pcall(function() lastToolName = tool.Name end)
                else
                    lastToolName = "none"
                end

                local blocked = nil
                if State.NeedFocus and not focused then
                    blocked = "paused: game window not focused"
                elseif menuIsOpen() then
                    blocked = "paused: close the menu (F7)"
                elseif healthReadable and GetHealth() == 0 then
                    blocked = "paused: you are dead"
                elseif State.RequireTool and not tool then
                    blocked = "paused: no tool equipped"
                elseif State.MeleeOnly and tool and not IsMeleeTool(tool) then
                    blocked = "paused: ranged weapon"
                end

                if blocked then
                    ForceRelease()
                    swingStatus = blocked
                    if blocked == "paused: no tool equipped" and State.AutoEquip and focused
                       and not menuIsOpen() then
                        pcall(function() keypress(0x31) keyrelease(0x31) end)
                        swingStatus = "equipping (pressing 1)"
                    end
                    wait(0.25)
                else
                    -- nado.txt kill aura: only swing when a target is in reach
                    local hasTarget = true
                    if State.KillAura then hasTarget = TargetInRange() end

                    if not hasTarget then
                        ForceRelease()
                        swingStatus = "waiting for a target"
                        wait(0.15)          -- exactly the nado.txt pacing
                    else
                        swingStatus = auraTarget and ("hitting " .. auraTarget) or "swinging"
                        if not isDown and now >= nextSwingAt then
                            ApplyCooldownBypass()
                            PressDown()
                            local cps = State.SwingCPS
                            if cps < 1 then cps = 1 end
                            nextSwingAt = now + (1 / cps)
                        end
                        wait(TICK)
                    end
                end
            end
        end
        ForceRelease()
    end)
end

------------------------------------------------------------------
-- 7. NOCLIP
------------------------------------------------------------------

-- Throttled: GetDescendants() every frame was a major stall source.
local lastNoclipAt = 0

local function NoclipStep()
    if not State.Noclip then return end
    local now = tick()
    if now - lastNoclipAt < 0.4 then return end
    lastNoclipAt = now

    local char = GetChar()
    if not char then return end
    -- direct children only: body parts live there, and it is far cheaper
    local ok, parts = pcall(function() return char:GetChildren() end)
    if not ok or not parts then return end
    for _, p in pairs(parts) do
        pcall(function()
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end)
    end
end


------------------------------------------------------------------
-- 7b. ON-SCREEN HUD (the menu hides the status, so draw it outside)
------------------------------------------------------------------

local hudBg, hudTxt, hudDot
local hudReady = false

local function BuildHUD()
    if hudReady then return end
    local FONT
    pcall(function()
        FONT = Drawing.Fonts and (Drawing.Fonts.Monospace or Drawing.Fonts.System)
    end)
    local function mk(kind, props)
        local ok, o = pcall(function() return Drawing.new(kind) end)
        if not ok or not o then return nil end
        for k, v in pairs(props) do pcall(function() o[k] = v end) end
        return o
    end
    hudBg  = mk("Square", { Filled = true, Visible = false, ZIndex = 1,
                            Color = Color3.fromRGB(12, 13, 15), Transparency = 0.55,
                            Corner = 6, Rounding = 6 })
    hudDot = mk("Circle", { Radius = 4, NumSides = 14, Filled = true, Visible = false,
                            ZIndex = 3, Color = Color3.fromRGB(126, 217, 163) })
    hudTxt = mk("Text",   { Visible = false, ZIndex = 3, Center = false, Outline = true,
                            Color = Color3.fromRGB(236, 238, 242) })
    if hudTxt then
        if FONT then pcall(function() hudTxt.Font = FONT end) end
        pcall(function() hudTxt.FontSize = 13 end)
        pcall(function() hudTxt.Size = 13 end)
        pcall(function() hudTxt.Transparency = 1 end)
    end
    hudReady = true
end

local function HUDStep()
    if not hudReady then return end
    local show = State.ShowHUD and State.AutoSwing and not menuIsOpen()
    if not show then
        pcall(function() hudBg.Visible = false end)
        pcall(function() hudTxt.Visible = false end)
        pcall(function() hudDot.Visible = false end)
        return
    end

    local txt = "SWING  " .. swingStatus .. "   [" .. swingCount .. "]"
    local w = 26 + #txt * 7
    local x, y = 18, 120

    local good = (swingStatus == "swinging")
    local col = good and Color3.fromRGB(126, 217, 163) or Color3.fromRGB(250, 190, 60)

    pcall(function()
        hudBg.Position = Vector2.new(x, y)
        hudBg.Size     = Vector2.new(w, 26)
        hudBg.Visible  = true
    end)
    pcall(function()
        hudDot.Position = Vector2.new(x + 13, y + 13)
        hudDot.Color    = col
        hudDot.Visible  = true
    end)
    pcall(function()
        hudTxt.Text     = txt
        hudTxt.Position = Vector2.new(x + 24, y + 6)
        hudTxt.Color    = col
        hudTxt.Visible  = true
    end)
end


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

local function espHide(set)
    if not set then return end
    for _, o in pairs(set) do pcall(function() o.Visible = false end) end
end

local lastESPAt = 0

local lastESPAt = 0

local function RoleStyle(role, toolName)
    if role == "murderer" then return Color3.fromRGB(255, 70, 70),  "MURDERER" end
    if role == "sheriff"  then return Color3.fromRGB(80, 170, 255), "SHERIFF"  end
    if role == "armed"    then return Color3.fromRGB(250, 190, 60), toolName or "ARMED" end
    if role == "holding"  then return Color3.fromRGB(190, 195, 205), toolName or "" end
    return Color3.fromRGB(150, 155, 165), ""
end

local function ESPStep()
    if not espReady then return end

    if not State.RoleESP then
        pcall(function() if loadoutBox then loadoutBox:Remove() end end)
    for _, set in pairs(espObjs) do espHide(set) end
        roleCounts.murderer, roleCounts.sheriff, roleCounts.armed = 0, 0, 0
        return
    end

    local nowT = tick()
    if nowT - lastESPAt < 0.06 then return end   -- ~16 Hz ceiling
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
            local dist = 0
            if myPos then dist = (e.pos - myPos).Magnitude end

            local skip = dist > State.ESPRange
            if State.ESPOnlyRole and e.role ~= "murderer" and e.role ~= "sheriff" then
                skip = true
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
                        local col, label = RoleStyle(e.role, e.tool)
                        local h = math.abs(bot.Y - top.Y)
                        if h < 8 then h = 8 end
                        local w = h * 0.52
                        local x = top.X - w / 2

                        if State.ESPBox then
                            pcall(function()
                                set.box.Position = Vector2.new(x, top.Y)
                                set.box.Size     = Vector2.new(w, h)
                                set.box.Color    = col
                                set.box.Visible  = true
                            end)
                        else pcall(function() set.box.Visible = false end) end

                        if State.ESPName then
                            pcall(function()
                                set.name.Text     = (e.display or e.name) .. "  " .. math.floor(dist) .. "m"
                                set.name.Position = Vector2.new(top.X, top.Y - 16)
                                set.name.Color    = col
                                set.name.Visible  = true
                            end)
                        else pcall(function() set.name.Visible = false end) end

                        if State.ESPRole and label ~= "" then
                            pcall(function()
                                set.role.Text     = label
                                set.role.Position = Vector2.new(top.X, bot.Y + 2)
                                set.role.Color    = col
                                set.role.Visible  = true
                            end)
                        else pcall(function() set.role.Visible = false end) end

                        local drawLine = State.ESPLine
                        if drawLine and State.ESPOnlyRole and
                           e.role ~= "murderer" and e.role ~= "sheriff" then
                            drawLine = false
                        end
                        if drawLine then
                            pcall(function()
                                set.line.From    = Vector2.new(vw / 2, vh)
                                set.line.To      = Vector2.new(top.X, bot.Y)
                                set.line.Color   = col
                                set.line.Visible = true
                            end)
                        else pcall(function() set.line.Visible = false end) end
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
        local ok, r = pcall(function() return loadstring(b)() end)
        if ok and type(r) == "table" then return r end
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

local mainConn = nil

_G.NadoMatchaCleanup = function()
    Running = false
    pcall(function() mouse1release() end)
    pcall(function() hudBg.Visible = false hudTxt.Visible = false hudDot.Visible = false end)
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

local loadoutBox, loadoutLines = nil, {}
local BOX_ROWS = 20
local lastBoxAt = 0

local ROLE_ORDER = { murderer = 1, sheriff = 2, armed = 3, holding = 4, none = 5 }

local function BuildLoadoutBox()
    if loadoutBox or not Lib then return end
    local ok = pcall(function()
        loadoutBox = Lib:CreateBox({
            title    = "INVENTORY",
            position = Vector2.new(State.BoxX, State.BoxY),
            width    = 290,
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
    local tabC = window:Tab("Combat", "home")
    local sw = tabC:Section("Auto Swing", "Left", "real clicks + cooldown bypass")

    UIRef.t.AutoSwing = sw:Toggle("Auto Swing", State.AutoSwing, function(v)
        State.AutoSwing = v
        if not v then pcall(function() mouse1release() end) end
        SaveSettings()
    end, "Matcha has no Tool:Activate(), so this sends real mouse clicks")
    pcall(function() UIRef.t.AutoSwing:AddKeybind("f", "Toggle") end)

    UIRef.t.CDBypass = sw:Toggle("Cooldown Bypass", State.CDBypass, function(v)
        State.CDBypass = v
        if not v then gcCache, gcHits = nil, 0 end
        SaveSettings()
    end, "Zeroes the weapon debounce inside the game's Lua GC")

    UIRef.t.RequireTool = sw:Toggle("Only With Tool", State.RequireTool, function(v)
        State.RequireTool = v SaveSettings()
    end, "Do not click unless a Tool is in your hands")

    UIRef.t.AutoEquip = sw:Toggle("Auto Equip", State.AutoEquip, function(v)
        State.AutoEquip = v SaveSettings()
    end, "Presses the 1 key when your hands are empty")

    UIRef.t.NeedFocus = sw:Toggle("Require Window Focus", State.NeedFocus, function(v)
        State.NeedFocus = v SaveSettings()
    end, "Off by default: isrbxactive() is unreliable on some setups")

    UIRef.t.ShowHUD = sw:Toggle("On-Screen Status", State.ShowHUD, function(v)
        State.ShowHUD = v SaveSettings()
    end, "Shows why swinging is paused while the menu is closed")

    UIRef.t.KillAura = sw:Toggle("Kill Aura Mode", State.KillAura, function(v)
        State.KillAura = v SaveSettings()
    end, "Only swings when a player is in range. This is what stops the lag")

    UIRef.t.MeleeOnly = sw:Toggle("Melee Only", State.MeleeOnly, function(v)
        State.MeleeOnly = v SaveSettings()
    end, "Do not spam clicks while holding a gun or launcher")

    UIRef.t.AuraRange = sw:Slider("Aura Range", State.AuraRange, 1, 5, 60, "studs", function(v)
        State.AuraRange = v SaveSettings()
    end, "15 is the value used by the original script")

    UIRef.t.SwingCPS = sw:Slider("Clicks Per Second", State.SwingCPS, 1, 1, 20, "", function(v)
        State.SwingCPS = v SaveSettings()
    end, "10-15 works best, faster is not always better")

    UIRef.t.ClickHold = sw:Slider("Click Hold", State.ClickHold, 5, 5, 150, "ms", function(v)
        State.ClickHold = v SaveSettings()
    end, "How long the button stays down. Below ~20ms Roblox may ignore the click")

    local dbg = tabC:Section("Diagnostics", "Right", "use these if nothing happens")

    dbg:Button("Test 5 Clicks", function()
        task.spawn(function()
            pcall(function() Lib:SetOpen(false) end)
            wait(0.6)
            for _ = 1, 5 do
                ClickOnce()
                wait(0.15)
            end
            pcall(function()
                Lib:Notify("Test", "5 clicks sent. Did the tool swing?", 6, "info")
            end)
        end)
    end, "Closes the menu, waits, then sends 5 clean clicks")

    dbg:Button("Why Is It Not Swinging?", function()
        task.spawn(function()
            local focused = true
            pcall(function() focused = isrbxactive() end)
            local tool = GetEquippedTool()
            local hp   = GetHealth()

            print("[Nado] ---- swing diagnostic ----")
            print("[Nado] AutoSwing toggle : " .. tostring(State.AutoSwing))
            print("[Nado] menu open        : " .. tostring(menuIsOpen()) .. "  (blocks input)")
            print("[Nado] isrbxactive()    : " .. tostring(focused) ..
                  "   enforced=" .. tostring(State.NeedFocus))
            print("[Nado] tool detected    : " .. (tool and tool.Name or "NONE") ..
                  "   enforced=" .. tostring(State.RequireTool))
            print("[Nado] health           : " .. tostring(hp) ..
                  "   readable=" .. tostring(healthReadable))
            print("[Nado] click hold       : " .. State.ClickHold .. " ms")
            print("[Nado] current status   : " .. swingStatus)

            local why
            if not State.AutoSwing then why = "Auto Swing is OFF"
            elseif menuIsOpen() then why = "menu is open - it blocks game input"
            elseif State.NeedFocus and not focused then why = "window not focused"
            elseif State.RequireTool and not tool then why = "no tool detected - turn Only With Tool OFF"
            elseif healthReadable and hp == 0 then why = "you are dead"
            else why = "nothing is blocking it - if the weapon still does not swing, the cooldown is server-side" end

            print("[Nado] VERDICT: " .. why)
            pcall(function() Lib:Notify("Diagnostic", why, 8, "info") end)
        end)
    end, "Prints exactly which check is stopping the swing")

    dbg:Button("Scan Cooldown Vars", function()
        if type(getgc) ~= "function" then
            pcall(function() Lib:Notify("Scan", "getgc missing in this build", 5, "warning") end)
            return
        end
        task.spawn(function()
            local ok, found = pcall(function() return getgc(CD_KEYS) end)
            local n, seen = 0, {}
            if ok and found then
                for _, e in pairs(found) do
                    n = n + 1
                    if type(e) == "table" and e.key and not seen[tostring(e.key)] then
                        seen[tostring(e.key)] = true
                        print("[Nado][gc] " .. tostring(e.key) .. " = " ..
                              tostring(e.value) .. "  (" .. tostring(e.type) .. ")")
                    end
                end
            end
            pcall(function()
                Lib:Notify("Scan", n .. " cooldown values -- see console", 5,
                           n > 0 and "success" or "warning")
            end)
        end)
    end, "Prints every cooldown variable found, so you can confirm the bypass has targets")

    dbg:Button("Dump Workspace", function()
        task.spawn(function()
            local ok, kids = pcall(function() return Workspace:GetChildren() end)
            if ok and kids then
                print("[Nado] ---- Workspace children ----")
                for _, o in pairs(kids) do
                    pcall(function() print("[Nado]  " .. o.Name .. "  (" .. o.ClassName .. ")") end)
                end
            end
            local t = GetEquippedTool()
            print("[Nado] equipped tool: " .. (t and t.Name or "none"))
            pcall(function() Lib:Notify("Dump", "Workspace printed to console", 5, "info") end)
        end)
    end, "Prints the map layout so unknown event names can be added")

    ---------------------------------------------------------------
    -- EVENTS
    ---------------------------------------------------------------
    local tabE = window:Tab("Events", "activity")

    local haz = tabE:Section("Hazard Events", "Left", "auto react to round events")

    UIRef.t.AntiLava = haz:Toggle("Anti-Lava", State.AntiLava, function(v)
        State.AntiLava = v SaveSettings()
    end, "'Watch out, the floor is lava' -- hovers you above the lava plate")

    UIRef.t.AntiSweeper = haz:Toggle("Anti-Sweeper / Spin", State.AntiSweeper, function(v)
        State.AntiSweeper = v SaveSettings()
    end, "Sweeper beam, spinning plates and kill bricks")

    UIRef.t.AntiWater = haz:Toggle("Anti-Flood / Tsunami", State.AntiWater, function(v)
        State.AntiWater = v SaveSettings()
    end, "Keeps you above rising water")

    UIRef.t.AntiBomb = haz:Toggle("Anti-Bomb / Nuke", State.AntiBomb, function(v)
        State.AntiBomb = v SaveSettings()
    end, "Walks you out of bomb, nuke, mine and missile blast range")

    UIRef.t.AntiFire = haz:Toggle("Anti-Fire", State.AntiFire, function(v)
        State.AntiFire = v SaveSettings()
    end, "Campfires and burning houses")

    UIRef.t.AntiBees = haz:Toggle("Anti-Bees", State.AntiBees, function(v)
        State.AntiBees = v SaveSettings()
    end, "The beehive event")

    UIRef.t.AntiVoid = haz:Toggle("Anti-Void", State.AntiVoid, function(v)
        State.AntiVoid = v SaveSettings()
    end, "Pulls you back if you fall off the map")

    local tune = tabE:Section("Reaction Tuning", "Right", "how it reacts")

    UIRef.t.HoverHeight = tune:Slider("Hover Height", State.HoverHeight, 1, 4, 40, "studs", function(v)
        State.HoverHeight = v SaveSettings()
    end, "How high above lava/water/beam you float")

    UIRef.t.PushDist = tune:Slider("Danger Radius", State.PushDist, 1, 8, 80, "studs", function(v)
        State.PushDist = v SaveSettings()
    end, "How far from bombs and fire you keep")

    UIRef.t.ScanRate = tune:Slider("Scan Rate", State.ScanRate, 1, 1, 30, "/10s", function(v)
        State.ScanRate = v SaveSettings()
    end, "Higher reacts faster but costs more CPU")

    UIRef.t.Noclip = tune:Toggle("Noclip", State.Noclip, function(v)
        State.Noclip = v SaveSettings()
    end, "Only resets on respawn")

    local loot = tabE:Section("Auto Loot", "Right", "grab event drops")

    UIRef.t.AutoLoot = loot:Toggle("Auto Loot", State.AutoLoot, function(v)
        State.AutoLoot = v SaveSettings()
    end, "Teleports to weapons and gear dropped by events")

    UIRef.t.LootNote = loot:Toggle("Death Note", State.LootNote, function(v)
        State.LootNote = v SaveSettings()
    end, "'A powerful note falls from the sky'")

    UIRef.t.LootWeapons = loot:Toggle("Weapons", State.LootWeapons, function(v)
        State.LootWeapons = v SaveSettings()
    end, "Swords, illumina, hammers, guns, flute")

    UIRef.t.LootGear = loot:Toggle("Gear & Items", State.LootGear, function(v)
        State.LootGear = v SaveSettings()
    end, "Coils, totems, presents, chests, food")

    UIRef.t.LootRange = loot:Slider("Loot Range", State.LootRange, 10, 50, 2000, "studs", function(v)
        State.LootRange = v SaveSettings()
    end)

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

    local pl = tabP:Section("Detected", "Right", "live role scan")
    pl:Label(function() return "Murderer:  " .. roleCounts.murderer end)
    pl:Label(function() return "Sheriff:  "  .. roleCounts.sheriff  end)
    pl:Label(function() return "Other armed:  " .. roleCounts.armed end)
    pl:Label("")
    pl:Label("Window legend:")
    pl:Label("  >  item in their hands")
    pl:Label("  -  item in their backpack")
    pl:Label("")
    pl:Label("Backpacks of OTHER players are")
    pl:Label("often hidden by Roblox, so some")
    pl:Label("show only the equipped item.")

    ---------------------------------------------------------------
    -- STATS
    ---------------------------------------------------------------
    local tabS = window:Tab("Stats", "activity")

    local li = tabS:Section("Combat", "Left", "live")
    li:Label(function() return "Tool:  " .. lastToolName end)
    li:Label(function() return "Swings sent:  " .. swingCount end)
    li:Label(function() return "Status:  " .. swingStatus end)
    li:Label(function() return "Target:  " .. (auraTarget or "none in range") end)
    li:Label(function()
        if not State.CDBypass then return "Bypass:  off" end
        return "Bypass:  " .. gcHits .. " values patched"
    end)

    local ev = tabS:Section("Events", "Right", "live")
    ev:Label(function() return "Event status:  " .. eventStatus end)
    ev:Label(function() return "Reactions:  " .. reactions end)
    ev:Label(function() return "Hazards tracked:  " .. #dangerCache end)
    ev:Label(function() return "Loot tracked:  " .. #lootCache end)
    ev:Label(function() return "Loot:  " .. lootStatus .. "  (" .. lootGrabs .. ")" end)
    ev:Label(function() return "Scan cost:  " .. scanCost .. " ms" end)

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
        State.AutoSwing, State.CDBypass                    = false, true
        State.SwingCPS, State.ClickHold, State.AutoEquip   = 12, 35, false
        State.KillAura, State.AuraRange, State.MeleeOnly   = true, 15, true
        State.NeedFocus, State.ShowHUD                     = false, true
        State.RequireTool                                  = false
        State.AntiLava, State.AntiSweeper, State.AntiWater = false, false, false
        State.AntiBomb, State.AntiFire, State.AntiBees     = false, false, false
        State.AntiVoid, State.Noclip                       = false, false
        State.HoverHeight, State.PushDist, State.ScanRate  = 12, 28, 10
        State.AutoLoot, State.LootRange                    = false, 350
        State.RoleESP, State.ESPOnlyRole                   = false, false
        State.ESPBox, State.ESPName, State.ESPRole         = true, true, true
        State.ESPLine, State.ESPRange                      = false, 2000
        State.LoadoutBox, State.BoxSortRole                = false, true
        State.BoxHideIdle                                  = false
        -- Theme / ConfigName / AutoSaveUI intentionally preserved
        State.LootWeapons, State.LootNote, State.LootGear  = true, true, true
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

    local help = tabCfg:Section("If Swinging Does Nothing", "Right", "in order")
    help:Label("1. Press Why Is It Not Swinging?")
    help:Label("   It names the exact blocker.")
    help:Label("2. CLOSE THE MENU. INS-ui blocks")
    help:Label("   all game input while open.")
    help:Label("3. Watch the on-screen status")
    help:Label("   box once the menu is closed.")
    help:Label("4. Raise Click Hold to 50-80ms.")
    help:Label("")
    help:Label("Lagging? Keep Kill Aura Mode ON")
    help:Label("and Clicks Per Second near 12.")

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

pcall(BuildHUD)
pcall(BuildESP)
pcall(BuildLoadoutBox)
-- ONE background worker instead of four separate timer threads.
-- Fewer independent yields means far less scheduler churn inside Matcha.
task.spawn(function()
    local tickN = 0
    local lastScanAtW = 0
    while Running do
        tickN = tickN + 1

        -- player cache: every pass (5 Hz) when something needs it
        if State.RoleESP or State.AutoSwing or State.LoadoutBox then
            pcall(RefreshPlayerInfo)
        elseif #PlayerInfo > 0 then
            PlayerInfo = {}
        end

        -- loot + loadout: every other pass (~2.5 Hz)
        if tickN % 2 == 0 then
            pcall(LootStep)
            pcall(LoadoutStep)
        end

        -- workspace hazard scan: on its own slower schedule
        if AnyDangerOn() or State.AutoLoot then
            local rate = State.ScanRate
            if rate < 1 then rate = 1 end
            if rate > 10 then rate = 10 end
            local due = 10 / rate
            local nowW = tick()
            if nowW - lastScanAtW >= due then
                lastScanAtW = nowW
                pcall(ScanWorkspace)
            end
        elseif #dangerCache > 0 or #lootCache > 0 then
            dangerCache, lootCache = {}, {}
        end

        wait(0.2)
    end
end)

AutoSwingLoop()

local function Frame()
    if not Running then return end
    pcall(DangerStep)
    pcall(NoclipStep)
    pcall(HUDStep)
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
