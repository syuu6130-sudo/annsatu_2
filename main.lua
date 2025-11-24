--// 暗殺者対保安官2 - 全Executer対応版 //--
-- 作者: @syu_u0316 --
-- 全Executer対応 - 図形ESPシステム搭載版 --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== 互換性チェック ==========
local isSupportedExecutor = true
local hasGetConnections = pcall(getconnections, game.Loaded)
local hasVirtualInput = pcall(function() return VirtualInputManager.SendMouseButtonEvent end)

-- ========== 設定 ==========
local softAimEnabled = false
local autoAimEnabled = false
local silentAimEnabled = false
local magicCircleEnabled = false
local circleEnabled = false
local espEnabled = false
local tracersEnabled = false

local softAimStrength = 0.3
local aimPart = "Head"
local circleRadius = 120
local circleThickness = 3
local circleSize = 240

local currentLockTarget = nil
local lastShootTime = 0
local isShootingActive = false

-- キー設定
local softAimKey = Enum.KeyCode.Q
local softAimKeyString = "Q"

-- 図形の設定
local currentShape = "丸"
local shapes = {"丸", "四角", "卍", "十字"}
local colors = {
    "赤", "青", "緑", "黄色", 
    "紫", "橙", "ピンク", "水色",
    "白", "黒", "虹色", "シアン"
}

local colorValues = {
    赤 = Color3.fromRGB(255, 0, 0),
    青 = Color3.fromRGB(0, 0, 255),
    緑 = Color3.fromRGB(0, 255, 0),
    黄色 = Color3.fromRGB(255, 255, 0),
    紫 = Color3.fromRGB(128, 0, 128),
    橙 = Color3.fromRGB(255, 165, 0),
    ピンク = Color3.fromRGB(255, 192, 203),
    水色 = Color3.fromRGB(173, 216, 230),
    白 = Color3.fromRGB(255, 255, 255),
    黒 = Color3.fromRGB(0, 0, 0),
    シアン = Color3.fromRGB(0, 255, 255)
}

local currentColor = "赤"
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = game.CoreGui

-- ========== 武器システム ==========
local weaponData = {
    currentTool = nil,
    remotes = {}
}

local function getEquippedWeapon()
    if not player.Character then return nil end
    return player.Character:FindFirstChildOfClass("Tool")
end

-- ========== チームチェック & 壁判定 ==========
local function isVisible(target)
    local origin = Camera.CFrame.Position
    local direction = (target.Position - origin)
    local ray = Ray.new(origin, direction)
    local hit = workspace:FindPartOnRay(ray, player.Character, false, true)
    return (not hit or hit:IsDescendantOf(target.Parent))
end

local function isEnemy(plr)
    if not player.Team or not plr.Team then
        return true
    end
    return plr.Team ~= player.Team
end

-- ========== 最も近い敵を取得 ==========
function getClosestEnemy()
    local closest, dist = nil, math.huge
    local camCF = Camera.CFrame
    local camDir = camCF.LookVector
    local maxAngle = math.rad(70)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(aimPart) or p.Character:FindFirstChild("Head")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetPart and humanoid and humanoid.Health > 0 then
                local dir = (targetPart.Position - camCF.Position).Unit
                local dot = camDir:Dot(dir)
                local angle = math.acos(math.clamp(dot, -1, 1))
                if angle < maxAngle then
                    local mag = (targetPart.Position - camCF.Position).Magnitude
                    if mag < dist and isVisible(targetPart) then
                        closest = p.Character
                        dist = mag
                    end
                end
            end
        end
    end

    return closest
end

-- ========== 円内の敵を取得 ==========
local function isInMagicCircle(screenPos)
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    
    local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    if isMobile then
        centerY = viewportSize.Y * 0.4
    end
    
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance <= circleRadius
end

local function getEnemyInCircle()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(aimPart) or p.Character:FindFirstChild("Head")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetPart and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and isInMagicCircle(Vector2.new(screenPos.X, screenPos.Y)) then
                    return p.Character, targetPart
                end
            end
        end
    end
    return nil, nil
end

-- ========== Silent Aim (全Executer対応版) ==========
local silentAimHooked = false
local function setupSilentAim()
    if silentAimHooked then return end
    
    local success, mt = pcall(getrawmetatable, game)
    if not success then
        warn("⚠️ メタテーブル取得失敗 - SilentAim無効")
        return
    end
    
    local oldNamecall
    local oldIndex
    
    pcall(function()
        oldNamecall = mt.__namecall
        oldIndex = mt.__index
        
        setreadonly(mt, false)
        
        mt.__namecall = newcclosure(function(self, ...)
            local args = {...}
            local method = getnamecallmethod()
            
            if silentAimEnabled and (method == "FireServer" or method == "InvokeServer") then
                local target = getClosestEnemy()
                if target then
                    local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
                    if targetPart then
                        if typeof(args[1]) == "Vector3" then
                            args[1] = targetPart.Position
                        elseif typeof(args[1]) == "CFrame" then
                            args[1] = targetPart.CFrame
                        end
                    end
                end
            end
            
            return oldNamecall(self, unpack(args))
        end)
        
        mt.__index = newcclosure(function(self, key)
            if silentAimEnabled and key == "Hit" then
                local target = getClosestEnemy()
                if target then
                    local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
                    if targetPart then
                        return targetPart.CFrame
                    end
                end
            end
            return oldIndex(self, key)
        end)
        
        setreadonly(mt, true)
        silentAimHooked = true
    end)
end

-- ========== メインループ ==========
RunService.RenderStepped:Connect(function()
    -- キー押下でソフトエイム
    local softAimActive = UserInputService:IsKeyDown(softAimKey) and softAimEnabled
    
    if softAimActive or autoAimEnabled then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if softAimActive then
                    local newCF = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPart.Position), softAimStrength)
                    Camera.CFrame = newCF
                end
                if autoAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
            end
        end
    end
    
    -- 魔法の円での自動エイム
    if magicCircleEnabled and circleEnabled then
        local target, targetPart = getEnemyInCircle()
        if target and targetPart then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
        end
    end
end)

-- ========== 図形描画システム ==========
local circleFolder = Instance.new("Folder")
circleFolder.Name = "DecorativeShapes"
circleFolder.Parent = game.CoreGui

local function hsvToRgb(h, s, v)
    return Color3.fromHSV(h, s, v)
end

local function createShape()
    for _,v in ipairs(circleFolder:GetChildren()) do v:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "ShapeScreen"
    screen.Parent = circleFolder

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, circleSize, 0, circleSize)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = screen

    local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    if isMobile then
        frame.Position = UDim2.new(0.5, 0, 0.4, 0)
    else
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

    if currentShape == "丸" then
        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(1, 0)
        
        local stroke = Instance.new("UIStroke", frame)
        stroke.Thickness = circleThickness
        stroke.Color = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]

    elseif currentShape == "四角" then
        local stroke = Instance.new("UIStroke", frame)
        stroke.Thickness = circleThickness
        stroke.Color = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]

    elseif currentShape == "卍" then
        -- 卍の描画（4本の線で表現）
        local part1 = Instance.new("Frame")
        part1.Size = UDim2.new(0, circleThickness, 0, circleSize * 0.6)
        part1.Position = UDim2.new(0.5, -circleThickness/2, 0.2, 0)
        part1.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        part1.BorderSizePixel = 0
        part1.Parent = frame

        local part2 = Instance.new("Frame")
        part2.Size = UDim2.new(0, circleSize * 0.6, 0, circleThickness)
        part2.Position = UDim2.new(0.2, 0, 0.5, -circleThickness/2)
        part2.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        part2.BorderSizePixel = 0
        part2.Parent = frame

        local part3 = Instance.new("Frame")
        part3.Size = UDim2.new(0, circleThickness, 0, circleSize * 0.4)
        part3.Position = UDim2.new(0.7, -circleThickness/2, 0.3, 0)
        part3.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        part3.BorderSizePixel = 0
        part3.Parent = frame

        local part4 = Instance.new("Frame")
        part4.Size = UDim2.new(0, circleSize * 0.4, 0, circleThickness)
        part4.Position = UDim2.new(0.3, 0, 0.7, -circleThickness/2)
        part4.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        part4.BorderSizePixel = 0
        part4.Parent = frame

    elseif currentShape == "十字" then
        local horizontal = Instance.new("Frame")
        horizontal.Size = UDim2.new(0, circleSize, 0, circleThickness)
        horizontal.Position = UDim2.new(0, 0, 0.5, -circleThickness/2)
        horizontal.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        horizontal.BorderSizePixel = 0
        horizontal.Parent = frame

        local vertical = Instance.new("Frame")
        vertical.Size = UDim2.new(0, circleThickness, 0, circleSize)
        vertical.Position = UDim2.new(0.5, -circleThickness/2, 0, 0)
        vertical.BackgroundColor3 = currentColor == "虹色" and hsvToRgb((tick() * 0.2) % 1, 1, 1) or colorValues[currentColor]
        vertical.BorderSizePixel = 0
        vertical.Parent = frame
    end

    return frame
end

-- ========== 図形アニメーション ==========
RunService.RenderStepped:Connect(function()
    if circleEnabled then
        for _,screen in ipairs(circleFolder:GetChildren()) do
            for _,shape in ipairs(screen:GetChildren()) do
                if currentColor == "虹色" then
                    local hue = (tick() * 0.2) % 1
                    local rainbowColor = hsvToRgb(hue, 1, 1)
                    
                    -- すべてのパーツの色を更新
                    for _,child in ipairs(shape:GetDescendants()) do
                        if child:IsA("Frame") then
                            child.BackgroundColor3 = rainbowColor
                        elseif child:IsA("UIStroke") then
                            child.Color = rainbowColor
                        end
                    end
                end

                -- サイズアニメーション
                local scale = 1 + 0.05 * math.sin(tick() * 2)
                shape.Size = UDim2.new(0, circleSize * scale, 0, circleSize * scale)

                -- 位置調整
                local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
                if isMobile then
                    shape.Position = UDim2.new(0.5, 0, 0.4, 0)
                else
                    shape.Position = UDim2.new(0.5, 0, 0.5, 0)
                end
            end
        end
    end
end)

-- ========== ESP システム ==========
local function updateESP()
    -- 既存のESPをクリア
    for _, v in ipairs(espFolder:GetChildren()) do
        v:Destroy()
    end

    if not espEnabled then return end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    -- Tracers
                    if tracersEnabled then
                        local tracerGui = Instance.new("ScreenGui")
                        tracerGui.Name = "Tracer_" .. p.Name
                        tracerGui.Parent = espFolder

                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.new(0, 2, 0, 1000)
                        frame.AnchorPoint = Vector2.new(0.5, 0)
                        frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                        frame.BorderSizePixel = 0
                        frame.Parent = tracerGui

                        RunService.RenderStepped:Connect(function()
                            local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                            if onScreen then
                                frame.Visible = true
                                frame.Position = UDim2.new(0, vector.X, 0, vector.Y)
                                
                                -- 画面の下から敵への角度を計算
                                local viewportSize = Camera.ViewportSize
                                local angle = math.atan2(vector.Y - viewportSize.Y, vector.X - viewportSize.X/2)
                                frame.Rotation = math.deg(angle) + 90
                            else
                                frame.Visible = false
                            end
                        end)
                    end
                end
            end
        end
    end
end

-- ========== Rayfieldウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
   Name = "暗殺者対保安官2 v3 | 全Executer対応",
   LoadingTitle = "全Executer対応版 図形ESPシステム",
   LoadingSubtitle = "互換性: " .. (isSupportedExecutor and "良好" or "一部制限"),
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "AssassinSheriff2_Universal",
      FileName = "config"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false
})

-- ========== タブ作成 ==========
local CombatTab = Window:CreateTab("戦闘", nil)
local VisualTab = Window:CreateTab("視覚効果", nil)
local ESPTab = Window:CreateTab("ESP", nil)

-- ========== 戦闘タブ ==========
local AimSection = CombatTab:CreateSection("エイム設定")

local SoftAimToggle = CombatTab:CreateToggle({
   Name = "ソフトエイム (キー押下で有効)",
   CurrentValue = false,
   Flag = "SoftAim",
   Callback = function(Value)
       softAimEnabled = Value
   end,
})

local AutoAimToggle = CombatTab:CreateToggle({
   Name = "自動エイム (スナップ)",
   CurrentValue = false,
   Flag = "AutoAim",
   Callback = function(Value)
       autoAimEnabled = Value
   end,
})

local SilentAimToggle = CombatTab:CreateToggle({
   Name = "サイレントエイム",
   CurrentValue = false,
   Flag = "SilentAim",
   Callback = function(Value)
       silentAimEnabled = Value
       if Value then
           setupSilentAim()
       end
   end,
})

local AimStrengthSlider = CombatTab:CreateSlider({
   Name = "ソフトエイム強度",
   Range = {0.1, 1},
   Increment = 0.05,
   CurrentValue = 0.3,
   Flag = "AimStrength",
   Callback = function(Value)
       softAimStrength = Value
   end,
})

local AimPartDropdown = CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
   CurrentOption = "Head",
   Flag = "AimPart",
   Callback = function(Option)
       aimPart = Option
   end,
})

local SoftAimKeybind = CombatTab:CreateKeybind({
   Name = "ソフトエイムキー",
   CurrentKeybind = softAimKeyString,
   HoldToInteract = false,
   Flag = "SoftAimKeybind",
   Callback = function(Key)
       softAimKey = Enum.KeyCode[Key]
       softAimKeyString = Key
   end,
})

-- ========== 視覚効果タブ ==========
local CircleSection = VisualTab:CreateSection("図形設定")

local CircleToggle = VisualTab:CreateToggle({
   Name = "図形を表示",
   CurrentValue = false,
   Flag = "Circle",
   Callback = function(Value)
       circleEnabled = Value
       if Value then
           createShape()
       else
           for _,v in ipairs(circleFolder:GetChildren()) do 
               v:Destroy() 
           end
       end
   end,
})

local MagicCircleToggle = VisualTab:CreateToggle({
   Name = "図形内自動エイム",
   CurrentValue = false,
   Flag = "MagicCircle",
   Callback = function(Value)
       magicCircleEnabled = Value
   end,
})

local ShapeDropdown = VisualTab:CreateDropdown({
   Name = "図形の形",
   Options = shapes,
   CurrentOption = "丸",
   Flag = "Shape",
   Callback = function(Option)
       currentShape = Option
       if circleEnabled then
           createShape()
       end
   end,
})

local ColorDropdown = VisualTab:CreateDropdown({
   Name = "図形の色",
   Options = colors,
   CurrentOption = "赤",
   Flag = "Color",
   Callback = function(Option)
       currentColor = Option
       if circleEnabled then
           createShape()
       end
   end,
})

local CircleRadiusSlider = VisualTab:CreateSlider({
   Name = "自動エイム範囲",
   Range = {50, 500},
   Increment = 10,
   CurrentValue = 120,
   Flag = "CircleRadius",
   Callback = function(Value)
       circleRadius = Value
   end,
})

local CircleSizeSlider = VisualTab:CreateSlider({
   Name = "図形の大きさ",
   Range = {50, 500},
   Increment = 10,
   CurrentValue = 240,
   Flag = "CircleSize",
   Callback = function(Value)
       circleSize = Value
       if circleEnabled then
           createShape()
       end
   end,
})

local CircleThicknessSlider = VisualTab:CreateSlider({
   Name = "図形の太さ",
   Range = {1, 20},
   Increment = 1,
   CurrentValue = 3,
   Flag = "CircleThickness",
   Callback = function(Value)
       circleThickness = Value
       if circleEnabled then
           createShape()
       end
   end,
})

-- ========== ESPタブ ==========
local ESPSection = ESPTab:CreateSection("ESP設定")

local ESPToggle = ESPTab:CreateToggle({
   Name = "ESPを有効化",
   CurrentValue = false,
   Flag = "ESP",
   Callback = function(Value)
       espEnabled = Value
       updateESP()
   end,
})

local TracersToggle = ESPTab:CreateToggle({
   Name = "Tracers (線)",
   CurrentValue = false,
   Flag = "Tracers",
   Callback = function(Value)
       tracersEnabled = Value
       updateESP()
   end,
})

-- ========== 互換性情報 ==========
local CompatibilitySection = ESPTab:CreateSection("互換性情報")

local CompatibilityLabel = ESPTab:CreateLabel(
    "互換性状態:\n" ..
    "getconnections: " .. (hasGetConnections and "✅ 利用可能" or "❌ 利用不可") .. "\n" ..
    "VirtualInput: " .. (hasVirtualInput and "✅ 利用可能" or "❌ 利用不可") .. "\n" ..
    "SilentAim: " .. (silentAimHooked and "✅ 初期化済み" or "🔄 準備中")
)

-- ========== 通知 ==========
Rayfield:Notify({
   Title = "全Executer対応版 読み込み完了",
   Content = "暗殺者対保安官2 v3 - 図形ESPシステム\n互換性: " .. 
             (hasGetConnections and "getconnections✅ " or "getconnections❌ ") ..
             (hasVirtualInput and "VirtualInput✅" or "VirtualInput❌"),
   Duration = 5,
   Image = nil,
})

-- ========== 自動更新ループ ==========
task.spawn(function()
    while true do
        task.wait(1)
        updateESP()
    end
end)

-- ========== 初期化 ==========
task.spawn(function()
    task.wait(2)
    setupSilentAim()
    
    -- 互換性情報を更新
    task.wait(1)
    CompatibilityLabel:Set(
        "互換性状態:\n" ..
        "getconnections: " .. (hasGetConnections and "✅ 利用可能" or "❌ 利用不可") .. "\n" ..
        "VirtualInput: " .. (hasVirtualInput and "✅ 利用可能" or "❌ 利用不可") .. "\n" ..
        "SilentAim: " .. (silentAimHooked and "✅ 初期化済み" : "❌ 初期化失敗")
    )
end)
