-- =====================================================================
-- LIVE ANTI-CHEAT (English)
-- =====================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

-- ========== LICENSE CHECK ==========
local LICENSE_KEY = "LICENSE-KEY"
local success, response = pcall(function()
	return HttpService:GetAsync("https://liveac-api.onrender.com/loader?key=" .. LICENSE_KEY)
end)

if not success then
	for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Connection error") end
	return
end

local result = tostring(response):gsub("[%s\r\n]", "")
if result ~= "OK" then
	for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Invalid license") end
	return
end

print("[Live Anti-Cheat] License valid - Starting anti-cheat...")

-- ========== WEBHOOK SETTINGS ==========
-- Enter Discord webhook URLs for each module
-- Empty ones will fall back to MAIN
local WB = {
	main = "",             -- main webhook (fallback for empty ones)
	anticheat = "",        -- speed/fly/teleport detections
	joinleave = "",        -- join/leave logs
	chat = "",             -- chat logs
	kill = "",             -- kill/death logs
	damage = "",           -- damage logs
	spam = "",             -- spam mute logs
	remote = "",           -- remote event spam logs
	filter = "",           -- bad word filter logs
	adonis = "",           -- adonis command logs
	tps = "",              -- performance alerts
	shutdown = "",         -- server shutdown log
	invis = "",            -- invisibility detection
	vehicle = "",          -- vehicle enter/exit logs
}

local function wb(n)
	local v = WB[n]
	return (v ~= nil and v ~= "") and v or WB.main
end

-- ========== SEND DISCORD LOG ==========
local function sendLog(webhook, title, desc, color, fields)
	if webhook == "" then return end
	local data = {
		["embeds"] = {{
			["title"] = title,
			["description"] = desc,
			["color"] = color or 16711680,
			["fields"] = fields or {},
			["footer"] = { ["text"] = "Live Anti-Cheat" }
		}}
	}
	pcall(function() HttpService:PostAsync(webhook, HttpService:JSONEncode(data)) end)
end

-- ====================== CONFIG_END ======================

-- =====================================================================
-- TELEPORT / SPEED HACK
-- =====================================================================
local playerPositions = {}
local TELEPORT_LIMIT = 300
local MAX_SPEED = 110

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local hrp = character.HumanoidRootPart
				local currentPos = hrp.Position
				local lastPosData = playerPositions[player]
				if lastPosData then
					local distance = (currentPos - lastPosData.pos).Magnitude
					if distance > TELEPORT_LIMIT then
						sendLog(wb("anticheat"), "Teleport", "**Player:** " .. player.Name .. "\n**Detail:** " .. math.floor(distance) .. " studs", 16711680, {
							{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
						})
					elseif distance > MAX_SPEED then
						sendLog(wb("anticheat"), "Speed/Fly", "**Player:** " .. player.Name .. "\n**Detail:** " .. math.floor(distance) .. " studs/s", 16711680, {
							{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
						})
					end
				end
				playerPositions[player] = { pos = currentPos }
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player) playerPositions[player] = nil end)

-- =====================================================================
-- NEW ACCOUNT PROTECTION
-- =====================================================================
local MIN_ACCOUNT_AGE = 2

Players.PlayerAdded:Connect(function(player)
	if player.AccountAge < MIN_ACCOUNT_AGE then
		sendLog(wb("joinleave"), "New Account", "**" .. player.Name .. "** banned - account too new!\nAccount Age: `" .. player.AccountAge .. " days` (Limit: " .. MIN_ACCOUNT_AGE .. ")", 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
		player:Kick("\n[Live Anti-Cheat]\nYour account is too new! Must be at least " .. MIN_ACCOUNT_AGE .. " days old.")
	end
end)

-- =====================================================================
-- JOIN / LEAVE LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	sendLog(wb("joinleave"), "Player Joined", "**" .. player.Name .. "** joined the server.", 65280, {
		{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
end)

Players.PlayerRemoving:Connect(function(player)
	sendLog(wb("joinleave"), "Player Left", "**" .. player.Name .. "** left the server.", 16711680, {
		{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
end)

-- =====================================================================
-- VEHICLE TRACKING
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Seated:Connect(function(active, seat)
			if active and seat then
				local vehicle = seat.Parent
				local vehicleName = vehicle and vehicle.Name or "Unknown"
				local seatType = seat:IsA("VehicleSeat") and "Driver" or "Passenger"
				sendLog(wb("vehicle"), "Vehicle Enter", "**" .. player.Name .. "** entered a vehicle.\n**Vehicle:** `" .. vehicleName .. "`\n**Seat:** `" .. seatType .. "`", 3447003, {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				})
			elseif not active then
				sendLog(wb("vehicle"), "Vehicle Exit", "**" .. player.Name .. "** exited a vehicle.", 3447003, {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				})
			end
		end)
	end)
end)

-- =====================================================================
-- CHAT SPAM PROTECTION
-- =====================================================================
local spamNotifyEvent = Instance.new("RemoteEvent", ReplicatedStorage)
spamNotifyEvent.Name = "SpamNotifyEvent"
local SPAM_LIMIT = 5
local MUTE_TIME = 60
local playerChatCount = {}
local mutedPlayers = {}

TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	local player = Players:GetPlayerByUserId(src.UserId)
	if not player or mutedPlayers[player] then return end
	local now = tick()
	if not playerChatCount[player] then
		playerChatCount[player] = { count = 1, lastTime = now }
	else
		local s = playerChatCount[player]
		if now - s.lastTime < 2 then s.count += 1 else s.count = 1; s.lastTime = now end
		if s.count > SPAM_LIMIT then
			mutedPlayers[player] = true
			sendLog(wb("spam"), "Spam Mute", "**" .. player.Name .. "** muted for spam!\nMessages: `" .. s.count .. "/" .. SPAM_LIMIT .. "`\nDuration: " .. MUTE_TIME .. "s", 16711680, {
				{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			})
			spamNotifyEvent:FireClient(player)
			task.delay(MUTE_TIME, function() mutedPlayers[player] = nil; if playerChatCount[player] then playerChatCount[player].count = 0 end end)
		end
	end
end)

Players.PlayerRemoving:Connect(function(p) playerChatCount[p] = nil; mutedPlayers[p] = nil end)

-- =====================================================================
-- CORE ANTI-CHEAT (Speed / Flight)
-- =====================================================================
local AlertEvent = Instance.new("RemoteEvent", ReplicatedStorage)
AlertEvent.Name = "LiveAlertEvent"
local SETTINGS = {
	MAX_WALK_SPEED = 110, MAX_VEHICLE_SPEED = 750, FLIGHT_THRESHOLD = 5,
	COOLDOWN_TIME = 8, KICK_THRESHOLD = 3, TICK_RATE = 0.5, WHITELIST = {}
}
local SESSION_DATA = {}

local function HandleViolation(player, reason, value)
	local data = SESSION_DATA[player]
	if not data or os.clock() < data.NextAlert then return end
	data.Violations += 1
	data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
	sendLog(wb("anticheat"), "Cheat Detected: " .. reason, "**Player:** " .. player.Name .. "\n**Detail:** " .. value .. "\n**Violation:** " .. data.Violations .. "/3", 16711680)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSuspicious activity detected. (3/3)")
	end
end

local function TrackPlayer(player)
	if SETTINGS.WHITELIST[player.UserId] then return end
	SESSION_DATA[player] = { Violations = 0, NextAlert = 0, LastPos = nil, VerticalTick = 0 }
	player.CharacterAdded:Connect(function(char)
		local root = char:WaitForChild("HumanoidRootPart")
		local hum = char:WaitForChild("Humanoid")
		while char.Parent and player.Parent do
			task.wait(SETTINGS.TICK_RATE)
			local cp = root.Position
			if SESSION_DATA[player].LastPos then
				local iv = hum.Sit
				local dist = (Vector3.new(cp.X, 0, cp.Z) - Vector3.new(SESSION_DATA[player].LastPos.X, 0, SESSION_DATA[player].LastPos.Z)).Magnitude
				local speed = dist / SETTINGS.TICK_RATE
				local limit = iv and SETTINGS.MAX_VEHICLE_SPEED or SETTINGS.MAX_WALK_SPEED
				if speed > limit then HandleViolation(player, "Speed/Teleport", math.floor(speed) .. " studs/s") end
				local ray = workspace:Raycast(root.Position, Vector3.new(0, -30, 0))
				if not ray and not iv and hum.FloorMaterial == Enum.Material.Air then
					SESSION_DATA[player].VerticalTick += SETTINGS.TICK_RATE
					if SESSION_DATA[player].VerticalTick >= SETTINGS.FLIGHT_THRESHOLD then
						HandleViolation(player, "Flight/Fling", SESSION_DATA[player].VerticalTick .. "s")
						SESSION_DATA[player].VerticalTick = 0
					end
				else SESSION_DATA[player].VerticalTick = 0 end
			end
			SESSION_DATA[player].LastPos = cp
		end
	end)
end

Players.PlayerAdded:Connect(TrackPlayer)
Players.PlayerRemoving:Connect(function(p) SESSION_DATA[p] = nil end)

-- =====================================================================
-- INVISIBILITY DETECT
-- =====================================================================
local loggedPlayers = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			while character.Parent do
				task.wait(10)
				if not loggedPlayers[player.UserId] then
					for _, part in pairs(character:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency >= 0.98 then
							loggedPlayers[player.UserId] = true
							sendLog(wb("invis"), "Invisibility Detected", "**Player:** " .. player.Name .. "\n**ID:** " .. player.UserId .. "\n**Detail:** Hidden part (" .. part.Name .. ")", 16711680)
							task.delay(30, function() loggedPlayers[player.UserId] = nil end)
							break
						end
					end
				end
			end
		end)
	end)
end)

-- =====================================================================
-- DAMAGE LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local dmg = lastHealth - newHealth
				if dmg > 2 then
					sendLog(wb("damage"), "Damage", "**Player:** " .. player.Name .. "\n**Damage:** " .. math.floor(dmg) .. "\n**Health:** " .. math.floor(newHealth), 10038562)
				end
			end
			lastHealth = newHealth
		end)
	end)
end)

-- =====================================================================
-- KILL LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			local tag = humanoid:FindFirstChild("creator")
			local killer = tag and tag.Value or nil
			local desc = killer and "**" .. killer.Name .. "** killed **" .. player.Name .. "**!" or "**" .. player.Name .. "** died."
			local fields = {
				{ ["name"] = "Victim", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			}
			if killer then table.insert(fields, 2, { ["name"] = "Killer", ["value"] = "ID: `" .. killer.UserId .. "`", ["inline"] = true }) end
			sendLog(wb("kill"), "Death", desc, 16711680, fields)
		end)
	end)
end)

-- =====================================================================
-- CHAT LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if #message < 1 then return end
		sendLog(wb("chat"), "Chat", "**" .. player.Name .. ":** " .. message, 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
	end)
end)

-- =====================================================================
-- REMOTE SPAM
-- =====================================================================
local REMOTE_LIMIT = 15
local playerStats = {}

local function attachRemote(remote)
	if remote:IsA("RemoteEvent") then
		remote.OnServerEvent:Connect(function(player, ...)
			local args = {...}
			local now = tick()
			if not playerStats[player] then playerStats[player] = { lastCheck = now, count = 0 } end
			local s = playerStats[player]
			if now - s.lastCheck >= 1 then s.count = 0; s.lastCheck = now end
			s.count += 1
			if s.count > REMOTE_LIMIT then
				local strs = {}
				for _, v in ipairs(args) do table.insert(strs, tostring(v)) end
				sendLog(wb("remote"), "Remote Spam", "**" .. player.Name .. "** remote spam!\n**Remote:** `" .. remote.Name .. "`\n**Requests:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n**Data:** `" .. (#strs > 0 and table.concat(strs, ", ") or "-") .. "`", 16711680, {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				})
			end
		end)
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do attachRemote(obj) end
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do attachRemote(obj) end
workspace.DescendantAdded:Connect(attachRemote)
ReplicatedStorage.DescendantAdded:Connect(attachRemote)
Players.PlayerRemoving:Connect(function(p) playerStats[p] = nil end)

-- =====================================================================
-- SERVER SHUTDOWN
-- =====================================================================
game:BindToClose(function()
	local count = #Players:GetPlayers()
	task.wait(2.5)
	sendLog(wb("shutdown"), "Server Shutdown", "Server shutting down.\n**Players:** `" .. count .. "`", 16711680, {
		{ ["name"] = "Data", ["value"] = "Saved.", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
	task.wait(1)
end)

-- =====================================================================
-- TPS PERFORMANCE
-- =====================================================================
local TPS_LIMIT = 45
local lastTPSLog = 0

RunService.Heartbeat:Connect(function()
	fpsCount = (fpsCount or 0) + 1
	local now = tick()
	if not lastUpdate then lastUpdate = now end
	if now - lastUpdate >= 1 then
		local tps = fpsCount / (now - lastUpdate)
		if tps < TPS_LIMIT and (now - lastTPSLog) > 30 then
			lastTPSLog = now
			sendLog(wb("tps"), "Server Under Load!", "**TPS:** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. ")", 16711680, {
				{ ["name"] = "Status", ["value"] = "Server may crash!", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			})
		end
		fpsCount = 0
		lastUpdate = now
	end
end)

-- =====================================================================
-- CHAT FILTER
-- =====================================================================
local blockedWords = {
	"amk", "sg", "orospu", "pic", "pıc", "sik", "sık", "siktir", "aq", "oc", "oç",
	"kahpe", "yarak", "yarrak", "meme", "göt", "got", "amcik", "amcık", "daşşak", "dalyarak"
}

local function cleanText(text)
	text = string.lower(text)
	text = string.gsub(text, "[@01]", { ["@"] = "a", ["0"] = "o", ["1"] = "i" })
	text = string.gsub(text, "[37]", { ["3"] = "e", ["7"] = "t" })
	text = string.gsub(text, "[%s%p%c]", "")
	local out, last = "", ""
	for i = 1, #text do
		local c = string.sub(text, i, i)
		if c ~= last then out = out .. c; last = c end
	end
	return out
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		local cleaned = cleanText(msg)
		for _, word in ipairs(blockedWords) do
			if string.find(cleaned, word) then
				sendLog(wb("filter"), "Chat Filter", "**" .. player.Name .. "** triggered the filter!\nMessage: `" .. msg .. "`", 16711680, {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				})
				break
			end
		end
	end)
end)

-- =====================================================================
-- ADONIS COMMAND LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if string.sub(msg, 1, 1) == ":" and #msg > 2 then
			sendLog(wb("adonis"), "Adonis Command", "**" .. player.Name .. "** ran command: `" .. msg .. "`", 3447003, {
				{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			})
		end
	end)
end)

-- =====================================================================
-- PERIODIC LICENSE CHECK (5 min)
-- =====================================================================
task.spawn(function()
	while true do
		task.wait(300)
		local suc, res = pcall(function()
			return HttpService:GetAsync("https://liveac-api.onrender.com/loader?key=" .. LICENSE_KEY)
		end)
		if suc then
			local r = tostring(res):gsub("[%s\r\n]", "")
			if r ~= "OK" then
				for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] License expired") end
				break
			end
		end
	end
end)

print("[Live Anti-Cheat] All systems active")
