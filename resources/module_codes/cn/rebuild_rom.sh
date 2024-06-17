function rebuild_rom {
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash"
    cp -r "$TOOL_DIR/flash_tool/"* "$WORK_DIR/$current_workspace/Ready-to-flash"

    while true; do
        echo -e "\n   请把要刷入的分区文件放入在所选工作域目录的 Ready-to-flash/images 文件夹中"
        echo -e "\n   [1] 开始打包    "  "[2] 取消打包\n"
        echo -n "   选择你的操作："
        read choice

        if [[ "$choice" == "1" || "$choice" == "2" ]]; then
            break
        else
            clear
            echo -e "\n   无效的选项，请重新输入。"
        fi
    done

    if [[ "$choice" == "1" ]]; then
        clear

        while true; do
            echo -e "\n   [Q] 返回工作域菜单\n"
            echo -n "   请输入你的机型："
            read device_model

            if [[ "$device_model" == "Q" || "$device_model" == "q" ]]; then
                echo "   取消打包，返回工作域菜单。"
                return
            elif [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
                break
            else
                clear
                echo -e "\n   不可能的型号，请重新输入。"
            fi
        done

        sed -i "s/set \"right_device=\w*\"/set \"right_device=$device_model\"/g" "$WORK_DIR/$current_workspace/Ready-to-flash/FlashROM.bat"
        clear
        while true; do
            echo -e "\n   [1] 分卷压缩    "  "[2] 完全压缩    "  "[Q] 返回工作域菜单\n"
            echo -n "   请输入压缩方式："
            read choice

            if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "Q" || "$choice" == "q" ]]; then
                break
            else
                clear
                echo -e "\n   无效的选项，请重新输入。"
            fi
        done

        clear
        if [[ "$choice" == "1" ]]; then
            while true; do
                echo -e "\n   [Q] 返回工作域菜单\n"
                echo -n "   请输入分卷大小："
                read volume_size

                if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ || "$volume_size" == "Q" || "$volume_size" == "q" ]]; then
                    break
                else
                    clear 
                    echo -e "\n   无效的分卷大小，请重新输入。"
                fi
            done

            if [[ "$volume_size" == "Q" || "$volume_size" == "q" ]]; then
                echo "   取消打包，返回工作域菜单。"
                return
            fi

            clear
            start=$(date +%s%N)
            echo -e "\n开始打包..."
            rm -rf "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/"*
            "$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/${current_workspace}.zip" "$WORK_DIR/$current_workspace/Ready-to-flash/*" -y -mx2
            echo -e "刷机包已打包到工作域目录的 Ready-to-flash/Packed-rom 目录"
            end=$(date +%s%N)
            runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
            runtime=$(printf "%.3f" "$runtime")
            echo "耗时： $runtime 秒"
        elif [[ "$choice" == "2" ]]; then
            start=$(date +%s%N)
            clear
            echo -e "\n开始打包..."
            rm -rf "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/"*
            "$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/${current_workspace}.zip" "$WORK_DIR/$current_workspace/Ready-to-flash/*" -y -mx2
            echo -e "刷机包已打包到工作域目录的 Ready-to-flash/Packed-rom 目录"
            end=$(date +%s%N)
            runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
            runtime=$(printf "%.3f" "$runtime")
            echo "耗时： $runtime 秒"
        else
            echo "   取消打包，返回工作域菜单。"
            return
        fi

        echo -n "打包完成，按任意键返回..."
        read -n 1
    fi
}
