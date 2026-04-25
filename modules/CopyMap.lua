local CopyMap = {}

local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEFAULT_CONFIG = {
    DISCORD_WEBHOOK     = "",
    KICK_ON_DETECT      = true,
    KICK_MESSAGE        = "[r31] Unauthorized activity detected.",
    REPORT_REMOTE_NAME  = "r31_Report",
    OBFUSCATE_WORKSPACE = true,
    IMPORTANT_FOLDERS   = { "Map", "Baseplate" },
}

local function randomName(len)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}
    for i = 1, len or 12 do
        local idx = math.random(1, #chars)
        result[i] = chars:sub(idx, idx)
    end
    return table.concat(result)
end

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

local function sendDiscord(player, webhook)
    if not webhook or webhook == "" then return end
    local data = {
        embeds = {{
            title       = "🚨 SaveInstance Terdeteksi!",
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

local reported = setmetatable({}, { __mode = "k" })

local function handleReport(player, cfg)
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

local function injectClientScript(remoteName)
    local repFirst = game:GetService("ReplicatedFirst")

    local old = repFirst:FindFirstChild("r31_CM")
    if old then old:Destroy() end

    local ls        = Instance.new("LocalScript")
    ls.Name         = "r31_CM"
    ls.Parent       = repFirst

    -- Source dibuat manual agar tidak ada string escape issue
    local src = {}
    src[#src+1] = 'local RunService = game:GetService("RunService")'
    src[#src+1] = 'if RunService:IsStudio() then return end'
    src[#src+1] = 'local Players    = game:GetService("Players")'
    src[#src+1] = 'local RepStorage = game:GetService("ReplicatedStorage")'
    src[#src+1] = 'local remote     = RepStorage:WaitForChild("' .. remoteName .. '", 15)'
    src[#src+1] = 'if not remote then return end'
    src[#src+1] = 'local reported = false'
    src[#src+1] = 'local function report()'
    src[#src+1] = '    if reported then return end'
    src[#src+1] = '    reported = true'
    src[#src+1] = '    pcall(function() remote:FireServer("SaveInstance") end)'
    src[#src+1] = 'end'
    src[#src+1] = '-- Deteksi 1: UGCValidationService'
    src[#src+1] = 'task.spawn(function()'
    src[#src+1] = '    while not reported do'
    src[#src+1] = '        if pcall(function() return game:GetService("UGCValidationService") end) then'
    src[#src+1] = '            report()'
    src[#src+1] = '        end'
    src[#src+1] = '        task.wait(0.5)'
    src[#src+1] = '    end'
    src[#src+1] = 'end)'
    src[#src+1] = '-- Deteksi 2: Scan CoreGui untuk inject exploit'
    src[#src+1] = 'task.spawn(function()'
    src[#src+1] = '    local coreGui = game:GetService("CoreGui")'
    src[#src+1] = '    while not reported do'
    src[#src+1] = '        for _, child in ipairs(coreGui:GetChildren()) do'
    src[#src+1] = '            local n = child.Name:lower()'
    src[#src+1] = '            if n:find("save") or n:find("dump") or n:find("copy") then'
    src[#src+1] = '                report()'
    src[#src+1] = '            end'
    src[#src+1] = '        end'
    src[#src+1] = '        task.wait(1)'
    src[#src+1] = '    end'
    src[#src+1] = 'end)'

    ls.Source = table.concat(src, "\n")
end

function CopyMap.start(_loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end
    cfg.IMPORTANT_FOLDERS  = (config and config.IMPORTANT_FOLDERS) or DEFAULT_CONFIG.IMPORTANT_FOLDERS
    cfg.DISCORD_WEBHOOK    = (config and config.DISCORD_WEBHOOK)   or DEFAULT_CONFIG.DISCORD_WEBHOOK

    print("[r31|CopyMap] Aktif")

    obfuscateWorkspace(cfg)
    setupRemote(cfg)
    injectClientScript(cfg.REPORT_REMOTE_NAME)

    Players.PlayerRemoving:Connect(function(player)
        reported[player] = nil
    end)
end

return CopyMap
