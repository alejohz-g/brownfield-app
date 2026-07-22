import { Router } from "express";
import { nextId, capacityFor, countForSlot, insert, all, findById, Booking } from "../db";
import { ApiError } from "../middleware/errors";
import { sanitizeCreateBooking, SanitizedCreateBookingBody } from "../middleware/sanitize";
import { validateCreateBooking } from "../middleware/validateBooking";
// Legacy JS module pulled in without types.
const rates = require("../legacy/rates");

export const bookingsRouter = Router();

bookingsRouter.post(
  "/",
  sanitizeCreateBooking,
  validateCreateBooking,
  (req, res, next) => {
    try {
      const body = req.body as SanitizedCreateBookingBody;
      const { production, stage, slot, crewSize } = body;

      const cap = capacityFor(stage);
      const taken = countForSlot(stage, slot);
      if (taken + crewSize > cap) {
        throw new ApiError(409, "stage full", "STAGE_FULL");
      }

      const rate = rates.rateFor(stage, slot, crewSize);

      const b: Booking = {
        id: nextId(),
        production,
        stage,
        slot,
        crewSize,
        ratePaid: rate,
        createdAt: new Date().toISOString(),
      };
      insert(b);
      return res.status(201).json(b);
    } catch (err) {
      next(err);
    }
  }
);

bookingsRouter.get("/", (_req, res) => {
  res.json(all());
});

bookingsRouter.get("/:id", (req, res) => {
  const b = findById(req.params.id);
  if (!b) return res.status(404).send("not found");
  res.json(b);
});
