import { describe, expect, it } from "vitest";
import {
  DiscoveryRequestSchema,
  EmbeddingsCreateRequestSchema,
  GenerateStoryRequestSchema,
  RealtimeCallRequestSchema,
  RealtimeSessionRequestSchema,
  ReviseStoryRequestSchema,
  StoryEngineSchema,
  StoryScriptSchema
} from "../types.js";

describe("request and response schemas", () => {
  it("accepts valid generate, revise, discovery, realtime, and embeddings payloads", () => {
    expect(() =>
      GenerateStoryRequestSchema.parse({
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        age_band: "3-8",
        language: "en",
        length_minutes: 4,
        voice: "alloy",
        question_count: 2,
        story_brief: {
          theme: "finding a kite",
          characters: ["Bunny"],
          setting: "park",
          tone: "gentle",
          episode_intent: "a happy adventure"
        },
        continuity_facts: ["Bunny likes kites"]
      })
    ).not.toThrow();

    expect(() =>
      ReviseStoryRequestSchema.parse({
        story_id: "22222222-2222-2222-2222-222222222222",
        current_scene_index: 1,
        user_update: "Make the ending cozier",
        remaining_scenes: [{ scene_id: "2", text: "Scene", duration_sec: 30 }]
      })
    ).not.toThrow();

    expect(() =>
      DiscoveryRequestSchema.parse({
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        transcript: "A bunny in the park",
        question_count: 1,
        mode: "new"
      })
    ).not.toThrow();

    expect(() =>
      RealtimeSessionRequestSchema.parse({
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      })
    ).not.toThrow();

    expect(() =>
      RealtimeCallRequestSchema.parse({
        ticket: "x".repeat(24),
        sdp: "v=0\r\n" + "a".repeat(32)
      })
    ).not.toThrow();

    expect(() => EmbeddingsCreateRequestSchema.parse({ inputs: ["hello", "world"] })).not.toThrow();
  });

  it("preserves realtime SDP exactly without trimming trailing line endings", () => {
    const sdp = "v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\ns=StoryTime\r\n";
    const parsed = RealtimeCallRequestSchema.parse({
      ticket: "x".repeat(24),
      sdp
    });

    expect(parsed.sdp).toBe(sdp);
    expect(parsed.sdp.endsWith("\r\n")).toBe(true);
  });

  it("rejects invalid payloads and validates story engine shape", () => {
    expect(() =>
      GenerateStoryRequestSchema.parse({
        child_profile_id: "not-a-uuid",
        length_minutes: 20,
        voice: "",
        question_count: 9,
        story_brief: {
          theme: "",
          characters: [],
          setting: "",
          tone: ""
        }
      })
    ).toThrow();

    expect(() =>
      StoryScriptSchema.parse({
        title: "Test",
        scenes: [{ scene_id: "1", text: "Hi", duration_sec: 5 }]
      })
    ).toThrow();

    expect(() =>
      StoryEngineSchema.parse({
        series_memory: {
          recurring_characters: ["Bunny"],
          world_facts: [],
          open_loops: [],
          favorite_places: [],
          relationship_facts: []
        },
        character_bible: [],
        beat_plan: [{ beat_id: "b1", scene_index: 0, label: "Open", purpose: "Start", target_duration_sec: 30 }],
        continuity_facts: []
      })
    ).not.toThrow();
  });
});
