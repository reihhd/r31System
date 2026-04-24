local Speed = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL   = 1.0,
    VIOLATIONS_KICK  = 4,
    MAX_WALKSPEED    = 20,      -- batas atas walkspeed (normal Roblox = 16)
    MAX_JUMPPOWER    = 60,      -- batas atas jumppower (normal = 50)
}

local playerData = setmetatable({}, { __mode = "k" })

local function checkPlayer(player, cfg)
    local data = playerData[player]
    if not data then return end

    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local walkspeed = humanoid.WalkSpeed
    local jumppower = humanoid.JumpPower

    local flag = false

    if walkspeed > cfg.MAX_WALKSPEED then
        flag = true
        warn(string.format("[r31|Speed] %s → walkspeed too high: %.1f", player.Name, walkspeed))
    end

    if jumppower > cfg.MAX_JUMPPOWER then
        flag = true
        warn(string.format("[r31|Speed] %s → jumppower too high: %.1f", player.Name, jumppower))
    end

    if flag then
        data.violations = data.violations + 1
        if data.violations >= cfg.VIOLATIONS_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick("[r31] Speed cheat detected.")
                end
            end)
        end
    else
        if data.violations > 0 then
            data.violations = data.violations - 1
        end
    end
end

function Speed.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|Speed] Aktif — interval=" .. cfg.CHECK_INTERVAL .. "s, maxWS=" .. cfg.MAX_WALKSPEED .. ", maxJP=" .. cfg.MAX_JUMPPOWER)

    for _, p in ipairs(Players:GetPlayers()) do
        playerData[p] = { violations = 0 }
    end

    Players.PlayerAdded:Connect(function(p)
        playerData[p] = { violations = 0 }
    end)

    Players.PlayerRemoving:Connect(function(p)
        playerData[p] = nil
    end)

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

return Speed
