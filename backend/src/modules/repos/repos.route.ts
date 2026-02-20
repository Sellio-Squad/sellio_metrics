/**
 * Repos Module — Route (Controller)
 *
 * HTTP layer only: validates input, calls service, shapes response.
 * No business logic here.
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import type { ReposListResponse } from "./repos.types";

const reposRoute: FastifyPluginAsync = async (fastify) => {
    /**
     * GET /api/repos?org=Sellio-Squad
     * Lists all repositories for the given org (defaults to env org).
     */
    fastify.get<{
        Querystring: { org?: string };
    }>(
        "/",
        {
            schema: {
                querystring: {
                    type: "object",
                    properties: {
                        org: { type: "string" },
                    },
                },
            },
        },
        async (request): Promise<ReposListResponse> => {
            const { env, reposService } = request.diScope.cradle as Cradle;
            const org = request.query.org || env.org;

            const repos = await reposService.listByOrg(org);

            return {
                org,
                count: repos.length,
                repos,
            };
        },
    );
};

export default reposRoute;
