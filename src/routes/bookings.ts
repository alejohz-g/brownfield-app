import { Router } from "express";
import { nextId, capacityFor, countForSlot, insert, all, findById, Booking } from "../db";
// Legacy JS module pulled in without types.
const rates = require("../legacy/rates");

export const bookingsRouter = Router();

// One fat handler doing validation, business logic, rate calculation, and persistence.
// This is the classic brownfield route: everything in one place, no tests,
// inconsistent error shapes. Good target for the workshop refactor.
bookingsRouter.post("/", (req, res) => {
  const body = req.body || {};

  if (!body.production) {
    return res.status(400).send("production required");
  }
  if (!body.stage) {
    return res.json({ error: "stage missing" }); // note: 200 status, different error shape
  }

  const crewSize = body.crewSize ? body.crewSize : 1;
  const cap = capacityFor(body.stage);
  if (cap === undefined) {
    return res.status(400).json({ error: "unknown stage" });
  }

  const taken = countForSlot(body.stage, body.slot);
  if (taken + crewSize > cap) {
    // Stage block is full. Today we just reject. The waitlist feature (see specs/) changes this.
    return res.status(409).json({ error: "stage full", capacity: cap, taken: taken });
  }

  const rate = rates.rateFor(body.stage, body.slot, crewSize);

  const b: Booking = {
    id: nextId(),
    production: body.production,
    stage: body.stage,
    slot: body.slot,
    crewSize: crewSize,
    ratePaid: rate,
    createdAt: new Date().toISOString(),
  };
  insert(b);
  return res.status(201).json(b);
});

bookingsRouter.get("/", (_req, res) => {
  res.json(all());
});

bookingsRouter.get("/:id", (req, res) => {
  const b = findById(req.params.id);
  if (!b) return res.status(404).send("not found");
  res.json(b);
});
