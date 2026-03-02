--[[
    QWEN Horrific Housing Ultimate + Real Fling
    DELETE - открыть/закрыть меню
    Scroll - переключение вкладок
]]

-- ============================================================
-- CLEANUP
-- ============================================================
for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("HorrificUltimate") or gui.Name == "KilasikFlingGUI" then
        pcall(function() gui:Destroy() end)
    end
end

-- ============================================================
-- SERVICES
-- ============================================================
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

-- ============================================================
-- STATE
-- ============================================================
local Running = true
local MenuOpen = false
local CurrentTabIndex = 1

local State = {
    Speed = 16,
    JumpPower = 50,
    KillAura = false,
    ESP = false,
    NoCooldownBlade = false,
    NoCooldownSword = false,
    NoCooldownPrompts = false,
    AutoGetMap = false,
    AutoTouchIllumina = false,
    AntiLava = false,
    AntiVoid = false,
    InfiniteJump = false,
    AntiSpinner = false,
}

-- FLING STATE
local FlingActive = false
local SelectedTargets = {}  -- для мульти-флинга
local SelectedFlingTarget = nil  -- для одиночного флинга (QWEN список)
local espDrawings = {}

getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

-- ============================================================
-- THEME
-- ============================================================
local T = {
    BG = Color3.fromRGB(8,8,8),
    BG2 = Color3.fromRGB(14,14,14),
    Surface = Color3.fromRGB(20,20,20),
    Hover = Color3.fromRGB(32,32,32),
    Primary = Color3.fromRGB(255,255,255),
    Text = Color3.fromRGB(245,245,245),
    Muted = Color3.fromRGB(85,85,85),
    Dark = Color3.fromRGB(0,0,0),
    Border = Color3.fromRGB(38,38,38),
    Danger = Color3.fromRGB(255,70,70),
    Selected = Color3.fromRGB(255,200,50),
    Green = Color3.fromRGB(80,255,80),
    Blue = Color3.fromRGB(80,160,255),
}

-- ============================================================
-- UI HELPERS
-- ============================================================
local function Corner(p,r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = p
    return c
end

local function Stroke(p,c,t)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Border
    s.Thickness = t or 1
    s.Parent = p
    return s
end

local function Tween(o,pr,d)
    if not o or not o.Parent then return end
    TS:Create(o, TweenInfo.new(d or 0.3, Enum.EasingStyle.Quint), pr):Play()
end

local function lerpColor(a,b,t)
    return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
end

-- ============================================================
-- РЕАЛЬНЫЙ SKID FLING (механика из zqyDSUWX)
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
    if THumanoid and THumanoid.RootPart then
        TRootPart = THumanoid.RootPart
    end
    if TCharacter:FindFirstChild("Head") then
        THead = TCharacter.Head
    end
    if TCharacter:FindFirstChildOfClass("Accessory") then
        Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    end
    if Accessory and Accessory:FindFirstChild("Handle") then
        Handle = Accessory.Handle
    end

    if not (Character and Humanoid and RootPart) then return end

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end

    if THumanoid and THumanoid.Sit then return end

    -- Переключаем камеру на цель
    if THead then
        workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then
        workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then
        workspace.CurrentCamera.CameraSubject = THumanoid
    end

    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

    -- Функция позиционирования
    local FPos = function(BasePart, Pos, Ang)
        RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
        Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
        RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    -- Основной цикл флинга
    local SFBasePart = function(BasePart)
        local TimeToWait = 2
        local Time = tick()
        local Angle = 0
        repeat
            if RootPart and THumanoid then
                if BasePart.Velocity.Magnitude < 50 then
                    Angle = Angle + 100
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                    task.wait()
                else
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                    task.wait()
                    FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
                    task.wait()
                end
            end
        until Time + TimeToWait < tick() or not FlingActive
    end

    workspace.FallenPartsDestroyHeight = 0/0

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart
    BV.Velocity = Vector3.new(0, 0, 0)
    BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    if TRootPart then
        SFBasePart(TRootPart)
    elseif THead then
        SFBasePart(THead)
    elseif Handle then
        SFBasePart(Handle)
    end

    BV:Destroy()
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    workspace.CurrentCamera.CameraSubject = Humanoid

    -- Возвращаем персонажа на место
    if getgenv().OldPos then
        repeat
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
            Humanoid:ChangeState("GettingUp")
            for _, part in pairs(Character:GetChildren()) do
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

-- Флинг одиночной цели (одноразовый)
local function FlingTarget(targetPlayer)
    if not targetPlayer then return end
    local wasActive = FlingActive
    FlingActive = true
    task.spawn(function()
        SkidFling(targetPlayer)
        if not wasActive then FlingActive = false end
    end)
end

-- Флинг всех (одноразовый)
local function FlingAll()
    local wasActive = FlingActive
    FlingActive = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            task.spawn(function()
                SkidFling(plr)
            end)
            task.wait(0.1)
        end
    end
    if not wasActive then FlingActive = false end
end

-- Непрерывный мульти-флинг (START/STOP)
local function StartMultiFling(statusLabel, checkboxes)
    if FlingActive then return end

    local count = 0
    for _ in pairs(SelectedTargets) do count = count + 1 end
    if count == 0 then
        statusLabel.Text = "⚠️ Выбери цели!"
        statusLabel.TextColor3 = T.Danger
        task.wait(1.5)
        statusLabel.Text = "Выбери цели и нажми START"
        statusLabel.TextColor3 = T.Muted
        return
    end

    FlingActive = true
    statusLabel.Text = "⚡ Флингаем " .. count .. " цел(ей)..."
    statusLabel.TextColor3 = Color3.fromRGB(255,80,80)

    task.spawn(function()
        while FlingActive do
            -- Проверяем что цели ещё в игре
            for name, player in pairs(SelectedTargets) do
                if not player or not player.Parent then
                    SelectedTargets[name] = nil
                    local cb = checkboxes[name]
                    if cb then cb.Visible = false end
                end
            end

            local count2 = 0
            for _ in pairs(SelectedTargets) do count2 = count2 + 1 end
            if count2 == 0 then
                FlingActive = false
                break
            end

            statusLabel.Text = "⚡ Флингаем " .. count2 .. " цел(ей)..."

            for _, player in pairs(SelectedTargets) do
                if FlingActive and player and player.Parent then
                    SkidFling(player)
                    task.wait(0.1)
                end
            end

            task.wait(0.3)
        end

        statusLabel.Text = "Выбери цели и нажми START"
        statusLabel.TextColor3 = T.Muted
    end)
end

local function StopMultiFling()
    FlingActive = false
end

-- ============================================================
-- MAIN GUI
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "HorrificUltimateGUI"
SG.Parent = game.CoreGui
SG.ResetOnSpawn = false
SG.Enabled = false

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,520,0,680)
Main.Position = UDim2.new(0.5,-260,0.5,-340)
Main.BackgroundColor3 = T.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ZIndex = 10
Main.Parent = SG
Corner(Main,20)
Stroke(Main)

-- HEADER
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,64)
Header.BackgroundColor3 = T.BG2
Header.BorderSizePixel = 0
Header.ZIndex = 11
Header.Parent = Main
Corner(Header,20)

local HBot = Instance.new("Frame")
HBot.Size = UDim2.new(1,0,0,20)
HBot.Position = UDim2.new(0,0,1,-20)
HBot.BackgroundColor3 = T.BG2
HBot.BorderSizePixel = 0
HBot.ZIndex = 11
HBot.Parent = Header

local QwenTitle = Instance.new("TextLabel")
QwenTitle.Size = UDim2.new(1,-160,1,0)
QwenTitle.Position = UDim2.new(0,20,0,0)
QwenTitle.BackgroundTransparency = 1
QwenTitle.Font = Enum.Font.GothamBlack
QwenTitle.Text = "⚔️ QWEN HORRIFIC HOUSING"
QwenTitle.TextColor3 = T.Text
QwenTitle.TextSize = 16
QwenTitle.TextXAlignment = Enum.TextXAlignment.Left
QwenTitle.ZIndex = 12
QwenTitle.Parent = Header

-- SETTINGS BUTTON (шестерёнка)
local SettingsBtn = Instance.new("TextButton")
SettingsBtn.Size = UDim2.new(0,38,0,38)
SettingsBtn.Position = UDim2.new(1,-96,0.5,-19)
SettingsBtn.BackgroundColor3 = T.Surface
SettingsBtn.Font = Enum.Font.GothamBold
SettingsBtn.Text = "⚙️"
SettingsBtn.TextColor3 = T.Text
SettingsBtn.TextSize = 18
SettingsBtn.AutoButtonColor = false
SettingsBtn.ZIndex = 13
SettingsBtn.Parent = Header
Corner(SettingsBtn,19)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,38,0,38)
CloseBtn.Position = UDim2.new(1,-50,0.5,-19)
CloseBtn.BackgroundColor3 = T.Surface
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Text = "X"
CloseBtn.TextColor3 = T.Muted
CloseBtn.TextSize = 14
CloseBtn.AutoButtonColor = false
CloseBtn.ZIndex = 13
CloseBtn.Parent = Header
Corner(CloseBtn,19)

-- ============================================================
-- SETTINGS PANEL
-- ============================================================
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(1,0,1,0)
SettingsPanel.Position = UDim2.new(1,10,0,0)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(10,10,10)
SettingsPanel.BorderSizePixel = 0
SettingsPanel.ZIndex = 50
SettingsPanel.Visible = false
SettingsPanel.Parent = Main
Corner(SettingsPanel,20)
Stroke(SettingsPanel,T.Border,1)

local SPTitle = Instance.new("TextLabel")
SPTitle.Size = UDim2.new(1,0,0,50)
SPTitle.BackgroundTransparency = 1
SPTitle.Font = Enum.Font.GothamBlack
SPTitle.Text = "⚙️  НАСТРОЙКИ"
SPTitle.TextColor3 = T.Text
SPTitle.TextSize = 18
SPTitle.ZIndex = 51
SPTitle.Parent = SettingsPanel

local SPClose = Instance.new("TextButton")
SPClose.Size = UDim2.new(0,38,0,38)
SPClose.Position = UDim2.new(1,-50,0,6)
SPClose.BackgroundColor3 = T.Surface
SPClose.Font = Enum.Font.GothamBold
SPClose.Text = "X"
SPClose.TextColor3 = T.Muted
SPClose.TextSize = 14
SPClose.AutoButtonColor = false
SPClose.ZIndex = 52
SPClose.Parent = SettingsPanel
Corner(SPClose,19)

local SPSep = Instance.new("Frame")
SPSep.Size = UDim2.new(1,-40,0,1)
SPSep.Position = UDim2.new(0,20,0,55)
SPSep.BackgroundColor3 = T.Border
SPSep.BorderSizePixel = 0
SPSep.ZIndex = 51
SPSep.Parent = SettingsPanel

-- UNLOAD FRAME
local UnloadFrame = Instance.new("Frame")
UnloadFrame.Size = UDim2.new(1,-40,0,70)
UnloadFrame.Position = UDim2.new(0,20,0,70)
UnloadFrame.BackgroundColor3 = Color3.fromRGB(30,10,10)
UnloadFrame.BorderSizePixel = 0
UnloadFrame.ZIndex = 51
UnloadFrame.Parent = SettingsPanel
Corner(UnloadFrame,16)
Stroke(UnloadFrame, Color3.fromRGB(120,20,20), 1)

local UnloadIcon = Instance.new("TextLabel")
UnloadIcon.Size = UDim2.new(0,50,1,0)
UnloadIcon.Position = UDim2.new(0,10,0,0)
UnloadIcon.BackgroundTransparency = 1
UnloadIcon.Font = Enum.Font.GothamBlack
UnloadIcon.Text = "🗑️"
UnloadIcon.TextColor3 = T.Danger
UnloadIcon.TextSize = 26
UnloadIcon.ZIndex = 52
UnloadIcon.Parent = UnloadFrame

local UnloadTitleL = Instance.new("TextLabel")
UnloadTitleL.Size = UDim2.new(1,-170,0,22)
UnloadTitleL.Position = UDim2.new(0,58,0,10)
UnloadTitleL.BackgroundTransparency = 1
UnloadTitleL.Font = Enum.Font.GothamBlack
UnloadTitleL.Text = "Выгрузить скрипт"
UnloadTitleL.TextColor3 = T.Danger
UnloadTitleL.TextSize = 13
UnloadTitleL.TextXAlignment = Enum.TextXAlignment.Left
UnloadTitleL.ZIndex = 52
UnloadTitleL.Parent = UnloadFrame

local UnloadDescL = Instance.new("TextLabel")
UnloadDescL.Size = UDim2.new(1,-170,0,16)
UnloadDescL.Position = UDim2.new(0,58,0,34)
UnloadDescL.BackgroundTransparency = 1
UnloadDescL.Font = Enum.Font.Gotham
UnloadDescL.Text = "Удаляет весь GUI и хуки"
UnloadDescL.TextColor3 = T.Muted
UnloadDescL.TextSize = 10
UnloadDescL.TextXAlignment = Enum.TextXAlignment.Left
UnloadDescL.ZIndex = 52
UnloadDescL.Parent = UnloadFrame

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(0,90,0,36)
UnloadBtn.Position = UDim2.new(1,-100,0.5,-18)
UnloadBtn.BackgroundColor3 = T.Danger
UnloadBtn.Font = Enum.Font.GothamBlack
UnloadBtn.Text = "ВЫГРУЗИТЬ"
UnloadBtn.TextColor3 = Color3.fromRGB(255,255,255)
UnloadBtn.TextSize = 10
UnloadBtn.AutoButtonColor = false
UnloadBtn.ZIndex = 53
UnloadBtn.Parent = UnloadFrame
Corner(UnloadBtn,18)

-- CONFIRM PANEL
local ConfirmPanel = Instance.new("Frame")
ConfirmPanel.Size = UDim2.new(1,-40,0,100)
ConfirmPanel.Position = UDim2.new(0,20,0,155)
ConfirmPanel.BackgroundColor3 = Color3.fromRGB(20,15,15)
ConfirmPanel.BorderSizePixel = 0
ConfirmPanel.ZIndex = 51
ConfirmPanel.Visible = false
ConfirmPanel.Parent = SettingsPanel
Corner(ConfirmPanel,16)
Stroke(ConfirmPanel,T.Danger,1)

local ConfirmText = Instance.new("TextLabel")
ConfirmText.Size = UDim2.new(1,-20,0,40)
ConfirmText.Position = UDim2.new(0,10,0,8)
ConfirmText.BackgroundTransparency = 1
ConfirmText.Font = Enum.Font.GothamBold
ConfirmText.Text = "⚠️ Вы уверены? Это удалит весь скрипт!"
ConfirmText.TextColor3 = T.Danger
ConfirmText.TextSize = 12
ConfirmText.TextWrapped = true
ConfirmText.ZIndex = 52
ConfirmText.Parent = ConfirmPanel

local ConfirmYes = Instance.new("TextButton")
ConfirmYes.Size = UDim2.new(0.45,0,0,34)
ConfirmYes.Position = UDim2.new(0,8,1,-42)
ConfirmYes.BackgroundColor3 = T.Danger
ConfirmYes.Font = Enum.Font.GothamBlack
ConfirmYes.Text = "✓  ДА"
ConfirmYes.TextColor3 = Color3.fromRGB(255,255,255)
ConfirmYes.TextSize = 13
ConfirmYes.AutoButtonColor = false
ConfirmYes.ZIndex = 53
ConfirmYes.Parent = ConfirmPanel
Corner(ConfirmYes,17)

local ConfirmNo = Instance.new("TextButton")
ConfirmNo.Size = UDim2.new(0.45,0,0,34)
ConfirmNo.Position = UDim2.new(0.55,-8,1,-42)
ConfirmNo.BackgroundColor3 = T.Surface
ConfirmNo.Font = Enum.Font.GothamBlack
ConfirmNo.Text = "✕  НЕТ"
ConfirmNo.TextColor3 = T.Text
ConfirmNo.TextSize = 13
ConfirmNo.AutoButtonColor = false
ConfirmNo.ZIndex = 53
ConfirmNo.Parent = ConfirmPanel
Corner(ConfirmNo,17)

-- INFO
local InfoFrame = Instance.new("Frame")
InfoFrame.Size = UDim2.new(1,-40,0,80)
InfoFrame.Position = UDim2.new(0,20,0,270)
InfoFrame.BackgroundColor3 = T.Surface
InfoFrame.BorderSizePixel = 0
InfoFrame.ZIndex = 51
InfoFrame.Parent = SettingsPanel
Corner(InfoFrame,16)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1,-20,1,0)
InfoLabel.Position = UDim2.new(0,15,0,0)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.Text = "ℹ️  QWEN Horrific Housing Ultimate\nВерсия 3.0  |  Реальный SkidFling\nDELETE — открыть/закрыть"
InfoLabel.TextColor3 = T.Muted
InfoLabel.TextSize = 11
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextWrapped = true
InfoLabel.ZIndex = 52
InfoLabel.Parent = InfoFrame

local settingsOpen = false

local function OpenSettings()
    settingsOpen = true
    SettingsPanel.Visible = true
    SettingsPanel.Position = UDim2.new(1,10,0,0)
    Tween(SettingsPanel,{Position=UDim2.new(0,0,0,0)},0.3)
end

local function CloseSettings()
    settingsOpen = false
    Tween(SettingsPanel,{Position=UDim2.new(1,10,0,0)},0.25)
    task.wait(0.25)
    SettingsPanel.Visible = false
    ConfirmPanel.Visible = false
end

SettingsBtn.MouseEnter:Connect(function() Tween(SettingsBtn,{BackgroundColor3=T.Hover},0.2) end)
SettingsBtn.MouseLeave:Connect(function() Tween(SettingsBtn,{BackgroundColor3=T.Surface},0.2) end)
SettingsBtn.MouseButton1Click:Connect(function()
    if settingsOpen then CloseSettings() else OpenSettings() end
end)
SPClose.MouseButton1Click:Connect(CloseSettings)
ConfirmNo.MouseButton1Click:Connect(function() ConfirmPanel.Visible = false end)
UnloadBtn.MouseButton1Click:Connect(function()
    ConfirmPanel.Visible = true
end)
ConfirmYes.MouseButton1Click:Connect(function()
    Running = false
    FlingActive = false
    for plr,_ in pairs(espDrawings) do
        pcall(function()
            for _,d in pairs(espDrawings[plr]) do d.Visible=false d:Remove() end
        end)
    end
    espDrawings = {}
    pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
    task.wait(0.1)
    Tween(Main,{Position=UDim2.new(0.5,-260,1.5,0)},0.4)
    task.wait(0.4)
    pcall(function() SG:Destroy() end)
    for _,gui in pairs(game.CoreGui:GetChildren()) do
        if gui.Name:find("HorrificUltimate") then pcall(function() gui:Destroy() end) end
    end
    print("✅ Скрипт выгружен!")
end)

-- ============================================================
-- TAB NAVIGATION
-- ============================================================
local TabNavContainer = Instance.new("Frame")
TabNavContainer.Size = UDim2.new(1,-40,0,45)
TabNavContainer.Position = UDim2.new(0,20,0,74)
TabNavContainer.BackgroundTransparency = 1
TabNavContainer.ZIndex = 11
TabNavContainer.Parent = Main

local LeftArrow = Instance.new("TextButton")
LeftArrow.Size = UDim2.new(0,38,0,38)
LeftArrow.Position = UDim2.new(0,0,0.5,-19)
LeftArrow.BackgroundColor3 = T.Surface
LeftArrow.Font = Enum.Font.GothamBlack
LeftArrow.Text = "◄"
LeftArrow.TextColor3 = T.Text
LeftArrow.TextSize = 15
LeftArrow.AutoButtonColor = false
LeftArrow.ZIndex = 12
LeftArrow.Parent = TabNavContainer
Corner(LeftArrow,19)

local TabDisplay = Instance.new("TextLabel")
TabDisplay.Size = UDim2.new(1,-96,0,38)
TabDisplay.Position = UDim2.new(0,48,0.5,-19)
TabDisplay.BackgroundColor3 = T.Primary
TabDisplay.Font = Enum.Font.GothamBlack
TabDisplay.Text = "COMBAT"
TabDisplay.TextColor3 = T.Dark
TabDisplay.TextSize = 14
TabDisplay.ZIndex = 12
TabDisplay.Parent = TabNavContainer
Corner(TabDisplay,19)

local RightArrow = Instance.new("TextButton")
RightArrow.Size = UDim2.new(0,38,0,38)
RightArrow.Position = UDim2.new(1,-38,0.5,-19)
RightArrow.BackgroundColor3 = T.Surface
RightArrow.Font = Enum.Font.GothamBlack
RightArrow.Text = "►"
RightArrow.TextColor3 = T.Text
RightArrow.TextSize = 15
RightArrow.AutoButtonColor = false
RightArrow.ZIndex = 12
RightArrow.Parent = TabNavContainer
Corner(RightArrow,19)

local TabIndicator = Instance.new("TextLabel")
TabIndicator.Size = UDim2.new(1,0,0,16)
TabIndicator.Position = UDim2.new(0,0,0,122)
TabIndicator.BackgroundTransparency = 1
TabIndicator.Font = Enum.Font.Gotham
TabIndicator.Text = "1 / 7  •  scroll to switch"
TabIndicator.TextColor3 = T.Muted
TabIndicator.TextSize = 10
TabIndicator.ZIndex = 12
TabIndicator.Parent = Main

local tabs = {"Combat", "Movement", "Fling", "Teleports", "Players", "ESP", "Misc"}
local TabContents = {}

for i, name in ipairs(tabs) do
    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1,-40,0,490)
    content.Position = UDim2.new(0,20,0,146)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = T.Muted
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.BorderSizePixel = 0
    content.ZIndex = 11
    content.Visible = i == 1
    content.Parent = Main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,8)
    layout.Parent = content

    TabContents[name] = content
end

local tabSwitching = false
local function SwitchTab(index)
    if tabSwitching then return end
    tabSwitching = true
    if index < 1 then index = #tabs end
    if index > #tabs then index = 1 end
    CurrentTabIndex = index
    local tabName = tabs[index]
    Tween(TabDisplay,{Position=UDim2.new(0,48,0.5,-40),TextTransparency=1},0.12)
    task.wait(0.12)
    TabDisplay.Text = tabName:upper()
    TabDisplay.Position = UDim2.new(0,48,0.5,10)
    Tween(TabDisplay,{Position=UDim2.new(0,48,0.5,-19),TextTransparency=0},0.12)
    TabIndicator.Text = index .. " / " .. #tabs .. "  •  scroll to switch"
    for name, content in pairs(TabContents) do
        content.Visible = name == tabName
    end
    task.wait(0.12)
    tabSwitching = false
end

Main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        if input.Position.Z > 0 then SwitchTab(CurrentTabIndex-1)
        else SwitchTab(CurrentTabIndex+1) end
    end
end)

LeftArrow.MouseEnter:Connect(function() Tween(LeftArrow,{BackgroundColor3=T.Hover},0.2) end)
LeftArrow.MouseLeave:Connect(function() Tween(LeftArrow,{BackgroundColor3=T.Surface},0.2) end)
LeftArrow.MouseButton1Click:Connect(function() SwitchTab(CurrentTabIndex-1) end)
RightArrow.MouseEnter:Connect(function() Tween(RightArrow,{BackgroundColor3=T.Hover},0.2) end)
RightArrow.MouseLeave:Connect(function() Tween(RightArrow,{BackgroundColor3=T.Surface},0.2) end)
RightArrow.MouseButton1Click:Connect(function() SwitchTab(CurrentTabIndex+1) end)

-- ============================================================
-- UI COMPONENTS
-- ============================================================
local function CreateSectionLabel(parent, text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,28)
    f.BackgroundColor3 = T.BG2
    f.BorderSizePixel = 0
    f.ZIndex = 12
    f.Parent = parent
    Corner(f,14)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-20,1,0)
    l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBold
    l.Text = text
    l.TextColor3 = T.Muted
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 13
    l.Parent = f
end

local function CreateToggle(parent, name, desc, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,62)
    frame.BackgroundColor3 = T.Surface
    frame.BorderSizePixel = 0
    frame.ZIndex = 12
    frame.Parent = parent
    Corner(frame,16)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7,0,0,20)
    label.Position = UDim2.new(0,15,0,11)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = name
    label.TextColor3 = T.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 13
    label.Parent = frame

    local desc2 = Instance.new("TextLabel")
    desc2.Size = UDim2.new(0.7,0,0,16)
    desc2.Position = UDim2.new(0,15,0,33)
    desc2.BackgroundTransparency = 1
    desc2.Font = Enum.Font.Gotham
    desc2.Text = desc
    desc2.TextColor3 = T.Muted
    desc2.TextSize = 10
    desc2.TextXAlignment = Enum.TextXAlignment.Left
    desc2.ZIndex = 13
    desc2.Parent = frame

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0,48,0,26)
    toggleBg.Position = UDim2.new(1,-62,0.5,-13)
    toggleBg.BackgroundColor3 = T.BG2
    toggleBg.BorderSizePixel = 0
    toggleBg.ZIndex = 13
    toggleBg.Parent = frame
    Corner(toggleBg,13)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,20,0,20)
    circle.Position = UDim2.new(0,3,0.5,-10)
    circle.BackgroundColor3 = T.Muted
    circle.BorderSizePixel = 0
    circle.ZIndex = 14
    circle.Parent = toggleBg
    Corner(circle,10)

    local enabled = false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = frame

    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        Tween(toggleBg,{BackgroundColor3=enabled and T.Primary or T.BG2},0.2)
        Tween(circle,{
            Position=enabled and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10),
            BackgroundColor3=enabled and T.Dark or T.Muted
        },0.2)
        callback(enabled)
    end)
end

local function CreateSlider(parent, name, min, max, def, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,72)
    frame.BackgroundColor3 = T.Surface
    frame.BorderSizePixel = 0
    frame.ZIndex = 12
    frame.Parent = parent
    Corner(frame,16)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7,0,0,20)
    label.Position = UDim2.new(0,15,0,9)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = name
    label.TextColor3 = T.Text
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 13
    label.Parent = frame

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(0,52,0,20)
    value.Position = UDim2.new(1,-67,0,9)
    value.BackgroundTransparency = 1
    value.Font = Enum.Font.GothamBold
    value.Text = tostring(def)
    value.TextColor3 = T.Primary
    value.TextSize = 13
    value.ZIndex = 13
    value.Parent = frame

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,-30,0,8)
    bar.Position = UDim2.new(0,15,0,42)
    bar.BackgroundColor3 = T.BG2
    bar.BorderSizePixel = 0
    bar.ZIndex = 13
    bar.Parent = frame
    Corner(bar,4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = T.Primary
    fill.BorderSizePixel = 0
    fill.ZIndex = 14
    fill.Parent = bar
    Corner(fill,4)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = bar

    local dragging = false
    btn.MouseButton1Down:Connect(function() dragging = true end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local pos = (i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            pos = math.clamp(pos,0,1)
            local val = math.floor(min+(max-min)*pos)
            fill.Size = UDim2.new(pos,0,1,0)
            value.Text = tostring(val)
            callback(val)
        end
    end)
end

local function CreateButton(parent, name, desc, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,0,52)
    frame.BackgroundColor3 = T.Surface
    frame.BorderSizePixel = 0
    frame.ZIndex = 12
    frame.Parent = parent
    Corner(frame,16)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.62,0,1,0)
    label.Position = UDim2.new(0,15,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.Text = name
    label.TextColor3 = T.Text
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 13
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,100,0,34)
    btn.Position = UDim2.new(1,-112,0.5,-17)
    btn.BackgroundColor3 = T.Primary
    btn.Font = Enum.Font.GothamBlack
    btn.Text = "EXECUTE"
    btn.TextColor3 = T.Dark
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.ZIndex = 14
    btn.Parent = frame
    Corner(btn,17)

    btn.MouseButton1Click:Connect(function()
        Tween(btn,{BackgroundColor3=Color3.fromRGB(210,210,210)},0.1)
        task.wait(0.1)
        Tween(btn,{BackgroundColor3=T.Primary},0.1)
        callback()
    end)
end

-- ============================================================
-- ESP SYSTEM
-- ============================================================
local function removeESP(plr)
    if espDrawings[plr] then
        for _,d in pairs(espDrawings[plr]) do
            pcall(function() d.Visible=false d:Remove() end)
        end
        espDrawings[plr] = nil
    end
end

local function createESP(plr)
    if espDrawings[plr] then return end
    local box=Drawing.new("Square")
    local nameTag=Drawing.new("Text")
    local distTag=Drawing.new("Text")
    local hpBg=Drawing.new("Square")
    local hpFill=Drawing.new("Square")
    box.Thickness=1 box.Filled=false box.Visible=false box.Color=Color3.fromRGB(255,255,255)
    nameTag.Size=13 nameTag.Center=true nameTag.Outline=true
    nameTag.OutlineColor=Color3.fromRGB(0,0,0) nameTag.Color=Color3.fromRGB(255,255,255) nameTag.Visible=false
    distTag.Size=11 distTag.Center=true distTag.Outline=true
    distTag.OutlineColor=Color3.fromRGB(0,0,0) distTag.Color=Color3.fromRGB(200,200,200) distTag.Visible=false
    hpBg.Thickness=0 hpBg.Filled=true hpBg.Visible=false hpBg.Color=Color3.fromRGB(20,20,20)
    hpFill.Thickness=0 hpFill.Filled=true hpFill.Visible=false hpFill.Color=Color3.fromRGB(80,255,80)
    espDrawings[plr]={box=box,name=nameTag,distance=distTag,hpBg=hpBg,hpFill=hpFill}
end

local function updateESP()
    if not State.ESP then
        for plr,_ in pairs(espDrawings) do removeESP(plr) end
        return
    end
    local validPlayers={}
    for _,plr in ipairs(Players:GetPlayers()) do validPlayers[plr]=true end
    for plr,_ in pairs(espDrawings) do
        if not validPlayers[plr] then removeESP(plr) end
    end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LP then continue end
        local char=plr.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local head=char and char:FindFirstChild("Head")
        if not char or not hum or not root or not head or hum.Health<=0 then removeESP(plr) continue end
        if not espDrawings[plr] then createESP(plr) end
        local d=espDrawings[plr]
        if not d then continue end
        local rootVP,onScreen=Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local headVP=Camera:WorldToViewportPoint(head.Position+Vector3.new(0,0.6,0))
            local footVP=Camera:WorldToViewportPoint(root.Position-Vector3.new(0,3.1,0))
            local height=math.abs(footVP.Y-headVP.Y)
            local width=height*0.5
            local boxX=rootVP.X-width/2
            local boxY=headVP.Y
            d.box.Size=Vector2.new(width,height) d.box.Position=Vector2.new(boxX,boxY) d.box.Visible=true
            d.name.Text=plr.DisplayName d.name.Position=Vector2.new(rootVP.X,boxY-16) d.name.Visible=true
            local dist=(Camera.CFrame.Position-root.Position).Magnitude
            d.distance.Text=string.format("%.0fm",dist)
            d.distance.Position=Vector2.new(rootVP.X,footVP.Y+3) d.distance.Visible=true
            local barW=4 local barH=height local barX=boxX-barW-2 local barY=boxY
            d.hpBg.Size=Vector2.new(barW,barH) d.hpBg.Position=Vector2.new(barX,barY) d.hpBg.Visible=true
            local maxHp=hum.MaxHealth>0 and hum.MaxHealth or 100
            local hpFrac=math.clamp(hum.Health/maxHp,0,1)
            local fillH=math.max(1,barH*hpFrac)
            local fillY=barY+(barH-fillH)
            local col=lerpColor(Color3.fromRGB(255,60,60),Color3.fromRGB(80,255,80),hpFrac)
            d.hpFill.Size=Vector2.new(barW,fillH) d.hpFill.Position=Vector2.new(barX,fillY)
            d.hpFill.Color=col d.hpFill.Visible=true
        else
            d.box.Visible=false d.name.Visible=false d.distance.Visible=false
            d.hpBg.Visible=false d.hpFill.Visible=false
        end
    end
end

-- ============================================================
-- FLING TAB
-- ============================================================

-- Статус строка
local flingStatusFrame = Instance.new("Frame")
flingStatusFrame.Size = UDim2.new(1,0,0,36)
flingStatusFrame.BackgroundColor3 = Color3.fromRGB(15,15,15)
flingStatusFrame.BorderSizePixel = 0
flingStatusFrame.ZIndex = 12
flingStatusFrame.Parent = TabContents.Fling
Corner(flingStatusFrame,16)
Stroke(flingStatusFrame,T.Border,1)

local flingStatusText = Instance.new("TextLabel")
flingStatusText.Size = UDim2.new(1,-20,1,0)
flingStatusText.Position = UDim2.new(0,12,0,0)
flingStatusText.BackgroundTransparency = 1
flingStatusText.Font = Enum.Font.GothamBold
flingStatusText.Text = "Выбери цели и нажми START"
flingStatusText.TextColor3 = T.Muted
flingStatusText.TextSize = 11
flingStatusText.TextXAlignment = Enum.TextXAlignment.Left
flingStatusText.ZIndex = 13
flingStatusText.Parent = flingStatusFrame

-- START / STOP кнопки
local flingBtnRow = Instance.new("Frame")
flingBtnRow.Size = UDim2.new(1,0,0,44)
flingBtnRow.BackgroundTransparency = 1
flingBtnRow.ZIndex = 12
flingBtnRow.Parent = TabContents.Fling

local flingRowLayout = Instance.new("UIListLayout")
flingRowLayout.FillDirection = Enum.FillDirection.Horizontal
flingRowLayout.Padding = UDim.new(0,8)
flingRowLayout.Parent = flingBtnRow

local StartFlingBtn = Instance.new("TextButton")
StartFlingBtn.Size = UDim2.new(0.5,-4,0,44)
StartFlingBtn.BackgroundColor3 = Color3.fromRGB(0,160,0)
StartFlingBtn.Font = Enum.Font.GothamBlack
StartFlingBtn.Text = "▶  START FLING"
StartFlingBtn.TextColor3 = Color3.fromRGB(255,255,255)
StartFlingBtn.TextSize = 13
StartFlingBtn.AutoButtonColor = false
StartFlingBtn.ZIndex = 13
StartFlingBtn.Parent = flingBtnRow
Corner(StartFlingBtn,16)

local StopFlingBtn = Instance.new("TextButton")
StopFlingBtn.Size = UDim2.new(0.5,-4,0,44)
StopFlingBtn.BackgroundColor3 = Color3.fromRGB(160,0,0)
StopFlingBtn.Font = Enum.Font.GothamBlack
StopFlingBtn.Text = "■  STOP FLING"
StopFlingBtn.TextColor3 = Color3.fromRGB(255,255,255)
StopFlingBtn.TextSize = 13
StopFlingBtn.AutoButtonColor = false
StopFlingBtn.ZIndex = 13
StopFlingBtn.Parent = flingBtnRow
Corner(StopFlingBtn,16)

-- FLING ONE / FLING ALL
local flingActionRow = Instance.new("Frame")
flingActionRow.Size = UDim2.new(1,0,0,44)
flingActionRow.BackgroundTransparency = 1
flingActionRow.ZIndex = 12
flingActionRow.Parent = TabContents.Fling

local flingActionLayout = Instance.new("UIListLayout")
flingActionLayout.FillDirection = Enum.FillDirection.Horizontal
flingActionLayout.Padding = UDim.new(0,8)
flingActionLayout.Parent = flingActionRow

local FlingOneBtn = Instance.new("TextButton")
FlingOneBtn.Size = UDim2.new(0.5,-4,0,44)
FlingOneBtn.BackgroundColor3 = Color3.fromRGB(40,20,20)
FlingOneBtn.Font = Enum.Font.GothamBlack
FlingOneBtn.Text = "⚡ FLING TARGET"
FlingOneBtn.TextColor3 = T.Danger
FlingOneBtn.TextSize = 12
FlingOneBtn.AutoButtonColor = false
FlingOneBtn.ZIndex = 13
FlingOneBtn.Parent = flingActionRow
Corner(FlingOneBtn,16)
Stroke(FlingOneBtn, Color3.fromRGB(100,30,30), 1)

local FlingAllBtn = Instance.new("TextButton")
FlingAllBtn.Size = UDim2.new(0.5,-4,0,44)
FlingAllBtn.BackgroundColor3 = Color3.fromRGB(40,10,10)
FlingAllBtn.Font = Enum.Font.GothamBlack
FlingAllBtn.Text = "💥 FLING ALL"
FlingAllBtn.TextColor3 = Color3.fromRGB(255,100,100)
FlingAllBtn.TextSize = 12
FlingAllBtn.AutoButtonColor = false
FlingAllBtn.ZIndex = 13
FlingAllBtn.Parent = flingActionRow
Corner(FlingAllBtn,16)
Stroke(FlingAllBtn, Color3.fromRGB(150,20,20), 1)

-- Выбранная цель (для FLING TARGET)
local selectedTargetFrame = Instance.new("Frame")
selectedTargetFrame.Size = UDim2.new(1,0,0,40)
selectedTargetFrame.BackgroundColor3 = Color3.fromRGB(25,20,8)
selectedTargetFrame.BorderSizePixel = 0
selectedTargetFrame.ZIndex = 12
selectedTargetFrame.Parent = TabContents.Fling
Corner(selectedTargetFrame,14)
Stroke(selectedTargetFrame, Color3.fromRGB(80,65,15), 1)

local selectedTargetText = Instance.new("TextLabel")
selectedTargetText.Size = UDim2.new(1,-20,1,0)
selectedTargetText.Position = UDim2.new(0,12,0,0)
selectedTargetText.BackgroundTransparency = 1
selectedTargetText.Font = Enum.Font.GothamBold
selectedTargetText.Text = "🎯 Цель: не выбрана"
selectedTargetText.TextColor3 = T.Selected
selectedTargetText.TextSize = 12
selectedTargetText.TextXAlignment = Enum.TextXAlignment.Left
selectedTargetText.ZIndex = 13
selectedTargetText.Parent = selectedTargetFrame

-- SELECT ALL / DESELECT ALL
local selBtnRow = Instance.new("Frame")
selBtnRow.Size = UDim2.new(1,0,0,34)
selBtnRow.BackgroundTransparency = 1
selBtnRow.ZIndex = 12
selBtnRow.Parent = TabContents.Fling

local selBtnLayout = Instance.new("UIListLayout")
selBtnLayout.FillDirection = Enum.FillDirection.Horizontal
selBtnLayout.Padding = UDim.new(0,8)
selBtnLayout.Parent = selBtnRow

local SelectAllBtn = Instance.new("TextButton")
SelectAllBtn.Size = UDim2.new(0.5,-4,0,34)
SelectAllBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
SelectAllBtn.Font = Enum.Font.GothamBold
SelectAllBtn.Text = "☑ SELECT ALL"
SelectAllBtn.TextColor3 = T.Text
SelectAllBtn.TextSize = 11
SelectAllBtn.AutoButtonColor = false
SelectAllBtn.ZIndex = 13
SelectAllBtn.Parent = selBtnRow
Corner(SelectAllBtn,16)

local DeselectAllBtn = Instance.new("TextButton")
DeselectAllBtn.Size = UDim2.new(0.5,-4,0,34)
DeselectAllBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
DeselectAllBtn.Font = Enum.Font.GothamBold
DeselectAllBtn.Text = "☐ DESELECT ALL"
DeselectAllBtn.TextColor3 = T.Muted
DeselectAllBtn.TextSize = 11
DeselectAllBtn.AutoButtonColor = false
DeselectAllBtn.ZIndex = 13
DeselectAllBtn.Parent = selBtnRow
Corner(DeselectAllBtn,16)

CreateSectionLabel(TabContents.Fling, "👥 Список игроков (нажми чтобы выбрать):")

-- СПИСОК ИГРОКОВ для флинга
local flingPlayerContainer = Instance.new("Frame")
flingPlayerContainer.Size = UDim2.new(1,0,0,0)
flingPlayerContainer.BackgroundTransparency = 1
flingPlayerContainer.ZIndex = 12
flingPlayerContainer.AutomaticSize = Enum.AutomaticSize.Y
flingPlayerContainer.Parent = TabContents.Fling

local flingPlayerLayout = Instance.new("UIListLayout")
flingPlayerLayout.Padding = UDim.new(0,5)
flingPlayerLayout.Parent = flingPlayerContainer

local flingRefreshBtn = Instance.new("TextButton")
flingRefreshBtn.Size = UDim2.new(1,0,0,32)
flingRefreshBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
flingRefreshBtn.Font = Enum.Font.GothamBold
flingRefreshBtn.Text = "🔄  Обновить список"
flingRefreshBtn.TextColor3 = T.Muted
flingRefreshBtn.TextSize = 11
flingRefreshBtn.AutoButtonColor = false
flingRefreshBtn.ZIndex = 12
flingRefreshBtn.Parent = TabContents.Fling
Corner(flingRefreshBtn,14)

-- Checkboxes хранилище
local flingCheckboxes = {} -- [playerName] = checkmarkLabel
local flingPlayerBtns = {}

local function RefreshFlingPlayerList()
    for _, b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end
    flingPlayerBtns = {}
    flingCheckboxes = {}

    local allPlayers = Players:GetPlayers()
    table.sort(allPlayers, function(a,b) return a.Name:lower() < b.Name:lower() end)

    for _, plr in ipairs(allPlayers) do
        if plr ~= LP then
            local isChecked = SelectedTargets[plr.Name] ~= nil
            local isTarget = SelectedFlingTarget == plr

            local pFrame = Instance.new("Frame")
            pFrame.Size = UDim2.new(1,0,0,48)
            pFrame.BackgroundColor3 = isChecked and Color3.fromRGB(25,35,15) or T.Surface
            pFrame.BorderSizePixel = 0
            pFrame.ZIndex = 13
            pFrame.Parent = flingPlayerContainer
            Corner(pFrame,14)
            if isChecked then Stroke(pFrame, Color3.fromRGB(50,120,20), 1)
            elseif isTarget then Stroke(pFrame, Color3.fromRGB(120,100,20), 1) end

            -- Checkbox квадрат
            local cbBg = Instance.new("Frame")
            cbBg.Size = UDim2.new(0,26,0,26)
            cbBg.Position = UDim2.new(0,8,0.5,-13)
            cbBg.BackgroundColor3 = isChecked and Color3.fromRGB(0,160,0) or Color3.fromRGB(40,40,40)
            cbBg.BorderSizePixel = 0
            cbBg.ZIndex = 14
            cbBg.Parent = pFrame
            Corner(cbBg,8)

            local cbMark = Instance.new("TextLabel")
            cbMark.Size = UDim2.new(1,0,1,0)
            cbMark.BackgroundTransparency = 1
            cbMark.Font = Enum.Font.GothamBlack
            cbMark.Text = isChecked and "✓" or ""
            cbMark.TextColor3 = Color3.fromRGB(255,255,255)
            cbMark.TextSize = 14
            cbMark.ZIndex = 15
            cbMark.Parent = cbBg

            -- Аватар цвет
            local av = Instance.new("Frame")
            av.Size = UDim2.new(0,32,0,32)
            av.Position = UDim2.new(0,42,0.5,-16)
            av.BackgroundColor3 = Color3.fromHSV((plr.UserId%100)/100, 0.7, 0.9)
            av.BorderSizePixel = 0
            av.ZIndex = 14
            av.Parent = pFrame
            Corner(av,16)

            local avL = Instance.new("TextLabel")
            avL.Size = UDim2.new(1,0,1,0)
            avL.BackgroundTransparency = 1
            avL.Font = Enum.Font.GothamBlack
            avL.Text = string.upper(string.sub(plr.Name,1,1))
            avL.TextColor3 = Color3.fromRGB(255,255,255)
            avL.TextSize = 15
            avL.ZIndex = 15
            avL.Parent = av

            -- DisplayName
            local dnL = Instance.new("TextLabel")
            dnL.Size = UDim2.new(1,-90,0,20)
            dnL.Position = UDim2.new(0,82,0,5)
            dnL.BackgroundTransparency = 1
            dnL.Font = Enum.Font.GothamBold
            dnL.Text = plr.DisplayName
            dnL.TextColor3 = isChecked and T.Green or (isTarget and T.Selected or T.Text)
            dnL.TextSize = 13
            dnL.TextXAlignment = Enum.TextXAlignment.Left
            dnL.ZIndex = 14
            dnL.Parent = pFrame

            -- Username
            local unL = Instance.new("TextLabel")
            unL.Size = UDim2.new(1,-90,0,14)
            unL.Position = UDim2.new(0,82,0,25)
            unL.BackgroundTransparency = 1
            unL.Font = Enum.Font.Gotham
            unL.Text = "@" .. plr.Name
            unL.TextColor3 = T.Muted
            unL.TextSize = 10
            unL.TextXAlignment = Enum.TextXAlignment.Left
            unL.ZIndex = 14
            unL.Parent = pFrame

            -- Кнопка "Цель" (для одиночного флинга)
            local targetBtn = Instance.new("TextButton")
            targetBtn.Size = UDim2.new(0,52,0,30)
            targetBtn.Position = UDim2.new(1,-60,0.5,-15)
            targetBtn.BackgroundColor3 = isTarget and T.Selected or Color3.fromRGB(35,35,35)
            targetBtn.Font = Enum.Font.GothamBlack
            targetBtn.Text = "🎯"
            targetBtn.TextSize = 14
            targetBtn.TextColor3 = Color3.fromRGB(255,255,255)
            targetBtn.AutoButtonColor = false
            targetBtn.ZIndex = 15
            targetBtn.Parent = pFrame
            Corner(targetBtn,15)

            flingCheckboxes[plr.Name] = {mark=cbMark, bg=cbBg, frame=pFrame, dispName=dnL, targetBtn=targetBtn}

            local capturedPlr = plr

            -- Клик по строке = переключить чекбокс (для мульти START/STOP)
            local clickArea = Instance.new("TextButton")
            clickArea.Size = UDim2.new(1,-70,1,0)
            clickArea.BackgroundTransparency = 1
            clickArea.Text = ""
            clickArea.ZIndex = 16
            clickArea.Parent = pFrame

            clickArea.MouseButton1Click:Connect(function()
                if SelectedTargets[capturedPlr.Name] then
                    SelectedTargets[capturedPlr.Name] = nil
                    Tween(cbBg,{BackgroundColor3=Color3.fromRGB(40,40,40)},0.15)
                    cbMark.Text = ""
                    Tween(pFrame,{BackgroundColor3=T.Surface},0.15)
                    dnL.TextColor3 = T.Text
                else
                    SelectedTargets[capturedPlr.Name] = capturedPlr
                    Tween(cbBg,{BackgroundColor3=Color3.fromRGB(0,160,0)},0.15)
                    cbMark.Text = "✓"
                    Tween(pFrame,{BackgroundColor3=Color3.fromRGB(25,35,15)},0.15)
                    dnL.TextColor3 = T.Green
                end

                local count = 0
                for _ in pairs(SelectedTargets) do count = count + 1 end
                if not FlingActive then
                    flingStatusText.Text = count .. " цел(ей) выбрано"
                    flingStatusText.TextColor3 = T.Muted
                end
            end)

            -- Кнопка 🎯 = установить как одиночную цель для FLING TARGET
            targetBtn.MouseButton1Click:Connect(function()
                if SelectedFlingTarget == capturedPlr then
                    SelectedFlingTarget = nil
                    selectedTargetText.Text = "🎯 Цель: не выбрана"
                    Tween(targetBtn,{BackgroundColor3=Color3.fromRGB(35,35,35)},0.15)
                else
                    -- Снимаем предыдущую цель
                    local prev = flingCheckboxes
                    for _, data in pairs(prev) do
                        if data ~= flingCheckboxes[capturedPlr.Name] then
                            Tween(data.targetBtn,{BackgroundColor3=Color3.fromRGB(35,35,35)},0.15)
                        end
                    end
                    SelectedFlingTarget = capturedPlr
                    selectedTargetText.Text = "🎯 " .. capturedPlr.DisplayName .. " (@" .. capturedPlr.Name .. ")"
                    Tween(targetBtn,{BackgroundColor3=T.Selected},0.15)
                end
            end)

            table.insert(flingPlayerBtns, pFrame)
        end
    end

    if #flingPlayerBtns == 0 then
        local emptyL = Instance.new("TextLabel")
        emptyL.Size = UDim2.new(1,0,0,35)
        emptyL.BackgroundTransparency = 1
        emptyL.Font = Enum.Font.Gotham
        emptyL.Text = "Нет других игроков"
        emptyL.TextColor3 = T.Muted
        emptyL.TextSize = 12
        emptyL.ZIndex = 12
        emptyL.Parent = flingPlayerContainer
        table.insert(flingPlayerBtns, emptyL)
    end
end

-- Кнопки START / STOP
StartFlingBtn.MouseButton1Click:Connect(function()
    StartMultiFling(flingStatusText, flingCheckboxes)
end)

StopFlingBtn.MouseButton1Click:Connect(function()
    StopMultiFling()
    flingStatusText.Text = "Остановлено"
    flingStatusText.TextColor3 = T.Muted
end)

-- FLING TARGET (одиночный, одноразовый)
FlingOneBtn.MouseButton1Click:Connect(function()
    if SelectedFlingTarget and SelectedFlingTarget.Character then
        Tween(FlingOneBtn,{BackgroundColor3=Color3.fromRGB(70,20,20)},0.1)
        FlingTarget(SelectedFlingTarget)
        task.wait(0.2)
        Tween(FlingOneBtn,{BackgroundColor3=Color3.fromRGB(40,20,20)},0.15)
    else
        Tween(selectedTargetFrame,{BackgroundColor3=Color3.fromRGB(50,15,15)},0.1)
        task.wait(0.25)
        Tween(selectedTargetFrame,{BackgroundColor3=Color3.fromRGB(25,20,8)},0.2)
    end
end)

-- FLING ALL (одноразовый)
FlingAllBtn.MouseButton1Click:Connect(function()
    Tween(FlingAllBtn,{BackgroundColor3=Color3.fromRGB(70,10,10)},0.1)
    task.spawn(FlingAll)
    task.wait(0.2)
    Tween(FlingAllBtn,{BackgroundColor3=Color3.fromRGB(40,10,10)},0.15)
end)

-- SELECT ALL / DESELECT ALL
SelectAllBtn.MouseButton1Click:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            SelectedTargets[plr.Name] = plr
            local cb = flingCheckboxes[plr.Name]
            if cb then
                cb.bg.BackgroundColor3 = Color3.fromRGB(0,160,0)
                cb.mark.Text = "✓"
                cb.frame.BackgroundColor3 = Color3.fromRGB(25,35,15)
                cb.dispName.TextColor3 = T.Green
            end
        end
    end
    local count = 0
    for _ in pairs(SelectedTargets) do count = count + 1 end
    flingStatusText.Text = count .. " цел(ей) выбрано"
end)

DeselectAllBtn.MouseButton1Click:Connect(function()
    SelectedTargets = {}
    for _, cb in pairs(flingCheckboxes) do
        cb.bg.BackgroundColor3 = Color3.fromRGB(40,40,40)
        cb.mark.Text = ""
        cb.frame.BackgroundColor3 = T.Surface
        cb.dispName.TextColor3 = T.Text
    end
    flingStatusText.Text = "Выбери цели и нажми START"
    flingStatusText.TextColor3 = T.Muted
end)

flingRefreshBtn.MouseButton1Click:Connect(function()
    RefreshFlingPlayerList()
end)

-- ============================================================
-- TELEPORTS TAB
-- ============================================================
CreateSectionLabel(TabContents.Teleports, "📍 Основные места:")

local teleportLocations = {
    {name="🏠 Spawn / Лобби",      desc="Начальная точка",             pos=CFrame.new(0,50,0)},
    {name="🏁 Финиш Оббика",       desc="Конец паркура",               pos=CFrame.new(65,128.95,-119.5)},
    {name="💎 Illumina",            desc="Место спауна Illumina",       pos=CFrame.new(-120,80,45)},
    {name="☁️ Облака",             desc="Высокая точка карты",          pos=CFrame.new(0,250,0)},
    {name="🌑 Подземелье",         desc="Нижний уровень",              pos=CFrame.new(30,-20,30)},
    {name="🌋 Лава-зона",          desc="Опасная лавовая область",     pos=CFrame.new(80,30,120)},
    {name="❄️ Ледяная зона",       desc="Лёд и сосульки",              pos=CFrame.new(-80,50,-150)},
    {name="🎯 Секретная комната",   desc="Скрытая область",             pos=CFrame.new(150,70,80)},
}

for _, tp in ipairs(teleportLocations) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,0,52)
    f.BackgroundColor3 = T.Surface
    f.BorderSizePixel = 0
    f.ZIndex = 12
    f.Parent = TabContents.Teleports
    Corner(f,16)

    local nL = Instance.new("TextLabel")
    nL.Size = UDim2.new(0.6,0,0,22)
    nL.Position = UDim2.new(0,15,0,6)
    nL.BackgroundTransparency = 1
    nL.Font = Enum.Font.GothamBold
    nL.Text = tp.name
    nL.TextColor3 = T.Text
    nL.TextSize = 12
    nL.TextXAlignment = Enum.TextXAlignment.Left
    nL.ZIndex = 13
    nL.Parent = f

    local dL = Instance.new("TextLabel")
    dL.Size = UDim2.new(0.6,0,0,16)
    dL.Position = UDim2.new(0,15,0,28)
    dL.BackgroundTransparency = 1
    dL.Font = Enum.Font.Gotham
    dL.Text = tp.desc
    dL.TextColor3 = T.Muted
    dL.TextSize = 10
    dL.TextXAlignment = Enum.TextXAlignment.Left
    dL.ZIndex = 13
    dL.Parent = f

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0,100,0,34)
    tpBtn.Position = UDim2.new(1,-112,0.5,-17)
    tpBtn.BackgroundColor3 = T.Blue
    tpBtn.Font = Enum.Font.GothamBlack
    tpBtn.Text = "📍 ТП"
    tpBtn.TextColor3 = Color3.fromRGB(255,255,255)
    tpBtn.TextSize = 12
    tpBtn.AutoButtonColor = false
    tpBtn.ZIndex = 14
    tpBtn.Parent = f
    Corner(tpBtn,17)

    tpBtn.MouseEnter:Connect(function() Tween(tpBtn,{BackgroundColor3=Color3.fromRGB(50,130,220)},0.2) end)
    tpBtn.MouseLeave:Connect(function() Tween(tpBtn,{BackgroundColor3=T.Blue},0.2) end)

    local capturedTp = tp
    tpBtn.MouseButton1Click:Connect(function()
        Tween(tpBtn,{BackgroundColor3=Color3.fromRGB(30,100,180)},0.1)
        pcall(function() HRP.CFrame = capturedTp.pos end)
        task.wait(0.2)
        Tween(tpBtn,{BackgroundColor3=T.Blue},0.15)
    end)
end

CreateSectionLabel(TabContents.Teleports, "👤 Телепорт к игроку:")

local tpPlayerContainer = Instance.new("Frame")
tpPlayerContainer.Size = UDim2.new(1,0,0,0)
tpPlayerContainer.BackgroundTransparency = 1
tpPlayerContainer.ZIndex = 12
tpPlayerContainer.AutomaticSize = Enum.AutomaticSize.Y
tpPlayerContainer.Parent = TabContents.Teleports

local tpPlayerLayout = Instance.new("UIListLayout")
tpPlayerLayout.Padding = UDim.new(0,5)
tpPlayerLayout.Parent = tpPlayerContainer

local tpRefreshBtn = Instance.new("TextButton")
tpRefreshBtn.Size = UDim2.new(1,0,0,32)
tpRefreshBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
tpRefreshBtn.Font = Enum.Font.GothamBold
tpRefreshBtn.Text = "🔄  Обновить"
tpRefreshBtn.TextColor3 = T.Muted
tpRefreshBtn.TextSize = 11
tpRefreshBtn.AutoButtonColor = false
tpRefreshBtn.ZIndex = 12
tpRefreshBtn.Parent = TabContents.Teleports
Corner(tpRefreshBtn,14)

local tpPlayerBtns = {}

local function RefreshTpPlayerList()
    for _,b in pairs(tpPlayerBtns) do pcall(function() b:Destroy() end) end
    tpPlayerBtns = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1,0,0,48)
            f.BackgroundColor3 = T.Surface
            f.BorderSizePixel = 0
            f.ZIndex = 12
            f.Parent = tpPlayerContainer
            Corner(f,14)

            local av = Instance.new("Frame")
            av.Size = UDim2.new(0,30,0,30)
            av.Position = UDim2.new(0,8,0.5,-15)
            av.BackgroundColor3 = Color3.fromHSV((plr.UserId%100)/100,0.7,0.9)
            av.BorderSizePixel = 0
            av.ZIndex = 13
            av.Parent = f
            Corner(av,15)

            local avL = Instance.new("TextLabel")
            avL.Size = UDim2.new(1,0,1,0)
            avL.BackgroundTransparency = 1
            avL.Font = Enum.Font.GothamBlack
            avL.Text = string.upper(string.sub(plr.Name,1,1))
            avL.TextColor3 = Color3.fromRGB(255,255,255)
            avL.TextSize = 14
            avL.ZIndex = 14
            avL.Parent = av

            local dnL = Instance.new("TextLabel")
            dnL.Size = UDim2.new(1,-130,0,20)
            dnL.Position = UDim2.new(0,46,0,5)
            dnL.BackgroundTransparency = 1
            dnL.Font = Enum.Font.GothamBold
            dnL.Text = plr.DisplayName
            dnL.TextColor3 = T.Text
            dnL.TextSize = 12
            dnL.TextXAlignment = Enum.TextXAlignment.Left
            dnL.ZIndex = 13
            dnL.Parent = f

            local unL = Instance.new("TextLabel")
            unL.Size = UDim2.new(1,-130,0,14)
            unL.Position = UDim2.new(0,46,0,24)
            unL.BackgroundTransparency = 1
            unL.Font = Enum.Font.Gotham
            unL.Text = "@"..plr.Name
            unL.TextColor3 = T.Muted
            unL.TextSize = 10
            unL.TextXAlignment = Enum.TextXAlignment.Left
            unL.ZIndex = 13
            unL.Parent = f

            local tpB = Instance.new("TextButton")
            tpB.Size = UDim2.new(0,110,0,32)
            tpB.Position = UDim2.new(1,-118,0.5,-16)
            tpB.BackgroundColor3 = T.Blue
            tpB.Font = Enum.Font.GothamBlack
            tpB.Text = "📍 ТП к нему"
            tpB.TextColor3 = Color3.fromRGB(255,255,255)
            tpB.TextSize = 10
            tpB.AutoButtonColor = false
            tpB.ZIndex = 14
            tpB.Parent = f
            Corner(tpB,16)

            tpB.MouseEnter:Connect(function() Tween(tpB,{BackgroundColor3=Color3.fromRGB(50,130,220)},0.2) end)
            tpB.MouseLeave:Connect(function() Tween(tpB,{BackgroundColor3=T.Blue},0.2) end)

            local capturedPlr = plr
            tpB.MouseButton1Click:Connect(function()
                pcall(function()
                    local tc = capturedPlr.Character
                    if tc and tc:FindFirstChild("HumanoidRootPart") then
                        HRP.CFrame = tc.HumanoidRootPart.CFrame * CFrame.new(0,0,-3)
                    end
                end)
            end)

            table.insert(tpPlayerBtns, f)
        end
    end
    if #tpPlayerBtns == 0 then
        local eL = Instance.new("TextLabel")
        eL.Size = UDim2.new(1,0,0,35)
        eL.BackgroundTransparency = 1
        eL.Font = Enum.Font.Gotham
        eL.Text = "Нет других игроков"
        eL.TextColor3 = T.Muted
        eL.TextSize = 12
        eL.ZIndex = 12
        eL.Parent = tpPlayerContainer
        table.insert(tpPlayerBtns, eL)
    end
end

tpRefreshBtn.MouseButton1Click:Connect(RefreshTpPlayerList)

-- ============================================================
-- PLAYERS TAB
-- ============================================================
CreateSectionLabel(TabContents.Players, "👥 Все игроки на сервере:")

local allPlayersContainer = Instance.new("Frame")
allPlayersContainer.Size = UDim2.new(1,0,0,0)
allPlayersContainer.BackgroundTransparency = 1
allPlayersContainer.ZIndex = 12
allPlayersContainer.AutomaticSize = Enum.AutomaticSize.Y
allPlayersContainer.Parent = TabContents.Players

local allPlayersLayout = Instance.new("UIListLayout")
allPlayersLayout.Padding = UDim.new(0,6)
allPlayersLayout.Parent = allPlayersContainer

local playersRefreshBtn = Instance.new("TextButton")
playersRefreshBtn.Size = UDim2.new(1,0,0,32)
playersRefreshBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
playersRefreshBtn.Font = Enum.Font.GothamBold
playersRefreshBtn.Text = "🔄  Обновить список"
playersRefreshBtn.TextColor3 = T.Muted
playersRefreshBtn.TextSize = 11
playersRefreshBtn.AutoButtonColor = false
playersRefreshBtn.ZIndex = 12
playersRefreshBtn.Parent = TabContents.Players
Corner(playersRefreshBtn,14)

local playerCards = {}

local function RefreshPlayersTab()
    for _,b in pairs(playerCards) do pcall(function() b:Destroy() end) end
    playerCards = {}

    local allPlrs = Players:GetPlayers()
    table.sort(allPlrs, function(a,b) return a.Name:lower()<b.Name:lower() end)

    for _, plr in ipairs(allPlrs) do
        local isMe = plr == LP
        local char = plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hp = hum and math.floor(hum.Health) or 0
        local maxHp = hum and math.floor(hum.MaxHealth) or 100

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1,0,0,72)
        card.BackgroundColor3 = isMe and Color3.fromRGB(12,18,12) or T.Surface
        card.BorderSizePixel = 0
        card.ZIndex = 12
        card.Parent = allPlayersContainer
        Corner(card,16)
        if isMe then Stroke(card,Color3.fromRGB(40,100,40),1) end

        local avF = Instance.new("Frame")
        avF.Size = UDim2.new(0,44,0,44)
        avF.Position = UDim2.new(0,10,0.5,-22)
        avF.BackgroundColor3 = Color3.fromHSV((plr.UserId%100)/100,0.7,0.9)
        avF.BorderSizePixel = 0
        avF.ZIndex = 13
        avF.Parent = card
        Corner(avF,22)

        local avT = Instance.new("TextLabel")
        avT.Size = UDim2.new(1,0,1,0)
        avT.BackgroundTransparency = 1
        avT.Font = Enum.Font.GothamBlack
        avT.Text = string.upper(string.sub(plr.Name,1,1))
        avT.TextColor3 = Color3.fromRGB(255,255,255)
        avT.TextSize = 20
        avT.ZIndex = 14
        avT.Parent = avF

        if isMe then
            local meTag = Instance.new("Frame")
            meTag.Size = UDim2.new(0,26,0,14)
            meTag.Position = UDim2.new(0,28,0,0)
            meTag.BackgroundColor3 = T.Green
            meTag.BorderSizePixel = 0
            meTag.ZIndex = 15
            meTag.Parent = avF
            Corner(meTag,7)
            local meText = Instance.new("TextLabel")
            meText.Size = UDim2.new(1,0,1,0)
            meText.BackgroundTransparency = 1
            meText.Font = Enum.Font.GothamBlack
            meText.Text = "YOU"
            meText.TextColor3 = T.Dark
            meText.TextSize = 7
            meText.ZIndex = 16
            meText.Parent = meTag
        end

        local dispN = Instance.new("TextLabel")
        dispN.Size = UDim2.new(1,-175,0,22)
        dispN.Position = UDim2.new(0,62,0,8)
        dispN.BackgroundTransparency = 1
        dispN.Font = Enum.Font.GothamBlack
        dispN.Text = plr.DisplayName
        dispN.TextColor3 = isMe and T.Green or T.Text
        dispN.TextSize = 14
        dispN.TextXAlignment = Enum.TextXAlignment.Left
        dispN.ZIndex = 13
        dispN.Parent = card

        local userN = Instance.new("TextLabel")
        userN.Size = UDim2.new(1,-175,0,14)
        userN.Position = UDim2.new(0,62,0,28)
        userN.BackgroundTransparency = 1
        userN.Font = Enum.Font.Gotham
        userN.Text = "@"..plr.Name
        userN.TextColor3 = T.Muted
        userN.TextSize = 10
        userN.TextXAlignment = Enum.TextXAlignment.Left
        userN.ZIndex = 13
        userN.Parent = card

        -- HP bar
        local hpBg = Instance.new("Frame")
        hpBg.Size = UDim2.new(1,-175,0,5)
        hpBg.Position = UDim2.new(0,62,0,46)
        hpBg.BackgroundColor3 = T.BG2
        hpBg.BorderSizePixel = 0
        hpBg.ZIndex = 13
        hpBg.Parent = card
        Corner(hpBg,3)

        local hpFrac = maxHp > 0 and math.clamp(hp/maxHp,0,1) or 0
        local hpFill = Instance.new("Frame")
        hpFill.Size = UDim2.new(hpFrac,0,1,0)
        hpFill.BackgroundColor3 = lerpColor(Color3.fromRGB(255,60,60),Color3.fromRGB(80,255,80),hpFrac)
        hpFill.BorderSizePixel = 0
        hpFill.ZIndex = 14
        hpFill.Parent = hpBg
        Corner(hpFill,3)

        local hpTxt = Instance.new("TextLabel")
        hpTxt.Size = UDim2.new(1,-175,0,13)
        hpTxt.Position = UDim2.new(0,62,0,54)
        hpTxt.BackgroundTransparency = 1
        hpTxt.Font = Enum.Font.Gotham
        hpTxt.Text = "HP: "..hp.." / "..maxHp
        hpTxt.TextColor3 = T.Muted
        hpTxt.TextSize = 9
        hpTxt.TextXAlignment = Enum.TextXAlignment.Left
        hpTxt.ZIndex = 13
        hpTxt.Parent = card

        if not isMe then
            local tpB = Instance.new("TextButton")
            tpB.Size = UDim2.new(0,52,0,30)
            tpB.Position = UDim2.new(1,-118,0.5,-15)
            tpB.BackgroundColor3 = T.Blue
            tpB.Font = Enum.Font.GothamBlack
            tpB.Text = "📍"
            tpB.TextColor3 = Color3.fromRGB(255,255,255)
            tpB.TextSize = 14
            tpB.AutoButtonColor = false
            tpB.ZIndex = 14
            tpB.Parent = card
            Corner(tpB,15)

            local flB = Instance.new("TextButton")
            flB.Size = UDim2.new(0,52,0,30)
            flB.Position = UDim2.new(1,-60,0.5,-15)
            flB.BackgroundColor3 = T.Danger
            flB.Font = Enum.Font.GothamBlack
            flB.Text = "⚡"
            flB.TextColor3 = Color3.fromRGB(255,255,255)
            flB.TextSize = 14
            flB.AutoButtonColor = false
            flB.ZIndex = 14
            flB.Parent = card
            Corner(flB,15)

            local capturedPlr = plr
            tpB.MouseEnter:Connect(function() Tween(tpB,{BackgroundColor3=Color3.fromRGB(50,130,220)},0.15) end)
            tpB.MouseLeave:Connect(function() Tween(tpB,{BackgroundColor3=T.Blue},0.15) end)
            tpB.MouseButton1Click:Connect(function()
                pcall(function()
                    local tc = capturedPlr.Character
                    if tc and tc:FindFirstChild("HumanoidRootPart") then
                        HRP.CFrame = tc.HumanoidRootPart.CFrame * CFrame.new(0,0,-3)
                    end
                end)
            end)

            flB.MouseEnter:Connect(function() Tween(flB,{BackgroundColor3=Color3.fromRGB(200,30,30)},0.15) end)
            flB.MouseLeave:Connect(function() Tween(flB,{BackgroundColor3=T.Danger},0.15) end)
            flB.MouseButton1Click:Connect(function()
                -- Используем реальный SkidFling!
                Tween(flB,{BackgroundColor3=Color3.fromRGB(150,20,20)},0.1)
                FlingTarget(capturedPlr)
                task.wait(0.2)
                Tween(flB,{BackgroundColor3=T.Danger},0.15)
            end)
        end

        table.insert(playerCards, card)
    end
end

playersRefreshBtn.MouseButton1Click:Connect(function()
    Tween(playersRefreshBtn,{BackgroundColor3=T.Surface},0.1)
    RefreshPlayersTab()
    task.wait(0.2)
    Tween(playersRefreshBtn,{BackgroundColor3=Color3.fromRGB(25,25,25)},0.15)
end)

-- ============================================================
-- GAME FUNCTIONS
-- ============================================================
local function KillAura()
    while State.KillAura and Running do
        pcall(function()
            for _,p in pairs(Players:GetPlayers()) do
                if p~=LP and p.Character and p.Character:FindFirstChild("Humanoid") then
                    local tool = LP.Character:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Event") then
                        tool.Event:FireServer(p.Character.HumanoidRootPart)
                    end
                end
            end
        end)
        task.wait(0.1)
    end
end

local function NoCooldownBlade()
    while State.NoCooldownBlade and Running do
        pcall(function()
            local blade = LP.Character:FindFirstChild("DuelingSword")
            if blade and blade:FindFirstChild("Cooldown") then blade.Cooldown.Value = 0 end
        end)
        task.wait()
    end
end

local function NoCooldownSword()
    while State.NoCooldownSword and Running do
        pcall(function()
            for _,tool in pairs(LP.Character:GetChildren()) do
                if tool:IsA("Tool") and tool:FindFirstChild("Cooldown") then tool.Cooldown.Value = 0 end
            end
        end)
        task.wait()
    end
end

local function NoCooldownPrompts()
    while State.NoCooldownPrompts and Running do
        pcall(function()
            for _,obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then obj.HoldDuration = 0 end
            end
        end)
        task.wait(0.5)
    end
end

local function AutoGetMap()
    while State.AutoGetMap and Running do
        pcall(function()
            for _,obj in pairs(Workspace:GetDescendants()) do
                if (obj.Name=="MapToken" or obj.Name=="Token") and obj:IsA("BasePart") then
                    HRP.CFrame = obj.CFrame task.wait(0.1)
                end
            end
        end)
        task.wait(0.5)
    end
end

local function AutoTouchIllumina()
    while State.AutoTouchIllumina and Running do
        pcall(function()
            local illumina = Workspace:FindFirstChild("Illumina",true)
            if illumina and illumina:IsA("BasePart") then HRP.CFrame = illumina.CFrame end
        end)
        task.wait(0.5)
    end
end

local function AntiLavaLoop()
    while State.AntiLava and Running do
        pcall(function()
            for _,obj in pairs(Workspace:GetDescendants()) do
                if obj.Name:lower():find("lava") and obj:IsA("BasePart") then obj:Destroy() end
            end
        end)
        task.wait(0.5)
    end
end

local function AntiSpinnerLoop()
    while State.AntiSpinner and Running do
        pcall(function()
            for _,obj in pairs(Workspace:GetDescendants()) do
                local n = obj.Name:lower()
                if n:find("spin") or n=="rotating" or n=="rotateplat" then
                    for _,child in pairs(obj:GetDescendants()) do
                        if child:IsA("BodyAngularVelocity") then child.AngularVelocity=Vector3.zero child.MaxTorque=Vector3.new(1e9,1e9,1e9) end
                        if child:IsA("BodyVelocity") then child.Velocity=Vector3.zero child.MaxForce=Vector3.new(1e9,1e9,1e9) end
                    end
                    if obj:IsA("BasePart") and not obj.Anchored then obj.Anchored=true end
                end
            end
            if HRP and HRP.RotVelocity.Magnitude>5 then HRP.RotVelocity=Vector3.zero end
        end)
        task.wait(0.05)
    end
end

-- ============================================================
-- COMBAT TAB
-- ============================================================
CreateToggle(TabContents.Combat, "Kill Aura", "Auto attack nearby players", function(s)
    State.KillAura = s
    if s then task.spawn(KillAura) end
end)

CreateButton(TabContents.Combat, "Kill All (Rocket)", "Requires Rocket Launcher", function()
    local rocket = LP.Backpack:FindFirstChild("RocketLauncher") or LP.Character:FindFirstChild("RocketLauncher")
    if not rocket then
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="Ошибка",Text="Rocket Launcher не найден!",Duration=3})
        return
    end
    rocket.Parent = LP.Character
    task.wait(0.1)
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                pcall(function()
                    local myRoot = LP.Character:FindFirstChild("HumanoidRootPart")
                    if not myRoot then return end
                    local savedCFrame = myRoot.CFrame
                    -- Отходим далеко от цели перед выстрелом чтобы не взорвало нас
                    myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 200)
                    task.wait(0.05)
                    -- Ищем все возможные remotes
                    local remoteNames = {"fire","Fire","shoot","Shoot","Launch","launch","remote","Remote"}
                    for _, rName in pairs(remoteNames) do
                        local rem = rocket:FindFirstChild(rName)
                        if rem and rem:IsA("RemoteEvent") then
                            rem:FireServer(targetRoot.Position + Vector3.new(0,3,0))
                            break
                        end
                    end
                    task.wait(0.05)
                    myRoot.CFrame = savedCFrame
                end)
                task.wait(0.15)
            end
        end
    end
    task.wait(0.5)
    pcall(function() rocket.Parent = LP.Backpack end)
end)

CreateButton(TabContents.Combat, "Kill All (Snowball)", "Equip Snowball first", function()
    local s = LP.Character:FindFirstChild("Snowball")
    if s and s:FindFirstChild("remote") then
        for _,p in pairs(Players:GetPlayers()) do
            if p~=LP and p.Character then pcall(function() s.remote:FireServer(p.Character.HumanoidRootPart.Position) end) end
        end
    end
end)

CreateButton(TabContents.Combat, "Freeze All", "Requires Freeze Ray", function()
    -- Ищем Freeze Ray по разным названиям
    local freeze = nil
    local freezeNames = {"Freeze Ray","FreezeRay","Freeze","Ice Ray","IceRay","freeze_ray"}
    for _, fname in pairs(freezeNames) do
        freeze = LP.Backpack:FindFirstChild(fname) or LP.Character:FindFirstChild(fname)
        if freeze then break end
    end

    if not freeze then
        game:GetService("StarterGui"):SetCore("SendNotification",{Title="Ошибка",Text="Freeze Ray не найден!",Duration=3})
        return
    end

    freeze.Parent = LP.Character
    task.wait(0.1)

    local frozenCount = 0

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = p.Character:FindFirstChildOfClass("Humanoid")

            if targetRoot and targetHum and targetHum.Health > 0 then
                pcall(function()
                    -- Пробуем все возможные названия remote
                    local remoteNames = {
                        "fire","Fire","shoot","Shoot",
                        "freeze","Freeze","activate","Activate",
                        "remote","Remote","event","Event","Cast","cast"
                    }
                    local fired = false
                    for _, rName in pairs(remoteNames) do
                        local rem = freeze:FindFirstChild(rName)
                        if rem then
                            if rem:IsA("RemoteEvent") then
                                rem:FireServer(targetRoot)
                                rem:FireServer(targetRoot.Position)
                                fired = true
                                break
                            elseif rem:IsA("RemoteFunction") then
                                pcall(function() rem:InvokeServer(targetRoot) end)
                                fired = true
                                break
                            end
                        end
                    end
                    -- Если не нашли remote — ищем глубже
                    if not fired then
                        for _, desc in pairs(freeze:GetDescendants()) do
                            if desc:IsA("RemoteEvent") then
                                desc:FireServer(targetRoot)
                                desc:FireServer(targetRoot.Position)
                                break
                            end
                        end
                    end
                end)
                frozenCount = frozenCount + 1
                task.wait(0.05)
            end
        end
    end

    game:GetService("StarterGui"):SetCore("SendNotification",{
        Title="Freeze All",
        Text="Заморожено "..frozenCount.." игроков",
        Duration=3
    })

    task.wait(0.3)
    pcall(function() freeze.Parent = LP.Backpack end)
end)
CreateToggle(TabContents.Combat, "NoCooldown Blade", "Dueling sword no cooldown", function(s)
    State.NoCooldownBlade = s
    if s then task.spawn(NoCooldownBlade) end
end)

CreateToggle(TabContents.Combat, "NoCooldown Sword", "All swords no cooldown", function(s)
    State.NoCooldownSword = s
    if s then task.spawn(NoCooldownSword) end
end)

CreateToggle(TabContents.Combat, "NoCooldown Prompts", "No cooldown on prompts", function(s)
    State.NoCooldownPrompts = s
    if s then task.spawn(NoCooldownPrompts) end
end)

-- ============================================================
-- MOVEMENT TAB
-- ============================================================
CreateSlider(TabContents.Movement, "Speed", 16, 200, 16, function(v)
    State.Speed = v
    if Hum then Hum.WalkSpeed = v end
end)

CreateSlider(TabContents.Movement, "Jump Power", 50, 300, 50, function(v)
    State.JumpPower = v
    if Hum then Hum.JumpPower = v end
end)

CreateToggle(TabContents.Movement, "Infinite Jump", "Jump in air", function(s)
    State.InfiniteJump = s
end)

-- ============================================================
-- ESP TAB
-- ============================================================
CreateToggle(TabContents.ESP, "Enable ESP", "See all players through walls", function(s)
    State.ESP = s
    if not s then for plr,_ in pairs(espDrawings) do removeESP(plr) end end
end)

-- ============================================================
-- MISC TAB
-- ============================================================
CreateToggle(TabContents.Misc, "Auto Get Map", "Auto collect map tokens", function(s)
    State.AutoGetMap = s
    if s then task.spawn(AutoGetMap) end
end)

CreateToggle(TabContents.Misc, "Auto Touch Illumina", "Auto get Illumina sword", function(s)
    State.AutoTouchIllumina = s
    if s then task.spawn(AutoTouchIllumina) end
end)

CreateToggle(TabContents.Misc, "Anti-Lava", "Remove all lava", function(s)
    State.AntiLava = s
    if s then task.spawn(AntiLavaLoop) end
end)

CreateToggle(TabContents.Misc, "Anti-Void", "Teleport up if falling", function(s)
    State.AntiVoid = s
end)

CreateToggle(TabContents.Misc, "Anti-Spinner", "Выживание на ивенте спиннер", function(s)
    State.AntiSpinner = s
    if s then task.spawn(AntiSpinnerLoop) end
end)

CreateButton(TabContents.Misc, "Remove Meteors", "Delete falling meteors", function()
    for _,obj in pairs(Workspace:GetChildren()) do
        if obj.Name=="Meteor" then obj:Destroy() end
    end
end)

CreateButton(TabContents.Misc, "Remove Coal", "Delete coal objects", function()
    for _,obj in pairs(Workspace:GetChildren()) do
        if obj.Name=="Coal" or obj.Name=="coal" then obj:Destroy() end
    end
end)

CreateButton(TabContents.Misc, "Remove Icicles", "Delete falling icicles", function()
    pcall(function()
        for _,obj in pairs(Workspace.Plates:GetDescendants()) do
            if obj.Name=="Spike" or obj.Name=="spike" then obj:Destroy() end
        end
    end)
end)

CreateButton(TabContents.Misc, "Hide Effects", "Remove visual effects", function()
    for _,obj in pairs(game:GetService("Lighting"):GetChildren()) do
        if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") then
            obj.Enabled = false
        end
    end
end)

-- ============================================================
-- CLOSE BUTTON
-- ============================================================
CloseBtn.MouseEnter:Connect(function() Tween(CloseBtn,{BackgroundColor3=T.Hover},0.2) end)
CloseBtn.MouseLeave:Connect(function() Tween(CloseBtn,{BackgroundColor3=T.Surface},0.2) end)
CloseBtn.MouseButton1Click:Connect(function()
    Tween(Main,{Position=UDim2.new(0.5,-260,1.5,0)},0.35)
    task.wait(0.35)
    SG.Enabled = false
    MenuOpen = false
    Main.Position = UDim2.new(0.5,-260,0.5,-340)
end)

-- ============================================================
-- PLAYER EVENTS
-- ============================================================
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    RefreshFlingPlayerList()
    RefreshPlayersTab()
    RefreshTpPlayerList()
end)

Players.PlayerRemoving:Connect(function(plr)
    if SelectedFlingTarget == plr then
        SelectedFlingTarget = nil
        selectedTargetText.Text = "🎯 Цель: не выбрана"
    end
    SelectedTargets[plr.Name] = nil
    RefreshFlingPlayerList()
    RefreshPlayersTab()
    RefreshTpPlayerList()
    removeESP(plr)
end)

-- ============================================================
-- TOGGLE MENU
-- ============================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp or not Running then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        if not MenuOpen then
            MenuOpen = true
            SG.Enabled = true
            Main.Position = UDim2.new(0.5,-260,-0.5,0)
            Tween(Main,{Position=UDim2.new(0.5,-260,0.5,-340)},0.4)
        end
    end
end)

-- ============================================================
-- INFINITE JUMP
-- ============================================================
UIS.JumpRequest:Connect(function()
    if State.InfiniteJump and Hum and Hum:GetState() ~= Enum.HumanoidStateType.Jumping then
        Hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
RS.RenderStepped:Connect(function()
    if not Running then return end
    updateESP()
    if State.AntiVoid and HRP and HRP.Position.Y < -50 then
        HRP.CFrame = CFrame.new(HRP.Position.X, 50, HRP.Position.Z)
    end
end)

-- ============================================================
-- CHARACTER UPDATE
-- ============================================================
LP.CharacterAdded:Connect(function(char)
    Char = char
    Hum = char:WaitForChild("Humanoid")
    HRP = char:WaitForChild("HumanoidRootPart")
    Hum.WalkSpeed = State.Speed
    Hum.JumpPower = State.JumpPower
end)

-- ============================================================
-- INIT
-- ============================================================
task.wait(0.5)
RefreshFlingPlayerList()
RefreshPlayersTab()
RefreshTpPlayerList()

SG.Enabled = true
MenuOpen = true
Main.Position = UDim2.new(0.5,-260,-0.5,0)
Tween(Main,{Position=UDim2.new(0.5,-260,0.5,-340)},0.4)

print("⚔️ QWEN Horrific Housing Ultimate loaded!")
print("DELETE   — открыть/закрыть")
print("⚙️       — настройки + выгрузка")
print("Scroll   — переключение вкладок")
print("Fling    — SkidFling (реальный механизм)")
print("  ☑ чекбокс = мульти цель (START/STOP)")
print("  🎯 кнопка = одиночная цель (FLING TARGET)")	
