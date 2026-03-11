// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import vercel from '@astrojs/vercel';

// https://astro.build/config
export default defineConfig({
  site: 'https://www.burgerium.in',
  output: 'server',
  adapter: vercel(),
  security: {
    allowedDomains: [
      { protocol: 'https', hostname: 'www.burgerium.in' },
      { protocol: 'https', hostname: 'burgerium.in' },
      { protocol: 'https', hostname: '**.vercel.app' },
    ],
  },
  integrations: [sitemap()],
});
