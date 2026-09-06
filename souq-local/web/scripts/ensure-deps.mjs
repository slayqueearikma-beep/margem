import { accessSync, constants } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const nextPkg = join(root, "node_modules", "next", "package.json");

function hasNext() {
  try {
    accessSync(nextPkg, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

if (hasNext()) {
  process.exit(0);
}

console.log("Installing web dependencies (first run — this can take a minute)...");
const result = spawnSync("npm", ["install"], {
  cwd: root,
  stdio: "inherit",
  env: process.env,
});

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

if (!hasNext()) {
  console.error("npm install finished but next is still missing. Try: rm -rf node_modules && npm install");
  process.exit(1);
}
