import type { APIRoute } from "astro";
import type { FeedbackFormValues } from "../../lib/feedback";
import { feedbackCategories, feedbackOptions } from "../../lib/feedback";
import {
  createFeedbackSubmission,
  FeedbackStorageConfigError,
  getFeedbackStorageStatus,
} from "../../lib/feedback-store";
import { feedbackInputSchema } from "../../lib/feedback-validation";

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function availabilityPayload() {
  const storage = getFeedbackStorageStatus();

  return {
    ok: storage.isConfigured,
    availability: {
      isReachable: true,
      isConfigured: storage.isConfigured,
      label: storage.isConfigured ? "Feedback API ready" : storage.label,
      message: storage.message ?? null,
    },
    storage: {
      mode: storage.mode,
      isConfigured: storage.isConfigured,
      label: storage.label,
      message: storage.message ?? null,
    },
    form: {
      categories: feedbackCategories,
      options: feedbackOptions,
      commentsMaxLength: 600,
      phoneDigits: 10,
    },
  };
}

function firstValidationMessage(error: {
  issues?: Array<{ message?: string }>;
  flatten?: () => { fieldErrors: Record<string, string[] | undefined> };
}) {
  return (
    error.issues?.find((issue) => issue.message)?.message ??
    "Check the required fields and try again."
  );
}

export const GET: APIRoute = async () => {
  const payload = availabilityPayload();
  return json(payload, payload.ok ? 200 : 503);
};

export const POST: APIRoute = async ({ request }) => {
  const storage = getFeedbackStorageStatus();

  if (!storage.isConfigured) {
    return json(
      {
        ok: false,
        error: storage.message ?? "Feedback storage is not configured.",
      },
      503,
    );
  }

  let body: unknown;

  try {
    body = await request.json();
  } catch {
    return json(
      {
        ok: false,
        error: "Invalid JSON body.",
      },
      400,
    );
  }

  const parsed = feedbackInputSchema.safeParse(body);

  if (!parsed.success) {
    return json(
      {
        ok: false,
        error: firstValidationMessage(parsed.error),
        fieldErrors: parsed.error.flatten().fieldErrors,
      },
      400,
    );
  }

  try {
    const submission = await createFeedbackSubmission(
      parsed.data as FeedbackFormValues,
    );

    return json(
      {
        ok: true,
        submission: {
          id: submission.id,
          name: submission.name,
          createdAt: submission.createdAt,
          compositeScore: submission.compositeScore,
          compositeLabel: submission.compositeLabel,
        },
      },
      201,
    );
  } catch (error) {
    if (error instanceof FeedbackStorageConfigError) {
      return json(
        {
          ok: false,
          error: error.message,
        },
        503,
      );
    }

    return json(
      {
        ok: false,
        error: "Unable to save feedback right now.",
      },
      500,
    );
  }
};
