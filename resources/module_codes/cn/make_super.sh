function create_super_img {
  local partition_type=$1  # 本地变量 partition_type，其值为函数的第一个参数
  local is_sparse=$2  # 本地变量 is_sparse，其值为函数的第二个参数

  # 计算 super 文件夹中所有文件的总字节数
  local total_size=0
  for file in "$WORK_DIR/$current_workspace/Extracted-files/super/"*; do
    file_size_bytes=$(stat -c%s "$file")
    remainder=$(($file_size_bytes % 4096))
    if [ $remainder -ne 0 ]; then
      file_size_bytes=$(($file_size_bytes + 4096 - $remainder))
    fi
    total_size=$(($total_size + $file_size_bytes))
  done

  # 定义额外的空间大小
  local extra_space=$(( 125 * 1024 * 1024 * 1024 / 100 ))

  # 根据分区类型调整 total_size 的值
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
  # 显示 SUPER 文件夹中所有文件的总字节数
    echo -e "\n   SUPER 参考值：$total_size\n" 
    echo -e "   [1] 8.50 G    " "[2] 12.00 G    " "[3] 20.00 G\n"
    echo -e "   [4] 自定义输入    " "[Q] 返回工作域菜单\n"
    echo -n "   请选择打包 SUPER 的大小："
    read device_size_option

    # 根据用户的选择，设置 device_size 的值
    case "$device_size_option" in
      1)
        device_size=9126805504
        if ((device_size < total_size)); then
          echo "   小于参考值，请执行其它选项。"
          continue
        fi
        break
        ;;
      2)
        device_size=12884901888
        if ((device_size < total_size)); then
          echo "   小于参考值，请执行其它选项。"
          continue
        fi
        break
        ;;
      3)
        device_size=21474836480
        if ((device_size < total_size)); then
          echo "   小于参考值，请执行其它选项。"
          continue
        fi
        break
        ;;
      4)
        while true; do
          echo -n "   请输入自定义大小："
          read device_size

          if [[ "$device_size" =~ ^[0-9]+$ ]]; then
            # 如果输入值小于 total_size，要求重新输入
            if ((device_size < total_size)); then
              echo "   输入的数值小于参考值，请重新输入："
            else
              if ((device_size % 4096 == 0)); then
                break 
              else
                echo "   输入的值不是 4096 字节数的倍数，请重新输入"
              fi
            fi
          elif [ "${device_size,,}" = "q" ]; then
            return
          else
            echo -e "\n   无效的输入，请重新输入"
          # 如果输入无效，继续循环
          fi
        done
        break
        ;;
      Q|q)
        echo "   已取消打包操作，返回工作域菜单。"
        return
        ;;
      *)
        clear
        echo -e "\n   无效的选择，请重新输入。"
        ;;
    esac
  done

  clear #清除屏幕
  echo -e "\n"

  # 其他参数
  metadata_size="65536"
  block_size="4096"
  super_name="super"
  group_name="qti_dynamic_partitions"
  group_name_a="${group_name}_a"
  group_name_b="${group_name}_b"

# 根据分区类型设置 metadata_slots 的值
case "$partition_type" in
  "AB"|"VAB")
    metadata_slots="3"
    ;;
  *)
    metadata_slots="2"
    ;;
esac


# 初始化参数字符串
params=""

case "$is_sparse" in
  "yes")
    params+="--sparse"
    ;;
esac

case "$partition_type" in
  "VAB")
    params+=" --group \"$group_name_a:$device_size\""
    params+=" --group \"$group_name_b:$device_size\""
    params+=" --virtual-ab"
    ;;
  "AB")
    device_size_ab=$((device_size / 2))
    params+=" --group \"$group_name_a:$device_size_ab\""
    params+=" --group \"$group_name_b:$device_size_ab\""
    ;;
  *)
    params+=" --group \"$group_name:$device_size\""
    ;;
esac


  # 获取 super 目录下的所有镜像文件
  img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)

  # 创建 Packed 目录（如果不存在）
  mkdir -p "$WORK_DIR/$current_workspace/Packed"

  # 循环处理每个镜像文件
  for img_file in "${img_files[@]}"; do
    # 从文件路径中提取文件名
    base_name=$(basename "$img_file")
    partition_name=${base_name%.*}

    # 使用 stat 命令获取镜像文件的大小
    partition_size=$(stat -c%s "$img_file")

    # 根据分区类型设置分区组名参数
    case "$partition_type" in
      "VAB")
          params+=" --partition \"${partition_name}_a:readonly:$partition_size:$group_name_a\""
          params+=" --image \"${partition_name}_a=$img_file\""
          params+=" --partition \"${partition_name}_b:readonly:0:$group_name_b\""
        ;;
      "AB")
          params+=" --partition \"${partition_name}_a:readonly:$partition_size:$group_name_a\""
          params+=" --image \"${partition_name}_a=$img_file\""
          params+=" --partition \"${partition_name}_b:readonly:$partition_size:$group_name_b\""
          params+=" --image \"${partition_name}_b=$img_file\""
        ;;
      *)
        params+=" --partition \"$partition_name:readonly:$partition_size:$group_name\""
        params+=" --image \"$partition_name=$img_file\""
        ;;
    esac
  done
              echo -e "正在打包 SUPER 分区，等待中...\n..................\n..................\n.................."
              start=$(date +%s%N)

    eval "$TOOL_DIR/lpmake  \
      --device-size \"$device_size\" \
      --metadata-size \"$metadata_size\" \
      --metadata-slots \"$metadata_slots\" \
      --block-size \"$block_size\" \
      --super-name \"$super_name\" \
      --force-full-image \
      $params \
      --output \"$WORK_DIR/$current_workspace/Packed/super.img\"" > /dev/null 2>&1

  echo "SUPER 分区已打包"
              end=$(date +%s%N)
              runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
              runtime=$(printf "%.3f" "$runtime")
              echo "耗时： $runtime 秒"
  echo -n "按任意键返回工作域菜单..."
  read
}

function package_super_image {
  echo -e "\n"
  mkdir -p "$WORK_DIR/$current_workspace/Extracted-files/super"
  if [ ! -d "$WORK_DIR/$current_workspace/Extracted-files/super" ]; then
    echo "   SUPER 目录不存在。"
    read -n 1 -s -r -p "   按任意键返回工作域菜单..."
    return
  fi

  # 检查 SUPER 目录中是否有镜像文件
  img_files=("$WORK_DIR/$current_workspace/Extracted-files/super/"*.img)
  real_img_files=()
  for file in "${img_files[@]}"; do
    if [ -e "$file" ]; then
      real_img_files+=("$file")
    fi
  done
  if [ ${#real_img_files[@]} -lt 2 ]; then
    echo "   SUPER 目录需要至少应包含两个镜像文件。"
    read -n 1 -s -r -p "   按任意键返回工作域菜单..."
    return
  fi

  # 询问用户是否要打包
  while true; do
    # 列出目标目录下的所有子文件，每个文件前面都有一个编号
    echo -e "   SUPER 待打包子分区：\n"
    for i in "${!img_files[@]}"; do
      file_name=$(basename "${img_files[$i]}")
      printf "   \e[95m[%02d] %s\e[0m\n\n" $((i+1)) "$file_name"
    done

    echo -e "\n   [Y] 打包 SUPER    "  "[N] 返回工作域菜单\n"
    echo -n "   选择你想要执行的功能："
    read is_pack
    clear

    case "$is_pack" in
      Y|y)
        while true; do
          echo -e "\n   [1] OnlyA 动态分区    "  "[2] AB 动态分区    "  "[3] VAB 动态分区\n"
          echo -e "   [Q] 返回工作域菜单\n"
          echo -n "   请选择你的分区类型："
          read partition_type

          if [ "${partition_type,,}" = "q" ]; then  # 将用户输入转换为小写
            echo "   已取消选择分区类型，返回工作域菜单。"
            return
          fi
          clear

          case "$partition_type" in
            1|2|3)
              while true; do
                echo -e "\n   [1] 稀疏    "  "[2] 非稀疏\n"
                echo -e "   [Q] 返回工作域菜单\n"
                echo -n "   请选择打包方式："
                read is_sparse

                if [ "${is_sparse,,}" = "q" ]; then
                  echo "   已取消选择，返回工作域菜单。"
                  return
                fi

                case "$is_sparse" in
                  1|2)
                    break 
                    ;;
                  *)
                    clear
                    echo -e "\n   无效的选择，请重新输入。"
                    ;;
                esac
              done
              break 
              ;;
            *)
              clear
              echo -e "\n   无效的选择，请重新输入。"
              # 如果用户输入无效，继续循环
              ;;
          esac
        done
        break 
        ;;
      N|n)
        echo "已取消打包操作，返回上级菜单。"
        return
        ;;
      *)
        clear
        echo -e "\n   无效的选择，请重新输入。"
        # 如果用户输入无效，继续循环
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
      echo "   无效的选择，请重新输入。"
      ;;
  esac
}
