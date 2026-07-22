import { Request, Response, NextFunction } from "express";
import { ApiError } from "./errors";

export type SanitizedCreateBookingBody = {
  production: string | undefined;
  stage: string | undefined;
  slot: string | undefined;
  crewSize: number;
};

function trimString(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function coercePositiveInt(value: unknown, fallback: number): number {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }

  const parsed = typeof value === "number" ? value : parseInt(String(value), 10);
  if (!Number.isFinite(parsed) || !Number.isInteger(parsed) || parsed < 1) {
    return NaN;
  }

  return parsed;
}

export function sanitizeCreateBooking(
  req: Request,
  _res: Response,
  next: NextFunction
): void {
  const raw = req.body;

  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    return next(new ApiError(400, "request body must be a JSON object", "INVALID_BODY"));
  }

  const sanitized: SanitizedCreateBookingBody = {
    production: trimString(raw.production),
    stage: trimString(raw.stage),
    slot: trimString(raw.slot),
    crewSize: coercePositiveInt(raw.crewSize, 1),
  };

  req.body = sanitized;
  next();
}
