import { describe, expect, it } from "vitest";
import { enforceFollowUpCap, fillMissingSlots } from "../services/discoveryService.js";
import {
  buildFallbackQuestionForSlot,
  defaultEpisodeIntentForMode,
  mergeDiscoverySlotState,
  missingDiscoverySlots,
  normalizeDiscoverySlotState
} from "../services/storyDiscoveryService.js";

describe("discoveryService", () => {
  it("caps follow-up questions at 3", () => {
    expect(enforceFollowUpCap(0)).toBe(0);
    expect(enforceFollowUpCap(2)).toBe(2);
    expect(enforceFollowUpCap(3)).toBe(3);
    expect(enforceFollowUpCap(10)).toBe(3);
  });

  it("fills missing story brief slots with defaults", () => {
    const filled = fillMissingSlots({
      theme: "",
      setting: "",
      tone: "cozy",
      characters: [],
      lesson: ""
    });

    expect(filled.theme.length).toBeGreaterThan(0);
    expect(filled.setting.length).toBeGreaterThan(0);
    expect(filled.tone).toBe("cozy");
    expect(filled.characters.length).toBeGreaterThan(0);
    expect(filled.episodeIntent.length).toBeGreaterThan(0);
    expect(filled.lesson.length).toBeGreaterThan(0);
  });

  it("tracks missing conversational discovery slots", () => {
    const missing = missingDiscoverySlots({
      theme: "find a kite",
      characters: ["Bunny"],
      setting: "park",
      tone: undefined,
      episode_intent: undefined
    });

    expect(missing).toEqual(["tone", "episode_intent"]);
  });

  it("merges discovery state and derives extend-mode episode intent", () => {
    const existing = normalizeDiscoverySlotState(
      {
        theme: "lost balloon",
        characters: ["Bunny"]
      },
      "extend"
    );

    const merged = mergeDiscoverySlotState(
      existing,
      {
        setting: "park",
        tone: "funny"
      },
      "extend"
    );

    expect(merged.theme).toBe("lost balloon");
    expect(merged.characters).toEqual(["Bunny"]);
    expect(merged.setting).toBe("park");
    expect(merged.tone).toBe("funny");
    expect(merged.episode_intent).toBe(defaultEpisodeIntentForMode("extend"));
  });

  it("provides slot-specific fallback questions", () => {
    expect(buildFallbackQuestionForSlot("tone", "new")).toContain("funny");
    expect(buildFallbackQuestionForSlot("episode_intent", "extend", "Last time they found a map")).toContain("next episode");
  });
});
