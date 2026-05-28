-- ========== LIVE ANTI-CHEAT LOADER (Türkçe) ==========
-- DEĞİŞTİREBİLECEKLERİN:
local LICENSE_KEY = "%KEY%"
local WB = {
    main = "",
    anticheat = "",
    joinleave = "",
    chat = "",
    kill = "",
    damage = "",
    spam = "",
    remote = "",
    filter = "",
    adonis = "",
    tps = "",
    shutdown = "",
    invis = "",
}
-- ================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local success, response = pcall(function()
    return HttpService:GetAsync("https://liveac-api.onrender.com/anticheat?key=" .. LICENSE_KEY .. "&lang=tr&obfuscate=true")
end)

if not success or response == "INVALID" or response == "EXPIRED" then
    for _, p in ipairs(Players:GetPlayers()) do p:Kick("[Live Anti-Cheat] Lisans gecersiz") end
    return
end

local wbCode = "local WB = {"
for k, v in pairs(WB) do
    wbCode = wbCode .. string.format("%s=%q,", k, v)
end
wbCode = wbCode .. "}"
local code = response:gsub("local WB%s*=%s*{[^}]-}", wbCode)

local s = Instance.new("Script")
s.Name = "LiveAntiCheat"
s.Source = code
s.Parent = game:GetService("ServerScriptService")

print("[Live Anti-Cheat] Anti-Cheat baslatildi")
