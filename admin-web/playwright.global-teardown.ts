import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const currentDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(currentDir, '..');

function run(command: string, args: string[]) {
  spawnSync(command, args, {
    cwd: repoRoot,
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
}

export default async function globalTeardown() {
  run('docker', ['compose', 'stop', 'admin-web', 'admin-api', 'postgres']);
  run('docker', ['compose', 'rm', '-sf', 'admin-web', 'admin-api', 'db-migration', 'postgres']);
}
