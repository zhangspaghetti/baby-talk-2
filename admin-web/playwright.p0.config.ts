import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from '@playwright/test';

const currentDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  testDir: path.join(currentDir, 'tests'),
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report-p0' }]],
  use: {
    baseURL: 'http://127.0.0.1:3000',
    trace: 'retain-on-failure',
    screenshot: 'on',
  },
  webServer: {
    command: 'pnpm run preview',
    url: 'http://127.0.0.1:3000/login',
    reuseExistingServer: true,
    timeout: 30_000,
  },
});
