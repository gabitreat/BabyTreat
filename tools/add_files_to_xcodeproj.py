#!/usr/bin/env python3
"""Add Swift sources to BabyTreat.xcodeproj.

Tuist can't regenerate without a network fetch for an unused dependency, and
regenerating would also revert IPHONEOS_DEPLOYMENT_TARGET from 26.0 to the 17.0
in Project.swift (D-13). So we edit the existing project instead.

    tools/add_files_to_xcodeproj.py BabyTreat/MealPlanning/MealPlanner.swift ...

Idempotent: a file already in the project is skipped. Ids are derived from the
file name, so re-running never produces a second, colliding reference.
"""
import hashlib
import re
import subprocess
import sys
import os

PROJ = "BabyTreat.xcodeproj/project.pbxproj"


def oid(seed):
    """Deterministic 24-char uppercase hex id, namespaced so it can't collide."""
    return hashlib.sha1(("babytreat-meals:" + seed).encode()).hexdigest()[:24].upper()


# Directory -> the PBXGroup that owns it. The first two were created by the
# original bulk import and keep their derived ids; the rest are Xcode's own.
GROUPS = {
    "BabyTreat/MealPlanning": oid("group:MealPlanning"),
    "BabyTreat/Views/Meals": oid("group:Meals"),
    "BabyTreat/Models": "06580E702F35321600FBC564",
    "BabyTreat/Views": "AD3508F41705AB2EA836F4C8",
    "BabyTreat": "574B75AB6E15F28E135AC551",
}


def main(paths):
    if not paths:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    src = open(PROJ).read()
    added = []

    for path in paths:
        path = os.path.normpath(path)
        name = os.path.basename(path)
        directory = os.path.dirname(path)

        if not os.path.exists(path):
            print(f"no such file: {path}", file=sys.stderr)
            return 1
        if f"/* {name} */" in src:
            print(f"skipped (already in project): {name}")
            continue
        group = GROUPS.get(directory)
        if group is None:
            print(f"no group mapped for directory {directory!r}", file=sys.stderr)
            return 1

        fid, bid = oid("file:" + name), oid("build:" + name)

        src = src.replace(
            "/* End PBXBuildFile section */",
            f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; '
            f'fileRef = {fid} /* {name} */; }};\n/* End PBXBuildFile section */', 1)

        src = src.replace(
            "/* End PBXFileReference section */",
            f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};\n'
            '/* End PBXFileReference section */', 1)

        pattern = re.compile(
            r'(\t\t' + group + r' /\* .*? \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)')
        src, count = pattern.subn(lambda m: m.group(1) + f'\t\t\t\t{fid} /* {name} */,\n', src, count=1)
        if count != 1:
            print(f"FAILED to find group {group} for {name}", file=sys.stderr)
            return 1

        # The Sources phase has no buildActionMask line, so match loosely.
        pattern = re.compile(r'(isa = PBXSourcesBuildPhase;\n(?:\t\t\t\w+ = [^\n]*\n)*?\t\t\tfiles = \(\n)')
        src, count = pattern.subn(
            lambda m: m.group(1) + f'\t\t\t\t{bid} /* {name} in Sources */,\n', src, count=1)
        if count != 1:
            print("FAILED to find sources build phase", file=sys.stderr)
            return 1

        added.append(name)

    if not added:
        return 0

    open(PROJ, "w").write(src)
    check = subprocess.run(["plutil", "-lint", PROJ], capture_output=True, text=True)
    if check.returncode != 0:
        print(check.stdout + check.stderr, file=sys.stderr)
        return 1
    print(f"added {len(added)}: {', '.join(added)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
