return function(config)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TextChatService = game:GetService("TextChatService")
	local RunService = game:GetService("RunService")

	local WEBHOOKS = {}
	for k, v in pairs(config or {}) do WEBHOOKS[k] = v end
	WEBHOOKS.main = WEBHOOKS.main or WEBHOOKS.webhook or ""

	local function sendLog(title, desc, color, fields)
		local data = {
			["embeds"] = {{
				["title"] = title,
				["description"] = desc,
				["color"] = color or 16711680,
				["fields"] = fields or {},
				["footer"] = { ["text"] = "Live Anti-Cheat" }
			}}
		}
		pcall(function() HttpService:PostAsync(WEBHOOKS.main, HttpService:JSONEncode(data)) end)
	end

	-- =====================================================================
	-- TELEPORT / SPEED HACK DETECTION
	-- =====================================================================
	local playerPositions = {}
	local TELEPORT_LIMIT = 300
	local MAX_SPEED = 110

	local function cheatLog(player, reason, detail)
		sendLog("Live Anti-Cheat - " .. reason, "**Player:** " .. player.Name .. "\n**Detail:** " .. detail, 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
	end

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
							cheatLog(player, "Teleport", math.floor(distance) .. " studs")
						elseif distance > MAX_SPEED then
							cheatLog(player, "Speed/Fly", math.floor(distance) .. " studs/s")
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

	local function accountLog(player, age)
		sendLog("Live Anti-Cheat - New Account", "**" .. player.Name .. "** banned - account too new!\nAccount Age: `" .. age .. " days` (Limit: " .. MIN_ACCOUNT_AGE .. ")", 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
	end

	Players.PlayerAdded:Connect(function(player)
		if player.AccountAge < MIN_ACCOUNT_AGE then
			accountLog(player, player.AccountAge)
			player:Kick("\n[Live Anti-Cheat]\nYour account is too new! Must be at least " .. MIN_ACCOUNT_AGE .. " days old.")
		end
	end)

	-- =====================================================================
	-- VEHICLE LOG
	-- =====================================================================
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Seated:Connect(function(active, seat)
				if active and seat then
					local vehicle = seat.Parent
					sendLog("Live Anti-Cheat - Vehicle", "**" .. player.Name .. "** entered a vehicle.\nVehicle: `" .. (vehicle and vehicle.Name or "?") .. "`\nSeat: `" .. (seat:IsA("VehicleSeat") and "Driver" or "Passenger") .. "`", 3447003, {
						{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					})
				elseif not active then
					sendLog("Live Anti-Cheat - Vehicle", "**" .. player.Name .. "** left a vehicle.", 3447003, {
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

	local function spamLog(player, count)
		sendLog("Live Anti-Cheat - Spam", "**" .. player.Name .. "** muted for spam!\nMessages: `" .. count .. "/" .. SPAM_LIMIT .. "`\nDuration: `" .. MUTE_TIME .. "s`", 16711680, {
			{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
			{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
		})
	end

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
			if now - s.lastTime < 2 then s.count += 1
			else s.count = 1; s.lastTime = now end
			if s.count > SPAM_LIMIT then
				mutedPlayers[player] = true
				spamLog(player, s.count)
				spamNotifyEvent:FireClient(player)
				task.delay(MUTE_TIME, function()
					mutedPlayers[player] = nil
					if playerChatCount[player] then playerChatCount[player].count = 0 end
				end)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(p) playerChatCount[p] = nil; mutedPlayers[p] = nil end)

	-- =====================================================================
	-- CORE ANTI-CHEAT (Speed / Flight / Vehicle)
	-- =====================================================================
	local AlertEvent = Instance.new("RemoteEvent", ReplicatedStorage)
	AlertEvent.Name = "LiveAlertEvent"

	local SETTINGS = {
		MAX_WALK_SPEED = 110, MAX_VEHICLE_SPEED = 750, FLIGHT_THRESHOLD = 5,
		COOLDOWN_TIME = 8, KICK_THRESHOLD = 3, TICK_RATE = 0.5, WHITELIST = {}
	}
	local SESSION_DATA = {}
	local AC_WEBHOOK = WEBHOOKS.anticheat or WEBHOOKS.main

	local function acLog(player, reason, value)
		local data = {
			["embeds"] = {{
				["title"] = "Live Anti-Cheat: Cheat Detected",
				["color"] = 16711680,
				["description"] = "**Player:** " .. player.Name .. "\n**Reason:** " .. reason .. "\n**Detail:** " .. value .. "\n**Violation:** " .. SESSION_DATA[player].Violations .. "/3",
				["footer"] = { ["text"] = "Live Anti-Cheat" }
			}}
		}
		pcall(function() HttpService:PostAsync(AC_WEBHOOK, HttpService:JSONEncode(data)) end)
	end

	local function HandleViolation(player, reason, value)
		local data = SESSION_DATA[player]
		if not data or os.clock() < data.NextAlert then return end
		data.Violations += 1
		data.NextAlert = os.clock() + SETTINGS.COOLDOWN_TIME
		acLog(player, reason, value)
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
	-- JOIN / LEAVE LOG
	-- =====================================================================
	local JL_WEBHOOK = WEBHOOKS.joinleave or WEBHOOKS.main

	Players.PlayerAdded:Connect(function(player)
		local data = {
			["embeds"] = {{
				["title"] = "Player Joined",
				["description"] = "**" .. player.Name .. "** joined the server.",
				["color"] = 65280,
				["fields"] = {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Join" }
			}}
		}
		pcall(function() HttpService:PostAsync(JL_WEBHOOK, HttpService:JSONEncode(data)) end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local data = {
			["embeds"] = {{
				["title"] = "Player Left",
				["description"] = "**" .. player.Name .. "** left the server.",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Leave" }
			}}
		}
		pcall(function() HttpService:PostAsync(JL_WEBHOOK, HttpService:JSONEncode(data)) end)
	end)

	-- =====================================================================
	-- INVISIBILITY DETECT
	-- =====================================================================
	local loggedPlayers = {}
	local INVIS_WEBHOOK = WEBHOOKS.invis or WEBHOOKS.main

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				while character.Parent do
					task.wait(10)
					if not loggedPlayers[player.UserId] then
						for _, part in pairs(character:GetChildren()) do
							if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency >= 0.98 then
								loggedPlayers[player.UserId] = true
								local data = {
									["embeds"] = {{
										["title"] = "Live System - Invisibility Cheat",
										["description"] = "**Player:** " .. player.Name .. "\n**ID:** " .. player.UserId .. "\n**Detail:** Hidden part (" .. part.Name .. ")",
										["color"] = 16711680
									}}
								}
								pcall(function() HttpService:PostAsync(INVIS_WEBHOOK, HttpService:JSONEncode(data)) end)
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
	local DAMAGE_WEBHOOK = WEBHOOKS.damage or WEBHOOKS.main

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			local lastHealth = humanoid.Health
			humanoid.HealthChanged:Connect(function(newHealth)
				if newHealth < lastHealth then
					local dmg = lastHealth - newHealth
					if dmg > 2 then
						local data = {
							["embeds"] = {{
								["title"] = "Live System - Damage Log",
								["description"] = "**Player:** " .. player.Name .. "\n**Damage:** " .. math.floor(dmg) .. "\n**Health:** " .. math.floor(newHealth),
								["color"] = 10038562
							}}
						}
						pcall(function() HttpService:PostAsync(DAMAGE_WEBHOOK, HttpService:JSONEncode(data)) end)
					end
				end
				lastHealth = newHealth
			end)
		end)
	end)

	-- =====================================================================
	-- KILL LOG
	-- =====================================================================
	local KILL_WEBHOOK = WEBHOOKS.kill or WEBHOOKS.main

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
				if killer then
					table.insert(fields, 2, { ["name"] = "Killer", ["value"] = "Name: `" .. killer.Name .. "`\nID: `" .. killer.UserId .. "`", ["inline"] = true })
				end
				local data = {
					["embeds"] = {{
						["title"] = "Death Event",
						["description"] = desc,
						["color"] = 16711680,
						["fields"] = fields,
						["footer"] = { ["text"] = "Live Anti-Cheat • Kill" }
					}}
				}
				pcall(function() HttpService:PostAsync(KILL_WEBHOOK, HttpService:JSONEncode(data)) end)
			end)
		end)
	end)

	-- =====================================================================
	-- CHAT LOG
	-- =====================================================================
	local CHAT_WEBHOOK = WEBHOOKS.chat or WEBHOOKS.main

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			if #message < 1 then return end
			local data = {
				["embeds"] = {{
					["title"] = "New Message",
					["description"] = "**" .. player.Name .. ":** " .. message,
					["color"] = 16711680,
					["fields"] = {
						{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
						{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
					},
					["footer"] = { ["text"] = "Live Anti-Cheat • Chat" }
				}}
			}
			pcall(function() HttpService:PostAsync(CHAT_WEBHOOK, HttpService:JSONEncode(data)) end)
		end)
	end)

	-- =====================================================================
	-- REMOTE SPAM
	-- =====================================================================
	local REMOTE_LIMIT = 15
	local playerStats = {}
	local REMOTE_WEBHOOK = WEBHOOKS.remote or WEBHOOKS.main

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
					local data = {
						["embeds"] = {{
							["title"] = "Live Anti-Cheat - Remote Spam",
							["description"] = "**" .. player.Name .. "** remote spam!\n**Remote:** `" .. remote.Name .. "`\n**Requests:** `" .. s.count .. "/" .. REMOTE_LIMIT .. "`\n**Data:** `" .. (#strs > 0 and table.concat(strs, ", ") or "-") .. "`",
							["color"] = 16711680,
							["fields"] = {
								{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
								{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
							},
							["footer"] = { ["text"] = "Live Anti-Cheat • Remote" }
						}}
					}
					pcall(function() HttpService:PostAsync(REMOTE_WEBHOOK, HttpService:JSONEncode(data)) end)
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
	local SHUTDOWN_WEBHOOK = WEBHOOKS.shutdown or WEBHOOKS.main

	game:BindToClose(function()
		local count = #Players:GetPlayers()
		task.wait(2.5)
		local data = {
			["embeds"] = {{
				["title"] = "Live Anti-Cheat - Server Shutdown",
				["description"] = "Server shutting down.\n**Players:** `" .. count .. "`",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "Data", ["value"] = "Saved successfully.", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Shutdown" }
			}}
		}
		pcall(function() HttpService:PostAsync(SHUTDOWN_WEBHOOK, HttpService:JSONEncode(data)) end)
		task.wait(1)
	end)

	-- =====================================================================
	-- TPS / PERFORMANCE MONITOR
	-- =====================================================================
	local TPS_LIMIT = 45
	local lastTPSLog = 0
	local TPS_WEBHOOK = WEBHOOKS.tps or WEBHOOKS.main

	local function stressLog(tps)
		local data = {
			["content"] = "@everyone",
			["embeds"] = {{
				["title"] = "Live Anti-Cheat - Server Under Load!",
				["description"] = "**TPS:** `" .. math.floor(tps) .. "/60` (Limit: " .. TPS_LIMIT .. ")",
				["color"] = 16711680,
				["fields"] = {
					{ ["name"] = "Status", ["value"] = "Server may crash!", ["inline"] = true },
					{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
				},
				["footer"] = { ["text"] = "Live Anti-Cheat • Performance" }
			}}
		}
		pcall(function() HttpService:PostAsync(TPS_WEBHOOK, HttpService:JSONEncode(data)) end)
	end

	local fpsCount = 0
	local lastUpdate = tick()

	RunService.Heartbeat:Connect(function()
		fpsCount += 1
		local now = tick()
		if now - lastUpdate >= 1 then
			local tps = fpsCount / (now - lastUpdate)
			if tps < TPS_LIMIT and (now - lastTPSLog) > 30 then
				lastTPSLog = now
				stressLog(tps)
			end
			fpsCount = 0
			lastUpdate = now
		end
	end)

	-- =====================================================================
	-- SMART CHAT FILTER (Turkish bad words)
	-- =====================================================================
	local FILTER_WEBHOOK = WEBHOOKS.filter or WEBHOOKS.main
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
					local data = {
						["embeds"] = {{
							["title"] = "Live Anti-Cheat - Filter",
							["description"] = "**" .. player.Name .. "** triggered the filter!\nMessage: `" .. msg .. "`",
							["color"] = 16711680,
							["fields"] = {
								{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
								{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
							},
							["footer"] = { ["text"] = "Live Anti-Cheat • Filter" }
						}}
					}
					pcall(function() HttpService:PostAsync(FILTER_WEBHOOK, HttpService:JSONEncode(data)) end)
					break
				end
			end
		end)
	end)

	-- =====================================================================
	-- ADONIS COMMAND LOG
	-- =====================================================================
	local ADONIS_WEBHOOK = WEBHOOKS.adonis or WEBHOOKS.main
	local prefix = ":"

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(msg)
			if string.sub(msg, 1, #prefix) == prefix and #msg > 2 then
				local data = {
					["embeds"] = {{
						["title"] = "Adonis Command Log",
						["description"] = "**" .. player.Name .. "** ran command: `" .. msg .. "`",
						["color"] = 3447003,
						["fields"] = {
							{ ["name"] = "Profile", ["value"] = "Name: `" .. player.Name .. "`\nID: `" .. player.UserId .. "`", ["inline"] = true },
							{ ["name"] = "Time", ["value"] = "<t:" .. os.time() .. ":R>", ["inline"] = true }
						},
						["footer"] = { ["text"] = "Live Anti-Cheat • Adonis" }
					}}
				}
				pcall(function() HttpService:PostAsync(ADONIS_WEBHOOK, HttpService:JSONEncode(data)) end)
			end
		end)
	end)

	-- =====================================================================
	-- PERIODIC LICENSE CHECK (every 5 minutes)
	-- =====================================================================
	local LICENSE_KEY = config.key or ""
	task.spawn(function()
		while true do
			task.wait(300)
			if LICENSE_KEY ~= "" then
				local suc, res = pcall(function()
					return HttpService:GetAsync("https://liveac-api.onrender.com/loader?key=" .. LICENSE_KEY)
				end)
				if suc then
					local r = tostring(res):gsub("[%s\r\n]", "")
					if r ~= "OK" then
						for _, p in ipairs(Players:GetPlayers()) do
							p:Kick("[Live Anti-Cheat] License expired")
						end
						break
					end
				end
			end
		end
	end)

	print("[Live Anti-Cheat] All systems active")
end
