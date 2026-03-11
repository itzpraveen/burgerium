import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import {
    calculateCompositeScore,
    feedbackMetricKeys,
    getScoreMeta,
    type FeedbackFormValues,
    type FeedbackMetricKey,
    type FeedbackSubmission,
} from './feedback';

const defaultStoragePath = path.join(process.cwd(), 'data', 'feedback-submissions.json');
let writeQueue = Promise.resolve();

function getStoragePath() {
    return process.env.FEEDBACK_STORAGE_PATH
        ? path.resolve(process.env.FEEDBACK_STORAGE_PATH)
        : defaultStoragePath;
}

async function ensureStorageFile() {
    const storagePath = getStoragePath();
    await mkdir(path.dirname(storagePath), { recursive: true });

    try {
        await readFile(storagePath, 'utf8');
    } catch {
        await writeFile(storagePath, '[]\n', 'utf8');
    }

    return storagePath;
}

async function readEntries() {
    const storagePath = await ensureStorageFile();
    const raw = await readFile(storagePath, 'utf8');

    if (!raw.trim()) {
        return [] as FeedbackSubmission[];
    }

    const parsed = JSON.parse(raw) as FeedbackSubmission[];
    parsed.sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt));
    return parsed;
}

export async function listFeedbackSubmissions() {
    return readEntries();
}

export async function createFeedbackSubmission(values: FeedbackFormValues) {
    const metrics = Object.fromEntries(
        feedbackMetricKeys.map((key) => [key, values[key]])
    ) as Pick<FeedbackFormValues, FeedbackMetricKey>;
    const compositeScore = calculateCompositeScore(metrics);
    const compositeLabel = getScoreMeta(compositeScore).label;

    const submission: FeedbackSubmission = {
        ...values,
        id: randomUUID(),
        createdAt: new Date().toISOString(),
        compositeScore,
        compositeLabel,
        comments: values.comments.trim(),
        name: values.name.trim(),
        phone: values.phone.trim(),
    };

    const persist = async () => {
        const storagePath = await ensureStorageFile();
        const existing = await readEntries();
        existing.unshift(submission);
        await writeFile(storagePath, `${JSON.stringify(existing, null, 2)}\n`, 'utf8');
    };

    writeQueue = writeQueue.then(persist, persist);
    await writeQueue;

    return submission;
}
