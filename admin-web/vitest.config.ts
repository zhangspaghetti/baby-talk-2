import path from 'node:path';
import { fileURLToPath } from 'node:url';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const currentDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: currentDir,
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['unit/**/*.test.ts', 'unit/**/*.test.tsx'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      reportsDirectory: 'coverage',
      include: ['src/auth/**/*.ts', 'src/shared/errors/**/*.ts', 'src/app/access.ts'],
      thresholds: {
        lines: 40,
      },
    },
  },
});
