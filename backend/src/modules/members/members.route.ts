/**
 * Members Module — Route (Controller)
 *
 * HTTP layer only: validates params, calls service, shapes response.
 * No business logic, no data transformation.
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import type { PrMetric } from "../../core/types";
import type { MemberStatus } from "./members.types";

const membersRoute: FastifyPluginAsync = async (fastify) => {
    /**
     * POST /api/members/status
     * Receives a filtered array of PRs and returns the active/inactive status of all org members.
     */
    fastify.post<{ Body: { prs: PrMetric[] } }>(
        "/status",
        async (request): Promise<MemberStatus[]> => {
            const { membersService, cachedGithubClient, env } = request.diScope.cradle as Cradle;

            // Get all organization members for active/inactive status
            const orgMembers = await cachedGithubClient.listOrgMembers(env.org);

            // Forward the active org members and known PR activity
            return membersService.calculateMemberStatus(request.body.prs, orgMembers);
        },
    );
};

export default membersRoute;
