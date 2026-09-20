#!/usr/bin/env python3
"""Opt-in prompt evaluation. Standard-library CLI; never discovers API keys."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, encoding="utf-8").strip()


def fixture_hash() -> str:
    digest = hashlib.sha256()
    for name in ("scenarios.json", "gameplay.json"):
        digest.update((ROOT / "tools/prompt_eval/fixtures" / name).read_bytes())
    return digest.hexdigest()


def execute(args: argparse.Namespace, source: Path, revision: str) -> int:
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not args.overwrite:
        raise ValueError("Output already exists; choose another path or pass --overwrite")
    selected = args.scenarios.split(",") if args.scenarios else []
    available = {s["id"] for s in json.loads((ROOT / "tools/prompt_eval/fixtures/scenarios.json").read_text(encoding="utf-8"))["scenarios"]}
    if set(selected) - available:
        raise ValueError("Unknown scenario ID")
    if args.repeats < 1 or args.max_requests < 1 or args.max_output_tokens < 8192:
        raise ValueError("Positive repeats/requests and at least 8192 reserved output tokens are required")
    if args.mode == "live":
        required = ("PROMPT_EVAL_API_URL", "PROMPT_EVAL_API_KEY", "PROMPT_EVAL_MODEL")
        if not all(os.environ.get(name) for name in required):
            raise ValueError("Live mode needs explicit PROMPT_EVAL_API_URL / API_KEY / MODEL environment variables")
    config = {
        "mode": args.mode, "revision": revision, "fixtureHash": fixture_hash(),
        "repeats": args.repeats, "scenarios": selected, "maxRequests": args.max_requests,
        "maxOutputTokens": args.max_output_tokens, "output": str(output),
    }
    config_path = output.with_suffix(".config.json")
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    env = dict(os.environ, PROMPT_EVAL_CONFIG=str(config_path))
    if args.mode != "live":
        # A developer's environment must never turn an offline run into live.
        for name in ("PROMPT_EVAL_API_URL", "PROMPT_EVAL_API_KEY", "PROMPT_EVAL_MODEL"):
            env.pop(name, None)
    command = [args.flutter, "test", "--no-pub", "test/prompt_eval_runner_test.dart", "--reporter", "expanded"]
    print(f"{args.mode}: {len(selected) or 16} scenarios x {args.repeats}; "
          f"at most {args.max_requests} production calls / {args.max_output_tokens} reserved output tokens.")
    print("Fault fixtures and additional repair/continuation calls are itemized. No network retries.")
    completed = subprocess.run(command, cwd=source, env=env)
    if completed.returncode:
        return completed.returncode
    data = json.loads(output.read_text(encoding="utf-8"))
    if data.get("stoppedEarly"):
        print(f"Stopped early; partial results preserved at {output}")
        return 2
    print(f"Saved {len(data['cases'])} results: {output}")
    return 0


def run(args: argparse.Namespace) -> int:
    if not args.ref:
        dirty = bool(git("status", "--porcelain", "--untracked-files=no"))
        revision = git("rev-parse", "HEAD") + ("+worktree" if dirty else "")
        return execute(args, ROOT, revision)
    revision = git("rev-parse", "--verify", f"{args.ref}^{{commit}}")
    # Read a committed tree without checkout, branch changes, or shared caches.
    archive = subprocess.check_output(["git", "archive", "--format=zip", revision], cwd=ROOT)
    scratch_parent = ROOT / ".tmp/prompt-eval-baselines"
    scratch_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="baseline-", dir=scratch_parent) as temp:
        source = Path(temp).resolve()
        with zipfile.ZipFile(io.BytesIO(archive)) as package:
            for member in package.infolist():
                if not (source / member.filename).resolve().is_relative_to(source):
                    raise ValueError("Unsafe path in Git archive")
            package.extractall(source)
        shutil.copytree(ROOT / "tools/prompt_eval", source / "tools/prompt_eval", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(ROOT / "test/prompt_eval_runner_test.dart", source / "test/prompt_eval_runner_test.dart")
        # Resolve cached dependencies only; missing packages fail explicitly.
        subprocess.run([args.flutter, "pub", "get", "--offline"], cwd=source, check=True)
        return execute(args, source, revision)


def build_report(left: dict, right: dict, seed: int = 20260920) -> dict:
    for field in ("fixtureHash", "mode", "model", "endpointHost"):
        if left.get(field) != right.get(field):
            raise ValueError(f"Runs differ in {field}; use the same fixtures, mode, model and endpoint")
    left_cases = {(c["id"], c["repeat"]): c for c in left["cases"]}
    right_cases = {(c["id"], c["repeat"]): c for c in right["cases"]}
    if left_cases.keys() != right_cases.keys():
        raise ValueError("Scenario/repeat sets differ; partial runs cannot be silently compared")
    randomizer = random.Random(seed)
    pairs = []
    for key, first in left_cases.items():
        second = right_cases[key]
        variants = [(left["revision"], first), (right["revision"], second)]
        randomizer.shuffle(variants)
        pairs.append({
            "id": f"{key[0]}-{key[1]}", "title": first["title"], "kind": first["kind"],
            "input": first["input"], "history": first["history"], "characterPrompt": first["characterPrompt"],
            "checks": first["checks"], "faultInjected": first.get("faultInjected", False),
            "variants": [{"revision": revision, "output": case.get("output", ""),
                          "initialOutput": case.get("requests", [{}])[0].get("response", "") if case.get("requests") else "",
                          "firstPassValid": case.get("firstPassValid"), "finalValid": case.get("finalValid"),
                          "firstPassIssues": case.get("firstPassIssues", []), "finalIssues": case.get("finalIssues", []),
                          "additionalRequests": case.get("additionalRequests", 0), "status": case["status"],
                          "requests": [{k: v for k, v in request.items() if k != "payload"} for request in case.get("requests", [])]}
                         for revision, case in variants],
        })
    identity = hashlib.sha256(json.dumps([left["revision"], right["revision"], left["fixtureHash"], pairs], sort_keys=True).encode()).hexdigest()[:20]
    return {"schemaVersion": 1, "mode": left["mode"], "model": left["model"], "reportId": identity,
            "fixtureHash": left["fixtureHash"], "pairs": pairs,
            "note": "Synthetic/mock output is not model quality evidence." if left["mode"] != "live" else "Human review pending. Fault injections excluded from ordinary first-pass rates."}


def report(args: argparse.Namespace) -> int:
    left = json.loads(Path(args.left).read_text(encoding="utf-8"))
    right = json.loads(Path(args.right).read_text(encoding="utf-8"))
    data = build_report(left, right, args.seed)
    template = (ROOT / "tools/prompt_eval/report.html").read_text(encoding="utf-8")
    payload = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(template.replace("__REPORT_DATA__", payload), encoding="utf-8")
    print(f"Blind review report: {output}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    capture = commands.add_parser("run", help="Capture real production requests with synthetic replies, or explicitly call a model")
    capture.add_argument("--mode", choices=("offline", "live"), default="offline")
    capture.add_argument("--ref", help="Read a Git commit/tag in an isolated temporary archive")
    capture.add_argument("--output", required=True)
    capture.add_argument("--repeats", type=int, default=2)
    capture.add_argument("--scenarios", default="", help="Comma-separated scenario IDs; default all 16")
    capture.add_argument("--max-requests", type=int, default=80)
    capture.add_argument("--max-output-tokens", type=int, default=655360)
    capture.add_argument("--flutter", default=shutil.which("flutter") or "flutter")
    capture.add_argument("--overwrite", action="store_true")
    capture.set_defaults(handler=run)
    view = commands.add_parser("report", help="Build a standalone local A/B blind review report")
    view.add_argument("left")
    view.add_argument("right")
    view.add_argument("--output", required=True)
    view.add_argument("--seed", type=int, default=20260920)
    view.set_defaults(handler=report)
    args = parser.parse_args()
    try:
        return args.handler(args)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"Evaluation stopped: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
