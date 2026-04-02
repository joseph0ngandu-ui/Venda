import dotenv from 'dotenv';

dotenv.config({ quiet: true });

const INSECURE_JWT_SECRET_VALUES = new Set([
  'change_me_for_local_dev',
  'replace_with_a_long_random_secret',
  'venda_secret_key',
  'venda_production_secret_key_change_me',
]);

const LOOPBACK_HOSTNAMES = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

type CorsRuntimeConfig = {
  allowDevelopmentOrigins: boolean;
  allowNoOrigin: boolean;
  allowedOrigins: Set<string>;
};

let cachedCorsConfig: CorsRuntimeConfig | null = null;
let cachedDatabaseUrl: string | null = null;
let cachedJwtSecret: string | null = null;
let cachedPort: number | null = null;

const getTrimmedEnv = (name: string) => {
  const value = process.env[name];
  return typeof value === 'string' ? value.trim() : '';
};

const readBooleanEnv = (name: string, defaultValue: boolean) => {
  const value = getTrimmedEnv(name);

  if (!value) {
    return defaultValue;
  }

  switch (value.toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
    case 'on':
      return true;
    case '0':
    case 'false':
    case 'no':
    case 'off':
      return false;
    default:
      throw new Error(`${name} must be set to true or false.`);
  }
};

const normalizeOrigin = (origin: string, envName: string) => {
  const trimmedOrigin = origin.trim();

  if (!trimmedOrigin) {
    throw new Error(`${envName} contains an empty origin entry.`);
  }

  if (trimmedOrigin === '*') {
    throw new Error(`${envName} does not support "*" wildcard origins. Use an explicit comma-separated allowlist.`);
  }

  if (trimmedOrigin.toLowerCase() === 'null') {
    throw new Error(`${envName} must not contain the literal "null" origin.`);
  }

  let parsedOrigin: URL;

  try {
    parsedOrigin = new URL(trimmedOrigin);
  } catch {
    throw new Error(`${envName} contains an invalid origin: ${trimmedOrigin}`);
  }

  if (parsedOrigin.protocol !== 'http:' && parsedOrigin.protocol !== 'https:') {
    throw new Error(`${envName} only supports http:// or https:// origins: ${trimmedOrigin}`);
  }

  if (parsedOrigin.username || parsedOrigin.password) {
    throw new Error(`${envName} origins must not include credentials: ${trimmedOrigin}`);
  }

  if (parsedOrigin.pathname !== '/' || parsedOrigin.search || parsedOrigin.hash) {
    throw new Error(`${envName} origins must not include paths, query strings, or fragments: ${trimmedOrigin}`);
  }

  return parsedOrigin.origin;
};

const readJwtSecretFromEnv = () => {
  const jwtSecret = getTrimmedEnv('JWT_SECRET');

  if (!jwtSecret) {
    throw new Error('JWT_SECRET is required and must not be empty.');
  }

  if (INSECURE_JWT_SECRET_VALUES.has(jwtSecret)) {
    throw new Error('JWT_SECRET must be replaced with a unique secret before starting the API.');
  }

  return jwtSecret;
};

const readDatabaseUrlFromEnv = () => {
  const databaseUrl = getTrimmedEnv('DATABASE_URL');

  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required and must not be empty.');
  }

  let parsedUrl: URL;

  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL must be a valid postgres connection URL.');
  }

  if (parsedUrl.protocol !== 'postgres:' && parsedUrl.protocol !== 'postgresql:') {
    throw new Error('DATABASE_URL must start with postgres:// or postgresql://.');
  }

  return databaseUrl;
};

const readPortFromEnv = () => {
  const rawPort = getTrimmedEnv('PORT');

  if (!rawPort) {
    return 3000;
  }

  const port = Number(rawPort);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be an integer between 1 and 65535.');
  }

  return port;
};

const readCorsConfigFromEnv = (): CorsRuntimeConfig => {
  const nodeEnv = getTrimmedEnv('NODE_ENV').toLowerCase();
  const allowDevelopmentOrigins = readBooleanEnv('CORS_ALLOW_DEV_ORIGINS', nodeEnv !== 'production');
  const allowNoOrigin = readBooleanEnv('CORS_ALLOW_NO_ORIGIN', true);
  const allowedOriginsValue = getTrimmedEnv('CORS_ALLOWED_ORIGINS');
  const allowedOrigins = new Set<string>();

  if (allowedOriginsValue) {
    for (const origin of allowedOriginsValue.split(',')) {
      allowedOrigins.add(normalizeOrigin(origin, 'CORS_ALLOWED_ORIGINS'));
    }
  }

  return {
    allowDevelopmentOrigins,
    allowNoOrigin,
    allowedOrigins,
  };
};

const isLoopbackOrigin = (origin: string) => {
  try {
    const parsedOrigin = new URL(origin);

    if (parsedOrigin.protocol !== 'http:' && parsedOrigin.protocol !== 'https:') {
      return false;
    }

    return LOOPBACK_HOSTNAMES.has(parsedOrigin.hostname.toLowerCase());
  } catch {
    return false;
  }
};

export const getJwtSecret = () => {
  if (cachedJwtSecret) {
    return cachedJwtSecret;
  }

  cachedJwtSecret = readJwtSecretFromEnv();
  return cachedJwtSecret;
};

export const getPort = () => {
  if (cachedPort !== null) {
    return cachedPort;
  }

  cachedPort = readPortFromEnv();
  return cachedPort;
};

export const getDatabaseUrl = () => {
  if (cachedDatabaseUrl) {
    return cachedDatabaseUrl;
  }

  cachedDatabaseUrl = readDatabaseUrlFromEnv();
  return cachedDatabaseUrl;
};

export const isCorsOriginAllowed = (origin: string | undefined) => {
  if (!cachedCorsConfig) {
    cachedCorsConfig = readCorsConfigFromEnv();
  }

  const cors = cachedCorsConfig;

  if (!origin) {
    return cors.allowNoOrigin;
  }

  if (origin.toLowerCase() === 'null') {
    return false;
  }

  let normalizedOrigin: string;

  try {
    normalizedOrigin = normalizeOrigin(origin, 'Origin header');
  } catch {
    return false;
  }

  if (cors.allowedOrigins.has(normalizedOrigin)) {
    return true;
  }

  return cors.allowDevelopmentOrigins && isLoopbackOrigin(normalizedOrigin);
};

export const validateRuntimeConfig = () => {
  getDatabaseUrl();
  getJwtSecret();
  getPort();

  if (!cachedCorsConfig) {
    cachedCorsConfig = readCorsConfigFromEnv();
  }
};

export const resetRuntimeConfigCache = () => {
  cachedCorsConfig = null;
  cachedDatabaseUrl = null;
  cachedJwtSecret = null;
  cachedPort = null;
};
