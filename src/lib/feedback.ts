export const feedbackCategories = [
  { key: "overall", label: "Overall rating", shortLabel: "Overall" },
  { key: "food", label: "Food", shortLabel: "Food" },
  { key: "service", label: "Service", shortLabel: "Service" },
  { key: "onTime", label: "Food on time?", shortLabel: "On time" },
  {
    key: "cleanlinessAmbience",
    label: "Cleanliness & ambience",
    shortLabel: "Ambience",
  },
  { key: "menuAvailability", label: "Menu availability", shortLabel: "Menu" },
] as const;

export const feedbackOptions = [
  { value: 5, label: "Great", emoji: "😍" },
  { value: 4, label: "Good", emoji: "😄" },
  { value: 3, label: "Okay", emoji: "🙂" },
  { value: 2, label: "Fair", emoji: "😐" },
  { value: 1, label: "Poor", emoji: "😞" },
] as const;

export type FeedbackMetricKey = (typeof feedbackCategories)[number]["key"];
export type FeedbackScore = (typeof feedbackOptions)[number]["value"];

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

export interface PublicFeedbackTestimonial {
  id: string;
  quote: string;
  name: string;
  tag: string;
  initial: string;
  featured: boolean;
  score: FeedbackScore;
  createdAt: string;
}

export const feedbackMetricKeys = feedbackCategories.map(
  (category) => category.key,
) as FeedbackMetricKey[];

export function getScoreMeta(score: number) {
  if (score >= 4.5) return feedbackOptions[4];
  if (score >= 3.5) return feedbackOptions[3];
  if (score >= 2.5) return feedbackOptions[2];
  if (score >= 1.5) return feedbackOptions[1];
  return feedbackOptions[0];
}

export function getScoreColorClass(score: number) {
  if (score >= 4.5) return "is-great";
  if (score >= 3.5) return "is-good";
  if (score >= 2.5) return "is-okay";
  if (score >= 1.5) return "is-fair";
  return "is-poor";
}

export function calculateCompositeScore(
  values: Pick<FeedbackFormValues, FeedbackMetricKey>,
) {
  const total = feedbackMetricKeys.reduce((sum, key) => sum + values[key], 0);
  return Number((total / feedbackMetricKeys.length).toFixed(1));
}

function normalizeComment(value: string) {
  return value.replace(/\s+/g, " ").trim();
}

function isPrivateComment(value: string) {
  return /(contact me|call me|callback|phone|mobile|whatsapp)/i.test(value);
}

function isTestLikeValue(value: string) {
  return /(test|demo|sample|verification|dummy|qa)/i.test(value);
}

function getDisplayName(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);

  if (!parts.length) {
    return "Guest";
  }

  if (parts.length === 1) {
    return parts[0];
  }

  return `${parts[0]} ${parts[1].charAt(0)}.`;
}

function getInitial(name: string) {
  const trimmed = name.trim();
  return trimmed ? trimmed.charAt(0).toUpperCase() : "G";
}

function getTestimonialTag(submission: FeedbackSubmission) {
  const strongest = feedbackMetricKeys.reduce(
    (best, key) => {
      const score = submission[key];
      if (score > best.score) {
        return { key, score };
      }

      return best;
    },
    { key: feedbackMetricKeys[0], score: submission[feedbackMetricKeys[0]] },
  );

  const strongestCategory = feedbackCategories.find(
    (category) => category.key === strongest.key,
  );
  if (strongest.score >= 5 && strongestCategory) {
    return `${strongestCategory.shortLabel} stood out`;
  }

  if (submission.compositeScore >= 4.5) {
    return "Five-star visit";
  }

  if (strongestCategory) {
    return `${strongestCategory.shortLabel} landed well`;
  }

  return "Guest feedback";
}

function toFeedbackScore(score: number): FeedbackScore {
  if (score >= 4.5) return 5;
  if (score >= 3.5) return 4;
  if (score >= 2.5) return 3;
  if (score >= 1.5) return 2;
  return 1;
}

export function createPublicFeedbackTestimonials(
  submissions: FeedbackSubmission[],
  limit = 3,
) {
  const eligibleSubmissions = submissions.filter((submission) => {
    const normalizedName = submission.name.trim();
    const normalizedComment = normalizeComment(submission.comments);

    return (
      !isTestLikeValue(normalizedName) &&
      !isTestLikeValue(normalizedComment) &&
      !isPrivateComment(normalizedComment)
    );
  });

  const preferred = submissions.filter((submission) => {
    const comment = normalizeComment(submission.comments);

    return (
      submission.compositeScore >= 4.2 &&
      comment.length >= 18 &&
      eligibleSubmissions.some((candidate) => candidate.id == submission.id)
    );
  });

  const fallback = submissions.filter((submission) => {
    const comment = normalizeComment(submission.comments);

    return (
      submission.compositeScore >= 3.8 &&
      comment.length >= 18 &&
      eligibleSubmissions.some((candidate) => candidate.id == submission.id)
    );
  });

  const selected = [...preferred, ...fallback]
    .filter((submission, index, all) => {
      const quote = normalizeComment(submission.comments).toLowerCase();

      return (
        all.findIndex((candidate) => candidate.id === submission.id) ===
          index &&
        all.findIndex(
          (candidate) =>
            normalizeComment(candidate.comments).toLowerCase() === quote,
        ) === index
      );
    })
    .slice(0, limit);

  const prioritized = selected.map(
    (submission): PublicFeedbackTestimonial => ({
      id: submission.id,
      quote: normalizeComment(submission.comments),
      name: getDisplayName(submission.name),
      tag: getTestimonialTag(submission),
      initial: getInitial(submission.name),
      featured: false,
      score: toFeedbackScore(submission.compositeScore),
      createdAt: submission.createdAt,
    }),
  );

  if (prioritized.length < limit) {
    const selectedIds = new Set(prioritized.map((testimonial) => testimonial.id));
    const topUp = createPublicFeedbackArchive(submissions)
      .filter((testimonial) => !selectedIds.has(testimonial.id))
      .slice(0, limit - prioritized.length)
      .map((testimonial) => ({ ...testimonial, featured: false }));

    prioritized.push(...topUp);
  }

  return prioritized.map((testimonial, index) => ({
    ...testimonial,
    featured: index === 0,
  }));
}

export function createPublicFeedbackArchive(submissions: FeedbackSubmission[]) {
  return submissions
    .filter((submission) => {
      const normalizedName = submission.name.trim();
      const normalizedComment = normalizeComment(submission.comments);

      return (
        normalizedComment.length >= 6 &&
        submission.compositeScore >= 3.5 &&
        !isTestLikeValue(normalizedName) &&
        !isTestLikeValue(normalizedComment) &&
        !isPrivateComment(normalizedComment)
      );
    })
    .filter(
      (submission, index, all) =>
        all.findIndex(
          (candidate) =>
            normalizeComment(candidate.comments).toLowerCase() ===
            normalizeComment(submission.comments).toLowerCase(),
        ) === index,
    )
    .sort((left, right) => Date.parse(right.createdAt) - Date.parse(left.createdAt))
    .map(
      (submission, index): PublicFeedbackTestimonial => ({
        id: submission.id,
        quote: normalizeComment(submission.comments),
        name: getDisplayName(submission.name),
        tag: getTestimonialTag(submission),
        initial: getInitial(submission.name),
        featured: index === 0,
        score: toFeedbackScore(submission.compositeScore),
        createdAt: submission.createdAt,
      }),
    );
}
