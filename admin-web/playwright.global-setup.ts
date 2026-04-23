import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');
const adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const adminWebUrl = 'http://127.0.0.1:3000/';

function run(command: string, args: string[], allowFailure = false) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });

  if (result.status !== 0 && !allowFailure) {
    throw new Error(`Command failed (${result.status ?? 'unknown'}): ${command} ${args.join(' ')}`);
  }

  return result;
}

async function waitForAdminApi(timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(adminApiHealthUrl);
      if (response.ok) {
        const body = (await response.json()) as { status?: string };
        if (body.status === 'UP') {
          return;
        }
      }
    } catch {
      // Keep polling until timeout.
    }

    await new Promise((resolve) => setTimeout(resolve, 2_000));
  }

  run('docker', ['compose', 'ps'], true);
  run('docker', ['compose', 'logs', 'db-migration', 'admin-api', 'admin-web'], true);
  throw new Error(`admin-api health did not become ready within ${timeoutMs}ms: ${adminApiHealthUrl}`);
}

async function waitForAdminWeb(timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(adminWebUrl);
      if (response.ok) {
        const body = await response.text();
        if (body.includes('BabyTalk Admin')) {
          return;
        }
      }
    } catch {
      // Keep polling until timeout.
    }

    await new Promise((resolve) => setTimeout(resolve, 2_000));
  }

  run('docker', ['compose', 'ps'], true);
  run('docker', ['compose', 'logs', 'db-migration', 'admin-api', 'admin-web'], true);
  throw new Error(`admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}`);
}

export default async function globalSetup() {
  run('docker', ['compose', 'up', '-d', '--build', 'postgres', 'db-migration', 'admin-api', 'admin-web']);
  await waitForAdminApi(180_000);
  await waitForAdminWeb(180_000);
}
