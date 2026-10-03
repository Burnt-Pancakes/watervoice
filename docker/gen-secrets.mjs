import { createHmac, randomBytes } from "node:crypto";
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
const jwtSecret = randomBytes(32).toString("hex");
const sign = (role) => {
  const now = Math.floor(Date.now() / 1000);
  const h = b64({ alg: "HS256", typ: "JWT" });
  const p = b64({ iss: "supabase", role, iat: now, exp: now + 10 * 365 * 86400 });
  const s = createHmac("sha256", jwtSecret).update(`${h}.${p}`).digest("base64url");
  return `${h}.${p}.${s}`;
};
const lines = {
  POSTGRES_PASSWORD: randomBytes(24).toString("hex"),
  JWT_SECRET: jwtSecret,
  CRON_SECRET: randomBytes(24).toString("hex"),
  ANON_KEY: sign("anon"),
  SERVICE_ROLE_KEY: sign("service_role"),
};
for (const [k, v] of Object.entries(lines)) console.log(`${k}='${v}'`);
