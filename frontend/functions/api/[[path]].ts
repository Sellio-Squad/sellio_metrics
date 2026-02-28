/**
 * Cloudflare Pages Function — API Proxy
 *
 * Proxies all /api/* requests to the Sellio Metrics Worker.
 * This eliminates CORS issues because the browser only talks
 * to the Pages domain (same-origin).
 *
 * The Worker URL is configured via the WORKER_URL environment variable
 * set in the Cloudflare Pages dashboard.
 */

interface Env {
    WORKER_URL: string;
}

export const onRequest: PagesFunction<Env> = async (context) => {
    const workerUrl = context.env.WORKER_URL || 'https://sellio-metrics.abdoessam743.workers.dev';

    // Build the proxied URL: keep the path and query string
    const url = new URL(context.request.url);
    const targetUrl = `${workerUrl}${url.pathname}${url.search}`;

    // Forward the request to the Worker
    const response = await fetch(targetUrl, {
        method: context.request.method,
        headers: context.request.headers,
        body: context.request.method !== 'GET' && context.request.method !== 'HEAD'
            ? context.request.body
            : undefined,
    });

    // Return the Worker's response with CORS headers for safety
    const newHeaders = new Headers(response.headers);
    newHeaders.set('Access-Control-Allow-Origin', '*');
    newHeaders.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    newHeaders.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: newHeaders,
    });
};
