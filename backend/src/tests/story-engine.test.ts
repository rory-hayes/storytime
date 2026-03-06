import { describe, expect, it, vi } from "vitest";
import { StoryContinuityService, mergeContinuity } from "../services/storyContinuityService.js";
import { StoryService } from "../services/storyService.js";
import type { StoryScene } from "../types.js";
import { buildStoryPlan } from "../services/storyPlannerService.js";
import { makeRequestContext, makeTestEnv, responseWithJSON } from "./testHelpers.js";

const goodStoryPayload = {
  title: "Bunny and the Lantern Path",
  scenes: [
    { scene_id: "1", text: "Bunny woke in the sunny park and smiled at a tiny lantern clue.", duration_sec: 45 },
    { scene_id: "2", text: "Fox joined Bunny and together they followed a gentle path past the pond.", duration_sec: 45 },
    { scene_id: "3", text: "They solved the clue with teamwork and found a warm picnic surprise.", duration_sec: 45 },
    { scene_id: "4", text: "Everyone hugged, laughed, and walked home happy beneath the soft sky.", duration_sec: 45 }
  ]
};

const revisedScenesPayload = {
  scenes: [
    { scene_id: "3", text: "The dragon giggled and shared a funny clue by the fountain.", duration_sec: 20 },
    { scene_id: "4", text: "They celebrated with a cozy smile and a happy picnic at home.", duration_sec: 50 }
  ]
};

function makeGenerateRequest() {
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

function makeReviseRequest() {
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

describe("story engine services", () => {
  it("merges extracted continuity with planned series memory", () => {
    const plan = buildStoryPlan({
      titleHint: "Lantern Club",
      theme: "following a clue",
      characters: ["Bunny", "Fox"],
      setting: "park",
      tone: "gentle and playful",
      episodeIntent: "continue the series with a new episode",
      lengthMinutes: 3,
      continuityFacts: [
        "Characters: Bunny, Fox",
        "Open loop: There is still one lantern clue left.",
        "Place: lantern park"
      ]
    });

    const merged = mergeContinuity(plan, {
      episode_recap: "Bunny and Fox followed a glowing clue together.",
      character_bible: [{ name: "Fox", role: "returning friend", traits: ["clever", "kind"] }],
      favorite_places: ["lantern park"],
      relationship_facts: ["Bunny and Fox trust each other."],
      world_facts: ["Lanterns bloom in the park at dusk."],
      open_loops: ["They still need to find the last lantern clue."],
      arc_summary: "Bunny and Fox are solving a lantern mystery.",
      next_episode_hook: "A final lantern begins to glow by the hill.",
      continuity_facts: ["Bunny and Fox are solving a lantern mystery."]
    });

    expect(merged.series_memory.favorite_places).toContain("lantern park");
    expect(merged.series_memory.open_loops.join(" ")).toContain("last lantern clue");
    expect(merged.character_bible.map((entry) => entry.name)).toContain("Fox");
    expect(merged.continuity_facts.join(" ")).toContain("Next episode hook");
  });

  it("falls back to structural continuity when extraction fails", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockRejectedValue(new Error("continuity unavailable"))
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
      continuityFacts: ["Place: lantern park"]
    });

    const engine = await service.enrichEngine(
      "Lantern Club",
      [
        { scene_id: "1", text: "Bunny met Fox in Lantern Park.", duration_sec: 45 },
        { scene_id: "2", text: "They walked home happy after the clue glowed.", duration_sec: 45 }
      ],
      plan,
      makeRequestContext()
    );

    expect(engine.episode_recap).toContain("Lantern Club");
    expect(engine.series_memory.favorite_places).toContain("lantern park");
    expect(engine.character_bible.map((entry) => entry.name)).toContain("Bunny");
  });

  it("blocks unsafe generate requests before calling the model", async () => {
    const openai = { responses: { create: vi.fn() } } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);
    const request = makeGenerateRequest();
    request.story_brief.theme = "a horror cave";

    const result = await service.generateStory(request, makeRequestContext());

    expect(result.blocked).toBe(true);
    expect(openai.responses.create).not.toHaveBeenCalled();
    expect(result.data.safety.input_moderation).toBe("flagged");
  });

  it("generates a safe story and enriches engine continuity", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue(responseWithJSON(goodStoryPayload))
      }
    } as any;
    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = {
      enrichEngine: vi.fn().mockResolvedValue({
        episode_recap: "Bunny and Fox solved the clue.",
        series_memory: {
          title: "Lantern Club",
          recurring_characters: ["Bunny", "Fox"],
          prior_episode_recap: "Bunny and Fox solved the clue.",
          world_facts: ["Lanterns glow at dusk."],
          open_loops: [],
          favorite_places: ["sunny park"],
          relationship_facts: ["Bunny and Fox are kind friends."],
          arc_summary: "They help each other solve clues.",
          next_episode_hook: "A new lantern flickers by the pond."
        },
        character_bible: [
          { name: "Bunny", role: "main story friend", traits: ["kind", "curious"] },
          { name: "Fox", role: "supporting friend", traits: ["warm", "helpful"] }
        ],
        continuity_facts: ["Lanterns glow at dusk."]
      })
    } as any;

    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);
    const result = await service.generateStory(makeGenerateRequest(), makeRequestContext());

    expect(result.blocked).toBe(false);
    expect(result.data.scenes).toHaveLength(4);
    expect(result.data.engine?.episode_recap).toContain("Bunny and Fox");
    expect(continuity.enrichEngine).toHaveBeenCalledTimes(1);
  });

  it("falls back when repeated quality or moderation failures persist", async () => {
    const poorStory = {
      title: "Too Rough",
      scenes: [
        { scene_id: "1", text: "Bunny saw a monster. Bunny saw a monster. Bunny saw a monster.", duration_sec: 60 },
        { scene_id: "2", text: "The monster made Bunny scream in the dark park.", duration_sec: 60 },
        { scene_id: "3", text: "Then they went away.", duration_sec: 60 }
      ]
    };
    const openai = {
      responses: {
        create: vi
          .fn()
          .mockResolvedValueOnce(responseWithJSON(poorStory))
          .mockResolvedValueOnce(responseWithJSON(goodStoryPayload))
          .mockResolvedValueOnce(responseWithJSON(goodStoryPayload))
          .mockResolvedValueOnce(responseWithJSON(goodStoryPayload))
      }
    } as any;

    const moderation = {
      moderateText: vi.fn().mockResolvedValue({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: true, categories: ["violence"] })
    } as any;
    const continuity = { enrichEngine: vi.fn() } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);

    const result = await service.generateStory(makeGenerateRequest(), makeRequestContext());

    expect(result.blocked).toBe(true);
    expect(result.data.safety.output_moderation).toBe("flagged");
    expect(openai.responses.create).toHaveBeenCalledTimes(3);
  });

  it("blocks unsafe revision updates and only rewrites remaining scenes on success", async () => {
    const openai = {
      responses: {
        create: vi.fn().mockResolvedValue(responseWithJSON(revisedScenesPayload))
      }
    } as any;
    const moderation = {
      moderateText: vi
        .fn()
        .mockResolvedValueOnce({ flagged: true, categories: ["violence"] })
        .mockResolvedValueOnce({ flagged: false, categories: [] }),
      moderateManyText: vi.fn().mockResolvedValue({ flagged: false, categories: [] })
    } as any;
    const continuity = {
      enrichEngine: vi.fn().mockResolvedValue({
        episode_recap: "Bunny and Dragon solved the picnic mystery.",
        series_memory: {
          title: "The Friendly Dragon",
          recurring_characters: ["Bunny", "Dragon"],
          prior_episode_recap: "Bunny and Dragon solved the picnic mystery.",
          world_facts: ["The fountain hides funny clues."],
          open_loops: [],
          favorite_places: ["fountain"],
          relationship_facts: ["Bunny and Dragon are gentle friends."],
          arc_summary: "They solve happy mysteries together.",
          next_episode_hook: "A new clue floats past the fountain."
        },
        character_bible: [
          { name: "Bunny", role: "main story friend", traits: ["kind", "curious"] },
          { name: "Dragon", role: "supporting friend", traits: ["funny", "warm"] }
        ],
        continuity_facts: ["The fountain hides funny clues."]
      })
    } as any;
    const service = new StoryService(openai, makeTestEnv(), moderation, continuity);

    const blocked = await service.reviseStory(
      {
        ...makeReviseRequest(),
        user_update: "Make it a scary horror ending"
      },
      makeRequestContext()
    );
    expect(blocked.blocked).toBe(true);
    expect(blocked.data.scenes).toHaveLength(2);

    const revised = await service.reviseStory(makeReviseRequest(), makeRequestContext());
    expect(revised.blocked).toBe(false);
    expect(revised.data.revised_from_scene_index).toBe(2);
    expect(revised.data.scenes).toEqual(revisedScenesPayload.scenes);
    expect(continuity.enrichEngine).toHaveBeenCalledTimes(1);
  });
});
