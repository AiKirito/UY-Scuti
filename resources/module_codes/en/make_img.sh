function update_config_files {
	local partition="$1"
	local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
	local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"

	# 创建临时文件来存储新的配置
	local temp_fs_config_file="$fs_config_file.tmp"
	local temp_file_contexts_file="$file_contexts_file.tmp"

	# 将原配置文件的所有内容复制到临时配置文件中
	cat "$fs_config_file" >>"$temp_fs_config_file"
	cat "$file_contexts_file" >>"$temp_file_contexts_file"

	# 遍历解包后的目录
	find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | while read -r file; do
		# 移除 "Extracted-files/" 前缀，得到相对路径
		relative_path="${file#$WORK_DIR/$current_workspace/Extracted-files/}"

		# 检查该路径是否已经在临时配置文件中
		if ! grep -Fq "$relative_path " "$temp_fs_config_file"; then
			# 如果不存在，则按照原来的方式添加
			if [ -d "$file" ]; then
				echo "$relative_path 0 0 0755" >>"$temp_fs_config_file"
			elif [ -L "$file" ]; then
				# 处理符号链接
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
				# 处理普通文件
				local mode="0644"
				if [[ "$relative_path" == *".sh"* ]]; then
					mode="0750"
				fi
				echo "$relative_path 0 0 $mode" >>"$temp_fs_config_file"
			fi
		fi

		escaped_path=$(echo "$relative_path" | sed -e 's/[+.\[()（）]/\&/g' -e 's/]/\]/g')
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
	echo -e "Updating the configuration file of the $(basename "$dir") partition..."
	update_config_files "$(basename "$dir")"
	case "$fs_type_choice" in
	1)
		fs_type="erofs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
		echo "Partition configuration file update completed"
		echo "Packaging $(basename "$dir") partition file..."

		"$mkfs_tool_path" -d1 -zlz4hc,1 -T "$utc" --mount-point="/$(basename "$dir")" --fs-config-file="$fs_config_file" --product-out="$(dirname "$output_image")" --file-contexts="$file_contexts_file" "$output_image" "$dir" >/dev/null 2>&1
		;;
	2)
		fs_type="f2fs"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		# 计算目录的大小（单位：MB）
		size=$(($(du -sm "$dir" | cut -f1) * 11 / 10 + 55))

		echo "Partition configuration file update completed"
		echo "Packaging $(basename "$dir") partition file..."
		# 创建一个与目录大小相同的空镜像文件
		dd if=/dev/zero of="$output_image" bs=1M count=$size >/dev/null 2>&1
		"$mkfs_tool_path" "$output_image" -O extra_attr,inode_checksum,sb_checksum,compression -f -T "$utc" -q
		"$sload_tool_path" -f "$dir" -C "$fs_config_file" -s "$file_contexts_file" -t "/$(basename "$dir")" "$output_image" -c -T "$utc" >/dev/null 2>&1
		;;
	3)
		fs_type="ext4"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.ext4fs"
		# 计算目录的大小
		size=$(du -sb "$dir" | cut -f1)
		if [ "$size" -lt $((1024 * 1024)) ]; then
			size=$((size * 6))
		elif [ "$size" -lt $((50 * 1024 * 1024)) ]; then
			size=$((size * 12 / 10))
		else
			# 否则，将大小增加到原来的1.1倍
			size=$((size * 11 / 10))
		fi
		echo "Partition configuration file update completed"
		echo "Packaging $(basename "$dir") partition file..."

		"$mkfs_tool_path" -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" >/dev/null 2>&1
		;;
	4)
		fs_type="f2fss"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.f2fs"
		sload_tool_path="$(dirname "$0")/resources/my_tools/sload.f2fs"
		# 计算目录的大小（单位：MB）
		size=$(($(du -sm "$dir" | cut -f1) * 11 / 10 + 55))

		echo "Partition configuration file update completed"
		echo "Packaging $(basename "$dir") partition file..."
		# 创建一个与目录大小相同的空镜像文件
		dd if=/dev/zero of="$output_image" bs=1M count=$size >/dev/null 2>&1
		"$mkfs_tool_path" "$output_image" -O extra_attr,inode_checksum,sb_checksum,compression -f -T "$utc" -q
		"$sload_tool_path" -f "$dir" -C "$fs_config_file" -s "$file_contexts_file" -t "/$(basename "$dir")" "$output_image" -c -T "$utc" >/dev/null 2>&1
		"$(dirname "$0")/resources/my_tools/img2simg" "$output_image" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir")_sparse.img"
		mv "$WORK_DIR/$current_workspace/Packed/$(basename "$dir")_sparse.img" "$output_image"
		;;
	5)
		fs_type="ext4s"
		mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.ext4fs"
		# 计算目录的大小
		size=$(du -sb "$dir" | cut -f1)
		if [ "$size" -lt $((1024 * 1024)) ]; then
			size=$((size * 6))
		elif [ "$size" -lt $((50 * 1024 * 1024)) ]; then
			size=$((size * 12 / 10))
		else
			# 否则，将大小增加到原来的1.1倍
			size=$((size * 11 / 10))
		fi
		echo "Partition configuration file update completed"
		echo "Packaging $(basename "$dir") partition file..."

		"$mkfs_tool_path" -s -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" >/dev/null 2>&1
		;;
	esac
	echo "$(basename "$dir") partition file packaging completed"
	end=$(date +%s%N)
	runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
	runtime=$(printf "%.3f" "$runtime")
	echo "Time consuming: $runtime seconds"
}

function package_special_partition {
	echo -e "Packaging $(basename "$dir") partition"
	# 获取开始时间
	start=$(date +%s%N)
	# 定义一个本地变量 dir
	local dir="$1"

	# 删除目录 "$TOOL_DIR/boot_editor/build/unzip_boot" 下的所有文件和文件夹
	rm -rf "$TOOL_DIR/boot_editor/build/unzip_boot"
	# 创建目录 "$TOOL_DIR/boot_editor/build/unzip_boot"
	mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"

	# 复制 "$dir" 下的所有文件和文件夹到 "$TOOL_DIR/boot_editor/build/unzip_boot"
	cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"

	# 遍历所有的 .img 文件
	for file in $(find $TOOL_DIR/boot_editor -type f -name "*.img"); do
		# 获取文件的基本名（不包含扩展名）
		base_name=$(basename "$file" .img)

		# 将 .img 文件重命名为 .img.wait
		mv "$file" "$TOOL_DIR/boot_editor/${base_name}.img.wait"
	done

	# 将文件 "$(basename "$dir").img.wait" 移动并重命名为 "$(basename "$dir").img"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait" "$TOOL_DIR/boot_editor/$(basename "$dir").img"

	# 在 "$TOOL_DIR/boot_editor" 目录下执行 ./gradlew pack 命令
	(cd "$TOOL_DIR/boot_editor" && ./gradlew pack) >/dev/null 2>&1

	# 将 "$(basename "$dir").img.signed" 文件复制到 "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
	cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
	# 将 "$(basename "$dir").img.signed" 文件移动并重命名为 "$(basename "$dir").img"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$TOOL_DIR/boot_editor/$(basename "$dir").img"
	# 将 "$(basename "$dir").img" 文件移动并重命名为 "$(basename "$dir").img.wait"
	mv "$TOOL_DIR/boot_editor/$(basename "$dir").img" "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait"

	rm -rf "$TOOL_DIR/boot_editor/build"

	echo "$(basename "$dir") partition file packaging completed"

	end=$(date +%s%N)
	runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
	runtime=$(printf "%.3f" "$runtime")
	echo "Time consuming: $runtime seconds"
}

function package_regular_image {
	mkdir -p "$WORK_DIR/$current_workspace/Packed"
	while true; do
		echo -e "\nCurrent partition directory:\n"
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
			echo -e "\n No partition files were detected."
			echo -n "  Press any key to return..."
			read -n 1
			clear
			return
		fi
		echo -e " [ALL] Pack all partition files [Q] Return to the workspace menu\n"
		echo -n "   请选择打包的分区目录："
		read dir_num
		dir_num=$(echo "$dir_num" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
		if [ "$dir_num" = "all" ]; then
			if [ $special_dir_count -ne ${#dir_array[@]} ]; then
				clear
				while true; do
					echo -e "\n   [1] EROFS    [2] F2FS    [3] EXT4"
					echo -e "\n   [4] F2FSS    [5] EXT4S\n"
					echo -e " [Q] Return to the workspace menu\n"
					echo -n "  please select the file system type to be packaged:"
					read fs_type_choice
					fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
					if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" || "$fs_type_choice" == "4" || "$fs_type_choice" == "5" ]]; then
						break
					elif [ "$fs_type_choice" = "q" ]; then
						return
					else
						clear
						echo -e "\n Invalid input, please re-enter."
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
						echo -e " [Q] Return to the workspace menu\n"
						echo -n "  please select the file system type to be packaged:"
						read fs_type_choice
						fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase
						if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" || "$fs_type_choice" == "3" || "$fs_type_choice" == "4" || "$fs_type_choice" == "5" ]]; then
							break
						elif [ "$fs_type_choice" = "q" ]; then
							return
						else
							clear
							echo -e "\n Invalid input, please re-enter."
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
				echo -e "\n The selected directory does not exist, please select again."
			fi
		fi
	done
}
