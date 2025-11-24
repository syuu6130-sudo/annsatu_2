--// 暗殺者対保安官2 - 全executer対応版 (超高密度自動射撃 v3) //--
-- 作者: @syu_u0316 --
-- 完全再構築版 - 全エクスプロイト互換対応 --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ========== 設定 ==========
local softAimEnabled = false
local autoAimEnabled = false
local autoShootEnabled = false
local flyEnabled = false
local circleEnabled = false
local magicCircleEnabled = false
local silentAimEnabled = false
local triggerBotEnabled = false
local autoEquipEnabled = false

local softAimStrength = 0.3
local flySpeed = 50
local aimPart = "Head"
local shootDelay = 0.08
local burstCount = 1

local currentLockTarget = nil
local circleRadius = 120
local lastShootTime = 0
local isShootingActive = false

-- ========== 互換性チェック ==========
local isSupportedExecutor = true
local hasGetConnections = pcall(getconnections, game.Loaded)
local hasVirtualInput = pcall(function() return VirtualInputManager.SendMouseButtonEvent end)

if not hasGetConnections then
    warn("⚠️ getconnections が利用できません - 一部機能が制限されます")
end

if not hasVirtualInput then
    warn("⚠️ VirtualInputManager が利用できません - 一部機能が制限されます")
end

-- ========== デバッグシステム ==========
local debugLog = {}
local function log(msg)
    table.insert(debugLog, "[" .. os.date("%X") .. "] " .. msg)
    if #debugLog > 50 then
        table.remove(debugLog, 1)
    end
    print(msg)
end

-- ========== 超精密武器検出システム ==========
local weaponData = {
    currentTool = nil,
    remotes = {},
    activateMethod = nil,
    lastUpdate = 0
}

local function deepScanTool(tool)
    log("🔍 武器スキャン開始: " .. tool.Name)
    
    weaponData.remotes = {}
    
    -- RemoteEvent/RemoteFunction検索
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
            table.insert(weaponData.remotes, desc)
            log("✅ Remote発見: " .. desc.Name .. " (" .. desc.ClassName .. ")")
        end
    end
    
    -- BindableEvent検索
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("BindableEvent") or desc:IsA("BindableFunction") then
            log("📡 Bindable発見: " .. desc.Name)
        end
    end
    
    -- Script検索
    local scripts = {}
    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("LocalScript") or desc:IsA("Script") then
            scripts[#scripts + 1] = desc
            log("📜 スクリプト発見: " .. desc.Name)
        end
    end
    
    log("📊 スキャン結果: Remote=" .. #weaponData.remotes .. "個, Script=" .. #scripts .. "個")
end

local function getEquippedWeapon()
    if not player.Character then return nil end
    local tool = player.Character:FindFirstChildOfClass("Tool")
    
    if tool and tool ~= weaponData.currentTool then
        weaponData.currentTool = tool
        deepScanTool(tool)
    end
    
    return tool
end

local function autoEquipWeapon()
    if not autoEquipEnabled then return getEquippedWeapon() end
    
    if not getEquippedWeapon() then
        for _, item in ipairs(player.Backpack:GetChildren()) do
            if item:IsA("Tool") then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    log("🔧 武器装備中: " .. item.Name)
                    humanoid:EquipTool(item)
                    task.wait(0.15)
                    return item
                end
            end
        end
    end
    return getEquippedWeapon()
end

-- ========== 超高密度射撃システム (10層アプローチ) ==========
local shootMethods = {}

-- 方法1: Tool:Activate() (標準)
shootMethods[1] = function(tool)
    local success = pcall(function()
        tool:Activate()
    end)
    if success then log("✅ 方法1成功: Tool:Activate()") end
    return success
end

-- 方法2: RemoteEvent:FireServer() (全Remote試行)
shootMethods[2] = function(tool)
    local fired = 0
    for _, remote in ipairs(weaponData.remotes) do
        if remote:IsA("RemoteEvent") then
            pcall(function()
                remote:FireServer()
                remote:FireServer(mouse.Hit.Position)
                remote:FireServer(mouse.Hit)
                remote:FireServer(true)
                fired = fired + 1
            end)
        end
    end
    if fired > 0 then log("✅ 方法2成功: Remote発火 x" .. fired) end
    return fired > 0
end

-- 方法3: RemoteFunction:InvokeServer()
shootMethods[3] = function(tool)
    local invoked = 0
    for _, remote in ipairs(weaponData.remotes) do
        if remote:IsA("RemoteFunction") then
            pcall(function()
                remote:InvokeServer()
                remote:InvokeServer(mouse.Hit.Position)
                invoked = invoked + 1
            end)
        end
    end
    if invoked > 0 then log("✅ 方法3成功: RemoteFunction x" .. invoked) end
    return invoked > 0
end

-- 方法4: VirtualInput マウスクリック (互換性チェック付き)
shootMethods[4] = function(tool)
    if not hasVirtualInput then return false end
    local success = pcall(function()
        local pos = UserInputService:GetMouseLocation()
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    if success then log("✅ 方法4成功: VirtualInput") end
    return success
end

-- 方法5: mouse1press/release (互換性チェック付き)
shootMethods[5] = function(tool)
    if not mousemoverel or not mouse1press then return false end
    local success = pcall(function()
        mouse1press()
        task.wait(0.05)
        mouse1release()
    end)
    if success then log("✅ 方法5成功: mouse1press") end
    return success
end

-- 方法6: ツールハンドルクリック検出
shootMethods[6] = function(tool)
    local handle = tool:FindFirstChild("Handle")
    if handle then
        local success = pcall(function()
            if hasGetConnections then
                for _, connection in ipairs(getconnections(handle.Touched)) do
                    connection:Fire()
                end
            end
        end)
        if success then log("✅ 方法6成功: Handle:Touched") end
        return success
    end
    return false
end

-- 方法7: ReplicatedStorage検索
shootMethods[7] = function(tool)
    local found = 0
    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
        if remote:IsA("RemoteEvent") and (remote.Name:lower():find("fire") or remote.Name:lower():find("shoot") or remote.Name:lower():find("gun")) then
            pcall(function()
                remote:FireServer()
                remote:FireServer(mouse.Hit.Position)
                found = found + 1
            end)
        end
    end
    if found > 0 then log("✅ 方法7成功: ReplicatedStorage Remote x" .. found) end
    return found > 0
end

-- 方法8: ツール内のConnection発火 (互換性チェック付き)
shootMethods[8] = function(tool)
    if not hasGetConnections then return false end
    local fired = 0
    pcall(function()
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("BindableEvent") then
                for _, con in ipairs(getconnections(v.OnClientEvent)) do
                    pcall(function() con:Fire() end)
                    fired = fired + 1
                end
            end
        end
    end)
    if fired > 0 then log("✅ 方法8成功: Connection発火 x" .. fired) end
    return fired > 0
end

-- 方法9: Activated イベント発火 (互換性チェック付き)
shootMethods[9] = function(tool)
    if not hasGetConnections then return false end
    local success = pcall(function()
        for _, con in ipairs(getconnections(tool.Activated)) do
            con:Fire()
        end
    end)
    if success then log("✅ 方法9成功: Activated発火") end
    return success
end

-- 方法10: マウスButton1Down シミュレーション (互換性チェック付き)
shootMethods[10] = function(tool)
    if not hasGetConnections then return false end
    local success = pcall(function()
        for _, con in ipairs(getconnections(mouse.Button1Down)) do
            con:Fire()
        end
    end)
    if success then log("✅ 方法10成功: Mouse.Button1Down") end
    return success
end

-- ========== メイン射撃関数 ==========
local function shootWeapon()
    if isShootingActive then return false end
    isShootingActive = true
    
    local tool = getEquippedWeapon()
    if not tool then
        log("❌ 武器未装備")
        isShootingActive = false
        return false
    end
    
    log("🔫 射撃開始: " .. tool.Name)
    
    local successCount = 0
    
    -- 全ての方法を並列実行
    for i, method in ipairs(shootMethods) do
        task.spawn(function()
            if method(tool) then
                successCount = successCount + 1
            end
        end)
    end
    
    task.wait(0.1)
    
    log("📊 射撃結果: " .. successCount .. "/" .. #shootMethods .. "個の方法が成功")
    
    isShootingActive = false
    return successCount > 0
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

-- ========== トリガーボット判定 ==========
local function isLookingAtEnemy()
    local target = getClosestEnemy()
    if not target then return false end
    
    local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
    if not targetPart then return false end
    
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local viewportSize = Camera.ViewportSize
    local centerX = viewportSize.X / 2
    local centerY = viewportSize.Y / 2
    
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance < 100
end

-- ========== Silent Aim (メタテーブルフック - 互換性対応) ==========
local silentAimHooked = false
local function setupSilentAim()
    if silentAimHooked then return end
    
    local success, mt = pcall(getrawmetatable, game)
    if not success then
        log("❌ メタテーブル取得失敗 - SilentAim無効")
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
                        elseif typeof(args[1]) == "Instance" then
                            args[1] = targetPart
                        end
                    end
                end
            end
            
            return oldNamecall(self, unpack(args))
        end)
        
        mt.__index = newcclosure(function(self, key)
            if silentAimEnabled and (key == "Hit" or key == "Target") then
                local target = getClosestEnemy()
                if target then
                    local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
                    if targetPart then
                        if key == "Hit" then
                            return targetPart.CFrame
                        else
                            return targetPart
                        end
                    end
                end
            end
            return oldIndex(self, key)
        end)
        
        setreadonly(mt, true)
        silentAimHooked = true
        log("✅ SilentAimフック完了")
    end)
end

-- ========== メインループ ==========
local shootCoroutine
RunService.RenderStepped:Connect(function()
    local currentTime = tick()
    
    -- 通常のエイム
    if softAimEnabled or autoAimEnabled then
        local target = getClosestEnemy()
        if target then
            local targetPart = target:FindFirstChild(aimPart) or target:FindFirstChild("Head")
            if targetPart then
                if softAimEnabled then
                    local newCF = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPart.Position), softAimStrength)
                    Camera.CFrame = newCF
                end
                if autoAimEnabled then
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
                end
                
                -- 自動射撃
                if autoShootEnabled and currentTime - lastShootTime > shootDelay then
                    if autoEquipEnabled then
                        autoEquipWeapon()
                    end
                    
                    shootCoroutine = coroutine.create(function()
                        for i = 1, burstCount do
                            if shootWeapon() then
                                lastShootTime = currentTime
                            end
                            if burstCount > 1 then
                                task.wait(0.08)
                            end
                        end
                    end)
                    coroutine.resume(shootCoroutine)
                end
            end
        end
    end
    
    -- 魔法の円での自動エイム
    if magicCircleEnabled and circleEnabled then
        local target, targetPart = getEnemyInCircle()
        if target and targetPart then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            
            if currentTime - lastShootTime > shootDelay then
                if autoEquipEnabled then
                    autoEquipWeapon()
                end
                
                shootCoroutine = coroutine.create(function()
                    for i = 1, burstCount do
                        if shootWeapon() then
                            lastShootTime = currentTime
                        end
                        if burstCount > 1 then
                            task.wait(0.08)
                        end
                    end
                end)
                coroutine.resume(shootCoroutine)
            end
        end
    end
    
    -- トリガーボット
    if triggerBotEnabled and isLookingAtEnemy() then
        if currentTime - lastShootTime > shootDelay then
            if autoEquipEnabled then
                autoEquipWeapon()
            end
            
            if shootWeapon() then
                lastShootTime = currentTime
            end
        end
    end
end)

-- ========== Fly ==========
local bodyVel
local function toggleFly()
    if flyEnabled then
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not bodyVel then
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
                bodyVel.Parent = player.Character.HumanoidRootPart
            end
        end
    else
        if bodyVel then 
            bodyVel:Destroy() 
            bodyVel = nil 
        end
    end
end

RunService.RenderStepped:Connect(function()
    if flyEnabled and bodyVel then
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        bodyVel.Velocity = moveDir * flySpeed
    end
end)

-- ========== 虹色の円 ==========
local circleFolder = Instance.new("Folder")
circleFolder.Name = "DecorativeCircle"
circleFolder.Parent = game.CoreGui

local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

local function hsvToRgb(h, s, v)
    return Color3.fromHSV(h, s, v)
end

local function createCircle(diameter, thickness)
    for _,v in ipairs(circleFolder:GetChildren()) do v:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "CircleScreen"
    screen.Parent = circleFolder

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, diameter, 0, diameter)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.Parent = screen

    if isMobile then
        frame.Position = UDim2.new(0.5, 0, 0.4, 0)
    else
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    end

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = thickness or 3
    stroke.Color = Color3.fromRGB(255, 255, 255)

    return frame
end

RunService.RenderStepped:Connect(function()
    if circleEnabled then
        local hue = (tick() * 0.2) % 1
        local rainbowColor = hsvToRgb(hue, 1, 1)

        for _,screen in ipairs(circleFolder:GetChildren()) do
            for _,circle in ipairs(screen:GetChildren()) do
                local stroke = circle:FindFirstChildOfClass("UIStroke")
                if stroke then stroke.Color = rainbowColor end

                local scale = 1 + 0.05 * math.sin(tick() * 2)
                circle.Size = UDim2.new(0, 240 * scale, 0, 240 * scale)

                if isMobile then
                    circle.Position = UDim2.new(0.5, 0, 0.4, 0)
                else
                    circle.Position = UDim2.new(0.5, 0, 0.5, 0)
                end
            end
        end
    end
end)

-- ========== Rayfieldウィンドウ作成 ==========
local Window = Rayfield:CreateWindow({
   Name = "暗殺者対保安官2 v3 | 全executer対応",
   LoadingTitle = "超高密度射撃システム",
   LoadingSubtitle = "全エクスプロイト互換版",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "AssassinSheriff2",
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
local ShootTab = Window:CreateTab("射撃設定", nil)
local DebugTab = Window:CreateTab("デバッグ", nil)
local MovementTab = Window:CreateTab("移動", nil)
local VisualTab = Window:CreateTab("視覚効果", nil)

-- ========== 戦闘タブ ==========
local AimSection = CombatTab:CreateSection("エイム設定")

local SoftAimToggle = CombatTab:CreateToggle({
   Name = "ソフトエイム",
   CurrentValue = false,
   Flag = "SoftAim",
   Callback = function(Value)
       softAimEnabled = Value
       log("ソフトエイム: " .. (Value and "有効" or "無効"))
   end,
})

local AutoAimToggle = CombatTab:CreateToggle({
   Name = "自動エイム (スナップ)",
   CurrentValue = false,
   Flag = "AutoAim",
   Callback = function(Value)
       autoAimEnabled = Value
       log("自動エイム: " .. (Value and "有効" or "無効"))
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
       log("サイレントエイム: " .. (Value and "有効" or "無効"))
   end,
})

local TriggerBotToggle = CombatTab:CreateToggle({
   Name = "トリガーボット",
   CurrentValue = false,
   Flag = "TriggerBot",
   Callback = function(Value)
       triggerBotEnabled = Value
       log("トリガーボット: " .. (Value and "有効" or "無効"))
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
       log("エイム強度: " .. Value)
   end,
})

local AimPartDropdown = CombatTab:CreateDropdown({
   Name = "狙う部位",
   Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
   CurrentOption = "Head",
   Flag = "AimPart",
   Callback = function(Option)
       aimPart = Option
       log("狙う部位: " .. Option)
   end,
})

-- ========== 射撃設定タブ ==========
local ShootSection = ShootTab:CreateSection("自動射撃")

local AutoShootToggle = ShootTab:CreateToggle({
   Name = "自動射撃",
   CurrentValue = false,
   Flag = "AutoShoot",
   Callback = function(Value)
       autoShootEnabled = Value
       log("自動射撃: " .. (Value and "有効" or "無効"))
   end,
})

local AutoEquipToggle = ShootTab:CreateToggle({
   Name = "武器自動装備",
   CurrentValue = false,
   Flag = "AutoEquip",
   Callback = function(Value)
       autoEquipEnabled = Value
       log("自動装備: " .. (Value and "有効" or "無効"))
   end,
})

local ShootDelaySlider = ShootTab:CreateSlider({
   Name = "射撃間隔 (秒)",
   Range = {0.05, 1},
   Increment = 0.01,
   CurrentValue = 0.08,
   Flag = "ShootDelay",
   Callback = function(Value)
       shootDelay = Value
       log("射撃間隔: " .. Value .. "秒")
   end,
})

local BurstCountSlider = ShootTab:CreateSlider({
   Name = "バースト射撃数",
   Range = {1, 10},
   Increment = 1,
   CurrentValue = 1,
   Flag = "BurstCount",
   Callback = function(Value)
       burstCount = Value
       log("バースト数: " .. Value)
   end,
})

local ManualShootButton = ShootTab:CreateButton({
   Name = "手動射撃テスト",
   Callback = function()
       log("🎯 手動射撃実行")
       if autoEquipEnabled then
           autoEquipWeapon()
       end
       shootWeapon()
   end,
})

local RescanWeaponButton = ShootTab:CreateButton({
   Name = "武器再スキャン",
   Callback = function()
       local tool = getEquippedWeapon()
       if tool then
           deepScanTool(tool)
           Rayfield:Notify({
               Title = "スキャン完了",
               Content = "Remote: " .. #weaponData.remotes .. "個検出",
               Duration = 3,
               Image = nil,
           })
       else
           Rayfield:Notify({
               Title = "エラー",
               Content = "武器が装備されていません",
               Duration = 3,
               Image = nil,
           })
       end
   end,
})

-- ========== 視覚効果タブ ==========
local CircleSection = VisualTab:CreateSection("魔法の円")

local CircleToggle = VisualTab:CreateToggle({
   Name = "円を表示",
   CurrentValue = false,
   Flag = "Circle",
   Callback = function(Value)
       circleEnabled = Value
       if Value then
           createCircle(240, 3)
           log("視覚円: 有効")
       else
           for _,v in ipairs(circleFolder:GetChildren()) do 
               v:Destroy() 
           end
           log("視覚円: 無効")
       end
   end,
})

local MagicCircleToggle = VisualTab:CreateToggle({
   Name = "円内自動エイム",
   CurrentValue = false,
   Flag = "MagicCircle",
   Callback = function(Value)
       magicCircleEnabled = Value
       log("魔法の円: " .. (Value and "有効" or "無効"))
   end,
})

local CircleRadiusSlider = VisualTab:CreateSlider({
   Name = "円の半径",
   Range = {50, 300},
   Increment = 10,
   CurrentValue = 120,
   Flag = "CircleRadius",
   Callback = function(Value)
       circleRadius = Value
       log("円半径: " .. Value)
       if circleEnabled then
           createCircle(Value * 2, 3)
       end
   end,
})

-- ========== 移動タブ ==========
local MovementSection = MovementTab:CreateSection("飛行")

local FlyToggle = MovementTab:CreateToggle({
   Name = "飛行",
   CurrentValue = false,
   Flag = "Fly",
   Callback = function(Value)
       flyEnabled = Value
       toggleFly()
       log("飛行: " .. (Value and "有効" or "無効"))
   end,
})

local FlySpeedSlider = MovementTab:CreateSlider({
   Name = "飛行速度",
   Range = {10, 200},
   Increment = 5,
   CurrentValue = 50,
   Flag = "FlySpeed",
   Callback = function(Value)
       flySpeed = Value
       log("飛行速度: " .. Value)
   end,
})

-- ========== デバッグタブ ==========
local DebugSection = DebugTab:CreateSection("システム情報")

local LogLabel = DebugTab:CreateLabel("ログは下のボタンで更新")

local RefreshLogButton = DebugTab:CreateButton({
   Name = "ログを更新",
   Callback = function()
       local logText = "=== 最新ログ ===\n"
       for i = math.max(1, #debugLog - 10), #debugLog do
           logText = logText .. debugLog[i] .. "\n"
       end
       LogLabel:Set(logText)
   end,
})

local WeaponInfoLabel = DebugTab:CreateLabel("武器情報: なし")

local RefreshWeaponButton = DebugTab:CreateButton({
   Name = "武器情報を更新",
   Callback = function()
       local tool = getEquippedWeapon()
       if tool then
           local info = string.format(
               "武器: %s\nRemote数: %d\nスクリプト数: %d",
               tool.Name,
               #weaponData.remotes,
               #tool:GetDescendants()
           )
           WeaponInfoLabel:Set(info)
       else
           WeaponInfoLabel:Set("武器: 装備なし")
       end
   end,
})

local CompatibilityLabel = DebugTab:CreateLabel(
    "互換性: " .. 
    (hasGetConnections and "✅ getconnections" or "❌ getconnections") .. " | " ..
    (hasVirtualInput and "✅ VirtualInput" or "❌ VirtualInput")
)

local ClearLogButton = DebugTab:CreateButton({
   Name = "ログをクリア",
   Callback = function()
       debugLog = {}
       LogLabel:Set("ログがクリアされました")
       log("ログクリア")
   end,
})

-- ========== 通知 ==========
Rayfield:Notify({
   Title = "読み込み完了",
   Content = "暗殺者対保安官2 v3 準備完了\n互換性: " .. (isSupportedExecutor and "良好" or "一部制限"),
   Duration = 5,
   Image = nil,
})

log("========================================")
log("  暗殺者対保安官2 超高密度射撃 v3")
log("  作者: @syu_u0316")
log("  全executer対応版")
log("  getconnections: " .. (hasGetConnections and "✅" or "❌"))
log("  VirtualInput: " .. (hasVirtualInput and "✅" or "❌"))
log("========================================")

-- ========== 自動更新ループ ==========
task.spawn(function()
    while true do
        task.wait(5)
        if getEquippedWeapon() then
            local tool = getEquippedWeapon()
            if tool ~= weaponData.currentTool then
                log("🔄 武器変更検出: " .. tool.Name)
            end
        end
    end
end)
