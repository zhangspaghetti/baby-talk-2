import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from '@playwright/test';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const e2eBaseUrl = process.env.PLAYWRIGHT_BASE_URL?.trim() || 'http://127.0.0.1:3100';
const e2eBaseUrlParsed = new URL(e2eBaseUrl);
const e2eHost = e2eBaseUrlParsed.hostname;
const e2ePort = e2eBaseUrlParsed.port || (e2eBaseUrlParsed.protocol === 'https:' ? '443' : '80');
process.env.BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT ??= '1';

export default defineConfig({
  testDir: path.join(currentDir, 'tests'),
  fullyParallel: false,
  timeout: 120_000,
  expect: {
    timeout: 15_000,
  },
  retries: process.env.CI ? 2 : 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  use: {
    baseURL: e2eBaseUrl,
    channel: 'chrome',
    trace: 'retain-on-failure',
    screenshot: 'on',
    video: 'retain-on-failure',
  },
  webServer: {
    command: `pnpm dev --host ${e2eHost} --port ${e2ePort}`,
    url: e2eBaseUrl,
    reuseExistingServer: true,
    timeout: 120_000,
    env: {
      ...process.env,
      VITE_ADMIN_API_PROXY_TARGET: process.env.VITE_ADMIN_API_PROXY_TARGET ?? 'http://127.0.0.1:8081',
    },
  },
  globalSetup: './playwright.global-setup.ts',
  globalTeardown: './playwright.global-teardown.ts',
});
