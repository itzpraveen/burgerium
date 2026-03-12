import { defineMiddleware } from 'astro:middleware';
import {
    buildFeedbackAdminLoginUrl,
    getFeedbackAdminConfig,
    getFeedbackAdminUnauthorizedResponse,
    hasValidFeedbackAdminSession,
    verifyFeedbackAdminBasicAuth,
} from './lib/feedback-admin-auth';

const browserProtectedRoutes = ['/feedback/admin', '/feedback/export.csv'];
const apiProtectedRoutes = ['/api/feedback/admin'];

function isProtectedPath(pathname: string, routes: string[]) {
    return routes.some(
        (route) => pathname === route || (route.endsWith('/admin') && pathname.startsWith(`${route}/`))
    );
}

export const onRequest = defineMiddleware(async (context, next) => {
    const { url, request, cookies } = context;
    const hasTrailingSlash = url.pathname.length > 1 && url.pathname.endsWith('/');

    if (hasTrailingSlash) {
        const redirectUrl = new URL(url);
        redirectUrl.pathname = url.pathname.replace(/\/+$/, '');

        return Response.redirect(redirectUrl, 308);
    }

    if (
        !isProtectedPath(url.pathname, browserProtectedRoutes) &&
        !isProtectedPath(url.pathname, apiProtectedRoutes)
    ) {
        return next();
    }

    const config = getFeedbackAdminConfig();

    if (!config.isConfigured) {
        return new Response(config.message ?? 'Feedback admin access is not configured for this deployment.', {
            status: 503,
            headers: {
                'Content-Type': 'text/plain; charset=utf-8',
                'Cache-Control': 'no-store',
            },
        });
    }

    const hasSession = hasValidFeedbackAdminSession(cookies, config);
    const hasBasicAuth = verifyFeedbackAdminBasicAuth(request.headers.get('authorization'), config);

    if (hasSession || hasBasicAuth) {
        return next();
    }

    if (isProtectedPath(url.pathname, apiProtectedRoutes)) {
        return getFeedbackAdminUnauthorizedResponse();
    }

    return Response.redirect(buildFeedbackAdminLoginUrl(url), 303);
});
