import { defineAction } from 'astro:actions';
import { createFeedbackSubmission } from '../lib/feedback-store';
import type { FeedbackFormValues } from '../lib/feedback';
import { feedbackInputSchema } from '../lib/feedback-validation';

export const server = {
    submitFeedback: defineAction({
        accept: 'form',
        input: feedbackInputSchema,
        handler: async (input) => {
            const submission = await createFeedbackSubmission(input as FeedbackFormValues);

            return {
                id: submission.id,
                name: submission.name,
                createdAt: submission.createdAt,
                compositeScore: submission.compositeScore,
                compositeLabel: submission.compositeLabel,
            };
        },
    }),
};
