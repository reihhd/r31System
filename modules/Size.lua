local Size = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    VIOLATIONS_KICK = 3,
    MAX_SCALE       = 2.0,
    MIN_SCALE       = 0.1,
}

local playerData = setmetatable({}, { __mode = "k" })

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Ambil skala dari Humanoid (properti yang benar)
    local bodyDepth = humanoid.BodyDepthScale
    local bodyHeight = humanoid.BodyHeightScale
    local bodyWidth = humanoid.BodyWidthScale
    local bodyProportion = humanoid.BodyProportionScale
    local bodyType = humanoid.BodyTypeScale

    -- Cek apakah ada yang melebihi batas
    local maxScale = math.max(bodyDepth, bodyHeight, bodyWidth, bodyProportion, bodyType)
    local minScale = math.min(bodyDepth, bodyHeight, bodyWidth, bodyProportion, bodyType)

    if maxScale > cfg.MAX_SCALE or minScale < cfg.MIN_SCALE then
        data.violations = (data.violations or 0) + 1
        warn(string.format("[r31|Size] %s → scale violation max=%.2f min=%.2f", player.Name, maxScale, minScale))
        if data.violations >= cfg.VIOLATIONS_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick("[r31] Illegal character scale detected.")
                end
            end)
        end
    else
        if data.violations and data.violations > 0 then
            data.violations = data.violations - 1
        end
    end
end

function Size.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end
    print("[r31|Size] Aktif — maxScale=" .. cfg.MAX_SCALE .. " minScale=" .. cfg.MIN_SCALE)

    for _, p in ipairs(Players:GetPlayers()) do
        playerData[p] = { violations = 0 }
    end
    Players.PlayerAdded:Connect(function(p) playerData[p] = { violations = 0 } end)
    Players.PlayerRemoving:Connect(function(p) playerData[p] = nil end)

    task.spawn(function()
        while true do
            for _, p in ipairs(Players:GetPlayers()) do
                task.defer(function() checkPlayer(p, cfg) end)
            end
            task.wait(cfg.CHECK_INTERVAL)
        end
    end)
end

return Size
