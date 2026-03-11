import type { APIRoute } from 'astro';
import { feedbackCategories } from '../../lib/feedback';
import { listFeedbackSubmissions } from '../../lib/feedback-store';

export const prerender = false;

function escapeCsv(value: string | number | boolean) {
    const text = String(value ?? '');
    return `"${text.replace(/"/g, '""')}"`;
}

export const GET: APIRoute = async () => {
    const submissions = await listFeedbackSubmissions();
    const headers = [
        'id',
        'createdAt',
        ...feedbackCategories.map((category) => category.key),
        'compositeScore',
        'compositeLabel',
        'name',
        'phone',
        'contactConsent',
        'comments',
    ];

    const rows = submissions.map((submission) =>
        [
            submission.id,
            submission.createdAt,
            ...feedbackCategories.map((category) => submission[category.key]),
            submission.compositeScore,
            submission.compositeLabel,
            submission.name,
            submission.phone,
            submission.contactConsent,
            submission.comments,
        ]
            .map(escapeCsv)
            .join(',')
    );

    const csv = [headers.join(','), ...rows].join('\n');

    return new Response(csv, {
        headers: {
            'Content-Type': 'text/csv; charset=utf-8',
            'Content-Disposition': 'attachment; filename="burgerium-feedback.csv"',
            'Cache-Control': 'no-store',
        },
    });
};
