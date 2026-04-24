import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');
const reuseComposeBoot = process.env.BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT === '1';
const appApiHealthUrl = 'http://127.0.0.1:8080/actuator/health';
const adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const adminWebUrl = 'http://127.0.0.1:3000/';
const composePollIntervalMs = 2_000;

type ComposePsEntry = {
  Service?: string;
  Name?: string;
  State?: string;
  Health?: string;
  ExitCode?: number | string | null;
  Status?: string;
};

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

function runCapture(command: string, args: string[], label: string): string {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf-8',
    stdio: 'pipe',
    shell: false,
  });

  if (result.status !== 0) {
    throw new Error(
      `[compose-runtime] ${label} failed with status ${result.status ?? 'unknown'}\n${result.stderr?.trim() ?? ''}`,
    );
  }

  return result.stdout ?? '';
}

function parseComposePs(rawJson: string): ComposePsEntry[] {
  const trimmed = rawJson.trim();
  if (!trimmed) {
    return [];
  }

  const decoded = trimmed.startsWith('[')
    ? JSON.parse(trimmed)
    : trimmed
        .split(/\r?\n/)
        .filter((line) => line.trim().length > 0)
        .map((line) => JSON.parse(line));

  if (!Array.isArray(decoded)) {
    throw new Error('[compose-runtime] docker compose ps did not return a JSON array.');
  }

  return decoded as ComposePsEntry[];
}

function readComposePs(): ComposePsEntry[] {
  return parseComposePs(runCapture('docker', ['compose', 'ps', '--all', '--format', 'json'], 'docker compose ps'));
}

function formatComposeState(serviceName: string, entry: ComposePsEntry | undefined): string {
  if (!entry) {
    return `${serviceName}: missing`;
  }

  const parts = [`state=${entry.State ?? 'unknown'}`];
  if (entry.Health) {
    parts.push(`health=${entry.Health}`);
  }
  if (entry.ExitCode !== undefined && entry.ExitCode !== null && String(entry.ExitCode).length > 0) {
    parts.push(`exit=${entry.ExitCode}`);
  }
  if (entry.Status) {
    parts.push(`status="${entry.Status}"`);
  }

  return `${serviceName}: ${parts.join(', ')}`;
}

function evaluateComposeRuntime(snapshot: ComposePsEntry[]) {
  const byService = new Map(snapshot.map((entry) => [entry.Service ?? entry.Name ?? 'unknown-service', entry]));
  const pending: string[] = [];
  const hardFailures: string[] = [];

  for (const serviceName of ['postgres', 'minio', 'app-api', 'admin-api', 'admin-web']) {
    const entry = byService.get(serviceName);
    if (!entry) {
      pending.push(`${serviceName}: missing from docker compose ps --all`);
      continue;
    }

    const state = (entry.State ?? '').toLowerCase();
    const health = (entry.Health ?? '').toLowerCase();

    if (state === 'dead' || state === 'exited') {
      hardFailures.push(formatComposeState(serviceName, entry));
      continue;
    }

    if (health === 'unhealthy') {
      hardFailures.push(formatComposeState(serviceName, entry));
      continue;
    }

    if (state !== 'running' || health !== 'healthy') {
      pending.push(formatComposeState(serviceName, entry));
    }
  }

  const migration = byService.get('db-migration');
  if (!migration) {
    pending.push('db-migration: missing from docker compose ps --all');
  } else {
    const state = (migration.State ?? '').toLowerCase();
    const exitCode = migration.ExitCode === undefined || migration.ExitCode === null || `${migration.ExitCode}` === ''
      ? null
      : Number(migration.ExitCode);

    if (state === 'exited') {
      if (exitCode === null || Number.isNaN(exitCode)) {
        hardFailures.push(`${formatComposeState('db-migration', migration)} (missing exit code metadata)`);
      } else if (exitCode !== 0) {
        hardFailures.push(formatComposeState('db-migration', migration));
      }
    } else if (state === 'dead') {
      hardFailures.push(formatComposeState('db-migration', migration));
    } else {
      pending.push(formatComposeState('db-migration', migration));
    }
  }

  if (hardFailures.length > 0) {
    return {
      ready: false,
      hardFailure: true,
      message: `Compose runtime hit a hard failure:\n- ${hardFailures.join('\n- ')}`,
      byService,
    };
  }

  if (pending.length > 0) {
    return {
      ready: false,
      hardFailure: false,
      message: `Still waiting for runtime services:\n- ${pending.join('\n- ')}`,
      byService,
    };
  }

  return {
    ready: true,
    hardFailure: false,
    message: 'ready',
    byService,
  };
}

async function waitForComposeRuntimeTruth(timeoutMs: number) {
  const startedAt = Date.now();
  let lastVerdict: ReturnType<typeof evaluateComposeRuntime> | null = null;

  while (Date.now() - startedAt < timeoutMs) {
    lastVerdict = evaluateComposeRuntime(readComposePs());
    if (lastVerdict.ready) {
      return lastVerdict.byService;
    }

    if (lastVerdict.hardFailure) {
      dumpComposeDiagnostics();
      throw new Error(lastVerdict.message);
    }

    await new Promise((resolve) => setTimeout(resolve, composePollIntervalMs));
  }

  dumpComposeDiagnostics();
  throw new Error(
    `Timed out after ${timeoutMs}ms while waiting for compose runtime truth. ${lastVerdict?.message ?? ''}`.trim(),
  );
}

async function waitForHealth(name: string, url: string, timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        dumpComposeDiagnostics();
        throw new Error(`${name} health probe returned HTTP ${response.status}.`);
      }

      let body: { status?: string };
      try {
        body = (await response.json()) as { status?: string };
      } catch (error) {
        dumpComposeDiagnostics();
        throw new Error(
          `${name} health probe returned malformed JSON. ${error instanceof Error ? error.message : String(error)}`,
        );
      }

      if (body.status !== 'UP') {
        dumpComposeDiagnostics();
        throw new Error(`${name} health probe returned status=${body.status ?? 'missing'}.`);
      }

      return;
    } catch (error) {
      if (error instanceof TypeError) {
        if (Date.now() - startedAt >= timeoutMs) {
          dumpComposeDiagnostics();
          throw new Error(`${name} health did not become ready within ${timeoutMs}ms: ${url}. ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, composePollIntervalMs));
        continue;
      }

      throw error;
    }
  }

  dumpComposeDiagnostics();
  throw new Error(`${name} health did not become ready within ${timeoutMs}ms: ${url}`);
}

async function waitForAdminWeb(timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(adminWebUrl);
      if (!response.ok) {
        dumpComposeDiagnostics();
        throw new Error(`admin-web landing page returned HTTP ${response.status}.`);
      }

      const body = await response.text();
      if (!body.includes('BabyTalk Admin')) {
        dumpComposeDiagnostics();
        throw new Error('admin-web landing page did not contain the BabyTalk Admin marker.');
      }

      return;
    } catch (error) {
      if (error instanceof TypeError) {
        if (Date.now() - startedAt >= timeoutMs) {
          dumpComposeDiagnostics();
          throw new Error(`admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}. ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, composePollIntervalMs));
        continue;
      }

      throw error;
    }
  }

  dumpComposeDiagnostics();
  throw new Error(`admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}`);
}

function dumpComposeDiagnostics() {
  run('docker', ['compose', 'ps', '--all'], true);
  run('docker', ['compose', 'logs', '--no-color', '--tail', '120', 'db-migration', 'app-api', 'admin-api', 'admin-web', 'minio'], true);
}

export default async function globalSetup() {
  if (!reuseComposeBoot) {
    run('docker', ['compose', 'up', '-d', '--build']);
  }

  const composeState = await waitForComposeRuntimeTruth(240_000);
  for (const serviceName of ['postgres', 'minio', 'db-migration', 'app-api', 'admin-api', 'admin-web']) {
    console.log(`[compose-runtime] ${formatComposeState(serviceName, composeState.get(serviceName))}`);
  }
  await waitForHealth('app-api', appApiHealthUrl, 180_000);
  await waitForHealth('admin-api', adminApiHealthUrl, 180_000);
  await waitForAdminWeb(180_000);
}
