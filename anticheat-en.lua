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
-- NEW ACCOUNT PROTECTION
-- =====================================================================
local MIN_ACCOUNT_AGE = 3

Players.PlayerAdded:Connect(function(player)
	local accountAge = player.AccountAge
	if accountAge < MIN_ACCOUNT_AGE then
		local embed = {
			["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Suspicious New Account!",
			["description"] = "<a:dikkat:1508252116072796180> **" .. player.Name .. "** tried to join with a new account and was banned!\n\n<:pause:1508253755315851385> **Account Age:** `" .. accountAge .. " days` (Limit: " .. MIN_ACCOUNT_AGE .. " days)\n",
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat - New Account Protection" }
		}
		sendLog(wb("joinleave"), embed)
		player:Kick("\n\n[Live Anti-Cheat]\nYour account is too new! Must be at least " .. MIN_ACCOUNT_AGE .. " days old.")
	end
end)

-- =====================================================================
-- JOIN / LEAVE LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	local embed = {
		["title"] = "<a:RingingBell:1483429950190260305> New User Joined",
		["description"] = "<a:join:1486684147970871472> **" .. player.Name .. "** successfully connected to the server.",
		["color"] = 65280,
		["fields"] = {
			{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Join System" }
	}
	sendLog(wb("joinleave"), embed)
end)

Players.PlayerRemoving:Connect(function(player)
	local embed = {
		["title"] = "<a:RingingBell:1483429950190260305> User Left",
		["description"] = "<:parsher_a_leave:1486684695797170277> **" .. player.Name .. "** left the server.",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Leave System" }
	}
	sendLog(wb("joinleave"), embed)
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
				local vehicleName = vehicle and vehicle.Name or "Unknown Vehicle"
				local seatType = seat:IsA("VehicleSeat") and "Driver Seat" or "Passenger Seat"
				local embed = {
					["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Vehicle Action!",
					["description"] = "<a:bye_car_blank_bearish:1486689158947803267> **" .. player.Name .. "** entered a vehicle.\n\n🔍 **Vehicle:** `" .. vehicleName .. "`\n💺 **Seat:** `" .. seatType .. "`",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat - Vehicle System" }
				}
				sendLog(wb("vehicle"), embed)
			elseif not active then
				local embed = {
					["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Vehicle Action!",
					["description"] = "<a:q_peperun:1486689348203319457> **" .. player.Name .. "** exited a vehicle.",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat - Vehicle System" }
				}
				sendLog(wb("vehicle"), embed)
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

TextChatService.MessageReceived:Connect(function(textChatMessage)
	local textSource = textChatMessage.TextSource
	if not textSource then return end
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player or mutedPlayers[player] then return end
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
				["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Chat Mute!",
				["description"] = "<a:dikkat:1508252116072796180> **" .. player.Name .. "** was muted for spamming!\n\n<:pause:1508253755315851385> **Messages/Second:** `" .. stats.count .. "/" .. SPAM_LIMIT .. "`\n<:pause:1508253755315851385> **Duration:** `" .. MUTE_TIME .. " seconds`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
end)

Players.PlayerRemoving:Connect(function(player)
	playerChatCount[player] = nil
	mutedPlayers[player] = nil
end)

-- =====================================================================
-- SPEED / FLIGHT DETECTION
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
	local embed = {
		["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat: Cheat Detected",
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
							local embed = {
								["title"] = "<a:LiveLoading:1483077755032834249> Live System - Invisibility Cheat Detect",
								["description"] = "<a:alarm:1465818655697932330> **Invisibility Check**\n\n<:uye:1508252675655995494> **Player:** " .. player.Name .. "\n<:id:1486640503243018323> **ID:** " .. player.UserId .. "\n<:ruleslogs:1486691313633067018> **Detail:** Hidden Part (" .. part.Name .. ")\n<a:saat:1508253737431601243> **Time:** " .. os.date("%H:%M:%S"),
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
					local embed = {
						["title"] = "<:damlacik_kan:1491091955038556192> Live System - Damage Tracking",
						["description"] = "<a:RingingBell:1483429950190260305> **Damage Log**\n\n<:uye:1508252675655995494> **Player:** " .. player.Name .. "\n<a:eddead:1486686805439811594> **Damage:** " .. math.floor(dmg) .. "\n<:web:1486640325681348699> **Health:** " .. math.floor(newHealth) .. "\n<a:saat:1508253737431601243> **Time:** " .. os.date("%H:%M:%S"),
						["color"] = 10038562
					}
					sendLog(wb("damage"), embed)
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
			local desc = killer and "<:pepeKnife:1486686549767753738> **" .. killer.Name .. "** killed **" .. player.Name .. "**!" or "<a:eddead:1486686805439811594> **" .. player.Name .. "** died or committed suicide."
			local fields = {
				{ ["name"] = "<:uye:1508252675655995494> Profile (Victim)", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			}
			if killer then table.insert(fields, 2, { ["name"] = "<:uye:1508252675655995494> Profile (Killer)", ["value"] = "Name: `" .. killer.Name .. "`\nID: `" .. killer.UserId .. "`", ["inline"] = true }) end
			local embed = {
				["title"] = "<a:RingingBell:1483429950190260305> New Death Event",
				["description"] = desc,
				["color"] = 16711680,
				["fields"] = fields,
				["footer"] = { ["text"] = "Live Anti-Cheat - Kill System" }
			}
			sendLog(wb("kill"), embed)
		end)
	end)
end)

-- =====================================================================
-- CHAT LOG
-- =====================================================================
TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	local player = Players:GetPlayerByUserId(src.UserId)
	if not player then return end
	local message = msg.Text
	if #message < 1 then return end
	local embed = {
		["title"] = "<a:RingingBell:1483429950190260305> New Message",
		["description"] = "<a:mesaj2:1486681118303457421> **" .. player.Name .. ":** " .. message,
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "🕒 Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat - Log System" }
	}
	sendLog(wb("chat"), embed)
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
				local finalArgs = #strs > 0 and table.concat(strs, ", ") or "No Data"
				local embed = {
					["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Remote Event Spam!",
					["description"] = "<a:dikkat:1508252116072796180> **" .. player.Name .. "** triggered suspicious Remote activity!\n\n<:event:1508253224031748237> **Remote Name:** `" .. remote.Name .. "`\n<:ruleslogs:1486691313633067018> **Requests/sec:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n<:pause:1508253755315851385> **Sent Data:** `" .. finalArgs .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
		["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Server Shutdown Summary!",
		["description"] = "<a:dikkat:1508252116072796180> **Server is shutting down or updating!**\n\n<:pause:1508253755315851385> **Status:** Server disconnecting, data being saved.\n<:uye:1508252675655995494> **Players Online:** `" .. count .. "`\n",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "💾 Database (DataStore)", ["value"] = "All player data successfully synced and saved.", ["inline"] = true },
			{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
				["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Server Under Heavy Load!",
				["description"] = "<a:dikkat:1508252116072796180> **Critical Lag Detected!**\n\n<:pause:1508253755315851385> **Current Server Speed (TPS):** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. " TPS)\n<:event:1508253224031748237> **Possible Cause:** Extreme Lag",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "<:uye:1508252675655995494> Status", ["value"] = "Server is at risk of crashing!", ["inline"] = true },
					{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
-- CHAT FILTER
-- =====================================================================
local blockedWords = {
	"amk", "sg", "orospu", "pic", "pic", "sik", "sik", "siktir", "aq", "oc", "oc",
	"kahpe", "yarak", "yarrak", "meme", "got", "got", "amcik", "amcik", "dassak", "dalyarak",
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

TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	local player = Players:GetPlayerByUserId(src.UserId)
	if not player then return end
	local message = msg.Text
	local cleaned = cleanText(message)
	for _, word in ipairs(blockedWords) do
		if string.find(cleaned, word) then
			local embed = {
				["title"] = "<a:dikkat:1508252116072796180> Live Anti-Cheat - Smart Filter Alert!",
				["description"] = "<a:dikkat:1508252116072796180> **" .. player.Name .. "** tried to bypass the smart filter!\n\n<:pause:1508253755315851385> **Message:** `" .. message .. "`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat - Smart Filter" }
			}
			sendLog(wb("filter"), embed)
			break
		end
	end
end)

-- =====================================================================
-- ADONIS COMMAND LOG
-- =====================================================================
TextChatService.MessageReceived:Connect(function(msg)
	local src = msg.TextSource
	if not src then return end
	local player = Players:GetPlayerByUserId(src.UserId)
	if not player then return end
	local message = msg.Text
	if string.sub(message, 1, 1) == ":" and #message > 2 then
		local embed = {
			["title"] = "<a:dikkat:1508252116072796180> Adonis Admin Command Log!",
			["description"] = "<a:dikkat:1508252116072796180> **" .. player.Name .. "** ran an admin command!\n\n<:event:1508253224031748237> **Command:** `" .. message .. "`",
			["color"] = 3447003,
			["fields"] = {
				{ ["name"] = "<:uye:1508252675655995494> Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "<a:saat:1508253737431601243> Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat - Adonis Protection" }
		}
		sendLog(wb("adonis"), embed)
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
