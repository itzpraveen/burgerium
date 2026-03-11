import { randomUUID } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { get, list, put } from '@vercel/blob';
import {
    calculateCompositeScore,
    feedbackMetricKeys,
    getScoreMeta,
    type FeedbackFormValues,
    type FeedbackMetricKey,
    type FeedbackSubmission,
} from './feedback';

const defaultStoragePath = path.join(process.cwd(), 'data', 'feedback-submissions.json');
const feedbackBlobPrefix = 'feedback-submissions/';
const isVercelRuntime = Boolean(process.env.VERCEL || process.env.VERCEL_ENV);
const hasBlobToken = Boolean(process.env.BLOB_READ_WRITE_TOKEN);

export interface FeedbackStorageStatus {
    mode: 'blob' | 'file' | 'unconfigured';
    isConfigured: boolean;
    label: string;
    message?: string;
}

export class FeedbackStorageConfigError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'FeedbackStorageConfigError';
    }
}

export function getFeedbackStorageStatus(): FeedbackStorageStatus {
    if (hasBlobToken) {
        return {
            mode: 'blob',
            isConfigured: true,
            label: 'Vercel Blob',
        };
    }

    if (isVercelRuntime) {
        return {
            mode: 'unconfigured',
            isConfigured: false,
            label: 'Storage not configured',
            message: 'Connect a Vercel Blob store and expose BLOB_READ_WRITE_TOKEN to this project.',
        };
    }

    return {
        mode: 'file',
        isConfigured: true,
        label: 'Local JSON file',
    };
}

function getStoragePath() {
    return process.env.FEEDBACK_STORAGE_PATH
        ? path.resolve(process.env.FEEDBACK_STORAGE_PATH)
        : defaultStoragePath;
}

function getWritableStorageStatus() {
    const status = getFeedbackStorageStatus();

    if (!status.isConfigured) {
        throw new FeedbackStorageConfigError(status.message ?? 'Feedback storage is not configured.');
    }

    return status;
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

async function readFileEntries() {
    const storagePath = await ensureStorageFile();
    const raw = await readFile(storagePath, 'utf8');

    if (!raw.trim()) {
        return [] as FeedbackSubmission[];
    }

    const parsed = JSON.parse(raw) as FeedbackSubmission[];
    parsed.sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt));
    return parsed;
}

async function listBlobEntries() {
    const blobs = [];
    let cursor: string | undefined;

    do {
        const page = await list({
            prefix: feedbackBlobPrefix,
            cursor,
            limit: 1000,
        });

        blobs.push(...page.blobs);
        cursor = page.cursor;

        if (!page.hasMore) {
            break;
        }
    } while (cursor);

    blobs.sort((left, right) => right.uploadedAt.getTime() - left.uploadedAt.getTime());

    const submissions = await Promise.all(
        blobs.map(async (blob) => {
            const result = await get(blob.pathname, {
                access: 'private',
                useCache: false,
            });

            if (!result || result.statusCode !== 200) {
                return null;
            }

            const raw = await new Response(result.stream).text();
            return JSON.parse(raw) as FeedbackSubmission;
        })
    );

    return submissions.filter((submission): submission is FeedbackSubmission => submission !== null);
}

async function createFileSubmission(submission: FeedbackSubmission) {
    const storagePath = await ensureStorageFile();
    const existing = await readFileEntries();
    existing.unshift(submission);
    await writeFile(storagePath, `${JSON.stringify(existing, null, 2)}\n`, 'utf8');
}

async function createBlobSubmission(submission: FeedbackSubmission) {
    const safeTimestamp = submission.createdAt.replace(/[:.]/g, '-');
    const pathname = `${feedbackBlobPrefix}${safeTimestamp}-${submission.id}.json`;

    await put(pathname, JSON.stringify(submission, null, 2), {
        access: 'private',
        addRandomSuffix: false,
        allowOverwrite: false,
        contentType: 'application/json',
        cacheControlMaxAge: 60,
    });
}

export async function listFeedbackSubmissions() {
    const status = getFeedbackStorageStatus();

    if (status.mode === 'blob') {
        return listBlobEntries();
    }

    if (status.mode === 'file') {
        return readFileEntries();
    }

    return [];
}

export async function createFeedbackSubmission(values: FeedbackFormValues) {
    const status = getWritableStorageStatus();
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

    if (status.mode === 'blob') {
        await createBlobSubmission(submission);
    } else {
        await createFileSubmission(submission);
    }

    return submission;
}
