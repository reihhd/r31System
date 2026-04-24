local NoClip = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 0.5,
    VIOLATIONS_KICK = 5,
    MIN_WALL_DIST   = 0.5,
}

local playerData = setmetatable({}, { __mode = "k" })

-- ============================================================
-- DETEKSI NOCLIP
-- Cara kerja: cek apakah HumanoidRootPart berada di dalam
-- geometry (overlap dengan BasePart lain selain karakter sendiri)
-- ============================================================
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function isInsideWall(character, hrp)
    -- Exclude seluruh karakter dari overlap check
    overlapParams.FilterDescendantsInstances = { character }

    -- Cek apakah HRP overlap dengan part lain di sekitarnya
    local size = hrp.Size + Vector3.new(0.2, 0.2, 0.2)  -- sedikit lebih besar dari HRP
    local parts = workspace:GetPartBoundsInBox(
        hrp.CFrame,
        size,
        overlapParams
    )

    -- Kalau ada part lain yang overlap dengan HRP = noclip
    for _, part in ipairs(parts) do
        -- Skip part yang bukan BasePart solid
        if part:IsA("BasePart") and
           not part.CanCollide == false and
           part.Transparency < 1 then
            return true, part.Name
        end
    end

    return false, nil
end

-- ============================================================
-- CEK SATU PLAYER
-- ============================================================
local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local character = player.Character
    if not character then return end

    local hrp      = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end
    if humanoid.Health <= 0 then return end

    -- Skip jika sedang jump atau terjatuh normal
    local velY = hrp.AssemblyLinearVelocity.Y
    if math.abs(velY) > 20 then return end

    local inside, partName = isInsideWall(character, hrp)

    if inside then
        data.violations += 1
        warn(string.format(
            "[r31|NoClip] %s → inside '%s' | Flag=%d/%d",
            player.Name,
            tostring(partName),
            data.violations,
            cfg.VIOLATIONS_KICK
        ))

        if data.violations >= cfg.VIOLATIONS_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick("[r31] NoClip hack detected.")
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

local function onPlayerAdded(player, cfg)
    playerCount += 1
    local offset = (playerCount - 1) * 0.15

    playerData[player] = {
        violations  = 0,
        connections = {},
    }

    local conn = player.CharacterAdded:Connect(function()
        if playerData[player] then
            playerData[player].violations = 0
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
function NoClip.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|NoClip] Aktif — interval=" .. cfg.CHECK_INTERVAL .. "s")

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p, cfg)
    end

    Players.PlayerAdded:Connect(function(p)
        onPlayerAdded(p, cfg)
    end)

    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return NoClip
