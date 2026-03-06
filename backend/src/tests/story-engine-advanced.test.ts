import { describe, expect, it, vi } from "vitest";
import { StoryContinuityService } from "../services/storyContinuityService.js";
import { StoryDiscoveryService } from "../services/storyDiscoveryService.js";
import { buildStoryPlan } from "../services/storyPlannerService.js";
import { StoryService } from "../services/storyService.js";
import type { DiscoveryRequest, StoryScene } from "../types.js";
import { makeRequestContext, makeTestEnv } from "./testHelpers.js";

function discoveryRequest(overrides: Partial<DiscoveryRequest> = {}): DiscoveryRequest {
  return {
    child_profile_id: "11111111-1111-1111-1111-111111111111",
    transcript: "Bunny wants a lantern story in the park",
    question_count: 1,
    slot_state: {
      theme: "lantern adventure",
      characters: ["Bunny"]
    },
    mode: "new",
    ...overrides
  };
}

function generateRequest() {
  return {
    child_profile_id: "11111111-1111-1111-1111-111111111111",
    age_band: "3-8" as const,
    language: "en" as const,
    length_minutes: 3,
    voice: "alloy",
    question_count: 2,
    story_brief: {
      theme: "following a lantern clue",
      characters: ["Bunny", "Fox"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episode_intent: "a complete and happy standalone adventure",
      lesson: "kindness"
    },
    continuity_facts: ["Characters: Bunny, Fox"]
  };
}

function revisionRequest() {
  const remainingScenes: StoryScene[] = [
    { scene_id: "3", text: "The dragon looked worried by the fountain.", duration_sec: 20 },
    { scene_id: "4", text: "Bunny promised to help before sunset.", duration_sec: 50 }
  ];

  return {
    story_id: "22222222-2222-2222-2222-222222222222",
    current_scene_index: 2,
    story_title: "The Friendly Dragon",
    user_update: "Make the dragon funny and keep the ending cozy.",
    completed_scenes: [
      { scene_id: "1", text: "Bunny met Dragon at the park gate.", duration_sec: 35 },
      { scene_id: "2", text: "They looked for the missing picnic basket.", duration_sec: 35 }
    ],
    remaining_scenes: remainingScenes
  };
}

describe("story engine advanced coverage", () => {
  it("sanitizes discovery follow-up questions from model output", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue({
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    slot_state: {
                      theme: "lantern adventure",
                      characters: ["Bunny", "Fox"],
                      setting: null,
                      tone: "cozy",
                      episode_intent: null
                    },
                    ready_to_generate: false,
                    next_focus_slot: "theme",
                    assistant_message: "Tell me more"
                  })
                }
              ]
            }
          ]
        })
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;

    const service = new StoryDiscoveryService(openai, makeTestEnv(), moderation);
    const result = await service.analyzeTurn(discoveryRequest(), makeRequestContext());

    expect(result.blocked).toBe(false);
    expect(result.data.question_count).toBe(2);
    expect(result.data.slot_state.characters).toEqual(["Bunny", "Fox"]);
    expect(result.data.assistant_message).toBe("Where should the story happen?");
  });

  it("caps discovery after three follow-ups without calling the model", async () => {
    const openai = {
      responses: {
        create: vi.fn()
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;

    const service = new StoryDiscoveryService(openai, makeTestEnv(), moderation);
    const result = await service.analyzeTurn(
      discoveryRequest({
        question_count: 3,
        slot_state: {}
      }),
      makeRequestContext()
    );

    expect(result.blocked).toBe(false);
    expect(result.data.ready_to_generate).toBe(true);
    expect(result.data.question_count).toBe(3);
    expect(openai.responses.create).not.toHaveBeenCalled();
  });

  it("surfaces empty discovery model output as an upstream error", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue({ output: [] })
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;

    const service = new StoryDiscoveryService(openai, makeTestEnv(), moderation);

    await expect(service.analyzeTurn(discoveryRequest(), makeRequestContext())).rejects.toMatchObject({
      code: "model_empty_output"
    });
  });

  it("extracts continuity from message-part output and merges plan memory", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue({
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    episode_recap: "Bunny and Fox followed the moon lantern through the park.",
                    character_bible: [{ name: "Fox", role: "returning friend", traits: ["clever", "kind"] }],
                    favorite_places: ["moonlit park"],
                    relationship_facts: ["Bunny and Fox trust each other."],
                    world_facts: ["Moon lanterns glow brighter near the pond."],
                    open_loops: ["One lantern clue still points toward the hill."],
                    arc_summary: "They are solving a glowing lantern trail.",
                    next_episode_hook: "A final clue twinkles near the hill.",
                    continuity_facts: ["Moon lanterns glow brighter near the pond."]
                  })
                }
              ]
            }
          ]
        })
      }
    } as any;

    const service = new StoryContinuityService(openai, makeTestEnv());
    const plan = buildStoryPlan({
      titleHint: "Lantern Club",
      theme: "following a clue",
      characters: ["Bunny", "Fox"],
      setting: "park",
      tone: "gentle and playful",
      episodeIntent: "continue the series with a new episode",
      lengthMinutes: 3,
      continuityFacts: ["Place: moonlit park"]
    });

    const result = await service.enrichEngine(
      "Lantern Club",
      [
        { scene_id: "1", text: "Bunny found the moon lantern at the pond.", duration_sec: 40 },
        { scene_id: "2", text: "Fox smiled and promised to follow the final clue next time.", duration_sec: 40 }
      ],
      plan,
      makeRequestContext()
    );

    expect(result.series_memory.favorite_places).toContain("moonlit park");
    expect(result.series_memory.next_episode_hook).toContain("final clue");
    expect(result.character_bible.map((entry) => entry.name)).toContain("Fox");
  });

  it("handles flagged input moderation before story generation", async () => {
    const openai = { responses: { create: vi.fn() } } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: true, categories: ["violence"] }),
      moderateManyText: vi.fn()
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);

    const result = await service.generateStory(generateRequest(), makeRequestContext());

    expect(result.blocked).toBe(true);
    expect(result.safe_message).toContain("different idea");
    expect(openai.responses.create).not.toHaveBeenCalled();
  });

  it("reads generated story payloads from response message parts", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue({
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    title: "Lantern Trail",
                    scenes: [
                      { scene_id: "1", text: " Bunny smiled in the park. ", duration_sec: 40 },
                      { scene_id: "2", text: " Fox found the clue and everyone cheered happily. ", duration_sec: 50 },
                      { scene_id: "3", text: " They walked home happy beneath the moon. ", duration_sec: 60 }
                    ]
                  })
                }
              ]
            }
          ]
        })
      }
    } as any;

    const moderation = {
      moderateText: vi.fn(),
      moderateManyText: vi.fn()
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);
    const plan = buildStoryPlan({
      titleHint: undefined,
      theme: "following a lantern clue",
      characters: ["Bunny", "Fox"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episodeIntent: "a complete and happy standalone adventure",
      lengthMinutes: 3,
      continuityFacts: []
    });

    const story = await (service as any).generateStoryFromModel(generateRequest(), plan, false, [], makeRequestContext());

    expect(story.title).toBe("Lantern Trail");
    expect(story.scenes[0].text).toBe("Bunny smiled in the park.");
    expect(story.scenes).toHaveLength(3);
  });

  it("rejects empty generation output and invalid revision payloads", async () => {
    const openai = {
      responses: {
        create: vi
          .fn()
          .mockResolvedValueOnce({ output: [] })
          .mockResolvedValueOnce({ output_text: JSON.stringify({ scenes: [] }) })
      }
    } as any;
    const moderation = {
      moderateText: vi.fn(),
      moderateManyText: vi.fn()
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);
    const plan = buildStoryPlan({
      titleHint: undefined,
      theme: "following a lantern clue",
      characters: ["Bunny", "Fox"],
      setting: "a sunny park",
      tone: "gentle and playful",
      episodeIntent: "a complete and happy standalone adventure",
      lengthMinutes: 3,
      continuityFacts: []
    });

    await expect(
      (service as any).generateStoryFromModel(generateRequest(), plan, false, [], makeRequestContext())
    ).rejects.toMatchObject({ code: "model_empty_output" });

    await expect(
      (service as any).reviseRemainingScenesFromModel(revisionRequest(), plan, false, [], makeRequestContext())
    ).rejects.toMatchObject({ code: "invalid_revision_output" });
  });

  it("falls back to original remaining scenes when revision output stays flagged", async () => {
    const openai = {
      responses: {
        create: vi
          .fn()
          .mockResolvedValue({ output_text: JSON.stringify({ scenes: revisionRequest().remaining_scenes }) })
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: true, categories: ["violence"] })
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);

    const result = await service.reviseStory(revisionRequest(), makeRequestContext());

    expect(result.blocked).toBe(true);
    expect(result.data.scenes).toEqual(revisionRequest().remaining_scenes);
    expect(result.data.safety.output_moderation).toBe("flagged");
  });
});
