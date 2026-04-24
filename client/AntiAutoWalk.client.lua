-- ReplicatedFirst -> AntiAutoWalk (LocalScript)
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

if RunService:IsStudio() then return end

local SETTINGS = {
    MOVEMENT_KEYS = {
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right
    },
    GRACE_PERIOD = 0.6,
    CHECK_INTERVAL = 0.3,
    VIOLATION_LIMIT = 3,
}

local lastMovementTime = tick()
local activeMovementKeys = {}
for _, key in pairs(SETTINGS.MOVEMENT_KEYS) do
    activeMovementKeys[key] = false
end

local function onInputBegan(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if SETTINGS.MOVEMENT_KEYS[input.KeyCode] then
        activeMovementKeys[input.KeyCode] = true
        lastMovementTime = tick()
    end
end

local function onInputEnded(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if SETTINGS.MOVEMENT_KEYS[input.KeyCode] then
        activeMovementKeys[input.KeyCode] = false
        lastMovementTime = tick()
    end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

local violationCount = 0
local function detectionLoop()
    while true do
        task.wait(SETTINGS.CHECK_INTERVAL)
        local char = LocalPlayer.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            violationCount = 0
            continue
        end
        local isMoving = (humanoid.MoveDirection.Magnitude > 0.1)
        if isMoving then
            local timeSinceLastInput = tick() - lastMovementTime
            if timeSinceLastInput > SETTINGS.GRACE_PERIOD then
                violationCount = violationCount + 1
                if violationCount >= SETTINGS.VIOLATION_LIMIT then
                    local remote = game:GetService("ReplicatedStorage"):FindFirstChild("AntiCheatReport")
                    if remote and remote:IsA("RemoteEvent") then
                        remote:FireServer("AutoWalkSuspicion")
                    else
                        LocalPlayer:Kick("[r31] AutoWalk detected.")
                    end
                    break
                end
            end
        else
            violationCount = 0
        end
    end
end

task.spawn(detectionLoop)
