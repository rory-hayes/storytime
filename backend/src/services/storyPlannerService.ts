import type {
  GenerateStoryRequest,
  ReviseStoryRequest,
  StoryBeat,
  StoryEngine,
  StoryEngineCharacter,
  StoryQualityReport,
  StoryScene,
  StoryScript,
  StorySeriesMemory
} from "../types.js";
import { containsBannedTheme, estimateSceneCount } from "./policyService.js";

const DURATION_WEIGHTS: Record<number, number[]> = {
  3: [0.28, 0.32, 0.4],
  4: [0.22, 0.24, 0.25, 0.29],
  6: [0.14, 0.15, 0.16, 0.17, 0.18, 0.2],
  8: [0.11, 0.11, 0.12, 0.12, 0.13, 0.13, 0.14, 0.14],
  10: [0.09, 0.09, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.11, 0.11]
};

const BEAT_LABELS: Record<number, string[]> = {
  3: ["Cozy Opening", "Kind Adventure", "Happy Ending"],
  4: ["Warm Welcome", "Small Problem", "Trying a Plan", "Happy Ending"],
  6: ["Warm Welcome", "Story Wish", "Gentle Problem", "Trying a Plan", "Bright Turn", "Happy Ending"],
  8: [
    "Warm Welcome",
    "Story Wish",
    "Gentle Problem",
    "Trying a Plan",
    "Playful Detour",
    "Helpful Discovery",
    "Bright Turn",
    "Happy Ending"
  ],
  10: [
    "Warm Welcome",
    "Story Wish",
    "Gentle Problem",
    "Trying a Plan",
    "Playful Detour",
    "Small Surprise",
    "Helpful Discovery",
    "Brave Choice",
    "Bright Turn",
    "Happy Ending"
  ]
};

const AGE_FIT_WARNING_WORDS = [
  "monster",
  "graveyard",
  "blood",
  "knife",
  "gun",
  "kill",
  "dead",
  "died",
  "attack",
  "scream",
  "haunted",
  "nightmare"
];

type StoryPlanInput = {
  titleHint?: string;
  theme: string;
  characters: string[];
  setting: string;
  tone: string;
  episodeIntent?: string;
  lengthMinutes: number;
  continuityFacts: string[];
};

type RevisionPlanInput = {
  titleHint?: string;
  completedScenes: StoryScene[];
  remainingScenes: StoryScene[];
  userUpdate: string;
};

export type StoryPlan = {
  episodeRecap?: string;
  seriesMemory: StorySeriesMemory;
  characterBible: StoryEngineCharacter[];
  beatPlan: StoryBeat[];
};

export function buildStoryPlan(input: StoryPlanInput): StoryPlan {
  const seriesMemory = buildSeriesMemory(input.continuityFacts, input.titleHint);
  const characterBible = buildCharacterBible(input.characters, seriesMemory, input.tone);
  const episodeRecap = buildEpisodeRecap(seriesMemory);
  const beatPlan = buildBeatPlan({
    sceneCount: estimateSceneCount(input.lengthMinutes),
    targetDurationSec: input.lengthMinutes * 60,
    theme: input.theme,
    setting: input.setting,
    tone: input.tone,
    episodeIntent: input.episodeIntent,
    episodeRecap
  });

  return {
    episodeRecap,
    seriesMemory,
    characterBible,
    beatPlan
  };
}

export function buildRevisionPlan(input: RevisionPlanInput): StoryPlan {
  const recap = summarizeScenes(input.completedScenes);
  const seriesMemory = buildSeriesMemory(
    recap ? [`Last episode context: ${recap}`] : [],
    input.titleHint
  );
  const characterBible = buildCharacterBible(
    extractCharactersFromScenes([...input.completedScenes, ...input.remainingScenes]),
    seriesMemory,
    inferToneFromText(input.userUpdate)
  );
  const totalTargetDuration = Math.max(
    60,
    input.remainingScenes.reduce((sum, scene) => sum + scene.duration_sec, 0)
  );

  return {
    episodeRecap: recap,
    seriesMemory,
    characterBible,
    beatPlan: buildBeatPlan({
      sceneCount: input.remainingScenes.length,
      targetDurationSec: totalTargetDuration,
      theme: input.userUpdate,
      setting: summarizeSettingHint(input.completedScenes, input.remainingScenes),
      tone: inferToneFromText(input.userUpdate),
      episodeIntent: "continue the story from the next unfinished beat",
      episodeRecap: recap
    })
  };
}

export function evaluateStoryQuality(
  story: StoryScript,
  plan: StoryPlan,
  targetDurationSec: number,
  targetSceneCount: number
): StoryQualityReport {
  const issues: string[] = [];
  const totalDurationSec = story.scenes.reduce((sum, scene) => sum + scene.duration_sec, 0);

  if (story.scenes.length !== targetSceneCount) {
    issues.push(`Expected exactly ${targetSceneCount} scenes but got ${story.scenes.length}.`);
  }

  const durationDelta = Math.abs(totalDurationSec - targetDurationSec);
  if (durationDelta > Math.max(20, Math.round(targetDurationSec * 0.2))) {
    issues.push("Story pacing does not match the selected duration closely enough.");
  }

  if (story.scenes.length > 0) {
    const firstSceneRatio = story.scenes[0].duration_sec / Math.max(1, totalDurationSec);
    if (firstSceneRatio > 0.35) {
      issues.push("The opening scene is too long compared with the rest of the story.");
    }
  }

  const ending = story.scenes.at(-1)?.text.toLowerCase() ?? "";
  if (!/(smile|home|hug|cheer|happy|sleep|rest|celebrate|goodnight|thank)/.test(ending)) {
    issues.push("The ending does not land with a clear gentle resolution.");
  }

  const repeatedPhraseCount = countRepeatedPhrases(story.scenes);
  if (repeatedPhraseCount > 2) {
    issues.push("The story repeats itself too much.");
  }

  const fullText = story.scenes.map((scene) => scene.text).join(" ").toLowerCase();
  if (containsBannedTheme(fullText) || AGE_FIT_WARNING_WORDS.some((word) => fullText.includes(word))) {
    issues.push("The story may not be age-appropriate for young children.");
  }

  if (plan.episodeRecap && story.scenes.length > 0) {
    const recapKeywords = extractKeywords(plan.episodeRecap);
    if (recapKeywords.length > 0) {
      const overlap = recapKeywords.filter((word) => fullText.includes(word)).length;
      if (overlap === 0 && plan.seriesMemory.recurring_characters.length > 0) {
        issues.push("The story does not carry forward enough of the existing series memory.");
      }
    }
  }

  return {
    passed: issues.length === 0,
    issues,
    total_duration_sec: totalDurationSec,
    target_duration_sec: targetDurationSec,
    repeated_phrase_count: repeatedPhraseCount
  };
}

export function buildEngineMetadata(
  plan: StoryPlan,
  quality: StoryQualityReport
): StoryEngine {
  return {
    episode_recap: plan.episodeRecap,
    series_memory: plan.seriesMemory,
    character_bible: plan.characterBible,
    beat_plan: plan.beatPlan,
    continuity_facts: uniqueStrings([
      ...(plan.seriesMemory.world_facts ?? []),
      ...(plan.seriesMemory.relationship_facts ?? []),
      ...(plan.seriesMemory.favorite_places ?? []).map((place) => `Place: ${place}`),
      ...(plan.seriesMemory.open_loops ?? []).map((loop) => `Open loop: ${loop}`),
      ...(plan.seriesMemory.arc_summary ? [`Arc summary: ${plan.seriesMemory.arc_summary}`] : [])
    ]).slice(0, 24),
    quality
  };
}

function buildSeriesMemory(continuityFacts: string[], titleHint?: string): StorySeriesMemory {
  let title = titleHint;
  let priorEpisodeRecap: string | undefined;
  const recurringCharacters = new Set<string>();
  const worldFacts: string[] = [];
  const openLoops: string[] = [];
  const favoritePlaces: string[] = [];
  const relationshipFacts: string[] = [];
  let arcSummary: string | undefined;
  let nextEpisodeHook: string | undefined;

  for (const rawFact of continuityFacts) {
    const fact = rawFact.trim();
    if (!fact) {
      continue;
    }

    if (fact.toLowerCase().startsWith("series title:")) {
      title = cleanFactValue(fact);
      continue;
    }

    if (fact.toLowerCase().startsWith("characters:")) {
      for (const name of cleanFactValue(fact).split(",")) {
        const trimmed = name.trim();
        if (trimmed) {
          recurringCharacters.add(trimmed);
        }
      }
      continue;
    }

    if (fact.toLowerCase().startsWith("last episode context:")) {
      priorEpisodeRecap = clampSentence(cleanFactValue(fact), 320);
      continue;
    }

    if (fact.toLowerCase().startsWith("open loop:")) {
      openLoops.push(clampSentence(cleanFactValue(fact), 180));
      continue;
    }

    if (fact.toLowerCase().startsWith("place:")) {
      favoritePlaces.push(clampSentence(cleanFactValue(fact), 120));
      continue;
    }

    if (fact.toLowerCase().startsWith("relationship:")) {
      relationshipFacts.push(clampSentence(cleanFactValue(fact), 180));
      continue;
    }

    if (fact.toLowerCase().startsWith("arc summary:")) {
      arcSummary = clampSentence(cleanFactValue(fact), 240);
      continue;
    }

    if (fact.toLowerCase().startsWith("next episode hook:")) {
      nextEpisodeHook = clampSentence(cleanFactValue(fact), 180);
      continue;
    }

    worldFacts.push(clampSentence(fact, 180));
  }

  return {
    title,
    recurring_characters: Array.from(recurringCharacters).slice(0, 12),
    prior_episode_recap: priorEpisodeRecap,
    world_facts: worldFacts.slice(0, 20),
    open_loops: openLoops.slice(0, 12),
    favorite_places: uniqueStrings(favoritePlaces).slice(0, 12),
    relationship_facts: uniqueStrings(relationshipFacts).slice(0, 12),
    arc_summary: arcSummary,
    next_episode_hook: nextEpisodeHook
  };
}

function buildCharacterBible(
  requestedCharacters: string[],
  seriesMemory: StorySeriesMemory,
  tone: string
): StoryEngineCharacter[] {
  const names = uniqueStrings([...requestedCharacters, ...seriesMemory.recurring_characters]).slice(0, 12);
  const toneTraits = traitsForTone(tone);

  return names.map((name, index) => ({
    name,
    role: index === 0 ? "main story friend" : seriesMemory.recurring_characters.includes(name) ? "returning friend" : "supporting friend",
    traits: uniqueStrings(
      index === 0
        ? ["kind", "curious", ...toneTraits]
        : ["helpful", "warm", ...toneTraits]
    ).slice(0, 6)
  }));
}

function buildEpisodeRecap(seriesMemory: StorySeriesMemory): string | undefined {
  if (!seriesMemory.prior_episode_recap) {
    return undefined;
  }

  const titlePart = seriesMemory.title ? `In ${seriesMemory.title}, ` : "Last time, ";
  return clampSentence(`${titlePart}${seriesMemory.prior_episode_recap}`, 320);
}

function buildBeatPlan(input: {
  sceneCount: number;
  targetDurationSec: number;
  theme: string;
  setting: string;
  tone: string;
  episodeIntent?: string;
  episodeRecap?: string;
}): StoryBeat[] {
  const sceneCount = Math.max(1, Math.min(10, input.sceneCount));
  const labels = beatLabelsForCount(sceneCount);
  const durations = distributeDurations(input.targetDurationSec, sceneCount);

  return labels.map((label, index) => {
    const themeSnippet = clampSentence(input.theme, 80);
    const intentSnippet = clampSentence(
      input.episodeIntent ?? "a complete and happy standalone adventure",
      90
    );

    return {
      beat_id: `beat-${index + 1}`,
      scene_index: index,
      label,
      purpose: buildBeatPurpose({
        label,
        index,
        sceneCount,
        theme: themeSnippet,
        setting: input.setting,
        tone: input.tone,
        episodeIntent: intentSnippet,
        episodeRecap: input.episodeRecap
      }),
      target_duration_sec: durations[index]
    };
  });
}

function buildBeatPurpose(input: {
  label: string;
  index: number;
  sceneCount: number;
  theme: string;
  setting: string;
  tone: string;
  episodeIntent: string;
  episodeRecap?: string;
}): string {
  if (input.index === 0) {
    return clampSentence(
      `Open in ${input.setting} with a ${input.tone} tone and set up ${input.theme}.`,
      180
    );
  }

  if (input.index === input.sceneCount - 1) {
    return clampSentence(
      `Resolve the adventure gently and end with a warm payoff that fits ${input.episodeIntent}.`,
      180
    );
  }

  if (input.index === 1 && input.episodeRecap) {
    return clampSentence(
      `Carry forward the recap naturally and move into the next playful step of ${input.theme}.`,
      180
    );
  }

  return clampSentence(
    `${input.label} should move the story forward with clear action, simple language, and a ${input.tone} feeling.`,
    180
  );
}

function beatLabelsForCount(sceneCount: number): string[] {
  if (BEAT_LABELS[sceneCount]) {
    return BEAT_LABELS[sceneCount];
  }

  const labels = BEAT_LABELS[10];
  return labels.slice(0, sceneCount);
}

function distributeDurations(targetDurationSec: number, sceneCount: number): number[] {
  const weights = DURATION_WEIGHTS[sceneCount] ?? new Array(sceneCount).fill(1 / sceneCount);
  const rawDurations = weights.map((weight) => Math.max(10, Math.round(targetDurationSec * weight)));
  const delta = targetDurationSec - rawDurations.reduce((sum, value) => sum + value, 0);

  if (delta === 0) {
    return rawDurations;
  }

  rawDurations[rawDurations.length - 1] = Math.max(10, rawDurations.at(-1)! + delta);
  return rawDurations;
}

function countRepeatedPhrases(scenes: StoryScene[]): number {
  const seen = new Map<string, number>();

  for (const sentence of scenes.flatMap((scene) => splitIntoSentences(scene.text))) {
    const normalized = normalizePhrase(sentence);
    if (normalized.length < 18) {
      continue;
    }

    seen.set(normalized, (seen.get(normalized) ?? 0) + 1);
  }

  let repeated = 0;
  for (const count of seen.values()) {
    if (count > 1) {
      repeated += count - 1;
    }
  }

  return repeated;
}

function summarizeScenes(scenes: StoryScene[]): string | undefined {
  if (scenes.length === 0) {
    return undefined;
  }

  const pieces = scenes
    .slice(Math.max(0, scenes.length - 2))
    .map((scene) => clampSentence(scene.text.replace(/\s+/g, " "), 140));

  return clampSentence(pieces.join(" "), 320);
}

function summarizeSettingHint(completedScenes: StoryScene[], remainingScenes: StoryScene[]): string {
  const merged = [...completedScenes, ...remainingScenes].map((scene) => scene.text).join(" ");
  const candidates = ["park", "forest", "castle", "beach", "village", "cloud", "garden", "school", "spaceship"];
  return candidates.find((candidate) => merged.toLowerCase().includes(candidate)) ?? "a friendly story world";
}

function inferToneFromText(text: string): string {
  const lower = text.toLowerCase();
  if (lower.includes("funny") || lower.includes("silly")) {
    return "playful and funny";
  }
  if (lower.includes("brave")) {
    return "brave and hopeful";
  }
  if (lower.includes("sleep") || lower.includes("calm") || lower.includes("quiet")) {
    return "calm and cozy";
  }
  if (lower.includes("magic") || lower.includes("sparkle")) {
    return "magical and gentle";
  }
  return "gentle and playful";
}

function traitsForTone(tone: string): string[] {
  const lower = tone.toLowerCase();
  if (lower.includes("funny") || lower.includes("silly")) {
    return ["playful", "cheerful"];
  }
  if (lower.includes("brave")) {
    return ["brave", "steady"];
  }
  if (lower.includes("sleep") || lower.includes("calm") || lower.includes("cozy")) {
    return ["calm", "gentle"];
  }
  if (lower.includes("magic")) {
    return ["wonder-filled", "gentle"];
  }
  return ["warm", "helpful"];
}

function extractCharactersFromScenes(scenes: StoryScene[]): string[] {
  const names = new Set<string>();
  const capitalized = scenes
    .map((scene) => scene.text.match(/\b[A-Z][a-z]{2,}\b/g) ?? [])
    .flat();

  for (const token of capitalized) {
    if (!["Once", "Then", "After", "When", "Because"].includes(token)) {
      names.add(token);
    }
  }

  return Array.from(names).slice(0, 12);
}

function extractKeywords(text: string): string[] {
  return uniqueStrings(
    text
      .toLowerCase()
      .split(/[^a-z]+/)
      .filter((word) => word.length >= 5 && !["there", "their", "about", "story", "time"].includes(word))
  ).slice(0, 8);
}

function splitIntoSentences(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
}

function normalizePhrase(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9\s]+/g, "").replace(/\s+/g, " ").trim();
}

function cleanFactValue(fact: string): string {
  const parts = fact.split(":");
  return clampSentence(parts.slice(1).join(":").trim(), 320);
}

function clampSentence(text: string, maxLength: number): string {
  return text.trim().slice(0, maxLength).trim();
}

function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const value of values) {
    const trimmed = value.trim();
    if (!trimmed) {
      continue;
    }
    const key = trimmed.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(trimmed);
  }

  return result;
}
