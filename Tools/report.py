import os

"""
  This script generates markdown-friendly output of testing results for HW and emulators.
Usage:
> sed -i '/# Output/q' ../README.md
> python3 report.py >> ../README.md
"""

def find_images(root_dir, path_dir, title_level):
	path = root_dir + path_dir
	dirs = [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))]
	if dirs:
		dirs.sort(key=str.lower)
		for dir in dirs:
			# these dirs we are ignoring...
			if not dir in ("ZilogDMA", "zilog_hw_photos", "ZX48_ZX128"):
				print(f"\n{'#'*title_level} [{dir}]({path_dir}{dir}/)")
				find_images(root_dir, f"{path_dir}{dir}/", title_level + 1)
	else:
		image_files = [f for f in os.listdir(path) if os.path.isfile(os.path.join(path, f))
			# extensions we are interested in
			and f.lower().endswith(('.png', '.jpg'))
			# name prefixes we are interested in
			and f.lower().startswith(('board', 'cspect', 'zesarux', 'mame'))
		]
		if image_files:
			image_files.sort(key=lambda x: (not x.lower().startswith("board"), x.lower()))
			for img in image_files:
				print(f"<img src=\"{path_dir}{img}\" width=\"300\" height=\"200\" /> ", end="")
			print("")

if __name__ == "__main__":
	root_dir = "../"
	path_dir = "Tests/"
	title_level = 2
	find_images(root_dir, path_dir, title_level)
