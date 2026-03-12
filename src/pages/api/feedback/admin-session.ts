import type { APIRoute } from 'astro';
import {
    clearFeedbackAdminSession,
    getFeedbackAdminConfig,
    getFeedbackAdminDefaultRedirectPath,
    sanitizeFeedbackAdminNextPath,
    setFeedbackAdminSession,
    verifyFeedbackAdminCredentials,
} from '../../../lib/feedback-admin-auth';

function redirect(requestUrl: URL, pathname: string, params?: Record<string, string>) {
    const url = new URL(pathname, requestUrl);

    if (params) {
        for (const [key, value] of Object.entries(params)) {
            url.searchParams.set(key, value);
        }
    }

    return new Response(null, {
        status: 303,
        headers: {
            Location: url.toString(),
            'Cache-Control': 'no-store',
        },
    });
}

export const POST: APIRoute = async ({ request, cookies, url }) => {
    const formData = await request.formData();
    const intent = String(formData.get('intent') ?? 'login');
    const nextPath = sanitizeFeedbackAdminNextPath(formData.get('next')?.toString());

    if (intent === 'logout') {
        clearFeedbackAdminSession(cookies);
        return redirect(url, '/feedback/login', {
            next: nextPath,
            loggedOut: '1',
        });
    }

    const config = getFeedbackAdminConfig();

    if (!config.isConfigured) {
        return redirect(url, '/feedback/login', {
            error: 'config',
        });
    }

    const username = String(formData.get('username') ?? '').trim();
    const password = String(formData.get('password') ?? '');

    if (!verifyFeedbackAdminCredentials(username, password, config)) {
        clearFeedbackAdminSession(cookies);
        return redirect(url, '/feedback/login', {
            error: 'invalid',
            next: nextPath,
        });
    }

    setFeedbackAdminSession(cookies, username, config);

    return redirect(url, nextPath || getFeedbackAdminDefaultRedirectPath());
};
