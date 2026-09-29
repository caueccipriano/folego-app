import { defineConfig } from '@playwright/test';

// Isolated HTTPS staging ONLY. Ordinary public-shell QA uses the separate
// qa/playwright.config.ts and never loads authenticated staging test data.
export default defineConfig({
  testDir: '.',
  testMatch: '**/*.spec.ts',
  fullyParallel: false,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { outputFolder: '../staging-report', open: 'never' }]],
  use: {
    baseURL: process.env.QA_STAGING_SITE_URL,
    timezoneId: 'America/Sao_Paulo',
    locale: 'pt-BR',
    trace: 'off',
    video: 'off',
    screenshot: 'off',
  },
  projects: [
    {
      name: 'isolated-chromium',
      use: { browserName: 'chromium', viewport: { width: 412, height: 915 } },
    },
    {
      name: 'isolated-webkit-iphone',
      use: {
        browserName: 'webkit',
        viewport: { width: 393, height: 852 },
        deviceScaleFactor: 3,
        isMobile: true,
        hasTouch: true,
      },
    },
  ],
});
