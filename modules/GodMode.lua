local GodMode = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    MAX_HEALTH      = 1000,
    VIOLATIONS_KICK = 3,
}

local playerData = setmetatable({}, { __mode = "k" })

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

    local currentHealth    = humanoid.Health
    local currentMaxHealth = humanoid.MaxHealth

    -- Cek MaxHealth melebihi batas
    local isGodMaxHealth = currentMaxHealth > cfg.MAX_HEALTH

    -- Cek Health melebihi MaxHealth asli (exploit set health > maxhealth)
    local isHealthOverMax = currentHealth > currentMaxHealth

    -- Cek infinite health (math.huge)
    local isInfinite = currentMaxHealth == math.huge or currentHealth == math.huge

    if isGodMaxHealth or isHealthOverMax or isInfinite then
        data.violations += 1

        warn(string.format(
            "[r31|GodMode] %s → HP=%.1f | MaxHP=%.1f | Flag=%d/%d",
            player.Name,
            currentHealth,
            currentMaxHealth,
            data.violations,
            cfg.VIOLATIONS_KICK
        ))

        -- Paksa reset health ke normal dulu sebelum kick
        pcall(function()
            humanoid.MaxHealth = 100
            humanoid.Health    = 100
        end)

        if data.violations >= cfg.VIOLATIONS_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick("[r31] GodMode hack detected.")
                end
            end)
        end
    else
        if data.violations > 0 then
            data.violations -= 1
        end
    end
end

-- ============================================================
-- SETUP PLAYER
-- ============================================================
local playerCount = 0
local STAGGER     = 0.15

local function onPlayerAdded(player, cfg)
    playerCount += 1
    local offset = (playerCount - 1) * STAGGER

    playerData[player] = {
        violations  = 0,
        connections = {},
    }

    -- Reset violations saat respawn
    local conn = player.CharacterAdded:Connect(function()
        if playerData[player] then
            playerData[player].violations = 0
        end
    end)
    table.insert(playerData[player].connections, conn)

    -- Loop dengan stagger
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
function GodMode.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|GodMode] Aktif — maxHP=" .. cfg.MAX_HEALTH)

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p, cfg)
    end

    Players.PlayerAdded:Connect(function(p)
        onPlayerAdded(p, cfg)
    end)

    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return GodMode
