#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ownShimDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "Scripts", "bin");

const args = process.argv.slice(2);
const subcommand = args[0] ?? "";

const DESTRUCTIVE = new Set(["reset", "checkout", "restore", "clean", "switch", "branch", "push"]);

function isDestructive(parsedArgs) {
  const cmd = parsedArgs[0];
  if (!DESTRUCTIVE.has(cmd)) return false;

  if (cmd === "reset") {
    return parsedArgs.includes("--hard") || parsedArgs.includes("--merge") || parsedArgs.includes("--keep");
  }
  if (cmd === "checkout") {
    if (parsedArgs.includes("--")) return true;
    if (parsedArgs.includes("-f") || parsedArgs.includes("--force")) return true;
    if (parsedArgs.includes(".")) return true;
    return false;
  }
  if (cmd === "restore") {
    return true;
  }
  if (cmd === "clean") {
    return parsedArgs.some((a) => a.startsWith("-") && a.includes("f"));
  }
  if (cmd === "switch") {
    return parsedArgs.includes("-f") || parsedArgs.includes("--force") || parsedArgs.includes("--discard-changes");
  }
  if (cmd === "branch") {
    return parsedArgs.includes("-D");
  }
  if (cmd === "push") {
    return (
      parsedArgs.includes("--force") || parsedArgs.includes("-f") || parsedArgs.some((a) => a.startsWith("--force"))
    );
  }
  return false;
}

function hasDirtyTree() {
  const diff = spawnSync(realGit, ["diff", "--quiet"], { cwd: process.cwd(), stdio: "ignore" });
  const diffCached = spawnSync(realGit, ["diff", "--cached", "--quiet"], { cwd: process.cwd(), stdio: "ignore" });
  const untracked = spawnSync(realGit, ["ls-files", "--others", "--exclude-standard"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  const hasUntracked = untracked.stdout && untracked.stdout.trim().length > 0;
  return diff.status !== 0 || diffCached.status !== 0 || hasUntracked;
}

function stashBackup(cmd) {
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const msg = `auto-backup pre-${cmd} ${ts}`;
  const result = spawnSync(realGit, ["stash", "push", "-m", msg, "--include-untracked"], {
    cwd: process.cwd(),
    encoding: "utf8",
  });
  return { msg, status: result.status, output: (result.stdout ?? "") + (result.stderr ?? "") };
}

function findRealGit() {
  if (process.env.REAL_GIT) return process.env.REAL_GIT;
  const which = spawnSync("bash", ["-lc", "which -a git 2>/dev/null | head -20"], { encoding: "utf8" });
  const candidates = (which.stdout ?? "")
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean)
    .filter((p) => path.dirname(p) !== ownShimDir);
  if (candidates.length > 0) return candidates[0];
  return "git";
}

function execRealGit(realGit, gitArgs) {
  const bypassEnv = { ...process.env };
  const destructiveAliases = ["reset", "checkout", "restore", "clean", "switch", "branch", "push"];
  let idx = 0;
  for (const a of destructiveAliases) {
    bypassEnv[`GIT_CONFIG_KEY_${idx}`] = `alias.${a}`;
    bypassEnv[`GIT_CONFIG_VALUE_${idx}`] = "";
    idx++;
  }
  bypassEnv.GIT_CONFIG_COUNT = String(idx);
  if (process.env.GIT_CONFIG_COUNT) {
    bypassEnv.GIT_CONFIG_COUNT = String(idx);
  }
  const result = spawnSync(realGit, gitArgs, { cwd: process.cwd(), stdio: "inherit", env: bypassEnv });
  process.exit(result.status ?? 0);
}

const realGit = findRealGit();

if (!isDestructive(args)) {
  execRealGit(realGit, args);
}

if (!hasDirtyTree()) {
  execRealGit(realGit, args);
}

const backup = stashBackup(subcommand || "destructive");
console.error("");
console.error("blocked: destructive git command with dirty tree");
console.error(`  attempted: git ${args.join(" ")}`);
console.error(`  backup: git stash push -m "${backup.msg}" --include-untracked`);
if (backup.output.trim()) console.error(backup.output.trim());
console.error("");
console.error("  Your work was stashed, not lost. Recover with:");
console.error("    git stash list");
console.error(`    git stash show -p stash@{0}   # inspect`);
console.error(`    git stash pop                 # restore`);
console.error("  Or review recent HEAD moves:");
console.error("    git reflog | head -20");
console.error("");
console.error("  To retry after stashing/committing, run the same git command again on a clean tree.");
console.error("  If you have parallel agents, use isolated worktrees instead:");
console.error("    node Scripts/agent-worktree.mjs create --task <slug>");
console.error("    # compat: ./Scripts/agent-worktree.sh create <slug>");
console.error("");
process.exit(1);
