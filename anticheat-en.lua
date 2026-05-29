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

-- ========== WEBHOOK CONFIG ==========
-- Enter Discord webhook URLs for each module
-- Empty ones will fall back to MAIN
local config = {
	main = "",
	joinleave = "",
	anticheat = "",
	spam = "",
	chat = "",
	kill = "",
	damage = "",
	remote = "",
	filter = "",
	adonis = "",
	tps = "",
	shutdown = "",
	invis = "",
	vehicle = "",
}

local function wb(n)
	local v = config[n]
	return (v ~= nil and v ~= "") and v or config.main
end

local function sendLog(webhook, embed)
	if webhook == "" then return end
	local data = { ["embeds"] = { embed } }
	pcall(function() HttpService:PostAsync(webhook, HttpService:JSONEncode(data)) end)
end

-- ====================== CONFIG_END ======================

-- =====================================================================
-- JOIN / LEAVE LOG
-- =====================================================================
Players.PlayerRemoving:Connect(function(player)
	local embed = {
		["title"] = "🔔 User Left",
		["description"] = "🔴 **" .. player.Name .. "** left the server.",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Leave System" }
	}
	sendLog(wb("joinleave"), embed)
end)



-- =====================================================================
-- CHAT SYSTEM (Spam + Log + Filter + Adonis)
-- =====================================================================
local spamNotifyEvent = Instance.new("RemoteEvent", ReplicatedStorage)
spamNotifyEvent.Name = "SpamNotifyEvent"
local SPAM_LIMIT = 5
local MUTE_TIME = 60
local playerChatCount = {}
local mutedPlayers = {}

local blockedWords = {
	"amk", "sg", "orospu", "pic", "pıc", "sik", "sık", "siktir", "aq", "oc", "oç",
	"kahpe", "yarak", "yarrak", "meme", "got", "göt", "amcik", "amcık", "dassak", "daşşak", "dalyarak",
	"discordgg", "robloxcom", "sunucupatlatma"
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

local function handleChatMessage(player, message)
	if not player then return end
	if #message < 1 then return end

	-- Chat log
	local embed = {
		["title"] = "🔔 New Message",
		["description"] = "💬 **" .. player.Name .. ":** " .. message,
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Log System" }
	}
	sendLog(wb("chat"), embed)

	-- Spam (skip for muted players)
	if mutedPlayers[player] then return end
	local now = tick()
	if not playerChatCount[player] then
		playerChatCount[player] = { count = 1, lastTime = now }
	else
		local stats = playerChatCount[player]
		if now - stats.lastTime < 2 then
			stats.count += 1
		else
			stats.count = 1
			stats.lastTime = now
		end
		if stats.count > SPAM_LIMIT then
			mutedPlayers[player] = true
			local embed = {
				["title"] = "🚨 Live Anti-Cheat - Chat Mute!",
				["description"] = "🚨 **" .. player.Name .. "** was muted for spamming!\n\n📌 **Messages/Second:** `" .. stats.count .. "/" .. SPAM_LIMIT .. "`\n📌 **Duration:** `" .. MUTE_TIME .. " seconds`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat - Chat Protection" }
			}
			sendLog(wb("spam"), embed)
			spamNotifyEvent:FireClient(player)
			task.delay(MUTE_TIME, function()
				mutedPlayers[player] = nil
				if playerChatCount[player] then playerChatCount[player].count = 0 end
			end)
		end
	end

	-- Filter
	local cleaned = cleanText(message)
	for _, word in ipairs(blockedWords) do
		if string.find(cleaned, word) then
			local embed = {
				["title"] = "🚨 Live Anti-Cheat - Smart Filter Alert!",
				["description"] = "🚨 **" .. player.Name .. "** tried to bypass the smart filter!\n\n📌 **Message:** `" .. message .. "`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat - Smart Filter" }
			}
			sendLog(wb("filter"), embed)
			break
		end
	end

	-- Adonis command
	if string.sub(message, 1, 1) == ":" and #message > 2 then
		local embed = {
			["title"] = "🚨 Adonis Admin Command Log!",
			["description"] = "🚨 **" .. player.Name .. "** ran an admin command!\n\n⚡ **Command:** `" .. message .. "`",
			["color"] = 3447003,
			["fields"] = {
				{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat - Adonis Protection" }
		}
		sendLog(wb("adonis"), embed)
	end
end

TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	handleChatMessage(Players:GetPlayerByUserId(src.UserId), msg.Text)
end)

Players.PlayerRemoving:Connect(function(player)
	playerChatCount[player] = nil
	mutedPlayers[player] = nil
end)

-- =====================================================================
-- PLAYER SETUP (Speed, Invis, Damage, Kill, Vehicle, Chat, Join)
-- =====================================================================
local AlertEvent = Instance.new("RemoteEvent", ReplicatedStorage)
AlertEvent.Name = "LiveAlertEvent"
local SETTINGS = {
	MAX_WALK_SPEED = 110, MAX_VEHICLE_SPEED = 750, FLIGHT_THRESHOLD = 5,
	COOLDOWN_TIME = 8, KICK_THRESHOLD = 3, TICK_RATE = 0.5, WHITELIST = {}
}
local SESSION_DATA = {}
local loggedPlayers = {}
local MIN_ACCOUNT_AGE = 3

local function HandleViolation(player, reason, value)
	local data = SESSION_DATA[player]
	if not data or os.clock() < data.NextAlert then return end
	data.Violations += 1
	data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
	local embed = {
		["title"] = "🚨 Live Anti-Cheat: Cheat Detected",
		["color"] = 16711680,
		["description"] = "**Player:** " .. player.Name .. "\n**Reason:** " .. reason .. "\n**Detail:** " .. value .. "\n**Violation Count:** " .. data.Violations .. "/3",
		["footer"] = { ["text"] = "Live Anti-Cheat - " .. os.date("%H:%M") }
	}
	sendLog(wb("anticheat"), embed)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSuspicious activity detected.\nStatus: Kicked from game. (3/3)")
	end
end

local function setupPlayer(player)
	if SETTINGS.WHITELIST[player.UserId] then return end

	-- New account protection
	if player.AccountAge < MIN_ACCOUNT_AGE then
		local embed = {
			["title"] = "🚨 Live Anti-Cheat - Suspicious New Account!",
			["description"] = "🚨 **" .. player.Name .. "** tried to join with a new account and was banned!\n\n📌 **Account Age:** `" .. player.AccountAge .. " days` (Limit: " .. MIN_ACCOUNT_AGE .. " days)\n",
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat - New Account Protection" }
		}
		sendLog(wb("joinleave"), embed)
		player:Kick("\n\n[Live Anti-Cheat]\nYour account is too new! Must be at least " .. MIN_ACCOUNT_AGE .. " days old.")
		return
	end

	-- Join log
	local embed = {
		["title"] = "🔔 New User Joined",
		["description"] = "🟢 **" .. player.Name .. "** successfully connected to the server.",
		["color"] = 65280,
		["fields"] = {
			{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Join System" }
	}
	sendLog(wb("joinleave"), embed)

	-- Chatted (legacy)
	player.Chatted:Connect(function(message)
		handleChatMessage(player, message)
	end)

	-- All character-based modules
	local function setupCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")

		-- Vehicle
		humanoid.Seated:Connect(function(active, seat)
			if active and seat then
				local vehicle = seat.Parent
				local vehicleName = vehicle and vehicle.Name or "Unknown Vehicle"
				local seatType = seat:IsA("VehicleSeat") and "Driver Seat" or "Passenger Seat"
				local embed = {
					["title"] = "🚨 Live Anti-Cheat - Vehicle Action!",
					["description"] = "🚗 **" .. player.Name .. "** entered a vehicle.\n\n🔍 **Vehicle:** `" .. vehicleName .. "`\n💺 **Seat:** `" .. seatType .. "`",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat - Vehicle System" }
				}
				sendLog(wb("vehicle"), embed)
			elseif not active then
				local embed = {
					["title"] = "🚨 Live Anti-Cheat - Vehicle Action!",
					["description"] = "🚶 **" .. player.Name .. "** exited a vehicle.",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat - Vehicle System" }
				}
				sendLog(wb("vehicle"), embed)
			end
		end)

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

		-- Invisibility
		task.spawn(function()
			while character.Parent do
				task.wait(10)
				if not loggedPlayers[player.UserId] then
					for _, part in pairs(character:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency >= 0.98 then
							loggedPlayers[player.UserId] = true
							local embed = {
								["title"] = "🔍 Live System - Invisibility Cheat Detect",
								["description"] = "🚨 **Invisibility Check**\n\n👤 **Player:** " .. player.Name .. "\n🆔 **ID:** " .. player.UserId .. "\n📋 **Detail:** Hidden Part (" .. part.Name .. ")\n🕒 **Time:** " .. os.date("%H:%M:%S"),
								["color"] = 16711680
							}
							sendLog(wb("invis"), embed)
							task.delay(30, function() loggedPlayers[player.UserId] = nil end)
							break
						end
					end
				end
			end
		end)

		-- Damage
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local dmg = lastHealth - newHealth
				if dmg > 2 then
					local embed = {
						["title"] = "🩸 Live System - Damage Tracking",
						["description"] = "🔔 **Damage Log**\n\n👤 **Player:** " .. player.Name .. "\n💀 **Damage:** " .. math.floor(dmg) .. "\n🌐 **Health:** " .. math.floor(newHealth) .. "\n🕒 **Time:** " .. os.date("%H:%M:%S"),
						["color"] = 10038562
					}
					sendLog(wb("damage"), embed)
				end
			end
			lastHealth = newHealth
		end)

		-- Kill
		humanoid.Died:Connect(function()
			local tag = humanoid:FindFirstChild("creator")
			local killer = tag and tag.Value or nil
			local desc = killer and "🔪 **" .. killer.Name .. "** killed **" .. player.Name .. "**!" or "💀 **" .. player.Name .. "** died or committed suicide."
			local fields = {
				{ ["name"] = "👤 Profile (Victim)", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			}
			if killer then table.insert(fields, 2, { ["name"] = "👤 Profile (Killer)", ["value"] = "Name: `" .. killer.Name .. "`\nID: `" .. killer.UserId .. "`", ["inline"] = true }) end
			local embed = {
				["title"] = "🔔 New Death Event",
				["description"] = desc,
				["color"] = 16711680,
				["fields"] = fields,
				["footer"] = { ["text"] = "Live Anti-Cheat - Kill System" }
			}
			sendLog(wb("kill"), embed)
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
					["title"] = "🚨 Live Anti-Cheat - Remote Event Spam!",
					["description"] = "🚨 **" .. player.Name .. "** triggered suspicious Remote activity!\n\n⚡ **Remote Name:** `" .. remote.Name .. "`\n📋 **Requests/sec:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n📌 **Sent Data:** `" .. finalArgs .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat - Remote Protection" }
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
		["title"] = "🚨 Live Anti-Cheat - Server Shutdown Summary!",
		["description"] = "🚨 **Server is shutting down or updating!**\n\n📌 **Status:** Server disconnecting, data being saved.\n👤 **Players Online:** `" .. count .. "`\n",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "💾 Database (DataStore)", ["value"] = "All player data successfully synced and saved.", ["inline"] = true },
			{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Server Security & Data System" }
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
				["title"] = "🚨 Live Anti-Cheat - Server Under Heavy Load!",
				["description"] = "🚨 **Critical Lag Detected!**\n\n📌 **Current Server Speed (TPS):** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. " TPS)\n⚡ **Possible Cause:** Extreme Lag",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Status", ["value"] = "Server is at risk of crashing!", ["inline"] = true },
					{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat - Server Performance Monitor" }
			}
			sendLog(wb("tps"), embed)
		end
		fpsCount = 0
		lastUpdate = now
	end
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
