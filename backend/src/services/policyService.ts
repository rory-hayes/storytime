import type { GenerateStoryRequest, ReviseStoryRequest, StoryScript } from "../types.js";

export const REALTIME_VOICES = [
  "alloy",
  "ash",
  "ballad",
  "cedar",
  "coral",
  "echo",
  "marin",
  "sage",
  "shimmer",
  "verse"
] as const;

const BANNED_THEMES = ["horror", "gore", "suicide", "self-harm", "sexual", "abuse", "drugs", "weapon"];

const SAFE_FALLBACK_SCENES: StoryScript["scenes"] = [
  {
    scene_id: "fallback-1",
    text: "Once upon a time, a curious little squirrel found a map to a sunny meadow. The squirrel invited two friends to share a picnic and everyone took turns helping.",
    duration_sec: 45
  },
  {
    scene_id: "fallback-2",
    text: "On the way, they crossed a tiny stream by building a safe stepping path. They cheered for each other and learned that teamwork makes adventures kinder and more fun.",
    duration_sec: 45
  },
  {
    scene_id: "fallback-3",
    text: "At the meadow, they shared snacks, told jokes, and watched clouds drift by. They went home smiling, grateful for a peaceful day and good friends.",
    duration_sec: 45
  }
];

export function estimateSceneCount(lengthMinutes: number): number {
  if (lengthMinutes <= 2) {
    return 3;
  }
  if (lengthMinutes <= 4) {
    return 4;
  }
  if (lengthMinutes <= 6) {
    return 6;
  }
  if (lengthMinutes <= 8) {
    return 8;
  }
  return 10;
}

export function maxWordsForDuration(lengthMinutes: number): number {
  // Child-friendly speech pacing around 110 words per minute.
  return Math.round(lengthMinutes * 110);
}

export function containsBannedTheme(text: string): boolean {
  const lower = text.toLowerCase();
  return BANNED_THEMES.some((word) => lower.includes(word));
}

export function buildGenerateSystemPrompt(request: GenerateStoryRequest, stricter = false): string {
  const sceneCount = estimateSceneCount(request.length_minutes);
  const maxWords = maxWordsForDuration(request.length_minutes);
  const continuity = request.continuity_facts.length
    ? `Continuity facts to preserve: ${request.continuity_facts.join(" | ")}`
    : "No continuity facts provided.";

  return [
    "You are a child-safe story writer for ages 3-8.",
    "Never include scary, violent, sexual, hateful, or age-inappropriate content.",
    "Prefer gentle stakes, emotional safety, and positive endings.",
    "You will receive a story engine plan with character bible, series memory, episode recap, and beat plan. Treat that plan as a hard structure, not a suggestion.",
    "Respect the requested episode intent, such as starting a fresh adventure or continuing an existing series.",
    `Output a full story script with exactly ${sceneCount} scenes and approximately ${maxWords} words total.`,
    "Each scene must have: scene_id, text, duration_sec.",
    "Durations should sum close to requested length in seconds (+/-20%).",
    "English only.",
    continuity,
    stricter ? "Apply extra strict safety filtering: avoid conflict-heavy framing and any risky motifs." : ""
  ]
    .filter(Boolean)
    .join(" ");
}

export function buildReviseSystemPrompt(request: ReviseStoryRequest, stricter = false): string {
  return [
    "You revise the remaining scenes of a child-safe story for ages 3-8.",
    "Only rewrite future scenes; preserve continuity and tone from prior scenes.",
    "You will receive completed scenes and a revision plan. Preserve completed beats and only rewrite what has not happened yet.",
    "Never produce age-inappropriate content.",
    "Return only replacement scenes as JSON.",
    stricter ? "Use extra conservative language and lower-intensity plot changes." : ""
  ]
    .filter(Boolean)
    .join(" ");
}

export function safeFallbackStory(targetMinutes: number): StoryScript {
  const base = SAFE_FALLBACK_SCENES.map((scene, index) => ({
    ...scene,
    scene_id: `fallback-${index + 1}`
  }));

  if (targetMinutes <= 2) {
    return { title: "A Calm Meadow Adventure", scenes: base.slice(0, 2) };
  }

  return { title: "A Calm Meadow Adventure", scenes: base };
}
