function extract_single_img {
  local single_file="$1"
  local single_file_name=$(basename "$single_file")
  local base_name="${single_file_name%.*}"
  fs_type=$(recognize_file_type "$single_file")
  start=$(date +%s%N)
  # 在提取前清理一次目标文件夹
  rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
  case "$fs_type" in
    sparse)
      echo "正在转换稀疏分区文件 ${single_file_name}，请稍等..."
      "$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
      rm -rf "$single_file"
      mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
      single_file="$WORK_DIR/$current_workspace/${base_name}.img"
      fs_type=$(recognize_file_type "$single_file")
      if [ "$fs_type" == "super" ]; then
        echo "正在提取非稀疏 SUPER 分区文件 ${single_file_name}，请稍等..."
        "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
        rm "$single_file"
        mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
      fi
      ;;
    super)
      echo "正在提取非稀疏 SUPER 分区文件 ${single_file_name}，请稍等..."
      "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
      rm "$single_file"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
      ;;
    boot|dtbo|recovery|vbmeta|vendor_boot)
      echo "正在提取分区文件 ${single_file_name}，请稍等..."
      rm -rf "$TOOL_DIR/boot_editor/build"
      cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
      (cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) > /dev/null 2>&1
      rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mv -f "$TOOL_DIR/boot_editor/$base_name.img" "$TOOL_DIR/boot_editor/$base_name.img.wait"
      ;;
    f2fs)
      echo "正在提取分区文件 ${single_file_name}，请稍等..."
      "$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" > /dev/null 2>&1
      ;;
    erofs)
      echo "正在提取分区文件 ${single_file_name}，请稍等..."
      "$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x > /dev/null 2>&1
      ;;
    ext)
      echo "正在提取分区文件 ${single_file_name}，请稍等..."
      PYTHONDONTWRITEBYTECODE=1 python "$TOOL_DIR/ext4_info_get.py" "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config"
      rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      "$TOOL_DIR/extract.ext" "$single_file" "./:$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      ;;
    payload)
      echo "正在提取 ${single_file_name}，请稍等..."
      "$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file" > /dev/null 2>&1
      rm -rf "$single_file"
      ;;
    *)
      echo "   未知的文件系统类型"
      ;;
  esac
  for file in "$WORK_DIR/$current_workspace"/*; do
    base_name=$(basename "$file")
    if [[ ! -s $file ]] || [[ $base_name == *_b.img ]] || [[ $base_name == *_b ]] || [[ $base_name == *_b.ext ]]; then
      rm -rf "$file"
    elif [[ $base_name == *_a.img ]]; then
      mv -f "$file" "${file%_a.img}.img"
    elif [[ $base_name == *_a.ext ]]; then
      mv -f "$file" "${file%_a.ext}.img"
    fi
  done
  echo "${single_file_name} 提取完成"
  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "耗时： $runtime 秒"
}

function extract_img {
  mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
  while true; do
    shopt -s nullglob
    matched_bin_files=("$WORK_DIR/$current_workspace"/*.bin)
    matched_img_files=("$WORK_DIR/$current_workspace"/*.img)
    matched_files=("${matched_bin_files[@]}" "${matched_img_files[@]}")
    shopt -u nullglob
    if [ -e "${matched_files[0]}" ]; then
      displayed_files=()
      counter=0
      for i in "${!matched_files[@]}"; do
        if [ -f "${matched_files[$i]}" ]; then
          fs_type=$(recognize_file_type "${matched_files[$i]}")
          if [ "$fs_type" != "unknown" ]; then
            displayed_files+=("${matched_files[$i]}")
            counter=$((counter+1))
          fi
        fi
      done
      while true; do
        echo -e "\n   当前工作域的文件：\n"
        for i in "${!displayed_files[@]}"; do
          fs_type_upper=$(echo "$(recognize_file_type "${displayed_files[$i]}")" | awk '{print toupper($0)}')
          printf "   \033[92m[%02d] %s —— %s\033[0m\n\n" "$((i+1))" "$(basename "${displayed_files[$i]}")" "$fs_type_upper"
        done
        echo -e "   [ALL] 提取所有    [S] 简易识别    [Q] 返回上级菜单\n"
        echo -n "   请选择要提取的分区文件："
        read choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [ "$choice" = "all" ]; then
	  clear
          for file in "${displayed_files[@]}"; do
	    echo -e "\n"
            extract_single_img "$file"
          done
          echo -n "按任意键返回文件列表..."
          read -n 1
          clear
          break
        elif [ "$choice" = "s" ]; then
          mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
          for file in "$WORK_DIR/$current_workspace"/*.img; do
            filename=$(basename "$file")
            if ! grep -q "$filename" "$TOOL_DIR/super_search"; then
              mv "$file" "$WORK_DIR/$current_workspace/Ready-to-flash/images/"
            fi
          done
          clear
          break
        elif [ "$choice" = "q" ]; then
          return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#displayed_files[@]} ]; then
          file="${displayed_files[$((choice-1))]}"
          if [ -f "$file" ]; then
            clear
            echo -e "\n"
            extract_single_img "$file"
            echo -n "按任意键返回文件列表..."
            read -n 1
            clear
            break
          else
            echo "   选择的文件不存在。"
          fi
        else
          clear
          echo -e "\n   无效的选择，请重新输入。"
        fi
      done
    else
      echo -e "\n   工作域中没有文件。"
      echo -n "   按任意键返回工作域菜单..."
      read -n 1
      return
    fi
  done
}
