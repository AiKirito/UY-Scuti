function update_config_files {
  # 定义局部变量
  local partition="$1"
  local fs_config_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_fs_config"
  local file_contexts_file="$WORK_DIR/$current_workspace/Extracted-files/config/${partition}_file_contexts"

  # 创建临时文件来存储新的配置
  local temp_fs_config_file="$fs_config_file.tmp"
  local temp_file_contexts_file="$file_contexts_file.tmp"

  # 将原配置文件的所有内容复制到临时配置文件中
  cat "$fs_config_file" >> "$temp_fs_config_file"
  cat "$file_contexts_file" >> "$temp_file_contexts_file"

  # 遍历解包后的目录
  find "$WORK_DIR/$current_workspace/Extracted-files/$partition" -type f -o -type d -o -type l | while read -r file; do
    # 移除 "Extracted-files/" 前缀，得到相对路径
    relative_path="${file#$WORK_DIR/$current_workspace/Extracted-files/}"

    # 检查该路径是否已经在临时配置文件中
    if ! grep -Fq "$relative_path " "$temp_fs_config_file"; then
      # 如果不存在，则按照原来的方式添加
      if [ -d "$file" ]; then
        echo "$relative_path 0 0 0755" >> "$temp_fs_config_file"
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
          echo "$relative_path 0 $gid $mode $relative_link_target" >> "$temp_fs_config_file"
        else
          echo "$relative_path 0 $gid $mode" >> "$temp_fs_config_file"
        fi
      else
        # 处理普通文件
        local mode="0644"
        if [[ "$relative_path" == *".sh"* ]]; then
          mode="0750"
        fi
        echo "$relative_path 0 0 $mode" >> "$temp_fs_config_file"
      fi
    fi

    # 检查 file_contexts 文件中是否已经存在该路径
    # 转义路径中的特殊字符
    escaped_path=$(echo "$relative_path" | sed -e 's/[+.\\[()（）]/\\&/g' -e 's/]/\\]/g')
    if ! grep -Fq "/$escaped_path " "$temp_file_contexts_file"; then
      # 如果不存在，则添加新的上下文
      if [[ $relative_path == "$partition" ]]; then
        relative_path="/$relative_path/"
      fi
      if [[ $relative_path != /* ]]; then
        relative_path="/$relative_path"
      fi
      echo "/$escaped_path u:object_r:${partition}_file:s0" >> "$temp_file_contexts_file"
    fi
  done

  # 检查 lost+found 是否在配置文件和上下文文件中
  if ! grep -Fq "${partition}/lost+found " "$temp_fs_config_file"; then
    echo "${partition}/lost+found 0 0 0755" >> "$temp_fs_config_file"
  fi
  if ! grep -Fq "/${partition}/lost\+found " "$temp_file_contexts_file"; then
    echo "/${partition}/lost\+found u:object_r:${partition}_file:s0" >> "$temp_file_contexts_file"
  fi

  # 替换旧的配置文件
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
  echo -e "Updating the configuration file of $(basename "$dir") partition..."
  update_config_files "$(basename "$dir")"
  case "$fs_type_choice" in
    1)
      fs_type="erofs"
      mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
      echo "Partition configuration file update completed"
      echo "Packing files of $(basename "$dir") partition..."

      "$mkfs_tool_path" -zlz4hc,1 -T "$utc" --mount-point="/$(basename "$dir")" --fs-config-file="$fs_config_file" --product-out="$(dirname "$output_image")" --file-contexts="$file_contexts_file" "$output_image" "$dir" > /dev/null 2>&1
      ;;
    2)
      fs_type="ext4"
      mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.ext4fs"
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
      echo "Packing files of $(basename "$dir") partition..."

      "$mkfs_tool_path" -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" > /dev/null
      ;;
  esac
  echo "$(basename "$dir") partition file packing completed"
  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "Time consumed: $runtime seconds"
}

function package_special_partition {
  echo -e "Packing $(basename "$dir") partition"
  # Get the start time
  start=$(date +%s%N)
  # Define a local variable dir
  local dir="$1"

  # Delete all files and folders under the directory "$TOOL_DIR/boot_editor/build/unzip_boot"
  rm -rf "$TOOL_DIR/boot_editor/build/unzip_boot"
  # Create the directory "$TOOL_DIR/boot_editor/build/unzip_boot"
  mkdir -p "$TOOL_DIR/boot_editor/build/unzip_boot"

  # Copy all files and folders under "$dir" to "$TOOL_DIR/boot_editor/build/unzip_boot"
  cp -r "$dir"/. "$TOOL_DIR/boot_editor/build/unzip_boot"

  # Traverse all .img files
  for file in $(find $TOOL_DIR/boot_editor -type f -name "*.img")
  do
    # Get the base name of the file (excluding the extension)
    base_name=$(basename "$file" .img)

    # Rename the .img file to .img.wait
    mv "$file" "$TOOL_DIR/boot_editor/${base_name}.img.wait"
  done

  # Move and rename the file "$(basename "$dir").img.wait" to "$(basename "$dir").img"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait" "$TOOL_DIR/boot_editor/$(basename "$dir").img"

  # Execute the ./gradlew pack command under the "$TOOL_DIR/boot_editor" directory
  (cd "$TOOL_DIR/boot_editor" && ./gradlew pack) > /dev/null 2>&1

  # Copy the "$(basename "$dir").img.signed" file to "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
  cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
  # Move and rename the "$(basename "$dir").img.signed" file to "$(basename "$dir").img"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$TOOL_DIR/boot_editor/$(basename "$dir").img"
  # Move and rename the "$(basename "$dir").img" file to "$(basename "$dir").img.wait"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img" "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait"

  rm -rf "$TOOL_DIR/boot_editor/build"

  echo "$(basename "$dir") partition file packing completed"

  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "Time consumed: $runtime seconds"
}

function package_regular_image {
  mkdir -p "$WORK_DIR/$current_workspace/Packed"
  while true; do
    echo -e "\n   Current partition directory: \n"
    local i=1
    local dir_array=()
    local special_dir_count=0
    for dir in "$WORK_DIR/$current_workspace/Extracted-files"/*; do
      if [ -d "$dir" ] && [ "$(basename "$dir")" != "config" ] && [ "$(basename "$dir")" != "super" ]; then
        printf "   \033[0;31m[%02d] %s\033[0m\n\n" "$i" "$(basename "$dir")"  
        dir_array[i]="$dir"
        i=$((i+1))
        if [[ "$(basename "$dir")" == "dtbo" || "$(basename "$dir")" == "boot" || "$(basename "$dir")" == "init_boot" || "$(basename "$dir")" == "vendor_boot" || "$(basename "$dir")" == "recovery" || "$(basename "$dir")" == *"vbmeta"* ]]; then
          special_dir_count=$((special_dir_count+1))
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
    echo -n "   Please select the partition directory to be packaged: "
    read dir_num
    dir_num=$(echo "$dir_num" | tr '[:upper:]' '[:lower:]')  # Convert input to lowercase
    if [ "$dir_num" = "all" ]; then
      if [ $special_dir_count -ne ${#dir_array[@]} ]; then
        clear
        while true; do
          echo -e "\n   [1] EROFS    "  "[2] EXT4\n"
          echo -e "   [Q] Return to workspace menu\n"
          echo -n "   Please select the file system type to be packaged: "
          read fs_type_choice
          fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')  # Convert input to lowercase
          if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" ]]; then
            break
          elif [ "$fs_type_choice" = "q" ]; then
            return
          else
            clear
            echo -e "\n   Invalid input, please re-enter."
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
      echo -n "Packaging complete, press any key to return..."
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
            echo -e "\n   [1] EROFS    "  "[2] EXT4\n"
            echo -e "   [Q] Return to workspace menu\n"
            echo -n "   Please select the file system type to be packaged: "
            read fs_type_choice
            fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')  # Convert input to lowercase
            if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" ]]; then
              break
            elif [ "$fs_type_choice" = "q" ]; then
              return
            else
              clear
              echo -e "\n   Invalid input, please re-enter."
            fi
          done
          clear
          echo -e "\n"
          package_single_partition "$dir" "$fs_type_choice"
        fi
        echo -n "Packaging complete, press any key to return..."
        read -n 1
        clear
        continue
      else
        clear
        echo -e "\n   The selected directory does not exist, please re-select."
      fi
    fi
  done
}
