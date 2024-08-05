function rebuild_rom {
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"

    while true; do
        echo -e "\n   请把要刷入的分区文件放入在所选工作域目录的 Ready-to-flash/images 文件夹中"
        echo -e "\n   [1] Fastboot(d) 刷入包    "  "[2] Odin 刷入包    "  "[3] 取消打包\n"
        echo -n "   选择你的操作："
        read main_choice

        if [[ "$main_choice" == "1" || "$main_choice" == "2" || "$main_choice" == "3" ]]; then
            break
        else
            clear
            echo -e "\n   无效的选项，请重新输入。"
        fi
    done

    if [[ "$main_choice" == "1" ]]; then
        clear

        while true; do
            echo -e "\n   [Q] 返回工作域菜单\n"
            echo -n "   请输入你的机型："
            read device_model
            device_model=$(echo "$device_model" | tr '[:upper:]' '[:lower:]')

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

        sed "s/set \"right_device=\w*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat" > "$TOOL_DIR/flash_tool/StartFlash.bat"
        clear
        while true; do
            echo -e "\n   [1] 分卷压缩    "  "[2] 完全压缩    "  "[Q] 返回工作域菜单\n"
            echo -n "   请输入压缩方式："
            read compression_choice

            if [[ "$compression_choice" == "1" || "$compression_choice" == "2" || "$compression_choice" == "Q" || "$compression_choice" == "q" ]]; then
                break
            else
                clear
                echo -e "\n   无效的选项，请重新输入。"
            fi
        done

        clear
        if [[ "$compression_choice" == "1" ]]; then
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
            start=$(python3 "$TOOL_DIR/get_right_time.py")
            echo -e "\n开始打包..."
            find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
            "$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
            echo -e "Fastboot(d) 刷入包打包完成"

            end=$(python3 "$TOOL_DIR/get_right_time.py")
            runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
            echo "耗时： $runtime 秒"

        elif [[ "$compression_choice" == "2" ]]; then
            start=$(python3 "$TOOL_DIR/get_right_time.py")
            clear
            echo -e "\n开始打包..."
            find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
            "$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
            echo -e "Fastboot(d) 刷入包打包完成"

            end=$(python3 "$TOOL_DIR/get_right_time.py")
            runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
            echo "耗时： $runtime 秒"

        else
            echo "   取消打包，返回工作域菜单。"
            return
        fi

        echo -n "按任意键返回工作域菜单..."
        read -n 1

    elif [[ "$main_choice" == "2" ]]; then
        clear
        echo -e "\n开始打包 Odin 刷入包..."

        # 定义基础路径
        BASE_PATH="$WORK_DIR/$current_workspace/Ready-to-flash/images"

        # 定义文件名
        AP_FILES="boot.img dtbo.img init_boot.img misc.bin persist.img recovery.img super.img vbmeta_system.img vendor_boot.img vm-bootsys.img"
        BL_FILES="abl.elf aop_devcfg.mbn aop.mbn apdp.mbn bksecapp.mbn cpucp_dtbs.elf cpucp.elf devcfg.mbn dspso.bin engmode.mbn hypvm.mbn imagefv.elf keymint.mbn NON-HLOS.bin quest.fv qupv3fw.elf sec.elf shrm.elf storsec.mbn tz_hdm.mbn tz_iccc.mbn tz_kg.mbn tz.mbn uefi_sec.mbn uefi.elf vaultkeeper.mbn vbmeta.img xbl_config.elf xbl_s.melf XblRamdump.elf"
        CP_FILES="modem.bin"
        CSC_FILES="cache.img E3Q_*.pit omr.img optics.img prism.img"

        # 打包 AP 文件
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/AP_${current_workspace}.tar" $(for file in $AP_FILES; do echo "$BASE_PATH/$file"; done)

        # 打包 BL 文件
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/BL_${current_workspace}.tar" $(for file in $BL_FILES; do echo "$BASE_PATH/$file"; done)

        # 打包 CP 文件
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CP_${current_workspace}.tar" "$BASE_PATH/$CP_FILES"

        # 打包 CSC 文件
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CSC_${current_workspace}.tar" $(for file in $CSC_FILES; do echo "$BASE_PATH/$file"; done)

        echo -e "Odin 刷入包打包完成"

        echo -n "按任意键返回工作域菜单..."
        read -n 1

    else
        echo "   取消打包，返回工作域菜单。"
    fi
}
