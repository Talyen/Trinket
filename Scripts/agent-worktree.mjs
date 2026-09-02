#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFile = fileURLToPath(import.meta.url);
const root = path.resolve(path.dirname(currentFile), "..");
const WORKTREE_ROOT = path.join(root, ".worktrees");

function runGit(args, opts = {}) {
  const result = spawnSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: opts.stdio ?? "pipe",
  });
  return result;
}

function usage() {
  console.log(`Usage:
  node Scripts/agent-worktree.mjs create --task <slug> [--base <branch>]
  node Scripts/agent-worktree.mjs remove --task <slug> [--force]
  node Scripts/agent-worktree.mjs list
  node Scripts/agent-worktree.mjs prune
  node Scripts/agent-worktree.mjs legacy-detach create <slug>
  node Scripts/agent-worktree.mjs legacy-detach list
  node Scripts/agent-worktree.mjs legacy-detach remove <slug>

Creates isolated worktrees under .worktrees/<slug> on branch agent/<slug>.
Use when another agent has dirty work on main to avoid shared-checkout races.
legacy-detach keeps the old sibling ../Trinket-<slug> --detach workflow.
`);
}

function slugify(s) {
  return s
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-_]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

const [cmd, ...rest] = process.argv.slice(2);

function getArg(name) {
  const idx = rest.indexOf(name);
  if (idx === -1) return null;
  return rest[idx + 1] ?? null;
}

function hasFlag(name) {
  return rest.includes(name);
}

if (!cmd || cmd === "--help" || cmd === "-h") {
  usage();
  process.exit(0);
}

if (cmd === "list") {
  const r = runGit(["worktree", "list"], { stdio: "inherit" });
  process.exit(r.status ?? 0);
}

if (cmd === "prune") {
  const r = runGit(["worktree", "prune", "-v"], { stdio: "inherit" });
  process.exit(r.status ?? 0);
}

if (cmd === "create") {
  const taskRaw = getArg("--task");
  if (!taskRaw) {
    console.error("missing --task <slug>");
    usage();
    process.exit(1);
  }
  const task = slugify(taskRaw);
  if (!task) {
    console.error("invalid --task slug");
    process.exit(1);
  }
  const base = getArg("--base") ?? "main";
  const worktreePath = path.join(WORKTREE_ROOT, task);
  const branch = `agent/${task}`;

  if (fs.existsSync(worktreePath)) {
    console.error(`worktree already exists: ${worktreePath}`);
    console.error(`remove with: node Scripts/agent-worktree.mjs remove --task ${task}`);
    process.exit(1);
  }

  const branchExists = runGit(["show-ref", "--verify", `refs/heads/${branch}`]);

  fs.mkdirSync(WORKTREE_ROOT, { recursive: true });

  const args =
    branchExists.status === 0
      ? ["worktree", "add", worktreePath, branch]
      : ["worktree", "add", "-b", branch, worktreePath, base];

  console.log(`▸ git ${args.join(" ")}`);
  const r = runGit(args, { stdio: "inherit" });
  if (r.status !== 0) process.exit(r.status ?? 1);
  console.log(`worktree ready: ${worktreePath} on ${branch} (base ${base})`);
  console.log(`  cd ${path.relative(root, worktreePath)}  # work in isolation`);
  console.log(`  node Scripts/agent-worktree.mjs remove --task ${task}  # after merging to main`);
  process.exit(0);
}

if (cmd === "remove") {
  const taskRaw = getArg("--task");
  if (!taskRaw) {
    console.error("missing --task <slug>");
    usage();
    process.exit(1);
  }
  const task = slugify(taskRaw);
  const worktreePath = path.join(WORKTREE_ROOT, task);
  const branch = `agent/${task}`;
  const force = hasFlag("--force");

  const list = runGit(["worktree", "list", "--porcelain"]);
  const isRegistered = (list.stdout ?? "").includes(worktreePath);

  if (isRegistered) {
    const args = ["worktree", "remove", worktreePath];
    if (force) args.push("--force");
    console.log(`▸ git ${args.join(" ")}`);
    const r = runGit(args, { stdio: "inherit" });
    if (r.status !== 0) process.exit(r.status ?? 1);
  } else if (fs.existsSync(worktreePath)) {
    console.log(`worktree not registered, removing directory ${worktreePath}`);
    fs.rmSync(worktreePath, { recursive: true, force: true });
  } else {
    console.log(`no worktree at ${worktreePath}`);
  }

  const branchExists = runGit(["show-ref", "--verify", `refs/heads/${branch}`]);
  if (branchExists.status === 0) {
    const del = runGit(["branch", force ? "-D" : "-d", branch], { stdio: "inherit" });
    if (del.status !== 0 && !force) {
      console.error(`branch ${branch} not fully merged; use --force to delete`);
      process.exit(del.status ?? 1);
    }
  }

  const prune = runGit(["worktree", "prune"], { stdio: "inherit" });
  process.exit(prune.status ?? 0);
}

if (cmd === "legacy-detach") {
  const sub = rest[0];
  const slugRaw = rest[1];
  const worktreeParent = path.resolve(root, "..");
  const siblingPathFor = (slug) => path.join(worktreeParent, `Trinket-${slug}`);
  if (!sub || sub === "--help" || sub === "-h") {
    usage();
    process.exit(0);
  }
  if (sub === "list") {
    const r = runGit(["worktree", "list"], { stdio: "inherit" });
    process.exit(r.status ?? 0);
  }
  if (sub === "create" || sub === "remove") {
    if (!slugRaw) {
      console.error(`legacy-detach ${sub} requires a <slug>`);
      usage();
      process.exit(1);
    }
    const slug = slugify(slugRaw);
    if (!slug) {
      console.error(`invalid slug: ${slugRaw}`);
      process.exit(1);
    }
    const target = siblingPathFor(slug);
    if (sub === "create") {
      if (fs.existsSync(target)) {
        console.error(`Worktree path already exists: ${target}`);
        process.exit(1);
      }
      const r = runGit(["worktree", "add", "--detach", target, "HEAD"], { stdio: "inherit" });
      if (r.status !== 0) process.exit(r.status ?? 1);
      console.log(`Created worktree: ${target}`);
      console.log(``);
      console.log(`Checked out detached at the current HEAD (same commit as this tree; no new branch).`);
      console.log(`Next:`);
      console.log(`  cd "${target}"`);
      console.log(`  ./Scripts/handoff.sh --isolate --paths <file...>`);
      console.log(``);
      console.log(`Use a unique TRINKET_RUN_ID / --isolate in each worktree so DerivedData and`);
      console.log(`simulators do not collide with peers on this Mac.`);
      process.exit(0);
    } else {
      if (!fs.existsSync(target)) {
        console.error(`No worktree at ${target}`);
        process.exit(1);
      }
      const r = runGit(["worktree", "remove", target], { stdio: "inherit" });
      if (r.status !== 0) process.exit(r.status ?? 1);
      console.log(`Removed worktree: ${target}`);
      process.exit(0);
    }
  }
  console.error(`unknown legacy-detach subcommand: ${sub}`);
  usage();
  process.exit(1);
}

console.error(`unknown command: ${cmd}`);
usage();
process.exit(1);