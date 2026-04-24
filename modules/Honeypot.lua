local Honeypot = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_CONFIG = {
    FOLDER_NAME      = "GameSystems",
    INSTANT_KICK     = true,
    KICK_MESSAGE     = "[r31] Cheat detected.",
    REMOTE_EVENTS    = { "GiveCash", "GiveAdmin", "SetHealth" },
    REMOTE_FUNCTIONS = { "GetAdminLevel", "GetPlayerData" },
}

-- ============================================================
-- UTIL: Cari player dari siapapun yang fire remote
-- ============================================================
local function getPlayer(caller)
    -- Untuk RemoteEvent, argument pertama adalah player
    if typeof(caller) == "Instance" and caller:IsA("Player") then
        return caller
    end
    return nil
end

local function kickPlayer(player, cfg, remoteName)
    if not player or not player.Parent then return end

    warn(string.format(
        "[r31|Honeypot] %s mencoba fire remote tipuan: '%s'",
        player.Name,
        remoteName
    ))

    task.defer(function()
        if player and player.Parent then
            player:Kick(cfg.KICK_MESSAGE)
        end
    end)
end

-- ============================================================
-- BUAT FOLDER HONEYPOT
-- ============================================================
local function createHoneypot(cfg)
    -- Hapus folder lama kalau ada (prevent duplicate)
    local existing = ReplicatedStorage:FindFirstChild(cfg.FOLDER_NAME)
    if existing then
        existing:Destroy()
    end

    -- Buat folder baru
    local folder  = Instance.new("Folder")
    folder.Name   = cfg.FOLDER_NAME
    folder.Parent = ReplicatedStorage

    -- ============================================================
    -- Buat semua RemoteEvent tipuan
    -- ============================================================
    for _, name in ipairs(cfg.REMOTE_EVENTS) do
        local remote  = Instance.new("RemoteEvent")
        remote.Name   = name
        remote.Parent = folder

        -- Siapapun yang OnServerEvent akan langsung kick
        remote.OnServerEvent:Connect(function(player, ...)
            kickPlayer(player, cfg, name)
        end)
    end

    -- ============================================================
    -- Buat semua RemoteFunction tipuan
    -- ============================================================
    for _, name in ipairs(cfg.REMOTE_FUNCTIONS) do
        local remote  = Instance.new("RemoteFunction")
        remote.Name   = name
        remote.Parent = folder

        -- Siapapun yang InvokeServer akan langsung kick
        remote.OnServerInvoke = function(player, ...)
            kickPlayer(player, cfg, name)
            -- Return nilai palsu agar tidak error di sisi exploiter
            return false
        end
    end

    print(string.format(
        "[r31|Honeypot] Folder '%s' dibuat — %d RemoteEvent, %d RemoteFunction",
        cfg.FOLDER_NAME,
        #cfg.REMOTE_EVENTS,
        #cfg.REMOTE_FUNCTIONS
    ))
end

-- ============================================================
-- ENTRY POINT
-- ============================================================
function Honeypot.start(_loader, config)
    local cfg = {}

    -- Merge config (khusus table harus di-copy manual)
    cfg.FOLDER_NAME      = (config and config.FOLDER_NAME)      or DEFAULT_CONFIG.FOLDER_NAME
    cfg.INSTANT_KICK     = (config and config.INSTANT_KICK ~= nil) and config.INSTANT_KICK or DEFAULT_CONFIG.INSTANT_KICK
    cfg.KICK_MESSAGE     = (config and config.KICK_MESSAGE)      or DEFAULT_CONFIG.KICK_MESSAGE
    cfg.REMOTE_EVENTS    = (config and config.REMOTE_EVENTS)     or DEFAULT_CONFIG.REMOTE_EVENTS
    cfg.REMOTE_FUNCTIONS = (config and config.REMOTE_FUNCTIONS)  or DEFAULT_CONFIG.REMOTE_FUNCTIONS

    print("[r31|Honeypot] Aktif — folder: " .. cfg.FOLDER_NAME)

    -- Buat honeypot saat server start
    createHoneypot(cfg)
end

return Honeypot
