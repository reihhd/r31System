local CopyMap = {}

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_CONFIG = {
    -- Discord webhook untuk notifikasi (isi di Settings)
    DISCORD_WEBHOOK     = "",

    -- Kick player yang terdeteksi
    KICK_ON_DETECT      = true,
    KICK_MESSAGE        = "[r31] Unauthorized activity detected.",

    -- Nama RemoteEvent untuk report dari client
    REPORT_REMOTE_NAME  = "r31_Report",

    -- Obfuscate nama folder/model penting di workspace
    OBFUSCATE_WORKSPACE = true,

    -- Daftar nama folder/model yang ingin diobfuscate
    -- Kosongkan jika tidak ingin obfuscate
    IMPORTANT_FOLDERS   = {
        "Map",
        "Baseplate",
        "Terrain",
    },
}

-- ============================================================
-- UTIL: Generate nama random
-- ============================================================
local function randomName(len)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    for i = 1, len or 12 do
        local idx = math.random(1, #chars)
        result[i] = chars:sub(idx, idx)
    end
    return table.concat(result)
end

-- ============================================================
-- OBFUSCATE WORKSPACE
-- Rename folder penting agar dump tidak mudah digunakan
-- ============================================================
local function obfuscateWorkspace(cfg)
    if not cfg.OBFUSCATE_WORKSPACE then return end

    for _, folderName in ipairs(cfg.IMPORTANT_FOLDERS) do
        local obj = workspace:FindFirstChild(folderName, true)
        if obj then
            local newName = randomName(16)
            obj.Name = newName
            print("[r31|CopyMap] Obfuscated: " .. folderName .. " → " .. newName)
        end
    end
end

-- ============================================================
-- KIRIM KE DISCORD
-- ============================================================
local function sendDiscord(player, webhook)
    if not webhook or webhook == "" then return end

    local data = {
        embeds = {{
            title       = "🚨 SaveInstance Terdeteksi!",
            description = string.format(
                "**Player:** %s\n**UserId:** %d\n**GameId:** %d",
                player.Name,
                player.UserId,
                game.GameId
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
local reported = {}  -- anti spam report

local function handleReport(player, cfg)
    -- Satu kali report per player per session
    if reported[player] then return end
    reported[player] = true

    warn(string.format("[r31|CopyMap] SaveInstance terdeteksi: %s (%d)",
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

-- ============================================================
-- BUAT REMOTE UNTUK REPORT CLIENT
-- ============================================================
local function setupRemote(cfg)
    -- Cek apakah sudah ada (dari Honeypot atau sistem lain)
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

    return remote
end

-- ============================================================
-- CLIENT SCRIPT — Di-inject ke ReplicatedFirst via server
-- Deteksi UGCValidationService dari sisi client
-- ============================================================
local CLIENT_SCRIPT = [[
local RunService = game:GetService("RunService")
if RunService:IsStudio() then return end

local Players      = game:GetService("Players")
local RepStorage   = game:GetService("ReplicatedStorage")
local player       = Players.LocalPlayer

-- Tunggu remote siap
local remote = RepStorage:WaitForChild("]] .. "r31_Report" .. [[", 10)
if not remote then return end

local reported = false

local function report()
    if reported then return end
    reported = true
    pcall(function()
        remote:FireServer("SaveInstance")
    end)
end

-- Metode 1: Cek UGCValidationService (cara paling umum SaveInstance bekerja)
task.spawn(function()
    while not reported do
        if pcall(function() return game:GetService("UGCValidationService") end) then
            report()
        end
        task.wait(0.5)
    end
end)

-- Metode 2: Cek CoreGui yang tidak normal (beberapa exploit inject ke sini)
task.spawn(function()
    while not reported do
        local coreGui = game:GetService("CoreGui")
        for _, child in ipairs(coreGui:GetChildren()) do
            if child.Name:lower():find("save") or
               child.Name:lower():find("dump") or
               child.Name:lower():find("copy") then
                report()
            end
        end
        task.wait(1)
    end
end)
]]

local function injectClientScript(cfg)
    -- Buat LocalScript di ReplicatedFirst agar jalan sebelum game load
    local repFirst = game:GetService("ReplicatedFirst")

    -- Hapus inject lama kalau ada
    local old = repFirst:FindFirstChild("r31_CM")
    if old then old:Destroy() end

    local ls       = Instance.new("LocalScript")
    ls.Name        = "r31_CM"
    ls.Source      = CLIENT_SCRIPT
    ls.Parent      = repFirst
end

-- ============================================================
-- ENTRY POINT
-- ============================================================
function CopyMap.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    -- Copy table config
    cfg.IMPORTANT_FOLDERS = (config and config.IMPORTANT_FOLDERS) or DEFAULT_CONFIG.IMPORTANT_FOLDERS
    cfg.DISCORD_WEBHOOK   = (config and config.DISCORD_WEBHOOK)   or DEFAULT_CONFIG.DISCORD_WEBHOOK

    print("[r31|CopyMap] Aktif")

    -- 1. Obfuscate nama folder penting
    obfuscateWorkspace(cfg)

    -- 2. Setup remote untuk terima report client
    setupRemote(cfg)

    -- 3. Inject client script detector
    injectClientScript(cfg)

    -- Bersihkan reported saat player keluar
    Players.PlayerRemoving:Connect(function(player)
        reported[player] = nil
    end)
end

return CopyMap
]]
