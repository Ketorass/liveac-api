const express = require("express");
const axios = require("axios");

const app = express();

const FIREBASE_URL =
  "https://liveac-database-default-rtdb.europe-west1.firebasedatabase.app";

app.get("/loader", async (req, res) => {
  const key = req.query.key;

  console.log("GELEN KEY:", key);

  if (!key) {
    return res.send("game:Shutdown()");
  }

  try {
    const result = await axios.get(
      `${FIREBASE_URL}/LicenceKeys/${key}.json`
    );

    const data = result.data;

    console.log("FIREBASE RESPONSE:", data);

    // ❌ key yoksa
    if (!data) {
      return res.send("game:Shutdown()");
    }

    // ❌ Active kontrolü (daha sağlam)
    if (data.Active !== true) {
      return res.send("game:Shutdown()");
    }

    const now = Math.floor(Date.now() / 1000);

    const start = Number(data.StartTime);
    const expireDays = Number(data.ExpireDays);

    // ❌ bozuk veri kontrolü
    if (!start || !expireDays) {
      return res.send("game:Shutdown()");
    }

    const expireTime = start + expireDays * 86400;

    if (now >= expireTime) {
      return res.send("game:Shutdown()");
    }

    // ✅ Lua loader output
    const luaScript = `
print("Live Anti-Cheat Loaded")

-- loader OK
`;

    return res.type("text/plain").send(luaScript);

  } catch (err) {
    console.error("ERROR:", err.message);
    return res.send("game:Shutdown()");
  }
});

app.listen(3000, () => {
  console.log("Server çalışıyor: http://localhost:3000");
});