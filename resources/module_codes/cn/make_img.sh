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
  echo -e "正在更新 $(basename "$dir") 分区的配置文件..."
  update_config_files "$(basename "$dir")"
  case "$fs_type_choice" in
    1)
      fs_type="erofs"
      mkfs_tool_path="$(dirname "$0")/resources/my_tools/make.erofs"
      echo "分区配置文件更新完成"
      echo "正在打包 $(basename "$dir") 分区文件..."

      "$mkfs_tool_path" -d1 -zlz4hc,1 -T "$utc" --mount-point="/$(basename "$dir")" --fs-config-file="$fs_config_file" --product-out="$(dirname "$output_image")" --file-contexts="$file_contexts_file" "$output_image" "$dir" > /dev/null
 
      ;;
    2)
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
      echo "分区配置文件更新完成"
      echo "正在打包 $(basename "$dir") 分区文件..."

      "$mkfs_tool_path" -J -l "$size" -b 4096 -S "$file_contexts_file" -L $(basename "$dir") -a "/$(basename "$dir")" -C "$fs_config_file" -T "$utc" "$output_image" "$dir" > /dev/null
      ;;
  esac
  echo "$(basename "$dir") 分区文件打包完成"
  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "耗时： $runtime 秒"
}

function package_special_partition {
  echo -e "正在打包 $(basename "$dir") 分区"
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
  for file in $(find $TOOL_DIR/boot_editor -type f -name "*.img")
  do
    # 获取文件的基本名（不包含扩展名）
    base_name=$(basename "$file" .img)

    # 将 .img 文件重命名为 .img.wait
    mv "$file" "$TOOL_DIR/boot_editor/${base_name}.img.wait"
  done

  # 将文件 "$(basename "$dir").img.wait" 移动并重命名为 "$(basename "$dir").img"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait" "$TOOL_DIR/boot_editor/$(basename "$dir").img"

  # 在 "$TOOL_DIR/boot_editor" 目录下执行 ./gradlew pack 命令
  (cd "$TOOL_DIR/boot_editor" && ./gradlew pack) > /dev/null 2>&1

  # 将 "$(basename "$dir").img.signed" 文件复制到 "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
  cp -r "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$WORK_DIR/$current_workspace/Packed/$(basename "$dir").img"
  # 将 "$(basename "$dir").img.signed" 文件移动并重命名为 "$(basename "$dir").img"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img.signed" "$TOOL_DIR/boot_editor/$(basename "$dir").img"
  # 将 "$(basename "$dir").img" 文件移动并重命名为 "$(basename "$dir").img.wait"
  mv "$TOOL_DIR/boot_editor/$(basename "$dir").img" "$TOOL_DIR/boot_editor/$(basename "$dir").img.wait"

  rm -rf "$TOOL_DIR/boot_editor/build"

  echo "$(basename "$dir") 分区文件打包完成"

  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "耗时： $runtime 秒"
}

function package_regular_image {
  mkdir -p "$WORK_DIR/$current_workspace/Packed"
  while true; do
    echo -e "\n   当前分区目录：\n"
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
      echo -e "\n   没有检测到任何分区文件。"
      echo -n "   按任意键返回..."
      read -n 1
      clear
      return
    fi
    echo -e "   [ALL] 打包所有分区文件    [Q] 返回工作域菜单\n"
    echo -n "   请选择打包的分区目录："
    read dir_num
    dir_num=$(echo "$dir_num" | tr '[:upper:]' '[:lower:]')  # 将输入转换为小写
    if [ "$dir_num" = "all" ]; then
      if [ $special_dir_count -ne ${#dir_array[@]} ]; then
        clear
        while true; do
          echo -e "\n   [1] EROFS    "  "[2] EXT4\n"
          echo -e "   [Q] 返回工作域菜单\n"
          echo -n "   请选择要打包的文件系统类型："
          read fs_type_choice
          fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')  # 将输入转换为小写
          if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" ]]; then
            break
          elif [ "$fs_type_choice" = "q" ]; then
            return
          else
            clear
            echo -e "\n   无效的输入，请重新输入。"
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
      echo -n "打包完成，按任意键返回..."
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
            echo -e "   [Q] 返回工作域菜单\n"
            echo -n "   请选择要打包的文件系统类型："
            read fs_type_choice
            fs_type_choice=$(echo "$fs_type_choice" | tr '[:upper:]' '[:lower:]')  # 将输入转换为小写
            if [[ "$fs_type_choice" == "1" || "$fs_type_choice" == "2" ]]; then
              break
            elif [ "$fs_type_choice" = "q" ]; then
              return
            else
              clear
              echo -e "\n   无效的输入，请重新输入。"
            fi
          done
          clear
          echo -e "\n"
          package_single_partition "$dir" "$fs_type_choice"
        fi
        echo -n "打包完成，按任意键返回..."
        read -n 1
        clear
        continue
      else
        clear
        echo -e "\n   选择的目录不存在，请重新选择。"
      fi
    fi
  done
}
