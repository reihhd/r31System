local Size = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    VIOLATIONS_KICK = 3,
    MAX_SCALE       = 2.0,
    MIN_SCALE       = 0.1,
}

local playerData = setmetatable({}, { __mode = "k" })

local function getScaleValue(scaleObject)
    if scaleObject and scaleObject:IsA("NumberValue") then
        return scaleObject.Value
    end
    return 1.0  -- nilai normal jika tidak ada
end

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Ambil NumberValue dari Humanoid
    local depthScale = humanoid:FindFirstChild("BodyDepthScale")
    local heightScale = humanoid:FindFirstChild("BodyHeightScale")
    local widthScale = humanoid:FindFirstChild("BodyWidthScale")
    local proportionScale = humanoid:FindFirstChild("BodyProportionScale")
    local typeScale = humanoid:FindFirstChild("BodyTypeScale")

    local depth = getScaleValue(depthScale)
    local height = getScaleValue(heightScale)
    local width = getScaleValue(widthScale)
    local proportion = getScaleValue(proportionScale)
    local bodyType = getScaleValue(typeScale)

    local maxScale = math.max(depth, height, width, proportion, bodyType)
    local minScale = math.min(depth, height, width, proportion, bodyType)

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
