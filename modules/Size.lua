local Size = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    VIOLATIONS_KICK = 3,
    MAX_SCALE       = 2.0,
    MIN_SCALE       = 0.1,
}

-- Part yang dicek ukurannya
local BODY_PARTS = {
    "HumanoidRootPart",
    "UpperTorso",
    "LowerTorso",
    "Head",
}

local playerData = setmetatable({}, { __mode = "k" })

-- ============================================================
-- AMBIL NORMAL SIZE SAAT CHARACTER SPAWN
-- Disimpan sebagai referensi ukuran asli
-- ============================================================
local function captureNormalSize(character)
    local sizes = {}
    for _, partName in ipairs(BODY_PARTS) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            sizes[partName] = part.Size
        end
    end
    return sizes
end

-- ============================================================
-- CEK SATU PLAYER
-- ============================================================
local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if humanoid.Health <= 0 then return end

    -- Kalau belum ada normal size, capture dulu
    if not data.normalSize then
        data.normalSize = captureNormalSize(character)
        return
    end

    -- Cek lewat HumanoidDescription scale
    local desc = humanoid:FindFirstChild("HumanoidDescription")
    if desc then
        local scales = {
            humanoid.BodyDepthScale,
            desc.BodyHeightScale,
            desc.BodyWidthScale,
            desc.HeadScale,
        }

        for _, scale in ipairs(scales) do
            if scale > cfg.MAX_SCALE or scale < cfg.MIN_SCALE then
                data.violations += 1

                warn(string.format(
                    "[r31|Size] %s → scale=%.2f (max=%.2f, min=%.2f) | Flag=%d/%d",
                    player.Name,
                    scale,
                    cfg.MAX_SCALE,
                    cfg.MIN_SCALE,
                    data.violations,
                    cfg.VIOLATIONS_KICK
                ))

                -- Paksa reset scale ke normal
                pcall(function()
                    humanoid.BodyDepthScale  = 1
                    desc.BodyHeightScale = 1
                    desc.BodyWidthScale  = 1
                    desc.HeadScale       = 1
                    humanoid:ApplyDescription(desc)
                end)

                if data.violations >= cfg.VIOLATIONS_KICK then
                    task.defer(function()
                        if player and player.Parent then
                            player:Kick("[r31] Size hack detected.")
                        end
                    end)
                end

                return
            end
        end
    end

    -- Cek juga lewat ukuran part langsung (backup)
    for partName, normalSize in pairs(data.normalSize) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local currentSize = part.Size
            local scaleX = currentSize.X / normalSize.X
            local scaleY = currentSize.Y / normalSize.Y
            local scaleZ = currentSize.Z / normalSize.Z

            if scaleX > cfg.MAX_SCALE or scaleY > cfg.MAX_SCALE or scaleZ > cfg.MAX_SCALE or
               scaleX < cfg.MIN_SCALE or scaleY < cfg.MIN_SCALE or scaleZ < cfg.MIN_SCALE then

                data.violations += 1

                warn(string.format(
                    "[r31|Size] %s → part '%s' scale abnormal | Flag=%d/%d",
                    player.Name,
                    partName,
                    data.violations,
                    cfg.VIOLATIONS_KICK
                ))

                if data.violations >= cfg.VIOLATIONS_KICK then
                    task.defer(function()
                        if player and player.Parent then
                            player:Kick("[r31] Size hack detected.")
                        end
                    end)
                end

                return
            end
        end
    end

    -- Tidak ada anomali, kurangi violations
    if data.violations > 0 then
        data.violations -= 1
    end
end

-- ============================================================
-- SETUP PLAYER
-- ============================================================
local playerCount = 0

local function onPlayerAdded(player, cfg)
    playerCount += 1
    local offset = (playerCount - 1) * 0.15

    playerData[player] = {
        violations  = 0,
        connections = {},
        normalSize  = nil,
    }

    -- Capture normal size setiap respawn
    local conn = player.CharacterAdded:Connect(function(character)
        if playerData[player] then
            playerData[player].violations = 0
            playerData[player].normalSize = nil

            -- Tunggu character fully loaded dulu
            task.delay(1, function()
                if playerData[player] and player.Character then
                    playerData[player].normalSize = captureNormalSize(player.Character)
                end
            end)
        end
    end)
    table.insert(playerData[player].connections, conn)

    task.delay(offset, function()
        while playerData[player] do
            checkPlayer(player, cfg)
            task.wait(cfg.CHECK_INTERVAL)
        end
    end)
end

local function onPlayerRemoving(player)
    local data = playerData[player]
    if data then
        for _, conn in ipairs(data.connections) do
            conn:Disconnect()
        end
    end
    playerData[player] = nil
end

-- ============================================================
-- ENTRY POINT
-- ============================================================
function Size.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|Size] Aktif — maxScale=" .. cfg.MAX_SCALE .. " minScale=" .. cfg.MIN_SCALE)

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p, cfg)
    end

    Players.PlayerAdded:Connect(function(p)
        onPlayerAdded(p, cfg)
    end)

    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Size
