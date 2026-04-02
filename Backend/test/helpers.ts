import type { Response } from 'express';
import type { AuthRequest } from '../src/middleware/auth';

type MockState = {
  statusCode: number;
  body: unknown;
};

export const createMockResponse = () => {
  const state: MockState = {
    statusCode: 200,
    body: undefined,
  };

  const response = {
    status(code: number) {
      state.statusCode = code;
      return response;
    },
    json(payload: unknown) {
      state.body = payload;
      return response;
    },
  };

  return {
    res: response as unknown as Response,
    state,
  };
};

export const createAuthRequest = (overrides: Partial<AuthRequest> = {}) => {
  return {
    headers: {},
    params: {},
    query: {},
    body: {},
    ...overrides,
  } as AuthRequest;
};

export const replaceMethod = <T extends object, K extends keyof T>(
  target: T,
  key: K,
  replacement: T[K]
) => {
  const original = target[key];
  target[key] = replacement;

  return () => {
    target[key] = original;
  };
};

export const isIsoTimestamp = (value: unknown) => {
  return typeof value === 'string' && !Number.isNaN(Date.parse(value));
};
