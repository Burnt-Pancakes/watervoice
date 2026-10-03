// Router for Supabase Edge Runtime: /<function-name>/... -> /opt/functions/<function-name>
Deno.serve(async (req: Request) => {
  const name = new URL(req.url).pathname.split("/")[1];
  if (!name || name.startsWith("_") || name === "main") {
    return new Response(JSON.stringify({ error: "not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
  }
  try {
    // @ts-ignore EdgeRuntime is provided by the runtime
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `/opt/functions/${name}`,
      memoryLimitMb: 256,
      workerTimeoutMs: 10 * 60 * 1000, // fetch-water-quality cron allows 400 s
      noModuleCache: false,
      importMapPath: null,
      envVars: Object.entries(Deno.env.toObject()),
      forceCreate: false,
      netAccessDisabled: false,
      cpuTimeSoftLimitMs: 60000,
      cpuTimeHardLimitMs: 120000,
    });
    return await worker.fetch(req);
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
