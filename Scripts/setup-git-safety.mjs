#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";

const currentFile = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(currentFile), "..");
const shimDir = path.join(root, "Scripts/bin");
const line = `export PATH="${shimDir}:$PATH"  # Trinket git safety shim (auto-backup on destructive git)`;

function ensureLine(filePath) {
  let content = "";
  try {
    content = fs.readFileSync(filePath, "utf8");
  } catch {}
  if (content.includes(shimDir)) {
    console.log(`ok: ${filePath} already contains shim`);
    return;
  }
  const append = content.endsWith("\n") || content === "" ? "" : "\n";
  fs.appendFileSync(filePath, `${append}${line}\n`);
  console.log(`added shim to ${filePath}`);
}

const home = os.homedir();
for (const rc of [".zshrc", ".bashrc", ".bash_profile"]) {
  const p = path.join(home, rc);
  if (fs.existsSync(p) || rc === ".zshrc") ensureLine(p);
}

const envrc = path.join(root, ".envrc");
let envrcContent = "";
try {
  envrcContent = fs.readFileSync(envrc, "utf8");
} catch {}
if (!envrcContent.includes(shimDir)) {
  const addition = `export PATH="${shimDir}:$PATH"\n`;
  fs.appendFileSync(envrc, envrcContent.endsWith("\n") || envrcContent === "" ? addition : `\n${addition}`);
  console.log(`added shim to ${envrc} (direnv)`);
  try {
    const { spawnSync } = await import("node:child_process");
    spawnSync("direnv", ["allow", root], { stdio: "ignore" });
  } catch {}
} else {
  console.log(`ok: ${envrc} already contains shim`);
}

const globalWrapperDir = path.join(home, ".local/bin");
const globalWrapper = path.join(globalWrapperDir, "git");
try {
  fs.mkdirSync(globalWrapperDir, { recursive: true });
  const wrapperContent = `#!/usr/bin/env sh
# Global harness-agnostic shim: if inside Trinket repo, delegate to repo guard
case "$(pwd)" in
  "${root}"* ) exec "${shimDir}/git" "$@" ;;
  *)
    for cand in /opt/homebrew/bin/git /usr/local/bin/git /usr/bin/git; do
      if [ -x "$cand" ]; then exec "$cand" "$@"; fi
    done
    exec git "$@"
    ;;
esac
`;
  if (!fs.existsSync(globalWrapper) || !fs.readFileSync(globalWrapper, "utf8").includes(shimDir)) {
    fs.writeFileSync(globalWrapper, wrapperContent, { mode: 0o755 });
    console.log(`installed global wrapper at ${globalWrapper}`);
  } else {
    console.log(`ok: ${globalWrapper} already installed`);
  }
} catch (e) {
  console.log(`global wrapper skipped: ${e.message}`);
}

console.log(`\nShim installed at ${shimDir}/git`);
console.log(`Restart shells or run: export PATH="${shimDir}:$PATH"`);
