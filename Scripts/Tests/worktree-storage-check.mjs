import process from "node:process";
import { Buffer } from "node:buffer";
import console from "node:console";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawn } from "node:child_process";
import { pathToFileURL } from "node:url";

const moduleFile = path.resolve(process.argv[2]);
const {
  storagePolicy: policy,
  storageProfile,
  populateWorktree,
} = await import(pathToFileURL(moduleFile));
const repo = path.resolve(path.dirname(moduleFile), "../..");
const directory = fs.mkdtempSync(path.join(os.tmpdir(), "worktree-storage-"));
const main = path.join(directory, "main");
fs.mkdirSync(main);
const env = {
  ...process.env,
  GIT_AUTHOR_NAME: "Fixture",
  GIT_AUTHOR_EMAIL: "fixture@example.invalid",
  GIT_COMMITTER_NAME: "Fixture",
  GIT_COMMITTER_EMAIL: "fixture@example.invalid",
};
const git = (cwd, ...args) =>
  execFileSync("git", ["-c", "core.fsmonitor=false", ...args], {
    cwd,
    env,
    encoding: "utf8",
    stdio: "pipe",
  }).trim();
const write = (file, bytes) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, bytes);
};
const sourceFile = policy.sources[0] + "/master.bin";
const retained = policy.prepared[0] + "/ready.bin";
const executable = policy.prepared[0] + "/executable.bin";
let serial = 0;
const add = (options = {}, native = {}) => {
  const target = path.join(directory, `task-${++serial}`);
  git(
    main,
    "worktree",
    "add",
    "--no-checkout",
    "-b",
    `task-${serial}`,
    target,
    "main",
  );
  const result = populateWorktree(
    main,
    target,
    storageProfile(main, git(target, "rev-parse", "HEAD"), options),
    native,
  );
  assert.equal(git(target, "status", "--porcelain"), "");
  return { target, result };
};
try {
  git(main, "init", "-q", "-b", "main");
  git(main, "config", "core.hooksPath", "/dev/null");
  for (const [file] of policy.markers)
    write(path.join(main, file), fs.readFileSync(path.join(repo, file)));
  for (const root of policy.prepared)
    write(path.join(main, root, "ready.bin"), Buffer.alloc(384 * 1024, 7));
  write(path.join(main, sourceFile), Buffer.alloc(512 * 1024, 3));
  write(path.join(main, executable), Buffer.alloc(300 * 1024, 8));
  fs.chmodSync(path.join(main, executable), 0o755);
  fs.symlinkSync("ready.bin", path.join(main, policy.prepared[0], "link"));
  write(
    path.join(main, policy.prepared[0], "filtered.bin"),
    Buffer.from("raw\n".repeat(80 * 1024)),
  );
  write(
    path.join(main, ".gitattributes"),
    `* text=auto eol=lf\n*.bin -text\n${policy.prepared[0]}/filtered.bin filter=fixture\n`,
  );
  git(main, "config", "filter.fixture.smudge", "sed s/raw/prepared/g");
  git(main, "config", "filter.fixture.clean", "sed s/prepared/raw/g");
  git(main, "add", ".");
  git(main, "commit", "-qm", "fixture");
  const original = git(main, "rev-parse", "HEAD");
  assert(storageProfile(main, original).capable);
  const normal = add();
  assert(!fs.existsSync(path.join(normal.target, sourceFile)));
  assert(fs.existsSync(path.join(normal.target, retained)));
  assert(
    fs
      .readFileSync(
        path.join(normal.target, policy.prepared[0], "filtered.bin"),
        "utf8",
      )
      .startsWith("prepared\n"),
  );
  assert.equal(
    fs.readlinkSync(path.join(normal.target, policy.prepared[0], "link")),
    "ready.bin",
  );
  assert(fs.statSync(path.join(normal.target, executable)).mode & 0o111);
  assert.equal(fs.readFileSync(path.join(main, sourceFile))[0], 3);
  if (process.platform === "darwin" && !normal.result.fallback)
    assert(normal.result.clonedFiles >= 2, JSON.stringify(normal.result));
  assert.notEqual(
    fs.statSync(path.join(main, retained)).ino,
    fs.statSync(path.join(normal.target, retained)).ino,
  );
  write(path.join(normal.target, retained), "task edit");
  assert.equal(fs.readFileSync(path.join(main, retained))[0], 7);
  write(path.join(main, executable), "source edit");
  assert.equal(fs.readFileSync(path.join(normal.target, executable))[0], 8);
  git(main, "restore", executable);
  git(normal.target, "restore", retained);
  git(normal.target, "sparse-checkout", "disable");
  assert.equal(fs.readFileSync(path.join(normal.target, sourceFile))[0], 3);
  assert.equal(git(normal.target, "status", "--porcelain"), "");

  const full = add({ fullAssets: true });
  assert.equal(fs.readFileSync(path.join(full.target, sourceFile))[0], 3);
  assert.equal(full.result.omittedBytes, 0);
  // Filtered checkout representations always belong to Git.
  const attempted = [];
  const fallback = add(
    {},
    {
      platform: "darwin",
      cloneFile(from, to) {
        attempted.push(from);
        write(to, "partial");
        const error = new Error("injected clone failure");
        error.code = "EIO";
        throw error;
      },
    },
  );
  assert.equal(fallback.result.clonedFiles, 0);
  assert.equal(fs.readFileSync(path.join(fallback.target, retained))[0], 7);
  assert(!attempted.some((file) => file.endsWith("filtered.bin")));
  assert(attempted.length >= 2);
  for (const code of ["ENOTSUP", "EXDEV"]) {
    const nativeFallback = add(
      {},
      {
        platform: "darwin",
        cloneFile() {
          const error = new Error("unsupported fixture filesystem");
          error.code = code;
          throw error;
        },
      },
    );
    assert.equal(nativeFallback.result.clonedFiles, 0);
    assert.equal(
      fs.readFileSync(path.join(nativeFallback.target, retained))[0],
      7,
    );
  }
  const unsupported = add({}, { platform: "linux" });
  assert.equal(unsupported.result.clonedFiles, 0);
  assert.equal(fs.readFileSync(path.join(unsupported.target, retained))[0], 7);

  write(path.join(main, retained), "dirty source");
  const dirty = add();
  assert.equal(fs.readFileSync(path.join(dirty.target, retained))[0], 7);
  assert.equal(
    fs.readFileSync(path.join(main, retained), "utf8"),
    "dirty source",
  );
  git(main, "restore", retained);
  // A changed source during copying is rejected even when the copy looked valid.
  const raced = add(
    {},
    {
      platform: "darwin",
      cloneFile(from, to) {
        fs.copyFileSync(from, to);
        write(from, "raced");
      },
    },
  );
  assert.equal(raced.result.clonedFiles, 0);
  assert.equal(fs.readFileSync(path.join(raced.target, retained))[0], 7);
  git(main, "restore", ".");

  write(path.join(main, "advance"), "main advanced");
  git(main, "add", ".");
  git(main, "commit", "-qm", "advance");
  const mismatched = path.join(directory, "mismatched");
  git(
    main,
    "worktree",
    "add",
    "--no-checkout",
    "--detach",
    mismatched,
    original,
  );
  const mismatch = populateWorktree(
    main,
    mismatched,
    storageProfile(main, original),
  );
  assert.equal(mismatch.clonedFiles, 0);
  assert.equal(fs.readFileSync(path.join(mismatched, retained))[0], 7);
  git(full.target, "switch", "--detach", "main");
  assert(fs.existsSync(path.join(full.target, "advance")));
  git(full.target, "switch", "--detach", original);
  assert(!fs.existsSync(path.join(full.target, "advance")));
  write(path.join(normal.target, "task-owned"), "committed independently");
  git(normal.target, "add", "task-owned");
  git(normal.target, "commit", "-qm", "task");
  assert(!fs.existsSync(path.join(main, "task-owned")));
  git(main, "worktree", "remove", normal.target);
  assert(!git(main, "worktree", "list", "--porcelain").includes(normal.target));

  // A gitlink in a source root keeps the full Git representation; it is never cloned.
  const gitlink = policy.sources[0] + "/submodule";
  git(
    main,
    "update-index",
    "--add",
    "--cacheinfo",
    "160000",
    original,
    gitlink,
  );
  git(main, "commit", "-qm", "source submodule");
  assert.equal(storageProfile(main, "HEAD").capable, false);
  const withSubmodule = add();
  assert.equal(
    fs.readFileSync(path.join(withSubmodule.target, sourceFile))[0],
    3,
  );
  git(main, "update-index", "--force-remove", gitlink);
  git(main, "commit", "-qm", "remove fixture submodule");

  // Capability failure uses a full normal checkout, including source masters.
  const marker = policy.markers[0][0];
  git(main, "rm", marker);
  git(main, "commit", "-qm", "old revision without prepared-only capability");
  assert.equal(
    storageProfile(main, git(main, "rev-parse", "HEAD")).capable,
    false,
  );
  const legacy = add();
  assert.equal(fs.readFileSync(path.join(legacy.target, sourceFile))[0], 3);

  // Simultaneous creation owns separate indexes; Git arbitrates the same path.
  const child = path.join(directory, "child.mjs");
  write(
    child,
    `import {execFileSync} from 'node:child_process'; import {storageProfile,populateWorktree} from ${JSON.stringify(pathToFileURL(moduleFile).href)}; const [root,target]=process.argv.slice(2); execFileSync('git',['worktree','add','--no-checkout','--detach',target,'main'],{cwd:root,stdio:'pipe'}); populateWorktree(root,target,storageProfile(root,'main'));`,
  );
  const start = (target) =>
    new Promise((resolve) => {
      const process = spawn(
        globalThis.process.execPath,
        [child, main, target],
        { env, stdio: "pipe" },
      );
      let errors = "";
      process.stderr.on("data", (data) => {
        errors += data;
      });
      process.on("exit", (code) => resolve({ code, errors }));
    });
  const targets = [
    path.join(directory, "parallel-one"),
    path.join(directory, "parallel-two"),
  ];
  const outcomes = await Promise.all(targets.map(start));
  assert(
    outcomes.every((result) => result.code === 0),
    JSON.stringify(outcomes),
  );
  for (const target of targets)
    assert.equal(git(target, "status", "--porcelain"), "");
  const collision = path.join(directory, "collision");
  const same = await Promise.all([start(collision), start(collision)]);
  assert.equal(
    same.filter((result) => result.code === 0).length,
    1,
    JSON.stringify(same),
  );
  assert.equal(git(collision, "status", "--porcelain"), "");
  console.log(
    "PASS: default/full/legacy, independent writes, clean status, restore, filter/symlink/mode, dirty/racing/mismatched source, native failure rollback, unsupported platform, switch/commit/removal and concurrent creation",
  );
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
