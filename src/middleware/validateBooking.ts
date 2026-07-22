import { Request, Response, NextFunction } from "express";
import { capacityFor } from "../db";
import { ApiError } from "./errors";
import { SanitizedCreateBookingBody } from "./sanitize";

const SLOT_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}$/;

export function validateCreateBooking(
  req: Request,
  _res: Response,
  next: NextFunction
): void {
  const body = req.body as SanitizedCreateBookingBody;

  if (!body.production) {
    return next(new ApiError(400, "production required", "PRODUCTION_REQUIRED"));
  }

  if (!body.stage) {
    return next(new ApiError(400, "stage required", "STAGE_REQUIRED"));
  }

  if (capacityFor(body.stage) === undefined) {
    return next(new ApiError(400, "unknown stage", "UNKNOWN_STAGE"));
  }

  if (!body.slot || !SLOT_PATTERN.test(body.slot)) {
    return next(new ApiError(400, "slot must match YYYY-MM-DDTHH", "INVALID_SLOT"));
  }

  if (Number.isNaN(body.crewSize)) {
    return next(new ApiError(400, "crewSize must be a positive integer", "INVALID_CREW_SIZE"));
  }

  next();
}
