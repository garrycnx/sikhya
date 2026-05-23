import { Response } from 'express';
import { ApiResponse } from '../types';
export function sendSuccess<T>(res: Response, data: T, status = 200, meta?: ApiResponse['meta']) {
  return res.status(status).json({ success: true, data, meta } satisfies ApiResponse<T>);
}
export function sendError(res: Response, message: string, status = 400) {
  return res.status(status).json({ success: false, error: message } satisfies ApiResponse);
}
export function sendCreated<T>(res: Response, data: T) { return sendSuccess(res, data, 201); }