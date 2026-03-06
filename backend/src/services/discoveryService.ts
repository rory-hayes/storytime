import type { GenerateStoryRequest } from "../types.js";

export type StorySlotValues = {
  theme?: string;
  setting?: string;
  tone?: string;
  characters?: string[];
  episodeIntent?: string;
  lesson?: string;
};

const DEFAULTS: Required<StorySlotValues> = {
  theme: "friendship adventure",
  setting: "a bright forest village",
  tone: "gentle and playful",
  characters: ["a brave bunny", "a kind fox"],
  episodeIntent: "a complete and happy standalone adventure",
  lesson: "kindness and teamwork"
};

export function enforceFollowUpCap(questionCount: number): number {
  return Math.max(0, Math.min(3, Math.floor(questionCount)));
}

export function fillMissingSlots(slots: StorySlotValues): Required<StorySlotValues> {
  return {
    theme: slots.theme?.trim() || DEFAULTS.theme,
    setting: slots.setting?.trim() || DEFAULTS.setting,
    tone: slots.tone?.trim() || DEFAULTS.tone,
    characters: slots.characters?.length ? slots.characters : DEFAULTS.characters,
    episodeIntent: slots.episodeIntent?.trim() || DEFAULTS.episodeIntent,
    lesson: slots.lesson?.trim() || DEFAULTS.lesson
  };
}

export function normalizeGenerateRequest(request: GenerateStoryRequest): GenerateStoryRequest {
  const safeQuestionCount = enforceFollowUpCap(request.question_count);
  const safeSlots = fillMissingSlots({
    theme: request.story_brief.theme,
    setting: request.story_brief.setting,
    tone: request.story_brief.tone,
    characters: request.story_brief.characters,
    episodeIntent: request.story_brief.episode_intent,
    lesson: request.story_brief.lesson
  });

  return {
    ...request,
    question_count: safeQuestionCount,
    story_brief: {
      theme: safeSlots.theme,
      characters: safeSlots.characters,
      setting: safeSlots.setting,
      tone: safeSlots.tone,
      episode_intent: safeSlots.episodeIntent,
      lesson: safeSlots.lesson
    }
  };
}
