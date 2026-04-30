#!/usr/bin/env python3
"""Wyvrn template-verifier hook.

PostToolUse hook for Write/Edit on `.claude-wyvrn-local/**/*.md`. Replaces the
former `template-verifier` subagent with deterministic structural comparison.

Behaviour:
  1. Resolve the artifact's template via INDEX.md folder mapping. Skip if no
     mapping (e.g., conventions, .archive).
  2. Strip `> [template]` lines from the template per CONVENTIONS.md §4.4.
  3. Verify heading sequence, table headers, list-marker style, placeholder
     replacement, and absence of leaked `> [template]` lines in the artifact.
  4. Append one log line per invocation to
     `.claude-wyvrn-local/.metrics/template-verifier-findings.log` (compliant
     and non-compliant runs both logged — feeds the deferred decision in the
     performance-overhaul roadmap on per-artifact-type opt-out).
  5. Exit 0 (silent) on compliance. Exit 2 with stderr findings on
     non-compliance — Claude Code surfaces stderr back to the model.

Skipped without a finding:
  - Any tool other than Write/Edit/MultiEdit.
  - Any path outside `.claude-wyvrn-local/`.
  - Anything under `.claude-wyvrn-local/.archive/`.
  - Files that are byte-equivalent to the unfilled template (bootstrap state
    per HARNESS.md §3.5).

Input is the standard Claude Code hook JSON on stdin. Output is silent or
stderr text.
"""

from __future__ import annotations

import datetime
import json
import os
import re
import sys
from pathlib import Path

HARNESS_ROOT = Path(os.environ.get("WYVRN_HARNESS") or (Path.home() / ".claude-wyvrn"))
PROJECT_LOCAL_DIR = ".claude-wyvrn-local"
ARCHIVE_DIR = ".archive"
METRICS_RELPATH = Path(".metrics") / "template-verifier-findings.log"
TEMPLATE_MARKER_RE = re.compile(r"^\s*> \[template\]")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
TABLE_SEP_RE = re.compile(r"^\s*\|?\s*:?-{3,}:?(\s*\|\s*:?-{3,}:?)+\s*\|?\s*$")
TABLE_ROW_RE = re.compile(r"^\s*\|.*\|\s*$")
PLACEHOLDER_RE = re.compile(r"<[^<>\n]+>")
LIST_MARKER_RE = re.compile(r"^(\s*)(([-*+])|(\d+)\.|\(?[a-zA-Z]\))\s+\S")


def main() -> int:
    payload = _read_payload()
    if payload is None:
        return 0

    tool_name = payload.get("tool_name", "")
    if tool_name not in {"Write", "Edit", "MultiEdit"}:
        return 0

    file_path = _extract_file_path(payload)
    if file_path is None:
        return 0

    cwd = Path(payload.get("cwd") or os.getcwd())
    artifact_path = _resolve_artifact_path(file_path, cwd)
    if artifact_path is None:
        return 0

    project_local = _find_project_local(artifact_path)
    if project_local is None:
        return 0

    rel = artifact_path.relative_to(project_local)
    if rel.parts and rel.parts[0] == ARCHIVE_DIR:
        return 0

    template_path = _template_for(rel)
    if template_path is None or not template_path.is_file():
        return 0

    if not artifact_path.is_file():
        return 0

    artifact_text = _read_text(artifact_path)
    template_text = _read_text(template_path)

    if artifact_text == template_text:
        # Bootstrap state per HARNESS.md §3.5 — unfilled template byte-equal.
        _log_finding(project_local, rel, template_path, [], note="bootstrap")
        return 0

    findings = _check(template_text, artifact_text)
    _log_finding(project_local, rel, template_path, findings)

    if not findings:
        return 0

    sys.stderr.write(_format_findings(rel, template_path, findings))
    return 2


def _read_payload() -> dict | None:
    try:
        raw = sys.stdin.read()
    except (OSError, ValueError):
        return None
    if not raw.strip():
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def _extract_file_path(payload: dict) -> str | None:
    tool_input = payload.get("tool_input") or {}
    candidate = tool_input.get("file_path") or tool_input.get("path")
    if isinstance(candidate, str) and candidate:
        return candidate
    return None


def _resolve_artifact_path(raw_path: str, cwd: Path) -> Path | None:
    p = Path(raw_path)
    if not p.is_absolute():
        p = (cwd / p).resolve()
    else:
        p = p.resolve()
    if p.suffix.lower() != ".md":
        return None
    return p


def _find_project_local(artifact_path: Path) -> Path | None:
    for parent in artifact_path.parents:
        if parent.name == PROJECT_LOCAL_DIR:
            return parent
    return None


def _load_template_map(harness_root: Path) -> dict[str, str]:
    """Parse INDEX.md's "Artifacts" table to build the folder→template map.

    Each row maps a path under `.claude-wyvrn-local/` to a template file in
    `templates/`. Folder paths key by the last folder segment (e.g.,
    `features/` → `features`); fixed file paths key by the filename (e.g.,
    `ARCHITECTURE.md` → `ARCHITECTURE.md`). Returns an empty map if INDEX.md
    is missing or no Artifacts table is found — the script then skips every
    write silently rather than emitting false findings.
    """
    try:
        text = (harness_root / "INDEX.md").read_text(encoding="utf-8")
    except OSError:
        return {}

    mapping: dict[str, str] = {}
    in_section = False
    seen_separator = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("## "):
            in_section = stripped == "## Artifacts"
            seen_separator = False
            continue
        if not in_section or not stripped.startswith("|"):
            continue
        if not seen_separator:
            if "---" in stripped:
                seen_separator = True
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 3:
            continue
        path_cell = cells[1].strip("` ")
        template_cell = cells[2].strip("` ")
        if not path_cell or not template_cell:
            continue
        template_name = template_cell.rsplit("/", 1)[-1]
        if path_cell.endswith("/"):
            key = path_cell.rstrip("/").rsplit("/", 1)[-1]
        else:
            key = path_cell.rsplit("/", 1)[-1]
        mapping[key] = template_name
    return mapping


def _template_for(rel: Path) -> Path | None:
    parts = rel.parts
    if not parts:
        return None
    template_name = _load_template_map(HARNESS_ROOT).get(parts[0])
    if template_name is None:
        return None
    return HARNESS_ROOT / "templates" / template_name


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# Structural comparison
# ---------------------------------------------------------------------------


def _check(template_text: str, artifact_text: str) -> list[dict]:
    findings: list[dict] = []

    template_stripped = _strip_template_lines(template_text)
    findings.extend(_check_leaked_markers(artifact_text))
    findings.extend(_check_placeholders(template_stripped, artifact_text))

    template_skel = _build_skeleton(template_stripped, source="template")
    artifact_skel = _build_skeleton(artifact_text, source="artifact")

    findings.extend(_check_headings(template_skel, artifact_skel))
    findings.extend(_check_tables(template_skel, artifact_skel))
    findings.extend(_check_list_markers(template_skel, artifact_skel, artifact_text))

    return findings


def _strip_template_lines(text: str) -> str:
    return "\n".join(
        line for line in text.splitlines() if not TEMPLATE_MARKER_RE.match(line)
    )


def _check_leaked_markers(artifact_text: str) -> list[dict]:
    leaks = []
    for n, line in enumerate(artifact_text.splitlines(), 1):
        if TEMPLATE_MARKER_RE.match(line):
            leaks.append({
                "kind": "leaked_template_marker",
                "line": n,
                "detail": f"Artifact contains leaked instructional line: {line.strip()!r}",
            })
    return leaks


def _check_placeholders(template_stripped: str, artifact_text: str) -> list[dict]:
    # Strip backtick-quoted spans before extracting placeholders. Templates use
    # backticks to wrap sentinel values (e.g. `<pending>`) that the artifact is
    # *expected* to contain literally; treating those as "must replace" tokens
    # produces false positives.
    template_for_placeholders = _strip_backtick_spans(template_stripped)
    template_placeholders = {
        m.group(0)
        for m in PLACEHOLDER_RE.finditer(template_for_placeholders)
        if _is_replaceable_placeholder(m.group(0))
    }
    if not template_placeholders:
        return []
    findings = []
    for placeholder in sorted(template_placeholders):
        if placeholder in artifact_text:
            findings.append({
                "kind": "unreplaced_placeholder",
                "line": None,
                "detail": f"Placeholder {placeholder} from the template still appears verbatim in the artifact.",
            })
    return findings


def _strip_backtick_spans(text: str) -> str:
    return re.sub(r"`[^`\n]*`", "", text)


def _is_replaceable_placeholder(token: str) -> bool:
    inner = token.strip("<>").strip()
    if not inner:
        return False
    # Drop tokens that look like HTML/markup (e.g., URLs, email envelopes).
    if any(ch in inner for ch in ("/", "@", " http", "://")):
        return False
    return True


def _build_skeleton(text: str, *, source: str) -> list[dict]:
    skel: list[dict] = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        heading = HEADING_RE.match(line)
        if heading:
            level = len(heading.group(1))
            title = heading.group(2).strip()
            skel.append({
                "type": "heading",
                "level": level,
                "title": title,
                "normalized": _normalize_title(title),
                "line": i + 1,
            })
            i += 1
            continue
        if TABLE_ROW_RE.match(line) and i + 1 < len(lines) and TABLE_SEP_RE.match(lines[i + 1]):
            cells = _parse_table_cells(line)
            skel.append({
                "type": "table_header",
                "cells": cells,
                "normalized": tuple(_normalize_title(c) for c in cells),
                "line": i + 1,
            })
            i += 2
            continue
        list_match = LIST_MARKER_RE.match(line)
        if list_match:
            marker_kind = _list_marker_kind(line)
            skel.append({
                "type": "list_item",
                "marker": marker_kind,
                "line": i + 1,
            })
        i += 1
    return skel


def _normalize_title(text: str) -> str:
    # Drop placeholder tokens — the artifact substitutes those.
    cleaned = PLACEHOLDER_RE.sub("", text)
    cleaned = re.sub(r"\s+", " ", cleaned).strip().lower()
    cleaned = cleaned.strip(" :|—-")
    return cleaned


def _parse_table_cells(line: str) -> list[str]:
    raw = line.strip()
    if raw.startswith("|"):
        raw = raw[1:]
    if raw.endswith("|"):
        raw = raw[:-1]
    return [cell.strip() for cell in raw.split("|")]


def _list_marker_kind(line: str) -> str:
    stripped = line.lstrip()
    if not stripped:
        return "unknown"
    first = stripped[0]
    if first in {"-", "*", "+"}:
        return first
    if first.isdigit():
        return "ordered"
    return "unknown"


def _check_headings(template: list[dict], artifact: list[dict]) -> list[dict]:
    template_headings = [item for item in template if item["type"] == "heading"]
    artifact_headings = [item for item in artifact if item["type"] == "heading"]
    findings: list[dict] = []
    cursor = 0
    for expected in template_headings:
        match_idx = _find_heading(artifact_headings, expected, cursor)
        if match_idx is None:
            findings.append({
                "kind": "missing_heading",
                "line": expected["line"],
                "detail": (
                    f"Template heading {'#' * expected['level']} {expected['title']!r} "
                    f"(level {expected['level']}) was not found at or after the prior matched "
                    "heading in the artifact."
                ),
            })
            continue
        cursor = match_idx + 1
    return findings


def _find_heading(artifact_headings: list[dict], expected: dict, start: int) -> int | None:
    expected_norm = expected["normalized"]
    expected_level = expected["level"]
    # Empty normalized title means the template heading was just placeholders
    # (e.g., `### <module name>`). Match by level only.
    for idx in range(start, len(artifact_headings)):
        candidate = artifact_headings[idx]
        if candidate["level"] != expected_level:
            continue
        if not expected_norm:
            return idx
        if expected_norm in candidate["normalized"]:
            return idx
    return None


def _check_tables(template: list[dict], artifact: list[dict]) -> list[dict]:
    template_tables = [item for item in template if item["type"] == "table_header"]
    artifact_tables = [item for item in artifact if item["type"] == "table_header"]
    findings: list[dict] = []
    cursor = 0
    for expected in template_tables:
        target = expected["normalized"]
        found = False
        for idx in range(cursor, len(artifact_tables)):
            candidate = artifact_tables[idx]
            if candidate["normalized"] == target:
                cursor = idx + 1
                found = True
                break
        if not found:
            findings.append({
                "kind": "missing_table_header",
                "line": expected["line"],
                "detail": (
                    f"Template table header {expected['cells']!r} not found in the artifact "
                    "in the expected order."
                ),
            })
    return findings


def _check_list_markers(template: list[dict], artifact: list[dict], artifact_text: str) -> list[dict]:
    template_sections = _segment_by_heading(template)
    artifact_sections = _segment_by_heading(artifact)

    artifact_index: dict[str, list[dict]] = {}
    for section in artifact_sections:
        artifact_index.setdefault(section["key"], []).append(section)

    findings: list[dict] = []
    for section in template_sections:
        template_markers = _markers_in_section(section)
        if not template_markers:
            continue
        candidates = artifact_index.get(section["key"], [])
        if not candidates:
            # Heading-level finding already covers absence; skip.
            continue
        if any(_section_is_na(c, artifact_text) for c in candidates):
            continue
        artifact_markers = set()
        for c in candidates:
            artifact_markers.update(_markers_in_section(c))
        missing = template_markers - artifact_markers
        if missing:
            findings.append({
                "kind": "list_marker_mismatch",
                "line": section["line"],
                "detail": (
                    f"Section {section['title']!r}: template uses list marker(s) "
                    f"{sorted(missing)} but the artifact section does not."
                ),
            })
    return findings


def _segment_by_heading(skel: list[dict]) -> list[dict]:
    sections = []
    current: dict | None = None
    for item in skel:
        if item["type"] == "heading":
            if current is not None:
                sections.append(current)
            current = {
                "title": item["title"],
                "key": (item["level"], item["normalized"]),
                "line": item["line"],
                "items": [],
            }
            continue
        if current is not None:
            current["items"].append(item)
    if current is not None:
        sections.append(current)
    return sections


def _markers_in_section(section: dict) -> set[str]:
    return {item["marker"] for item in section["items"] if item["type"] == "list_item"}


def _section_is_na(section: dict, artifact_text: str) -> bool:
    # Re-read the body lines for this section to look for "N/A" content.
    lines = artifact_text.splitlines()
    start = section["line"]  # 1-indexed; this is the heading line itself.
    end = len(lines)
    for idx in range(start, len(lines)):
        if HEADING_RE.match(lines[idx]):
            end = idx
            break
    body = "\n".join(lines[start:end]).strip().lower()
    if not body:
        return True
    if body == "n/a":
        return True
    return body.startswith("n/a") or "\nn/a\n" in f"\n{body}\n"


# ---------------------------------------------------------------------------
# Logging + output formatting
# ---------------------------------------------------------------------------


def _log_finding(
    project_local: Path,
    rel: Path,
    template_path: Path,
    findings: list[dict],
    *,
    note: str | None = None,
) -> None:
    log_path = project_local / METRICS_RELPATH
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
    except OSError:
        return
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
    kinds = ",".join(sorted({f["kind"] for f in findings})) if findings else "none"
    line = (
        f"{timestamp} | {rel.as_posix()} | template={template_path.name} | "
        f"findings={len(findings)} | kinds={kinds}"
    )
    if note:
        line += f" | note={note}"
    try:
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def _format_findings(rel: Path, template_path: Path, findings: list[dict]) -> str:
    lines = [
        f"template-verifier hook: {len(findings)} finding(s) for "
        f"{rel.as_posix()} against template {template_path.name}",
    ]
    for f in findings:
        prefix = f"- [{f['kind']}]"
        if f.get("line"):
            prefix += f" line {f['line']}:"
        lines.append(f"{prefix} {f['detail']}")
    lines.append(
        "Correct the artifact and re-write. Findings are also logged to "
        ".claude-wyvrn-local/.metrics/template-verifier-findings.log."
    )
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    sys.exit(main())
