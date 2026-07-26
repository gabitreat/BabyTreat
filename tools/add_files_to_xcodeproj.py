#!/usr/bin/env python3
"""Add the meal-planning sources to BabyTreat.xcodeproj.

Tuist can't regenerate without a network fetch for an unused dependency, and
regenerating would also revert IPHONEOS_DEPLOYMENT_TARGET from 26.0 to the 17.0
in Project.swift. So we edit the existing project instead.
"""
import hashlib
import re
import sys

PROJ = "BabyTreat.xcodeproj/project.pbxproj"

MODELS = ["Food.swift", "Recipe.swift", "MenuEntry.swift", "MealLog.swift", "ShoppingItem.swift"]
MEALPLANNING = ["MealTheme.swift", "MealRules.swift", "MealSeed.swift"]
MEALS_VIEWS = ["MealsTodayView.swift", "MealsWeekView.swift", "MealsFoodsView.swift",
               "MealsRecipesView.swift", "MealsShoppingView.swift"]
VIEWS = ["MealsView.swift"]

MODELS_GROUP = "06580E702F35321600FBC564"
VIEWS_GROUP = "AD3508F41705AB2EA836F4C8"
BABYTREAT_GROUP = "574B75AB6E15F28E135AC551"


def oid(seed):
    """Deterministic 24-char uppercase hex id, namespaced so it can't collide."""
    return hashlib.sha1(("babytreat-meals:" + seed).encode()).hexdigest()[:24].upper()


def main():
    src = open(PROJ).read()
    if "MealRules.swift" in src:
        print("already added; nothing to do")
        return 0

    build_lines, ref_lines, sources_lines = [], [], []
    group_children = {MODELS_GROUP: [], VIEWS_GROUP: [], BABYTREAT_GROUP: []}
    new_groups = []

    def add_file(name, group_key):
        fid, bid = oid("file:" + name), oid("build:" + name)
        ref_lines.append(
            f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'
        )
        build_lines.append(
            f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};'
        )
        sources_lines.append(f'\t\t\t\t{bid} /* {name} in Sources */,')
        group_children.setdefault(group_key, []).append(f'\t\t\t\t{fid} /* {name} */,')

    for n in MODELS:
        add_file(n, MODELS_GROUP)
    for n in VIEWS:
        add_file(n, VIEWS_GROUP)

    # New groups: BabyTreat/MealPlanning and BabyTreat/Views/Meals
    mp_id = oid("group:MealPlanning")
    meals_id = oid("group:Meals")
    for n in MEALPLANNING:
        add_file(n, mp_id)
    for n in MEALS_VIEWS:
        add_file(n, meals_id)

    for gid, gname, gpath in [(mp_id, "MealPlanning", "MealPlanning"), (meals_id, "Meals", "Meals")]:
        kids = "\n".join(group_children.get(gid, []))
        new_groups.append(
            f'\t\t{gid} /* {gname} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n'
            f'{kids}\n\t\t\t);\n\t\t\tpath = {gpath};\n\t\t\tsourceTree = "<group>";\n\t\t}};'
        )

    group_children[BABYTREAT_GROUP].append(f'\t\t\t\t{mp_id} /* MealPlanning */,')
    group_children[VIEWS_GROUP].append(f'\t\t\t\t{meals_id} /* Meals */,')

    # 1. build files + 2. file references + 3. new groups
    src = src.replace("/* End PBXBuildFile section */",
                      "\n".join(build_lines) + "\n/* End PBXBuildFile section */", 1)
    src = src.replace("/* End PBXFileReference section */",
                      "\n".join(ref_lines) + "\n/* End PBXFileReference section */", 1)
    src = src.replace("/* End PBXGroup section */",
                      "\n".join(new_groups) + "\n/* End PBXGroup section */", 1)

    # 4. attach children to their groups
    for gid, kids in group_children.items():
        if gid in (mp_id, meals_id) or not kids:
            continue
        pattern = re.compile(r'(\t\t' + gid + r' /\* .*? \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)')
        src, count = pattern.subn(lambda m: m.group(1) + "\n".join(kids) + "\n", src, count=1)
        if count != 1:
            print(f"FAILED to find group {gid}", file=sys.stderr)
            return 1

    # 5. add to the Sources build phase
    pattern = re.compile(r'(isa = PBXSourcesBuildPhase;\n(?:\t\t\t\w+ = [^\n]*\n)*?\t\t\tfiles = \(\n)')
    src, count = pattern.subn(lambda m: m.group(1) + "\n".join(sources_lines) + "\n", src, count=1)
    if count != 1:
        print("FAILED to find sources build phase", file=sys.stderr)
        return 1

    open(PROJ, "w").write(src)
    print(f"added {len(build_lines)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
