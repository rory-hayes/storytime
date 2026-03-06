import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "lcov"],
      include: ["src/**/*.ts", "api/**/*.ts"],
      exclude: ["src/tests/**", "src/index.ts", "dist/**"],
      thresholds: {
        lines: 95,
        functions: 95,
        statements: 95,
        branches: 80
      }
    }
  }
});
