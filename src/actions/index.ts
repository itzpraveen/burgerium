import { defineAction } from 'astro:actions';
import { z } from 'astro:schema';
import { createFeedbackSubmission } from '../lib/feedback-store';
import type { FeedbackFormValues } from '../lib/feedback';

const scoreSchema = z.number().int().min(1).max(5);

export const server = {
    submitFeedback: defineAction({
        accept: 'form',
        input: z.object({
            overall: scoreSchema,
            food: scoreSchema,
            service: scoreSchema,
            onTime: scoreSchema,
            cleanlinessAmbience: scoreSchema,
            menuAvailability: scoreSchema,
            name: z.string().trim().min(2, 'Enter a valid name.').max(80, 'Name is too long.'),
            phone: z
                .string()
                .trim()
                .regex(/^\d{10}$/, 'Enter a 10-digit phone number.'),
            comments: z.string().trim().max(600, 'Keep comments within 600 characters.').optional().default(''),
            contactConsent: z.boolean().default(false),
        }),
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
