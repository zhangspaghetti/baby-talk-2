import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');
const reuseComposeBoot = process.env.BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT === '1';
const dockerApiVersion = process.env.DOCKER_API_VERSION?.trim() || '1.44';
const appApiHealthUrl = 'http://127.0.0.1:8080/actuator/health';
const adminApiHealthUrl = 'http://127.0.0.1:8081/actuator/health';
const adminWebUrl = 'http://127.0.0.1:3000/';
const composePollIntervalMs = 2_000;
const composeServiceOrder = ['postgres', 'minio', 'db-migration', 'app-api', 'admin-api', 'admin-web'];
const composeDiagnosticServices = ['db-migration', 'app-api', 'admin-api', 'admin-web', 'minio'];

type ComposePsEntry = {
  Service?: string;
  Name?: string;
  State?: string;
  Health?: string;
  ExitCode?: number | string | null;
  Status?: string;
};

type RunOptions = {
  allowFailure?: boolean;
  dumpDiagnosticsOnFailure?: boolean;
};

type CapturedResult = {
  status: number;
  stdout: string;
  stderr: string;
};

function commandEnvironment(extraEnv: NodeJS.ProcessEnv = {}): NodeJS.ProcessEnv {
  return {
    ...process.env,
    DOCKER_API_VERSION: dockerApiVersion,
    ...extraEnv,
  };
}

function renderedCommand(command: string, args: ReadonlyArray<string>): string {
  return [command, ...args].join(' ');
}

function run(command: string, args: ReadonlyArray<string>, label: string, options: RunOptions = {}) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: false,
    env: commandEnvironment(),
  });

  if (result.error) {
    if (options.dumpDiagnosticsOnFailure) {
      dumpComposeDiagnostics();
    }
    throw new Error(`[${label}] Unable to start ${renderedCommand(command, args)}: ${result.error.message}`);
  }

  if (result.status !== 0 && !options.allowFailure) {
    if (options.dumpDiagnosticsOnFailure) {
      dumpComposeDiagnostics();
    }
    throw new Error(`[${label}] Command failed (${result.status ?? 'unknown'}): ${renderedCommand(command, args)}`);
  }

  return result;
}

function runCapture(command: string, args: ReadonlyArray<string>, label: string, options: RunOptions = {}): CapturedResult {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf-8',
    stdio: 'pipe',
    shell: false,
    env: commandEnvironment(),
  });

  if (result.error) {
    if (options.allowFailure) {
      return {
        status: result.status ?? 1,
        stdout: '',
        stderr: result.error.message,
      };
    }

    throw new Error(`[${label}] Unable to start ${renderedCommand(command, args)}: ${result.error.message}`);
  }

  const captured = {
    status: result.status ?? 1,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  };

  if (captured.status !== 0 && !options.allowFailure) {
    throw new Error(
      `[${label}] ${renderedCommand(command, args)} failed with status ${captured.status}\n${combinedOutput(captured)}`,
    );
  }

  return captured;
}

function combinedOutput(result: CapturedResult): string {
  return [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join('\n');
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
    throw new Error('[runtime_truth] docker compose ps did not return a JSON array.');
  }

  return decoded as ComposePsEntry[];
}

function readComposePs(): ComposePsEntry[] {
  const result = runCapture('docker', ['compose', 'ps', '--all', '--format', 'json'], 'runtime_truth');
  return parseComposePs(result.stdout);
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
    try {
      lastVerdict = evaluateComposeRuntime(readComposePs());
    } catch (error) {
      dumpComposeDiagnostics();
      throw error;
    }

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
        throw new Error(`[runtime_truth] ${name} health probe returned HTTP ${response.status}.`);
      }

      let body: { status?: string };
      try {
        body = (await response.json()) as { status?: string };
      } catch (error) {
        dumpComposeDiagnostics();
        throw new Error(
          `[runtime_truth] ${name} health probe returned malformed JSON. ${error instanceof Error ? error.message : String(error)}`,
        );
      }

      if (body.status !== 'UP') {
        dumpComposeDiagnostics();
        throw new Error(`[runtime_truth] ${name} health probe returned status=${body.status ?? 'missing'}.`);
      }

      console.log(`[runtime_truth] ${name} actuator status=UP`);
      return;
    } catch (error) {
      if (error instanceof TypeError) {
        if (Date.now() - startedAt >= timeoutMs) {
          dumpComposeDiagnostics();
          throw new Error(`[runtime_truth] ${name} health did not become ready within ${timeoutMs}ms: ${url}. ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, composePollIntervalMs));
        continue;
      }

      throw error;
    }
  }

  dumpComposeDiagnostics();
  throw new Error(`[runtime_truth] ${name} health did not become ready within ${timeoutMs}ms: ${url}`);
}

async function waitForAdminWeb(timeoutMs: number) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(adminWebUrl);
      if (!response.ok) {
        dumpComposeDiagnostics();
        throw new Error(`[runtime_truth] admin-web landing page returned HTTP ${response.status}.`);
      }

      const body = await response.text();
      if (!body.includes('BabyTalk Admin')) {
        dumpComposeDiagnostics();
        throw new Error('[runtime_truth] admin-web landing page did not contain the BabyTalk Admin marker.');
      }

      console.log('[runtime_truth] admin-web landing page responded with the BabyTalk Admin shell');
      return;
    } catch (error) {
      if (error instanceof TypeError) {
        if (Date.now() - startedAt >= timeoutMs) {
          dumpComposeDiagnostics();
          throw new Error(`[runtime_truth] admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}. ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, composePollIntervalMs));
        continue;
      }

      throw error;
    }
  }

  dumpComposeDiagnostics();
  throw new Error(`[runtime_truth] admin-web did not become ready within ${timeoutMs}ms: ${adminWebUrl}`);
}

function dumpComposeDiagnostics() {
  console.error('');
  console.error('[compose-runtime] diagnostics (sanitized):');

  for (const [label, command, args] of [
    ['docker version', 'docker', ['version']],
    ['docker compose ps --all', 'docker', ['compose', 'ps', '--all']],
    ['docker compose logs --tail 120', 'docker', ['compose', 'logs', '--no-color', '--tail', '120', ...composeDiagnosticServices]],
  ] as const) {
    const result = runCapture(command, args, label, { allowFailure: true });
    const output = combinedOutput(result);
    if (output) {
      console.error(`[compose-runtime] ${label}`);
      console.error(redactSensitiveText(output));
    }
  }
}

function redactSensitiveText(text: string): string {
  let redacted = text;
  redacted = redacted.replace(/Bearer\s+[A-Za-z0-9\-._~+/]+=*/gi, 'Bearer [REDACTED]');
  redacted = redacted.replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, '[REDACTED_JWT]');
  redacted = redacted.replace(
    /((?:password|secret|token|jwt|authorization)[^:=\n\r]{0,40}[:=]\s*)([^\s,;]+)/gi,
    '$1[REDACTED]',
  );
  redacted = redacted.replaceAll('SuperAdmin123!', '[REDACTED]');
  redacted = redacted.replaceAll('babytalk123', '[REDACTED]');
  return redacted;
}

export default async function globalSetup() {
  console.log(`[compose-runtime] mode=${reuseComposeBoot ? 'reuse' : 'playwright-owned-boot'} docker_api_version=${dockerApiVersion}`);

  if (!reuseComposeBoot) {
    run('docker', ['compose', 'up', '-d', '--build', ...composeServiceOrder], 'compose_boot', {
      dumpDiagnosticsOnFailure: true,
    });
  }

  try {
    const composeState = await waitForComposeRuntimeTruth(240_000);
    for (const serviceName of composeServiceOrder) {
      console.log(`[compose-runtime] ${formatComposeState(serviceName, composeState.get(serviceName))}`);
    }
    await waitForHealth('app-api', appApiHealthUrl, 180_000);
    await waitForHealth('admin-api', adminApiHealthUrl, 180_000);
    await waitForAdminWeb(180_000);
  } catch (error) {
    if (reuseComposeBoot) {
      throw new Error(
        `[runtime_truth] BABY_TALK_PLAYWRIGHT_SKIP_COMPOSE_BOOT=1 was set, but the verifier-owned runtime is not reusable. ${error instanceof Error ? error.message : String(error)}`,
      );
    }

    throw error;
  }
}
