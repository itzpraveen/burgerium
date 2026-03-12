# Burgerium Website + Feedback App

Astro marketing site for Burgerium, with a built-in feedback collection flow for dine-in guests and a Vercel-safe storage path.

## Routes

- `/` marketing site
- `/menu` digital menu
- `/feedback` guest feedback form
- `/feedback/login` browser login for the feedback dashboard
- `/feedback/admin` operator dashboard
- `/feedback/export.csv` CSV export of stored responses
- `/api/feedback/admin` protected JSON endpoint used by the Flutter admin dashboard

## Feedback storage

Production storage uses Vercel Blob.

- Required on Vercel: connect a Blob store so `BLOB_READ_WRITE_TOKEN` is available at runtime
- Required for `/feedback/admin` and `/feedback/export.csv`: set `FEEDBACK_ADMIN_USERNAME` and `FEEDBACK_ADMIN_PASSWORD`
- The Flutter admin login uses the same `FEEDBACK_ADMIN_USERNAME` and `FEEDBACK_ADMIN_PASSWORD` values
- Optional hardening: set `FEEDBACK_ADMIN_SESSION_SECRET` to sign browser admin session cookies with a secret separate from the login password
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
