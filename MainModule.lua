local MainModule = {}

local HttpService = game:GetService("HttpService")

local BASE_URL = "https://raw.githubusercontent.com/reihhd/r31System/main/modules/"

local MODULE_LIST = {
    "Fly",
    "GodMode",
    "Honeypot",
    "NoClip",
    "Size",
    "Speed",
    "Teleport",
    "AutoWalk",      -- <- pastikan nama ini sesuai dengan file .lua di folder modules
    "AgeCheck",
    "IllegalTools",
}

local function fetchModule(moduleName)
    local url = BASE_URL .. moduleName .. ".lua"
    local ok, result = pcall(function()
        return HttpService:GetAsync(url, true)
    end)
    if not ok then
        warn("[r31] Gagal fetch " .. moduleName .. ": " .. tostring(result))
        return nil
    end
    local ok2, moduleFunc = pcall(loadstring, result)
    if not ok2 or not moduleFunc then
        warn("[r31] Gagal compile " .. moduleName)
        return nil
    end
    local ok3, moduleTable = pcall(moduleFunc)
    if not ok3 or not moduleTable then
        warn("[r31] Gagal run " .. moduleName)
        return nil
    end
    return moduleTable
end

function MainModule.initialize(loader, settings)
    print("[r31] Memuat anti-cheat dari GitHub...")
    local Settings = settings or {}
    for _, name in ipairs(MODULE_LIST) do
        task.defer(function()
            if Settings.Modules and Settings.Modules[name] == false then
                print("[r31] ✗ " .. name .. " (disabled)")
                return
            end
            local module = fetchModule(name)
            if not module then
                warn("[r31] ✗ " .. name .. " (gagal load)")
                return
            end
            local cfg = Settings[name] or {}
            local ok, err = pcall(module.start, loader, cfg)
            if not ok then
                warn("[r31] Error " .. name .. ": " .. tostring(err))
            else
                print("[r31] ✓ " .. name .. " (loaded)")
            end
        end)
    end
end

return MainModule
