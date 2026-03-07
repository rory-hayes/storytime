import { describe, expect, it, vi } from "vitest";
import { StoryContinuityService } from "../services/storyContinuityService.js";
import { StoryDiscoveryService } from "../services/storyDiscoveryService.js";
import { buildStoryPlan } from "../services/storyPlannerService.js";
import { StoryService } from "../services/storyService.js";
import type { DiscoveryRequest, StoryScene } from "../types.js";
import { makeCapturedLogger, makeRequestContext, makeTestEnv } from "./testHelpers.js";

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

  it("logs discovery lifecycle retries without transcript content", async () => {
    vi.spyOn(Math, "random").mockReturnValue(0);
    const openai = {
      responses: {
        create: vi
          .fn()
          .mockRejectedValueOnce(Object.assign(new Error("temporary discovery failure"), { status: 503 }))
          .mockResolvedValueOnce({
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
                        setting: "park",
                        tone: "cozy",
                        episode_intent: "a complete and happy standalone adventure"
                      },
                      ready_to_generate: true,
                      next_focus_slot: null,
                      assistant_message: "I have enough details now."
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
    const captured = makeCapturedLogger();
    const service = new StoryDiscoveryService(openai, makeTestEnv({ OPENAI_MAX_RETRIES: 1, OPENAI_RETRY_BASE_MS: 0 }), moderation);

    const result = await service.analyzeTurn(discoveryRequest(), makeRequestContext({ logger: captured.logger }));

    expect(result.blocked).toBe(false);
    const lifecycleEntries = captured.entries.filter((entry) => entry.bindings.event_type === "lifecycle_event");
    expect(
      lifecycleEntries.map((entry) => `${entry.bindings.component}.${entry.bindings.action}.${entry.bindings.status}`)
    ).toEqual(
      expect.arrayContaining([
        "story_discovery.analyze_turn.started",
        "story_discovery.analyze_turn.retrying",
        "story_discovery.analyze_turn.completed"
      ])
    );
    const serializedLogs = JSON.stringify(lifecycleEntries);
    expect(serializedLogs).not.toContain("Bunny wants a lantern story in the park");
    expect(serializedLogs).not.toContain("temporary discovery failure");
  });

  it("logs generate lifecycle retries and completion without story text", async () => {
    vi.spyOn(Math, "random").mockReturnValue(0);
    const openai = {
      responses: {
        create: vi
          .fn()
          .mockRejectedValueOnce(Object.assign(new Error("transient generate failure"), { status: 503 }))
          .mockResolvedValueOnce({
            output: [
              {
                type: "message",
                content: [
                  {
                    type: "output_text",
                    text: JSON.stringify({
                      title: "Lantern Trail",
                      scenes: [
                        { scene_id: "1", text: "Bunny smiled in the park.", duration_sec: 40 },
                        { scene_id: "2", text: "Fox found the clue and everyone cheered happily.", duration_sec: 50 },
                        { scene_id: "3", text: "They followed the lantern path past the pond together.", duration_sec: 45 },
                        { scene_id: "4", text: "They walked home happy beneath the moon.", duration_sec: 45 }
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
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = {
      enrichEngine: vi.fn().mockResolvedValue({
        episode_recap: "Bunny and Fox followed the lantern trail.",
        series_memory: {
          title: "Lantern Trail",
          recurring_characters: ["Bunny", "Fox"],
          prior_episode_recap: "Bunny and Fox followed the lantern trail.",
          world_facts: ["Lanterns glow in the park."],
          open_loops: [],
          favorite_places: ["park"],
          relationship_facts: ["Bunny and Fox help each other."],
          arc_summary: "They follow happy clues together.",
          next_episode_hook: "Another lantern appears by the pond."
        },
        character_bible: [
          { name: "Bunny", role: "main friend", traits: ["kind", "curious"] },
          { name: "Fox", role: "returning friend", traits: ["warm", "helpful"] }
        ],
        continuity_facts: ["Lanterns glow in the park."]
      })
    } as any;
    const captured = makeCapturedLogger();
    const service = new StoryService(
      openai,
      makeTestEnv({ OPENAI_MAX_RETRIES: 1, OPENAI_RETRY_BASE_MS: 0 }),
      moderation,
      continuity
    );

    const result = await service.generateStory(generateRequest(), makeRequestContext({ logger: captured.logger }));

    expect(result.blocked).toBe(false);
    const lifecycleEntries = captured.entries.filter((entry) => entry.bindings.event_type === "lifecycle_event");
    expect(
      lifecycleEntries.map((entry) => `${entry.bindings.component}.${entry.bindings.action}.${entry.bindings.status}`)
    ).toEqual(
      expect.arrayContaining([
        "story_generate.generate_story.started",
        "story_generate.generate_story.retrying",
        "story_generate.generate_story.completed"
      ])
    );
    const serializedLogs = JSON.stringify(lifecycleEntries);
    expect(serializedLogs).not.toContain("Fox found the clue and everyone cheered happily.");
    expect(serializedLogs).not.toContain("transient generate failure");
  });

  it("logs revise lifecycle failures without remaining-scene text", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockRejectedValue(new Error("revision backend down"))
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const captured = makeCapturedLogger();
    const service = new StoryService(openai, makeTestEnv({ OPENAI_MAX_RETRIES: 0 }), moderation, continuity);

    await expect(service.reviseStory(revisionRequest(), makeRequestContext({ logger: captured.logger }))).rejects.toThrow(
      "revision backend down"
    );

    const lifecycleEntries = captured.entries.filter((entry) => entry.bindings.event_type === "lifecycle_event");
    expect(
      lifecycleEntries.map((entry) => `${entry.bindings.component}.${entry.bindings.action}.${entry.bindings.status}`)
    ).toEqual(
      expect.arrayContaining([
        "story_revise.revise_story.started",
        "story_revise.revise_story.failed"
      ])
    );
    const failedEntry = lifecycleEntries.find(
      (entry) => entry.bindings.component === "story_revise" && entry.bindings.status === "failed"
    );
    expect(failedEntry?.bindings.error_name).toBe("Error");

    const serializedLogs = JSON.stringify(lifecycleEntries);
    expect(serializedLogs).not.toContain("The dragon looked worried by the fountain.");
    expect(serializedLogs).not.toContain("revision backend down");
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
