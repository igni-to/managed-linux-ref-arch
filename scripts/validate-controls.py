#!/usr/bin/env python3
"""Validate the control catalog.

The catalog is the spine of this repository: the architecture docs describe
how something is built, and the catalog is what says whether it is actually
in place and how you would know. That only holds if every control carries the
same fields, so this runs in CI.

What it enforces, and why each one earns its place:

  * Unique IDs, matching their family. A control ID appears in evidence packs
    and in igni-scan rule metadata. If an ID can change meaning, every artifact
    that ever quoted it becomes ambiguous.

  * A verification for every implemented control. A control claiming to be
    implemented with nothing verifying it is an assertion, and assertions are
    what this project exists to replace. `status: implemented` therefore
    requires a non-empty `verified_by`.

  * Honest status values. `planned` is a first-class answer. Overstating is the
    only failure mode that matters here.
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("pyyaml is required: pip install pyyaml")

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = ROOT / "controls"

# The nine families. A control cannot belong to a family that does not exist,
# because the alternative is a typo silently creating one.
FAMILIES = {
    "IGN-AC": "Access control",
    "IGN-EP": "Endpoint",
    "IGN-SW": "Software",
    "IGN-PT": "Patching",
    "IGN-CM": "Change",
    "IGN-SC": "Provenance",
    "IGN-MO": "Monitoring",
    "IGN-BR": "Backup and restore",
    "IGN-VE": "Estate",
}

STATUSES = {"implemented", "partial", "planned"}

REQUIRED = ["id", "statement", "soc2", "status", "implemented_by", "evidence"]

ID_RE = re.compile(r"^(IGN-[A-Z]{2})-(\d{2})$")

# Trust Services Criteria, common criteria plus the availability series this
# architecture touches. Not the full published set — only what is claimable
# here. An unknown criterion is far more likely to be a typo than a gap in
# this list, and a wrong mapping is worse than no mapping.
TSC_RE = re.compile(r"^(CC[1-9]\.\d{1,2}|A1\.\d)$")


def fail(errors):
    for e in errors:
        print(f"  {e}", file=sys.stderr)
    print(f"\n{len(errors)} problem(s) in the control catalog", file=sys.stderr)
    sys.exit(1)


def main():
    if not CONTROLS.is_dir():
        sys.exit(f"no controls directory at {CONTROLS}")

    files = sorted(CONTROLS.glob("*.yaml"))
    if not files:
        sys.exit("the control catalog is empty")

    errors = []
    seen = {}
    counts = {"implemented": 0, "partial": 0, "planned": 0}

    for path in files:
        rel = path.relative_to(ROOT)
        doc = yaml.safe_load(path.read_text())

        if not isinstance(doc, dict):
            errors.append(f"{rel}: expected a mapping at the top level")
            continue

        family = doc.get("family")
        if family not in FAMILIES:
            errors.append(f"{rel}: unknown family {family!r}")
            continue

        for control in doc.get("controls") or []:
            cid = control.get("id", "<missing id>")
            where = f"{rel}: {cid}"

            for field in REQUIRED:
                if not control.get(field):
                    errors.append(f"{where}: missing {field}")

            m = ID_RE.match(str(cid))
            if not m:
                errors.append(f"{where}: id must look like IGN-XX-01")
            elif m.group(1) != family:
                errors.append(f"{where}: id belongs to {m.group(1)}, file declares {family}")

            if cid in seen:
                errors.append(f"{where}: duplicate id, also in {seen[cid]}")
            seen[cid] = rel

            status = control.get("status")
            if status and status not in STATUSES:
                errors.append(f"{where}: status {status!r} is not one of {sorted(STATUSES)}")
            elif status:
                counts[status] += 1

            for criterion in control.get("soc2") or []:
                if not TSC_RE.match(str(criterion)):
                    errors.append(f"{where}: {criterion!r} is not a Trust Services Criterion")

            # The rule that makes the catalog worth having.
            if status == "implemented" and not control.get("verified_by"):
                errors.append(
                    f"{where}: status is implemented but nothing verifies it — "
                    "add a verified_by, or set status to partial"
                )

    if errors:
        fail(errors)

    total = sum(counts.values())
    print(f"{total} controls across {len(files)} families — ", end="")
    print(", ".join(f"{n} {s}" for s, n in counts.items() if n))


if __name__ == "__main__":
    main()
