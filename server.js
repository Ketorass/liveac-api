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
  code = code.replace(/--\[\[[\s\S]*?\]\]/g, "");
  code = code.replace(/--.*$/gm, "");
  code = code.replace(/\n\s*\n/g, "\n");
  code = code.replace(/\s*([=+\-*\/,{}()\[\];.])\s*/g, "$1");
  code = code.replace(/\b(for|while|if|then|else|elseif|do|end|return|function|local|in|repeat|until)\b/g, " $1 ");
  code = code.replace(/("[^"]*")/g, (m) => {
    const s = m.slice(1, -1);
    if (
      s.length > 5 &&
      (/[A-Za-z]/.test(s) || /[çğıöşüÇĞİÖŞÜ]/.test(s))
    ) {
      const bytes = [];
      for (let i = 0; i < s.length; i++) {
        bytes.push(s.charCodeAt(i));
      }
      return `string.char(${bytes.join(",")})`;
    }
    return m;
  });
  code = code.replace(/(\b)[eE][nN][dD](\b)/g, "$1_end$2");
  code = code.replace(/string\.char\(([^)]+)\)_end/g, "string.char($1)");
  const junkVar = "_" + Math.random().toString(36).substr(2, 6);
  code = `local ${junkVar}=0 ${code}`;
  code = code.replace(/local function/g, ` ${junkVar}=${junkVar}+1 local function`);
  code = code.replace(/\s{2,}/g, " ");
  return code.trim();
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
    code = code.replace(/local LICENSE_KEY = "[^"]*"/, `local LICENSE_KEY = "${req.query.key}"`);
    if (req.query.obfuscate === "true") {
      code = obfuscate(code);
    }
    res.send(code);
  } catch {
    res.send("INVALID");
  }
});

app.get("/script", async (req, res) => {
  const status = await checkLicense(req.query.key);
  if (status !== "OK") return res.send(status);

  const lang = req.query.lang === "en" ? "en" : "tr";
  const filename = `loader-${lang}.lua`;

  try {
    let code = fs.readFileSync(path.join(__dirname, filename), "utf8");
    code = code.replace(/%KEY%/g, req.query.key);
    res.send(code);
  } catch {
    res.send("INVALID");
  }
});

app.listen(process.env.PORT || 3000);
