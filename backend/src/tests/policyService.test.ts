import { describe, expect, it } from "vitest";
import { containsBannedTheme, estimateSceneCount } from "../services/policyService.js";

describe("policyService", () => {
  it("maps story duration to scene count", () => {
    expect(estimateSceneCount(1)).toBe(3);
    expect(estimateSceneCount(3)).toBe(4);
    expect(estimateSceneCount(5)).toBe(6);
    expect(estimateSceneCount(7)).toBe(8);
    expect(estimateSceneCount(10)).toBe(10);
  });

  it("detects banned themes", () => {
    expect(containsBannedTheme("A gentle friendship tale")).toBe(false);
    expect(containsBannedTheme("A scary horror cave")).toBe(true);
  });
});
