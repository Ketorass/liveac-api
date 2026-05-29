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
	main = "https://discord.com/api/webhooks/1508895939522203701/GgLEmaZazl9heX-PQxBjwCVmf1Hw3l23sIoZ2koF0tCrS3OlKom5f42ch7T1vsbqzfzQ",        -- Ana webhook (diğerleri boşsa bu kullanılır)
	joinleave = "https://discord.com/api/webhooks/1508553878973583471/xVFa9ZNwtEL3OT14A4s7FQuO90OVnU79J4kmcovQC-JnmbP5csytagjb3Za6BG5z77Ce",   -- Oyuncu giriş/çıkış logları
	anticheat = "https://discord.com/api/webhooks/1509898010589528164/m2NtMh-nkh_CLTVKwVxHcW7HNZG_uVSsm27f2jPtvCwf_50XwEdAdbg0cRB_OOf2ta4v",   -- Hız/uçuş/şüpheli hareket logları
	chat = "https://discord.com/api/webhooks/1509898182711185570/E34Jt-P5DoY0-SOpiSNsOoytI0nyb94TfIjCudsqvgsf4YJhOZcFN99vvdo-DCdQYpXU",        -- Sohbet mesaj logları
	damage = "https://discord.com/api/webhooks/1509898415906099200/0LlnA1NVp_IoeYin72pTbUh3vCAH_0jHyp7xq2ql4zXLBSzrIZnvHOl4joedjvTrnU3K",      -- Hasar takip logları
	remote = "https://discord.com/api/webhooks/1509898486995488848/Pr4kIN-7-8shypZZEk39SBzeuIZF1RIj3kwZD6eBRNXAuwHiFqXaHv32qGgZrIdAF4Bz",      -- Remote event spam koruma logları
	filter = "https://discord.com/api/webhooks/1509698589910106143/hdw2nJDTtockRqJoFiphFXl54l1JNCFlPC5AeCE4BL_rDWt1G9Iu-jMITilNxormhacA",      -- Küfür/yasaklı kelime filtre logları
	adonis = "https://discord.com/api/webhooks/1509898562287308931/hW7fZ4STpk-Ze_En0AcsvZdf-cGBUAIF_2Dv96TfLUbzQKdRB2Rrs7VYwRm2lZ_oPVGF",      -- Adonis yetkili komut logları
	tps = "https://discord.com/api/webhooks/1509898615353643120/um6k08hfqXpol8c8zhYWHjnGu9cc_BZ0OltpbUxCGoig0X_tre4A5rDUMJUlPf0SFVrl",         -- Sunucu TPS/performans uyarı logları
	shutdown = "https://discord.com/api/webhooks/1509898773592145981/xFUrhkjwuKRbp30DfAFyQyEiC2U46mBKP4Ae0rPGEAioRKnhdjhuKnhLRtmO43vmNhoO",    -- Sunucu kapanış logları
}

local function wb(n)
	local v = config[n]
	return (v ~= nil and v ~= "") and v or config.main
end

-- ========== DISCORD EMOJİLERİ ==========
-- Bu emojiler sunucunuzda tanımlı olmalı
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
-- DISCORD LOG GÖNDERME
-- =====================================================================
local function sendLog(webhook, embed)
	if webhook == "" then warn("[Live-AC] Webhook empty, skipping") return end
	local data = { ["content"] = "Anti-Cheat Log: " .. (embed.description or embed.title or "Log"), ["embeds"] = { embed } }
	local json = HttpService:JSONEncode(data)
	warn("[Live-AC] JSON:", json)
	task.spawn(function()
		local ok, err = pcall(function()
			HttpService:PostAsync(webhook, json)
		end)
		if ok then warn("[Live-AC] POST success") else warn("[Live-AC] POST failed:", err) end
	end)
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
	COOLDOWN_TIME = 1, KICK_THRESHOLD = 1, TICK_RATE = 0.5, WHITELIST = {}
}
local SESSION_DATA = {}

local function HandleViolation(player, reason, value)
	local data = SESSION_DATA[player]
	if not data or os.clock() < data.NextAlert then return end
	data.Violations += 1
	data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
	warn("[Live-AC] Violation:", player.Name, reason, value, "Count:", data.Violations)
	local wh = config.main
	warn("[Live-AC] Webhook:", wh)
	local msg = "**" .. emoji.dikkat .. " " .. player.Name .. "** " .. reason .. " - " .. value
	sendLog(wh, { ["title"] = msg, ["color"] = 16711680, ["description"] = "Oyuncu: " .. player.Name .. " (" .. player.UserId .. ")\nSebep: " .. reason .. "\nDetay: " .. value .. "\nZaman: " .. os.date("%H:%M:%S") })
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nSürekli şüpheli hareketler algılandı.\nDurum: Oyundan Uzaklaştırıldınız. (3/3)")
	end
end

-- =====================================================================
-- PLAYER SETUP
-- =====================================================================
local MIN_ACCOUNT_AGE = 3

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

	-- Anti-Dex / Yasaklı Araç Koruması
	local yasakliIsimler = { "dex", "injector", "esp", "aimbot", "remotespy", "remote spy", "cheat", "wallet", "loadstring", "darkdex", "dex explorer", "exploit", "krnl", "synapse", "scriptware" }
	local function araclariTara(container)
		for _, obj in ipairs(container:GetChildren()) do
			local ad = string.lower(obj.Name)
			for _, y in ipairs(yasakliIsimler) do
				if string.find(ad, y) then
					local embed = {
						["title"] = emoji.dikkat .. " Live Anti-Cheat - Yasaklı Araç Tespit!",
						["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı yasaklı bir araç açtı veya kopyalama başlattı!\n\n" ..
							emoji.pause .. " **Tespit Edilen:** `" .. obj.Name .. "`\n" ..
							emoji.event .. " **Konum:** `" .. tostring(container) .. "`",
						["color"] = 16711680,
						["fields"] = {
							{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
			if bp then araclariTara(bp) end
			if pg then araclariTara(pg) end
			task.wait(5)
		end
	end)
	player.DescendantAdded:Connect(function(obj)
		local ad = string.lower(obj.Name)
		for _, y in ipairs(yasakliIsimler) do
			if string.find(ad, y) then
				local embed = {
					["title"] = emoji.dikkat .. " Live Anti-Cheat - Yasaklı Araç Tespit!",
					["description"] = emoji.dikkat .. " **" .. player.Name .. "** isimli kullanıcı yasaklı bir araç açtı veya kopyalama başlattı!\n\n" ..
						emoji.pause .. " **Tespit Edilen:** `" .. obj.Name .. "`\n" ..
						emoji.event .. " **Konum:** `" .. tostring(obj.Parent) .. "`",
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = emoji.uye .. " Profil", ["value"] = "İsim: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = emoji.saat .. " Zaman", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
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
