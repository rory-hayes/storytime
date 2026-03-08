import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import { analytics } from "../lib/analytics.js";
import { EmbeddingsService } from "../services/embeddingsService.js";
import { ModerationService } from "../services/moderationService.js";
import { RealtimeService } from "../services/realtimeService.js";
import { makeCapturedLogger, makeRequestContext, makeTestEnv } from "./testHelpers.js";

const validOfferSdp =
  "v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\ns=StoryTime\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=fingerprint:sha-256 offer-test\r\n";
const validAnswerSdp =
  "v=0\r\no=- 2 2 IN IP4 127.0.0.1\r\ns=StoryTime\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\na=fingerprint:sha-256 answer-test\r\n";

describe("model-adjacent services", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("extracts moderation verdicts and supports bulk moderation", async () => {
    const openai = {
      moderations: {
        create: vi.fn().mockResolvedValue({
          results: [
            {
              flagged: true,
              categories: {
                violence: true,
                hate: false,
                self_harm: true
              }
            }
          ]
        })
      }
    } as any;
    const service = new ModerationService(openai, makeTestEnv());

    await expect(service.moderateText("unsafe", makeRequestContext())).resolves.toEqual({
      flagged: true,
      categories: ["violence", "self_harm"]
    });
    await expect(service.moderateManyText(["unsafe", "content"], makeRequestContext())).resolves.toEqual({
      flagged: true,
      categories: ["violence", "self_harm"]
    });
  });

  it("returns embeddings and propagates embedding failures", async () => {
    const openai = {
      embeddings: {
        create: vi
          .fn()
          .mockResolvedValueOnce({ data: [{ embedding: [0.1, 0.2] }, { embedding: [0.3, 0.4] }] })
          .mockRejectedValueOnce(new Error("embedding failed"))
      }
    } as any;
    const service = new EmbeddingsService(openai, makeTestEnv());

    await expect(service.createEmbeddings(["a", "b"], makeRequestContext())).resolves.toEqual([
      [0.1, 0.2],
      [0.3, 0.4]
    ]);
    await expect(service.createEmbeddings(["c"], makeRequestContext())).rejects.toThrow("embedding failed");
  });

  it("issues realtime tickets and proxies call setup with retries", async () => {
    const env = makeTestEnv({ OPENAI_MAX_RETRIES: 1, OPENAI_RETRY_BASE_MS: 0, OPENAI_TIMEOUT_MS: 50 });
    const service = new RealtimeService(env);
    const context = makeRequestContext();
    const before = analytics.snapshot();
    const ticket = service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 500, text: async () => "upstream failed" })
      .mockResolvedValueOnce({ ok: true, text: async () => validAnswerSdp });
    vi.stubGlobal("fetch", fetchMock);
    vi.spyOn(Math, "random").mockReturnValue(0);

    const result = await service.createCall(
      {
        ticket: ticket.ticket,
        sdp: validOfferSdp
      },
      context
    );

    expect(result.answer_sdp).toBe(validAnswerSdp);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    const after = analytics.snapshot();
    expect((after["openai_stage:interaction:success"] ?? 0) - (before["openai_stage:interaction:success"] ?? 0)).toBe(1);
    expect((after["openai_stage_group:interaction:success"] ?? 0) - (before["openai_stage_group:interaction:success"] ?? 0)).toBe(1);
  });

  it("forwards realtime calls to OpenAI with text multipart sdp and session fields", async () => {
    const env = makeTestEnv();
    const service = new RealtimeService(env);
    const context = makeRequestContext();
    const ticket = service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    let capturedBody: FormData | undefined;
    const fetchMock = vi.fn().mockImplementation(async (_url, init) => {
      capturedBody = init?.body as FormData;
      return { ok: true, text: async () => validAnswerSdp };
    });
    vi.stubGlobal("fetch", fetchMock);

    await service.createCall(
      {
        ticket: ticket.ticket,
        sdp: validOfferSdp
      },
      context
    );

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(capturedBody).toBeInstanceOf(FormData);
    expect(capturedBody?.get("sdp")).toBe(validOfferSdp);

    const sessionField = capturedBody?.get("session");
    expect(typeof sessionField).toBe("string");
    expect(JSON.parse(String(sessionField))).toMatchObject({
      type: "realtime",
      model: "gpt-realtime",
      audio: {
        output: {
          voice: "alloy"
        }
      }
    });
  });

  it("rejects invalid SDP answers from the realtime upstream", async () => {
    const env = makeTestEnv();
    const service = new RealtimeService(env);
    const context = makeRequestContext();
    const ticket = service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
      ok: true,
      text: async () => "not-sdp"
    }));

    await expect(
      service.createCall(
        {
          ticket: ticket.ticket,
          sdp: validOfferSdp
        },
        context
      )
    ).rejects.toMatchObject({ code: "invalid_realtime_answer" });
  });

  it("returns a safe realtime_call_failed error when the upstream rejects the offer", async () => {
    const env = makeTestEnv({ OPENAI_MAX_RETRIES: 0 });
    const service = new RealtimeService(env);
    const context = makeRequestContext();
    const ticket = service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
      ok: false,
      status: 502,
      text: async () => "upstream failed"
    }));

    await expect(
      service.createCall(
        {
          ticket: ticket.ticket,
          sdp: validOfferSdp
        },
        context
      )
    ).rejects.toMatchObject({
      code: "realtime_call_failed",
      status: 502,
      publicMessage: "Unable to start the live story session right now."
    });
  });

  it("logs realtime lifecycle start retry and completion without SDP or upstream body text", async () => {
    const env = makeTestEnv({ OPENAI_MAX_RETRIES: 1, OPENAI_RETRY_BASE_MS: 0, OPENAI_TIMEOUT_MS: 50 });
    const service = new RealtimeService(env);
    const captured = makeCapturedLogger();
    const context = makeRequestContext({ logger: captured.logger });
    const ticket = service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    vi.spyOn(Math, "random").mockReturnValue(0);
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValueOnce({ ok: false, status: 503, text: async () => "upstream failed body" })
        .mockResolvedValueOnce({ ok: true, text: async () => validAnswerSdp })
    );

    const result = await service.createCall(
      {
        ticket: ticket.ticket,
        sdp: validOfferSdp
      },
      context
    );

    expect(result.answer_sdp).toBe(validAnswerSdp);
    const lifecycleEntries = captured.entries.filter((entry) => entry.bindings.event_type === "lifecycle_event");
    expect(
      lifecycleEntries.map((entry) => `${entry.bindings.component}.${entry.bindings.action}.${entry.bindings.status}`)
    ).toEqual(
      expect.arrayContaining([
        "realtime.session_ticket.started",
        "realtime.session_ticket.completed",
        "realtime.call_proxy.started",
        "realtime.call_proxy.retrying",
        "realtime.call_proxy.completed"
      ])
    );
    const retryEntry = lifecycleEntries.find(
      (entry) => entry.bindings.component === "realtime" && entry.bindings.action === "call_proxy" && entry.bindings.status === "retrying"
    );
    expect(retryEntry?.bindings.retry_source).toBe("openai");
    expect(retryEntry?.bindings.retry_in_ms).toBeTypeOf("number");

    const serializedLogs = JSON.stringify(lifecycleEntries);
    expect(serializedLogs).not.toContain(validOfferSdp);
    expect(serializedLogs).not.toContain(validAnswerSdp);
    expect(serializedLogs).not.toContain("upstream failed body");
  });

  it("rejects invalid realtime tickets and enforces service rate limits", async () => {
    const env = makeTestEnv({ REALTIME_RATE_LIMIT_MAX: 1 });
    const service = new RealtimeService(env);
    const context = makeRequestContext();

    service.issueSessionTicket(
      {
        child_profile_id: "11111111-1111-1111-1111-111111111111",
        voice: "alloy",
        region: "US"
      },
      context
    );

    expect(() =>
      service.issueSessionTicket(
        {
          child_profile_id: "11111111-1111-1111-1111-111111111111",
          voice: "alloy",
          region: "US"
        },
        context
      )
    ).toThrowError(expect.objectContaining({ code: "rate_limited" }));

    await expect(
      service.createCall(
        {
          ticket: "bad-ticket",
          sdp: "v=0\r\no=- 1 1 IN IP4 127.0.0.1\r\ns=StoryTime\r\n"
        },
        context
      )
    ).rejects.toMatchObject({ code: "invalid_realtime_ticket" });
  });
});
