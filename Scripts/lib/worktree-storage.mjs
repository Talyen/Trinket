import fs from "node:fs";
import { performance } from "node:perf_hooks";
import path from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

// POLICY is repository-local. Keep this helper independent of runtime dependencies.
export const storagePolicy = {
  sources: ["AssetSources"],
  assets: [
    "AssetSources",
    "Trinket/Assets.xcassets",
    "Trinket/Media",
    "Trinket/AppIcon.icon",
  ],
  prepared: [
    "Trinket/Assets.xcassets",
    "Trinket/Media",
    "Trinket/AppIcon.icon",
  ],
  markers: [
    ["Scripts/ci-assets-gate.sh", "--check --outputs-only"],
    ["Scripts/asset-library.py", "outputs_only"],
    [
      "Packages/TrinketContent/Sources/TrinketContent/Generated/PreparedAssets.generated.json",
      '"sources"',
    ],
  ],
};
const POLICY = storagePolicy;
const git = (cwd, args, input) => {
  for (let attempt = 0; ; attempt++) {
    try {
      return execFileSync(
        "git",
        [
          "-c",
          "core.fsmonitor=false",
          "-c",
          "core.untrackedCache=false",
          ...args,
        ],
        {
          cwd,
          input,
          encoding: "utf8",
          maxBuffer: 16 * 1024 * 1024,
          stdio: ["pipe", "pipe", "pipe"],
        },
      );
    } catch (error) {
      // sparse-checkout may initialize shared worktreeConfig concurrently.
      if (
        attempt >= 4 ||
        !/could not lock config file|config\.lock.*File exists/s.test(
          String(error.stderr),
        )
      )
        throw error;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 25);
    }
  }
};
const inside = (file, roots) =>
  roots.some((root) => file.startsWith(root + "/"));
const pattern = (file) => "/" + file.replace(/[\\*?[\]#! ]/g, "\\$&");
function entries(source, commit) {
  return git(source, ["ls-tree", "-rlz", commit])
    .split("\0")
    .filter(Boolean)
    .map((record) => {
      const separator = record.indexOf("\t");
      const metadata = record.slice(0, separator),
        file = record.slice(separator + 1);
      const [mode, type, oid, size] = metadata.trim().split(/\s+/);
      return { file, mode, type, oid, size: Number(size) };
    });
}

export function storageProfile(source, commit, { fullAssets = false } = {}) {
  const tracked = entries(source, commit);
  let capable = false;
  try {
    // Check the target revision, never an uncommitted source checkout's scripts.
    capable =
      POLICY.markers.every(([file, marker]) =>
        git(source, ["show", `${commit}:${file}`]).includes(marker),
      ) &&
      POLICY.prepared.every((root) =>
        tracked.some((entry) => inside(entry.file, [root]) && entry.size > 0),
      ) &&
      !tracked.some(
        (entry) => inside(entry.file, POLICY.sources) && entry.type !== "blob",
      );
  } catch {
    /* Older revisions retain their ordinary full checkout. */
  }
  const omit = capable && !fullAssets ? POLICY.sources : [];
  return {
    tracked,
    omit,
    capable,
    omittedBytes: tracked
      .filter((entry) => inside(entry.file, omit))
      .reduce((sum, entry) => sum + entry.size, 0),
  };
}

function blobHash(file, size, algorithm) {
  const fd = fs.openSync(file, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
  try {
    const hash = createHash(algorithm).update(`blob ${size}\0`);
    const buffer = Buffer.allocUnsafe(1024 * 1024);
    let total = 0;
    for (;;) {
      const length = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (!length) break;
      total += length;
      hash.update(buffer.subarray(0, length));
    }
    return total === size ? hash.digest("hex") : null;
  } finally {
    fs.closeSync(fd);
  }
}

// Node's COPYFILE_FICLONE_FORCE is ENOSYS on Darwin in some supported Node
// releases. Call Apple's clonefile directly in one optional standard-library
// Python process; unlike cp -c, this never silently falls back to a physical copy.
function nativeClones(plans) {
  const script = `import ctypes, errno, json, os, sys
lib = ctypes.CDLL(None, use_errno=True)
clone = lib.clonefile
clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
results = []
unsupported = None
for source, target in json.load(sys.stdin):
    code = unsupported
    if code is None:
        if clone(os.fsencode(source), os.fsencode(target), 1) == 0:
            code = None
        else:
            number = ctypes.get_errno()
            code = errno.errorcode.get(number, str(number))
            if number in (errno.ENOTSUP, errno.EXDEV, errno.ENOSYS, errno.EINVAL):
                unsupported = code
    results.append(code)
json.dump(results, sys.stdout)
`;
  try {
    return JSON.parse(
      execFileSync("python3", ["-c", script], {
        input: JSON.stringify(plans.map(({ from, to }) => [from, to])),
        encoding: "utf8",
        stdio: ["pipe", "pipe", "pipe"],
      }),
    );
  } catch (error) {
    if (plans.some(({ to }) => fs.existsSync(to)))
      throw new Error(
        "Native clone helper ended unexpectedly; inspect preserved checkout before retrying",
      );
    return plans.map(() => (error.code === "ENOENT" ? "ENOSYS" : "ENOTSUP"));
  }
}

// A fresh index belongs to Git. Only large tracked regular files are cloned;
// source/target indexes, dependencies, build databases and symlinks never are.
export function populateWorktree(
  source,
  target,
  profile,
  { cloneFile = null, platform = process.platform } = {},
) {
  source = fs.realpathSync(source);
  target = fs.realpathSync(target);
  const started = performance.now();
  const commit = git(target, ["rev-parse", "HEAD"]).trim();
  let candidates = [],
    reason = "",
    algorithm;
  const config = (cwd, name) => {
    try {
      return git(cwd, ["config", "--get", name]).trim();
    } catch (error) {
      if (error.status === 1) return "";
      throw error;
    }
  };
  try {
    if (
      platform !== "darwin" ||
      fs.statSync(source).dev !== fs.statSync(target).dev
    )
      throw new Error("native file clones unavailable on this platform/volume");
    if (git(source, ["rev-parse", "HEAD"]).trim() !== commit)
      throw new Error("source commit differs");
    for (const cwd of [source, target]) {
      if (
        !["", "false"].includes(config(cwd, "core.autocrlf")) ||
        config(cwd, "core.eol") === "crlf"
      )
        throw new Error("checkout conversion enabled");
    }
  } catch (error) {
    reason = error.message;
  }
  if (!reason) {
    try {
      algorithm = git(source, ["rev-parse", "--show-object-format"]).trim();
      candidates = profile.tracked.filter(
        (entry) =>
          entry.type === "blob" &&
          ["100644", "100755"].includes(entry.mode) &&
          entry.size >= 256 * 1024 &&
          inside(entry.file, POLICY.assets) &&
          !inside(entry.file, profile.omit) &&
          !/[\t\r\n]/.test(entry.file),
      );
      if (candidates.length) {
        const attributes = git(
          target,
          [
            "check-attr",
            `--source=${commit}`,
            "-z",
            "--stdin",
            "filter",
            "working-tree-encoding",
            "text",
            "eol",
            "ident",
          ],
          candidates.map((entry) => entry.file).join("\0") + "\0",
        ).split("\0");
        const values = new Map();
        for (let index = 0; index + 2 < attributes.length; index += 3) {
          const file = attributes[index];
          if (!values.has(file)) values.set(file, {});
          values.get(file)[attributes[index + 1]] = attributes[index + 2];
        }
        const converted = new Set();
        for (const [file, attrs] of values) {
          const active = (name) =>
            !["unspecified", "unset"].includes(attrs[name]);
          // -text/binary disables eol conversion even when eol=lf is inherited.
          if (
            active("filter") ||
            active("working-tree-encoding") ||
            active("ident") ||
            (attrs.text !== "unset" && (active("text") || active("eol")))
          )
            converted.add(file);
        }
        candidates = candidates.filter((entry) => !converted.has(entry.file));
      }
      if (candidates.length) {
        const dirty = new Set(
          git(source, [
            "--no-optional-locks",
            "diff",
            "HEAD",
            "--name-only",
            "-z",
            "--no-ext-diff",
            "--no-textconv",
            "--",
            ...candidates.map((entry) => entry.file),
          ]).split("\0"),
        );
        candidates = candidates.filter((entry) => !dirty.has(entry.file));
      }
    } catch {
      candidates = [];
      reason = "source or checkout attributes could not be verified";
    }
  }
  const sparse = (patterns) =>
    git(target, ["sparse-checkout", "set", "--no-cone", "--stdin"], patterns);
  const finalPatterns =
    "/*\n" + profile.omit.map((root) => `!${pattern(root)}/\n`).join("");
  sparse(
    finalPatterns +
      candidates.map((entry) => `!${pattern(entry.file)}\n`).join(""),
  );
  git(target, ["read-tree", "-mu", "HEAD"]);
  const plans = [];
  for (const entry of candidates) {
    const from = path.join(source, entry.file),
      to = path.join(target, entry.file);
    try {
      const before = fs.lstatSync(from, { bigint: true });
      if (
        !before.isFile() ||
        before.size !== BigInt(entry.size) ||
        fs.realpathSync(from) !== from ||
        Boolean(before.mode & 0o111n) !== (entry.mode === "100755")
      )
        continue;
      fs.mkdirSync(path.dirname(to), { recursive: true });
      if (fs.lstatSync(to, { throwIfNoEntry: false }))
        throw new Error("Unexpected destination file; preserve checkout");
      plans.push({ entry, from, to, before });
    } catch (error) {
      if (error.message.startsWith("Unexpected destination")) throw error;
    }
  }
  const outcomes = cloneFile ? null : plans.length ? nativeClones(plans) : [];
  let clonedFiles = 0,
    clonedBytes = 0;
  const cloned = [];
  for (const [index, { entry, from, to, before }] of plans.entries()) {
    let owned = false;
    try {
      // A dirty/racing source only qualifies if its independent clone still
      // hashes to the target Git blob and its identity/mode remained stable.
      if (cloneFile) {
        owned = true;
        cloneFile(from, to);
      } else {
        if (outcomes[index]) {
          const error = new Error("native clone failed");
          error.code = outcomes[index];
          throw error;
        }
        owned = true;
      }
      const after = fs.lstatSync(from, { bigint: true });
      if (
        before.ino !== after.ino ||
        before.mtimeNs !== after.mtimeNs ||
        before.ctimeNs !== after.ctimeNs ||
        before.mode !== after.mode ||
        blobHash(to, entry.size, algorithm) !== entry.oid
      )
        throw new Error("source changed during clone");
      fs.chmodSync(to, entry.mode === "100755" ? 0o755 : 0o644);
      cloned.push(to);
      clonedFiles++;
      clonedBytes += entry.size;
    } catch (error) {
      if (owned) fs.rmSync(to, { force: true });
      if (error.code === "EEXIST")
        throw new Error("Unexpected destination file; preserve checkout", {
          cause: error,
        });
      reason = error.code
        ? `native clone failed (${error.code}); Git populated remaining files`
        : error.message;
    }
  }
  if (clonedFiles && git(source, ["rev-parse", "HEAD"]).trim() !== commit) {
    for (const file of cloned) fs.rmSync(file, { force: true });
    clonedFiles = 0;
    clonedBytes = 0;
    reason = "source commit changed; Git populated assets";
  }
  if (profile.omit.length) sparse(finalPatterns);
  else git(target, ["sparse-checkout", "disable"]);
  // Populate/refresh with normal Git checks. Include the first status in timing;
  // no copied stat cache, assume-unchanged flags or relaxed stat settings.
  if (git(target, ["status", "--porcelain", "--untracked-files=no"]).trim())
    throw new Error(
      `Worktree population is not clean; inspect preserved checkout ${target}`,
    );
  const result = {
    clonedFiles,
    clonedBytes,
    omittedBytes: profile.omittedBytes,
    seconds: (performance.now() - started) / 1000,
    fallback: reason || null,
  };
  console.log(
    `Storage: ${profile.omit.length ? "code-only" : "full assets"}; omitted ${result.omittedBytes} logical bytes; cloned ${clonedFiles} files (${clonedBytes} logical bytes); population + first status ${result.seconds.toFixed(3)}s${reason ? `; ${reason}` : ""}.`,
  );
  if (profile.omit.length)
    console.log(
      "Restore masters before asset authoring: git sparse-checkout disable (or create with --full-assets).",
    );
  return result;
}
