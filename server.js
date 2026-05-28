const express = require("express");
const fs = require("fs");
const path = require("path");
const app = express();

const FIREBASE_URL = "https://liveac-database-default-rtdb.europe-west1.firebasedatabase.app";

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
    if (start > 0 && now > start + expire) return "EXPIRED";
    return "OK";
  } catch {
    return "INVALID";
  }
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
    const code = fs.readFileSync(path.join(__dirname, filename), "utf8");
    res.send(code);
  } catch {
    res.send("INVALID");
  }
});

app.listen(process.env.PORT || 3000);
