function extract_single_img {
  local single_file="$1"
  local single_file_name=$(basename "$single_file")
  local base_name="${single_file_name%.*}"
  fs_type=$(recognize_file_type "$single_file")
  start=$(date +%s%N)
  if [[ "$fs_type" == "ext" || "$fs_type" == "erofs" || "$fs_type" == "f2fs" || \
        "$fs_type" == "boot" || "$fs_type" == "dtbo" || "$fs_type" == "recovery" || \
        "$fs_type" == "vbmeta" || "$fs_type" == "vendor_boot" ]]; then
    rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
  fi
  case "$fs_type" in
    sparse)
      echo "Converting sparse partition file ${single_file_name}, please wait..."
      "$TOOL_DIR/simg2img" "$single_file" "$WORK_DIR/$current_workspace/${base_name}_converted.img"
      rm -rf "$single_file"
      mv "$WORK_DIR/$current_workspace/${base_name}_converted.img" "$WORK_DIR/$current_workspace/${base_name}.img"
      single_file="$WORK_DIR/$current_workspace/${base_name}.img"
      extract_single_img "$single_file"
      return
      ;;
    super)
      echo "Extracting SUPER partition file ${single_file_name}, please wait..."
      "$TOOL_DIR/7z" e -bb1 -aoa "$single_file" -o"$WORK_DIR/$current_workspace"
      rm "$single_file"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
      ;;
    boot|dtbo|recovery|vbmeta|vendor_boot)
      echo "Extracting partition file ${single_file_name}, please wait..."
      rm -rf "$TOOL_DIR/boot_editor/build"
      cp "$single_file" "$TOOL_DIR/boot_editor/$single_file_name"
      (cd "$TOOL_DIR/boot_editor" && ./gradlew unpack) > /dev/null 2>&1
      rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mv -f "$TOOL_DIR/boot_editor/build/unzip_boot"/* "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mv -f "$TOOL_DIR/boot_editor/$base_name.img" "$TOOL_DIR/boot_editor/$base_name.img.wait"
      ;;
    f2fs)
      echo "Extracting partition file ${single_file_name}, please wait..."
      "$TOOL_DIR/extract.f2fs" "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" > /dev/null 2>&1
      ;;
    erofs)
      echo "Extracting partition file ${single_file_name}, please wait..."
      "$TOOL_DIR/extract.erofs" -i "$single_file" -o "$WORK_DIR/$current_workspace/Extracted-files" -x > /dev/null 2>&1
      ;;
    ext)
      echo "Extracting partition file ${single_file_name}, please wait..."
      PYTHONDONTWRITEBYTECODE=1 python "$TOOL_DIR/ext4_info_get.py" "$single_file" "$WORK_DIR/$current_workspace/Extracted-files/config"
      rm -rf "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      "$TOOL_DIR/extract.ext" "$single_file" "./:$WORK_DIR/$current_workspace/Extracted-files/$base_name"
      ;;
    payload)
      echo "Extracting ${single_file_name}, please wait..."
      "$TOOL_DIR/payload-dumper-go" -c 4 -o "$WORK_DIR/$current_workspace" "$single_file"
      rm -rf "$single_file"
      ;;
    *)
      echo "   Unknown file system type"
      ;;
  esac
  for file in "$WORK_DIR/$current_workspace"/*; do
    base_name=$(basename "$file")
    if [[ ! -s $file ]] || [[ $base_name == *_b.img ]] || [[ $base_name == *_b ]]; then
      rm "$file"
    elif [[ $base_name == *_a.img ]]; then
      mv -f "$file" "${file%_a.img}.img"
    elif [[ $base_name == *_a.ext ]]; then
      mv -f "$file" "${file%_a.ext}.img"
    elif [[ $base_name == *.ext ]]; then
      mv -f "$file" "${file%.ext}.img"
    fi
  done
  echo "${single_file_name} extraction completed"
  end=$(date +%s%N)
  runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
  runtime=$(printf "%.3f" "$runtime")
  echo "Time consumed: $runtime seconds"
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
        echo -e "\n   Current workspace files:\n"
        for i in "${!displayed_files[@]}"; do
          fs_type_upper=$(echo "$(recognize_file_type "${displayed_files[$i]}")" | awk '{print toupper($0)}')
          printf "   \033[92m[%02d] %s —— %s\033[0m\n\n" "$((i+1))" "$(basename "${displayed_files[$i]}")" "$fs_type_upper"
        done
        echo -e "   [ALL] Extract all    [S] Simple recognition    [Q] Return to the previous menu\n"
        echo -n "   Please select the partition file to extract: "
        read choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        if [ "$choice" = "all" ]; then
	  clear
	  echo -e "\n"
          for file in "${displayed_files[@]}"; do
            extract_single_img "$file"
          done
          echo -n "Press any key to return to the file list... "
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
            echo -n "Press any key to return to the file list... "
            read -n 1
            clear
            break
          else
            echo "   The selected file does not exist. "
          fi
        else
          clear
          echo -e "\n   Invalid selection, please re-enter. "
        fi
      done
    else
      echo -e "\n   There are no files in the workspace. "
      echo -n "   Press any key to return to the workspace menu... "
      read -n 1
      return
    fi
  done
}
