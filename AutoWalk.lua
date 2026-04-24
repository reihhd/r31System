local AutoWalk = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL     = 1.0,      -- detik
    VIOLATIONS_KICK    = 4,
    MIN_DISTANCE       = 10,       -- jarak minimal ke target untuk dicurigai
    TIME_CONSISTENT    = 5,        -- detik konsisten mengikuti target yang sama
    MAX_ANGLE_VARIATION = 15,      -- derajat maksimum perubahan arah (normal lebih acak)
    VELOCITY_TOLERANCE = 2,        -- toleransi kecepatan (studi/detik)
}

local playerData = setmetatable({}, { __mode = "k" })

-- Helper: hitung sudut antara dua vektor arah (dalam derajat)
local function angleBetween(v1, v2)
    if v1.Magnitude == 0 or v2.Magnitude == 0 then return 0 end
    return math.deg(math.acos(v1.Unit:Dot(v2.Unit)))
end

-- Helper: cek apakah posisi pemain bergerak menuju target
local function isMovingToward(hrpPos, targetPos)
    local direction = (targetPos - hrpPos).Unit
    local velocity = hrpPos.Parent and hrpPos.Parent:FindFirstChild("Humanoid") and hrpPos.Parent.Humanoid:GetPropertyChangedSignal("WalkSpeed") or nil
    -- Lebih sederhana: bandingkan arah pergerakan dengan arah ke target
    if not hrpPos.Parent then return false end
    local humanoid = hrpPos.Parent:FindFirstChild("Humanoid")
    if not humanoid then return false end
    local moveDirection = humanoid.MoveDirection
    if moveDirection.Magnitude == 0 then return false end
    local angle = angleBetween(moveDirection, direction)
    return angle < 30  -- toleransi 30 derajat
end

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Health <= 0 then return end

    local now = tick()
    local currentPos = hrp.Position

    -- Cari target terdekat (player lain)
    local closestPlayer = nil
    local closestDist = cfg.MIN_DISTANCE + 1
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player then
            local otherChar = other.Character
            if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                local dist = (otherChar.HumanoidRootPart.Position - currentPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlayer = other
                end
            end
        end
    end

    if not closestPlayer or closestDist > cfg.MIN_DISTANCE then
        -- Tidak ada target dalam jangkauan, reset pelacakan
        data.currentTarget = nil
        data.targetStartTime = nil
        data.lastPositions = {}
        data.lastDirections = {}
        return
    end

    -- Ada target
    local targetChar = closestPlayer.Character
    if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then
        return
    end
    local targetPos = targetChar.HumanoidRootPart.Position

    -- Apakah pemain bergerak menuju target?
    local movingToward = isMovingToward(currentPos, targetPos)
    if not movingToward then
        -- Tidak bergerak ke arah target, reset
        data.currentTarget = nil
        data.targetStartTime = nil
        data.lastPositions = {}
        data.lastDirections = {}
        return
    end

    -- Cek konsistensi: apakah target yang sama terus menerus?
    if data.currentTarget == closestPlayer then
        -- Target sama, hitung durasi
        if not data.targetStartTime then
            data.targetStartTime = now
        end
        local duration = now - data.targetStartTime
        if duration >= cfg.TIME_CONSISTENT then
            -- Sudah terlalu lama mengikuti target yang sama -> flag
            data.violations = (data.violations or 0) + 1
            warn(string.format("[r31|AutoWalk] %s → auto-follow detected (target: %s, duration: %.1fs)", player.Name, closestPlayer.Name, duration))
            if data.violations >= cfg.VIOLATIONS_KICK then
                task.defer(function()
                    if player and player.Parent then
                        player:Kick("[r31] Auto-walk / auto-follow detected.")
                    end
                end)
            end
            -- Reset timer agar tidak memflag terus setiap interval
            data.targetStartTime = now
        end
    else
        -- Ganti target, reset timer
        data.currentTarget = closestPlayer
        data.targetStartTime = now
        data.violations = (data.violations or 0) > 0 and data.violations - 1 or 0
    end
end

function AutoWalk.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|AutoWalk] Aktif — interval=" .. cfg.CHECK_INTERVAL .. "s, timeConsistent=" .. cfg.TIME_CONSISTENT .. "s, minDist=" .. cfg.MIN_DISTANCE)

    -- Inisialisasi data untuk pemain yang sudah ada
    for _, p in ipairs(Players:GetPlayers()) do
        playerData[p] = {
            violations = 0,
            currentTarget = nil,
            targetStartTime = nil,
        }
    end

    Players.PlayerAdded:Connect(function(p)
        playerData[p] = {
            violations = 0,
            currentTarget = nil,
            targetStartTime = nil,
        }
    end)

    Players.PlayerRemoving:Connect(function(p)
        playerData[p] = nil
    end)

    -- Loop pengecekan
    task.spawn(function()
        while true do
            for _, p in ipairs(Players:GetPlayers()) do
                task.defer(function()
                    checkPlayer(p, cfg)
                end)
            end
            task.wait(cfg.CHECK_INTERVAL)
        end
    end)
end

return AutoWalk
