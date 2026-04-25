local Teleport = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    VIOLATIONS_KICK = 3,
    MAX_DISTANCE    = 200,
}

local playerData = setmetatable({}, { __mode = "k" })

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid or humanoid.Health <= 0 then return end

    local currentPos = hrp.Position

    if data.lastPos then
        local dist = (currentPos - data.lastPos).Magnitude
        if dist > cfg.MAX_DISTANCE then
            data.violations += 1
            warn(string.format(
                "[r31|Teleport] %s → jumped %.1f studs | Flag=%d/%d",
                player.Name, dist, data.violations, cfg.VIOLATIONS_KICK
            ))
            if data.violations >= cfg.VIOLATIONS_KICK then
                task.defer(function()
                    if player and player.Parent then
                        player:Kick("[r31] Teleport hack detected.")
                    end
                end)
            end
        else
            if data.violations > 0 then data.violations -= 1 end
        end
    end

    data.lastPos = currentPos
end

local playerCount = 0

local function onPlayerAdded(player, cfg)
    playerCount += 1
    local offset = (playerCount - 1) * 0.15

    playerData[player] = { violations = 0, lastPos = nil, connections = {} }

    local conn = player.CharacterAdded:Connect(function()
        if playerData[player] then
            playerData[player].violations = 0
            playerData[player].lastPos    = nil
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

function Teleport.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|Teleport] Aktif — maxDist=" .. cfg.MAX_DISTANCE)

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p, cfg)
    end
    Players.PlayerAdded:Connect(function(p) onPlayerAdded(p, cfg) end)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Teleport
