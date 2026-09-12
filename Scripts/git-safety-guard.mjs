#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ownShimDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "Scripts", "bin");

const args = process.argv.slice(2);
const optionsWithValues = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"]);
let commandIndex = 0;
while (commandIndex < args.length && args[commandIndex].startsWith("-")) {
  commandIndex += optionsWithValues.has(args[commandIndex]) ? 2 : 1;
}
const globalArgs = args.slice(0, commandIndex);
const commandArgs = args.slice(commandIndex);

function loadDestructiveCommands() {
  try {
    const listPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "config", "destructive-git-commands.txt");
    const names = fs.readFileSync(listPath, "utf8").split("\n").map((s) => s.trim()).filter((s) => s && !s.startsWith("#"));
    if (names.length > 0) return names;
  } catch {}
  return ["reset", "checkout", "restore", "clean", "switch", "branch", "push"];
}

export const DESTRUCTIVE_GIT_COMMANDS = loadDestructiveCommands();

const DESTRUCTIVE = new Set(DESTRUCTIVE_GIT_COMMANDS);

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
  const readOptions = { cwd: process.cwd(), env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" } };
  const diff = spawnSync(realGit, [...globalArgs, "diff", "--quiet"], { ...readOptions, stdio: "ignore" });
  const diffCached = spawnSync(realGit, [...globalArgs, "diff", "--cached", "--quiet"], { ...readOptions, stdio: "ignore" });
  const untracked = spawnSync(realGit, [...globalArgs, "ls-files", "--others", "--exclude-standard"], {
    ...readOptions,
    encoding: "utf8",
  });
  const hasUntracked = untracked.stdout && untracked.stdout.trim().length > 0;
  return diff.status !== 0 || diffCached.status !== 0 || untracked.status !== 0 || hasUntracked;
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
  const result = spawnSync(realGit, gitArgs, { cwd: process.cwd(), stdio: "inherit" });
  process.exit(result.status ?? 1);
}

const realGit = findRealGit();

if (!isDestructive(commandArgs)) {
  execRealGit(realGit, args);
}

if (!hasDirtyTree()) {
  execRealGit(realGit, args);
}

console.error("");
console.error("blocked: destructive git command with dirty or unreadable tree");
console.error(`  attempted: git ${args.join(" ")}`);
console.error("  Working files and index were left in place. Review git status before retrying.");
process.exit(1);
