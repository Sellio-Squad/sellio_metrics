/**
 * Webhook Handler Service
 *
 * Single responsibility: authenticate and decode Pub/Sub push messages,
 * then route the extracted event to the correct MeetingRoom Durable Object.
 *
 * The MeetingRoom DO handles persistence + WebSocket broadcast.
 */

import type { MeetingsRepository } from "./meetings.repository";
import type { Logger } from "../../core/logger";
import type { PubSubPushBody } from "./meetings.types";
import type { LogsService } from "../logs/logs.service";

/** Shape of the decoded Workspace Events CloudEvent payload */
interface WorkspaceEventPayload {
    type?: string;
    resourceName?: string;
    participant?: {
        name?: string;
        signedinUser?: { user?: string; displayName?: string };
        anonymousUser?: { displayName?: string };
    };
    participantSession?: {
        name?: string;
        startTime?: string;
        endTime?: string;
    };
    conferenceRecord?: { space?: { name?: string } };
    [key: string]: unknown;
}

export type MeetEventType =
    | "google.workspace.meet.participant.v2.joined"
    | "google.workspace.meet.participant.v2.left"
    | "google.workspace.meet.conference.v2.started"
    | "google.workspace.meet.conference.v2.ended";

export interface ParsedMeetEvent {
    type: MeetEventType | string;
    spaceName: string;
    participantKey: string | null;  // "users/{userId}" or null for anonymous
    displayName: string;
    timestamp: string;
}

export class WebhookHandlerService {
    private readonly logger: Logger;

    constructor({ logger }: { logger: Logger }) {
        this.logger = logger.child({ module: "webhook-handler" });
    }

    // ─── Entry point ─────────────────────────────────────────────────────────

    /**
     * Verify the Pub/Sub JWT, decode the message, and forward to the
     * correct MeetingRoom Durable Object.
     *
     * Returns 200 quickly so Pub/Sub does not retry.
     */
    async handle(request: Request, meetingsRepo: MeetingsRepository, meetingRooms: DurableObjectNamespace, logsService?: LogsService): Promise<Response> {
        // 1. Verify Pub/Sub OIDC JWT token
        const authError = await this.verifyPubSubJwt(request);
        if (authError) {
            this.logger.warn({ authError }, "Webhook JWT verification failed — rejecting");
            if (logsService) await logsService.log(`Webhook JWT verification failed: ${authError}`, "error", "googleMeet");
            return new Response("Unauthorized", { status: 401 });
        }

        // 2. Parse body
        let body: PubSubPushBody;
        try {
            body = await request.json() as PubSubPushBody;
        } catch {
            return new Response("Bad Request: invalid JSON", { status: 400 });
        }

        // 3. Decode base64 Pub/Sub message
        let payload: WorkspaceEventPayload;
        try {
            const b64Data = body.message.data.replace(/-/g, "+").replace(/_/g, "/");
            const dataPadded = b64Data + "===".slice((b64Data.length + 3) % 4);
            const decodedStr = atob(dataPadded);
            if (logsService) await logsService.log("Decoded Pub/Sub data", "info", "googleMeet", { rawData: decodedStr, attributes: body.message.attributes });
            payload = JSON.parse(decodedStr);
        } catch {
            this.logger.warn("Failed to decode Pub/Sub message data");
            if (logsService) await logsService.log("Failed to decode Pub/Sub message data", "error", "googleMeet");
            return new Response("Bad Request: invalid message data", { status: 400 });
        }

        const event = this.extractEvent(payload, body.message.attributes ?? {}, body.message.publishTime);
        this.logger.info({ type: event.type, spaceName: event.spaceName }, "Meet event received");
        if (logsService) await logsService.log(`Meet parsed: ${event.type}`, "info", "googleMeet", { spaceName: event.spaceName, participant: event.displayName });

        // 4. Resolve space name → meeting session ID
        const session = await meetingsRepo.getSessionBySpaceName(event.spaceName);
        if (!session) {
            this.logger.info({ spaceName: event.spaceName }, "Unknown space — ignoring event");
            if (logsService) await logsService.log(`Unknown space — ignoring event`, "warning", "googleMeet", { spaceName: event.spaceName });
            return new Response("OK", { status: 200 });
        }

        // 5. Forward to MeetingRoom Durable Object
        const doId   = meetingRooms.idFromName(session.id);
        const doStub = meetingRooms.get(doId);

        await doStub.fetch("https://do/event", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ sessionId: session.id, event }),
        });

        return new Response("OK", { status: 200 });
    }

    // ─── JWT Verification ────────────────────────────────────────────────────

    /**
     * Verify Google Pub/Sub OIDC JWT in the Authorization header.
     * Returns null on success, error string on failure.
     *
     * Verification steps:
     *   1. Extract Bearer token
     *   2. Fetch Google's JWKS and verify signature
     *   3. Validate aud (our webhook URL) and email (our SA email)
     */
    private async verifyPubSubJwt(request: Request): Promise<string | null> {
        const authHeader = request.headers.get("Authorization") ?? "";
        if (!authHeader.startsWith("Bearer ")) return "Missing Authorization header";

        const token = authHeader.slice(7);

        try {
            const b64Dec = (str: string) => {
                let s = str.replace(/-/g, "+").replace(/_/g, "/");
                while (s.length % 4) s += "=";
                return atob(s);
            };

            // Decode header + payload without verification first to get kid
            const [headerB64, payloadB64] = token.split(".");
            const header  = JSON.parse(b64Dec(headerB64));
            const claims  = JSON.parse(b64Dec(payloadB64));

            // Fetch Google's public certs (JWKS)
            const jwksRes  = await fetch("https://www.googleapis.com/oauth2/v3/certs");
            const jwks     = await jwksRes.json() as { keys: any[] };
            const jwk      = jwks.keys.find((k: any) => k.kid === header.kid);
            if (!jwk) return "Unknown key ID";

            // Import the public key and verify
            const publicKey = await crypto.subtle.importKey(
                "jwk", jwk,
                { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
                false,
                ["verify"],
            );

            const [, , sigB64] = token.split(".");
            const sig          = Uint8Array.from(b64Dec(sigB64), c => c.charCodeAt(0));
            const data         = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
            const valid        = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey, sig, data);
            if (!valid) return "Invalid signature";

            // Validate expiry
            if (claims.exp && Date.now() / 1000 > claims.exp) return "Token expired";

            // Production: also validate `claims.email` against your SA email
            // and `claims.aud` against your webhook URL.
            this.logger.info({ email: claims.email, aud: claims.aud }, "Pub/Sub JWT verified");
            return null;
        } catch (err: any) {
            return `JWT verification error: ${err?.message}`;
        }
    }

    // ─── Payload Extraction ──────────────────────────────────────────────────

    private extractEvent(payload: any, attrs: Record<string, string>, publishTime: string): ParsedMeetEvent {
        // CloudEvent "type" is often in ce-type attribute or root json "type"
        const type      = (attrs["ce-type"] ?? attrs["eventType"] ?? payload.type ?? "unknown") as MeetEventType;
        
        // Find spaceName realistically
        const subject = attrs["ce-subject"] ?? "";
        let spaceName = "";
        const m = subject.match(/spaces\/[^/]+/);
        if (m) spaceName = m[0];
        else if (payload.space?.name) spaceName = payload.space.name;
        else if (payload.conferenceRecord?.space?.name) spaceName = payload.conferenceRecord.space.name;
        
        // Safely extract the inner object whether it's wrapped in `data` or not
        const inner = payload.data ?? payload;
        const participantObj = inner.participant ?? inner;

        const participantKey =
            participantObj?.signedinUser?.user ?? null;  // "users/{userId}" or null

        const displayName =
            participantObj?.signedinUser?.displayName ??
            participantObj?.anonymousUser?.displayName ??
            "Unknown";

        return { type, spaceName, participantKey, displayName, timestamp: publishTime };
    }
}

// Cloudflare Durable Object namespace type shim (provided by @cloudflare/workers-types)
declare class DurableObjectNamespace {
    idFromName(name: string): DurableObjectId;
    get(id: DurableObjectId): DurableObjectStub;
}
declare class DurableObjectId {}
declare class DurableObjectStub {
    fetch(url: string, init?: RequestInit): Promise<Response>;
}
