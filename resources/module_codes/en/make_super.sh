function create_super_img {
  local partition_type=$1
  local is_sparse=$2
  local img_files=()
  
  for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
    file_type=$(recognize_file_type "$file")
    if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
      img_files+=("$file")
    fi
  done

  local total_size=0
  for img_file in "${img_files[@]}"; do
    file_type=$(recognize_file_type "$img_file")
    file_size_bytes=$(stat -c%s "$img_file")
    total_size=$((total_size + file_size_bytes))
  done
  remainder=$((total_size % 4096))
  if [ $remainder -ne 0 ]; then
    total_size=$((total_size + 4096 - remainder))
  fi

  local extra_space=$((100 * 1024 * 1024 * 1024 / 100))

  case "$partition_type" in
    "AB")
      total_size=$(((total_size + extra_space) * 2))
      ;;
    "OnlyA"|"VAB")
      total_size=$((total_size + extra_space))
      ;;
  esac
  clear

  while true; do
    local original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" 2>/dev/null)
    echo -e ""
    echo -n "   [1] 9126805504    [2] $total_size --Auto Calculate"
    if [ -n "$original_super_size" ]; then
      echo -e "    [3] \e[31m$original_super_size\e[0m --Original Size\n"
    else
      echo -e "\n"
    fi

    echo -e "   [C] Custom Input    [Q] Return to Workspace Menu\n"
    echo -n "   Please select the package size: "
    read device_size_option

    case "$device_size_option" in
      1)
        device_size=9126805504
        if ((device_size < total_size)); then
          echo "   Less than auto-calculated size, please choose another option."
          continue
        fi
        break
        ;;
      2)
        device_size=$total_size
        if ((device_size < total_size)); then
          echo "   Less than auto-calculated size, please choose another option."
          continue
        fi
        break
        ;;
      3)
        if [ -n "$original_super_size" ]; then
          device_size=$original_super_size
          if ((device_size < total_size)); then
            echo "   Less than auto-calculated size, please choose another option."
            continue
          fi
          break
        else
          clear
          echo -e "\n   Invalid choice, please re-enter."
        fi
        ;;
      C|c)
        clear
        while true; do
          echo -e "\n   Note: Auto-calculated size is $total_size\n"
          echo -e "   [Q] Return to Workspace Menu\n"
          echo -n "   Please enter custom size: "
          read device_size

          if [[ "$device_size" =~ ^[0-9]+$ ]]; then
            if ((device_size < total_size)); then
              clear
              echo -e "\n   The entered value is less than the auto-calculated size, please re-enter"
            else
              if ((device_size % 4096 == 0)); then
                break 
              else
                clear
                echo -e "\n   The entered value is not a multiple of 4096 bytes, please re-enter"
              fi
            fi
          elif [ "${device_size,,}" = "q" ]; then
            return
          else
            clear
            echo -e "\n   Invalid input, please re-enter"
          fi
        done
        break
        ;;
      Q|q)
        echo "   Packaging operation canceled, returning to workspace menu."
        return
        ;;
      *)
        clear
        echo -e "\n   Invalid choice, please re-enter."
        ;;
    esac
  done

  clear
  echo -e "\n"

  local metadata_size="65536"
  local block_size="4096"
  local super_name="super"
  local group_name="qti_dynamic_partitions"
  local group_name_a="${group_name}_a"
  local group_name_b="${group_name}_b"

  case "$partition_type" in
    "AB"|"VAB")
      metadata_slots="3"
      ;;
    *)
      metadata_slots="2"
      ;;
  esac

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

  for img_file in "${img_files[@]}"; do
    local base_name=$(basename "$img_file")
    local partition_name=${base_name%.*}
    local partition_size=$(stat -c%s "$img_file")
    local file_type=$(recognize_file_type "$img_file")
    if [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]]; then
      local read_write_attr="none"
    else
      local read_write_attr="readonly"
    fi

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

  echo -e "Packaging SUPER partition, please wait...\n..................\n..................\n.................."
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
    --output \"$WORK_DIR/$current_workspace/Repacked/super.img\"" > /dev/null 2>&1

  echo "SUPER partition packaged"

  local end=$(python3 "$TOOL_DIR/get_right_time.py")
  local runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
  echo "Time taken: $runtime seconds"

  echo -n "Press any key to return to the workspace menu..."
  read -n 1
}

function package_super_image {
  echo -e "\n"
  mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"

  # Get all image files
  img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
  real_img_files=()
  for file in "${img_files[@]}"; do
    if [ -e "$file" ]; then
      real_img_files+=("$file")
    fi
  done

  # Check if there are enough image files
  if [ ${#real_img_files[@]} -lt 2 ]; then
    echo "   The SUPER directory should contain at least two image files."
    read -n 1 -s -r -p "   Press any key to return to the workspace menu..."
    return
  fi

  # Check for forbidden files
  forbidden_files=()
  for file in "${real_img_files[@]}"; do
    filename=$(basename "$file")
    if ! grep -q -x "$filename" "$TOOL_DIR/super_search"; then
      forbidden_files+=("$file")
    fi
  done

  # If there are forbidden files, display an error message and return
  if [ ${#forbidden_files[@]} -gt 0 ]; then
    echo -e "   Forbidden partition files for packaging:\n"
    for file in "${forbidden_files[@]}"; do
      echo -e "   \e[33m$(basename "$file")\e[0m\n"
    done
    read -n 1 -s -r -p "   Press any key to return to the workspace menu..."
    return
  fi

  # Ask the user if they want to package
  while true; do
    # List all subfiles in the target directory, each file has a number in front
    echo -e "   SUPER partitions to be packaged:\n"
    for i in "${!img_files[@]}"; do
      file_name=$(basename "${img_files[$i]}")
      printf "   \e[96m[%02d] %s\e[0m\n\n" $((i+1)) "$file_name"
    done

    echo -e "\n   [Y] Package SUPER    "  "[N] Return to workspace menu\n"
    echo -n "   Choose the function you want to execute:"
    read is_pack
    clear

    # Handle the user's choice
    case "$is_pack" in
      Y|y)
        # The user chose to package, ask for partition type and packaging method
        while true; do
          echo -e "\n   [1] OnlyA Dynamic Partition    "  "[2] AB Dynamic Partition    "  "[3] VAB Dynamic Partition\n"
          echo -e "   [Q] Return to workspace menu\n"
          echo -n "   Please choose your partition type:"
          read partition_type

          if [ "${partition_type,,}" = "q" ]; then  # Convert user input to lowercase
            echo "   Partition type selection cancelled, returning to workspace menu."
            return
          fi
          clear

          # Handle the user's chosen partition type
          case "$partition_type" in
            1|2|3)
              # The user chose a valid partition type, ask for packaging method
              while true; do
                echo -e "\n   [1] Sparse    "  "[2] Non-sparse\n"
                echo -e "   [Q] Return to workspace menu\n"
                echo -n "   Please choose the packaging method:"
                read is_sparse

                if [ "${is_sparse,,}" = "q" ]; then
                  echo "   Selection cancelled, returning to workspace menu."
                  return
                fi

                # Handle the user's chosen packaging method
                case "$is_sparse" in
                  1|2)
                    break 
                    ;;
                  *)
                    clear
                    echo -e "\n   Invalid selection, please re-enter."
                    ;;
                esac
              done
              break 
              ;;
            *)
              clear
              echo -e "\n   Invalid selection, please re-enter."
              # If the user input is invalid, continue the loop
              ;;
          esac
        done
        break 
        ;;
      N|n)
        echo "Packaging operation cancelled, returning to upper menu."
        return
        ;;
      *)
        clear
        echo -e "\n   Invalid selection, please re-enter."
        # If the user input is invalid, continue the loop
        ;;
    esac
  done

  # Add your code here, handle the part after the user input
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
      echo "   Invalid selection, please re-enter."
      ;;
  esac
}
