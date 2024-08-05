function rebuild_rom {
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"

    while true; do
        echo -e "\n   Please put the partition files to be flashed into the Ready-to-flash/images folder in the selected workspace directory"
        echo -e "\n   [1] Fastboot(d) flash package    "  "[2] Odin flash package    "  "[3] Cancel packaging\n"
        echo -n "   Choose your operation: "
        read main_choice

        if [[ "$main_choice" == "1" || "$main_choice" == "2" || "$main_choice" == "3" ]]; then
            break
        else
            clear
            echo -e "\n   Invalid option, please re-enter."
        fi
    done

    if [[ "$main_choice" == "1" ]]; then
        clear

        while true; do
            echo -e "\n   [Q] Return to workspace menu\n"
            echo -n "   Please enter your device model: "
            read device_model
            device_model=$(echo "$device_model" | tr '[:upper:]' '[:lower:]')

            if [[ "$device_model" == "Q" || "$device_model" == "q" ]]; then
                echo "   Cancel packaging, return to workspace menu."
                return
            elif [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
                break
            else
                clear
                echo -e "\n   Impossible model, please re-enter."
            fi
        done

        sed "s/set \"right_device=\w*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat" > "$TOOL_DIR/flash_tool/StartFlash.bat"
        clear
        while true; do
            echo -e "\n   [1] Split compression    "  "[2] Full compression    "  "[Q] Return to workspace menu\n"
            echo -n "   Please enter the compression method: "
            read compression_choice

            if [[ "$compression_choice" == "1" || "$compression_choice" == "2" || "$compression_choice" == "Q" || "$compression_choice" == "q" ]]; then
                break
            else
                clear
                echo -e "\n   Invalid option, please re-enter."
            fi
        done

        clear
        if [[ "$compression_choice" == "1" ]]; then
            while true; do
                echo -e "\n   [Q] Return to workspace menu\n"
                echo -n "   Please enter the volume size: "
                read volume_size

                if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ || "$volume_size" == "Q" || "$volume_size" == "q" ]]; then
                    break
                else
                    clear 
                    echo -e "\n   Invalid volume size, please re-enter."
                fi
            done

            if [[ "$volume_size" == "Q" || "$volume_size" == "q" ]]; then
                echo "   Cancel packaging, return to workspace menu."
                return
            fi

            clear
            start=$(python3 "$TOOL_DIR/get_right_time.py")
            echo -e "\nStarting packaging..."
            find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
            "$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
            echo -e "Fastboot(d) flash package completed"

            end=$(python3 "$TOOL_DIR/get_right_time.py")
            runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
            echo "Time taken: $runtime seconds"

        elif [[ "$compression_choice" == "2" ]]; then
            start=$(python3 "$TOOL_DIR/get_right_time.py")
            clear
            echo -e "\nStarting packaging..."
            find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
            "$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
            echo -e "Fastboot(d) flash package completed"

            end=$(python3 "$TOOL_DIR/get_right_time.py")
            runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
            echo "Time taken: $runtime seconds"

        else
            echo "   Cancel packaging, return to workspace menu."
            return
        fi

        echo -n "Press any key to return to workspace menu..."
        read -n 1

    elif [[ "$main_choice" == "2" ]]; then
        clear
        echo -e "\nStarting packaging Odin flash package..."

        # Define base path
        BASE_PATH="$WORK_DIR/$current_workspace/Ready-to-flash/images"

        # Define file names
        AP_FILES="boot.img dtbo.img init_boot.img misc.bin persist.img recovery.img super.img vbmeta_system.img vendor_boot.img vm-bootsys.img"
        BL_FILES="abl.elf aop_devcfg.mbn aop.mbn apdp.mbn bksecapp.mbn cpucp_dtbs.elf cpucp.elf devcfg.mbn dspso.bin engmode.mbn hypvm.mbn imagefv.elf keymint.mbn NON-HLOS.bin quest.fv qupv3fw.elf sec.elf shrm.elf storsec.mbn tz_hdm.mbn tz_iccc.mbn tz_kg.mbn tz.mbn uefi_sec.mbn uefi.elf vaultkeeper.mbn vbmeta.img xbl_config.elf xbl_s.melf XblRamdump.elf"
        CP_FILES="modem.bin"
        CSC_FILES="cache.img E3Q_*.pit omr.img optics.img prism.img"

        # Package AP files
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/AP_${current_workspace}.tar" $(for file in $AP_FILES; do echo "$BASE_PATH/$file"; done)

        # Package BL files
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/BL_${current_workspace}.tar" $(for file in $BL_FILES; do echo "$BASE_PATH/$file"; done)

        # Package CP files
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CP_${current_workspace}.tar" "$BASE_PATH/$CP_FILES"

        # Package CSC files
        "$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CSC_${current_workspace}.tar" $(for file in $CSC_FILES; do echo "$BASE_PATH/$file"; done)

        echo -e "Odin flash package completed"

        echo -n "Press any key to return to workspace menu..."
        read -n 1

    else
        echo "   Cancel packaging, return to workspace menu."
    fi
}
