local Speed = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL  = 1.0,
    VIOLATIONS_KICK = 4,
    MAX_WALKSPEED   = 20,
    MAX_JUMPPOWER   = 60,
}

local playerData = setmetatable({}, { __mode = "k" })

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local flag = false

    if humanoid.WalkSpeed > cfg.MAX_WALKSPEED then
        flag = true
        warn(string.format("[r31|Speed] %s → WalkSpeed=%.1f", player.Name, humanoid.WalkSpeed))
    end

    if humanoid.JumpPower > cfg.MAX_JUMPPOWER then
        flag = true
        warn(string.format("[r31|Speed] %s → JumpPower=%.1f", player.Name, humanoid.JumpPower))
    end

    if flag then
        data.violations += 1
        if data.violations >= cfg.VIOLATIONS_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick("[r31] Speed cheat detected.")
                end
            end)
        end
    else
        if data.violations > 0 then data.violations -= 1 end
    end
end

local playerCount = 0

local function onPlayerAdded(player, cfg)
    playerCount += 1
    local offset = (playerCount - 1) * 0.15

    playerData[player] = { violations = 0, connections = {} }

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

function Speed.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|Speed] Aktif — maxWS=" .. cfg.MAX_WALKSPEED .. " maxJP=" .. cfg.MAX_JUMPPOWER)

    for _, p in ipairs(Players:GetPlayers()) do
        onPlayerAdded(p, cfg)
    end
    Players.PlayerAdded:Connect(function(p) onPlayerAdded(p, cfg) end)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Speed
