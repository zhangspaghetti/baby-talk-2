#!/usr/bin/env node
const { spawnSync } = require("node:child_process");
const { existsSync } = require("node:fs");
const path = require("node:path");

const forwardedArgs = process.argv.slice(2);
const tscEntrypoint = path.resolve(__dirname, "../admin-web/node_modules/typescript/bin/tsc");

if (!existsSync(tscEntrypoint)) {
  console.error("TypeScript compiler not found at admin-web/node_modules/typescript/bin/tsc");
  process.exit(1);
}

const passthroughOnly = new Set(["-v", "--version", "-h", "--help"]);
if (forwardedArgs.some((arg) => passthroughOnly.has(arg))) {
  const result = spawnSync(process.execPath, [tscEntrypoint, ...forwardedArgs], { stdio: "inherit" });
  process.exit(result.status ?? 1);
}

const sharedArgs = forwardedArgs.filter((arg) => arg !== "--noEmit");
const projects = ["admin-web/tsconfig.json", "admin-web/tsconfig.node.json"];

for (const project of projects) {
  const result = spawnSync(process.execPath, [tscEntrypoint, "--noEmit", "-p", project, ...sharedArgs], {
    stdio: "inherit"
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}
