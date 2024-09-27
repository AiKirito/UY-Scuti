function create_super_img {
  local partition_type=$1
  local is_sparse=$2
  local img_files=()
  
  # Filter out files of type ext, f2fs, erofs
  for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*.img; do
    file_type=$(recognize_file_type "$file")
    if [[ "$file_type" == "ext" || "$file_type" == "f2fs" || "$file_type" == "erofs" ]]; then
      img_files+=("$file")
    fi
  done

  # Calculate the total bytes of all files in the super folder
  local total_size=0
  for img_file in "${img_files[@]}"; do
    file_type=$(recognize_file_type "$img_file")
    # Calculate the size of the file
    file_size_bytes=$(stat -c%s "$img_file")
    total_size=$(($total_size + $file_size_bytes))
  done
  remainder=$(($total_size % 4096))
  if [ $remainder -ne 0 ]; then
    total_size=$(($total_size + 4096 - $remainder))
  fi

  # Define the size of extra space
  local extra_space=$(( 100 * 1024 * 1024 * 1024 / 100 ))

  # Adjust the value of total_size based on the partition type
  case "$partition_type" in
    "AB")
      total_size=$(((total_size + extra_space) * 2 ))
      ;;
    "ONLYA"|"VAB")
      total_size=$((total_size + extra_space))
      ;;
  esac
  clear

   while true; do
  # Display the total bytes of all files in the SUPER folder
    echo -e "\n   SUPER reference value: $total_size\n" 
    # Try to read the value of the original_super_size file
    if [ -f "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size" ]; then
      original_super_size=$(cat "$WORK_DIR/$current_workspace/Extracted-files/config/original_super_size")
      echo -e "   Original size: $original_super_size\n"
    fi

    echo -e "   [1] 8.50 G    " "[2] 12.00 G    " "[3] 20.00 G\n"
    echo -e "   [4] Custom input    " "[Q] Return to workspace menu\n"
    echo -n "   Please select the size to package SUPER: "
    read device_size_option

    # Set the value of device_size based on the user's choice
    case "$device_size_option" in
      1)
        device_size=9126805504
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please choose another option."
          continue
        fi
        break
        ;;
      2)
        device_size=12884901888
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please choose another option."
          continue
        fi
        break
        ;;
      3)
        device_size=21474836480
        if ((device_size < total_size)); then
          echo "   Less than the reference value, please choose another option."
          continue
        fi
        break
        ;;
      4)
        while true; do
          echo -n "   Please enter the custom size: "
          read device_size

          if [[ "$device_size" =~ ^[0-9]+$ ]]; then
            # If the input value is less than total_size, ask to re-enter
            if ((device_size < total_size)); then
              echo "   The entered value is less than the reference value, please re-enter"
            else
              if ((device_size % 4096 == 0)); then
                break 
              else
                echo "   The entered value is not a multiple of 4096 bytes, please re-enter"
              fi
            fi
          elif [ "${device_size,,}" = "q" ]; then
            return
          else
            echo -e "\n   Invalid input, please re-enter"
          # If the input is invalid, continue the loop
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

  clear # Clear the screen
  echo -e "\n"

  # Other parameters
  metadata_size="65536"
  block_size="4096"
  super_name="super"
  group_name="qti_dynamic_partitions"
  group_name_a="${group_name}_a"
  group_name_b="${group_name}_b"

# Set the value of metadata_slots based on the partition type
case "$partition_type" in
  "AB"|"VAB")
    metadata_slots="3"
    ;;
  *)
    metadata_slots="2"
    ;;
esac


# Initialize the parameter string
params=""

case "$is_sparse" in
  "yes")
    params+="--sparse"
    ;;
esac

case "$partition_type" in
  "VAB")
    overhead_adjusted_size=$((device_size - 40 * 1024 * 1024))
    params+=" --group \"$group_name_a:$overhead_adjusted_size\""
    params+=" --group \"$group_name_b:$overhead_adjusted_size\""
    params+=" --virtual-ab"
    ;;
  "AB")
    overhead_adjusted_size=$(((device_size / 2) - 40 * 1024 * 1024))
    params+=" --group \"$group_name_a:$overhead_adjusted_size\""
    params+=" --group \"$group_name_b:$overhead_adjusted_size\""
    ;;
  *)
    overhead_adjusted_size=$((device_size - 40 * 1024 * 1024))
    params+=" --group \"$group_name:$overhead_adjusted_size\""
    ;;
esac

 # Calculate the size of each partition
  for img_file in "${img_files[@]}"; do
    # Extract the file name from the file path
    base_name=$(basename "$img_file")
    partition_name=${base_name%.*}

    # Calculate the size of the file
    partition_size=$(stat -c%s "$img_file")

    # Set the read-write attribute based on the file system type
    file_type=$(recognize_file_type "$img_file")
    if [[ "$file_type" == "ext" || "$file_type" == "f2fs" ]]; then
      read_write_attr="none"
    else
      read_write_attr="readonly"
    fi

    # Set the partition group name parameter based on the partition type
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
              start=$(python3 "$TOOL_DIR/get_right_time.py")

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

              end=$(python3 "$TOOL_DIR/get_right_time.py")
              runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
              echo "Time taken: $runtime seconds"

  echo -n "Press any key to return to workspace menu..."
  read
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
