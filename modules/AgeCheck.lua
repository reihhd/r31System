local AgeCheck = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
    MIN_AGE_DAYS    = 7,        -- minimal umur akun dalam hari (0 = semua akun diizinkan)
    KICK_MESSAGE    = "[r31] Your account is too new. Please wait a few days before playing.",
    ENABLE_KICK     = true,      -- jika false, hanya peringatan tanpa kick
    CHECK_ON_JOIN   = true,      -- cek saat player join
    CHECK_PERIODIC  = false,     -- cek berkala (tidak terlalu diperlukan)
    CHECK_INTERVAL  = 60,        -- detik, jika CHECK_PERIODIC true
}

-- Cache untuk menyimpan umur akun yang sudah dihitung (opsional)
local accountAgeCache = {}

local function getAccountAge(player)
    -- AccountAge dalam hari (nilai float, bisa dibulatkan ke bawah)
    local age = player.AccountAge
    return age
end

local function handleUnderage(player, minAge, cfg)
    local age = getAccountAge(player)
    if age < minAge then
        warn(string.format("[r31|AgeCheck] %s → account age too young: %.1f days (min: %d)", player.Name, age, minAge))
        if cfg.ENABLE_KICK then
            task.defer(function()
                if player and player.Parent then
                    player:Kick(cfg.KICK_MESSAGE)
                end
            end)
        end
        return true  -- terdeteksi underage
    end
    return false
end

function AgeCheck.start(loader, config)
    local cfg = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        cfg[k] = (config and config[k] ~= nil) and config[k] or v
    end

    print("[r31|AgeCheck] Aktif — minAge=" .. cfg.MIN_AGE_DAYS .. " days, kick=" .. tostring(cfg.ENABLE_KICK))

    local function onPlayerAdded(player)
        if cfg.CHECK_ON_JOIN then
            handleUnderage(player, cfg.MIN_AGE_DAYS, cfg)
        end
        -- Optional periodic check (default false)
        if cfg.CHECK_PERIODIC then
            task.spawn(function()
                while player and player.Parent do
                    task.wait(cfg.CHECK_INTERVAL)
                    if not player or not player.Parent then break end
                    handleUnderage(player, cfg.MIN_AGE_DAYS, cfg)
                end
            end)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
end

return AgeCheck
