const express = require("express");
const app = express();

const FIREBASE_URL = "https://liveac-database-default-rtdb.europe-west1.firebasedatabase.app";

app.use((req, res, next) => {
  res.type("text/plain");
  next();
});

app.get("/loader", async (req, res) => {
  const key = req.query.key;
  if (!key || typeof key !== "string") return res.send("INVALID");

  try {
    const resp = await fetch(
      `${FIREBASE_URL}/LicenceKeys/${encodeURIComponent(key)}.json`
    );
    if (!resp.ok) return res.send("INVALID");

    const data = await resp.json();
    if (!data) return res.send("INVALID");

    const active = data.Active === true || data.Active === "true";
    if (!active) return res.send("INVALID");

    const now = Math.floor(Date.now() / 1000);
    const expire = Number(data.ExpireDays || 0) * 86400;
    const start = Number(data.StartTime || 0);

    if (start > 0 && now > start + expire) return res.send("EXPIRED");

    res.send("OK");
  } catch {
    res.send("INVALID");
  }
});

app.listen(process.env.PORT || 3000);
