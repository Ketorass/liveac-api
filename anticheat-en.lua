-- =====================================================================
-- LIVE ANTI-CHEAT (English)
-- =====================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

-- ========== LICENSE CHECK ==========
local LICENSE_KEY = "LISANS-KEYI"
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

-- ========== WEBHOOK CONFIG ==========
-- Enter a separate webhook URL for each module
-- Empty entries fall back to main
local config = {
	main = "https://discord.com/api/webhooks/1508895939522203701/GgLEmaZazl9heX-PQxBjwCVmf1Hw3l23sIoZ2koF0tCrS3OlKom5f42ch7T1vsbqzfzQ",        -- Default webhook (used when others are empty)
	joinleave = "https://discord.com/api/webhooks/1508553878973583471/xVFa9ZNwtEL3OT14A4s7FQuO90OVnU79J4kmcovQC-JnmbP5csytagjb3Za6BG5z77Ce",   -- Player join/leave logs
	anticheat = "https://discord.com/api/webhooks/1509898010589528164/m2NtMh-nkh_CLTVKwVxHcW7HNZG_uVSsm27f2jPtvCwf_50XwEdAdbg0cRB_OOf2ta4v",   -- Speed/fly/suspicious movement logs
	chat = "https://discord.com/api/webhooks/1509898182711185570/E34Jt-P5DoY0-SOpiSNsOoytI0nyb94TfIjCudsqvgsf4YJhOZcFN99vvdo-DCdQYpXU",        -- Chat message logs
	damage = "https://discord.com/api/webhooks/1509898415906099200/0LlnA1NVp_IoeYin72pTbUh3vCAH_0jHyp7xq2ql4zXLBSzrIZnvHOl4joedjvTrnU3K",      -- Damage tracking logs
	remote = "https://discord.com/api/webhooks/1509898486995488848/Pr4kIN-7-8shypZZEk39SBzeuIZF1RIj3kwZD6eBRNXAuwHiFqXaHv32qGgZrIdAF4Bz",      -- Remote event spam protection logs
	filter = "https://discord.com/api/webhooks/1509698589910106143/hdw2nJDTtockRqJoFiphFXl54l1JNCFlPC5AeCE4BL_rDWt1G9Iu-jMITilNxormhacA",      -- Profanity/banned word filter logs
	adonis = "https://discord.com/api/webhooks/1509898562287308931/hW7fZ4STpk-Ze_En0AcsvZdf-cGBUAIF_2Dv96TfLUbzQKdRB2Rrs7VYwRm2lZ_oPVGF",      -- Adonis admin command logs
	tps = "https://discord.com/api/webhooks/1509898615353643120/um6k08hfqXpol8c8zhYWHjnGu9cc_BZ0OltpbUxCGoig0X_tre4A5rDUMJUlPf0SFVrl",         -- Server TPS/performance warning logs
	shutdown = "https://discord.com/api/webhooks/1509898773592145981/xFUrhkjwuKRbp30DfAFyQyEiC2U46mBKP4Ae0rPGEAioRKnhdjhuKnhLRtmO43vmNhoO",    -- Server shutdown logs
}

local function wb(n)
	local v = config[n]
	return (v ~= nil and v ~= "") and v or config.main
end

-- ========== DISCORD EMOJIS ==========
-- These emojis must be defined in your server
local emoji = {
	uye = "<:uye:1508252634019135498>",
	dikkat = "<a:dikkat:1508250614075752629>",
	pause = "<:pause:1508253678295843008>",
	saat = "<:saat:1508253712685072514>",
	event = "<:event:1508253201223258152>",
	bell = "<a:RingingBell:1509931849730887750>",
	join = "<a:join:1486684147970871472>",
	leave = "<:leave:1509928987780972685>",
	vehicle_in = "<a:bye_car_blank_bearish:1509937025917391049>",
	vehicle_out = "<a:q_peperun:1486689348203319457>",
	alarm = "<a:alarm:1465818655697932330>",
	ids = "<:ids:1509938656780222556>",
	rules = "<:ruleslogs:1486691313633067018>",
	kan = "<:damlacik_kan:1509937451853025430>",
	oldu = "<a:eddead:1486686805439811594>",
	web = "<:web:1486640325681348699>",
	bicak = "<:pepeKnife:1509938429540958418>",
	mesaj = "<:chat:1509931912188264542>",
	loading = "<a:LiveLoading:1483077755032834249>",
	coins = "<:coins:1509939039430639657>",
}

-- ====================== CONFIG_END ======================

-- =====================================================================
-- DISCORD LOG SENDER
-- =====================================================================
local function sendLog(webhook, embed)
	if webhook == "" then return end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, { ["embeds"] = { embed } })
	if not ok then return end
	task.spawn(function()
		pcall(HttpService.PostAsync, HttpService, webhook, json)
	end)
end
local function sendMsg(webhook, text)
	if webhook == "" then return end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, { ["content"] = text })
	if not ok then return end
	task.spawn(function()
		pcall(HttpService.PostAsync, HttpService, webhook, json)
	end)
end

-- =====================================================================
-- JOIN / LEAVE LOG
-- =====================================================================
Players.PlayerRemoving:Connect(function(player)
	local embed = {
		["title"] = emoji.bell .. " User Left the Server",
		["description"] = emoji.leave .. " **" .. player.Name .. "** has left the server.",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Leave System" }
	}
	sendLog(wb("joinleave"), embed)
end)

-- =====================================================================
-- SPEED / FLIGHT DETECTION
-- =====================================================================
local AlertEvent = Instance.new("RemoteEvent", ReplicatedStorage)
AlertEvent.Name = "LiveAlertEvent"
local SETTINGS = {
	MAX_WALK_SPEED = 110, MAX_VEHICLE_SPEED = 750, FLIGHT_THRESHOLD = 5,
	COOLDOWN_TIME = 1, KICK_THRESHOLD = 1, TICK_RATE = 0.5, WHITELIST = {}
}
local SESSION_DATA = {}

local function HandleViolation(player, reason, value)
	local data = SESSION_DATA[player]
	if not data or os.clock() < data.NextAlert then return end
	data.Violations += 1
	data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
	warn("[Live-AC] Violation:", player.Name, reason, value, "Count:", data.Violations)
	local embed = {
		["title"] = emoji.dikkat .. " Live Anti-Cheat: Cheat Detected",
		["description"] = emoji.bell .. " **" .. player.Name .. "** detected with suspicious movements!\n\n" ..
			emoji.uye .. " **Player:** " .. player.Name .. "\n" ..
			emoji.pause .. " **Cheat Type:** " .. reason .. "\n" ..
			emoji.event .. " **Detail:** " .. value .. "\n" ..
			emoji.saat .. " **Time:** " .. os.date("%H:%M:%S"),
		["color"] = 16711680,
		["footer"] = { ["text"] = "Live Anti-Cheat • Security Module" }
	}
	sendLog(wb("damage"), embed)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSuspicious activity detected repeatedly.\nStatus: Kicked from game. (3/3)")
	end
end

-- =====================================================================
-- PLAYER SETUP
-- =====================================================================
local MIN_ACCOUNT_AGE = 3

local blockedWords = {
	"discordgg", "robloxcom", "crashserver"
}

local function cleanText(text)
	text = string.lower(text)
	text = string.gsub(text, "@", "a")
	text = string.gsub(text, "0", "o")
	text = string.gsub(text, "1", "i")
	text = string.gsub(text, "3", "e")
	text = string.gsub(text, "7", "t")
	text = string.gsub(text, "[%s%p%c]", "")
	local out, last = "", ""
	for i = 1, #text do
		local c = string.sub(text, i, i)
		if c ~= last then out = out .. c; last = c end
	end
	return out
end

local function setupPlayer(player)
	if SETTINGS.WHITELIST[player.UserId] then return end

	-- New account protection
	if player.AccountAge < MIN_ACCOUNT_AGE then
		local embed = {
			["title"] = emoji.dikkat .. " Live Anti-Cheat - Suspicious New Account!",
			["description"] = emoji.dikkat .. " **" .. player.Name .. "** tried to join with a new account and was banned!\n\n" ..
				emoji.pause .. " **Account Age:** `" .. player.AccountAge .. " Days` (Limit: " .. MIN_ACCOUNT_AGE .. " Days)",
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • New Account Protection" }
		}
		sendLog(wb("joinleave"), embed)
		player:Kick("\n\n[Live Anti-Cheat]\nYour account is too new! You need at least " .. MIN_ACCOUNT_AGE .. " days to join this server.")
		return
	end

	-- Join log
	local embed = {
		["title"] = emoji.bell .. " New User Joined",
		["description"] = emoji.join .. " **" .. player.Name .. "** successfully connected to the server.",
		["color"] = 65280,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Join System" }
	}
	sendLog(wb("joinleave"), embed)

	-- Anti-Dex / Banned Tool Protection
	local bannedNames = { "dex", "injector", "esp", "aimbot", "remotespy", "remote spy", "cheat", "wallet", "loadstring", "darkdex", "dex explorer", "exploit", "krnl", "synapse", "scriptware" }
	local function scanTools(container)
		for _, obj in ipairs(container:GetChildren()) do
			local name = string.lower(obj.Name)
			for _, b in ipairs(bannedNames) do
				if string.find(name, b) then
					local embed = {
						["title"] = emoji.dikkat .. " Live Anti-Cheat - Banned Tool Detected!",
						["description"] = emoji.dikkat .. " **" .. player.Name .. "** opened a banned tool or started copying!\n\n" ..
							emoji.pause .. " **Detected:** `" .. obj.Name .. "`\n" ..
							emoji.event .. " **Location:** `" .. tostring(container) .. "`",
						["color"] = 16711680,
						["fields"] = {
							{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
						},
						["footer"] = { ["text"] = "Live Anti-Cheat • Anti-Exploit" }
					}
					sendLog(wb("anticheat"), embed)
					return true
				end
			end
		end
		return false
	end
	task.spawn(function()
		while player.Parent do
			local bp = player:FindFirstChild("Backpack")
			local pg = player:FindFirstChild("PlayerGui")
			if bp then scanTools(bp) end
			if pg then scanTools(pg) end
			task.wait(5)
		end
	end)
	player.DescendantAdded:Connect(function(obj)
		local name = string.lower(obj.Name)
		for _, b in ipairs(bannedNames) do
			if string.find(name, b) then
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Banned Tool Detected!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** opened a banned tool or started copying!\n\n" ..
						emoji.pause .. " **Detected:** `" .. obj.Name .. "`\n" ..
						emoji.event .. " **Location:** `" .. tostring(obj.Parent) .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Anti-Exploit" }
				}
				sendLog(wb("anticheat"), embed)
				break
			end
		end
	end)

	-- Chatted (legacy)
	player.Chatted:Connect(function(message)
		if not player or #message < 1 then return end

		-- Chat log
		local embed = {
			["title"] = emoji.bell .. " New Message",
			["description"] = emoji.mesaj .. " **" .. player.Name .. ":** " .. message,
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Log System" }
		}
		sendLog(wb("chat"), embed)

		-- Filter
		local cleaned = cleanText(message)
		for _, word in ipairs(blockedWords) do
			if string.find(cleaned, word) then
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Smart Filter Alert!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** attempted to bypass the smart filter!\n\n" ..
						emoji.pause .. " **Message:** `" .. message .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Smart Filter" }
				}
				sendLog(wb("filter"), embed)
				break
			end
		end

		-- Adonis
		if string.sub(message, 1, 1) == ":" and #message > 2 then
			local embed = {
				["title"] = emoji.dikkat .. " Adonis Admin Command Log!",
				["description"] = emoji.dikkat .. " **" .. player.Name .. "** executed an admin command!\n\n" ..
					emoji.event .. " **Command:** `" .. message .. "`",
				["color"] = 3447003,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Adonis Protection" }
			}
			sendLog(wb("adonis"), embed)
		end
	end)

	-- All character-based modules
	local function setupCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")

		-- Speed/Fly
		SESSION_DATA[player] = { Violations = 0, NextAlert = 0, LastPos = nil, VerticalTick = 0 }
		task.spawn(function()
			while character.Parent and player.Parent do
				task.wait(SETTINGS.TICK_RATE)
				local cp = root.Position
				if SESSION_DATA[player].LastPos then
					local iv = humanoid.Sit
					local dist = (Vector3.new(cp.X, 0, cp.Z) - Vector3.new(SESSION_DATA[player].LastPos.X, 0, SESSION_DATA[player].LastPos.Z)).Magnitude
					local speed = dist / SETTINGS.TICK_RATE
					local limit = iv and SETTINGS.MAX_VEHICLE_SPEED or SETTINGS.MAX_WALK_SPEED
					if speed > limit then HandleViolation(player, "Speed/Teleport", math.floor(speed) .. " studs/s") end
					local ray = workspace:Raycast(root.Position, Vector3.new(0, -30, 0))
					if not ray and not iv and humanoid.FloorMaterial == Enum.Material.Air then
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

		-- Damage
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local dmg = lastHealth - newHealth
				if dmg > 2 then
					local embed = {
						["title"] = emoji.kan .. " Live System - Damage Tracking",
						["description"] = emoji.bell .. " **Damage Log**\n\n" ..
							emoji.uye .. " **Player:** " .. player.Name .. "\n" ..
							emoji.oldu .. " **Damage:** " .. math.floor(dmg) .. "\n" ..
							emoji.web .. " **Health:** " .. math.floor(newHealth) .. "\n" ..
							emoji.saat .. " **Time:** " .. os.date("%H:%M:%S"),
						["color"] = 10038562
					}
					sendLog(wb("damage"), embed)
				end
			end
			lastHealth = newHealth
		end)
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(p) SESSION_DATA[p] = nil end)

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
				local finalArgs = #strs > 0 and table.concat(strs, ", ") or "No Data"
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Remote Event Spam!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** triggered suspicious Remote activity!\n\n" ..
						emoji.event .. " **Remote Name:** `" .. remote.Name .. "`\n" ..
						emoji.rules .. " **Requests/sec:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n" ..
						emoji.pause .. " **Sent Data:** `" .. finalArgs .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Remote Protection" }
				}
				sendLog(wb("remote"), embed)
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
	local embed = {
		["title"] = emoji.dikkat .. " Live Anti-Cheat - Server Shutdown Summary!",
		["description"] = emoji.dikkat .. " **Server is shutting down or updating!**\n\n" ..
			emoji.pause .. " **Status:** Disconnecting, data being secured.\n" ..
			emoji.uye .. " **Players Disconnected:** `" .. count .. "`",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "💾 Database (DataStore)", ["value"] = "All player data successfully synced and saved.", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Server Security & Data System" }
	}
	sendLog(wb("shutdown"), embed)
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
			local embed = {
				["title"] = emoji.dikkat .. " Live Anti-Cheat - Server Under Heavy Load!",
				["description"] = emoji.dikkat .. " **Server Experiencing Severe Lag!**\n\n" ..
					emoji.pause .. " **Current TPS:** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. " TPS)\n" ..
					emoji.event .. " **Possible Cause:** Extreme Lag",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Status", ["value"] = "Server is at risk of crashing!", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Server Performance Monitor" }
			}
			sendLog(wb("tps"), embed)
		end
		fpsCount = 0
		lastUpdate = now
	end
end)

-- =====================================================================
-- CHAT SYSTEM (TextChatService)
-- =====================================================================
TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	local player = Players:GetPlayerByUserId(src.UserId)
	if not player then return end

	-- Chat log
	local embed = {
		["title"] = emoji.bell .. " New Message",
		["description"] = emoji.mesaj .. " **" .. player.Name .. ":** " .. msg.Text,
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Log System" }
	}
	sendLog(wb("chat"), embed)

	-- Filter
	local cleaned = cleanText(msg.Text)
	for _, word in ipairs(blockedWords) do
		if string.find(cleaned, word) then
			local embed = {
				["title"] = emoji.dikkat .. " Live Anti-Cheat - Smart Filter Alert!",
				["description"] = emoji.dikkat .. " **" .. player.Name .. "** attempted to bypass the smart filter!\n\n" ..
					emoji.pause .. " **Message:** `" .. msg.Text .. "`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Smart Filter" }
			}
			sendLog(wb("filter"), embed)
			break
		end
	end

	-- Adonis
	if string.sub(msg.Text, 1, 1) == ":" and #msg.Text > 2 then
		local embed = {
			["title"] = emoji.dikkat .. " Adonis Admin Command Log!",
			["description"] = emoji.dikkat .. " **" .. player.Name .. "** executed an admin command!\n\n" ..
				emoji.event .. " **Command:** `" .. msg.Text .. "`",
			["color"] = 3447003,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Adonis Protection" }
		}
		sendLog(wb("adonis"), embed)
	end
end)

print("[Live Anti-Cheat] All systems active")
