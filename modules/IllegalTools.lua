local IllegalTools = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DEFAULT_CONFIG = {
    CHECK_INTERVAL      = 2.0,        -- detik (periodic scan)
    USE_PERIODIC_SCAN   = true,       -- scan berkala
    USE_EVENT_DETECTION = true,       -- deteksi via ChildAdded
    VIOLATIONS_KICK     = 3,          -- berapa kali melanggar sebelum kick
    KICK_MESSAGE        = "[r31] Illegal tool detected.",
    WHITELIST = {                     -- daftar tool yang diizinkan (nama tool)
        "Tool",                       -- contoh, ganti sesuai game Anda
        "Sword",
        "Gun",
        "HealthPotion",
        "KeyCard",
    },
    -- Jika true, hapus tool; jika false, hanya peringatan (tidak hapus)
    REMOVE_ILLEGAL      = true,
}

local playerData = setmetatable({}, { __mode = "k" })  -- [player] = { violations = 0 }

-- Fungsi untuk memeriksa apakah sebuah tool ilegal
local function isToolIllegal(tool, whitelist)
    if not tool or not tool:IsA("Tool") then
        return false   -- bukan tool, abaikan
    end
    local toolName = tool.Name
    -- Cek whitelist (case-sensitive)
    for _, allowedName in ipairs(whitelist) do
        if toolName == allowedName then
            return false
        end
    end
    return true
end

-- Fungsi untuk menghapus atau memperingatkan tool ilegal
local function handleIllegalTool(player, tool, cfg)
    if not player or not player.Parent then return end
    local data = playerData[player]
    if not data then return end

    if cfg.REMOVE_ILLEGAL then
        tool:Destroy()
        warn(string.format("[r31|IllegalTools] %s → illegal tool removed: '%s'", player.Name, tool.Name))
    else
        warn(string.format("[r31|IllegalTools] %s → illegal tool detected (not removed): '%s'", player.Name, tool.Name))
    end

    -- Tingkatkan violation
    data.violations = data.violations + 1
    if data.violations >= cfg.VIOLATIONS_KICK then
        task.defer(function()
            if player and player.Parent then
                player:Kick(cfg.KICK_MESSAGE)
            end
        end)
    end
end

-- Memindai semua tool di dalam container (misal: Backpack, Character)
local function scanContainer(player, container, cfg)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            if isToolIllegal(child, cfg.WHITELIST) then
                handleIllegalTool(player, child, cfg)
            end
        end
    end
end

-- Memindai seluruh inventory pemain (Backpack + Character)
local function scanPlayer(player, cfg)
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")

    if backpack then
        scanContainer(player, backpack, cfg)
    end
    if character then
        scanContainer(player, character, cfg)
    end
end

-- Setup event listener untuk ChildAdded pada container
local function setupContainerListener(player, container, cfg)
    if not container then return end
    local conn
    conn = container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            -- Tunggu sebentar untuk memastikan tool sudah selesai di-parent
            task.wait(0.1)
            if isToolIllegal(child, cfg.WHITELIST) then
                handleIllegalTool(player, child, cfg)
            end
        end
    end)
    return conn
end

function IllegalTools.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    local function onPlayerAdded(player)
        local data = { violations = 0, connections = {} }
        playerData[player] = data

        -- Fungsi untuk menghubungkan semua listener saat karakter muncul
        local function setupForCharacter(char)
            -- Scan karakter saat muncul
            scanContainer(player, char, cfg)
            -- Pasang listener pada karakter (untuk tool yang ditambahkan setelah spawn)
            local charConn = setupContainerListener(player, char, cfg)
            if charConn then table.insert(data.connections, charConn) end
        end

        -- Backpack biasanya sudah ada, pasang listener
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            scanContainer(player, backpack, cfg)
            local bpConn = setupContainerListener(player, backpack, cfg)
            if bpConn then table.insert(data.connections, bpConn) end
        else
            -- Jika Backpack belum ada, tunggu
            player.ChildAdded:Connect(function(child)
                if child.Name == "Backpack" and child:IsA("Backpack") then
                    scanContainer(player, child, cfg)
                    local bpConn = setupContainerListener(player, child, cfg)
                    if bpConn then table.insert(data.connections, bpConn) end
                end
            end)
        end

        -- Saat karakter muncul
        local charAddedConn = player.CharacterAdded:Connect(function(char)
            task.wait(0.5) -- tunggu tool dari starter gear masuk
            setupForCharacter(char)
        end)
        table.insert(data.connections, charAddedConn)

        -- Jika karakter sudah ada saat ini
        if player.Character then
            setupForCharacter(player.Character)
        end
    end

    local function onPlayerRemoving(player)
        local data = playerData[player]
        if data then
            for _, conn in ipairs(data.connections or {}) do
                conn:Disconnect()
            end
        end
        playerData[player] = nil
    end

    -- Periodic scan (optional)
    if cfg.USE_PERIODIC_SCAN then
        task.spawn(function()
            while true do
                for player, data in pairs(playerData) do
                    if player and player.Parent then
                        scanPlayer(player, cfg)
                    end
                end
                task.wait(cfg.CHECK_INTERVAL)
            end
        end)
    end

    -- Hubungkan event
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return IllegalTools
