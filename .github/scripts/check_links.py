#!/usr/bin/env python3
"""Verify that relative markdown links in the repo resolve to real files.

Scans every tracked ``*.md`` file for inline links of the form ``[text](target)``
and checks that each *relative* target exists on disk. External links
(``http``/``https``/``mailto``) and pure in-page anchors (``#section``) are
skipped; an ``#anchor`` suffix on a relative path is stripped before the file
existence check. Exits non-zero (listing every broken link) if any relative
target is missing, so it can gate CI without needing network access.
"""

import os
import re
import sys

# [text](target) - capture the target, ignore optional "title" after a space.
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")

SKIP_PREFIXES = ("http://", "https://", "mailto:", "#")


def iter_markdown_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        if ".git" in dirnames:
            dirnames.remove(".git")
        for name in filenames:
            if name.endswith(".md"):
                yield os.path.join(dirpath, name)


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    broken = []
    checked = 0

    for md_path in iter_markdown_files(root):
        with open(md_path, encoding="utf-8") as fh:
            text = fh.read()
        base = os.path.dirname(md_path)
        for target in LINK_RE.findall(text):
            if target.startswith(SKIP_PREFIXES):
                continue
            # Drop any in-page anchor suffix before resolving the file.
            path_part = target.split("#", 1)[0]
            if not path_part:
                continue
            checked += 1
            resolved = os.path.normpath(os.path.join(base, path_part))
            if not os.path.exists(resolved):
                rel = os.path.relpath(md_path, root)
                broken.append((rel, target))

    if broken:
        print(f"Broken relative links ({len(broken)}):")
        for src, target in broken:
            print(f"  {src} -> {target}")
        return 1

    print(f"All {checked} relative markdown links resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
