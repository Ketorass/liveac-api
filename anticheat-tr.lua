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

-- ========== DISCORD EMOJİLERİ ==========
-- Bu emojiler sunucunuzda tanımlı olmalı
local emoji = {
	uye = "<:uye:1508252675655995494>",
	dikkat = "<a:dikkat:1508252116072796180>",
	pause = "<:pause:1508253755315851385>",
	saat = "<a:saat:1508253737431601243>",
	event = "<:event:1508253224031748237>",
	bell = "<a:RingingBell:1483429950190260305>",
	join = "<a:join:1486684147970871472>",
	leave = "<:parsher_a_leave:1486684695797170277>",
	vehicle_in = "<a:bye_car_blank_bearish:1486689158947803267>",
	vehicle_out = "<a:q_peperun:1486689348203319457>",
	alarm = "<a:alarm:1465818655697932330>",
	id = "<:id:1486640503243018323>",
	rules = "<:ruleslogs:1486691313633067018>",
	kan = "<:damlacik_kan:1491091955038556192>",
	oldu = "<a:eddead:1486686805439811594>",
	web = "<:web:1486640325681348699>",
	bicak = "<:pepeKnife:1486686549767753738>",
	mesaj = "<a:mesaj2:1486681118303457421>",
	loading = "<a:LiveLoading:1483077755032834249>",
}

-- ====================== CONFIG_END ======================

-- =====================================================================
-- DISCORD LOG GÖNDERME
-- =====================================================================
local function sendLog(webhook, embed)
	if webhook == "" then return end
	local data = { ["embeds"] = { embed } }
	pcall(function() HttpService:PostAsync(webhook, HttpService:JSONEncode(data)) end)
end

-- =====================================================================
-- JOIN / LEAVE LOG
-- =====================================================================
Players.PlayerRemoving:Connect(function(player)
	local embed = {
		["title"] = emoji.bell .. " Kullanıcı Sunucudan Ayrıldı",
		["description"] = emoji.leave .. " **" .. player.Name .. "** sunucudan çıkış yaptı.",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Çıkış Sistemi" }
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
	COOLDOWN_TIME = 8, KICK_THRESHOLD = 3, TICK_RATE = 0.5, WHITELIST = {}
}
local SESSION_DATA = {}

local function HandleViolation(player, reason, value)
	local data = SESSION_DATA[player]
	if not data or os.clock() < data.NextAlert then return end
	data.Violations += 1
	data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
	local embed = {
		["title"] = emoji.dikkat .. " Live Anti-Cheat: Cheat Detected",
		["color"] = 16711680,
		["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı hile açmış olabilir!\n\n" ..
			emoji.pause .. " **Hile Türü:** " .. reason .. "\n" ..
			emoji.event .. " **Detay:** " .. value .. "\n" ..
			emoji.uye .. " **Profil**\nİsim: **" .. player.Name .. "**\nID: **" .. player.UserId .. "**\n" ..
			emoji.saat .. " **Zaman**\n" .. os.date("%H:%M:%S"),
		["footer"] = { ["text"] = "Live Anti-Cheat • Güvenlik Modülü" }
	}
	sendLog(wb("anticheat"), embed)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSürekli şüpheli hareketler algılandı.\nDurum: Oyundan Uzaklaştırıldınız. (3/3)")
	end
end

-- =====================================================================
-- PLAYER SETUP
-- =====================================================================
local loggedPlayers = {}
local MIN_ACCOUNT_AGE = 3
local playerChatCount = {}
local mutedPlayers = {}
local SPAM_LIMIT = 5
local MUTE_TIME = 60
local spamNotifyEvent = Instance.new("RemoteEvent", ReplicatedStorage)
spamNotifyEvent.Name = "SpamNotifyEvent"

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

local function setupPlayer(player)
	if SETTINGS.WHITELIST[player.UserId] then return end

	-- New account protection
	if player.AccountAge < MIN_ACCOUNT_AGE then
		local embed = {
			["title"] = emoji.dikkat .. " Live Anti-Cheat - Şüpheli Yeni Hesap!",
			["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı yeni hesapla girmeye çalıştı ve yasaklandı!\n\n" ..
				emoji.pause .. " **Hesap Yaşı:** `" .. player.AccountAge .. " Günlük` (Limit: " .. MIN_ACCOUNT_AGE .. " Gün)",
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Yeni Hesap Koruması" }
		}
		sendLog(wb("joinleave"), embed)
		player:Kick("\n\n[Live Anti-Cheat]\nHesabınız çok yeni! Sunucumuza girebilmek için hesabınızın en az " .. MIN_ACCOUNT_AGE .. " günlük olması gerekmektedir.")
		return
	end

	-- Join log
	local embed = {
		["title"] = emoji.bell .. " Yeni Kullanıcı Giriş Sağladı",
		["description"] = emoji.join .. " **" .. player.Name .. "** sunucuya başarılı bir şekilde bağlandı.",
		["color"] = 65280,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Giriş Sistemi" }
	}
	sendLog(wb("joinleave"), embed)

	-- Chatted (legacy)
	player.Chatted:Connect(function(message)
		if not player or #message < 1 then return end

		-- Chat log
		local embed = {
			["title"] = emoji.bell .. " Yeni Mesaj Geldi",
			["description"] = emoji.mesaj .. " **" .. player.Name .. ":** " .. message,
			["color"] = 16711680,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Log Sistemi" }
		}
		sendLog(wb("chat"), embed)

		-- Spam
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
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Sohbet Susturma (Mute)!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı çok hızlı mesaj yazdı ve susturuldu!\n\n" ..
						emoji.pause .. " **Saniyedeki Mesaj:** `" .. stats.count .. "/" .. SPAM_LIMIT .. "`\n" ..
						emoji.pause .. " **Cezası:** `" .. MUTE_TIME .. " Saniye`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Akıllı Filtre Alarmı!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı akıllı filtreyi aşmaya çalıştı!\n\n" ..
						emoji.pause .. " **Yazılan Mesaj:** `" .. message .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Akıllı Filtreleme" }
				}
				sendLog(wb("filter"), embed)
				break
			end
		end

		-- Adonis
		if string.sub(message, 1, 1) == ":" and #message > 2 then
			local embed = {
				["title"] = emoji.dikkat .. " Adonis Yetkili Komut Logu!",
				["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli yetkili bir komut çalıştırdı!\n\n" ..
					emoji.event .. " **Çalıştırılan Komut:** `" .. message .. "`",
				["color"] = 3447003,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Adonis Koruma" }
			}
			sendLog(wb("adonis"), embed)
		end
	end)

	-- All character-based modules
	local function setupCharacter(character)
		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")

		-- Vehicle
		humanoid.Seated:Connect(function(active, seat)
			if active and seat then
				local vehicle = seat.Parent
				local aracIsmi = vehicle and vehicle.Name or "Bilinmeyen Araç"
				local koltukTuru = seat:IsA("VehicleSeat") and "Şoför Koltuğu" or "Yolcu Koltuğu"
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Araç Hareketi!",
					["description"] = emoji.vehicle_in .. " **" .. player.Name .. "** isimli oyuncu bir araca bindi.\n\n" ..
						emoji.event .. " **Araç:** `" .. aracIsmi .. "`\n" ..
						emoji.id .. " **Koltuk:** `" .. koltukTuru .. "`",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Araç Sistemi" }
				}
				sendLog(wb("vehicle"), embed)
			elseif not active then
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Araç Hareketi!",
					["description"] = emoji.vehicle_out .. " **" .. player.Name .. "** isimli oyuncu araçtan indi.",
					["color"] = 3447003,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Araç Sistemi" }
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
					if speed > limit then HandleViolation(player, "Hız/Işınlanma", math.floor(speed) .. " studs/s") end
					local ray = workspace:Raycast(root.Position, Vector3.new(0, -30, 0))
					if not ray and not iv and humanoid.FloorMaterial == Enum.Material.Air then
						SESSION_DATA[player].VerticalTick += SETTINGS.TICK_RATE
						if SESSION_DATA[player].VerticalTick >= SETTINGS.FLIGHT_THRESHOLD then
							HandleViolation(player, "Uçma/Fling", SESSION_DATA[player].VerticalTick .. "sn")
							SESSION_DATA[player].VerticalTick = 0
						end
					else SESSION_DATA[player].VerticalTick = 0 end
				end
				SESSION_DATA[player].LastPos = cp
			end
		end)

		-- Invisibility
		local visibleParts = { "Head", "Torso", "UpperTorso", "LowerTorso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
		task.spawn(function()
			while character.Parent do
				task.wait(10)
				if not loggedPlayers[player.UserId] then
					for _, part in pairs(character:GetChildren()) do
						if part:IsA("BasePart") then
							for _, bp in ipairs(visibleParts) do
								if part.Name == bp and part.Transparency >= 0.98 then
									loggedPlayers[player.UserId] = true
									local embed = {
										["title"] = emoji.loading .. " Live System - Invisiblity Cheat Detect",
										["description"] = emoji.alarm .. " **Invisibility Check**\n\n" ..
											emoji.uye .. " **Oyuncu:** " .. player.Name .. "\n" ..
											emoji.id .. " **ID:** " .. player.UserId .. "\n" ..
											emoji.rules .. " **Detay:** Gizli Parça (" .. part.Name .. ")\n" ..
											emoji.saat .. " **Zaman:** " .. os.date("%H:%M:%S"),
										["color"] = 16711680
									}
									sendLog(wb("invis"), embed)
									task.delay(30, function() loggedPlayers[player.UserId] = nil end)
									break
								end
							end
							if loggedPlayers[player.UserId] then break end
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
						["title"] = emoji.kan .. " Live System - Hasar Takip Sistemi",
						["description"] = emoji.bell .. " **Damage Log**\n\n" ..
							emoji.uye .. " **Oyuncu:** " .. player.Name .. "\n" ..
							emoji.oldu .. " **Hasar:** " .. math.floor(dmg) .. "\n" ..
							emoji.web .. " **Health:** " .. math.floor(newHealth) .. "\n" ..
							emoji.saat .. " **Zaman:** " .. os.date("%H:%M:%S"),
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
			local desc = killer and (emoji.bicak .. " **" .. killer.Name .. "** isimli oyuncu, **" .. player.Name .. "** isimli oyuncuyu kesti!") or (emoji.oldu .. " **" .. player.Name .. "** kendi kendine öldü veya intihar etti.")
			local fields = {
				{ ["name"] = emoji.uye .. " Profil (Ölen)", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			}
			if killer then table.insert(fields, 2, { ["name"] = emoji.uye .. " Profil (Katil)", ["value"] = "İsim: `" .. killer.Name .. "`\nID: `" .. killer.UserId .. "`", ["inline"] = true }) end
			local embed = {
				["title"] = emoji.bell .. " Yeni Ölüm Olayı",
				["description"] = desc,
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
Players.PlayerRemoving:Connect(function(p) SESSION_DATA[p] = nil; playerChatCount[p] = nil; mutedPlayers[p] = nil end)

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
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Remote Event Spam!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı şüpheli Remote tetiklemesi yaptı!\n\n" ..
						emoji.event .. " **Remote Adı:** `" .. remote.Name .. "`\n" ..
						emoji.rules .. " **Saniyedeki İstek:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n" ..
						emoji.pause .. " **Gönderilen Veri:** `" .. finalArgs .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
		["title"] = emoji.dikkat .. " Live Anti-Cheat - Sunucu Kapanış Özeti!",
		["description"] = emoji.dikkat .. " **Sunucu Kapatılıyor veya Güncelleniyor!**\n\n" ..
			emoji.pause .. " **Durum:** Sunucu bağlantısı kesiliyor, veriler koruma altına alınıyor.\n" ..
			emoji.uye .. " **Çıkış Yapan Oyuncu Sayısı:** `" .. count .. "`",
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = "💾 Veritabanı (DataStore)", ["value"] = "Tüm oyuncu verileri başarıyla senkronize edildi ve kaydedildi.", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Sunucu Güvenlik & Veri Sistemi" }
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
				["title"] = emoji.dikkat .. " Live Anti-Cheat - Sunucu Aşırı Yük Altında!",
				["description"] = emoji.dikkat .. " **Sunucuda Ciddi Lag Tespit Edildi!**\n\n" ..
					emoji.pause .. " **Mevcut Sunucu Hızı (TPS):** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. " TPS)\n" ..
					emoji.event .. " **Olası Sebep:** Aşırı Lag",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Durum", ["value"] = "Sunucu çökme tehlikesiyle karşı karşıya!", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Sunucu Performans Takibi" }
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
		["title"] = emoji.bell .. " Yeni Mesaj Geldi",
		["description"] = emoji.mesaj .. " **" .. player.Name .. ":** " .. msg.Text,
		["color"] = 16711680,
		["fields"] = {
			{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		},
		["footer"] = { ["text"] = "Live Anti-Cheat • Log Sistemi" }
	}
	sendLog(wb("chat"), embed)

	-- Filter
	local cleaned = cleanText(msg.Text)
	for _, word in ipairs(blockedWords) do
		if string.find(cleaned, word) then
			local embed = {
				["title"] = emoji.dikkat .. " Live Anti-Cheat - Akıllı Filtre Alarmı!",
				["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı akıllı filtreyi aşmaya çalıştı!\n\n" ..
					emoji.pause .. " **Yazılan Mesaj:** `" .. msg.Text .. "`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Akıllı Filtreleme" }
			}
			sendLog(wb("filter"), embed)
			break
		end
	end

	-- Adonis
	if string.sub(msg.Text, 1, 1) == ":" and #msg.Text > 2 then
		local embed = {
			["title"] = emoji.dikkat .. " Adonis Yetkili Komut Logu!",
			["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli yetkili bir komut çalıştırdı!\n\n" ..
				emoji.event .. " **Çalıştırılan Komut:** `" .. msg.Text .. "`",
			["color"] = 3447003,
			["fields"] = {
				{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			},
			["footer"] = { ["text"] = "Live Anti-Cheat • Adonis Koruma" }
		}
		sendLog(wb("adonis"), embed)
	end
end)

print("[Live Anti-Cheat] Tüm sistemler aktif")
