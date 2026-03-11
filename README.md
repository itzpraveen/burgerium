# Burgerium Website + Feedback App

Astro marketing site for Burgerium, with a built-in feedback collection flow for dine-in guests and a Vercel-safe storage path.

## Routes

- `/` marketing site
- `/menu` digital menu
- `/feedback` guest feedback form
- `/feedback/admin` operator dashboard
- `/feedback/export.csv` CSV export of stored responses

## Feedback storage

Production storage uses Vercel Blob.

- Required on Vercel: connect a Blob store so `BLOB_READ_WRITE_TOKEN` is available at runtime
- Required for `/feedback/admin` and `/feedback/export.csv`: set `FEEDBACK_ADMIN_USERNAME` and `FEEDBACK_ADMIN_PASSWORD`
- Local development fallback: `data/feedback-submissions.json`
- Optional local override: `FEEDBACK_STORAGE_PATH=/absolute/path/to/feedback-submissions.json`

## Commands

All commands are run from the root of the project, from a terminal:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Install dependencies                              |
| `npm run dev`             | Start local development server                    |
| `npm run build`           | Build the Vercel serverless Astro app             |
| `npm run check`           | Run Astro type checking                           |
