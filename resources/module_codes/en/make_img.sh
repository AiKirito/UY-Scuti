function update_config_files {
	local partition="$1"
	local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
	local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"
	# Create temporary files to store new configurations
	local temp_fs_config_file="$fs_config_file.tmp"
	local temp_file_contexts_file="$file_contexts_file.tmp"
	# Copy all contents of the original configuration files to the temporary files
	cat "$fs_config_file" >>"$temp_fs_config_file"
	cat "$file_contexts_file" >>"$temp_file_contexts_file"
	# Traverse the unpacked directory
	find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | while read -r file; do
		# Remove "Extracted-files/" prefix to get the relative path
		relative_path="${file#$WORK_DIR/$current_workspace/Extracted-files/}"
		# Check if the path already exists in the temporary configuration file
		if ! grep -Fq "$relative_path " "$temp_fs_config_file"; then
			# If not, add it as before
			if [ -d "$file" ]; then
				echo "$relative_path 0 0 0755" >>"$temp_fs_config_file"
			elif [ -L "$file" ]; then
				# Handle symbolic links
				local gid="0"
				local mode="0644"
				if [[ "$relative_path" == *"/system/bin"* || "$relative_path" == *"/system/xbin"* || "$relative_path" == *"/vendor/bin"* ]]; then
					gid="2000"
				fi
				if [[ "$relative_path" == *"/bin"* || "$relative_path" == *"/xbin"* ]]; then
					mode="0755"
				elif [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				local link_target=$(readlink -f "$file")
				if [[ "$link_target" == "$WORK_DIR/$current_workspace/Extracted-files/$partition"* ]]; then
					local relative_link_target="${link_target#$WORK_DIR/$current_workspace/Extracted-files/$partition}"
					echo "$relative_path 0 $gid $mode $relative_link_target" >>"$temp_fs_config_file"
				else
					echo "$relative_path 0 $gid $mode" >>"$temp_fs_config_file"
				fi
			else
				# Handle regular files
				local mode="0644"
				if [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				echo "$relative_path 0 0 $mode" >>"$temp_fs_config_file"
			fi
		fi
		escaped_path=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\&/g' -e 's/]/\\]/g')
		if ! grep -Fq "/$escaped_path " "$temp_file_contexts_file"; then
			echo "/$escaped_path u:object_r:${partition}_file:s0" >>"$temp_file_contexts_file"
		fi
	done
	if ! grep -Fq "${partition}/lost+found " "$temp_fs_config_file"; then
		echo "${partition}/lost+found 0 0 0755" >>"$temp_fs_config_file"
	fi
	if ! grep -Fq "/${partition}/lost\+found " "$temp_file_contexts_file"; then
		selinux_context=$(head -n 1 "$temp_file_contexts_file" | awk '{print $2}')
		echo "/${partition}/lost\+found ${selinux_context}" >>"$temp_file_contexts_file"
	fi
	if ! grep -Fq "/${partition}/ " "$temp_file_contexts_file"; then
		fix_selinux_context=$(head -n 1 "$temp_file_contexts_file" | awk '{print $2}')
		echo "/${partition}/ ${fix_selinux_context}" >>"$temp_file_contexts_file"
	fi
	sed -i "/\/${partition}(\/.*)? /d" "$temp_file_contexts_file"
	if [[ "$fs_type_choice" == 2 || "$fs_type_choice" == 4 ]]; then
		if ! grep -Fq "/${partition}(/.*)? " "$temp_file_contexts_file"; then
			echo "/${partition}(/.*)? u:object_r:${partition}_file:s0" >>"$temp_file_contexts_file"
		fi
	fi
	mv "$temp_fs_config_file" "$fs_config_file"
	mv "$temp_file_contexts_file" "$file_contexts_file"
	sort "$fs_config_file" -o "$fs_config_file"
	sort "$file_contexts_file" -o "$file_contexts_file"
}
function package_single_partition {
	dir=$1
	fs_type_choice=$2
	utc=$(date +%s)
	fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_fs_config"
	file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/$(basename "$dir")_file_contexts"
	output_image="$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
	start=$(date +%s%N)
	echo -e "Updating the configuration files of the $(basename "$dir") partition..."
	update_config_files "$(basename "$dir")"
	case "$fs_type_choice" in
	1)
		fs_type="erofs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
		echo "Partition configuration files updated."
		echo "Packaging the $(basename "$dir") partition files..."
		"$mkfs_tool_path" -d1 -zlz4hc,1 -T "$utc" --mount-point="/$(basename "$dir")" --fs-config-file="$fs_config_file" --product-out="$(dirname "$output_image")" --file-contexts="$file_contexts_file" "$output_image" "$dir" >/dev/null 2>&1
		;;
	2)
		fs_type="f2fs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		# Calculate directory size in MB
		size=$(($(du -sm "$dir" | cut -f1) * 11 / 10 + 55))
		echo "Partition configuration files updated."
		echo "Packaging the $(basename "$dir") partition files..."
		# Create an empty image file of the same size
		dd if=/dev/zero of="$output_image" bs=1M count=$size >/dev/null 2>&1
		"$mkfs_tool_path" "$output_image" -O extra_attr,inode_checksum,sb_checksum,compression -f -T "$utc" -q
		"$sload_tool_path" -f "$dir" -C "$fs_config_file" -s "$file_contexts_file" -t "/$(basename "$dir")" "$output_image" -c -T "$utc" >/dev/null 2>&1
		;;
	3)
		fs_type="ext4"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.ext4fs"
		size_file="$WORK_DIR/$current_workspace/Extracted-files/config/original_$(basename "$dir")_size"
		if [ -f "$size_file" ] && [ -s "$size_file" ]; then
			size=$(cat "$size_file")
		else
			size=$(du -sb "$dir" | cut -f1)
			if [ "$size" -lt $((2 * 1024 * 1024)) ]; then
				size=$((size * 11 / 10))
			else
				size=$((size * 1025 / 1000))
			fi
		fi
		echo "Partition configuration files updated."
		echo "Packaging the $(basename "$dir") partition files..."
		"$mkfs_tool_path" -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" >/dev/null 2>&1
		;;
	4)
		fs_type="f2fss"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		# Calculate directory size in MB
		size=$(($(du -sm "$dir" | cut -f1) * 11 / 10 + 55))
		echo "Partition configuration files updated."
		echo "Packaging the $(basename "$dir") partition files..."
		# Create an empty image file of the same size
		dd if=/dev/zero of="$output_image" bs=1M count=$size >/dev/null 2>&1
		"$mkfs_tool_path" "$output_image" -O extra_attr,inode_checksum,sb_checksum,compression -f -T "$utc" -q
		"$sload_tool_path" -f "$dir" -C "$fs_config_file" -s "$file_contexts_file" -t "/$(basename "$dir")" "$output_image" -c -T "$utc" >/dev/null 2>&1
		"$(dirname "$0")/resources/my_tools/img2simg" "$output_image" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir")_sparse.img"
		mv "$WORK_DIR/$current_workspace/Packed/$(basename "$dir")_sparse.img" "$output_image"
		;;
	5)
		fs_type="ext4s"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.ext4fs"
		# Calculate directory size
		size=$(du -sb "$dir" | cut -f1)
		if [ "$size" -lt $((1024 * 1024)) ]; then
			size=$((size * 6))
		elif [ "$size" -lt $((50 * 1024 * 1024)) ]; then
			size=$((size * 12 / 10))
		else
			# Otherwise, increase size by 1.1 times
			size=$((size * 11 / 10))
		fi
		echo "Partition configuration files updated."
		echo "Packaging the $(basename "$dir") partition files..."
		"$mkfs_tool_path" -s -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" >/dev/null 2>&1
		;;
	esac
	echo "$(basename "$dir") partition files packaging completed"
	end=$(date +%s%N)
	runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
	runtime=$(printf "%.3f" "$runtime")
	echo "Time taken: $runtime seconds"
}
function package_special_partition {
	echo -e "Packaging the $(basename "$dir") partition"
	# Get start time
	start=$(date +%s%N)
	# Define a local variable dir
	local dir="$1"
	# Delete all files and folders under "$TOOL_DIR/boot_editor/build/unzip_boot"
	rm -rf "$TOOL_DIR/boot_editor/build/unzip_boot"
	# Create directory "$TOOL_DIR/boot_editor/build/unzip_boot"
	mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"
	# Copy all files and folders from "$dir" to "$TOOL_DIR/boot_editor/build/unzip_boot"
	cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"
	# Iterate over all .img files
	for file in $(find $TOOL_DIR/boot_editor -type f -name "*.img"); do
		# Get base name of the file (without extension)
		base_name=$(basename "$file" .img)
		# Rename .img files to .img.wait
		mv "$file" "$TOOL_DIR/boot_editor/${base_name}.img.wait"
	done
	# Move and rename "$(basename "$dir").img.wait" to "$(basename "$dir").img"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait" "$TOOL_DIR/boot_editor/$(basename "$dir").img"
	# Execute ./gradlew pack command in "$TOOL_DIR/boot_editor"
	(cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1
	# Copy "$(basename "$dir").img.signed" to "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
	cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
	# Move and rename "$(basename "$dir").img.signed" to "$(basename "$dir").img"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$TOOL_DIR/boot_editor/$(basename "$dir").img"
	# Move and rename "$(basename "$dir").img" to "$(basename "$dir").img.wait"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img" "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait"
	rm -rf "$TOOL_DIR/boot_editor/build"
	echo "$(basename "$dir") partition files packaging completed"
	end=$(date +%s%N)
	runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
	runtime=$(printf "%.3f" "$runtime")
	echo "Time taken: $runtime seconds"
}
function package_regular_image {
	mkdir -p "$WORK_DIR/$current_workspace/Packed"
	while true; do
		echo -e "\n   Current partition directories:\n"
		local i=1
		local dir_array=()
		local special_dir_count=0
		for dir in "$WORK_DIR/$current_workspace/Extracted-files"/*; do
			if [ -d "$dir" ] && [ "$(basename "$dir")" != "config" ] && [ "$(basename "$dir")" != "super" ]; then
				printf "   \033[0;31m[%02d] %s\033[0m\n\n" "$i" "$(basename "$dir")"
				dir_array[i]="$dir"
				i=$((i + 1))
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* ]]; then
					special_dir_count=$((special_dir_count + 1))
				fi
			fi
		done
		if [ ${#dir_array[@]} -eq 0 ]; then
			clear
			echo -e "\n   No partition files detected."
			echo -n "   Press any key to return..."
			read -n 1
			clear
			return
		fi
		echo -e "   [ALL] Package all partition files    [Q] Return to workspace menu\n"
		echo -n "   Please choose the partition directory to package:"
		read dir_num
		dir_num=$(echo "$dir_num" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
		if [ "$dir_num" = "all" ]; then
			if [ $special_dir_count -ne ${#dir_array[@]} ]; then
				clear
				while true; do
					echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4"
					echo -e "\n   [4] F2FSS    [5] EXT4S\n"
					echo -e "   [Q] Return to workspace menu\n"
					echo -n "   Please choose the filesystem type to package:"
					read fs_type_choice
					fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
					if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" || "$fs_type_choice" == "4" || "$fs_type_choice" == "5" ]]; then
						break
					elif [ "$fs_type_choice" = "q" ]; then
						return
					else
						clear
						echo -e "\n   Invalid input, please try again."
					fi
				done
			fi
			clear
			for dir in "${dir_array[@]}"; do
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* ]]; then
					echo -e "\n"
					package_special_partition "$dir"
				else
					echo -e "\n"
					package_single_partition "$dir" "$fs_type_choice"
				fi
			done
			echo -n "Packaging completed, press any key to return..."
			read -n 1
			clear
			continue
		elif [ "$dir_num" = "q" ]; then
			break
		else
			dir="${dir_array[$dir_num]}"
			if [ -d "$dir" ]; then
				if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* ]]; then
					clear
					echo -e "\n"
					package_special_partition "$dir"
				else
					clear
					while true; do
						echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4"
						echo -e "\n   [4] F2FSS    [5] EXT4S\n"
						echo -e "   [Q] Return to workspace menu\n"
						echo -n "   Please choose the filesystem type to package:"
						read fs_type_choice
						fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
						if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" || "$fs_type_choice" == "4" || "$fs_type_choice" == "5" ]]; then
							break
						elif [ "$fs_type_choice" = "q" ]; then
							return
						else
							clear
							echo -e "\n   Invalid input, please try again."
						fi
					done
					clear
					echo -e "\n"
					package_single_partition "$dir" "$fs_type_choice"
				fi
				echo -n "Packaging completed, press any key to return..."
				read -n 1
				clear
				continue
			else
				clear
				echo -e "\n   The selected directory does not exist, please choose again."
			fi
		fi
	done
}
