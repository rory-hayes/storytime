import type { Env } from "../lib/env.js";
import { SlidingWindowRateLimiter } from "../lib/rateLimiter.js";
import { AppError } from "../lib/errors.js";
import { createRealtimeTicket, verifyRealtimeTicket } from "../lib/security.js";
import type { RequestContext } from "../lib/requestContext.js";
import { withRetry } from "../lib/retry.js";
import { analytics } from "../lib/analytics.js";
import { logLifecycle } from "../lib/lifecycle.js";
import { looksLikeSdp } from "../types.js";
import type {
  RealtimeCallRequest,
  RealtimeCallResult,
  RealtimeSessionRequest,
  RealtimeSessionTicket
} from "../types.js";

export class RealtimeService {
  private readonly limiter: SlidingWindowRateLimiter;

  constructor(private readonly env: Env) {
    this.limiter = new SlidingWindowRateLimiter(
      env.REALTIME_RATE_LIMIT_MAX,
      env.REALTIME_RATE_LIMIT_WINDOW_MS,
      "rate_limited",
      "Realtime rate limit exceeded"
    );
  }

  issueSessionTicket(request: RealtimeSessionRequest, context: RequestContext): RealtimeSessionTicket {
    const startedAt = Date.now();
    logLifecycle(context, {
      component: "realtime",
      action: "session_ticket",
      phase: "started",
      details: {
        voice: request.voice
      }
    });

    try {
      this.enforceRateLimit(context, "ticket");

      const ticket = createRealtimeTicket(
        {
          child_profile_id: request.child_profile_id,
          voice: request.voice,
          region: request.region,
          install_id: context.installId
        },
        this.env
      );

      this.recordSecurityEvent(context, "realtime_ticket_issued");
      logLifecycle(context, {
        component: "realtime",
        action: "session_ticket",
        phase: "completed",
        details: {
          voice: request.voice
        },
        durationMs: Date.now() - startedAt
      });

      return {
        ticket: ticket.ticket,
        expires_at: ticket.expires_at,
        model: this.env.OPENAI_REALTIME_MODEL,
        voice: request.voice,
        input_audio_transcription_model: this.env.OPENAI_REALTIME_TRANSCRIPTION_MODEL
      };
    } catch (error) {
      logLifecycle(context, {
        component: "realtime",
        action: "session_ticket",
        phase: "failed",
        details: {
          voice: request.voice
        },
        durationMs: Date.now() - startedAt,
        error
      });
      throw error;
    }
  }

  async createCall(request: RealtimeCallRequest, context: RequestContext): Promise<RealtimeCallResult> {
    const startedAt = Date.now();
    let attempts = 1;
    logLifecycle(context, {
      component: "realtime",
      action: "call_proxy",
      phase: "started",
      details: {
        offer_bytes: request.sdp.length
      }
    });

    try {
      this.enforceRateLimit(context, "call");
      const ticket = verifyRealtimeTicket(request.ticket, context.installId, this.env);
      const { result, attempts: usedAttempts } = await withRetry(
        () => this.fetchOpenAIAnswerSdp(ticket.voice, request.sdp),
        {
          retries: this.env.OPENAI_MAX_RETRIES,
          baseDelayMs: this.env.OPENAI_RETRY_BASE_MS,
          onRetry: (error, attempt, nextDelayMs) => {
            logLifecycle(context, {
              component: "realtime",
              action: "call_proxy",
              phase: "retrying",
              details: {
                retry_attempt: attempt,
                retry_in_ms: nextDelayMs,
                retry_source: "openai",
                voice: ticket.voice
              },
              error
            });
          }
        }
      );
      attempts = usedAttempts;
      this.recordUsage(context, attempts, Date.now() - startedAt, true);
      logLifecycle(context, {
        component: "realtime",
        action: "call_proxy",
        phase: "completed",
        details: {
          voice: ticket.voice,
          offer_bytes: request.sdp.length
        },
        attempts,
        durationMs: Date.now() - startedAt
      });
      return { answer_sdp: result };
    } catch (error) {
      this.recordUsage(context, attempts, Date.now() - startedAt, false);
      logLifecycle(context, {
        component: "realtime",
        action: "call_proxy",
        phase: "failed",
        details: {
          offer_bytes: request.sdp.length
        },
        attempts,
        durationMs: Date.now() - startedAt,
        error
      });
      throw error;
    }
  }

  private async fetchOpenAIAnswerSdp(voice: string, sdp: string): Promise<string> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.env.OPENAI_TIMEOUT_MS);

    try {
      const openAIResponse = await fetch("https://api.openai.com/v1/realtime/calls", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.env.OPENAI_API_KEY}`
        },
        body: createMultipartFormData(
          {
            type: "realtime",
            model: this.env.OPENAI_REALTIME_MODEL,
            instructions:
              "You are the secure realtime transport for StoryTime. Do not answer automatically. Wait for explicit response.create events from the client.",
            audio: {
              output: {
                voice
              },
              input: {
                turn_detection: {
                  type: "server_vad",
                  create_response: false,
                  interrupt_response: true
                },
                transcription: {
                  model: this.env.OPENAI_REALTIME_TRANSCRIPTION_MODEL
                }
              }
            }
          },
          sdp
        ),
        signal: controller.signal
      });

      if (!openAIResponse.ok) {
        const body = await openAIResponse.text();
        throw new AppError(`Realtime call creation failed (${openAIResponse.status})`, 502, "realtime_call_failed", {
          status: openAIResponse.status,
          body
        }, {
          publicMessage: "Unable to start the live story session right now.",
          exposeDetails: false,
          publicDetails: { status: openAIResponse.status }
        });
      }

      const answerSdp = await openAIResponse.text();
      if (!looksLikeSdp(answerSdp)) {
        throw new AppError("Realtime call returned an invalid SDP answer", 502, "invalid_realtime_answer", {
          answer_length: answerSdp.length
        }, {
          publicMessage: "Unable to start the live story session right now.",
          exposeDetails: false
        });
      }

      return answerSdp;
    } finally {
      clearTimeout(timeout);
    }
  }

  private enforceRateLimit(context: RequestContext, scope: string) {
    this.limiter.check(`${scope}:${context.installHash}:${context.ip}`);
  }

  private recordUsage(context: RequestContext, attempts: number, durationMs: number, success: boolean) {
    if (!this.env.ENABLE_STRUCTURED_ANALYTICS && !this.env.ENABLE_USAGE_METERING) {
      return;
    }

    analytics.recordOpenAI({
      requestId: context.requestId,
      route: context.route,
      operation: "realtime.call",
      runtimeStage: "interaction",
      provider: "openai",
      model: this.env.OPENAI_REALTIME_MODEL,
      region: context.region,
      installHash: context.installHash,
      sessionId: context.sessionId,
      attempts,
      durationMs,
      success
    });
  }

  private recordSecurityEvent(context: RequestContext, event: string) {
    if (!this.env.ENABLE_STRUCTURED_ANALYTICS && !this.env.ENABLE_USAGE_METERING) {
      return;
    }

    analytics.recordSecurity({
      requestId: context.requestId,
      route: context.route,
      event,
      region: context.region,
      installHash: context.installHash,
      authLevel: context.authLevel
    });
  }
}

function createMultipartFormData(session: Record<string, unknown>, sdp: string) {
  const form = new FormData();
  // OpenAI's /v1/realtime/calls endpoint expects text multipart fields for both
  // "sdp" and "session". Sending the SDP as a file/blob part causes the field
  // to be ignored and the request is rejected as invalid_form_data.
  form.set("sdp", sdp);
  form.set("session", JSON.stringify(session));
  return form;
}
