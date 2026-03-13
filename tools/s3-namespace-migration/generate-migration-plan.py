#!/usr/bin/env python3
"""
generate-migration-plan.py

Reads uuid-mapper CSV output and produces a human-readable migration plan
showing exactly which UUIDs will be copied to which namespaced folder.

This is a dry-run planning tool — it makes no changes to S3.
Run it before migrate-blobs.sh to understand the scope of the migration.

Usage:
    ./generate-migration-plan.py [OPTIONS]

Options:
    --input-dir DIR     Directory containing uuid-mapper CSV output
                        (default: ../uuid-mapper/output)
    --output FILE       Write plan to a file instead of stdout
    --format FORMAT     Output format: text, csv, json (default: text)
    --buildpack NAME    Show plan for only the specified namespace
    --help              Show this help message
"""

import argparse
import csv
import io
import json
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Dict, List, Optional

# ---------------------------------------------------------------------------
# Repo → S3 folder_name mapping (matches migrate-blobs.sh)
# ---------------------------------------------------------------------------

REPO_TO_FOLDER: Dict[str, str] = {
    "binary-buildpack-release": "binary-buildpack",
    "dotnet-core-buildpack-release": "dotnet-core-buildpack",
    "go-buildpack-release": "go-buildpack",
    "hwc-buildpack-release": "hwc-buildpack",
    "java-buildpack-release": "java-buildpack",
    "java-offline-buildpack-release": "java-offline-buildpack",
    "nginx-buildpack-release": "nginx-buildpack",
    "nodejs-buildpack-release": "nodejs-buildpack",
    "php-buildpack-release": "php-buildpack",
    "python-buildpack-release": "python-buildpack",
    "r-buildpack-release": "r-buildpack",
    "ruby-buildpack-release": "ruby-buildpack",
    "staticfile-buildpack-release": "staticfile-buildpack",
    "cflinuxfs3-release": "cflinuxfs3",
    "cflinuxfs4-release": "cflinuxfs4",
}

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class BlobCopy:
    uuid: str
    folder: str
    filename: str
    size: int
    repo: str
    date: str
    tags: str


@dataclass
class NamespacePlan:
    folder: str
    blobs: List[BlobCopy] = field(default_factory=list)

    @property
    def total_size_bytes(self) -> int:
        return sum(b.size for b in self.blobs)

    @property
    def total_size_gb(self) -> float:
        return self.total_size_bytes / (1024**3)


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------


def load_blob_history(input_dir: Path) -> List[BlobCopy]:
    """Load all_blob_history.csv and return deduplicated current-state blobs."""
    history_file = input_dir / "all_blob_history.csv"
    if not history_file.exists():
        print(f"ERROR: Missing {history_file}", file=sys.stderr)
        print("Run the uuid-mapper tool first:", file=sys.stderr)
        print("  cd tools/uuid-mapper && ./mapper.py --no-serve", file=sys.stderr)
        sys.exit(1)

    # Read all entries
    all_entries: List[dict] = []
    with open(history_file, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            repo = row.get("repo", "")
            folder = REPO_TO_FOLDER.get(repo)
            if not folder:
                continue
            all_entries.append(
                {
                    "uuid": row.get("uuid", ""),
                    "filename": row.get("filename", ""),
                    "size": int(row.get("size") or 0),
                    "repo": repo,
                    "folder": folder,
                    "date": row.get("date", ""),
                    "tags": row.get("tags", ""),
                }
            )

    # Deduplicate: keep most-recent entry per UUID (sorted by date desc)
    all_entries.sort(key=lambda e: (e["uuid"], e["date"]), reverse=True)
    seen: set = set()
    unique: List[BlobCopy] = []
    for entry in all_entries:
        uuid = entry["uuid"]
        if uuid and uuid not in seen:
            seen.add(uuid)
            unique.append(
                BlobCopy(
                    uuid=uuid,
                    folder=entry["folder"],
                    filename=entry["filename"],
                    size=entry["size"],
                    repo=entry["repo"],
                    date=entry["date"],
                    tags=entry["tags"],
                )
            )

    return unique


def load_orphaned_blobs(input_dir: Path) -> List[dict]:
    """Load orphaned_blobs.csv."""
    orphaned_file = input_dir / "orphaned_blobs.csv"
    if not orphaned_file.exists():
        return []

    results = []
    with open(orphaned_file, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            results.append(
                {
                    "uuid": row.get("uuid", ""),
                    "size": int(row.get("size") or 0),
                    "last_modified": row.get("last_modified", ""),
                }
            )
    return results


# ---------------------------------------------------------------------------
# Plan generation
# ---------------------------------------------------------------------------


def build_namespace_plans(
    blobs: List[BlobCopy],
    filter_buildpack: Optional[str],
) -> Dict[str, NamespacePlan]:
    plans: Dict[str, NamespacePlan] = {}

    for blob in blobs:
        if filter_buildpack and blob.folder != filter_buildpack:
            continue
        if blob.folder not in plans:
            plans[blob.folder] = NamespacePlan(folder=blob.folder)
        plans[blob.folder].blobs.append(blob)

    return dict(sorted(plans.items()))


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------


def fmt_size(size_bytes: int) -> str:
    if size_bytes >= 1_073_741_824:
        return f"{size_bytes / 1_073_741_824:.2f} GB"
    if size_bytes >= 1_048_576:
        return f"{size_bytes / 1_048_576:.2f} MB"
    if size_bytes >= 1_024:
        return f"{size_bytes / 1_024:.2f} KB"
    return f"{size_bytes} B"


def render_text(
    plans: Dict[str, NamespacePlan],
    orphaned: List[dict],
    bucket: str,
) -> str:
    lines = [
        "━" * 64,
        "  S3 Namespace Migration Plan",
        f"  Bucket: s3://{bucket}/",
        "━" * 64,
        "",
    ]

    total_blobs = 0
    total_bytes = 0

    for folder, plan in plans.items():
        total_blobs += len(plan.blobs)
        total_bytes += plan.total_size_bytes

        lines.append(
            f"  📂 {folder}/  ({len(plan.blobs)} blobs, {fmt_size(plan.total_size_bytes)})"
        )
        for blob in sorted(plan.blobs, key=lambda b: b.filename):
            size_str = fmt_size(blob.size) if blob.size else "unknown size"
            tags_str = f"  [tags: {blob.tags}]" if blob.tags else ""
            lines.append(f"      {blob.uuid}  →  {folder}/{blob.uuid}")
            lines.append(f"        filename: {blob.filename}  ({size_str}){tags_str}")
        lines.append("")

    lines += [
        "━" * 64,
        f"  Total blobs to migrate: {total_blobs}",
        f"  Total data to copy:     {fmt_size(total_bytes)}",
        "",
    ]

    if orphaned:
        orphaned_bytes = sum(o["size"] for o in orphaned)
        lines += [
            f"  Orphaned blobs (→ orphaned/ folder): {len(orphaned)}",
            f"  Orphaned data:                       {fmt_size(orphaned_bytes)}",
            "",
        ]

    lines.append("━" * 64)
    return "\n".join(lines)


def render_csv(plans: Dict[str, NamespacePlan]) -> str:
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(
        ["folder", "uuid", "filename", "size", "repo", "date", "tags", "destination"]
    )
    for folder, plan in plans.items():
        for blob in plan.blobs:
            writer.writerow(
                [
                    folder,
                    blob.uuid,
                    blob.filename,
                    blob.size,
                    blob.repo,
                    blob.date,
                    blob.tags,
                    f"{folder}/{blob.uuid}",
                ]
            )
    return buf.getvalue().rstrip("\n")


def render_json(
    plans: Dict[str, NamespacePlan],
    orphaned: List[dict],
) -> str:
    output = {
        "namespaces": {
            folder: {
                "folder": folder,
                "blob_count": len(plan.blobs),
                "total_size_bytes": plan.total_size_bytes,
                "blobs": [asdict(b) for b in plan.blobs],
            }
            for folder, plan in plans.items()
        },
        "orphaned": orphaned,
        "summary": {
            "total_namespaces": len(plans),
            "total_blobs": sum(len(p.blobs) for p in plans.values()),
            "total_size_bytes": sum(p.total_size_bytes for p in plans.values()),
            "orphaned_count": len(orphaned),
            "orphaned_size_bytes": sum(o["size"] for o in orphaned),
        },
    }
    return json.dumps(output, indent=2)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate S3 namespace migration plan from uuid-mapper output",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--input-dir",
        default=str(Path(__file__).parent / "../uuid-mapper/output"),
        help="Directory with uuid-mapper CSV output (default: ../uuid-mapper/output)",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--format",
        choices=["text", "csv", "json"],
        default="text",
        help="Output format (default: text)",
    )
    parser.add_argument(
        "--buildpack",
        default="",
        help="Limit plan to a single buildpack namespace",
    )
    parser.add_argument(
        "--bucket",
        default="buildpacks.cloudfoundry.org",
        help="S3 bucket name (default: buildpacks.cloudfoundry.org)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_dir = Path(args.input_dir).resolve()

    blobs = load_blob_history(input_dir)
    orphaned = load_orphaned_blobs(input_dir)
    plans = build_namespace_plans(blobs, args.buildpack or None)

    if args.format == "text":
        output = render_text(plans, orphaned, args.bucket)
    elif args.format == "csv":
        output = render_csv(plans)
    else:
        output = render_json(plans, orphaned)

    if args.output == "-":
        print(output)
    else:
        out_path = Path(args.output)
        out_path.write_text(output)
        print(f"Plan written to: {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
