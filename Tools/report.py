import os

def find_images(root_dir, path_dir, title_level):
	path = root_dir + path_dir
	dirs = [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))]
	if dirs:
		dirs.sort(key=str.lower)
		for dir in dirs:
			print(f"\n{'#'*title_level} [{dir}]({path_dir}{dir}/)")
			find_images(root_dir, f"{path_dir}{dir}/", title_level + 1)
	else:
		image_files = [f for f in os.listdir(path) if os.path.isfile(os.path.join(path, f))
			and f.lower().endswith(('.png', '.jpg'))
			and f.lower().startswith(('board', 'cspect', 'zesarux'))
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

