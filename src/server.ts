import express from "express";
import { bookingsRouter } from "./routes/bookings";

const app = express();
app.use(express.json());

// Legacy: health check lives here, everything else is bolted onto the router.
app.get("/health", (_req, res) => res.json({ ok: true, service: "shoot-scheduling" }));

app.use("/bookings", bookingsRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log("shoot-scheduling-api listening on " + PORT);
});
