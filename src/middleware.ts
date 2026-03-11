import { defineMiddleware } from 'astro:middleware';

const protectedRoutes = ['/feedback/admin', '/feedback/export.csv'];
const realm = 'Burgerium Feedback Admin';

function isProtectedPath(pathname: string) {
    return protectedRoutes.some(
        (route) => pathname === route || (route.endsWith('/admin') && pathname.startsWith(`${route}/`))
    );
}

function unauthorized(message = 'Authentication required.') {
    return new Response(message, {
        status: 401,
        headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store',
            'WWW-Authenticate': `Basic realm="${realm}"`,
        },
    });
}

export const onRequest = defineMiddleware(async ({ url, request }, next) => {
    if (!isProtectedPath(url.pathname)) {
        return next();
    }

    const username = process.env.FEEDBACK_ADMIN_USERNAME;
    const password = process.env.FEEDBACK_ADMIN_PASSWORD;

    if (!username || !password) {
        return new Response('Feedback admin access is not configured for this deployment.', {
            status: 503,
            headers: {
                'Content-Type': 'text/plain; charset=utf-8',
                'Cache-Control': 'no-store',
            },
        });
    }

    const authorization = request.headers.get('authorization');

    if (!authorization?.startsWith('Basic ')) {
        return unauthorized();
    }

    let decoded = '';

    try {
        decoded = Buffer.from(authorization.slice(6), 'base64').toString('utf8');
    } catch {
        return unauthorized('Invalid authorization header.');
    }

    const separatorIndex = decoded.indexOf(':');

    if (separatorIndex === -1) {
        return unauthorized('Invalid credentials.');
    }

    const providedUsername = decoded.slice(0, separatorIndex);
    const providedPassword = decoded.slice(separatorIndex + 1);

    if (providedUsername !== username || providedPassword !== password) {
        return unauthorized('Invalid credentials.');
    }

    return next();
});
