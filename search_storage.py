import os

project_dir = "."
for root, dirs, files in os.walk(project_dir):
    # Skip build, .git, etc.
    if any(x in root for x in [".git", "build", ".dart_tool"]):
        continue
    for file in files:
        if file.endswith(".dart"):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                    if "storage" in content.lower():
                        print(f"Found storage in {filepath}")
            except Exception as e:
                pass
