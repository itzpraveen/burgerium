# Burgerium Website + Feedback App

Astro marketing site for Burgerium, now with a built-in feedback collection flow for dine-in guests.

## Routes

- `/` marketing site
- `/menu` digital menu
- `/feedback` guest feedback form
- `/feedback/admin` operator dashboard
- `/feedback/export.csv` CSV export of stored responses

## Feedback storage

Feedback submissions are stored in a JSON file on the server.

- Default path: `data/feedback-submissions.json`
- Override path: set `FEEDBACK_STORAGE_PATH=/absolute/path/to/feedback-submissions.json`

This is appropriate for a small self-hosted Node deployment. If you move to serverless hosting without persistent disk, replace the file store with a real database.

## Commands

All commands are run from the root of the project, from a terminal:

| Command                   | Action                                           |
| :------------------------ | :----------------------------------------------- |
| `npm install`             | Install dependencies                              |
| `npm run dev`             | Start local development server                    |
| `npm run build`           | Build the hybrid Astro app                        |
| `npm run start`           | Run the standalone Node server from `dist/server` |
| `npm run check`           | Run Astro type checking                           |
