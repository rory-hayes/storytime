import { z } from "zod";

export function looksLikeSdp(value: string): boolean {
  return value.startsWith("v=0") && /\r?\nm=/.test(value) && value.includes("a=fingerprint:");
}

export const AgeBandSchema = z.literal("3-8");

export const StoryBriefSchema = z.object({
  theme: z.string().trim().min(1).max(200),
  characters: z.array(z.string().trim().min(1).max(80)).min(1).max(6),
  setting: z.string().trim().min(1).max(160),
  tone: z.string().trim().min(1).max(80),
  episode_intent: z.string().trim().min(1).max(200).optional(),
  lesson: z.string().trim().min(1).max(200).optional()
});

export const StorySceneSchema = z.object({
  scene_id: z.string().trim().min(1).max(64),
  text: z.string().trim().min(1),
  duration_sec: z.number().int().min(10).max(180)
});

export const StoryEngineCharacterSchema = z.object({
  name: z.string().trim().min(1).max(80),
  role: z.string().trim().min(1).max(120),
  traits: z.array(z.string().trim().min(1).max(40)).max(6).default([])
});

export const StorySeriesMemorySchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
  recurring_characters: z.array(z.string().trim().min(1).max(80)).max(12).default([]),
  prior_episode_recap: z.string().trim().min(1).max(400).optional(),
  world_facts: z.array(z.string().trim().min(1).max(200)).max(20).default([]),
  open_loops: z.array(z.string().trim().min(1).max(200)).max(12).default([]),
  favorite_places: z.array(z.string().trim().min(1).max(120)).max(12).default([]),
  relationship_facts: z.array(z.string().trim().min(1).max(200)).max(12).default([]),
  arc_summary: z.string().trim().min(1).max(240).optional(),
  next_episode_hook: z.string().trim().min(1).max(200).optional()
});

export const StoryBeatSchema = z.object({
  beat_id: z.string().trim().min(1).max(64),
  scene_index: z.number().int().min(0).max(19),
  label: z.string().trim().min(1).max(80),
  purpose: z.string().trim().min(1).max(200),
  target_duration_sec: z.number().int().min(10).max(180)
});

export const StoryQualityReportSchema = z.object({
  passed: z.boolean(),
  issues: z.array(z.string().trim().min(1).max(200)).max(20).default([]),
  total_duration_sec: z.number().int().min(0).max(3600),
  target_duration_sec: z.number().int().min(60).max(3600),
  repeated_phrase_count: z.number().int().min(0).max(100)
});

export const StoryEngineSchema = z.object({
  episode_recap: z.string().trim().min(1).max(400).optional(),
  series_memory: StorySeriesMemorySchema,
  character_bible: z.array(StoryEngineCharacterSchema).max(12).default([]),
  beat_plan: z.array(StoryBeatSchema).min(1).max(20),
  continuity_facts: z.array(z.string().trim().min(1).max(200)).max(24).default([]),
  quality: StoryQualityReportSchema.optional()
});

export const StoryScriptSchema = z.object({
  title: z.string().trim().min(1).max(120),
  scenes: z.array(StorySceneSchema).min(1).max(20)
});

export type StoryScript = z.infer<typeof StoryScriptSchema>;
export type StoryScene = z.infer<typeof StorySceneSchema>;

export const GenerateStoryRequestSchema = z.object({
  child_profile_id: z.string().uuid(),
  age_band: AgeBandSchema.default("3-8"),
  language: z.literal("en").default("en"),
  length_minutes: z.number().int().min(1).max(10),
  voice: z.string().trim().min(1).max(32),
  question_count: z.number().int().min(0).max(3),
  story_brief: StoryBriefSchema,
  continuity_facts: z.array(z.string().trim().min(1).max(260)).max(40).default([])
});

export type GenerateStoryRequest = z.infer<typeof GenerateStoryRequestSchema>;

export const StorySafetySchema = z.object({
  input_moderation: z.enum(["pass", "flagged"]),
  output_moderation: z.enum(["pass", "flagged"])
});

export const GenerateStoryResponseSchema = z.object({
  story_id: z.string().uuid(),
  title: z.string(),
  estimated_duration_sec: z.number().int().min(60).max(3600),
  scenes: z.array(StorySceneSchema),
  safety: StorySafetySchema,
  engine: StoryEngineSchema.optional()
});

export type GenerateStoryResponse = z.infer<typeof GenerateStoryResponseSchema>;

export const ReviseStoryRequestSchema = z.object({
  story_id: z.string().uuid(),
  current_scene_index: z.number().int().min(0),
  story_title: z.string().trim().min(1).max(120).optional(),
  user_update: z.string().trim().min(1).max(800),
  completed_scenes: z.array(StorySceneSchema).max(20).default([]),
  remaining_scenes: z.array(StorySceneSchema).min(1).max(20)
});

export type ReviseStoryRequest = z.infer<typeof ReviseStoryRequestSchema>;

export const ReviseStoryResponseSchema = z.object({
  story_id: z.string().uuid(),
  revised_from_scene_index: z.number().int().min(0),
  scenes: z.array(StorySceneSchema).min(1),
  safety: StorySafetySchema,
  engine: StoryEngineSchema.optional()
});

export type ReviseStoryResponse = z.infer<typeof ReviseStoryResponseSchema>;

export const ModerationCheckRequestSchema = z.object({
  text: z.string().trim().min(1).max(5000)
});

export const EmbeddingsCreateRequestSchema = z.object({
  inputs: z.array(z.string().trim().min(1).max(1000)).min(1).max(128)
});

export const RealtimeSessionRequestSchema = z.object({
  child_profile_id: z.string().uuid(),
  voice: z.string().trim().min(1).max(32),
  region: z.enum(["US", "EU"]).default("US")
});

export type RealtimeSessionRequest = z.infer<typeof RealtimeSessionRequestSchema>;

export const RealtimeCallRequestSchema = z.object({
  ticket: z.string().trim().min(20).max(4_096),
  // Preserve the SDP byte-for-byte. Trimming trailing CRLF makes valid offers invalid.
  sdp: z.string().min(20).max(200_000).refine(looksLikeSdp, {
    message: "Invalid SDP offer"
  })
});

export type RealtimeCallRequest = z.infer<typeof RealtimeCallRequestSchema>;

export const RealtimeCallResponseSchema = z.object({
  answer_sdp: z.string().min(20).max(200_000).refine(looksLikeSdp, {
    message: "Invalid SDP answer"
  })
});

export const DiscoverySlotStateSchema = z.object({
  theme: z.string().trim().min(1).max(200).optional(),
  characters: z.array(z.string().trim().min(1).max(80)).max(6).optional(),
  setting: z.string().trim().min(1).max(160).optional(),
  tone: z.string().trim().min(1).max(80).optional(),
  episode_intent: z.string().trim().min(1).max(200).optional()
});

export type DiscoverySlotState = z.infer<typeof DiscoverySlotStateSchema>;

export const DiscoveryRequestSchema = z.object({
  child_profile_id: z.string().uuid(),
  transcript: z.string().trim().min(1).max(800),
  question_count: z.number().int().min(0).max(3),
  slot_state: DiscoverySlotStateSchema.default({}),
  mode: z.enum(["new", "extend"]).default("new"),
  previous_episode_recap: z.string().trim().max(400).optional()
});

export type DiscoveryRequest = z.infer<typeof DiscoveryRequestSchema>;

export type ModerationVerdict = {
  flagged: boolean;
  categories: string[];
};

export type GeneratedStoryPayload = {
  title: string;
  scenes: Array<{ scene_id: string; text: string; duration_sec: number }>;
};

export type StoryEngineCharacter = z.infer<typeof StoryEngineCharacterSchema>;
export type StorySeriesMemory = z.infer<typeof StorySeriesMemorySchema>;
export type StoryBeat = z.infer<typeof StoryBeatSchema>;
export type StoryQualityReport = z.infer<typeof StoryQualityReportSchema>;
export type StoryEngine = z.infer<typeof StoryEngineSchema>;

export type RealtimeSessionTicket = {
  ticket: string;
  expires_at: number;
  model: string;
  voice: string;
  input_audio_transcription_model: string;
};

export type RealtimeCallResult = {
  answer_sdp: string;
};

export type DiscoveryResult = {
  blocked: boolean;
  safe_message?: string;
  data: {
    slot_state: {
      theme?: string;
      characters: string[];
      setting?: string;
      tone?: string;
      episode_intent?: string;
    };
    question_count: number;
    ready_to_generate: boolean;
    assistant_message: string;
    transcript: string;
  };
};
