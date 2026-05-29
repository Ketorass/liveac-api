-- =====================================================================
-- LIVE ANTI-CHEAT (Türkçe)
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
	for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Bağlantı hatası") end
	return
end

local result = tostring(response):gsub("[%s\r\n]", "")
if result ~= "OK" then
	for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Geçersiz lisans") end
	return
end

print("[Live Anti-Cheat] Lisans geçerli - Anti-Cheat başlatılıyor...")

-- ========== WEBHOOK CONFIG ==========
-- Her modül için ayrı webhook URL'si girin
-- Boş bırakılanlar main'e düşer
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
		["title"] = "🔴 Live Anti-Cheat ・ Çıkış Log",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
			{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Çıkış Sistemi" }
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
		["title"] = "💬 Live Anti-Cheat ・ Mesaj Log",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
			{ ["name"] = "📝 Mesaj", ["value"] = message, ["inline"] = false },
			{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Log Sistemi" }
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
				["title"] = "🚨 Live Anti-Cheat ・ Spam Log",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
					{ ["name"] = "⚡ Hız", ["value"] = "**" .. stats.count .. "** mesaj/2sn (Limit: " .. SPAM_LIMIT .. ")", ["inline"] = true },
					{ ["name"] = "⏸️ İşlem", ["value"] = "Susturuldu (**" .. MUTE_TIME .. "**sn)", ["inline"] = true },
					{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Sohbet Koruma" }
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
				["title"] = "🚨 Live Anti-Cheat ・ Filtre Log",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
					{ ["name"] = "📌 Mesaj", ["value"] = message, ["inline"] = false },
					{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Filtre Sistemi" }
			}
			sendLog(wb("filter"), embed)
			break
		end
	end

	-- Adonis command
	if string.sub(message, 1, 1) == ":" and #message > 2 then
		local embed = {
			["title"] = "⚡ Live Anti-Cheat ・ Yetkili Log",
			["color"] = 3447003,
			["fields"] = {
				{ ["name"] = "👤 Yetkili", ["value"] = "**" .. player.Name .. "** (`" .. player.UserId .. "`)", ["inline"] = false },
				{ ["name"] = "⌨️ Komut", ["value"] = "```" .. message .. "```", ["inline"] = false },
				{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Adonis Koruma" }
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
		["title"] = "🚨 Live Anti-Cheat ・ Tespit Log",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Oyuncu", ["value"] = player.Name .. " (`" .. player.UserId .. "`)", ["inline"] = false },
			{ ["name"] = "🔍 Sebep", ["value"] = reason, ["inline"] = true },
			{ ["name"] = "📊 Detay", ["value"] = value, ["inline"] = true },
			{ ["name"] = "⚠️ İhlal", ["value"] = data.Violations .. "/3", ["inline"] = true },
		},
		["footer"] = { ["text"] = "Live Anti-Cheat | " .. os.date("%H:%M:%S") }
	}
	sendLog(wb("anticheat"), embed)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSurekli supheli hareketler algilandi.\nDurum: Oyundan Uzaklastirildiniz. (3/3)")
	end
end

-- =====================================================================
-- PLAYER SETUP (Speed, Invis, Damage, Kill, Vehicle, Chat, Join)
-- =====================================================================
local loggedPlayers = {}
local MIN_ACCOUNT_AGE = 3

local function setupPlayer(player)
	if SETTINGS.WHITELIST[player.UserId] then return end

	-- New account protection
	if player.AccountAge < MIN_ACCOUNT_AGE then
		local embed = {
			["title"] = "🚨 Live Anti-Cheat ・ Hesap Log",
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
				{ ["name"] = "📊 Hesap Yaşı", ["value"] = "**" .. player.AccountAge .. "** gün (Limit: " .. MIN_ACCOUNT_AGE .. ")", ["inline"] = true },
				{ ["name"] = "⏸️ İşlem", ["value"] = "Yasaklandı", ["inline"] = true },
				{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Hesap Koruması" }
		}
		sendLog(wb("joinleave"), embed)
		player:Kick("\n\n[Live Anti-Cheat]\nHesabiniz cok yeni! Sunucumuza girebilmek icin hesabinizin en az " .. MIN_ACCOUNT_AGE .. " gunluk olmasi gerekmektedir.")
		return
	end

	-- Join log
	local embed = {
		["title"] = "🟢 Live Anti-Cheat ・ Giriş Log",
		["color"] = 65280,
		["fields"] = {
			{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
			{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Giriş Sistemi" }
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
			local vehicle = seat and seat.Parent
			local aracIsmi = vehicle and vehicle.Name or "Bilinmeyen Araç"
			if active and seat then
				local embed = {
					["title"] = "🚗 Live Anti-Cheat ・ Araç Log",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "👤 Oyuncu", ["value"] = "**" .. player.Name .. "** (`" .. player.UserId .. "`)", ["inline"] = false },
						{ ["name"] = "🚗 Araç", ["value"] = "**" .. aracIsmi .. "**", ["inline"] = true },
						{ ["name"] = "💺 Koltuk", ["value"] = seat:IsA("VehicleSeat") and "🚦 Sürücü" or "💺 Yolcu", ["inline"] = true },
						{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Araç Sistemi" }
				}
				sendLog(wb("vehicle"), embed)
			elseif not active then
				local embed = {
					["title"] = "🚶 Live Anti-Cheat ・ Araç Log",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = "👤 Oyuncu", ["value"] = "**" .. player.Name .. "** (`" .. player.UserId .. "`)", ["inline"] = false },
						{ ["name"] = "🚗 Araç", ["value"] = "**" .. aracIsmi .. "**", ["inline"] = true },
						{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Araç Sistemi" }
				}
				sendLog(wb("vehicle"), embed)
			end
		end)

		-- Speed/Fly (TrackPlayer loop)
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
					if speed > limit then HandleViolation(player, "Hiz/Isinlanma", math.floor(speed) .. " studs/s") end
					local ray = workspace:Raycast(root.Position, Vector3.new(0, -30, 0))
					if not ray and not iv and humanoid.FloorMaterial == Enum.Material.Air then
						SESSION_DATA[player].VerticalTick += SETTINGS.TICK_RATE
						if SESSION_DATA[player].VerticalTick >= SETTINGS.FLIGHT_THRESHOLD then
							HandleViolation(player, "Ucma/Fling", SESSION_DATA[player].VerticalTick .. "sn")
							SESSION_DATA[player].VerticalTick = 0
						end
					else SESSION_DATA[player].VerticalTick = 0 end
				end
				SESSION_DATA[player].LastPos = cp
			end
		end)

		-- Invisibility
		local function checkInvis()
			if loggedPlayers[player.UserId] then return end
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Transparency >= 0.98 then
					loggedPlayers[player.UserId] = true
					local embed = {
						["title"] = "👁️ Live Anti-Cheat ・ Görünmezlik Log",
						["color"] = 16711680,
						["fields"] = {
							{ ["name"] = "👤 Oyuncu", ["value"] = player.Name .. " (`" .. player.UserId .. "`)", ["inline"] = false },
							{ ["name"] = "📋 Parça", ["value"] = part.Name, ["inline"] = true },
							{ ["name"] = "🔍 Şeffaflık", ["value"] = math.floor(part.Transparency * 100) .. "%", ["inline"] = true },
						},
						["footer"] = { ["text"] = "Live Anti-Cheat | " .. os.date("%H:%M:%S") }
					}
					sendLog(wb("invis"), embed)
					task.delay(30, function() loggedPlayers[player.UserId] = nil end)
					break
				end
			end
		end
		checkInvis()
		character.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") then
				desc:GetPropertyChangedSignal("Transparency"):Connect(function()
					if desc.Transparency >= 0.98 then checkInvis() end
				end)
			end
		end)
		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part:GetPropertyChangedSignal("Transparency"):Connect(function()
					if part.Transparency >= 0.98 then checkInvis() end
				end)
			end
		end

		-- Damage
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local dmg = lastHealth - newHealth
				if dmg > 2 then
				local embed = {
					["title"] = "🩸 Live Anti-Cheat ・ Hasar Log",
					["color"] = 10038562,
					["fields"] = {
						{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
						{ ["name"] = "💀 Hasar", ["value"] = "**" .. math.floor(dmg) .. "**", ["inline"] = true },
						{ ["name"] = "❤️ Kalan Can", ["value"] = "**" .. math.floor(newHealth) .. "**", ["inline"] = true },
						{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Hasar Sistemi" }
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
			local fields = {
				{ ["name"] = "👤 Ölen", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = true }
			}
			if killer then
				table.insert(fields, { ["name"] = "🔪 Katil", ["value"] = "İsim: **" .. killer.Name .. "**\nID: **" .. killer.UserId .. "**", ["inline"] = true })
			end
			table.insert(fields, { ["name"] = "📝 Detay", ["value"] = killer and "**" .. killer.Name .. "** → **" .. player.Name .. "**" or "Kendi kendine öldü / intihar", ["inline"] = false })
			table.insert(fields, { ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true })
			local embed = {
				["title"] = "💀 Live Anti-Cheat ・ Ölüm Log",
				["color"] = 16711680,
				["fields"] = fields,
				["footer"] = { ["text"] = "Live Anti-Cheat • Kill Sistemi" }
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
				local finalArgs = #strs > 0 and table.concat(strs, ", ") or "Veri Yok"
			local embed = {
				["title"] = "🚨 Live Anti-Cheat ・ Remote Log",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "👤 Profil", ["value"] = "İsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**", ["inline"] = false },
					{ ["name"] = "⚡ Remote", ["value"] = "**" .. remote.Name .. "**", ["inline"] = true },
					{ ["name"] = "📊 İstek", ["value"] = "**" .. s.count .. "**/" .. REMOTE_LIMIT .. " istek/sn", ["inline"] = true },
					{ ["name"] = "📌 Veri", ["value"] = finalArgs, ["inline"] = false },
					{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Remote Koruma" }
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
		["title"] = "🔌 Live Anti-Cheat ・ Kapanış Log",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "👤 Oyuncu Sayısı", ["value"] = "**" .. count .. "** oyuncu çevrimiçiydi", ["inline"] = false },
			{ ["name"] = "📌 Durum", ["value"] = "Sunucu kapatılıyor veya güncelleniyor", ["inline"] = false },
			{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Kapanış Sistemi" }
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
				["title"] = "🚨 Live Anti-Cheat ・ Performans Log",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "⚡ Anlık TPS", ["value"] = "**" .. math.floor(tps) .. "** / 60", ["inline"] = true },
					{ ["name"] = "📊 Kritik Limit", ["value"] = "**" .. TPS_LIMIT .. "** TPS", ["inline"] = true },
					{ ["name"] = "📌 Durum", ["value"] = "Sunucu aşırı yük altında, çökme riski var!", ["inline"] = false },
					{ ["name"] = "🕒 Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Performans Takibi" }
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
				for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Lisans süresi doldu") end
				break
			end
		end
	end
end)

print("[Live Anti-Cheat] Tum sistemler aktif")
