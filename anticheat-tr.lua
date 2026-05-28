-- =====================================================================
-- LIVE ANTI-CHEAT (Türkçe)
-- =====================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")

-- ========== LİSANS KONTROLÜ ==========
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

-- ========== WEBHOOK AYARLARI ==========
-- Her modül için Discord webhook URL'si girin
-- Boş bırakılanlar MAIN'e düşer
local WB = {
	main = "",             -- ana webhook (diğerleri boşsa bu kullanılır)
	anticheat = "",        -- hız/uçma/ışınlanma tespitleri
	joinleave = "",        -- giriş/çıkış logları
	chat = "",             -- sohbet logları
	kill = "",             -- ölüm logları
	damage = "",           -- hasar logları
	spam = "",             -- spam susturma logları
	remote = "",           -- remote spam logları
	filter = "",           -- küfür filtresi logları
	adonis = "",           -- adonis komut logları
	tps = "",              -- performans uyarıları
	shutdown = "",         -- sunucu kapanış logu
	invis = "",            -- görünmezlik tespiti
}

local function wb(n)
	local v = WB[n]
	return (v ~= nil and v ~= "") and v or WB.main
end

-- ========== DISCORD LOG GÖNDER ==========
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
						sendLog(wb("anticheat"), "Işınlanma", "**Oyuncu:** " .. player.Name .. "\n**Detay:** " .. math.floor(distance) .. " stud", 16711680, {
							{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
						})
					elseif distance > MAX_SPEED then
						sendLog(wb("anticheat"), "Hız/Uçma", "**Oyuncu:** " .. player.Name .. "\n**Detay:** " .. math.floor(distance) .. " stud/s", 16711680, {
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
-- YENİ HESAP KORUMASI
-- =====================================================================
local MIN_ACCOUNT_AGE = 2

Players.PlayerAdded:Connect(function(player)
	if player.AccountAge < MIN_ACCOUNT_AGE then
		sendLog(wb("joinleave"), "Yeni Hesap", "**" .. player.Name .. "** yeni hesapla yasaklandı!\nHesap Yaşı: `" .. player.AccountAge .. " gün` (Limit: " .. MIN_ACCOUNT_AGE .. ")", 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
		player:Kick("\n[Live Anti-Cheat]\nHesabınız çok yeni! En az " .. MIN_ACCOUNT_AGE .. " günlük olmalı.")
	end
end)

-- =====================================================================
-- GİRİŞ/ÇIKIŞ LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	sendLog(wb("joinleave"), "Oyuncu Giriş Yaptı", "**" .. player.Name .. "** sunucuya bağlandı.", 65280, {
		{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
end)

Players.PlayerRemoving:Connect(function(player)
	sendLog(wb("joinleave"), "Oyuncu Ayrıldı", "**" .. player.Name .. "** sunucudan çıktı.", 16711680, {
		{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
end)

-- =====================================================================
-- CHAT SPAM KORUMASI
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
			sendLog(wb("spam"), "Spam Susturma", "**" .. player.Name .. "** spam yaptı!\nMesaj: `" .. s.count .. "/" .. SPAM_LIMIT .. "`\nSüre: " .. MUTE_TIME .. "sn", 16711680, {
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
-- ANA ANTİ-CHEAT (Speed / Flight)
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
	sendLog(wb("anticheat"), "Hile Tespit: " .. reason, "**Oyuncu:** " .. player.Name .. "\n**Detay:** " .. value .. "\n**İhlal:** " .. data.Violations .. "/3", 16711680)
	AlertEvent:FireClient(player)
	if data.Violations >= SETTINGS.KICK_THRESHOLD then
		task.wait(0.5)
		player:Kick("\n[Live Anti-Cheat]\nŞüpheli hareketler algılandı. (3/3)")
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
				if speed > limit then HandleViolation(player, "Hız/Işınlanma", math.floor(speed) .. " studs/s") end
				local ray = workspace:Raycast(root.Position, Vector3.new(0, -30, 0))
				if not ray and not iv and hum.FloorMaterial == Enum.Material.Air then
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
							sendLog(wb("invis"), "Görünmezlik Tespiti", "**Oyuncu:** " .. player.Name .. "\n**ID:** " .. player.UserId .. "\n**Detay:** Gizli parça (" .. part.Name .. ")", 16711680)
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
-- HASAR LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		local lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if newHealth < lastHealth then
				local dmg = lastHealth - newHealth
				if dmg > 2 then
					sendLog(wb("damage"), "Hasar", "**Oyuncu:** " .. player.Name .. "\n**Hasar:** " .. math.floor(dmg) .. "\n**Can:** " .. math.floor(newHealth), 10038562)
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
			local desc = killer and "**" .. killer.Name .. "**, **" .. player.Name .. "**'i öldürdü!" or "**" .. player.Name .. "** öldü."
			local fields = {
				{ ["name"] = "Ölen", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			}
			if killer then table.insert(fields, 2, { ["name"] = "Katil", ["value"] = "ID: `" .. killer.UserId .. "`", ["inline"] = true }) end
			sendLog(wb("kill"), "Ölüm", desc, 16711680, fields)
		end)
	end)
end)

-- =====================================================================
-- CHAT LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if #message < 1 then return end
		sendLog(wb("chat"), "Sohbet", "**" .. player.Name .. ":** " .. message, 16711680, {
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
				sendLog(wb("remote"), "Remote Spam", "**" .. player.Name .. "** remote spam!\n**Remote:** `" .. remote.Name .. "`\n**İstek:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n**Veri:** `" .. (#strs > 0 and table.concat(strs, ", ") or "-") .. "`", 16711680, {
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
-- SUNUCU KAPANIŞ
-- =====================================================================
game:BindToClose(function()
	local count = #Players:GetPlayers()
	task.wait(2.5)
	sendLog(wb("shutdown"), "Sunucu Kapanış", "Sunucu kapatılıyor.\n**Oyuncu:** `" .. count .. "`", 16711680, {
		{ ["name"] = "Veriler", ["value"] = "Kaydedildi.", ["inline"] = true },
		{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
	})
	task.wait(1)
end)

-- =====================================================================
-- TPS PERFORMANS
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
			sendLog(wb("tps"), "Sunucu Yük Altında!", "**TPS:** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. ")", 16711680, {
				{ ["name"] = "Durum", ["value"] = "Sunucu çökme tehlikesi!", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			})
		end
		fpsCount = 0
		lastUpdate = now
	end
end)

-- =====================================================================
-- KÜFÜR FİLTRESİ
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
				sendLog(wb("filter"), "Küfür Filtresi", "**" .. player.Name .. "** filtreyi aştı!\nMesaj: `" .. msg .. "`", 16711680, {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				})
				break
			end
		end
	end)
end)

-- =====================================================================
-- ADONIS KOMUT LOG
-- =====================================================================
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if string.sub(msg, 1, 1) == ":" and #msg > 2 then
			sendLog(wb("adonis"), "Adonis Komut", "**" .. player.Name .. "** komut çalıştırdı: `" .. msg .. "`", 3447003, {
				{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
				{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
			})
		end
	end)
end)

-- =====================================================================
-- PERİYODİK LİSANS KONTROLÜ (5 dk)
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

print("[Live Anti-Cheat] Tüm sistemler aktif")
