import { createHmac, timingSafeEqual } from 'node:crypto';

const adminSessionCookieName = 'burgerium_feedback_admin_session';
const adminRealm = 'Burgerium Feedback Admin';
const defaultAdminRedirectPath = '/feedback/admin';
const allowedNextPaths = new Set(['/feedback/admin', '/feedback/export.csv']);

export interface FeedbackAdminConfig {
    isConfigured: boolean;
    username?: string;
    password?: string;
    message?: string;
}

export function getFeedbackAdminConfig(): FeedbackAdminConfig {
    const username = process.env.FEEDBACK_ADMIN_USERNAME;
    const password = process.env.FEEDBACK_ADMIN_PASSWORD;

    if (!username || !password) {
        return {
            isConfigured: false,
            message: 'Feedback admin access is not configured for this deployment.',
        };
    }

    return {
        isConfigured: true,
        username,
        password,
    };
}

function secureCompare(left: string, right: string) {
    const leftBuffer = Buffer.from(left, 'utf8');
    const rightBuffer = Buffer.from(right, 'utf8');

    if (leftBuffer.length !== rightBuffer.length) {
        return false;
    }

    return timingSafeEqual(leftBuffer, rightBuffer);
}

function getSessionSecret(config: FeedbackAdminConfig) {
    return process.env.FEEDBACK_ADMIN_SESSION_SECRET ?? `${config.username}:${config.password}`;
}

function createSessionSignature(username: string, config: FeedbackAdminConfig) {
    return createHmac('sha256', getSessionSecret(config)).update(username).digest('hex');
}

function getSessionCookieOptions() {
    return {
        path: '/',
        httpOnly: true,
        sameSite: 'lax' as const,
        secure: Boolean(process.env.VERCEL || process.env.NODE_ENV === 'production'),
    };
}

export function setFeedbackAdminSession(
    cookies: {
        set: (name: string, value: string, options?: Record<string, unknown>) => void;
    },
    username: string,
    config: FeedbackAdminConfig
) {
    const payload = Buffer.from(username, 'utf8').toString('base64url');
    const signature = createSessionSignature(username, config);
    cookies.set(adminSessionCookieName, `${payload}.${signature}`, getSessionCookieOptions());
}

export function clearFeedbackAdminSession(
    cookies: {
        delete: (name: string, options?: Record<string, unknown>) => void;
    }
) {
    cookies.delete(adminSessionCookieName, { path: '/' });
}

export function hasValidFeedbackAdminSession(
    cookies: {
        get: (name: string) => { value: string } | undefined;
    },
    config: FeedbackAdminConfig
) {
    if (!config.isConfigured || !config.username) {
        return false;
    }

    const raw = cookies.get(adminSessionCookieName)?.value;

    if (!raw) {
        return false;
    }

    const separatorIndex = raw.indexOf('.');

    if (separatorIndex === -1) {
        return false;
    }

    const encodedUsername = raw.slice(0, separatorIndex);
    const providedSignature = raw.slice(separatorIndex + 1);

    let decodedUsername = '';

    try {
        decodedUsername = Buffer.from(encodedUsername, 'base64url').toString('utf8');
    } catch {
        return false;
    }

    const expectedSignature = createSessionSignature(decodedUsername, config);

    return (
        secureCompare(decodedUsername, config.username) &&
        secureCompare(providedSignature, expectedSignature)
    );
}

export function verifyFeedbackAdminCredentials(
    providedUsername: string,
    providedPassword: string,
    config: FeedbackAdminConfig
) {
    if (!config.isConfigured || !config.username || !config.password) {
        return false;
    }

    return (
        secureCompare(providedUsername, config.username) &&
        secureCompare(providedPassword, config.password)
    );
}

export function verifyFeedbackAdminBasicAuth(
    authorization: string | null,
    config: FeedbackAdminConfig
) {
    if (!authorization?.startsWith('Basic ')) {
        return false;
    }

    let decoded = '';

    try {
        decoded = Buffer.from(authorization.slice(6), 'base64').toString('utf8');
    } catch {
        return false;
    }

    const separatorIndex = decoded.indexOf(':');

    if (separatorIndex === -1) {
        return false;
    }

    return verifyFeedbackAdminCredentials(
        decoded.slice(0, separatorIndex),
        decoded.slice(separatorIndex + 1),
        config
    );
}

export function getFeedbackAdminUnauthorizedResponse(message = 'Authentication required.') {
    return new Response(message, {
        status: 401,
        headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Cache-Control': 'no-store',
            'WWW-Authenticate': `Basic realm="${adminRealm}"`,
        },
    });
}

export function sanitizeFeedbackAdminNextPath(raw: string | null | undefined) {
    if (!raw) {
        return defaultAdminRedirectPath;
    }

    let parsed: URL;

    try {
        parsed = new URL(raw, 'https://burgerium.local');
    } catch {
        return defaultAdminRedirectPath;
    }

    const path = `${parsed.pathname}${parsed.search}`;

    if (parsed.origin !== 'https://burgerium.local') {
        return defaultAdminRedirectPath;
    }

    return allowedNextPaths.has(parsed.pathname) ? path : defaultAdminRedirectPath;
}

export function buildFeedbackAdminLoginUrl(url: URL) {
    const loginUrl = new URL('/feedback/login', url);
    const nextPath = sanitizeFeedbackAdminNextPath(`${url.pathname}${url.search}`);

    if (nextPath !== defaultAdminRedirectPath) {
        loginUrl.searchParams.set('next', nextPath);
    }

    return loginUrl;
}

export function getFeedbackAdminDefaultRedirectPath() {
    return defaultAdminRedirectPath;
}
