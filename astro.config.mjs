// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';

// https://astro.build/config
export default defineConfig({
  site: 'https://www.burgerium.in',
  output: 'server',
  trailingSlash: 'never',
  adapter: vercel(),
  security: {
    allowedDomains: [
      { protocol: 'https', hostname: 'www.burgerium.in' },
      { protocol: 'https', hostname: 'burgerium.in' },
      { protocol: 'https', hostname: '**.vercel.app' },
    ],
  },
  integrations: [
    sitemap({
      filter(page) {
        const pathname = new URL(page).pathname.replace(/\/$/, '') || '/';
        return pathname !== '/feedback' && !pathname.startsWith('/feedback/');
      },
    }),
  ],
});
