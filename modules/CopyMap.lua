local CopyMap = {}

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_CONFIG = {
    DISCORD_WEBHOOK  = "",
    KICK_ON_DETECT   = true,
    KICK_MESSAGE     = "[r31] Unauthorized activity detected.",
    REPORT_REMOTE_NAME = "r31_Report",
}

-- ============================================================
-- ARCHIVABLE PROTECTION — ini yang paling efektif
-- Exploiter tidak bisa ubah ini dari client karena ini server-side
-- ============================================================
local function setNotArchivable(instance)
    pcall(function()
        instance.Archivable = false
    end)
    for _, child in ipairs(instance:GetChildren()) do
        setNotArchivable(child)
    end
end

local function watchInstance(instance)
    pcall(function()
        instance:GetPropertyChangedSignal("Archivable"):Connect(function()
            if instance.Archivable then
                instance.Archivable = false
            end
        end)
    end)
end

local function protectWorkspace()
    -- Set semua instance di workspace tidak archivable
    setNotArchivable(workspace)

    -- Watch semua yang sudah ada
    for _, desc in ipairs(workspace:GetDescendants()) do
        watchInstance(desc)
    end

    -- Watch instance baru
    workspace.DescendantAdded:Connect(function(desc)
        pcall(function()
            desc.Archivable = false
            watchInstance(desc)
        end)
    end)

    print("[r31|CopyMap] Archivable protection aktif — workspace tidak bisa disalin")
end

-- ============================================================
-- DISCORD WEBHOOK
-- ============================================================
local function sendDiscord(player, webhook)
    if not webhook or webhook == "" then return end
    local data = {
        embeds = {{
            title = "🚨 Copy Map Terdeteksi!",
            description = string.format(
                "**Player:** %s\n**UserId:** %d\n**GameId:** %d",
                player.Name, player.UserId, game.GameId
            ),
            color  = 15158332,
            footer = { text = "r31 Anti-Cheat" }
        }}
    }
    pcall(function()
        HttpService:PostAsync(
            webhook,
            HttpService:JSONEncode(data),
            Enum.HttpContentType.ApplicationJson
        )
    end)
end

-- ============================================================
-- HANDLE REPORT DARI CLIENT
-- ============================================================
local reported = setmetatable({}, { __mode = "k" })

local function handleReport(player, cfg)
    if reported[player] then return end
    reported[player] = true

    warn(string.format("[r31|CopyMap] Terdeteksi: %s (%d)",
        player.Name, player.UserId))

    sendDiscord(player, cfg.DISCORD_WEBHOOK)

    if cfg.KICK_ON_DETECT then
        task.defer(function()
            if player and player.Parent then
                player:Kick(cfg.KICK_MESSAGE)
            end
        end)
    end
end

local function setupRemote(cfg)
    local existing = ReplicatedStorage:FindFirstChild(cfg.REPORT_REMOTE_NAME)
    if existing then existing:Destroy() end

    local remote  = Instance.new("RemoteEvent")
    remote.Name   = cfg.REPORT_REMOTE_NAME
    remote.Parent = ReplicatedStorage

    remote.OnServerEvent:Connect(function(player, signal)
        if signal == "SaveInstance" then
            handleReport(player, cfg)
        end
    end)
end

-- ============================================================
-- ENTRY POINT
-- ============================================================
function CopyMap.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end
    cfg.DISCORD_WEBHOOK = (config and config.DISCORD_WEBHOOK) or DEFAULT_CONFIG.DISCORD_WEBHOOK

    print("[r31|CopyMap] Aktif")

    -- Ini yang paling penting — jalankan di server
    protectWorkspace()
    setupRemote(cfg)

    Players.PlayerRemoving:Connect(function(player)
        reported[player] = nil
    end)
end

return CopyMap
