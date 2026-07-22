import { Request, Response, NextFunction } from "express";

export type ApiErrorBody = {
  error: string;
  code: string;
};

export class ApiError extends Error {
  status: number;
  code: string;

  constructor(status: number, error: string, code: string) {
    super(error);
    this.status = status;
    this.code = code;
  }
}

export function sendError(res: Response, status: number, error: string, code: string): void {
  const body: ApiErrorBody = { error, code };
  res.status(status).json(body);
}

export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  next: NextFunction
): void {
  if (res.headersSent) {
    return next(err);
  }

  if (err instanceof ApiError) {
    sendError(res, err.status, err.message, err.code);
    return;
  }

  if (err instanceof SyntaxError && "body" in err) {
    sendError(res, 400, "invalid JSON", "INVALID_JSON");
    return;
  }

  sendError(res, 500, "internal server error", "INTERNAL_ERROR");
}
