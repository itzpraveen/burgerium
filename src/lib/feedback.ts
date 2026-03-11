export const feedbackCategories = [
    { key: 'overall', label: 'Overall rating', shortLabel: 'Overall' },
    { key: 'food', label: 'Food', shortLabel: 'Food' },
    { key: 'service', label: 'Service', shortLabel: 'Service' },
    { key: 'onTime', label: 'Food on time?', shortLabel: 'On time' },
    { key: 'cleanlinessAmbience', label: 'Cleanliness & ambience', shortLabel: 'Ambience' },
    { key: 'menuAvailability', label: 'Menu availability', shortLabel: 'Menu' },
] as const;

export const feedbackOptions = [
    { value: 1, label: 'Poor', emoji: '😞' },
    { value: 2, label: 'Fair', emoji: '😐' },
    { value: 3, label: 'Okay', emoji: '🙂' },
    { value: 4, label: 'Good', emoji: '😄' },
    { value: 5, label: 'Great', emoji: '😍' },
] as const;

export type FeedbackMetricKey = (typeof feedbackCategories)[number]['key'];
export type FeedbackScore = (typeof feedbackOptions)[number]['value'];

export interface FeedbackFormValues {
    overall: FeedbackScore;
    food: FeedbackScore;
    service: FeedbackScore;
    onTime: FeedbackScore;
    cleanlinessAmbience: FeedbackScore;
    menuAvailability: FeedbackScore;
    name: string;
    phone: string;
    comments: string;
    contactConsent: boolean;
}

export interface FeedbackSubmission extends FeedbackFormValues {
    id: string;
    createdAt: string;
    compositeScore: number;
    compositeLabel: string;
}

export const feedbackMetricKeys = feedbackCategories.map((category) => category.key) as FeedbackMetricKey[];

export function getScoreMeta(score: number) {
    if (score >= 4.5) return feedbackOptions[4];
    if (score >= 3.5) return feedbackOptions[3];
    if (score >= 2.5) return feedbackOptions[2];
    if (score >= 1.5) return feedbackOptions[1];
    return feedbackOptions[0];
}

export function getScoreColorClass(score: number) {
    if (score >= 4.5) return 'is-great';
    if (score >= 3.5) return 'is-good';
    if (score >= 2.5) return 'is-okay';
    if (score >= 1.5) return 'is-fair';
    return 'is-poor';
}

export function calculateCompositeScore(values: Pick<FeedbackFormValues, FeedbackMetricKey>) {
    const total = feedbackMetricKeys.reduce((sum, key) => sum + values[key], 0);
    return Number((total / feedbackMetricKeys.length).toFixed(1));
}
