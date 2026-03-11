import type { FastifyPluginAsync } from "fastify";
import type { LogsService } from "./logs.service";

interface LimitQuery {
    limit?: number;
}

const logsRoute: FastifyPluginAsync = async (fastify) => {
    fastify.get<{ Querystring: LimitQuery }>(
        "/",
        async (request, reply) => {
            const logsService = fastify.diContainer.resolve<LogsService>("logsService");
            const limit = request.query.limit || 50;
            return await logsService.getLogs(limit);
        },
    );
};

export default logsRoute;
