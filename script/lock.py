#!/usr/bin/env python3

import json
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print("usage: lock.py <old.lock> <new.lock>")
        sys.exit(1)

    old_path = Path(sys.argv[1])
    new_path = Path(sys.argv[2])

    old_data = json.loads(old_path.read_text())
    new_data = json.loads(new_path.read_text())

    old_nodes = old_data.get("nodes", {})
    new_nodes = new_data.get("nodes", {})

    changes = []
    for name in old_nodes:
        if name == "root":
            continue

        old_node = old_nodes.get(name, {})
        new_node = new_nodes.get(name, {})

        old_rev = old_node.get("locked", {}).get("rev")
        new_rev = new_node.get("locked", {}).get("rev")

        if old_rev and new_rev and old_rev != new_rev:
            changes.append(f"  {name}: {old_rev[:7]} → {new_rev[:7]}")

    if changes:
        print("\n".join(changes))


if __name__ == "__main__":
    main()
