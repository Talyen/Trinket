#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
function git(args, cwd = source) {
  const result = spawnSync("git", args, { cwd, encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr || result.error?.message || `git ${args.join(" ")} failed`);
  return result.stdout.trim();
}
function usage() {
  console.log(`Usage:
  node Scripts/agent-worktree.mjs create --task <slug> [--base <ref>] [--full-assets]
  node Scripts/agent-worktree.mjs integrate [--reviewed-main <commit>] [--keep-plan] [--keep-worktree [--keep-reason <reason>]]
  node Scripts/agent-worktree.mjs cleanup
  node Scripts/agent-worktree.mjs evidence [path...]
  node Scripts/agent-worktree.mjs remove --task <slug>
  node Scripts/agent-worktree.mjs list

Implementation uses .worktrees/<slug> on codex/<slug>, based on local main.
Run integrate from the task worktree: locked rebase, scoped handoff, fast-forward
into primary main, then preserve evidence and remove the completed checkout.
Use --keep-worktree for ongoing work. Cleanup removes only clean integrated work. No push.
See Docs/Platform/Development.md#isolated-chat-workflow for authorization and recovery.`);
}

try {
  const [command, ...args] = process.argv.slice(2);
  if (!command || ["--help", "-h"].includes(command)) {
    usage();
  } else if (["integrate", "evidence", "cleanup"].includes(command)) {
    if (command === "integrate") {
      const seen = new Set();
      for (let index = 0; index < args.length; index++) {
        const option = args[index];
        if (!["--keep-worktree", "--keep-reason", "--reviewed-main", "--keep-plan"].includes(option) || seen.has(option)) throw new Error(`Invalid integration option: ${option}`);
        seen.add(option);
        if (option === "--reviewed-main" && (!args[++index] || !/^[a-f0-9]{40}$/.test(args[index]))) throw new Error("--reviewed-main requires the full reviewed commit ID");
        if (option === "--keep-reason" && (!args[++index]?.trim() || args[index].startsWith("--") || args[index].length > 240)) throw new Error("--keep-reason requires a short reason");
      }
      if (seen.has("--keep-reason") && !seen.has("--keep-worktree")) throw new Error("--keep-reason requires --keep-worktree");
    }
    if (command === "cleanup" && args.length) throw new Error("cleanup takes no arguments");
    const result = spawnSync("python3", [path.join(source, "Scripts/agent-integrate.py"), ...(command === "integrate" ? [] : [`--${command}`]), ...args], { cwd: source, stdio: "inherit" });
    process.exitCode = result.status ?? 1;
  } else {
    if (!["create", "remove", "list"].includes(command)) throw new Error(`Unknown command: ${command}`);
    const options = {};
    for (let index = 0; index < args.length; index += 2) {
      const key = args[index];
      if (command === "create" && key === "--full-assets" && !(key in options)) {
        options[key] = true; index--; continue;
      }
      if (!["--task", ...(command === "create" ? ["--base"] : [])].includes(key)
          || !args[index + 1] || args[index + 1].startsWith("--") || key in options) {
        throw new Error(`Invalid argument: ${key}`);
      }
      options[key] = args[index + 1];
    }
    if (command === "list") {
      if (args.length) throw new Error("list takes no arguments");
      console.log(git(["worktree", "list"]));
    } else {
      const task = options["--task"];
      if (!task || !/^[a-z0-9][a-z0-9_-]{0,63}$/.test(task)) throw new Error("--task requires a lowercase slug (1–64 letters, digits, underscores or hyphens)");
      const records = git(["worktree", "list", "--porcelain", "-z"]).split("\0\0").map(record => record.split("\0"));
      if (records[0].includes("bare") || !records[0][0].startsWith("worktree ")) throw new Error("Non-bare primary checkout required");
      const primary = records[0][0].slice("worktree ".length);
      const destination = path.join(primary, ".worktrees", task);
      const branch = `codex/${task}`;
      if (command === "create") {
        if (fs.existsSync(destination)) throw new Error(`Worktree already exists: ${destination}. Reuse it for this task only.`);
        // Refuse existing branches rather than accidentally reusing another chat's work.
        git(["rev-parse", "--verify", `${options["--base"] ?? "main"}^{commit}`], primary);
        const retention = path.join(source, "Scripts/cleanup-outputs.py");
        if (fs.existsSync(retention)) {
          const maintenance = spawnSync("python3", [retention, "--apply", "--primary", "--intermediates-only", "--products", "--receipt", path.join(primary, ".DerivedData/Retention/latest-intermediates.json")], { cwd: source, encoding: "utf8", timeout: 20_000 });
          if (maintenance.status !== 0) console.log("Idle compiler cleanup deferred; active or unavailable ownership is preserved.");
          else if (maintenance.stdout.trim()) console.log(maintenance.stdout.trim());
        }
        const evidence = path.join(source, "Scripts/agent-integrate.py");
        if (fs.existsSync(evidence)) {
          const maintenance = spawnSync("python3", [evidence, "--expire-routine-evidence"], { cwd: source, encoding: "utf8", timeout: 20_000 });
          if (maintenance.status !== 0) console.log("Routine evidence expiry deferred; retained evidence is preserved.");
          else if (maintenance.stdout.trim()) console.log(maintenance.stdout.trim());
        }
        const compaction = path.join(source, "Scripts/compact-evidence.py");
        if (fs.existsSync(compaction)) {
          const maintenance = spawnSync("python3", [compaction], { cwd: source, encoding: "utf8", timeout: 20_000 });
          if (maintenance.status !== 0) console.log("Evidence compaction deferred; original paths remain available.");
          else if (maintenance.stdout.trim()) console.log(maintenance.stdout.trim());
        }
        fs.mkdirSync(path.dirname(destination), { recursive: true });
        console.log(git(["worktree", "add", "--no-checkout", "-b", branch, destination, options["--base"] ?? "main"], primary));
        const { storageProfile, populateWorktree } = await import("./lib/worktree-storage.mjs");
        populateWorktree(primary, destination, storageProfile(primary, git(["rev-parse", "HEAD"], destination), { fullAssets: options["--full-assets"] }));
        console.log(`Work in ${destination}\nLand there with: node Scripts/agent-worktree.mjs integrate`);
      } else {
        const registered = records.find(record => record.includes(`worktree ${destination}`));
        if (!registered || !registered.includes(`branch refs/heads/${branch}`)) throw new Error(`Refusing unregistered or unexpected worktree: ${destination}`);
        if (source === path.resolve(destination)) throw new Error("Run remove from the primary checkout after leaving the task worktree");
        if (git(["status", "--porcelain", "--untracked-files=all"], destination)) throw new Error("Dirty worktree preserved; commit and integrate task work first");
        if (git(["ls-files", "--others", "--ignored", "--exclude-standard"], destination)) throw new Error("Ignored files preserved; archive needed assets/outputs before cleanup");
        git(["merge-base", "--is-ancestor", branch, "main"], primary);
        console.log(git(["worktree", "remove", destination], primary));
        // Retain the merged branch as a recovery pointer; no forced deletion.
        console.log(`Removed ${destination}; retained ${branch} for recovery.`);
      }
    }
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
