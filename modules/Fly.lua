local Fly = {}

local Players = game:GetService("Players")

local DEFAULT_CONFIG = {
	CHECK_INTERVAL     = 1.5,
	MAX_VELOCITY_Y     = 75,
	MAX_AIR_HEIGHT     = 12,
	VIOLATIONS_KICK    = 4,
	RAYCAST_DIST       = 120,
	STAGGER_PER_PLAYER = 0.15,
}

local playerData = setmetatable({}, { __mode = "k" })
local rayParams  = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getHeightAboveGround(hrp, character, rayDist)
	rayParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(
		hrp.Position,
		Vector3.new(0, -rayDist, 0),
		rayParams
	)
	if result then
		return (hrp.Position - result.Position).Magnitude
	end
	return rayDist
end

local function checkPlayer(player, cfg)
	local data = playerData[player]
	if not data then return end

	local character = player.Character
	if not character then return end

	local hrp      = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	if humanoid.Health <= 0 then return end

	local velY = hrp.AssemblyLinearVelocity.Y

	if velY <= cfg.MAX_VELOCITY_Y then
		if data.violations > 0 then data.violations -= 1 end
		return
	end

	local height   = getHeightAboveGround(hrp, character, cfg.RAYCAST_DIST)
	local isFlying = (height > cfg.MAX_AIR_HEIGHT) and (velY > cfg.MAX_VELOCITY_Y)

	if isFlying then
		data.violations += 1
		warn(string.format(
			"[r31|Fly] %s → VelY=%.1f | H=%.1f | Flag=%d/%d",
			player.Name, velY, height, data.violations, cfg.VIOLATIONS_KICK
		))
		if data.violations >= cfg.VIOLATIONS_KICK then
			task.defer(function()
				if player and player.Parent then
					player:Kick("[r31] Fly hack detected.")
				end
			end)
		end
	else
		if data.violations > 0 then data.violations -= 1 end
	end
end

local playerCount = 0

local function onPlayerAdded(player, cfg)
	playerCount += 1
	local offset = (playerCount - 1) * cfg.STAGGER_PER_PLAYER

	playerData[player] = { violations = 0, connections = {} }

	local conn = player.CharacterAdded:Connect(function()
		if playerData[player] then
			playerData[player].violations = 0
		end
	end)
	table.insert(playerData[player].connections, conn)

	task.delay(offset, function()
		while playerData[player] do
			checkPlayer(player, cfg)
			task.wait(cfg.CHECK_INTERVAL)
		end
	end)
end

local function onPlayerRemoving(player)
	local data = playerData[player]
	if data then
		for _, conn in ipairs(data.connections) do
			conn:Disconnect()
		end
	end
	playerData[player] = nil
end

function Fly.start(_loader, config)
	local cfg = {}
	for k, v in pairs(DEFAULT_CONFIG) do
		cfg[k] = (config and config[k] ~= nil) and config[k] or v
	end

	print("[r31|Fly] Aktif — interval=" .. cfg.CHECK_INTERVAL .. "s")

	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p, cfg)
	end
	Players.PlayerAdded:Connect(function(p) onPlayerAdded(p, cfg) end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Fly
