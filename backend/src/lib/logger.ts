import pino from "pino";

export const logger = pino({
  level: process.env.NODE_ENV === "production" ? "info" : "debug",
  base: {
    service: "storytime-backend",
    environment: process.env.NODE_ENV ?? "development"
  },
  redact: {
    paths: [
      "req.headers.authorization",
      "req.headers.cookie",
      "req.headers.x-storytime-session",
      "req.headers.x-storytime-install-id",
      "headers.authorization",
      "headers.cookie",
      "headers.x-storytime-session",
      "headers.x-storytime-install-id",
      "authorization",
      "cookie",
      "ticket",
      "token",
      "session_token",
      "openai_api_key",
      "OPENAI_API_KEY"
    ],
    censor: "[REDACTED]"
  }
});
