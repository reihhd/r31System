local Teleport = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL   = 1.0,
    VIOLATIONS_KICK  = 3,
    MAX_DISTANCE     = 200,    -- jarak maksimal per interval (studs)
}

local lastPositions = setmetatable({}, { __mode = "k" })
local violations = setmetatable({}, { __mode = "k" })

local function checkPlayer(player, cfg)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local currentPos = hrp.Position
    local lastPos = lastPositions[player]

    if lastPos then
        local distance = (currentPos - lastPos).Magnitude
        if distance > cfg.MAX_DISTANCE then
            violations[player] = (violations[player] or 0) + 1
            warn(string.format("[r31|Teleport] %s → distance jumped: %.1f studs", player.Name, distance))
            if violations[player] >= cfg.VIOLATIONS_KICK then
                task.defer(function()
                    if player and player.Parent then
                        player:Kick("[r31] Teleport hack detected.")
                    end
                end)
            end
        else
            if violations[player] and violations[player] > 0 then
                violations[player] = violations[player] - 1
            end
        end
    end

    lastPositions[player] = currentPos
end

function Teleport.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|Teleport] Aktif — interval=" .. cfg.CHECK_INTERVAL .. "s, maxDist=" .. cfg.MAX_DISTANCE)

    for _, p in ipairs(Players:GetPlayers()) do
        lastPositions[p] = nil
        violations[p] = 0
    end

    Players.PlayerAdded:Connect(function(p)
        lastPositions[p] = nil
        violations[p] = 0
    end)

    Players.PlayerRemoving:Connect(function(p)
        lastPositions[p] = nil
        violations[p] = nil
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

return Teleport
