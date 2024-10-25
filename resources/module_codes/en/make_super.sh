function create_super_img {
	local partition_type=$1
	local is_sparse=$2
	local img_files=()

	# 筛选出文件类型为 ext, f2fs, erofs 的文件
	for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
		file_type=$(recognize_file_type "$file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
			img_files+=("$file")
		fi
	done

	# 计算 super 文件夹中所有文件的总字节数
	local total_size=0
	for img_file in "${img_files[@]}"; do
		file_type=$(recognize_file_type "$img_file")
		# 计算文件的大小
		file_size_bytes=$(stat -c%s "$img_file")
		total_size=$((total_size + file_size_bytes))
	done
	remainder=$((total_size % 4096))
	if [ $remainder -ne 0 ]; then
		total_size=$((total_size + 4096 - remainder))
	fi

	# 定义额外的空间大小
	local extra_space=$((100 * 1024 * 1024 * 1024 / 100))

	# 根据分区类型调整 total_size 的值
	case "$partition_type" in
	"AB")
		total_size=$(((total_size + extra_space) * 2))
		;;
	"OnlyA" | "VAB")
		total_size=$((total_size + extra_space))
		;;
	esac
	clear

	while true; do
		local original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
		# 根据是否能读取到 original_super_size 文件的值，显示不同的选项
		echo -e ""
		echo -n " [1] 9126805504 [2] $total_size --automatic calculation"
		if [ -n "$original_super_size" ]; then
			echo -e " [3] [31m$original_super_size [0m --original size\n"
		else
			echo -e "\n"
		fi

		echo -e " [C] Custom input [Q] Return to workspace menu\n"
		echo -n "  please select the package size:"
		read device_size_option

		# 根据用户的选择，设置 device_size 的值
		case "$device_size_option" in
		1)
			device_size=9126805504
			if ((device_size < total_size)); then
				echo "  is smaller than the automatically calculated size, please execute other options."
				continue
			fi
			break
			;;
		2)
			device_size=$total_size
			if ((device_size < total_size)); then
				echo "  is smaller than the automatically calculated size, please execute other options."
				continue
			fi
			break
			;;
		3)
			if [ -n "$original_super_size" ]; then
				device_size=$original_super_size
				if ((device_size < total_size)); then
					echo "  is smaller than the automatically calculated size, please execute other options."
					continue
				fi
				break
			else
				clear
				echo -e "\n Invalid selection, please re-enter."
			fi
			;;
		C | c)
			clear
			while true; do
				echo -e "\n Tip: The automatically calculated size is $total_size\n"
				echo -e " [Q] Return to the workspace menu\n"
				echo -n "  please enter a custom size:"
				read device_size

				if [[ "$device_size" =~ ^[0-9]+$ ]]; then
					# 如果输入值小于 total_size，要求重新输入
					if ((device_size < total_size)); then
						clear
						echo -e "\n The value entered is less than the automatically calculated size, please re-enter"
					else
						if ((device_size % 4096 == 0)); then
							break
						else
							clear
							echo -e "\nThe entered value is not a multiple of 4096 bytes, please re-enter"
						fi
					fi
				elif [ "${device_size,,}" = "q" ]; then
					return
				else
					clear
					echo -e "\n Invalid input, please re-enter"
				fi
			done
			break
			;;
		Q | q)
			echo "  has canceled the packaging operation and returned to the work domain menu."
			return
			;;
		*)
			clear
			echo -e "\n Invalid selection, please re-enter."
			;;
		esac
	done

	clear # 清除屏幕
	echo -e "\n"

	# 其他参数
	local metadata_size="65536"
	local block_size="4096"
	local super_name="super"
	local group_name="qti_dynamic_partitions"
	local group_name_a="${group_name}_a"
	local group_name_b="${group_name}_b"

	# 根据分区类型设置 metadata_slots 的值
	case "$partition_type" in
	"AB" | "VAB")
		metadata_slots="3"
		;;
	*)
		metadata_slots="2"
		;;
	esac

	# 初始化参数字符串
	local params=""

	case "$is_sparse" in
	"yes")
		params+="--sparse"
		;;
	esac

	case "$partition_type" in
	"VAB")
		overhead_adjusted_size=$((device_size - 10 * 1024 * 1024))
		params+=" --group \"$group_name_a:$overhead_adjusted_size\""
		params+=" --group \"$group_name_b:$overhead_adjusted_size\""
		params+=" --virtual-ab"
		;;
	"AB")
		overhead_adjusted_size=$(((device_size / 2) - 10 * 1024 * 1024))
		params+=" --group \"$group_name_a:$overhead_adjusted_size\""
		params+=" --group \"$group_name_b:$overhead_adjusted_size\""
		;;
	*)
		overhead_adjusted_size=$((device_size - 10 * 1024 * 1024))
		params+=" --group \"$group_name:$overhead_adjusted_size\""
		;;
	esac

	# 计算每个分区所拥有的大小
	for img_file in "${img_files[@]}"; do
		# 从文件路径中提取文件名
		local base_name=$(basename "$img_file")
		local partition_name=${base_name%.*}

		# 计算文件的大小
		local partition_size=$(stat -c%s "$img_file")

		# 根据文件系统类型设置 read-write 属性
		local file_type=$(recognize_file_type "$img_file")
		if [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]]; then
			local read_write_attr="none"
		else
			local read_write_attr="readonly"
		fi

		# 根据分区类型设置分区组名参数
		case "$partition_type" in
		"VAB")
			params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
			params+=" --image \"${partition_name}_a=$img_file\""
			params+=" --partition \"${partition_name}_b:$read_write_attr:0:$group_name_b\""
			;;
		"AB")
			params+=" --partition \"${partition_name}_a:$read_write_attr:$partition_size:$group_name_a\""
			params+=" --image \"${partition_name}_a=$img_file\""
			params+=" --partition \"${partition_name}_b:$read_write_attr:$partition_size:$group_name_b\""
			params+=" --image \"${partition_name}_b=$img_file\""
			;;
		*)
			params+=" --partition \"$partition_name:$read_write_attr:$partition_size:$group_name\""
			params+=" --image \"$partition_name=$img_file\""
			;;
		esac
	done

	echo -e "Packaging SUPER partition, waiting...\n.............\n............ ....\n............."
	mkdir -p "$WORK_DIR/$current_workspace/Repacked"
	local start=$(python3 "$TOOL_DIR/get_right_time.py")

	eval "$TOOL_DIR/lpmake  \
    --device-size \"$device_size\" \
    --metadata-size \"$metadata_size\" \
    --metadata-slots \"$metadata_slots\" \
    --block-size \"$block_size\" \
    --super-name \"$super_name\" \
    --force-full-image \
    $params \
    --output \"$WORK_DIR/$current_workspace/Repacked/super.img\"" >/dev/null 2>&1

	echo "SUPER partition has been packed"

	local end=$(python3 "$TOOL_DIR/get_right_time.py")
	local runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
	echo "Time consuming: $runtime seconds"

	echo -n "Press any key to return to the workspace menu..."
	read -n 1
}

function package_super_image {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
	# 检测 $WORK_DIR/$current_workspace/Repacked 内的 img 文件
	detected_files=()
	while IFS= read -r line; do
		line=$(echo "$line" | xargs) # Remove leading and trailing spaces
		if [ -e "$WORK_DIR/$current_workspace/Repacked/$line" ]; then
			detected_files+=("$WORK_DIR/$current_workspace/Repacked/$line")
		fi
	done < <(grep -oP '^[^#]+' "$TOOL_DIR/super_search")
	# 询问是否移动到 super 文件夹
	if [ ${#detected_files[@]} -gt 0 ]; then
		while true; do
			echo -e "\n   侦测到已打包的子分区：\n"
			for file in "${detected_files[@]}"; do
				echo -e "   \e[95m☑   $(basename "$file")\e[0m\n"
			done
			echo -e "\n Do you want to move these files to the directory to be packaged?"
			echo -e "\n [1] Move [2] Don't move\n"
			echo -n "  choose your operation:"
			read move_files
			clear
			if [[ "$move_files" = "1" ]]; then
				for file in "${detected_files[@]}"; do
					mv "$file" "$WORK_DIR/$current_workspace/Extracted-files/super/"
				done
				break
			elif [[ "$move_files" = "2" ]]; then
				break
			else
				echo -e "\nInvalid selection, please re-enter.\n"
			fi
		done
	fi
	# 获取所有镜像文件
	shopt -s nullglob
	img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
	shopt -u nullglob
	real_img_files=()
	for file in "${img_files[@]}"; do
		if [ -e "$file" ]; then
			real_img_files+=("$file")
		fi
	done
	# 检查是否有足够的镜像文件
	if [ ${#real_img_files[@]} -lt 2 ]; then
		echo -e "\n The SUPER directory needs to contain at least two image files."
		read -n 1 -s -r -p "  Press any key to return to the workspace menu..."
		return
	fi
	# 检查是否有被禁止的文件
	forbidden_files=()
	for file in "${real_img_files[@]}"; do
		filename=$(basename "$file")
		if ! grep -q -x "$filename" "$TOOL_DIR/super_search"; then
			forbidden_files+=("$file")
		fi
	done
	# 如果有被禁止的文件，显示错误信息并返回
	if [ ${#forbidden_files[@]} -gt 0 ]; then
		echo -e "\n Refusal to execute, the following files are prohibited from merging\n"
		for file in "${forbidden_files[@]}"; do
			echo -e "    u001b[33m☒   $(basename "$file")u001b[0m\n"
		done
		read -n 1 -s -r -p "  Press any key to return to the workspace menu..."
		return
	fi
	# 询问用户是否要打包
	while true; do
		# 列出目标目录下的所有子文件，每个文件前面都有一个编号
		echo -e "\n Subpartition of the directory to be packed:\n"
		for i in "${!img_files[@]}"; do
			file_name=$(basename "${img_files[$i]}")
			printf "   \e[96m[%02d] %s\e[0m\n\n" $((i + 1)) "$file_name"
		done
		echo -e "\n [1] Start packaging [Q] Return to workspace menu\n"
		echo -n "  selects the function you want to perform:"
		read is_pack
		is_pack=$(echo "$is_pack" | tr '[:upper:]' '[:lower:]')
		clear
		# 处理用户的选择
		case "$is_pack" in
		1)
			# 用户选择了打包，询问分区类型和打包方式
			while true; do
				echo -e "\n [1] OnlyA dynamic partition [2] AB dynamic partition [3] VAB dynamic partition\n"
				echo -e " [Q] Return to the workspace menu\n"
				echo -n "  please select your partition type:"
				read partition_type
				partition_type=$(echo "$partition_type" | tr '[:upper:]' '[:lower:]')
				if [ "$partition_type" = "q" ]; then
					echo "  has deselected the partition type and returned to the workspace menu."
					return
				fi
				clear
				# 处理用户选择的分区类型
				case "$partition_type" in
				1 | 2 | 3)
					# 用户选择了有效的分区类型，询问打包方式
					while true; do
						echo -e "\n [1] sparse [2] non-sparse\n"
						echo -e " [Q] Return to the workspace menu\n"
						echo -n "  please select the packaging method:"
						read is_sparse
						is_sparse=$(echo "$is_sparse" | tr '[:upper:]' '[:lower:]')
						if [ "$is_sparse" = "q" ]; then
							echo "  has been deselected, returning to the workspace menu."
							return
						fi
						# 处理用户选择的打包方式
						case "$is_sparse" in
						1 | 2)
							break
							;;
						*)
							clear
							echo -e "\n Invalid selection, please re-enter."
							;;
						esac
					done
					break
					;;
				*)
					clear
					echo -e "\n Invalid selection, please re-enter."
					;;
				esac
			done
			break
			;;
		q)
			echo "The packaging operation has been canceled and returns to the previous menu."
			return
			;;
		*)
			clear
			echo -e "\n Invalid selection, please re-enter."
			;;
		esac
	done
	# 在这里添加你的代码，处理用户输入后面的部分
	case "$partition_type-$is_sparse" in
	1-1)
		create_super_img "OnlyA" "yes"
		;;
	1-2)
		create_super_img "OnlyA" "no"
		;;
	2-1)
		create_super_img "AB" "yes"
		;;
	2-2)
		create_super_img "AB" "no"
		;;
	3-1)
		create_super_img "VAB" "yes"
		;;
	3-2)
		create_super_img "VAB" "no"
		;;
	*)
		echo "  Invalid selection, please re-enter."
		;;
	esac
}
