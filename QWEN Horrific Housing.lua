--[[
    QWEN Horrific Housing Ultimate v5.0
    Windows 11 Fluent Design - Black & White
    DELETE - open/close menu
    Right-click toggle = set bind
    Backspace = remove bind
    
    INVISIBLE METHOD: Teleport real char to void,
    use ViewportFrame or keep camera at old position
]]

for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("HorrificUltimate") or gui.Name == "BindIndicatorGui" then
        pcall(function() gui:Destroy() end)
    end
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local HRP = Char:WaitForChild("HumanoidRootPart")

local Running = true
local MenuOpen = false
local bindPopupActive = false
local BindListening = nil
local currentBindPopup = nil
local jumpDebounce = false

local State = {
    Speed = 16, JumpPower = 50,
    KillAura = false, ESP = false, AntiLava = false,
    AntiVoid = false, InfiniteJump = false, AntiSweeper = false,
    DeathNoteTP = false, AutoSword = false, Noclip = false, Reach = false,
    Invisible = false,
}

local ToggleStateMap = {
    ["Kill Aura"]="KillAura",["ESP"]="ESP",["Anti-Lava"]="AntiLava",
    ["Anti-Void"]="AntiVoid",["Infinite Jump"]="InfiniteJump",
    ["Anti-Spinner"]="AntiSweeper",["Death Note TP"]="DeathNoteTP",
    ["Auto Sword TP"]="AutoSword",["Noclip"]="Noclip",["Reach"]="Reach",
    ["Invisible"]="Invisible",
}

local SAVE_KEY = "HorrificUltimate_v50_Settings"
local Binds = {}
local bindLabels = {}
local allConnections = {}
local FlingActive = false
local SelectedTargets = {}
local SelectedFlingTarget = nil
local espDrawings = {}

getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

-- ═══════════════════════════════════════
-- INVISIBLE SYSTEM (Working Method)
-- Uses character recreation trick
-- ═══════════════════════════════════════
local InvisibleActive = false
local InvisConn = nil
local InvisParts = {}
local OriginalPositionInvis = nil
local FakeCharModel = nil

local function EnableInvisible()
    if InvisibleActive then return end
    
    local char = LP.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    
    InvisibleActive = true
    OriginalPositionInvis = hrp.CFrame
    
    -- Method: We use Humanoid:ChangeState to die, then immediately
    -- move the character. But better method for Horrific Housing:
    -- 
    -- ACTUAL WORKING METHOD:
    -- 1. Store position
    -- 2. Move character very far away (server sees you there)
    -- 3. Use a fake unanchored part as camera subject
    -- 4. Control movement with BodyVelocity on the fake part
    -- 5. Real character stays far = other players can't see you
    
    -- Create invisible controller part
    local controller = Instance.new("Part")
    controller.Name = "InvisController"
    controller.Size = Vector3.new(1, 1, 1)
    controller.Transparency = 1
    controller.CanCollide = false
    controller.Anchored = false
    controller.CFrame = hrp.CFrame
    controller.Parent = workspace
    
    -- Add BodyPosition to control it
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.D = 100
    bp.P = 10000
    bp.Position = hrp.Position
    bp.Parent = controller
    
    -- Add BodyGyro for rotation
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.D = 50
    bg.P = 5000
    bg.CFrame = hrp.CFrame
    bg.Parent = controller
    
    FakeCharModel = controller
    
    -- Set camera to follow controller
    workspace.CurrentCamera.CameraSubject = controller
    
    -- Move real character far away
    pcall(function()
        workspace.FallenPartsDestroyHeight = -math.huge
    end)
    
    hrp.CFrame = CFrame.new(0, -500, 0)
    
    -- Keep real character far and control fake part
    InvisConn = RS.Heartbeat:Connect(function()
        if not InvisibleActive or not Running then
            return
        end
        
        pcall(function()
            local c = LP.Character
            if not c then return end
            local h = c:FindFirstChild("HumanoidRootPart")
            local hum2 = c:FindFirstChildOfClass("Humanoid")
            if not h or not hum2 then return end
            
            -- Keep real char underground
            if h.Position.Y > -400 then
                h.CFrame = CFrame.new(0, -500, 0)
            end
            h.Velocity = Vector3.zero
            h.RotVelocity = Vector3.zero
            
            -- Move controller based on input
            if controller and controller.Parent then
                local cam = workspace.CurrentCamera
                local moveDir = hum2.MoveDirection
                
                if moveDir.Magnitude > 0 then
                    bp.Position = controller.Position + moveDir * State.Speed * 0.03
                else
                    bp.Position = controller.Position
                end
                
                -- Look direction from camera
                if cam then
                    local lookVector = cam.CFrame.LookVector
                    bg.CFrame = CFrame.new(controller.Position, controller.Position + Vector3.new(lookVector.X, 0, lookVector.Z))
                end
            end
        end)
    end)
    
    table.insert(allConnections, InvisConn)
end

local function DisableInvisible()
    if not InvisibleActive then return end
    InvisibleActive = false
    
    -- Disconnect loop
    if InvisConn then
        pcall(function() InvisConn:Disconnect() end)
        InvisConn = nil
    end
    
    -- Get position of controller before removing
    local returnPos = OriginalPositionInvis
    if FakeCharModel and FakeCharModel.Parent then
        returnPos = FakeCharModel.CFrame
        pcall(function() FakeCharModel:Destroy() end)
    end
    FakeCharModel = nil
    
    -- Restore fallen parts destroy height
    pcall(function()
        workspace.FallenPartsDestroyHeight = getgenv().FPDH
    end)
    
    -- Return real character
    pcall(function()
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if hrp and returnPos then
                hrp.CFrame = returnPos * CFrame.new(0, 3, 0)
                hrp.Velocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
            end
            if hum2 then
                workspace.CurrentCamera.CameraSubject = hum2
                hum2:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end)
end

-- ═══════════════════════════════════════

local function SaveSettings()
    local data = {}
    for k,v in pairs(State) do data[k]=v end
    data.Binds = Binds
    pcall(function() writefile(SAVE_KEY..".json", HttpService:JSONEncode(data)) end)
end

local function LoadSettings()
    local ok, r = pcall(function()
        if isfile and isfile(SAVE_KEY..".json") then
            return HttpService:JSONDecode(readfile(SAVE_KEY..".json"))
        end
    end)
    if ok and r then
        for k,v in pairs(r) do
            if k=="Binds" then if type(v)=="table" then Binds=v end
            elseif State[k]~=nil then State[k]=v end
        end
    end
end
LoadSettings()
-- Don't auto-enable invisible from save (requires fresh toggle)
State.Invisible = false

local C = {
    bg          = Color3.fromRGB(32, 32, 32),
    bg2         = Color3.fromRGB(40, 40, 40),
    surface     = Color3.fromRGB(45, 45, 45),
    surfaceHov  = Color3.fromRGB(55, 55, 55),
    card        = Color3.fromRGB(50, 50, 50),
    cardHov     = Color3.fromRGB(60, 60, 60),
    border      = Color3.fromRGB(65, 65, 65),
    borderLight = Color3.fromRGB(80, 80, 80),
    text        = Color3.fromRGB(255, 255, 255),
    textSec     = Color3.fromRGB(180, 180, 180),
    textMuted   = Color3.fromRGB(120, 120, 120),
    accent      = Color3.fromRGB(255, 255, 255),
    toggleOn    = Color3.fromRGB(255, 255, 255),
    toggleOff   = Color3.fromRGB(70, 70, 70),
    knobOn      = Color3.fromRGB(32, 32, 32),
    knobOff     = Color3.fromRGB(160, 160, 160),
    danger      = Color3.fromRGB(255, 75, 75),
    dangerBg    = Color3.fromRGB(60, 30, 30),
    shadow      = Color3.fromRGB(0, 0, 0),
}

local function Corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
end

local function Stroke(p, col, t, trans)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border; s.Thickness = t or 1; s.Transparency = trans or 0
    s.Parent = p; return s
end

local function Tween(o, pr, d, style, dir)
    if not o or not o.Parent then return end
    pcall(function()
        TS:Create(o, TweenInfo.new(d or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), pr):Play()
    end)
end

local function SmoothTween(o, pr, d)
    Tween(o, pr, d or 0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
end

local function BounceTween(o, pr, d)
    Tween(o, pr, d or 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local function lerpColor(a, b, t)
    return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
end

local function GetHRP()
    local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid")
end

-- FLING
local function SkidFling(TargetPlayer)
    if not Running or not FlingActive then return end
    local Character = LP.Character
    if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    local RootPart = Humanoid.RootPart
    if not RootPart then return end
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end
    if THumanoid and THumanoid.Sit then return end
    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid and TRootPart then workspace.CurrentCamera.CameraSubject = THumanoid end
    if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end
    local FPos = function(BP, Pos, Ang)
        if not RootPart or not RootPart.Parent then return end
        RootPart.CFrame = CFrame.new(BP.Position)*Pos*Ang
        pcall(function() Character:PivotTo(CFrame.new(BP.Position)*Pos*Ang) end)
        RootPart.Velocity = Vector3.new(9e7,9e7*10,9e7)
        RootPart.RotVelocity = Vector3.new(9e8,9e8,9e8)
    end
    local SFBasePart = function(BP)
        if not BP or not BP.Parent then return end
        local T2,Tm,A = 2,tick(),0
        repeat
            if not Running or not FlingActive or not RootPart or not RootPart.Parent or not BP or not BP.Parent then break end
            if THumanoid and THumanoid.Parent then
                if BP.Velocity.Magnitude < 50 then
                    A=A+100
                    local md=THumanoid.MoveDirection*BP.Velocity.Magnitude/1.25
                    FPos(BP,CFrame.new(0,1.5,0)+md,CFrame.Angles(math.rad(A),0,0)) task.wait()
                    FPos(BP,CFrame.new(0,-1.5,0)+md,CFrame.Angles(math.rad(A),0,0)) task.wait()
                    FPos(BP,CFrame.new(0,1.5,0)+THumanoid.MoveDirection,CFrame.Angles(math.rad(A),0,0)) task.wait()
                    FPos(BP,CFrame.new(0,-1.5,0)+THumanoid.MoveDirection,CFrame.Angles(math.rad(A),0,0)) task.wait()
                else
                    FPos(BP,CFrame.new(0,1.5,THumanoid.WalkSpeed),CFrame.Angles(math.rad(90),0,0)) task.wait()
                    FPos(BP,CFrame.new(0,-1.5,-THumanoid.WalkSpeed),CFrame.Angles(0,0,0)) task.wait()
                    FPos(BP,CFrame.new(0,-1.5,0),CFrame.Angles(math.rad(90),0,0)) task.wait()
                    FPos(BP,CFrame.new(0,-1.5,0),CFrame.Angles(0,0,0)) task.wait()
                end
            else break end
        until Tm+T2<tick() or not FlingActive or not Running
    end
    pcall(function() workspace.FallenPartsDestroyHeight=0/0 end)
    local BV=Instance.new("BodyVelocity") BV.Parent=RootPart BV.Velocity=Vector3.zero BV.MaxForce=Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,false)
    if TRootPart and TRootPart.Parent then SFBasePart(TRootPart)
    elseif THead and THead.Parent then SFBasePart(THead)
    elseif Handle and Handle.Parent then SFBasePart(Handle) end
    pcall(function() BV:Destroy() end)
    pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated,true) end)
    pcall(function() workspace.CurrentCamera.CameraSubject=Humanoid end)
    if getgenv().OldPos and RootPart and RootPart.Parent then
        local att=0
        repeat att=att+1 pcall(function()
            RootPart.CFrame=getgenv().OldPos*CFrame.new(0,.5,0)
            Character:PivotTo(getgenv().OldPos*CFrame.new(0,.5,0))
            Humanoid:ChangeState("GettingUp")
            for _,p in pairs(Character:GetChildren()) do
                if p:IsA("BasePart") then p.Velocity=Vector3.zero p.RotVelocity=Vector3.zero end
            end
        end) task.wait()
        until (RootPart.Position-getgenv().OldPos.Position).Magnitude<25 or att>100
        pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end)
    end
end

local function FlingAll()
    FlingActive=true
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and Running and FlingActive then
            task.spawn(function() pcall(function() SkidFling(p) end) end) task.wait(0.1)
        end
    end
end

-- KILL AURA
local MELEE_KW = {"sword","blade","knife","katana","dagger","saber","axe","scythe","melee","slash","cleave","cutlass","machete","illumina","linkedsword","darkheart","classic","necro","firebrand","icedagger","windforce"}
local RANGED_KW = {"gun","pistol","rifle","sniper","shoot","bullet","cannon","bow","arrow","musket","crossbow","blaster","laser","rocket","grenade"}

local function isMeleeTool(tool)
    if not tool then return false end
    local n=tool.Name:lower()
    for _,k in pairs(RANGED_KW) do if n:find(k) then return false end end
    for _,k in pairs(MELEE_KW) do if n:find(k) then return true end end
    if not tool:FindFirstChild("Handle") then return false end
    if tool:FindFirstChildWhichIsA("BillboardGui") then return false end
    return true
end

local function KillAura()
    while State.KillAura and Running do
        pcall(function()
            local mc=LP.Character if not mc then return end
            local mh=mc:FindFirstChild("HumanoidRootPart") if not mh then return end
            local tool=mc:FindFirstChildOfClass("Tool") if not tool or not isMeleeTool(tool) then return end
            for _,p in pairs(Players:GetPlayers()) do
                if p~=LP and p.Character then
                    local th=p.Character:FindFirstChild("Humanoid")
                    local tr=p.Character:FindFirstChild("HumanoidRootPart")
                    if th and tr and th.Health>0 and (mh.Position-tr.Position).Magnitude<=15 then
                        local fired=false
                        for _,d in pairs(tool:GetDescendants()) do
                            if d:IsA("RemoteEvent") then pcall(function() d:FireServer(tr) d:FireServer(tr.Position) end) fired=true end
                        end
                        if not fired then
                            for _,d in pairs(tool:GetDescendants()) do
                                if d:IsA("RemoteFunction") then pcall(function() d:InvokeServer(tr) end) end
                            end
                        end
                        pcall(function() tool:Activate() end)
                    end
                end
            end
        end)
        task.wait(0.15)
    end
end

-- ESP
local hasDrawing = pcall(function() return Drawing.new end)

local function removeESP(plr)
    if espDrawings[plr] then
        for _,d in pairs(espDrawings[plr]) do pcall(function() d.Visible=false d:Remove() end) end
        espDrawings[plr]=nil
    end
end

local function createESP(plr)
    if not hasDrawing or espDrawings[plr] then return end
    local ok,r=pcall(function()
        local b=Drawing.new("Square") local n=Drawing.new("Text") local dt=Drawing.new("Text")
        local hb=Drawing.new("Square") local hf=Drawing.new("Square")
        b.Thickness=1 b.Filled=false b.Visible=false b.Color=C.text
        n.Size=13 n.Center=true n.Outline=true n.OutlineColor=C.shadow n.Color=C.text n.Visible=false
        dt.Size=11 dt.Center=true dt.Outline=true dt.OutlineColor=C.shadow dt.Color=C.textSec dt.Visible=false
        hb.Thickness=0 hb.Filled=true hb.Visible=false hb.Color=Color3.fromRGB(40,40,40)
        hf.Thickness=0 hf.Filled=true hf.Visible=false hf.Color=C.text
        return {box=b,name=n,distance=dt,hpBg=hb,hpFill=hf}
    end)
    if ok and r then espDrawings[plr]=r end
end

local function updateESP()
    if not hasDrawing then return end
    if not State.ESP then for p,_ in pairs(espDrawings) do removeESP(p) end return end
    local cam=workspace.CurrentCamera if not cam then return end
    local valid={} for _,p in ipairs(Players:GetPlayers()) do valid[p]=true end
    for p,_ in pairs(espDrawings) do if not valid[p] then removeESP(p) end end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LP then
            local ch=plr.Character local hm=ch and ch:FindFirstChildOfClass("Humanoid")
            local rt=ch and ch:FindFirstChild("HumanoidRootPart") local hd=ch and ch:FindFirstChild("Head")
            if not(ch and hm and rt and hd) or hm.Health<=0 then removeESP(plr) else
                if not espDrawings[plr] then createESP(plr) end
                local d=espDrawings[plr]
                if d then
                    local rv,on=cam:WorldToViewportPoint(rt.Position)
                    if on then
                        local hv=cam:WorldToViewportPoint(hd.Position+Vector3.new(0,.6,0))
                        local fv=cam:WorldToViewportPoint(rt.Position-Vector3.new(0,3.1,0))
                        local h=math.abs(fv.Y-hv.Y) local w=h*0.5
                        d.box.Size=Vector2.new(w,h) d.box.Position=Vector2.new(rv.X-w/2,hv.Y) d.box.Visible=true
                        d.name.Text=plr.DisplayName d.name.Position=Vector2.new(rv.X,hv.Y-16) d.name.Visible=true
                        local dist=(cam.CFrame.Position-rt.Position).Magnitude
                        d.distance.Text=string.format("%.0fm",dist) d.distance.Position=Vector2.new(rv.X,fv.Y+3) d.distance.Visible=true
                        local bW,bH,bX,bY=4,math.max(10,h),rv.X-w/2-7,hv.Y
                        d.hpBg.Size=Vector2.new(bW,bH) d.hpBg.Position=Vector2.new(bX,bY) d.hpBg.Visible=true
                        local mH=hm.MaxHealth if mH<=0 or mH~=mH then mH=100 end
                        local cH=hm.Health if cH~=cH then cH=0 end
                        local fr=math.clamp(cH/mH,0,1) local fH=math.max(1,bH*fr)
                        d.hpFill.Size=Vector2.new(bW,fH) d.hpFill.Position=Vector2.new(bX,bY+(bH-fH))
                        d.hpFill.Color=lerpColor(Color3.fromRGB(255,75,75),C.text,fr) d.hpFill.Visible=true
                    else
                        d.box.Visible=false d.name.Visible=false d.distance.Visible=false
                        d.hpBg.Visible=false d.hpFill.Visible=false
                    end
                end
            end
        end
    end
end

-- MISC
local deathNoteConn, autoSwordConn, antiVoidConn = nil,nil,nil
local lastSafePos = nil

local function StartDeathNoteTP()
    if deathNoteConn then pcall(function() deathNoteConn:Disconnect() end) end
    deathNoteConn=Workspace.DescendantAdded:Connect(function(obj)
        if not State.DeathNoteTP or not Running then return end
        local ok2,nm=pcall(function() return obj.Name:lower() end) if not ok2 then return end
        if nm:find("note") or nm:find("death") then task.wait(0.05) pcall(function()
            local pt=obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if pt then local ch=LP.Character local hm=ch and ch:FindFirstChildOfClass("Humanoid")
                if hm and hm.Health>0 then local hr=ch:FindFirstChild("HumanoidRootPart")
                    if hr then hr.CFrame=pt.CFrame*CFrame.new(0,3,0) end end end
        end) end
    end) table.insert(allConnections,deathNoteConn)
end

local function StartAutoSword()
    if autoSwordConn then pcall(function() autoSwordConn:Disconnect() end) end
    autoSwordConn=Workspace.DescendantAdded:Connect(function(obj)
        if not State.AutoSword or not Running or not obj:IsA("Tool") then return end
        local nl=obj.Name:lower()
        local is=nl:find("sword") or nl:find("blade") or nl:find("knife") or nl:find("katana") or
            nl:find("illumina") or nl:find("linkedsword") or nl:find("darkheart") or nl:find("classic") or
            nl:find("saber") or nl:find("axe") or nl:find("scythe") or nl:find("dagger")
        if not is or obj.Parent~=Workspace then return end
        local w=0 repeat task.wait(0.05) w=w+0.05
        until (obj and obj.Parent==Workspace and obj:FindFirstChild("Handle") and obj:FindFirstChild("Handle").Velocity.Magnitude<1) or w>3
        if w>3 then return end
        pcall(function() if not obj or not obj.Parent or (LP.Character and obj:IsDescendantOf(LP.Character)) then return end
            local h=obj:FindFirstChild("Handle") local pt=h or obj:FindFirstChildWhichIsA("BasePart")
            if pt then local ch=LP.Character local hm=ch and ch:FindFirstChildOfClass("Humanoid")
                if hm and hm.Health>0 then local hr=ch:FindFirstChild("HumanoidRootPart")
                    if hr then hr.CFrame=pt.CFrame*CFrame.new(0,2,0) end end end
        end)
    end) table.insert(allConnections,autoSwordConn)
end

local function AntiLavaLoop()
    while State.AntiLava and Running do pcall(function()
        for _,o in pairs(Workspace:GetDescendants()) do
            if o:IsA("BasePart") and o.Name:lower():find("lava") then o.CanCollide=false o.Transparency=1 pcall(function() o:Destroy() end) end
        end
    end) task.wait(0.5) end
end

local function StartAntiVoid()
    if antiVoidConn then pcall(function() antiVoidConn:Disconnect() end) antiVoidConn=nil end
    lastSafePos=nil
    antiVoidConn=RS.Heartbeat:Connect(function()
        if not State.AntiVoid or not Running then if antiVoidConn then pcall(function() antiVoidConn:Disconnect() end) antiVoidConn=nil end return end
        if InvisibleActive then return end -- Don't interfere with invisible
        pcall(function() local hr=GetHRP() if not hr then return end
            if hr.Position.Y>0 then lastSafePos=hr.Position end
            if hr.Position.Y<-30 then
                hr.CFrame=CFrame.new(lastSafePos and lastSafePos.X or 0,50,lastSafePos and lastSafePos.Z or 0)
                hr.Velocity=Vector3.zero hr.RotVelocity=Vector3.zero
            end
        end)
    end) table.insert(allConnections,antiVoidConn)
end

local function AntiSweeperLoop()
    while State.AntiSweeper and Running do pcall(function()
        for _,v in pairs(Workspace:GetDescendants()) do if v.Name=="Spinner" then pcall(function() v:Destroy() end) end end
    end) task.wait(0.5) end
end

-- GUI
local WIN_W, WIN_H = 560, 580
local HEADER_H = 56
local SIDEBAR_W = 120
local STATUSBAR_H = 28
local CONTENT_X = SIDEBAR_W
local CONTENT_W = WIN_W - CONTENT_X
local CONTENT_H = WIN_H - HEADER_H - STATUSBAR_H

local SG = Instance.new("ScreenGui")
SG.Name = "HorrificUltimateGUI"
SG.Parent = game.CoreGui
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Enabled = false

local Blur = Instance.new("Frame")
Blur.Name = "Backdrop"
Blur.Size = UDim2.new(1, 0, 1, 0)
Blur.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Blur.BackgroundTransparency = 1
Blur.BorderSizePixel = 0
Blur.ZIndex = 0
Blur.Parent = SG

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Main.BackgroundColor3 = C.bg
Main.BackgroundTransparency = 0.02
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.ClipsDescendants = true
Main.Parent = SG
Corner(Main, 12)
Stroke(Main, C.border, 1, 0.3)

local Mica = Instance.new("Frame")
Mica.Size = UDim2.new(1, 0, 1, 0)
Mica.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Mica.BackgroundTransparency = 0.97
Mica.BorderSizePixel = 0
Mica.ZIndex = 1
Mica.Parent = Main
Corner(Mica, 12)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HEADER_H)
Header.BackgroundColor3 = C.bg
Header.BackgroundTransparency = 0.3
Header.BorderSizePixel = 0
Header.ZIndex = 5
Header.Parent = Main
Corner(Header, 12)

local HeaderBottom = Instance.new("Frame")
HeaderBottom.Size = UDim2.new(1, 0, 0, 12)
HeaderBottom.Position = UDim2.new(0, 0, 1, -12)
HeaderBottom.BackgroundColor3 = C.bg
HeaderBottom.BackgroundTransparency = 0.3
HeaderBottom.BorderSizePixel = 0
HeaderBottom.ZIndex = 5
HeaderBottom.Parent = Header

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, -24, 0, 1)
HeaderLine.Position = UDim2.new(0, 12, 1, 0)
HeaderLine.BackgroundColor3 = C.border
HeaderLine.BackgroundTransparency = 0.5
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 6
HeaderLine.Parent = Header

local AccDot = Instance.new("Frame")
AccDot.Size = UDim2.new(0, 4, 0, 4)
AccDot.Position = UDim2.new(0, 18, 0, 16)
AccDot.BackgroundColor3 = C.accent
AccDot.BorderSizePixel = 0
AccDot.ZIndex = 7
AccDot.Parent = Header
Corner(AccDot, 2)

local TitleL = Instance.new("TextLabel")
TitleL.Size = UDim2.new(0, 300, 0, 20)
TitleL.Position = UDim2.new(0, 28, 0, 10)
TitleL.BackgroundTransparency = 1
TitleL.Font = Enum.Font.GothamBlack
TitleL.Text = "Horrific Housing"
TitleL.TextColor3 = C.text
TitleL.TextSize = 15
TitleL.TextXAlignment = Enum.TextXAlignment.Left
TitleL.ZIndex = 7
TitleL.Parent = Header

local SubL = Instance.new("TextLabel")
SubL.Size = UDim2.new(0, 300, 0, 14)
SubL.Position = UDim2.new(0, 28, 0, 32)
SubL.BackgroundTransparency = 1
SubL.Font = Enum.Font.Gotham
SubL.Text = "v5.0 · Fluent · DELETE to toggle"
SubL.TextColor3 = C.textMuted
SubL.TextSize = 10
SubL.TextXAlignment = Enum.TextXAlignment.Left
SubL.ZIndex = 7
SubL.Parent = Header

local function HeaderBtn(text, posX, bg, tc, strokeCol)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 32, 0, 32)
    b.Position = UDim2.new(1, posX, 0.5, -16)
    b.BackgroundColor3 = bg
    b.BackgroundTransparency = 0.3
    b.Font = Enum.Font.GothamBold
    b.Text = text
    b.TextColor3 = tc
    b.TextSize = 12
    b.AutoButtonColor = false
    b.ZIndex = 7
    b.Parent = Header
    Corner(b, 8)
    if strokeCol then Stroke(b, strokeCol, 1, 0.5) end
    return b
end

local SettingsBtn = HeaderBtn("S", -72, C.surface, C.textSec, C.border)
local CloseBtn = HeaderBtn("X", -34, C.dangerBg, C.danger, Color3.fromRGB(80,30,30))

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 0, CONTENT_H)
Sidebar.Position = UDim2.new(0, 0, 0, HEADER_H)
Sidebar.BackgroundColor3 = C.bg
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 3
Sidebar.Parent = Main

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 2)
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.PaddingLeft = UDim.new(0, 8)
SidePad.PaddingRight = UDim.new(0, 8)
SidePad.Parent = Sidebar

local SideDiv = Instance.new("Frame")
SideDiv.Size = UDim2.new(0, 1, 0, CONTENT_H)
SideDiv.Position = UDim2.new(0, SIDEBAR_W, 0, HEADER_H)
SideDiv.BackgroundColor3 = C.border
SideDiv.BackgroundTransparency = 0.6
SideDiv.BorderSizePixel = 0
SideDiv.ZIndex = 4
SideDiv.Parent = Main

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(0, CONTENT_W, 0, CONTENT_H)
ContentArea.Position = UDim2.new(0, CONTENT_X, 0, HEADER_H)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.ClipsDescendants = true
ContentArea.ZIndex = 3
ContentArea.Parent = Main

local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, STATUSBAR_H)
StatusBar.Position = UDim2.new(0, 0, 1, -STATUSBAR_H)
StatusBar.BackgroundColor3 = C.bg
StatusBar.BackgroundTransparency = 0.3
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 5
StatusBar.Parent = Main

local StatusLine2 = Instance.new("Frame")
StatusLine2.Size = UDim2.new(1, -24, 0, 1)
StatusLine2.Position = UDim2.new(0, 12, 0, 0)
StatusLine2.BackgroundColor3 = C.border
StatusLine2.BackgroundTransparency = 0.6
StatusLine2.BorderSizePixel = 0
StatusLine2.ZIndex = 6
StatusLine2.Parent = StatusBar

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 6, 0, 6)
StatusDot.Position = UDim2.new(0, 14, 0.5, -3)
StatusDot.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 7
StatusDot.Parent = StatusBar
Corner(StatusDot, 3)

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -35, 1, 0)
StatusText.Position = UDim2.new(0, 26, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Font = Enum.Font.Gotham
StatusText.Text = "Ready · Combat"
StatusText.TextColor3 = C.textMuted
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.ZIndex = 7
StatusText.Parent = StatusBar

-- SETTINGS PANEL
local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(1, 0, 1, 0)
SettingsPanel.Position = UDim2.new(1, 10, 0, 0)
SettingsPanel.BackgroundColor3 = C.bg
SettingsPanel.BorderSizePixel = 0
SettingsPanel.ZIndex = 20
SettingsPanel.Visible = false
SettingsPanel.Parent = Main
Corner(SettingsPanel, 12)
Stroke(SettingsPanel, C.border, 1, 0.3)

local SPTitle = Instance.new("TextLabel")
SPTitle.Size = UDim2.new(1, -60, 0, 56)
SPTitle.Position = UDim2.new(0, 20, 0, 0)
SPTitle.BackgroundTransparency = 1
SPTitle.Font = Enum.Font.GothamBlack
SPTitle.Text = "Settings"
SPTitle.TextColor3 = C.text
SPTitle.TextSize = 15
SPTitle.TextXAlignment = Enum.TextXAlignment.Left
SPTitle.ZIndex = 21
SPTitle.Parent = SettingsPanel

local SPClose = Instance.new("TextButton")
SPClose.Size = UDim2.new(0, 32, 0, 32)
SPClose.Position = UDim2.new(1, -44, 0, 12)
SPClose.BackgroundColor3 = C.dangerBg
SPClose.BackgroundTransparency = 0.3
SPClose.Font = Enum.Font.GothamBold
SPClose.Text = "X"
SPClose.TextColor3 = C.danger
SPClose.TextSize = 12
SPClose.AutoButtonColor = false
SPClose.ZIndex = 22
SPClose.Parent = SettingsPanel
Corner(SPClose, 8)

local UnloadCard = Instance.new("Frame")
UnloadCard.Size = UDim2.new(1, -40, 0, 72)
UnloadCard.Position = UDim2.new(0, 20, 0, 68)
UnloadCard.BackgroundColor3 = C.dangerBg
UnloadCard.BackgroundTransparency = 0.3
UnloadCard.BorderSizePixel = 0
UnloadCard.ZIndex = 21
UnloadCard.Parent = SettingsPanel
Corner(UnloadCard, 10)
Stroke(UnloadCard, Color3.fromRGB(80, 35, 35), 1, 0.5)

local UTitle = Instance.new("TextLabel")
UTitle.Size = UDim2.new(0.6, 0, 0, 22)
UTitle.Position = UDim2.new(0, 16, 0, 12)
UTitle.BackgroundTransparency = 1
UTitle.Font = Enum.Font.GothamBold
UTitle.Text = "Unload Script"
UTitle.TextColor3 = C.danger
UTitle.TextSize = 12
UTitle.TextXAlignment = Enum.TextXAlignment.Left
UTitle.ZIndex = 22
UTitle.Parent = UnloadCard

local UDesc = Instance.new("TextLabel")
UDesc.Size = UDim2.new(0.6, 0, 0, 14)
UDesc.Position = UDim2.new(0, 16, 0, 36)
UDesc.BackgroundTransparency = 1
UDesc.Font = Enum.Font.Gotham
UDesc.Text = "Remove GUI and all hooks"
UDesc.TextColor3 = C.textMuted
UDesc.TextSize = 10
UDesc.TextXAlignment = Enum.TextXAlignment.Left
UDesc.ZIndex = 22
UDesc.Parent = UnloadCard

local UBtn = Instance.new("TextButton")
UBtn.Size = UDim2.new(0, 90, 0, 36)
UBtn.Position = UDim2.new(1, -106, 0.5, -18)
UBtn.BackgroundColor3 = C.danger
UBtn.Font = Enum.Font.GothamBold
UBtn.Text = "UNLOAD"
UBtn.TextColor3 = C.text
UBtn.TextSize = 10
UBtn.AutoButtonColor = false
UBtn.ZIndex = 23
UBtn.Parent = UnloadCard
Corner(UBtn, 8)

local ConfirmCard = Instance.new("Frame")
ConfirmCard.Size = UDim2.new(1, -40, 0, 90)
ConfirmCard.Position = UDim2.new(0, 20, 0, 152)
ConfirmCard.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
ConfirmCard.BackgroundTransparency = 0.2
ConfirmCard.BorderSizePixel = 0
ConfirmCard.ZIndex = 21
ConfirmCard.Visible = false
ConfirmCard.Parent = SettingsPanel
Corner(ConfirmCard, 10)
Stroke(ConfirmCard, Color3.fromRGB(120, 40, 40), 1, 0.3)

local CText = Instance.new("TextLabel")
CText.Size = UDim2.new(1, -20, 0, 36)
CText.Position = UDim2.new(0, 12, 0, 8)
CText.BackgroundTransparency = 1
CText.Font = Enum.Font.GothamBold
CText.Text = "Are you sure? This will remove everything."
CText.TextColor3 = C.danger
CText.TextSize = 11
CText.TextWrapped = true
CText.ZIndex = 22
CText.Parent = ConfirmCard

local CYes = Instance.new("TextButton")
CYes.Size = UDim2.new(0.45, 0, 0, 30)
CYes.Position = UDim2.new(0, 10, 1, -40)
CYes.BackgroundColor3 = C.danger
CYes.Font = Enum.Font.GothamBold
CYes.Text = "YES"
CYes.TextColor3 = C.text
CYes.TextSize = 11
CYes.AutoButtonColor = false
CYes.ZIndex = 23
CYes.Parent = ConfirmCard
Corner(CYes, 8)

local CNo = Instance.new("TextButton")
CNo.Size = UDim2.new(0.45, 0, 0, 30)
CNo.Position = UDim2.new(0.55, -10, 1, -40)
CNo.BackgroundColor3 = C.surface
CNo.Font = Enum.Font.GothamBold
CNo.Text = "NO"
CNo.TextColor3 = C.text
CNo.TextSize = 11
CNo.AutoButtonColor = false
CNo.ZIndex = 23
CNo.Parent = ConfirmCard
Corner(CNo, 8)
Stroke(CNo, C.border, 1, 0.5)

local settingsOpen = false
local function OpenSettings()
    settingsOpen = true; SettingsPanel.Visible = true; SettingsPanel.Position = UDim2.new(1, 10, 0, 0)
    SmoothTween(SettingsPanel, {Position = UDim2.new(0, 0, 0, 0)}, 0.35)
end
local function CloseSettings()
    settingsOpen = false
    SmoothTween(SettingsPanel, {Position = UDim2.new(1, 10, 0, 0)}, 0.3)
    task.delay(0.32, function() if not settingsOpen then SettingsPanel.Visible = false; ConfirmCard.Visible = false end end)
end

local function HoverBtn(btn, hoverBg, normalBg)
    btn.MouseEnter:Connect(function() SmoothTween(btn, {BackgroundColor3 = hoverBg, BackgroundTransparency = 0.1}, 0.15) end)
    btn.MouseLeave:Connect(function() SmoothTween(btn, {BackgroundColor3 = normalBg, BackgroundTransparency = 0.3}, 0.15) end)
end
HoverBtn(SettingsBtn, C.surfaceHov, C.surface)
HoverBtn(CloseBtn, Color3.fromRGB(80, 30, 30), C.dangerBg)

SettingsBtn.MouseButton1Click:Connect(function() if settingsOpen then CloseSettings() else OpenSettings() end end)
SPClose.MouseButton1Click:Connect(CloseSettings)
UBtn.MouseButton1Click:Connect(function() ConfirmCard.Visible = true end)
CNo.MouseButton1Click:Connect(function() ConfirmCard.Visible = false end)
CYes.MouseButton1Click:Connect(function()
    Running = false; FlingActive = false
    DisableInvisible()
    for _, cn in pairs(allConnections) do pcall(function() cn:Disconnect() end) end
    for p, _ in pairs(espDrawings) do pcall(function() for _, d in pairs(espDrawings[p]) do d.Visible = false; d:Remove() end end) end
    espDrawings = {}
    pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
    pcall(function() local h = GetHum(); if h then h.WalkSpeed = 16; h.JumpPower = 50 end end)
    SmoothTween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 1.5, 0), BackgroundTransparency = 1}, 0.4)
    SmoothTween(Blur, {BackgroundTransparency = 1}, 0.3)
    task.delay(0.45, function() pcall(function() SG:Destroy() end) end)
    pcall(function() local bg2 = game.CoreGui:FindFirstChild("BindIndicatorGui"); if bg2 then bg2:Destroy() end end)
end)

-- TABS
local tabs = {"Combat", "Movement", "Fling", "Teleport", "ESP", "Misc"}
local icons = {"⚔", "»", "~", "◆", "◉", "⚙"}
local TabPages, TabBtns = {}, {}
local ActiveTab = "Combat"

local function MakePage()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.border
    page.ScrollBarImageTransparency = 0.3
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.BorderSizePixel = 0
    page.Visible = false
    page.ZIndex = 3
    page.Parent = ContentArea
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14); pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16); pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = page
    local lay = Instance.new("UIListLayout"); lay.Padding = UDim.new(0, 8); lay.Parent = page
    return page
end

for _, name in ipairs(tabs) do TabPages[name] = MakePage() end

local ActiveIndicator = Instance.new("Frame")
ActiveIndicator.Size = UDim2.new(0, 3, 0, 18)
ActiveIndicator.BackgroundColor3 = C.accent
ActiveIndicator.BorderSizePixel = 0
ActiveIndicator.ZIndex = 5
ActiveIndicator.Parent = Sidebar
ActiveIndicator.Position = UDim2.new(0, -4, 0, 15)
Corner(ActiveIndicator, 2)

local function SetTab(name)
    for _, page in pairs(TabPages) do page.Visible = false end
    if TabPages[name] then TabPages[name].Visible = true end
    for _, tName in ipairs(tabs) do
        local btn = TabBtns[tName]
        if btn then
            if tName == name then
                SmoothTween(btn, {BackgroundColor3 = C.surface, BackgroundTransparency = 0}, 0.2)
                SmoothTween(btn:FindFirstChild("Label"), {TextColor3 = C.text}, 0.2)
                SmoothTween(btn:FindFirstChild("Icon"), {TextColor3 = C.accent}, 0.2)
                local yPos = btn.AbsolutePosition.Y - Sidebar.AbsolutePosition.Y + btn.AbsoluteSize.Y/2 - 9
                SmoothTween(ActiveIndicator, {Position = UDim2.new(0, -4, 0, yPos)}, 0.3)
            else
                SmoothTween(btn, {BackgroundTransparency = 1}, 0.2)
                SmoothTween(btn:FindFirstChild("Label"), {TextColor3 = C.textMuted}, 0.2)
                SmoothTween(btn:FindFirstChild("Icon"), {TextColor3 = C.textMuted}, 0.2)
            end
        end
    end
    ActiveTab = name
    StatusText.Text = "Ready · " .. name
end

for i, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = C.surface
    btn.BackgroundTransparency = i == 1 and 0 or 1
    btn.Font = Enum.Font.Gotham
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 4
    btn.Parent = Sidebar
    Corner(btn, 8)

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 20, 1, 0)
    icon.Position = UDim2.new(0, 10, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBold
    icon.Text = icons[i]
    icon.TextColor3 = i == 1 and C.accent or C.textMuted
    icon.TextSize = 12
    icon.ZIndex = 5
    icon.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, -38, 1, 0)
    lbl.Position = UDim2.new(0, 34, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = name
    lbl.TextColor3 = i == 1 and C.text or C.textMuted
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 5
    lbl.Parent = btn

    TabBtns[name] = btn

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then SmoothTween(btn, {BackgroundTransparency = 0.5, BackgroundColor3 = C.surfaceHov}, 0.15) end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then SmoothTween(btn, {BackgroundTransparency = 1}, 0.15) end
    end)
    btn.MouseButton1Click:Connect(function() SetTab(name) end)
end

TabPages[tabs[1]].Visible = true

-- BIND INDICATOR
local BindIndicatorGui = Instance.new("ScreenGui")
BindIndicatorGui.Name = "BindIndicatorGui"
BindIndicatorGui.ResetOnSpawn = false
BindIndicatorGui.Parent = game.CoreGui

local BindFrame = Instance.new("Frame")
BindFrame.Size = UDim2.new(0, 170, 0, 0)
BindFrame.Position = UDim2.new(1, -185, 0.5, 0)
BindFrame.BackgroundTransparency = 1
BindFrame.AutomaticSize = Enum.AutomaticSize.Y
BindFrame.Parent = BindIndicatorGui

local BindLayout = Instance.new("UIListLayout")
BindLayout.Padding = UDim.new(0, 4)
BindLayout.SortOrder = Enum.SortOrder.LayoutOrder
BindLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
BindLayout.Parent = BindFrame

local activeIndicators = {}
local toggleCallbacks = {}

local function ShowBindIndicator(name)
    if activeIndicators[name] then return end
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 0, 0, 28)
    f.BackgroundColor3 = C.bg
    f.BackgroundTransparency = 0.15
    f.BorderSizePixel = 0
    f.Parent = BindFrame
    Corner(f, 8)
    Stroke(f, C.border, 1, 0.4)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.Position = UDim2.new(0, 10, 0.5, -3)
    dot.BackgroundColor3 = C.accent
    dot.BorderSizePixel = 0
    dot.Parent = f
    Corner(dot, 3)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.Text = name
    lbl.TextColor3 = C.text
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    BounceTween(f, {Size = UDim2.new(0, 160, 0, 28)}, 0.3)
    activeIndicators[name] = f
end

local function HideBindIndicator(name)
    local f = activeIndicators[name]; if not f then return end
    activeIndicators[name] = nil
    SmoothTween(f, {Size = UDim2.new(0, 0, 0, 28), BackgroundTransparency = 1}, 0.2)
    task.delay(0.22, function() pcall(function() f:Destroy() end) end)
end

table.insert(allConnections, UIS.InputBegan:Connect(function(input, gp)
    if not Running or gp or bindPopupActive then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kn = tostring(input.KeyCode):gsub("Enum.KeyCode.", "")
    for fn, bk in pairs(Binds) do if bk == kn then local cb = toggleCallbacks[fn]; if cb then cb() end end end
end))

-- UI COMPONENTS
local function SectionLabel(parent, text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundTransparency = 1
    f.Parent = parent
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text
    lbl.TextColor3 = C.textMuted
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f
end

local function CloseBindPopup()
    if currentBindPopup then
        pcall(function() currentBindPopup.frame:Destroy() end)
        if currentBindPopup.conn then pcall(function() currentBindPopup.conn:Disconnect() end) end
        currentBindPopup = nil; bindPopupActive = false; BindListening = nil
    end
end

local function Toggle(parent, name, desc, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 56)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, C.border, 1, 0.6)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -80, 0, 20)
    nameL.Position = UDim2.new(0, 16, 0, 10)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamMedium
    nameL.Text = name
    nameL.TextColor3 = C.text
    nameL.TextSize = 12
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = frame

    local descL = Instance.new("TextLabel")
    descL.Size = UDim2.new(1, -80, 0, 14)
    descL.Position = UDim2.new(0, 16, 0, 32)
    descL.BackgroundTransparency = 1
    descL.Font = Enum.Font.Gotham
    descL.Text = desc
    descL.TextColor3 = C.textMuted
    descL.TextSize = 10
    descL.TextXAlignment = Enum.TextXAlignment.Left
    descL.Parent = frame

    local togBg = Instance.new("Frame")
    togBg.Size = UDim2.new(0, 44, 0, 22)
    togBg.Position = UDim2.new(1, -58, 0.5, -11)
    togBg.BackgroundColor3 = C.toggleOff
    togBg.BorderSizePixel = 0
    togBg.Parent = frame
    Corner(togBg, 11)
    Stroke(togBg, C.borderLight, 1.5, 0.3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 4, 0.5, -7)
    knob.BackgroundColor3 = C.knobOff
    knob.BorderSizePixel = 0
    knob.Parent = togBg
    Corner(knob, 7)

    local enabled = false
    local stateKey = ToggleStateMap[name]
    if stateKey and State[stateKey] == true then enabled = true end

    if enabled then
        togBg.BackgroundColor3 = C.toggleOn
        knob.Position = UDim2.new(1, -18, 0.5, -7)
        knob.BackgroundColor3 = C.knobOn
    end

    local bindLabel = Instance.new("TextLabel")
    bindLabel.Size = UDim2.new(0, 80, 0, 14)
    bindLabel.Position = UDim2.new(1, -146, 0.5, -7)
    bindLabel.BackgroundTransparency = 1
    bindLabel.Font = Enum.Font.GothamMedium
    bindLabel.TextColor3 = C.textMuted
    bindLabel.TextSize = 9
    bindLabel.TextXAlignment = Enum.TextXAlignment.Right
    bindLabel.Parent = frame
    bindLabel.Text = Binds[name] and ("["..Binds[name].."]") or ""
    bindLabels[name] = bindLabel

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = frame

    local function setEnabled(val)
        enabled = val
        if stateKey then State[stateKey] = val end

        if enabled then
            SmoothTween(togBg, {BackgroundColor3 = C.toggleOn}, 0.25)
            BounceTween(knob, {Position = UDim2.new(1, -18, 0.5, -7), Size = UDim2.new(0, 14, 0, 14)}, 0.35)
            SmoothTween(knob, {BackgroundColor3 = C.knobOn}, 0.2)
            SmoothTween(frame, {BackgroundTransparency = 0.05}, 0.2)
        else
            SmoothTween(togBg, {BackgroundColor3 = C.toggleOff}, 0.25)
            BounceTween(knob, {Position = UDim2.new(0, 4, 0.5, -7), Size = UDim2.new(0, 14, 0, 14)}, 0.35)
            SmoothTween(knob, {BackgroundColor3 = C.knobOff}, 0.2)
            SmoothTween(frame, {BackgroundTransparency = 0.2}, 0.2)
        end

        task.spawn(function()
            Tween(knob, {Size = UDim2.new(0, 18, 0, 14)}, 0.1)
            task.wait(0.12)
            Tween(knob, {Size = UDim2.new(0, 14, 0, 14)}, 0.15)
        end)

        callback(enabled)
        SaveSettings()
    end

    btn.MouseButton1Click:Connect(function()
        if bindPopupActive then return end
        setEnabled(not enabled)
    end)

    btn.MouseButton2Click:Connect(function()
        CloseBindPopup()
        bindPopupActive = true; BindListening = name

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, 240, 0, 80)
        popup.Position = UDim2.new(0.5, -140, 0.5, -50)
        popup.BackgroundColor3 = C.bg
        popup.BorderSizePixel = 0
        popup.ZIndex = 50
        popup.BackgroundTransparency = 0.5
        popup.Parent = Main
        Corner(popup, 12)
        Stroke(popup, C.borderLight, 1, 0.3)

        BounceTween(popup, {Size = UDim2.new(0, 280, 0, 100), BackgroundTransparency = 0.05}, 0.35)

        local pt = Instance.new("TextLabel")
        pt.Size = UDim2.new(1, 0, 0, 30)
        pt.Position = UDim2.new(0, 0, 0, 12)
        pt.BackgroundTransparency = 1
        pt.Font = Enum.Font.GothamBold
        pt.Text = "Bind key for \"" .. name .. "\""
        pt.TextColor3 = C.text
        pt.TextSize = 12
        pt.ZIndex = 51
        pt.Parent = popup

        local ps = Instance.new("TextLabel")
        ps.Size = UDim2.new(1, 0, 0, 16)
        ps.Position = UDim2.new(0, 0, 0, 44)
        ps.BackgroundTransparency = 1
        ps.Font = Enum.Font.Gotham
        ps.Text = "Press any key | Backspace = remove | Esc = cancel"
        ps.TextColor3 = C.textMuted
        ps.TextSize = 9
        ps.ZIndex = 51
        ps.Parent = popup

        local pw = Instance.new("TextLabel")
        pw.Size = UDim2.new(1, 0, 0, 16)
        pw.Position = UDim2.new(0, 0, 0, 68)
        pw.BackgroundTransparency = 1
        pw.Font = Enum.Font.GothamMedium
        pw.Text = "Waiting..."
        pw.TextColor3 = C.accent
        pw.TextSize = 10
        pw.ZIndex = 51
        pw.Parent = popup

        local conn
        conn = UIS.InputBegan:Connect(function(input2, gp2)
            if gp2 then return end
            if input2.UserInputType == Enum.UserInputType.Keyboard then
                if input2.KeyCode == Enum.KeyCode.Backspace then
                    Binds[name] = nil; bindLabel.Text = ""; CloseBindPopup(); SaveSettings(); return
                end
                if input2.KeyCode == Enum.KeyCode.Delete then return end
                if input2.KeyCode == Enum.KeyCode.Escape then CloseBindPopup(); return end
                local kn2 = tostring(input2.KeyCode):gsub("Enum.KeyCode.", "")
                Binds[name] = kn2; bindLabel.Text = "["..kn2.."]"; CloseBindPopup(); SaveSettings()
            end
        end)
        currentBindPopup = {frame = popup, conn = conn, name = name}
    end)

    btn.MouseEnter:Connect(function() SmoothTween(frame, {BackgroundColor3 = C.cardHov}, 0.15) end)
    btn.MouseLeave:Connect(function() SmoothTween(frame, {BackgroundColor3 = C.card}, 0.15) end)

    return setEnabled
end

local function SliderInput(parent, name, minV, maxV, def, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 70)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = parent
    Corner(frame, 10)
    Stroke(frame, C.border, 1, 0.6)

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(0.55, 0, 0, 20)
    nameL.Position = UDim2.new(0, 16, 0, 12)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamMedium
    nameL.Text = name
    nameL.TextColor3 = C.text
    nameL.TextSize = 12
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = frame

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(0, 60, 0, 26)
    inputBox.Position = UDim2.new(1, -76, 0, 9)
    inputBox.BackgroundColor3 = C.surface
    inputBox.BackgroundTransparency = 0.3
    inputBox.Font = Enum.Font.GothamMedium
    inputBox.Text = tostring(def)
    inputBox.TextColor3 = C.text
    inputBox.TextSize = 11
    inputBox.ClearTextOnFocus = true
    inputBox.BorderSizePixel = 0
    inputBox.Parent = frame
    Corner(inputBox, 8)
    Stroke(inputBox, C.border, 1, 0.5)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -32, 0, 4)
    track.Position = UDim2.new(0, 16, 0, 52)
    track.BackgroundColor3 = C.toggleOff
    track.BorderSizePixel = 0
    track.Parent = frame
    Corner(track, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((def-minV)/(maxV-minV), 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = C.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    Corner(fill, 2)

    local sknob = Instance.new("Frame")
    sknob.Size = UDim2.new(0, 16, 0, 16)
    sknob.AnchorPoint = Vector2.new(0.5, 0.5)
    sknob.Position = UDim2.new(math.clamp((def-minV)/(maxV-minV), 0, 1), 0, 0.5, 0)
    sknob.BackgroundColor3 = C.accent
    sknob.BorderSizePixel = 0
    sknob.ZIndex = 4
    sknob.Parent = track
    Corner(sknob, 8)
    Stroke(sknob, C.bg, 2, 0.3)

    local dragBtn = Instance.new("TextButton")
    dragBtn.Size = UDim2.new(1, 0, 5, 0)
    dragBtn.Position = UDim2.new(0, 0, -2, 0)
    dragBtn.BackgroundTransparency = 1
    dragBtn.Text = ""
    dragBtn.Parent = track

    local currentVal = def
    local function applyValue(v)
        v = math.clamp(math.floor(v+0.5), minV, maxV)
        currentVal = v
        local pct = (v-minV)/(maxV-minV)
        SmoothTween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.08)
        SmoothTween(sknob, {Position = UDim2.new(pct, 0, 0.5, 0)}, 0.08)
        inputBox.Text = tostring(v)
        callback(v); SaveSettings()
    end

    inputBox.FocusLost:Connect(function()
        local n = tonumber(inputBox.Text)
        if n then applyValue(n) else inputBox.Text = tostring(currentVal) end
    end)

    local dragging = false
    dragBtn.MouseButton1Down:Connect(function() dragging = true
        SmoothTween(sknob, {Size = UDim2.new(0, 18, 0, 18)}, 0.1)
    end)
    table.insert(allConnections, UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            SmoothTween(sknob, {Size = UDim2.new(0, 16, 0, 16)}, 0.15)
        end
    end))
    table.insert(allConnections, UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local aP, aS = track.AbsolutePosition.X, track.AbsoluteSize.X
            if aS > 0 then applyValue(minV + (maxV-minV) * math.clamp((i.Position.X-aP)/aS, 0, 1)) end
        end
    end))
end

-- BUILD TABS

-- COMBAT
local CP = TabPages.Combat
SectionLabel(CP, "AUTO-ATTACK")
local setKillAura = Toggle(CP, "Kill Aura", "Auto-attack nearby players with melee", function(s)
    State.KillAura = s; if s then task.spawn(KillAura) end
    if s then ShowBindIndicator("Kill Aura") else HideBindIndicator("Kill Aura") end
end)
toggleCallbacks["Kill Aura"] = function() if setKillAura then setKillAura(not State.KillAura) end end

SectionLabel(CP, "RANGE")
local setReach = Toggle(CP, "Reach", "Extend sword hit distance", function(s)
    State.Reach = s
    if not s then pcall(function() local c=LP.Character; if c then local t=c:FindFirstChildOfClass("Tool")
        if t then local h=t:FindFirstChild("Handle"); if h then h.Size=Vector3.new(1,1,4) end end end end) end
    if s then ShowBindIndicator("Reach") else HideBindIndicator("Reach") end
end)
toggleCallbacks["Reach"] = function() if setReach then setReach(not State.Reach) end end

-- MOVEMENT
local MP = TabPages.Movement
SectionLabel(MP, "PARAMETERS")
SliderInput(MP, "Walk Speed", 16, 250, State.Speed, function(v)
    State.Speed = v; local h = GetHum(); if h then h.WalkSpeed = v end
end)
SliderInput(MP, "Jump Power", 50, 400, State.JumpPower, function(v)
    State.JumpPower = v; local h = GetHum(); if h then h.JumpPower = v end
end)

SectionLabel(MP, "MODES")
local setInfJump = Toggle(MP, "Infinite Jump", "Jump in air with Space (BodyVelocity)", function(s)
    State.InfiniteJump = s
    if s then ShowBindIndicator("Infinite Jump") else HideBindIndicator("Infinite Jump") end
end)
toggleCallbacks["Infinite Jump"] = function() if setInfJump then setInfJump(not State.InfiniteJump) end end

SectionLabel(MP, "STEALTH")
local setInvisible = Toggle(MP, "Invisible", "Hide from other players (ghost mode)", function(s)
    State.Invisible = s
    if s then
        EnableInvisible()
        ShowBindIndicator("Invisible")
    else
        DisableInvisible()
        HideBindIndicator("Invisible")
    end
end)
toggleCallbacks["Invisible"] = function() if setInvisible then setInvisible(not State.Invisible) end end

SectionLabel(MP, "COLLISION")
local setNoclip = Toggle(MP, "Noclip", "Pass through walls and objects", function(s)
    State.Noclip = s
    if s then ShowBindIndicator("Noclip") else HideBindIndicator("Noclip") end
end)
toggleCallbacks["Noclip"] = function() if setNoclip then setNoclip(not State.Noclip) end end

-- FLING
local FP = TabPages.Fling

local flingStatusF = Instance.new("Frame")
flingStatusF.Size = UDim2.new(1, 0, 0, 34)
flingStatusF.BackgroundColor3 = C.card
flingStatusF.BackgroundTransparency = 0.2
flingStatusF.BorderSizePixel = 0
flingStatusF.Parent = FP
Corner(flingStatusF, 8)
Stroke(flingStatusF, C.border, 1, 0.6)

local flingStatusL = Instance.new("TextLabel")
flingStatusL.Size = UDim2.new(1, -16, 1, 0)
flingStatusL.Position = UDim2.new(0, 12, 0, 0)
flingStatusL.BackgroundTransparency = 1
flingStatusL.Font = Enum.Font.GothamMedium
flingStatusL.Text = "Select a target"
flingStatusL.TextColor3 = C.textMuted
flingStatusL.TextSize = 11
flingStatusL.TextXAlignment = Enum.TextXAlignment.Left
flingStatusL.Parent = flingStatusF

local flingBtnRow = Instance.new("Frame")
flingBtnRow.Size = UDim2.new(1, 0, 0, 34)
flingBtnRow.BackgroundTransparency = 1
flingBtnRow.Parent = FP

local flingBtnRowLay = Instance.new("UIListLayout")
flingBtnRowLay.FillDirection = Enum.FillDirection.Horizontal
flingBtnRowLay.Padding = UDim.new(0, 6)
flingBtnRowLay.Parent = flingBtnRow

local function FluentBtn(parent, text, bg, tc, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 100, 0, 34)
    b.BackgroundColor3 = bg; b.BackgroundTransparency = 0.1
    b.Font = Enum.Font.GothamBold; b.Text = text; b.TextColor3 = tc; b.TextSize = 11
    b.AutoButtonColor = false; b.Parent = parent
    Corner(b, 8); Stroke(b, C.border, 1, 0.5)
    b.MouseEnter:Connect(function() SmoothTween(b, {BackgroundTransparency = 0}, 0.12) end)
    b.MouseLeave:Connect(function() SmoothTween(b, {BackgroundTransparency = 0.1}, 0.12) end)
    return b
end

local StartFBtn = FluentBtn(flingBtnRow, "START", C.accent, C.bg, 110)
local StopFBtn = FluentBtn(flingBtnRow, "STOP", C.dangerBg, C.danger, 100)
local FlingAllFBtn = FluentBtn(flingBtnRow, "ALL", C.card, C.text, 80)

local selFrame = Instance.new("Frame")
selFrame.Size = UDim2.new(1, 0, 0, 30)
selFrame.BackgroundColor3 = C.card; selFrame.BackgroundTransparency = 0.3
selFrame.BorderSizePixel = 0; selFrame.Parent = FP
Corner(selFrame, 8); Stroke(selFrame, C.border, 1, 0.6)

local selText = Instance.new("TextLabel")
selText.Size = UDim2.new(1, -16, 1, 0); selText.Position = UDim2.new(0, 12, 0, 0)
selText.BackgroundTransparency = 1; selText.Font = Enum.Font.GothamMedium
selText.Text = "Target: none"; selText.TextColor3 = C.textMuted; selText.TextSize = 10
selText.TextXAlignment = Enum.TextXAlignment.Left; selText.Parent = selFrame

SectionLabel(FP, "PLAYERS")

local selRow = Instance.new("Frame")
selRow.Size = UDim2.new(1, 0, 0, 28); selRow.BackgroundTransparency = 1; selRow.Parent = FP
local selRowLay = Instance.new("UIListLayout"); selRowLay.FillDirection = Enum.FillDirection.Horizontal
selRowLay.Padding = UDim.new(0, 6); selRowLay.Parent = selRow

local selAllBtn = FluentBtn(selRow, "Select All", C.card, C.textSec, 120)
local deselAllBtn = FluentBtn(selRow, "Deselect All", C.card, C.textSec, 120)

local flingPlrCont = Instance.new("Frame")
flingPlrCont.Size = UDim2.new(1, 0, 0, 0); flingPlrCont.AutomaticSize = Enum.AutomaticSize.Y
flingPlrCont.BackgroundTransparency = 1; flingPlrCont.Parent = FP
local flingPlrLay = Instance.new("UIListLayout"); flingPlrLay.Padding = UDim.new(0, 4); flingPlrLay.Parent = flingPlrCont

local refreshFBtn = FluentBtn(FP, "Refresh", C.card, C.textSec, 0)
refreshFBtn.Size = UDim2.new(1, 0, 0, 28)

local flingCheckboxes, flingPlayerBtns = {}, {}

local function RefreshFlingList()
    for _, b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end
    flingPlayerBtns = {}; flingCheckboxes = {}
    local plrs = Players:GetPlayers()
    table.sort(plrs, function(a, b2) return a.Name:lower() < b2.Name:lower() end)
    for _, plr in ipairs(plrs) do
        if plr ~= LP then
            local isC = SelectedTargets[plr.Name] ~= nil
            local isT = SelectedFlingTarget == plr

            local pF = Instance.new("Frame")
            pF.Size = UDim2.new(1, 0, 0, 42)
            pF.BackgroundColor3 = isT and C.surfaceHov or (isC and C.surface or C.card)
            pF.BackgroundTransparency = 0.2
            pF.BorderSizePixel = 0; pF.Parent = flingPlrCont
            Corner(pF, 8); Stroke(pF, isT and C.accent or C.border, 1, isT and 0.2 or 0.6)

            local av = Instance.new("Frame")
            av.Size = UDim2.new(0, 28, 0, 28); av.Position = UDim2.new(0, 8, 0.5, -14)
            av.BackgroundColor3 = Color3.fromHSV((plr.UserId%100)/100, 0.2, 0.65)
            av.BorderSizePixel = 0; av.Parent = pF; Corner(av, 14)

            local avL = Instance.new("TextLabel")
            avL.Size = UDim2.new(1, 0, 1, 0); avL.BackgroundTransparency = 1
            avL.Font = Enum.Font.GothamBlack; avL.Text = plr.Name:sub(1,1):upper()
            avL.TextColor3 = C.text; avL.TextSize = 12; avL.Parent = av

            local nL = Instance.new("TextLabel")
            nL.Size = UDim2.new(1, -100, 0, 16); nL.Position = UDim2.new(0, 44, 0, 6)
            nL.BackgroundTransparency = 1; nL.Font = Enum.Font.GothamMedium
            nL.Text = plr.DisplayName; nL.TextColor3 = C.text; nL.TextSize = 11
            nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = pF

            local uL = Instance.new("TextLabel")
            uL.Size = UDim2.new(1, -100, 0, 12); uL.Position = UDim2.new(0, 44, 0, 24)
            uL.BackgroundTransparency = 1; uL.Font = Enum.Font.Gotham
            uL.Text = "@"..plr.Name; uL.TextColor3 = C.textMuted; uL.TextSize = 9
            uL.TextXAlignment = Enum.TextXAlignment.Left; uL.Parent = pF

            local tBtn = Instance.new("TextButton")
            tBtn.Size = UDim2.new(0, 36, 0, 24); tBtn.Position = UDim2.new(1, -44, 0.5, -12)
            tBtn.BackgroundColor3 = isT and C.accent or C.surface
            tBtn.BackgroundTransparency = isT and 0 or 0.3
            tBtn.Font = Enum.Font.GothamBold; tBtn.Text = "T"
            tBtn.TextColor3 = isT and C.bg or C.textMuted; tBtn.TextSize = 10
            tBtn.AutoButtonColor = false; tBtn.Parent = pF
            Corner(tBtn, 6); Stroke(tBtn, C.border, 1, 0.5)

            flingCheckboxes[plr.Name] = {frame = pF, nameL = nL, tBtn = tBtn}

            local clickArea = Instance.new("TextButton")
            clickArea.Size = UDim2.new(1, -52, 1, 0); clickArea.BackgroundTransparency = 1
            clickArea.Text = ""; clickArea.Parent = pF

            local cp = plr
            clickArea.MouseButton1Click:Connect(function()
                if SelectedTargets[cp.Name] then
                    SelectedTargets[cp.Name] = nil
                    SmoothTween(pF, {BackgroundColor3 = C.card}, 0.15)
                else
                    SelectedTargets[cp.Name] = cp
                    SmoothTween(pF, {BackgroundColor3 = C.surface}, 0.15)
                end
                local cnt = 0; for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
                flingStatusL.Text = cnt > 0 and ("Selected: "..cnt) or "Select a target"
                flingStatusL.TextColor3 = cnt > 0 and C.text or C.textMuted
            end)

            tBtn.MouseButton1Click:Connect(function()
                if SelectedFlingTarget == cp then
                    SelectedFlingTarget = nil; selText.Text = "Target: none"; selText.TextColor3 = C.textMuted
                    SmoothTween(tBtn, {BackgroundColor3 = C.surface, BackgroundTransparency = 0.3}, 0.15)
                    tBtn.TextColor3 = C.textMuted
                else
                    for _, data in pairs(flingCheckboxes) do
                        SmoothTween(data.tBtn, {BackgroundColor3 = C.surface, BackgroundTransparency = 0.3}, 0.15)
                        data.tBtn.TextColor3 = C.textMuted
                    end
                    SelectedFlingTarget = cp
                    selText.Text = cp.DisplayName.." (@"..cp.Name..")"
                    selText.TextColor3 = C.text
                    SmoothTween(tBtn, {BackgroundColor3 = C.accent, BackgroundTransparency = 0}, 0.15)
                    tBtn.TextColor3 = C.bg
                end
            end)

            clickArea.MouseEnter:Connect(function() SmoothTween(pF, {BackgroundTransparency = 0.05}, 0.1) end)
            clickArea.MouseLeave:Connect(function() SmoothTween(pF, {BackgroundTransparency = 0.2}, 0.1) end)

            table.insert(flingPlayerBtns, pF)
        end
    end
    if #flingPlayerBtns == 0 then
        local eL = Instance.new("TextLabel")
        eL.Size = UDim2.new(1, 0, 0, 30); eL.BackgroundTransparency = 1
        eL.Font = Enum.Font.Gotham; eL.Text = "No other players"; eL.TextColor3 = C.textMuted
        eL.TextSize = 11; eL.Parent = flingPlrCont
        table.insert(flingPlayerBtns, eL)
    end
end

StartFBtn.MouseButton1Click:Connect(function()
    local cnt = 0; for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
    if cnt == 0 then
        flingStatusL.Text = "Select targets first!"; flingStatusL.TextColor3 = C.danger
        task.delay(1.5, function() if not FlingActive then flingStatusL.Text = "Select a target"; flingStatusL.TextColor3 = C.textMuted end end)
        return
    end
    FlingActive = true; flingStatusL.Text = "Flinging: "..cnt; flingStatusL.TextColor3 = C.danger
    task.spawn(function()
        while FlingActive and Running do
            for n2, pl in pairs(SelectedTargets) do if not pl or not pl.Parent then SelectedTargets[n2] = nil end end
            local c2 = 0; for _ in pairs(SelectedTargets) do c2 = c2 + 1 end
            if c2 == 0 then FlingActive = false; break end
            flingStatusL.Text = "Flinging: "..c2
            for _, pl in pairs(SelectedTargets) do
                if FlingActive and Running and pl and pl.Parent then pcall(function() SkidFling(pl) end); task.wait(0.1) end
            end
            task.wait(0.3)
        end
        flingStatusL.Text = "Select a target"; flingStatusL.TextColor3 = C.textMuted
    end)
end)
StopFBtn.MouseButton1Click:Connect(function() FlingActive = false; flingStatusL.Text = "Stopped"; flingStatusL.TextColor3 = C.textMuted end)
FlingAllFBtn.MouseButton1Click:Connect(function() task.spawn(FlingAll) end)
selAllBtn.MouseButton1Click:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then SelectedTargets[p.Name] = p end end
    local cnt = 0; for _ in pairs(SelectedTargets) do cnt = cnt + 1 end
    flingStatusL.Text = "Selected: "..cnt; flingStatusL.TextColor3 = C.text
    RefreshFlingList()
end)
deselAllBtn.MouseButton1Click:Connect(function()
    SelectedTargets = {}; flingStatusL.Text = "Select a target"; flingStatusL.TextColor3 = C.textMuted
    RefreshFlingList()
end)
refreshFBtn.MouseButton1Click:Connect(RefreshFlingList)

-- TELEPORT
local TPP = TabPages.Teleport
SectionLabel(TPP, "LOCATIONS")

local function TpCard(parent, name, pos)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 40); f.BackgroundColor3 = C.card; f.BackgroundTransparency = 0.2
    f.BorderSizePixel = 0; f.Parent = parent; Corner(f, 8); Stroke(f, C.border, 1, 0.6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, 0, 1, 0); l.Position = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamMedium; l.Text = name
    l.TextColor3 = C.text; l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 72, 0, 26); b.Position = UDim2.new(1, -82, 0.5, -13)
    b.BackgroundColor3 = C.accent; b.BackgroundTransparency = 0.05
    b.Font = Enum.Font.GothamBold; b.Text = "TP"; b.TextColor3 = C.bg; b.TextSize = 10
    b.AutoButtonColor = false; b.Parent = f; Corner(b, 6)
    b.MouseEnter:Connect(function() SmoothTween(b, {BackgroundTransparency = 0}, 0.1) end)
    b.MouseLeave:Connect(function() SmoothTween(b, {BackgroundTransparency = 0.05}, 0.1) end)
    b.MouseButton1Click:Connect(function()
        pcall(function() local hr = GetHRP(); if hr then hr.CFrame = CFrame.new(pos) end end)
    end)
    f.MouseEnter:Connect(function() SmoothTween(f, {BackgroundTransparency = 0.05}, 0.1) end)
    f.MouseLeave:Connect(function() SmoothTween(f, {BackgroundTransparency = 0.2}, 0.1) end)
end

TpCard(TPP, "Spawn", Vector3.new(0, 50, 0))

SectionLabel(TPP, "TO PLAYER")

local tpPlrCont = Instance.new("Frame")
tpPlrCont.Size = UDim2.new(1, 0, 0, 0); tpPlrCont.AutomaticSize = Enum.AutomaticSize.Y
tpPlrCont.BackgroundTransparency = 1; tpPlrCont.Parent = TPP
local tpPlrLay = Instance.new("UIListLayout"); tpPlrLay.Padding = UDim.new(0, 4); tpPlrLay.Parent = tpPlrCont
local tpPlrBtns = {}

local function RefreshTpList()
    for _, b2 in pairs(tpPlrBtns) do pcall(function() b2:Destroy() end) end; tpPlrBtns = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local f = Instance.new("Frame")
            f.Size = UDim2.new(1, 0, 0, 38); f.BackgroundColor3 = C.card; f.BackgroundTransparency = 0.2
            f.BorderSizePixel = 0; f.Parent = tpPlrCont; Corner(f, 8); Stroke(f, C.border, 1, 0.6)
            local nL = Instance.new("TextLabel")
            nL.Size = UDim2.new(0.6, 0, 1, 0); nL.Position = UDim2.new(0, 14, 0, 0)
            nL.BackgroundTransparency = 1; nL.Font = Enum.Font.GothamMedium; nL.Text = plr.DisplayName
            nL.TextColor3 = C.text; nL.TextSize = 11; nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = f
            local tpB = Instance.new("TextButton")
            tpB.Size = UDim2.new(0, 72, 0, 24); tpB.Position = UDim2.new(1, -82, 0.5, -12)
            tpB.BackgroundColor3 = C.accent; tpB.BackgroundTransparency = 0.05
            tpB.Font = Enum.Font.GothamBold; tpB.Text = "TP"; tpB.TextColor3 = C.bg; tpB.TextSize = 10
            tpB.AutoButtonColor = false; tpB.Parent = f; Corner(tpB, 6)
            tpB.MouseEnter:Connect(function() SmoothTween(tpB, {BackgroundTransparency = 0}, 0.1) end)
            tpB.MouseLeave:Connect(function() SmoothTween(tpB, {BackgroundTransparency = 0.05}, 0.1) end)
            local cp = plr
            tpB.MouseButton1Click:Connect(function() pcall(function()
                local tc = cp.Character; local hr = GetHRP()
                if tc and tc:FindFirstChild("HumanoidRootPart") and hr then hr.CFrame = tc.HumanoidRootPart.CFrame * CFrame.new(0,0,-3) end
            end) end)
            f.MouseEnter:Connect(function() SmoothTween(f, {BackgroundTransparency = 0.05}, 0.1) end)
            f.MouseLeave:Connect(function() SmoothTween(f, {BackgroundTransparency = 0.2}, 0.1) end)
            table.insert(tpPlrBtns, f)
        end
    end
    if #tpPlrBtns == 0 then
        local eL = Instance.new("TextLabel"); eL.Size = UDim2.new(1, 0, 0, 30)
        eL.BackgroundTransparency = 1; eL.Font = Enum.Font.Gotham; eL.Text = "No other players"
        eL.TextColor3 = C.textMuted; eL.TextSize = 11; eL.Parent = tpPlrCont
        table.insert(tpPlrBtns, eL)
    end
end

local tpRefBtn = FluentBtn(TPP, "Refresh", C.card, C.textSec, 0)
tpRefBtn.Size = UDim2.new(1, 0, 0, 28)
tpRefBtn.MouseButton1Click:Connect(RefreshTpList)

-- ESP
local EP = TabPages.ESP
SectionLabel(EP, "VISIBILITY")
local setESP = Toggle(EP, "ESP", "See players through walls with boxes", function(s)
    State.ESP = s; if not s then for p, _ in pairs(espDrawings) do removeESP(p) end end
    if s then ShowBindIndicator("ESP") else HideBindIndicator("ESP") end
end)
toggleCallbacks["ESP"] = function() if setESP then setESP(not State.ESP) end end

-- MISC
local MiscP = TabPages.Misc
SectionLabel(MiscP, "AUTO")
local setDN = Toggle(MiscP, "Death Note TP", "Auto-teleport to death notes", function(s)
    State.DeathNoteTP = s; if s then StartDeathNoteTP() else if deathNoteConn then pcall(function() deathNoteConn:Disconnect() end); deathNoteConn = nil end end
    if s then ShowBindIndicator("Death Note TP") else HideBindIndicator("Death Note TP") end
end)
toggleCallbacks["Death Note TP"] = function() if setDN then setDN(not State.DeathNoteTP) end end

local setAS = Toggle(MiscP, "Auto Sword TP", "Auto-teleport to dropped swords", function(s)
    State.AutoSword = s; if s then StartAutoSword() else if autoSwordConn then pcall(function() autoSwordConn:Disconnect() end); autoSwordConn = nil end end
    if s then ShowBindIndicator("Auto Sword TP") else HideBindIndicator("Auto Sword TP") end
end)
toggleCallbacks["Auto Sword TP"] = function() if setAS then setAS(not State.AutoSword) end end

SectionLabel(MiscP, "PROTECTION")
local setAL = Toggle(MiscP, "Anti-Lava", "Remove all lava objects", function(s)
    State.AntiLava = s; if s then task.spawn(AntiLavaLoop) end
    if s then ShowBindIndicator("Anti-Lava") else HideBindIndicator("Anti-Lava") end
end)
toggleCallbacks["Anti-Lava"] = function() if setAL then setAL(not State.AntiLava) end end

local setAV = Toggle(MiscP, "Anti-Void", "Teleport to safety on fall", function(s)
    State.AntiVoid = s; if s then StartAntiVoid() end
    if s then ShowBindIndicator("Anti-Void") else HideBindIndicator("Anti-Void") end
end)
toggleCallbacks["Anti-Void"] = function() if setAV then setAV(not State.AntiVoid) end end

local setASp = Toggle(MiscP, "Anti-Spinner", "Remove spinner traps", function(s)
    State.AntiSweeper = s; if s then task.spawn(AntiSweeperLoop) end
    if s then ShowBindIndicator("Anti-Spinner") else HideBindIndicator("Anti-Spinner") end
end)
toggleCallbacks["Anti-Spinner"] = function() if setASp then setASp(not State.AntiSweeper) end end

-- CLOSE
CloseBtn.MouseButton1Click:Connect(function()
    SmoothTween(Main, {Position = UDim2.new(0.5, -WIN_W/2, 1.5, 0)}, 0.35)
    SmoothTween(Blur, {BackgroundTransparency = 1}, 0.25)
    task.delay(0.37, function() SG.Enabled = false; MenuOpen = false; Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2) end)
end)

-- INFINITE JUMP
table.insert(allConnections, UIS.InputBegan:Connect(function(input, gp)
    if gp or not Running then return end
    if input.KeyCode == Enum.KeyCode.Space and State.InfiniteJump then
        local hum = GetHum()
        local hrp = GetHRP()
        if not hum or not hrp then return end
        if InvisibleActive then return end -- Don't interfere with invisible
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Freefall and not jumpDebounce then
            jumpDebounce = true
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(hrp.Velocity.X, 20, hrp.Velocity.Z)
            bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Parent = hrp
            task.delay(0.08, function()
                pcall(function() bv:Destroy() end)
                task.delay(0.3, function() jumpDebounce = false end)
            end)
        end
    end
end))

-- Menu toggle
table.insert(allConnections, UIS.InputBegan:Connect(function(input, gp)
    if gp or not Running or bindPopupActive then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        if not MenuOpen then
            MenuOpen = true; SG.Enabled = true
            Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
            Main.Size = UDim2.new(0, WIN_W * 0.95, 0, WIN_H * 0.95)
            Main.BackgroundTransparency = 0.3
            Blur.BackgroundTransparency = 1
            BounceTween(Main, {Size = UDim2.new(0, WIN_W, 0, WIN_H), BackgroundTransparency = 0.02}, 0.4)
            SmoothTween(Blur, {BackgroundTransparency = 0.5}, 0.3)
        else
            SmoothTween(Main, {Size = UDim2.new(0, WIN_W * 0.95, 0, WIN_H * 0.95), BackgroundTransparency = 0.3}, 0.25)
            SmoothTween(Blur, {BackgroundTransparency = 1}, 0.2)
            task.delay(0.27, function()
                SG.Enabled = false; MenuOpen = false
                Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
                Main.Size = UDim2.new(0, WIN_W, 0, WIN_H)
            end)
        end
    end
end))

-- Runtime
table.insert(allConnections, RS.RenderStepped:Connect(function()
    if not Running then return end
    pcall(updateESP)
    if State.Noclip and not InvisibleActive then pcall(function()
        local c = LP.Character; if not c then return end
        for _, p in pairs(c:GetChildren()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end) end
    if State.Reach and not InvisibleActive then pcall(function()
        local c = LP.Character; if not c then return end
        local tool = c:FindFirstChildOfClass("Tool")
        if tool and isMeleeTool(tool) then
            local h = tool:FindFirstChild("Handle")
            if h then h.Size = Vector3.new(1,1,15); h.Massless = true end
        end
    end) end
end))

-- Character respawn
table.insert(allConnections, LP.CharacterAdded:Connect(function(char)
    if not Running then return end
    Char = char; Hum = char:WaitForChild("Humanoid"); HRP = char:WaitForChild("HumanoidRootPart")
    task.wait(0.1)
    pcall(function() Hum.WalkSpeed = State.Speed; Hum.JumpPower = State.JumpPower end)
    table.insert(allConnections, Hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if Running and Hum and Hum.Parent and Hum.WalkSpeed ~= State.Speed then Hum.WalkSpeed = State.Speed end
    end))
    table.insert(allConnections, Hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if Running and Hum and Hum.Parent and Hum.JumpPower ~= State.JumpPower then Hum.JumpPower = State.JumpPower end
    end))
    lastSafePos = nil; jumpDebounce = false
    
    -- Clean up invisible on respawn
    if InvisibleActive then
        InvisibleActive = false
        if InvisConn then pcall(function() InvisConn:Disconnect() end) InvisConn = nil end
        if FakeCharModel then pcall(function() FakeCharModel:Destroy() end) FakeCharModel = nil end
        pcall(function() workspace.FallenPartsDestroyHeight = getgenv().FPDH end)
        pcall(function() workspace.CurrentCamera.CameraSubject = Hum end)
    end
    
    if State.AntiVoid then StartAntiVoid() end
    if State.AutoSword then StartAutoSword() end
    if State.DeathNoteTP then StartDeathNoteTP() end
end))

pcall(function() local h = GetHum(); if h then h.WalkSpeed = State.Speed; h.JumpPower = State.JumpPower end end)

table.insert(allConnections, Players.PlayerAdded:Connect(function() if Running then task.wait(0.5); RefreshFlingList(); RefreshTpList() end end))
table.insert(allConnections, Players.PlayerRemoving:Connect(function(plr)
    if not Running then return end
    if SelectedFlingTarget == plr then SelectedFlingTarget = nil; selText.Text = "Target: none"; selText.TextColor3 = C.textMuted end
    SelectedTargets[plr.Name] = nil; RefreshFlingList(); RefreshTpList(); removeESP(plr)
end))

-- INIT
task.wait(0.5)
RefreshFlingList(); RefreshTpList()

if State.KillAura then task.spawn(KillAura); ShowBindIndicator("Kill Aura") end
if State.AntiLava then task.spawn(AntiLavaLoop); ShowBindIndicator("Anti-Lava") end
if State.AntiVoid then StartAntiVoid(); ShowBindIndicator("Anti-Void") end
if State.AntiSweeper then task.spawn(AntiSweeperLoop); ShowBindIndicator("Anti-Spinner") end
if State.DeathNoteTP then StartDeathNoteTP(); ShowBindIndicator("Death Note TP") end
if State.AutoSword then StartAutoSword(); ShowBindIndicator("Auto Sword TP") end
if State.ESP then ShowBindIndicator("ESP") end
if State.Reach then ShowBindIndicator("Reach") end
if State.Noclip then ShowBindIndicator("Noclip") end
if State.InfiniteJump then ShowBindIndicator("Infinite Jump") end

SG.Enabled = true; MenuOpen = true
Main.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Main.Size = UDim2.new(0, WIN_W * 0.9, 0, WIN_H * 0.9)
Main.BackgroundTransparency = 0.5
Blur.BackgroundTransparency = 1

BounceTween(Main, {Size = UDim2.new(0, WIN_W, 0, WIN_H), BackgroundTransparency = 0.02}, 0.5)
SmoothTween(Blur, {BackgroundTransparency = 0.5}, 0.4)

print("QWEN v5.0 | DELETE=menu | Invisible = ghost mode (controller part)")
