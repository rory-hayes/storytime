import { describe, expect, it } from "vitest";
import {
  buildRevisionPlan,
  buildStoryPlan,
  evaluateStoryQuality
} from "../services/storyPlannerService.js";

describe("storyPlannerService", () => {
  it("builds series memory, recap, and beat plan from continuity facts", () => {
    const plan = buildStoryPlan({
      titleHint: undefined,
      theme: "finding a moon kite",
      characters: ["Luna", "Pip"],
      setting: "a cloud village",
      tone: "gentle and magical",
      episodeIntent: "continue the series with a new episode",
      lengthMinutes: 6,
      continuityFacts: [
        "Series title: Luna's Kite Club",
        "Characters: Luna, Pip",
        "Last episode context: Luna and Pip found a silver map in the cloud village.",
        "Open loop: They still need to discover where the map leads.",
        "Place: cloud village",
        "Relationship: Luna and Pip are curious best friends.",
        "Arc summary: Luna and Pip are following clues from a silver map."
      ]
    });

    expect(plan.seriesMemory.title).toBe("Luna's Kite Club");
    expect(plan.seriesMemory.recurring_characters).toContain("Luna");
    expect(plan.seriesMemory.open_loops[0]).toContain("map");
    expect(plan.seriesMemory.favorite_places).toContain("cloud village");
    expect(plan.seriesMemory.relationship_facts[0]).toContain("Luna and Pip");
    expect(plan.seriesMemory.arc_summary).toContain("silver map");
    expect(plan.episodeRecap).toContain("Luna");
    expect(plan.beatPlan).toHaveLength(6);
    expect(plan.characterBible.map((entry) => entry.name)).toContain("Pip");
  });

  it("builds a revision plan from completed scenes and remaining beats", () => {
    const plan = buildRevisionPlan({
      titleHint: "The Friendly Dragon",
      userUpdate: "Make the dragon funny and keep the ending cozy.",
      completedScenes: [
        {
          scene_id: "1",
          text: "Bunny met a dragon by the park gate and offered a kind hello.",
          duration_sec: 40
        }
      ],
      remainingScenes: [
        {
          scene_id: "2",
          text: "The dragon looked worried about losing a picnic basket.",
          duration_sec: 45
        },
        {
          scene_id: "3",
          text: "Bunny promised to help before sunset.",
          duration_sec: 45
        }
      ]
    });

    expect(plan.episodeRecap).toContain("Bunny");
    expect(plan.beatPlan).toHaveLength(2);
    expect(plan.characterBible.map((entry) => entry.name)).toContain("Bunny");
  });

  it("flags repetitive or age-inappropriate story output", () => {
    const plan = buildStoryPlan({
      titleHint: undefined,
      theme: "helping a friend",
      characters: ["Bunny"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episodeIntent: "a complete and happy standalone adventure",
      lengthMinutes: 3,
      continuityFacts: []
    });

    const quality = evaluateStoryQuality(
      {
        title: "Too Rough",
        scenes: [
          {
            scene_id: "1",
            text: "Bunny saw a monster. Bunny saw a monster. Bunny saw a monster.",
            duration_sec: 70
          },
          {
            scene_id: "2",
            text: "The monster made Bunny scream in the dark park.",
            duration_sec: 55
          },
          {
            scene_id: "3",
            text: "Then they went away.",
            duration_sec: 40
          }
        ]
      },
      plan,
      180,
      3
    );

    expect(quality.passed).toBe(false);
    expect(quality.issues.join(" ")).toContain("age-appropriate");
    expect(quality.repeated_phrase_count).toBeGreaterThan(0);
  });
});
