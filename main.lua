--// 暗殺者対保安官2 - 全Executer対応版 //--
-- 作者: @syu_u0316 --
-- 全Executer対応 - 図形ESPシステム搭載版 --

-- Rayfieldの安全な読み込み
local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "エラー",
        Text = "Rayfieldの読み込みに失敗しました",
        Duration = 5
    })
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

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

-- ========== 基本機能 ==========
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

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and p.Character then
            local targetPart = p.Character:FindFirstChild(aimPart) or p.Character:FindFirstChild("Head")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetPart and humanoid and humanoid.Health > 0 then
                local mag = (targetPart.Position - camCF.Position).Magnitude
                if mag < dist then
                    closest = p.Character
                    dist = mag
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
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, circleSize, 0, circleSize)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = screen
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)

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
                        tracerGui.ResetOnSpawn = false
                        tracerGui.IgnoreGuiInset = true

                        local frame = Instance.new("Frame")
                        frame.Size = UDim2.new(0, 2, 0, 1000)
                        frame.AnchorPoint = Vector2.new(0.5, 0)
                        frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
                        frame.BorderSizePixel = 0
                        frame.Parent = tracerGui

                        local connection
                        connection = RunService.RenderStepped:Connect(function()
                            if not p.Character or not head then
                                connection:Disconnect()
                                return
                            end
                            
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
   Name = "暗殺者対保安官2",
   LoadingTitle = "図形ESPシステム",
   LoadingSubtitle = "全Executer対応版",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "暗殺者対保安官2"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false
})

-- ========== タブ作成 ==========
local CombatTab = Window:CreateTab("戦闘", 4483362458)
local VisualTab = Window:CreateTab("視覚効果", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)

-- ========== 戦闘タブ ==========
CombatTab:CreateSection("エイム設定")

local SoftAimToggle = CombatTab:CreateToggle({
   Name = "ソフトエイム (キー押下で有効)",
   CurrentValue = softAimEnabled,
   Flag = "SoftAim",
   Callback = function(Value)
       softAimEnabled = Value
   end,
})

local AutoAimToggle = CombatTab:CreateToggle({
   Name = "自動エイム (スナップ)",
   CurrentValue = autoAimEnabled,
   Flag = "AutoAim",
   Callback = function(Value)
       autoAimEnabled = Value
   end,
})

local SilentAimToggle = CombatTab:CreateToggle({
   Name = "サイレントエイム",
   CurrentValue = silentAimEnabled,
   Flag = "SilentAim",
   Callback = function(Value)
       silentAimEnabled = Value
   end,
})

CombatTab:CreateSlider({
   Name = "ソフトエイム強度",
   Range = {0.1, 1},
   Increment = 0.05,
   Suffix = "強度",
   CurrentValue = softAimStrength,
   Flag = "AimStrength",
   Callback = function(Value)
       softAimStrength = Value
   end,
})

CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
   CurrentOption = aimPart,
   Flag = "AimPart",
   Callback = function(Option)
       aimPart = Option
   end,
})

CombatTab:CreateKeybind({
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
VisualTab:CreateSection("図形設定")

local CircleToggle = VisualTab:CreateToggle({
   Name = "図形を表示",
   CurrentValue = circleEnabled,
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
   CurrentValue = magicCircleEnabled,
   Flag = "MagicCircle",
   Callback = function(Value)
       magicCircleEnabled = Value
   end,
})

VisualTab:CreateDropdown({
   Name = "図形の形",
   Options = shapes,
   CurrentOption = currentShape,
   Flag = "Shape",
   Callback = function(Option)
       currentShape = Option
       if circleEnabled then
           createShape()
       end
   end,
})

VisualTab:CreateDropdown({
   Name = "図形の色",
   Options = colors,
   CurrentOption = currentColor,
   Flag = "Color",
   Callback = function(Option)
       currentColor = Option
       if circleEnabled then
           createShape()
       end
   end,
})

VisualTab:CreateSlider({
   Name = "自動エイム範囲",
   Range = {50, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = circleRadius,
   Flag = "CircleRadius",
   Callback = function(Value)
       circleRadius = Value
   end,
})

VisualTab:CreateSlider({
   Name = "図形の大きさ",
   Range = {50, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = circleSize,
   Flag = "CircleSize",
   Callback = function(Value)
       circleSize = Value
       if circleEnabled then
           createShape()
       end
   end,
})

VisualTab:CreateSlider({
   Name = "図形の太さ",
   Range = {1, 20},
   Increment = 1,
   Suffix = "px",
   CurrentValue = circleThickness,
   Flag = "CircleThickness",
   Callback = function(Value)
       circleThickness = Value
       if circleEnabled then
           createShape()
       end
   end,
})

-- ========== ESPタブ ==========
ESPTab:CreateSection("ESP設定")

local ESPToggle = ESPTab:CreateToggle({
   Name = "ESPを有効化",
   CurrentValue = espEnabled,
   Flag = "ESP",
   Callback = function(Value)
       espEnabled = Value
       updateESP()
   end,
})

local TracersToggle = ESPTab:CreateToggle({
   Name = "Tracers (線)",
   CurrentValue = tracersEnabled,
   Flag = "Tracers",
   Callback = function(Value)
       tracersEnabled = Value
       updateESP()
   end,
})

-- ========== 自動更新ループ ==========
task.spawn(function()
    while task.wait(1) do
        updateESP()
    end
end)

-- ========== 初期化完了通知 ==========
task.spawn(function()
    task.wait(2)
    Rayfield:Notify({
        Title = "読み込み完了",
        Content = "暗殺者対保安官2 - 全Executer対応版が起動しました",
        Duration = 5,
        Image = nil,
    })
end)
