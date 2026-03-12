import type { APIRoute } from 'astro';
import { feedbackCategories, type FeedbackMetricKey } from '../../../lib/feedback';
import { getFeedbackStorageStatus, listFeedbackSubmissions } from '../../../lib/feedback-store';

function json(data: unknown, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Cache-Control': 'no-store',
        },
    });
}

export const GET: APIRoute = async () => {
    const storage = getFeedbackStorageStatus();

    if (!storage.isConfigured) {
        return json(
            {
                ok: false,
                error: storage.message ?? 'Feedback storage is not configured.',
            },
            503
        );
    }

    const submissions = await listFeedbackSubmissions();
    const totalResponses = submissions.length;
    const metricKeys = feedbackCategories.map((category) => category.key) as FeedbackMetricKey[];
    const averageOverall = totalResponses
        ? Number(
              (
                  submissions.reduce((sum, submission) => sum + submission.overall, 0) / totalResponses
              ).toFixed(1)
          )
        : 0;
    const averageComposite = totalResponses
        ? Number(
              (
                  submissions.reduce((sum, submission) => sum + submission.compositeScore, 0) / totalResponses
              ).toFixed(1)
          )
        : 0;
    const contactOptIns = submissions.filter((submission) => submission.contactConsent).length;
    const attentionNeeded = submissions.filter(
        (submission) => submission.overall <= 2 || submission.compositeScore <= 2.5
    ).length;
    const categoryAverages = Object.fromEntries(
        feedbackCategories.map((category) => [
            category.key,
            totalResponses
                ? Number(
                      (
                          submissions.reduce((sum, submission) => sum + submission[category.key], 0) / totalResponses
                      ).toFixed(1)
                  )
                : 0,
        ])
    );

    return json({
        ok: true,
        summary: {
            totalResponses,
            averageOverall,
            averageComposite,
            contactOptIns,
            attentionNeeded,
            latestEntryAt: submissions[0]?.createdAt ?? null,
            categoryAverages,
            storage: {
                mode: storage.mode,
                label: storage.label,
            },
        },
        categories: feedbackCategories,
        submissions: submissions.map((submission) => ({
            id: submission.id,
            createdAt: submission.createdAt,
            name: submission.name,
            phone: submission.phone,
            comments: submission.comments,
            contactConsent: submission.contactConsent,
            compositeScore: submission.compositeScore,
            compositeLabel: submission.compositeLabel,
            ratings: Object.fromEntries(metricKeys.map((key) => [key, submission[key]])),
        })),
    });
};
