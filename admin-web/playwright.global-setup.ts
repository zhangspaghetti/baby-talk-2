import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');
const appApiHealthUrl = 'http://127.0.0.1:8080/actuator/health';
const adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const adminWebUrl = 'http://127.0.0.1:3000/';

function run(command: string, args: string[], allowFailure = false) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: false,
  });

  if (result.status !== 0 && !allowFailure) {
    throw new Error(`Command failed (${result.status ?? 'unknown'}): ${command} ${args.join(' ')}`);
  }

  return result;
}

async function waitForHealth(name: string, url: string, timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url);
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

  dumpComposeDiagnostics();
  throw new Error(`${name} health did not become ready within ${timeoutMs}ms: ${url}`);
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

  dumpComposeDiagnostics();
  throw new Error(`admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}`);
}

function dumpComposeDiagnostics() {
  run('docker', ['compose', 'ps'], true);
  run('docker', ['compose', 'logs', 'minio', 'db-migration', 'app-api', 'admin-api', 'admin-web'], true);
}

export default async function globalSetup() {
  run('docker', ['compose', 'up', '-d', '--build']);
  await waitForHealth('app-api', appApiHealthUrl, 180_000);
  await waitForHealth('admin-api', adminApiHealthUrl, 180_000);
  await waitForAdminWeb(180_000);
}
