/**
 * Meetings Module — Route (Controller)
 *
 * HTTP layer only: validates params, calls service, shapes response.
 * No business logic, no data transformation.
 *
 * Endpoints:
 *   POST  /api/meetings              → create meeting
 *   GET   /api/meetings              → list meetings
 *   GET   /api/meetings/analytics    → aggregated analytics
 *   GET   /api/meetings/rate-limit   → Google API rate limit status
 *   GET   /api/meetings/:id          → meeting detail + participants
 *   GET   /api/meetings/:id/attendance → attendance records with scores
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import type { CreateMeetingRequest } from "./meetings.types";

const meetingsRoute: FastifyPluginAsync = async (fastify) => {
    /**
     * POST /api/meetings
     * Create a new Google Meet meeting space.
     */
    fastify.post<{ Body: CreateMeetingRequest }>(
        "/",
        {
            schema: {
                body: {
                    type: "object",
                    required: ["title"],
                    properties: {
                        title: { type: "string", minLength: 1, maxLength: 200 },
                    },
                },
            },
        },
        async (request, reply) => {
            const { meetingsService, logger } = request.diScope.cradle as Cradle;
            if (!meetingsService.isReady()) {
                return reply.status(401).send({
                    error: "UNAUTHORIZED",
                    message: "Google Meet API is not authorized. Please visit /api/meetings/auth-url to sign in.",
                    authUrl: meetingsService.getAuthUrl(),
                });
            }

            try {
                return await meetingsService.createMeeting(request.body.title);
            } catch (error: any) {
                logger.error({ err: error }, "Failed to create meeting space");
                if (error.message?.includes("not authorized")) {
                    return reply.status(401).send({ error: "UNAUTHORIZED", message: "Sign in required." });
                }
                throw error;
            }
        },
    );

    /**
     * GET /api/meetings/auth-url
     * Returns the OAuth2 consent screen URL for Google Meet.
     */
    fastify.get("/auth-url", async (request) => {
        const { meetingsService } = request.diScope.cradle as Cradle;
        return { authUrl: meetingsService.getAuthUrl() };
    });

    /**
     * GET /api/meetings/oauth2callback
     * Handles the Google OAuth2 redirect hook, stores tokens, and redirects back to app.
     */
    fastify.get<{ Querystring: { code: string; error?: string } }>(
        "/oauth2callback",
        async (request, reply) => {
            const { meetingsService, logger } = request.diScope.cradle as Cradle;
            const { code, error } = request.query;

            if (error) {
                logger.warn({ oauthError: error }, "Google OAuth2 sign-in denied or failed.");
                return reply.type("text/html").send(`<h1>Sign in failed</h1><p>${error}</p>`);
            }

            if (!code) {
                return reply.status(400).send({ error: "Missing authorization code" });
            }

            try {
                await meetingsService.authorize(code);
                // Optionally redirect to a frontend URL instead of just HTML,
                // but for now we'll just show a success page.
                return reply.type("text/html").send(`
                    <html><body>
                        <h1>Successfully authenticated!</h1>
                        <p>You can close this tab and return to Sellio Metrics.</p>
                        <script>setTimeout(() => window.close(), 3000);</script>
                    </body></html>
                `);
            } catch (authErr: any) {
                logger.error({ err: authErr }, "Failed to exchange OAuth2 code");
                return reply.status(500).send({ error: "Authentication failed" });
            }
        }
    );

    /**
     * GET /api/meetings
     * List all tracked meetings.
     */
    fastify.get("/", async (request) => {
        const { meetingsService } = request.diScope.cradle as Cradle;
        return meetingsService.listMeetings();
    });

    /**
     * GET /api/meetings/analytics
     * Aggregated attendance analytics across all meetings.
     * NOTE: Must be registered BEFORE /:id to avoid route conflict.
     */
    fastify.get("/analytics", async (request) => {
        const { meetingsService } = request.diScope.cradle as Cradle;
        return meetingsService.getAnalytics();
    });

    /**
     * GET /api/meetings/rate-limit
     * Google Meet API rate limit status for the frontend.
     */
    fastify.get("/rate-limit", async (request) => {
        const { meetingsService } = request.diScope.cradle as Cradle;
        return meetingsService.getRateLimitStatus();
    });

    /**
     * GET /api/meetings/:id
     * Meeting details with live participant list.
     */
    fastify.get<{ Params: { id: string } }>(
        "/:id",
        {
            schema: {
                params: {
                    type: "object",
                    required: ["id"],
                    properties: {
                        id: { type: "string" },
                    },
                },
            },
        },
        async (request) => {
            const { meetingsService } = request.diScope.cradle as Cradle;
            return meetingsService.getMeeting(request.params.id);
        },
    );

    /**
     * GET /api/meetings/:id/attendance
     * Attendance records with scores for a specific meeting.
     */
    fastify.get<{ Params: { id: string } }>(
        "/:id/attendance",
        {
            schema: {
                params: {
                    type: "object",
                    required: ["id"],
                    properties: {
                        id: { type: "string" },
                    },
                },
            },
        },
        async (request) => {
            const { meetingsService } = request.diScope.cradle as Cradle;
            return meetingsService.getAttendance(request.params.id);
        },
    );
};

export default meetingsRoute;
