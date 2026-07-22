import express from "express";
import { errorHandler } from "./middleware/errors";
import { bookingsRouter } from "./routes/bookings";

const app = express();

app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    const ms = Date.now() - start;
    console.log(req.method + " " + req.originalUrl + " " + res.statusCode + " " + ms + "ms");
  });
  next();
});

app.use(express.json());

// Legacy: health check lives here, everything else is bolted onto the router.
app.get("/health", (_req, res) => res.json({ ok: true, service: "shoot-scheduling" }));

app.use("/bookings", bookingsRouter);

app.use(errorHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log("shoot-scheduling-api listening on " + PORT);
});
