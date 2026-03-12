import { z } from 'astro:schema';

export const scoreSchema = z.number().int().min(1).max(5);

export const feedbackInputSchema = z.object({
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
    comments: z.preprocess(
        (value) => (value == null ? '' : value),
        z.string().trim().max(600, 'Keep comments within 600 characters.')
    ),
    contactConsent: z.boolean().default(false),
});

export type FeedbackInput = z.infer<typeof feedbackInputSchema>;
