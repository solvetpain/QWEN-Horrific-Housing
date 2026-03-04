--[[
    QWEN Horrific Housing Ultimate v4.2
    DELETE - открыть/закрыть меню
]]

-- CLEANUP
for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("HorrificUltimate") or gui.Name == "KilasikFlingGUI" then
        pcall(function() gui:Destroy() end)
    end
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")

local Running = true
local MenuOpen = false


local State = {
    Speed = 16,
    JumpPower = 50,
    KillAura = false,
    ESP = false,
    AntiLava = false,
    AntiVoid = false,
    InfiniteJump = false,
    AntiSweeper = false,
    DeathNoteTP = false,
    AutoSword = false,
    Noclip = false,
    Reach = false,
}

-- СОХРАНЕНИЕ НАСТРОЕК
local SAVE_KEY = "HorrificUltimate_v42_Settings"

local function SaveSettings()
    local data = {
        Speed = State.Speed,
        JumpPower = State.JumpPower,
        KillAura = State.KillAura,
        ESP = State.ESP,
        AntiLava = State.AntiLava,
        AntiVoid = State.AntiVoid,
        InfiniteJump = State.InfiniteJump,
        AntiSweeper = State.AntiSweeper,
        DeathNoteTP = State.DeathNoteTP,
        AutoSword = State.AutoSword,
        Noclip = State.Noclip,
        Reach = State.Reach,
    }
    pcall(function()
        writefile(SAVE_KEY .. ".json", game:GetService("HttpService"):JSONEncode(data))
    end)
end

local function LoadSettings()
    local ok, result = pcall(function()
        if isfile(SAVE_KEY .. ".json") then
            return game:GetService("HttpService"):JSONDecode(readfile(SAVE_KEY .. ".json"))
        end
    end)
    if ok and result then
        for k, v in pairs(result) do
            if State[k] ~= nil then
                State[k] = v
            end
        end
    end
end

LoadSettings()


local FlingActive = false
local SelectedTargets = {}
local SelectedFlingTarget = nil
local espDrawings = {}

getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local T = {
    BG       = Color3.fromRGB(6, 6, 6),
    BG2      = Color3.fromRGB(11, 11, 11),
    Surface  = Color3.fromRGB(18, 18, 18),
    Hover    = Color3.fromRGB(30, 30, 30),
    Text     = Color3.fromRGB(240, 240, 240),
    Muted    = Color3.fromRGB(80, 80, 80),
    Border   = Color3.fromRGB(38, 38, 38),
    Danger   = Color3.fromRGB(200, 60, 60),
    White    = Color3.fromRGB(255, 255, 255),
    Dark     = Color3.fromRGB(0, 0, 0),
    Selected = Color3.fromRGB(210, 210, 210),
    Accent   = Color3.fromRGB(50, 50, 50),
}

-- ============================================================
-- HELPERS
-- ============================================================
local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function Stroke(p, col, t)
    local s = Instance.new("UIStroke")
    s.Color = col or T.Border
    s.Thickness = t or 1
    s.Parent = p
    return s
end

local function Tween(o, pr, d)
    if not o or not o.Parent then return end
    TS:Create(o, TweenInfo.new(d or 0.2, Enum.EasingStyle.Quint), pr):Play()
end

local function lerpColor(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

-- ============================================================
-- FLING
-- ============================================================
local function SkidFling(TargetPlayer)
    local Character = LP.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    local THumanoid, TRootPart, THead, Accessory, Handle
    if TCharacter:FindFirstChildOfClass("Humanoid") then
        THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    end
    if THumanoid and THumanoid.RootPart then TRootPart = THumanoid.RootPart end
    if TCharacter:FindFirstChild("Head") then THead = TCharacter.Head end
    if TCharacter:FindFirstChildOfClass("Accessory") then
        Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    end
    if Accessory and Accessory:FindFirstChild("Handle") then Handle = Accessory.Handle end
    if not (Character and Humanoid and RootPart) then return end
    if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end
    if THumanoid and THumanoid.Sit then return end
    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then workspace.CurrentCamera.CameraSubject = THumanoid end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end
    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    local SFBasePart = function(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        repeat
            if RootPart and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    FPos(BasePart, CFrame.new(0,1.5,0)+THumanoid.MoveDirection*BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(Angle),0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,-1.5,0)+THumanoid.MoveDirection*BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(Angle),0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,1.5,0)+THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,-1.5,0)+THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0,0)) task.wait()
                else
                    FPos(BasePart, CFrame.new(0,1.5,THumanoid.WalkSpeed), CFrame.Angles(math.rad(90),0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,-1.5,-THumanoid.WalkSpeed), CFrame.Angles(0,0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(90),0,0)) task.wait()
                    FPos(BasePart, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0)) task.wait()
                end
            end
        until Time + TimeToWait < tick() or not FlingActive
    end
    workspace.FallenPartsDestroyHeight = 0/0
    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(0,0,0)
    BV.MaxForce = Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    if TRootPart then SFBasePart(TRootPart)
    elseif THead then SFBasePart(THead)
    elseif Handle then SFBasePart(Handle) end
    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid
    if getgenv().OldPos then
        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0,.5,0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0,.5,0))
            Humanoid:ChangeState("GettingUp")
            for _,part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            task.wait()
        until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
        workspace.FallenPartsDestroyHeight = getgenv().FPDH
    end
end

local function FlingTarget(tp)
    if not tp then return end
    FlingActive = true
    task.spawn(function() SkidFling(tp) end)
end

local function FlingAll()
    FlingActive = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            task.spawn(function() SkidFling(plr) end)
            task.wait(0.1)
        end
    end
end

-- ============================================================
-- KILL AURA
-- ============================================================
local MELEE_KEYWORDS = {
    "sword","blade","knife","katana","dagger","saber","axe","scythe",
    "melee","slash","cleave","cutlass","machete","illumina","linkedsword",
    "darkheart","classic","necro","firebrand","icedagger","windforce"
}

local RANGED_KEYWORDS = {
    "gun","pistol","rifle","sniper","shoot","bullet","cannon","bow",
    "arrow","musket","crossbow","blaster","laser","rocket","grenade"
}

local function isMeleeTool(tool)
    local nameLower = tool.Name:lower()
    for _, kw in pairs(RANGED_KEYWORDS) do
        if nameLower:find(kw) then return false end
    end
    for _, kw in pairs(MELEE_KEYWORDS) do
        if nameLower:find(kw) then return true end
    end
    local hasHandle = tool:FindFirstChild("Handle")
    if not hasHandle then return false end
    if tool:FindFirstChildWhichIsA("BillboardGui") then return false end
    return true
end

local function KillAura()
    while State.KillAura and Running do
        pcall(function()
            local myChar = LP.Character
            if not myChar then return end
            local tool = myChar:FindFirstChildOfClass("Tool")
            if not tool then return end
            if not isMeleeTool(tool) then return end
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local targetHum = p.Character:FindFirstChild("Humanoid")
                    local target = p.Character:FindFirstChild("HumanoidRootPart")
                    if not targetHum or not target then continue end
                    if targetHum.Health <= 0 then continue end
                    local dist = (HRP.Position - target.Position).Magnitude
                    if dist > 10 then continue end
                    local fired = false
                    for _, desc in pairs(tool:GetDescendants()) do
                        if desc:IsA("RemoteEvent") then
                            pcall(function()
                                desc:FireServer(target)
                                desc:FireServer(target.Position)
                            end)
                            fired = true
                        end
                    end
                    if not fired then
                        for _, desc in pairs(tool:GetDescendants()) do
                            if desc:IsA("RemoteFunction") then
                                pcall(function() desc:InvokeServer(target) end)
                            end
                        end
                    end
                end
            end
        end)
        task.wait(0.15)
    end
end

-- ============================================================
-- ESP
-- ============================================================
local function removeESP(plr)
    if espDrawings[plr] then
        for _, d in pairs(espDrawings[plr]) do
            pcall(function() d.Visible = false d:Remove() end)
        end
        espDrawings[plr] = nil
    end
end

local function createESP(plr)
    if espDrawings[plr] then return end
    local box      = Drawing.new("Square")
    local nameTag  = Drawing.new("Text")
    local distTag  = Drawing.new("Text")
    local hpBg     = Drawing.new("Square")
    local hpFill   = Drawing.new("Square")
    box.Thickness = 1  box.Filled = false  box.Visible = false  box.Color = T.White
    nameTag.Size = 13  nameTag.Center = true  nameTag.Outline = true
    nameTag.OutlineColor = T.Dark  nameTag.Color = T.White  nameTag.Visible = false
    distTag.Size = 11  distTag.Center = true  distTag.Outline = true
    distTag.OutlineColor = T.Dark  distTag.Color = Color3.fromRGB(200,200,200)  distTag.Visible = false
    hpBg.Thickness = 0  hpBg.Filled = true  hpBg.Visible = false  hpBg.Color = Color3.fromRGB(40,40,40)
    hpFill.Thickness = 0  hpFill.Filled = true  hpFill.Visible = false  hpFill.Color = T.White
    espDrawings[plr] = {box=box, name=nameTag, distance=distTag, hpBg=hpBg, hpFill=hpFill}
end

local function updateESP()
    if not State.ESP then
        for plr, _ in pairs(espDrawings) do removeESP(plr) end
        return
    end
    local valid = {}
    for _, plr in ipairs(Players:GetPlayers()) do valid[plr] = true end
    for plr, _ in pairs(espDrawings) do
        if not valid[plr] then removeESP(plr) end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local char = plr.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not char or not hum or not root or not head or hum.Health <= 0 then
            removeESP(plr) continue
        end
        if not espDrawings[plr] then createESP(plr) end
        local d = espDrawings[plr]
        if not d then continue end
        local rootVP, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local headVP = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.6,0))
            local footVP = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3.1,0))
            local height = math.abs(footVP.Y - headVP.Y)
            local width  = height * 0.5
            local boxX   = rootVP.X - width/2
            local boxY   = headVP.Y
            d.box.Size     = Vector2.new(width, height)
            d.box.Position = Vector2.new(boxX, boxY)
            d.box.Visible  = true
            d.name.Text     = plr.DisplayName
            d.name.Position = Vector2.new(rootVP.X, boxY - 16)
            d.name.Visible  = true
            local dist = (Camera.CFrame.Position - root.Position).Magnitude
            d.distance.Text     = string.format("%.0fm", dist)
            d.distance.Position = Vector2.new(rootVP.X, footVP.Y + 3)
            d.distance.Visible  = true
            local barW = 4  local barH = math.max(10, height)
            local barX = boxX - barW - 3  local barY = boxY
            d.hpBg.Size     = Vector2.new(barW, barH)
            d.hpBg.Position = Vector2.new(barX, barY)
            d.hpBg.Visible  = true
            local maxHp = hum.MaxHealth
            if maxHp <= 0 or maxHp ~= maxHp then maxHp = 100 end
            local curHp = hum.Health
            if curHp ~= curHp then curHp = 0 end
            local hpFrac = math.clamp(curHp/maxHp, 0, 1)
            local fillH  = math.max(1, barH * hpFrac)
            local fillY  = barY + (barH - fillH)
            d.hpFill.Size     = Vector2.new(barW, fillH)
            d.hpFill.Position = Vector2.new(barX, fillY)
            d.hpFill.Color    = lerpColor(Color3.fromRGB(100,50,50), T.White, hpFrac)
            d.hpFill.Visible  = true
        else
            d.box.Visible = false  d.name.Visible = false  d.distance.Visible = false
            d.hpBg.Visible = false  d.hpFill.Visible = false
        end
    end
end

-- ============================================================
-- MISC LOOPS
-- ============================================================

-- Тетрадь смерти
local deathNoteConn = nil
local function StartDeathNoteTP()
    if deathNoteConn then deathNoteConn:Disconnect() end
    deathNoteConn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.DeathNoteTP or not Running then return end
        local name = obj.Name:lower()
        if name:find("note") or name:find("death") or name:find("deathnote") then
            task.wait(0.05)
            pcall(function()
                local part = obj:IsA("BasePart") and obj
                    or obj:FindFirstChildWhichIsA("BasePart")
                if part then
                    local char = LP.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.CFrame = part.CFrame * CFrame.new(0, 3, 0)
                        end
                    end
                end
            end)
        end
    end)
end

-- Авто-тп к мечу
local autoSwordConn = nil
local function StartAutoSword()
    if autoSwordConn then autoSwordConn:Disconnect() end
    autoSwordConn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.AutoSword or not Running then return end
        if not obj:IsA("Tool") then return end
        local name = obj.Name:lower()
        local isSword = name:find("sword") or name:find("blade") or
            name:find("knife") or name:find("katana") or
            name:find("illumina") or name:find("linkedsword") or
            name:find("darkheart") or name:find("classic") or
            name:find("necro") or name:find("firebrand") or
            name:find("icedagger") or name:find("windforce") or
            name:find("saber") or name:find("axe") or
            name:find("scythe") or name:find("dagger")
        if not isSword then return end
        if obj.Parent ~= Workspace then return end
        local waited = 0
        repeat
            task.wait(0.05)
            waited = waited + 0.05
        until (obj and obj.Parent and obj.Parent == Workspace and
            obj:FindFirstChild("Handle") and
            obj:FindFirstChild("Handle").Velocity.Magnitude < 1)
            or waited > 3
        if waited > 3 then return end
        pcall(function()
            if not obj or not obj.Parent then return end
            if LP.Character and obj:IsDescendantOf(LP.Character) then return end
            local handle = obj:FindFirstChild("Handle")
            local part = handle or obj:FindFirstChildWhichIsA("BasePart")
            if not part then return end
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = part.CFrame * CFrame.new(0, 2, 0)
                end
            end
        end)
    end)
end

local function AntiLavaLoop()
    while State.AntiLava and Running do
        pcall(function()
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj.Name:lower():find("lava") and obj:IsA("BasePart") then obj:Destroy() end
            end
        end)
        task.wait(0.5)
    end
end

local lastSafePos = nil
local antiVoidConn = nil

local function StartAntiVoid()
    if antiVoidConn then antiVoidConn:Disconnect() end
    lastSafePos = nil
    antiVoidConn = RS.Heartbeat:Connect(function()
        if not State.AntiVoid or not Running then
            antiVoidConn:Disconnect()
            antiVoidConn = nil
            return
        end
        pcall(function()
            if not HRP then return end
            local pos = HRP.Position
            if pos.Y > 0 then
                lastSafePos = pos
            end
            if pos.Y < -30 then
                local safeY = 50
                local safeX = lastSafePos and lastSafePos.X or 0
                local safeZ = lastSafePos and lastSafePos.Z or 0
                HRP.CFrame = CFrame.new(safeX, safeY, safeZ)
                HRP.Velocity = Vector3.zero
                HRP.RotVelocity = Vector3.zero
            end
        end)
    end)
end

local function AntiSweeperLoop()
    while State.AntiSweeper and Running do
        pcall(function()
            for _, v in pairs(Workspace:GetDescendants()) do
                if v.Name == "Spinner" then v:Destroy() end
            end
        end)
        task.wait(0.5)
    end
end

-- ============================================================
-- КОНСТАНТЫ РАЗМЕРОВ
-- ============================================================
local WIN_W       = 520
local WIN_H       = 540
local HEADER_H    = 50
local SIDEBAR_W   = 110
local STATUSBAR_H = 24
local CONTENT_X   = SIDEBAR_W + 1
local CONTENT_W   = WIN_W - CONTENT_X
local CONTENT_H   = WIN_H - HEADER_H - STATUSBAR_H

-- ============================================================
-- ГЛАВНОЕ ОКНО
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "HorrificUltimateGUI"
SG.Parent = game.CoreGui
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Enabled = false

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ClipsDescendants = true
Main.Parent = SG
Corner(Main, 14)
Stroke(Main, Color3.fromRGB(40, 40, 40), 1.5)

-- ============================================================
-- HEADER
-- ============================================================
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, HEADER_H)
Header.Position = UDim2.new(0, 0, 0, 0)
Header.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = Main
Corner(Header, 14)

local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 14)
HeaderFix.Position = UDim2.new(0, 0, 1, -14)
HeaderFix.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
HeaderFix.BorderSizePixel = 0
HeaderFix.ZIndex = 2
HeaderFix.Parent = Header

local HLine = Instance.new("Frame")
HLine.Size = UDim2.new(1, 0, 0, 1)
HLine.Position = UDim2.new(0, 0, 0, HEADER_H)
HLine.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
HLine.BorderSizePixel = 0
HLine.ZIndex = 2
HLine.Parent = Main

local AccentBar = Instance.new("Frame")
AccentBar.Size = UDim2.new(0, 2, 0, 26)
AccentBar.Position = UDim2.new(0, 16, 0.5, -13)
AccentBar.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
AccentBar.BorderSizePixel = 0
AccentBar.ZIndex = 4
AccentBar.Parent = Header
Corner(AccentBar, 2)

local TitleL = Instance.new("TextLabel")
TitleL.Size = UDim2.new(0, 280, 0, 22)
TitleL.Position = UDim2.new(0, 26, 0, 8)
TitleL.BackgroundTransparency = 1
TitleL.Font = Enum.Font.GothamBlack
TitleL.Text = "HORRIFIC HOUSING"
TitleL.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleL.TextSize = 14
TitleL.TextXAlignment = Enum.TextXAlignment.Left
TitleL.ZIndex = 3
TitleL.Parent = Header

local SubL = Instance.new("TextLabel")
SubL.Size = UDim2.new(0, 280, 0, 14)
SubL.Position = UDim2.new(0, 26, 0, 30)
SubL.BackgroundTransparency = 1
SubL.Font = Enum.Font.Gotham
SubL.Text = "v4.2  ·  QWEN  ·  DELETE — скрыть"
SubL.TextColor3 = Color3.fromRGB(60, 60, 60)
SubL.TextSize = 9
SubL.TextXAlignment = Enum.TextXAlignment.Left
SubL.ZIndex = 3
SubL.Parent = Header

local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Size = UDim2.new(0, 30, 0, 30)
SettingsBtn.Position = UDim2.new(1, -70, 0.5, -15)
SettingsBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
SettingsBtn.Font = Enum.Font.GothamBold
SettingsBtn.Text = "⚙"
SettingsBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
SettingsBtn.TextSize = 15
SettingsBtn.AutoButtonColor = false
SettingsBtn.ZIndex = 3
SettingsBtn.Parent = Header
Corner(SettingsBtn, 8)
Stroke(SettingsBtn, Color3.fromRGB(35, 35, 35), 1)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(35, 14, 14)
CloseBtn.Font = Enum.Font.GothamBlack
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.TextSize = 13
CloseBtn.AutoButtonColor = false
CloseBtn.ZIndex = 3
CloseBtn.Parent = Header
Corner(CloseBtn, 8)
Stroke(CloseBtn, Color3.fromRGB(60, 25, 25), 1)

-- ============================================================
-- SIDEBAR
-- ============================================================
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 0, CONTENT_H)
Sidebar.Position = UDim2.new(0, 0, 0, HEADER_H + 1)
Sidebar.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
Sidebar.BorderSizePixel = 0
Sidebar.ClipsDescendants = false
Sidebar.ZIndex = 2
Sidebar.Parent = Main

local SideDiv = Instance.new("Frame")
SideDiv.Size = UDim2.new(0, 1, 0, CONTENT_H)
SideDiv.Position = UDim2.new(0, SIDEBAR_W - 1, 0, HEADER_H + 1)
SideDiv.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
SideDiv.BorderSizePixel = 0
SideDiv.ZIndex = 3
SideDiv.Parent = Main

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 3)
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop    = UDim.new(0, 8)
SidePad.PaddingLeft   = UDim.new(0, 7)
SidePad.PaddingRight  = UDim.new(0, 7)
SidePad.PaddingBottom = UDim.new(0, 8)
SidePad.Parent = Sidebar

-- ============================================================
-- CONTENT AREA
-- ============================================================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(0, CONTENT_W, 0, CONTENT_H)
ContentArea.Position = UDim2.new(0, CONTENT_X, 0, HEADER_H + 1)
ContentArea.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true
ContentArea.ZIndex = 2
ContentArea.Parent = Main

-- ============================================================
-- STATUS BAR
-- ============================================================
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, 0, 0, STATUSBAR_H)
StatusBar.Position = UDim2.new(0, 0, 1, -STATUSBAR_H)
StatusBar.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 2
StatusBar.Parent = Main

local StatusLine = Instance.new("Frame")
StatusLine.Size = UDim2.new(1, 0, 0, 1)
StatusLine.Position = UDim2.new(0, 0, 0, 0)
StatusLine.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
StatusLine.BorderSizePixel = 0
StatusLine.ZIndex = 3
StatusLine.Parent = StatusBar

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 5, 0, 5)
StatusDot.Position = UDim2.new(0, 12, 0.5, -2)
StatusDot.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 4
StatusDot.Parent = StatusBar
Corner(StatusDot, 3)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -30, 1, 0)
StatusText.Position = UDim2.new(0, 22, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.Gotham
StatusText.Text = "Combat"
StatusText.TextColor3 = Color3.fromRGB(55, 55, 55)
StatusText.TextSize = 9
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.ZIndex = 3
StatusText.Parent = StatusBar

-- ============================================================
-- SETTINGS PANEL
-- ============================================================
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Name = "SettingsPanel"
SettingsPanel.Size = UDim2.new(1, 0, 1, 0)
SettingsPanel.Position = UDim2.new(1, 10, 0, 0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.ZIndex = 10
SettingsPanel.Visible = false
SettingsPanel.Parent = Main
Corner(SettingsPanel, 14)
Stroke(SettingsPanel, Color3.fromRGB(35, 35, 35), 1)

local SPTitle = Instance.new("TextLabel")
SPTitle.Size = UDim2.new(1, -60, 0, 50)
SPTitle.Position = UDim2.new(0, 18, 0, 0)
SPTitle.BackgroundTransparency = 1
SPTitle.Font = Enum.Font.GothamBlack
SPTitle.Text = "НАСТРОЙКИ"
SPTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
SPTitle.TextSize = 13
SPTitle.TextXAlignment = Enum.TextXAlignment.Left
SPTitle.ZIndex = 11
SPTitle.Parent = SettingsPanel

local SPClose = Instance.new("TextButton")
SPClose.Size = UDim2.new(0, 30, 0, 30)
SPClose.Position = UDim2.new(1, -44, 0, 10)
SPClose.BackgroundColor3 = Color3.fromRGB(35, 14, 14)
SPClose.Font = Enum.Font.GothamBlack
SPClose.Text = "X"
SPClose.TextColor3 = Color3.fromRGB(180, 50, 50)
SPClose.TextSize = 13
SPClose.AutoButtonColor = false
SPClose.ZIndex = 12
SPClose.Parent = SettingsPanel
Corner(SPClose, 8)

local SPLine = Instance.new("Frame")
SPLine.Size = UDim2.new(1, -36, 0, 1)
SPLine.Position = UDim2.new(0, 18, 0, 50)
SPLine.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
SPLine.BorderSizePixel = 0
SPLine.ZIndex = 11
SPLine.Parent = SettingsPanel

local UnloadBlock = Instance.new("Frame")
UnloadBlock.Size = UDim2.new(1, -36, 0, 64)
UnloadBlock.Position = UDim2.new(0, 18, 0, 62)
UnloadBlock.BackgroundColor3 = Color3.fromRGB(22, 10, 10)
UnloadBlock.BorderSizePixel = 0
UnloadBlock.ZIndex = 11
UnloadBlock.Parent = SettingsPanel
Corner(UnloadBlock, 10)
Stroke(UnloadBlock, Color3.fromRGB(55, 20, 20), 1)

local UnloadTitle = Instance.new("TextLabel")
UnloadTitle.Size = UDim2.new(0.6, 0, 0, 22)
UnloadTitle.Position = UDim2.new(0, 14, 0, 10)
UnloadTitle.BackgroundTransparency = 1
UnloadTitle.Font = Enum.Font.GothamBlack
UnloadTitle.Text = "Выгрузить скрипт"
UnloadTitle.TextColor3 = Color3.fromRGB(180, 50, 50)
UnloadTitle.TextSize = 12
UnloadTitle.TextXAlignment = Enum.TextXAlignment.Left
UnloadTitle.ZIndex = 12
UnloadTitle.Parent = UnloadBlock

local UnloadDesc = Instance.new("TextLabel")
UnloadDesc.Size = UDim2.new(0.6, 0, 0, 14)
UnloadDesc.Position = UDim2.new(0, 14, 0, 34)
UnloadDesc.BackgroundTransparency = 1
UnloadDesc.Font = Enum.Font.Gotham
UnloadDesc.Text = "Удаляет GUI и все хуки"
UnloadDesc.TextColor3 = Color3.fromRGB(60, 60, 60)
UnloadDesc.TextSize = 9
UnloadDesc.TextXAlignment = Enum.TextXAlignment.Left
UnloadDesc.ZIndex = 12
UnloadDesc.Parent = UnloadBlock

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0, 88, 0, 34)
UnloadBtn.Position = UDim2.new(1, -100, 0.5, -17)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
UnloadBtn.Font = Enum.Font.GothamBlack
UnloadBtn.Text = "ВЫГРУЗИТЬ"
UnloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
UnloadBtn.TextSize = 9
UnloadBtn.AutoButtonColor = false
UnloadBtn.ZIndex = 13
UnloadBtn.Parent = UnloadBlock
Corner(UnloadBtn, 8)

local ConfirmBlock = Instance.new("Frame")
ConfirmBlock.Size = UDim2.new(1, -36, 0, 84)
ConfirmBlock.Position = UDim2.new(0, 18, 0, 138)
ConfirmBlock.BackgroundColor3 = Color3.fromRGB(18, 8, 8)
ConfirmBlock.BorderSizePixel = 0
ConfirmBlock.ZIndex = 11
ConfirmBlock.Visible = false
ConfirmBlock.Parent = SettingsPanel
Corner(ConfirmBlock, 10)
Stroke(ConfirmBlock, Color3.fromRGB(120, 35, 35), 1)

local ConfirmText = Instance.new("TextLabel")
ConfirmText.Size = UDim2.new(1, -16, 0, 36)
ConfirmText.Position = UDim2.new(0, 12, 0, 6)
ConfirmText.BackgroundTransparency = 1
ConfirmText.Font = Enum.Font.GothamBold
ConfirmText.Text = "Вы уверены? Это удалит весь скрипт!"
ConfirmText.TextColor3 = Color3.fromRGB(180, 50, 50)
ConfirmText.TextSize = 11
ConfirmText.TextWrapped = true
ConfirmText.ZIndex = 12
ConfirmText.Parent = ConfirmBlock

local ConfirmYes = Instance.new("TextButton")
ConfirmYes.Size = UDim2.new(0.45, 0, 0, 28)
ConfirmYes.Position = UDim2.new(0, 10, 1, -36)
ConfirmYes.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
ConfirmYes.Font = Enum.Font.GothamBlack
ConfirmYes.Text = "ДА"
ConfirmYes.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmYes.TextSize = 11
ConfirmYes.AutoButtonColor = false
ConfirmYes.ZIndex = 13
ConfirmYes.Parent = ConfirmBlock
Corner(ConfirmYes, 7)

local ConfirmNo = Instance.new("TextButton")
ConfirmNo.Size = UDim2.new(0.45, 0, 0, 28)
ConfirmNo.Position = UDim2.new(0.55, -10, 1, -36)
ConfirmNo.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
ConfirmNo.Font = Enum.Font.GothamBlack
ConfirmNo.Text = "НЕТ"
ConfirmNo.TextColor3 = Color3.fromRGB(180, 180, 180)
ConfirmNo.TextSize = 11
ConfirmNo.AutoButtonColor = false
ConfirmNo.ZIndex = 13
ConfirmNo.Parent = ConfirmBlock
Corner(ConfirmNo, 7)
Stroke(ConfirmNo, Color3.fromRGB(40, 40, 40), 1)

local InfoBlock = Instance.new("Frame")
InfoBlock.Size = UDim2.new(1, -36, 0, 50)
InfoBlock.Position = UDim2.new(0, 18, 0, 234)
InfoBlock.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
InfoBlock.BorderSizePixel = 0
InfoBlock.ZIndex = 11
InfoBlock.Parent = SettingsPanel
Corner(InfoBlock, 10)
Stroke(InfoBlock, Color3.fromRGB(30, 30, 30), 1)

local InfoL = Instance.new("TextLabel")
InfoL.Size = UDim2.new(1, -16, 1, 0)
InfoL.Position = UDim2.new(0, 14, 0, 0)
InfoL.BackgroundTransparency = 1
InfoL.Font = Enum.Font.Gotham
InfoL.Text = "QWEN Horrific Housing v4.2\nKill Aura · ESP · Fling · Teleport · Misc"
InfoL.TextColor3 = Color3.fromRGB(45, 45, 45)
InfoL.TextSize = 10
InfoL.TextXAlignment = Enum.TextXAlignment.Left
InfoL.TextWrapped = true
InfoL.ZIndex = 12
InfoL.Parent = InfoBlock

local settingsOpen = false

local function OpenSettings()
    settingsOpen = true
    SettingsPanel.Visible = true
    SettingsPanel.Position = UDim2.new(1, 10, 0, 0)
    Tween(SettingsPanel, {Position = UDim2.new(0, 0, 0, 0)}, 0.25)
end

local function CloseSettings()
    settingsOpen = false
    Tween(SettingsPanel, {Position = UDim2.new(1, 10, 0, 0)}, 0.2)
    task.delay(0.22, function()
        SettingsPanel.Visible = false
        ConfirmBlock.Visible = false
    end)
end

SettingsBtn.MouseEnter:Connect(function()
    Tween(SettingsBtn, {BackgroundColor3 = Color3.fromRGB(32, 32, 32)}, 0.1)
    Tween(SettingsBtn, {TextColor3 = Color3.fromRGB(180, 180, 180)}, 0.1)
end)
SettingsBtn.MouseLeave:Connect(function()
    Tween(SettingsBtn, {BackgroundColor3 = Color3.fromRGB(22, 22, 22)}, 0.1)
    Tween(SettingsBtn, {TextColor3 = Color3.fromRGB(100, 100, 100)}, 0.1)
end)
SettingsBtn.MouseButton1Click:Connect(function()
    if settingsOpen then CloseSettings() else OpenSettings() end
end)

SPClose.MouseButton1Click:Connect(CloseSettings)
UnloadBtn.MouseButton1Click:Connect(function() ConfirmBlock.Visible = true end)
ConfirmNo.MouseButton1Click:Connect(function() ConfirmBlock.Visible = false end)
ConfirmYes.MouseButton1Click:Connect(function()
    Running = false
    FlingActive = false
    if antiVoidConn then antiVoidConn:Disconnect() end
    if deathNoteConn then deathNoteConn:Disconnect() end
    if autoSwordConn then autoSwordConn:Disconnect() end
    for plr, _ in pairs(espDrawings) do
        pcall(function()
            for _, d in pairs(espDrawings[plr]) do d.Visible = false d:Remove() end
        end)
    end
    espDrawings = {}
    pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
    Tween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 1.5, 0)}, 0.35)
    task.delay(0.35, function() pcall(function() SG:Destroy() end) end)
    print("Скрипт выгружен!")
end)

-- ============================================================
-- ВКЛАДКИ
-- ============================================================
local tabs = {"Combat","Movement","Fling","Teleport","ESP","Misc"}
local TabPages = {}
local TabBtns  = {}
local ActiveTab = "Combat"

local function MakePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Color3.fromRGB(40, 40, 40)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.BorderSizePixel = 0
    page.Visible = false
    page.Parent = ContentArea
    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 12)
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = page
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 7)
    lay.Parent = page
    return page
end

for _, name in ipairs(tabs) do
    TabPages[name] = MakePage()
end

local function SetTab(name)
    for _, page in pairs(TabPages) do page.Visible = false end
    if TabPages[name] then TabPages[name].Visible = true end
    for _, tName in ipairs(tabs) do
        local btn = TabBtns[tName]
        if not btn then continue end
        if tName == name then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            btn.BackgroundTransparency = 1
            btn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
            btn.TextColor3 = Color3.fromRGB(55, 55, 55)
        end
    end
    ActiveTab = name
    StatusText.Text = name
end

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, SIDEBAR_W - 14, 0, 32)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(13,13,13)
    btn.BackgroundTransparency = i == 1 and 0 or 1
    btn.Font = Enum.Font.GothamBold
    btn.Text = name
    btn.TextColor3 = i == 1 and Color3.fromRGB(0,0,0) or Color3.fromRGB(55,55,55)
    btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.ZIndex = 3
    btn.Parent = Sidebar
    Corner(btn, 7)
    local bp = Instance.new("UIPadding")
    bp.PaddingLeft = UDim.new(0, 10)
    bp.Parent = btn
    TabBtns[name] = btn
    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
            btn.TextColor3 = Color3.fromRGB(140, 140, 140)
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            btn.BackgroundTransparency = 1
            btn.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
            btn.TextColor3 = Color3.fromRGB(55, 55, 55)
        end
    end)
    btn.MouseButton1Click:Connect(function() SetTab(name) end)
end

TabPages[tabs[1]].Visible = true

-- ============================================================
-- UI КОМПОНЕНТЫ
-- ============================================================
local function SectionLabel(parent, text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = "— " .. text
    lbl.TextColor3 = Color3.fromRGB(45, 45, 45)
    lbl.TextSize = 9
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
end

local function Toggle(parent, name, desc, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 52)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, Color3.fromRGB(28, 28, 28), 1)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -70, 0, 20)
    nameL.Position = UDim2.new(0, 14, 0, 9)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamBold
    nameL.Text = name
    nameL.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameL.TextSize = 11
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = frame

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(1, -70, 0, 14)
    descL.Position = UDim2.new(0, 14, 0, 30)
    descL.BackgroundTransparency = 1
    descL.Font = Enum.Font.Gotham
    descL.Text = desc
    descL.TextColor3 = Color3.fromRGB(45, 45, 45)
    descL.TextSize = 9
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.Parent = frame

    local togBg = Instance.new("Frame")
    togBg.Size = UDim2.new(0, 44, 0, 24)
    togBg.Position = UDim2.new(1, -56, 0.5, -12)
    togBg.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    togBg.BorderSizePixel = 0
    togBg.Parent = frame
    Corner(togBg, 12)
    Stroke(togBg, Color3.fromRGB(38, 38, 38), 1)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    circle.BorderSizePixel = 0
    circle.Parent = togBg
    Corner(circle, 9)

    local enabled = false
    local stateKey = nil
    for k, v in pairs(State) do
        if type(v) == "boolean" then
            local nameLower = name:lower():gsub("%s", ""):gsub("-", "")
            local keyLower = k:lower()
            if nameLower:find(keyLower) or keyLower:find(nameLower) then
                stateKey = k
                break
            end
        end
    end
    if stateKey and State[stateKey] == true then
        enabled = true
    end	
	

    local btn = Instance.new("TextButton")
    if enabled then
        togBg.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
        circle.Position = UDim2.new(1, -21, 0.5, -9)
        circle.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        nameL.TextColor3 = Color3.fromRGB(255, 255, 255)
        descL.TextColor3 = Color3.fromRGB(70, 70, 70)
    end
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            Tween(togBg,  {BackgroundColor3 = Color3.fromRGB(220, 220, 220)}, 0.2)
            Tween(circle, {Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = Color3.fromRGB(10,10,10)}, 0.2)
            Tween(frame,  {BackgroundColor3 = Color3.fromRGB(20, 20, 20)}, 0.2)
            Tween(nameL,  {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.2)
            Tween(descL,  {TextColor3 = Color3.fromRGB(70, 70, 70)}, 0.2)
        else
            Tween(togBg,  {BackgroundColor3 = Color3.fromRGB(28, 28, 28)}, 0.2)
            Tween(circle, {Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = Color3.fromRGB(50,50,50)}, 0.2)
            Tween(frame,  {BackgroundColor3 = Color3.fromRGB(16, 16, 16)}, 0.2)
            Tween(nameL,  {TextColor3 = Color3.fromRGB(200, 200, 200)}, 0.2)
            Tween(descL,  {TextColor3 = Color3.fromRGB(45, 45, 45)}, 0.2)
        end
        callback(enabled)
        SaveSettings()
    end)

    btn.MouseEnter:Connect(function()
        if not enabled then
            Tween(frame, {BackgroundColor3 = Color3.fromRGB(19, 19, 19)}, 0.1)
        end
    end)
    btn.MouseLeave:Connect(function()
        if not enabled then
            Tween(frame, {BackgroundColor3 = Color3.fromRGB(16, 16, 16)}, 0.1)
        end
    end)
end

local function SliderInput(parent, name, minV, maxV, def, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 66)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, Color3.fromRGB(28, 28, 28), 1)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(0.55, 0, 0, 20)
    nameL.Position = UDim2.new(0, 14, 0, 10)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamBold
    nameL.Text = name
    nameL.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameL.TextSize = 11
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = frame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0, 56, 0, 24)
    inputBox.Position = UDim2.new(1, -68, 0, 8)
    inputBox.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    inputBox.Font = Enum.Font.GothamBold
    inputBox.Text = tostring(def)
    inputBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    inputBox.TextSize = 11
    inputBox.ClearTextOnFocus = true
    inputBox.BorderSizePixel = 0
    inputBox.Parent = frame
    Corner(inputBox, 7)
    Stroke(inputBox, Color3.fromRGB(35, 35, 35), 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -28, 0, 4)
    bar.Position = UDim2.new(0, 14, 0, 48)
    bar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bar.BorderSizePixel = 0
    bar.Parent = frame
    Corner(bar, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def - minV) / (maxV - minV), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Corner(fill, 2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((def - minV) / (maxV - minV), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    Corner(knob, 6)

    local dragBtn = Instance.new("TextButton")
    dragBtn.Size = UDim2.new(1, 0, 4, 0)
    dragBtn.Position = UDim2.new(0, 0, -1.5, 0)
    dragBtn.BackgroundTransparency = 1
    dragBtn.Text = ""
    dragBtn.Parent = bar

    local currentVal = def

    local function applyValue(v)
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        currentVal = v
        local pct = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        inputBox.Text = tostring(v)
        callback(v)
        SaveSettings()
    end

    inputBox.FocusLost:Connect(function()
        local num = tonumber(inputBox.Text)
        if num then applyValue(num)
        else inputBox.Text = tostring(currentVal) end
    end)

    local dragging = false
    dragBtn.MouseButton1Down:Connect(function() dragging = true end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pct = math.clamp(
                (i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1
            )
            applyValue(minV + (maxV - minV) * pct)
        end
    end)
end

local function Button(parent, name, desc, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 48)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, Color3.fromRGB(28, 28, 28), 1)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(0.6, 0, 0, 20)
    nameL.Position = UDim2.new(0, 14, 0, 8)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamBold
    nameL.Text = name
    nameL.TextColor3 = Color3.fromRGB(200, 200, 200)
    nameL.TextSize = 11
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = frame

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(0.6, 0, 0, 14)
    descL.Position = UDim2.new(0, 14, 0, 28)
    descL.BackgroundTransparency = 1
    descL.Font = Enum.Font.Gotham
    descL.Text = desc
    descL.TextColor3 = Color3.fromRGB(45, 45, 45)
    descL.TextSize = 9
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 68, 0, 28)
    btn.Position = UDim2.new(1, -80, 0.5, -14)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = "RUN"
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = frame
    Corner(btn, 8)
    Stroke(btn, Color3.fromRGB(45, 45, 45), 1)

    btn.MouseEnter:Connect(function()
        Tween(btn, {BackgroundColor3 = Color3.fromRGB(220,220,220)}, 0.12)
        Tween(btn, {TextColor3 = Color3.fromRGB(0,0,0)}, 0.12)
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, {BackgroundColor3 = Color3.fromRGB(28,28,28)}, 0.12)
        Tween(btn, {TextColor3 = Color3.fromRGB(200,200,200)}, 0.12)
    end)
    btn.MouseButton1Click:Connect(function()
        Tween(btn, {BackgroundColor3 = Color3.fromRGB(160,160,160)}, 0.08)
        task.wait(0.1)
        Tween(btn, {BackgroundColor3 = Color3.fromRGB(220,220,220)}, 0.1)
        callback()
    end)
end

-- ============================================================
-- COMBAT TAB
-- ============================================================
local CP = TabPages.Combat
SectionLabel(CP, "АВТО-АТАКА")
Toggle(CP, "Kill Aura", "Авто-атака всех игроков", function(s)
    State.KillAura = s
    if s then task.spawn(KillAura) end
end)

SectionLabel(CP, "ДАЛЬНОСТЬ")
Toggle(CP, "Reach", "Увеличить дальность меча", function(s)
    State.Reach = s
end)

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
local MP = TabPages.Movement
SectionLabel(MP, "ПАРАМЕТРЫ")
SliderInput(MP, "Скорость", 16, 250, State.Speed, function(v)
    State.Speed = v
    if Hum then Hum.WalkSpeed = v end
end)
SliderInput(MP, "Высота прыжка", 50, 400, State.JumpPower, function(v)
    State.JumpPower = v
    if Hum then Hum.JumpPower = v end
end)
SectionLabel(MP, "РЕЖИМЫ")
Toggle(MP, "Бесконечный прыжок", "Прыгай без ограничений", function(s)
    State.InfiniteJump = s
end)

SectionLabel(MP, "ПРОЧЕЕ")
Toggle(MP, "Noclip", "Проходить сквозь стены", function(s)
    State.Noclip = s
end)

-- ============================================================
-- FLING TAB
-- ============================================================
local FP = TabPages.Fling

local flingStatusF = Instance.new("Frame")
flingStatusF.Size = UDim2.new(1, 0, 0, 30)
flingStatusF.BackgroundColor3 = T.Surface
flingStatusF.BorderSizePixel = 0
flingStatusF.Parent = FP
Corner(flingStatusF, 6)
Stroke(flingStatusF, T.Border, 1)

local flingStatusL = Instance.new("TextLabel")
flingStatusL.Size = UDim2.new(1, -12, 1, 0)
flingStatusL.Position = UDim2.new(0, 10, 0, 0)
flingStatusL.BackgroundTransparency = 1
flingStatusL.Font = Enum.Font.GothamBold
flingStatusL.Text = "Выбери цель"
flingStatusL.TextColor3 = T.Muted
flingStatusL.TextSize = 10
flingStatusL.TextXAlignment = Enum.TextXAlignment.Left
flingStatusL.Parent = flingStatusF

local flingBtnRow = Instance.new("Frame")
flingBtnRow.Size = UDim2.new(1, 0, 0, 32)
flingBtnRow.BackgroundTransparency = 1
flingBtnRow.Parent = FP

local flingBtnRowLay = Instance.new("UIListLayout")
flingBtnRowLay.FillDirection = Enum.FillDirection.Horizontal
flingBtnRowLay.Padding = UDim.new(0, 5)
flingBtnRowLay.Parent = flingBtnRow

local function FlingActionBtnH(parent, text, bg, textColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.333, -4, 0, 32)
    b.BackgroundColor3 = bg
    b.Font = Enum.Font.GothamBlack
    b.Text = text
    b.TextColor3 = textColor
    b.TextSize = 10
    b.AutoButtonColor = false
    b.Parent = parent
    Corner(b, 5)
    Stroke(b, T.Border, 1)
    return b
end

local StartFBtn    = FlingActionBtnH(flingBtnRow, "START", T.White, T.Dark)
local StopFBtn     = FlingActionBtnH(flingBtnRow, "STOP", Color3.fromRGB(38,18,18), T.Danger)
local FlingAllFBtn = FlingActionBtnH(flingBtnRow, "ALL", T.Surface, T.Text)

local selFrame = Instance.new("Frame")
selFrame.Size = UDim2.new(1, 0, 0, 30)
selFrame.BackgroundColor3 = T.Surface
selFrame.BorderSizePixel = 0
selFrame.Parent = FP
Corner(selFrame, 6)
Stroke(selFrame, T.Border, 1)

local selText = Instance.new("TextLabel")
selText.Size = UDim2.new(1, -12, 1, 0)
selText.Position = UDim2.new(0, 10, 0, 0)
selText.BackgroundTransparency = 1
selText.Font = Enum.Font.GothamBold
selText.Text = "Цель: не выбрана"
selText.TextColor3 = T.Muted
selText.TextSize = 10
selText.TextXAlignment = Enum.TextXAlignment.Left
selText.Parent = selFrame

SectionLabel(FP, "ИГРОКИ")

local selRow = Instance.new("Frame")
selRow.Size = UDim2.new(1, 0, 0, 26)
selRow.BackgroundTransparency = 1
selRow.Parent = FP

local selRowLay = Instance.new("UIListLayout")
selRowLay.FillDirection = Enum.FillDirection.Horizontal
selRowLay.Padding = UDim.new(0, 5)
selRowLay.Parent = selRow

local function SmallBtn(parent, text)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, -3, 0, 26)
    b.BackgroundColor3 = T.Surface
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.TextColor3 = T.Muted
    b.TextSize = 9
    b.AutoButtonColor = false
    b.Parent = parent
    Corner(b, 5)
    Stroke(b, T.Border, 1)
    return b
end

local selAllBtn   = SmallBtn(selRow, "Выбрать всех")
local deselAllBtn = SmallBtn(selRow, "Снять всех")

local flingPlrCont = Instance.new("Frame")
flingPlrCont.Size = UDim2.new(1, 0, 0, 0)
flingPlrCont.AutomaticSize = Enum.AutomaticSize.Y
flingPlrCont.BackgroundTransparency = 1
flingPlrCont.Parent = FP

local flingPlrLay = Instance.new("UIListLayout")
flingPlrLay.Padding = UDim.new(0, 4)
flingPlrLay.Parent = flingPlrCont

local refreshFBtn = Instance.new("TextButton")
refreshFBtn.Size = UDim2.new(1, 0, 0, 24)
refreshFBtn.BackgroundColor3 = T.Surface
refreshFBtn.Font = Enum.Font.GothamBold
refreshFBtn.Text = "Обновить список"
refreshFBtn.TextColor3 = T.Muted
refreshFBtn.TextSize = 9
refreshFBtn.AutoButtonColor = false
refreshFBtn.Parent = FP
Corner(refreshFBtn, 5)
Stroke(refreshFBtn, T.Border, 1)

local flingCheckboxes = {}
local flingPlayerBtns = {}

local function RefreshFlingList()
    for _, b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end
    flingPlayerBtns = {}
    flingCheckboxes = {}

    local plrs = Players:GetPlayers()
    table.sort(plrs, function(a, b) return a.Name:lower() < b.Name:lower() end)

    for _, plr in ipairs(plrs) do
        if plr ~= LP then
            local isChecked = SelectedTargets[plr.Name] ~= nil
            local isTarget  = SelectedFlingTarget == plr

            local pF = Instance.new("Frame")
            pF.Size = UDim2.new(1, 0, 0, 38)
            pF.BackgroundColor3 = isTarget and Color3.fromRGB(32,32,32)
                or (isChecked and Color3.fromRGB(24,24,24) or T.Surface)
            pF.BorderSizePixel = 0
            pF.Parent = flingPlrCont
            Corner(pF, 6)
            Stroke(pF, isTarget and T.White or (isChecked and Color3.fromRGB(80,80,80) or T.Border), 1)

            local av = Instance.new("Frame")
            av.Size = UDim2.new(0, 24, 0, 24)
            av.Position = UDim2.new(0, 8, 0.5, -12)
            av.BackgroundColor3 = Color3.fromHSV((plr.UserId % 100) / 100, 0.25, 0.75)
            av.BorderSizePixel = 0
            av.Parent = pF
            Corner(av, 12)

            local avL = Instance.new("TextLabel")
            avL.Size = UDim2.new(1, 0, 1, 0)
            avL.BackgroundTransparency = 1
            avL.Font = Enum.Font.GothamBlack
            avL.Text = string.upper(string.sub(plr.Name, 1, 1))
            avL.TextColor3 = T.White
            avL.TextSize = 11
            avL.Parent = av

            local nL = Instance.new("TextLabel")
            nL.Size = UDim2.new(1, -90, 0, 18)
            nL.Position = UDim2.new(0, 40, 0, 5)
            nL.BackgroundTransparency = 1
            nL.Font = Enum.Font.GothamBold
            nL.Text = plr.DisplayName
            nL.TextColor3 = isTarget and T.White or (isChecked and T.Selected or T.Text)
            nL.TextSize = 10
            nL.TextXAlignment = Enum.TextXAlignment.Left
            nL.Parent = pF

            local uL = Instance.new("TextLabel")
            uL.Size = UDim2.new(1, -90, 0, 12)
            uL.Position = UDim2.new(0, 40, 0, 22)
            uL.BackgroundTransparency = 1
            uL.Font = Enum.Font.Gotham
            uL.Text = "@" .. plr.Name
            uL.TextColor3 = T.Muted
            uL.TextSize = 8
            uL.TextXAlignment = Enum.TextXAlignment.Left
            uL.Parent = pF

            local tBtn = Instance.new("TextButton")
            tBtn.Size = UDim2.new(0, 34, 0, 22)
            tBtn.Position = UDim2.new(1, -42, 0.5, -11)
            tBtn.BackgroundColor3 = isTarget and T.White or T.BG
            tBtn.Font = Enum.Font.GothamBlack
            tBtn.Text = "T"
            tBtn.TextColor3 = isTarget and T.Dark or T.Muted
            tBtn.TextSize = 9
            tBtn.AutoButtonColor = false
            tBtn.Parent = pF
            Corner(tBtn, 5)
            Stroke(tBtn, T.Border, 1)

            flingCheckboxes[plr.Name] = {frame = pF, nameL = nL, tBtn = tBtn}

            local clickArea = Instance.new("TextButton")
            clickArea.Size = UDim2.new(1, -48, 1, 0)
            clickArea.BackgroundTransparency = 1
            clickArea.Text = ""
            clickArea.Parent = pF

            local cp = plr

            clickArea.MouseButton1Click:Connect(function()
                if SelectedTargets[cp.Name] then
                    SelectedTargets[cp.Name] = nil
                    Tween(pF, {BackgroundColor3 = T.Surface}, 0.1)
                    nL.TextColor3 = T.Text
                else
                    SelectedTargets[cp.Name] = cp
                    Tween(pF, {BackgroundColor3 = Color3.fromRGB(24,24,24)}, 0.1)
                    nL.TextColor3 = T.Selected
                end
                local cnt = 0
                for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
                flingStatusL.Text = cnt > 0 and ("Выбрано: "..cnt) or "Выбери цель"
                flingStatusL.TextColor3 = cnt > 0 and T.Text or T.Muted
            end)

            tBtn.MouseButton1Click:Connect(function()
                if SelectedFlingTarget == cp then
                    SelectedFlingTarget = nil
                    selText.Text = "Цель: не выбрана"
                    selText.TextColor3 = T.Muted
                    Tween(tBtn, {BackgroundColor3 = T.BG}, 0.1)
                    tBtn.TextColor3 = T.Muted
                    Tween(pF, {BackgroundColor3 = T.Surface}, 0.1)
                else
                    for _, data in pairs(flingCheckboxes) do
                        Tween(data.tBtn, {BackgroundColor3 = T.BG}, 0.1)
                        data.tBtn.TextColor3 = T.Muted
                    end
                    SelectedFlingTarget = cp
                    selText.Text = cp.DisplayName.." (@"..cp.Name..")"
                    selText.TextColor3 = T.White
                    Tween(tBtn, {BackgroundColor3 = T.White}, 0.1)
                    tBtn.TextColor3 = T.Dark
                    Tween(pF, {BackgroundColor3 = Color3.fromRGB(32,32,32)}, 0.1)
                end
            end)

            table.insert(flingPlayerBtns, pF)
        end
    end

    if #flingPlayerBtns == 0 then
        local eL = Instance.new("TextLabel")
        eL.Size = UDim2.new(1, 0, 0, 28)
        eL.BackgroundTransparency = 1
        eL.Font = Enum.Font.Gotham
        eL.Text = "Нет других игроков"
        eL.TextColor3 = T.Muted
        eL.TextSize = 10
        eL.Parent = flingPlrCont
        table.insert(flingPlayerBtns, eL)
    end
end

StartFBtn.MouseButton1Click:Connect(function()
    local cnt = 0
    for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
    if cnt == 0 then
        flingStatusL.Text = "Выбери цели!"
        flingStatusL.TextColor3 = T.Danger
        task.delay(1.5, function()
            flingStatusL.Text = "Выбери цель"
            flingStatusL.TextColor3 = T.Muted
        end)
        return
    end
    FlingActive = true
    flingStatusL.Text = "Флинг: "..cnt.." цел."
    flingStatusL.TextColor3 = T.Danger
    task.spawn(function()
        while FlingActive do
            for name, player in pairs(SelectedTargets) do
                if not player or not player.Parent then SelectedTargets[name] = nil end
            end
            local cnt2 = 0
            for _ in pairs(SelectedTargets) do cnt2 = cnt2 + 1 end
            if cnt2 == 0 then FlingActive = false break end
            flingStatusL.Text = "Флинг: "..cnt2.." цел."
            for _, player in pairs(SelectedTargets) do
                if FlingActive and player and player.Parent then
                    SkidFling(player)  task.wait(0.1)
                end
            end
            task.wait(0.3)
        end
        flingStatusL.Text = "Выбери цель"
        flingStatusL.TextColor3 = T.Muted
    end)
end)

StopFBtn.MouseButton1Click:Connect(function()
    FlingActive = false
    flingStatusL.Text = "Остановлено"
    flingStatusL.TextColor3 = T.Muted
end)

FlingAllFBtn.MouseButton1Click:Connect(function() task.spawn(FlingAll) end)

selAllBtn.MouseButton1Click:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            SelectedTargets[plr.Name] = plr
            local cb = flingCheckboxes[plr.Name]
            if cb then
                cb.nameL.TextColor3 = T.Selected
                cb.frame.BackgroundColor3 = Color3.fromRGB(24,24,24)
            end
        end
    end
    local cnt = 0
    for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
    flingStatusL.Text = "Выбрано: "..cnt
    flingStatusL.TextColor3 = T.Text
end)

deselAllBtn.MouseButton1Click:Connect(function()
    SelectedTargets = {}
    for _, cb in pairs(flingCheckboxes) do
        cb.nameL.TextColor3 = T.Text
        cb.frame.BackgroundColor3 = T.Surface
    end
    flingStatusL.Text = "Выбери цель"
    flingStatusL.TextColor3 = T.Muted
end)

refreshFBtn.MouseButton1Click:Connect(RefreshFlingList)

-- ============================================================
-- TELEPORT TAB
-- ============================================================
local TPP = TabPages.Teleport
SectionLabel(TPP, "ТОЧКИ")

local spawnF = Instance.new("Frame")
spawnF.Size = UDim2.new(1, 0, 0, 36)
spawnF.BackgroundColor3 = T.Surface
spawnF.BorderSizePixel = 0
spawnF.Parent = TPP
Corner(spawnF, 6)
Stroke(spawnF, T.Border, 1)
local spawnL = Instance.new("TextLabel")
spawnL.Size = UDim2.new(0.6, 0, 1, 0)
spawnL.Position = UDim2.new(0, 10, 0, 0)
spawnL.BackgroundTransparency = 1
spawnL.Font = Enum.Font.GothamBold
spawnL.Text = "Spawn"
spawnL.TextColor3 = T.Text
spawnL.TextSize = 11
spawnL.TextXAlignment = Enum.TextXAlignment.Left
spawnL.Parent = spawnF
local spawnB = Instance.new("TextButton")
spawnB.Size = UDim2.new(0, 72, 0, 24)
spawnB.Position = UDim2.new(1, -80, 0.5, -12)
spawnB.BackgroundColor3 = T.White
spawnB.Font = Enum.Font.GothamBlack
spawnB.Text = "ТП"
spawnB.TextColor3 = T.Dark
spawnB.TextSize = 10
spawnB.AutoButtonColor = false
spawnB.Parent = spawnF
Corner(spawnB, 5)
spawnB.MouseEnter:Connect(function() Tween(spawnB, {BackgroundColor3 = Color3.fromRGB(200,200,200)}, 0.1) end)
spawnB.MouseLeave:Connect(function() Tween(spawnB, {BackgroundColor3 = T.White}, 0.1) end)
spawnB.MouseButton1Click:Connect(function()
    pcall(function() HRP.CFrame = CFrame.new(0, 50, 0) end)
end)

SectionLabel(TPP, "К ИГРОКУ")

local tpPlrCont = Instance.new("Frame")
tpPlrCont.Size = UDim2.new(1, 0, 0, 0)
tpPlrCont.AutomaticSize = Enum.AutomaticSize.Y
tpPlrCont.BackgroundTransparency = 1
tpPlrCont.Parent = TPP

local tpPlrLay = Instance.new("UIListLayout")
tpPlrLay.Padding = UDim.new(0, 4)
tpPlrLay.Parent = tpPlrCont

local tpPlrBtns = {}

local function RefreshTpList()
    for _, b in pairs(tpPlrBtns) do pcall(function() b:Destroy() end) end
    tpPlrBtns = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 34)
            f.BackgroundColor3 = T.Surface
            f.BorderSizePixel = 0
            f.Parent = tpPlrCont
            Corner(f, 6)
            Stroke(f, T.Border, 1)

            local nL = Instance.new("TextLabel")
            nL.Size = UDim2.new(0.6, 0, 1, 0)
            nL.Position = UDim2.new(0, 10, 0, 0)
            nL.BackgroundTransparency = 1
            nL.Font = Enum.Font.GothamBold
            nL.Text = plr.DisplayName
            nL.TextColor3 = T.Text
            nL.TextSize = 10
            nL.TextXAlignment = Enum.TextXAlignment.Left
            nL.Parent = f

            local tpB = Instance.new("TextButton")
            tpB.Size = UDim2.new(0, 72, 0, 22)
            tpB.Position = UDim2.new(1, -80, 0.5, -11)
            tpB.BackgroundColor3 = T.White
            tpB.Font = Enum.Font.GothamBlack
            tpB.Text = "ТП"
            tpB.TextColor3 = T.Dark
            tpB.TextSize = 10
            tpB.AutoButtonColor = false
            tpB.Parent = f
            Corner(tpB, 5)

            tpB.MouseEnter:Connect(function() Tween(tpB, {BackgroundColor3 = Color3.fromRGB(200,200,200)}, 0.1) end)
            tpB.MouseLeave:Connect(function() Tween(tpB, {BackgroundColor3 = T.White}, 0.1) end)

            local cp = plr
            tpB.MouseButton1Click:Connect(function()
                pcall(function()
                    local tc = cp.Character
                    if tc and tc:FindFirstChild("HumanoidRootPart") then
                        HRP.CFrame = tc.HumanoidRootPart.CFrame * CFrame.new(0,0,-3)
                    end
                end)
            end)

            table.insert(tpPlrBtns, f)
        end
    end
    if #tpPlrBtns == 0 then
        local eL = Instance.new("TextLabel")
        eL.Size = UDim2.new(1, 0, 0, 28)
        eL.BackgroundTransparency = 1
        eL.Font = Enum.Font.Gotham
        eL.Text = "Нет других игроков"
        eL.TextColor3 = T.Muted
        eL.TextSize = 10
        eL.Parent = tpPlrCont
        table.insert(tpPlrBtns, eL)
    end
end

local tpRefBtn = Instance.new("TextButton")
tpRefBtn.Size = UDim2.new(1, 0, 0, 24)
tpRefBtn.BackgroundColor3 = T.Surface
tpRefBtn.Font = Enum.Font.GothamBold
tpRefBtn.Text = "Обновить"
tpRefBtn.TextColor3 = T.Muted
tpRefBtn.TextSize = 9
tpRefBtn.AutoButtonColor = false
tpRefBtn.Parent = TPP
Corner(tpRefBtn, 5)
Stroke(tpRefBtn, T.Border, 1)
tpRefBtn.MouseButton1Click:Connect(RefreshTpList)

-- ============================================================
-- ESP TAB
-- ============================================================
local EP = TabPages.ESP
SectionLabel(EP, "ВИДИМОСТЬ")
Toggle(EP, "ESP", "Видеть игроков сквозь стены", function(s)
    State.ESP = s
    if not s then for plr, _ in pairs(espDrawings) do removeESP(plr) end end
end)

-- ============================================================
-- MISC TAB
-- ============================================================
local MiscP = TabPages.Misc
SectionLabel(MiscP, "АВТО")
Toggle(MiscP, "Death Note TP", "Авто-тп к тетради смерти", function(s)
    State.DeathNoteTP = s
    if s then StartDeathNoteTP()
    else
        if deathNoteConn then deathNoteConn:Disconnect() deathNoteConn = nil end
    end
end)
Toggle(MiscP, "Auto Sword TP", "Авто-тп к мечу когда падает", function(s)
    State.AutoSword = s
    if s then StartAutoSword()
    else
        if autoSwordConn then autoSwordConn:Disconnect() autoSwordConn = nil end
    end
end)
SectionLabel(MiscP, "ЗАЩИТА")
Toggle(MiscP, "Anti-Lava", "Убирает всю лаву", function(s)
    State.AntiLava = s
    if s then task.spawn(AntiLavaLoop) end
end)
Toggle(MiscP, "Anti-Void", "Телепорт на безопасную позицию", function(s)
    State.AntiVoid = s
    if s then StartAntiVoid() end
end)
Toggle(MiscP, "Anti-Spinner", "Удаляет Spinner объекты", function(s)
    State.AntiSweeper = s
    if s then task.spawn(AntiSweeperLoop) end
end)

-- ============================================================
-- CLOSE BUTTON
-- ============================================================
CloseBtn.MouseEnter:Connect(function()
    Tween(CloseBtn, {BackgroundColor3 = Color3.fromRGB(60,20,20)}, 0.1)
end)
CloseBtn.MouseLeave:Connect(function()
    Tween(CloseBtn, {BackgroundColor3 = Color3.fromRGB(40,18,18)}, 0.1)
end)
CloseBtn.MouseButton1Click:Connect(function()
    Tween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 1.5, 0)}, 0.3)
    task.delay(0.32, function()
        SG.Enabled = false
        MenuOpen = false
        Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
    end)
end)

-- ============================================================
-- TOGGLE MENU (DELETE)
-- ============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp or not Running then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        if not MenuOpen then
            MenuOpen = true
            SG.Enabled = true
            Main.Position = UDim2.new(0.5, -WIN_W/2, -0.5, 0)
            Tween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)}, 0.35)
        else
            Tween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 1.5, 0)}, 0.3)
            task.delay(0.32, function()
                SG.Enabled = false
                MenuOpen = false
                Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
            end)
        end
    end
end)

-- ============================================================
-- RUNTIME EVENTS
-- ============================================================
local jumpDebounce = false
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space and State.InfiniteJump then
        if not Hum or not HRP then return end
        local state = Hum:GetState()
        if state == Enum.HumanoidStateType.Freefall and not jumpDebounce then
            jumpDebounce = true
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(HRP.Velocity.X, 20, HRP.Velocity.Z)
            bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Parent = HRP
            task.delay(0.08, function()
                bv:Destroy()
                task.delay(0.3, function()
                    jumpDebounce = false
                end)
            end)
        end
    end
end)

RS.RenderStepped:Connect(function()
    if not Running then return end
    updateESP()
    if State.Noclip then
        pcall(function()
            for _, part in pairs(Char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    end
    if State.Reach then
        pcall(function()
            local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
            if tool and isMeleeTool(tool) then
                local handle = tool:FindFirstChild("Handle")
                if handle then
                    handle.Size = Vector3.new(1, 1, 15)
                end
            end
        end)
    end
end)

LP.CharacterAdded:Connect(function(char)
    Char = char
    Hum = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
    Hum.WalkSpeed = State.Speed
    Hum.JumpPower = State.JumpPower
    Hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if Hum.WalkSpeed ~= State.Speed then
            Hum.WalkSpeed = State.Speed
        end
    end)
    Hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if Hum.JumpPower ~= State.JumpPower then
            Hum.JumpPower = State.JumpPower
        end
    end)
    lastSafePos = nil
    if State.AntiVoid then StartAntiVoid() end
    if State.AutoSword then StartAutoSword() end
    if State.DeathNoteTP then StartDeathNoteTP() end
end)

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    RefreshFlingList()
    RefreshTpList()
end)

Players.PlayerRemoving:Connect(function(plr)
    if SelectedFlingTarget == plr then
        SelectedFlingTarget = nil
        selText.Text = "Цель: не выбрана"
        selText.TextColor3 = T.Muted
    end
    SelectedTargets[plr.Name] = nil
    RefreshFlingList()
    RefreshTpList()
    removeESP(plr)
end)

-- ============================================================
-- INIT
-- ============================================================
task.wait(0.5)
RefreshFlingList()
-- Запуск функций если они были включены при загрузке
if State.KillAura then task.spawn(KillAura) end
if State.AntiLava then task.spawn(AntiLavaLoop) end
if State.AntiVoid then StartAntiVoid() end
if State.AntiSweeper then task.spawn(AntiSweeperLoop) end
if State.DeathNoteTP then StartDeathNoteTP() end
if State.AutoSword then StartAutoSword() end
if State.InfiniteJump then end -- включается через UIS автоматически
RefreshTpList()

SG.Enabled = true
MenuOpen = true
Main.Position = UDim2.new(0.5, -WIN_W/2, -0.5, 0)
Tween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)}, 0.35)

print("QWEN v4.2 loaded | DELETE = скрыть/показать | ⚙ = настройки/выгрузка")
