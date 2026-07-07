#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path

def resolve_file_path(file_path):
    if not file_path:
        return file_path
    p = Path(file_path)
    if p.exists() and p.is_absolute():
        return str(p.absolute())
    basename = os.path.basename(file_path)
    for root, dirs, files in os.walk(os.getcwd()):
        if ".DerivedData" in root or ".git" in root or "build" in root:
            continue
        if basename in files:
            return os.path.join(root, basename)
    return file_path

def run_xcresulttool(xcresult_path, cmd_args):
    cmd = ["xcrun", "xcresulttool"] + cmd_args + ["--path", str(xcresult_path), "--format", "json"]
    if "test-results" not in cmd_args and "get" in cmd_args:
        try:
            get_idx = cmd.index("get")
            cmd.insert(get_idx + 1, "--legacy")
        except ValueError:
            pass
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None
    try:
        return json.loads(res.stdout)
    except Exception:
        return None

def find_failed_tests(node, path=[]):
    node_type = node.get("_type", {}).get("_name", "")
    node_name = node.get("name", {}).get("_value", "")
    
    if node_type == "ActionTestMetadata":
        status = node.get("testStatus", {}).get("_value", "")
        if status == "Failure":
            ref_id = node.get("summaryRef", {}).get("id", {}).get("_value")
            clean_path = [p for p in path if p not in ["Selected tests", "TrinketUITests.xctest", "TrinketTests.xctest"]]
            full_name = "/".join(clean_path + [node_name])
            return [(full_name, ref_id)]
        return []
    
    failures = []
    current_path = path + [node_name] if node_name else path
    if "subtests" in node:
        for sub in node["subtests"].get("_values", []):
            failures.extend(find_failed_tests(sub, current_path))
    return failures

def get_clean_attachment_name(name, filename):
    name_lower = name.lower()
    if filename.endswith(".png") or "screenshot" in name_lower or "snapshot" in name_lower:
        return "failure_screenshot.png"
    elif filename.endswith(".mp4") or "screenrecording" in name_lower:
        return "failure_recording.mp4"
    elif "ui hierarchy" in name_lower or "accessibility hierarchy" in name_lower:
        return "ui_hierarchy.txt"
    elif name.startswith("Debug description for"):
        return None
    elif filename:
        return filename
    else:
        return name

def process_activities(activities, indent=""):
    lines = []
    attachments = []
    for act in activities:
        title = act.get("title", {}).get("_value", "No Title")
        duration = act.get("duration", {}).get("_value", "0")
        
        lines.append(f"{indent}• {title} ({float(duration):.2f}s)")
        
        atts = act.get("attachments", {}).get("_values", [])
        for att in atts:
            name = att.get("name", {}).get("_value", "attachment")
            filename = att.get("filename", {}).get("_value", "")
            payload_id = att.get("payloadRef", {}).get("id", {}).get("_value")
            if payload_id:
                attachments.append({
                    "name": name,
                    "filename": filename,
                    "payload_id": payload_id,
                    "activity_title": title
                })
        
        if "subactivities" in act:
            sub_lines, sub_atts = process_activities(act["subactivities"].get("_values", []), indent + "  ")
            lines.extend(sub_lines)
            attachments.extend(sub_atts)
            
    return lines, attachments

def export_attachment(xcresult_path, payload_id, output_path):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "xcrun", "xcresulttool", "export", "--legacy",
        "--path", str(xcresult_path),
        "--id", payload_id,
        "--output-path", str(output_path),
        "--type", "file"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def fallback_summary(xcresult_path):
    try:
        raw = subprocess.check_output(
            ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(xcresult_path), "--format", "json"],
            text=True,
            stderr=subprocess.DEVNULL
        )
        data = json.loads(raw)
        failures = data.get("testFailures", [])
        if not failures:
            sys.exit(0)

        print("\n\033[1;31m=== TEST FAILURES SUMMARY ===\033[0m")
        for f in failures:
            name = f.get("testIdentifierString", f.get("testName", "unknown"))
            text = f.get("failureText", "No failure details").strip()
            print(f"\033[1m  • {name}\033[0m")
            print(f"    \033[31m{text}\033[0m\n")
    except Exception as e:
        print(f"Warning: Failed to parse test failure summary: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: summarize-failures.py <path-to-xcresult>")
        sys.exit(1)

    xcresult_path = Path(sys.argv[1])
    if not xcresult_path.exists():
        sys.exit(0)

    # 1. Load ActionsInvocationRecord
    root = run_xcresulttool(xcresult_path, ["get"])
    if not root:
        fallback_summary(xcresult_path)
        sys.exit(0)

    # 2. Get testsRef from actionResult
    actions = root.get("actions", {}).get("_values", [])
    tests_ref_id = None
    for a in actions:
        ref = a.get("actionResult", {}).get("testsRef", {})
        if ref:
            tests_ref_id = ref.get("id", {}).get("_value")
            break

    failed_details = []
    if tests_ref_id:
        test_run_summaries = run_xcresulttool(xcresult_path, ["get", "--id", tests_ref_id])
        if test_run_summaries:
            failures = []
            summaries = test_run_summaries.get("summaries", {}).get("_values", [])
            for s in summaries:
                for ts in s.get("testableSummaries", {}).get("_values", []):
                    for t in ts.get("tests", {}).get("_values", []):
                        failures.extend(find_failed_tests(t))
            
            for name, ref_id in failures:
                test_summary = run_xcresulttool(xcresult_path, ["get", "--id", ref_id])
                if test_summary:
                    failed_details.append((name, test_summary))

    if failed_details:
        print("\n\033[1;31m=== TEST FAILURES DETAILS ===\033[0m")
        for name, detail in failed_details:
            print(f"\n\033[1m• {name}\033[0m")
            
            fail_summaries = detail.get("failureSummaries", {}).get("_values", [])
            for fs in fail_summaries:
                msg = fs.get("message", {}).get("_value", "No failure details")
                file_path = fs.get("fileName", {}).get("_value")
                line_number = fs.get("lineNumber", {}).get("_value")
                
                if file_path:
                    resolved = resolve_file_path(file_path)
                    if line_number is not None:
                        print(f"  \033[36mFile:\033[0m {resolved}:{line_number}")
                    else:
                        print(f"  \033[36mFile:\033[0m {resolved}")
                
                print(f"  \033[31mError:\033[0m {msg.strip()}")

            act_values = detail.get("activitySummaries", {}).get("_values", [])
            if act_values:
                print("\n  \033[1mSteps:\033[0m")
                act_lines, attachments = process_activities(act_values, "    ")
                for line in act_lines:
                    if "triage" in line.lower() or "screenshot of target" in line.lower():
                        print(f"\033[33m{line}\033[0m")
                    else:
                        print(f"\033[90m{line}\033[0m")

                if attachments:
                    print("\n  \033[1mAssets:\033[0m")
                    clean_dir_name = name.replace("()", "").replace("/", "_")
                    output_dir = xcresult_path.parent / "failures" / clean_dir_name
                    
                    exported_paths = set()
                    for att in attachments:
                        clean_name = get_clean_attachment_name(att["name"], att["filename"])
                        if clean_name is None:
                            continue
                        out_file = output_dir / clean_name
                        out_file_abs = str(out_file.absolute())
                        if out_file_abs in exported_paths:
                            continue
                        if export_attachment(xcresult_path, att["payload_id"], out_file):
                            exported_paths.add(out_file_abs)
                            emoji = "📄"
                            if "screenshot" in clean_name:
                                emoji = "📸"
                            elif "recording" in clean_name:
                                emoji = "🎥"
                            print(f"    {emoji} {att['name']}: \033[4mfile://{out_file.absolute()}\033[0m")
            print()
    else:
        issue_failures = root.get("issues", {}).get("testFailureSummaries", {}).get("_values", [])
        if issue_failures:
            print("\n\033[1;31m=== TEST FAILURES SUMMARY ===\033[0m")
            for f in issue_failures:
                name = f.get("testCaseName", {}).get("_value", "unknown")
                text = f.get("message", {}).get("_value", "No failure details").strip()
                loc = f.get("documentLocationInCreatingWorkspace", {})
                url_str = loc.get("url", {}).get("_value", "")
                
                file_path = ""
                line_number = ""
                if url_str.startswith("file://"):
                    parts = url_str[7:].split("#")
                    file_path = parts[0]
                    if len(parts) > 1:
                        params = dict(p.split("=") for p in parts[1].split("&") if "=" in p)
                        line_idx = params.get("StartingLineNumber")
                        if line_idx is not None:
                            line_number = str(int(line_idx) + 1)
                
                print(f"\033[1m  • {name}\033[0m")
                if file_path:
                    resolved = resolve_file_path(file_path)
                    if line_number:
                        print(f"    \033[36mFile:\033[0m {resolved}:{line_number}")
                    else:
                        print(f"    \033[36mFile:\033[0m {resolved}")
                print(f"    \033[31m{text}\033[0m\n")
        else:
            fallback_summary(xcresult_path)

if __name__ == "__main__":
    main()
