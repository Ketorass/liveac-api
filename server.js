const express = require("express");
const fs = require("fs");
const path = require("path");
const app = express();

const FIREBASE_URL =
  "https://liveac-database-default-rtdb.europe-west1.firebasedatabase.app";

app.use((req, res, next) => {
  res.type("text/plain");
  next();
});

async function checkLicense(key) {
  if (!key || typeof key !== "string") return "INVALID";
  try {
    const resp = await fetch(
      `${FIREBASE_URL}/LicenceKeys/${encodeURIComponent(key)}.json`
    );
    if (!resp.ok) return "INVALID";
    const data = await resp.json();
    if (!data) return "INVALID";
    const active = data.Active === true || data.Active === "true";
    if (!active) return "INVALID";
    const now = Math.floor(Date.now() / 1000);
    const expire = Number(data.ExpireDays || 0) * 86400;
    const start = Number(data.StartTime || 0);
    const effectiveStart = start > 0 ? start : now;
    if (expire > 0 && now > effectiveStart + expire) return "EXPIRED";
    return "OK";
  } catch {
    return "INVALID";
  }
}

function obfuscate(code) {
  // Remove comments
  code = code.replace(/--\[\[[\s\S]*?\]\]/g, "");
  code = code.replace(/--.*$/gm, "");
  code = code.replace(/\s+/g, " ");
  code = code.replace(/\s*([=+\-*/,{}()\[\];.])\s*/g, "$1");
  code = code.replace(/\s*([<>])\s*/g, "$1");
  code = code.replace(/\s*(and|or|not|in)\s/g, " $1 ");
  code = code.replace(/"([^"]*)"/g, (m, s) => {
    if (
      s.includes("discord.com") ||
      s.includes("onrender.com") ||
      s.includes("firebase") ||
      s.includes("api/webhook") ||
      s.includes("license") ||
      s.includes("License") ||
      s.includes("lisans") ||
      s.includes("Lisans") ||
      s.includes("anticheat") ||
      s.includes("Anti-Cheat") ||
      s.includes("Live Anti-Cheat") ||
      s.includes("Kick")
    ) {
      const bytes = [];
      for (let i = 0; i < s.length; i++) {
        bytes.push(s.charCodeAt(i));
      }
      return `string.char(${bytes.join(",")})`;
    }
    return m;
  });

  // Add junk
  const junkVar = "_" + Math.random().toString(36).substr(2, 6);
  code = `local ${junkVar}=0;${code}`;
  code = code.replace(/local function/g, ` ${junkVar}=${junkVar}+1;local function`);

  code = code.replace(/\n+/g, " ");
  code = code.replace(/\s{2,}/g, " ");

  return code;
}

app.get("/loader", async (req, res) => {
  res.send(await checkLicense(req.query.key));
});

app.get("/anticheat", async (req, res) => {
  const status = await checkLicense(req.query.key);
  if (status !== "OK") return res.send(status);

  const lang = req.query.lang === "en" ? "en" : "tr";
  const filename = `anticheat-${lang}.lua`;

  try {
    let code = fs.readFileSync(path.join(__dirname, filename), "utf8");
    if (req.query.obfuscate === "true") {
      code = obfuscate(code);
    }
    res.send(code);
  } catch {
    res.send("INVALID");
  }
});

app.listen(process.env.PORT || 3000);
