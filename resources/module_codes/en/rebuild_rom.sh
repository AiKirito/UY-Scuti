function rebuild_rom {
    mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash"
    cp -r "$TOOL_DIR/flash_tool/"* "$WORK_DIR/$current_workspace/Ready-to-flash"

    while true; do
        echo -e "\n   Please put the partition file to be flashed into the Ready-to-flash/images folder in the selected workspace directory"
        echo -e "\n   [1] Start packaging    "  "[2] Cancel packaging\n"
        echo -n "   Choose your operation: "
        read choice

        if [[ "$choice" == "1" || "$choice" == "2" ]]; then
            break
        else
            clear
            echo -e "\n   Invalid option, please re-enter."
        fi
    done

    if [[ "$choice" == "1" ]]; then
        clear

        while true; do
            echo -e "\n   [Q] Return to workspace menu\n"
            echo -n "   Please enter your model: "
            read device_model

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

        sed -i "s/set \"right_device=\w*\"/set \"right_device=$device_model\"/g" "$WORK_DIR/$current_workspace/Ready-to-flash/FlashROM.bat"
        clear
        while true; do
            echo -e "\n   [1] Volume compression    "  "[2] Full compression    "  "[Q] Return to workspace menu\n"
            echo -n "   Please enter the compression method: "
            read choice

            if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "Q" || "$choice" == "q" ]]; then
                break
            else
                clear
                echo -e "\n   Invalid option, please re-enter."
            fi
        done

        clear
        if [[ "$choice" == "1" ]]; then
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
            start=$(date +%s%N)
            echo -e "\nStart packaging..."
            rm -rf "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/"*
            "$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/${current_workspace}.zip" "$WORK_DIR/$current_workspace/Ready-to-flash/*" -y -mx2 
            echo -e "The ROM package has been packaged into the Ready-to-flash/Packed-rom directory of the workspace directory"
            end=$(date +%s%N)
            runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
            runtime=$(printf "%.3f" "$runtime")
            echo "Time consumed: $runtime seconds"
        elif [[ "$choice" == "2" ]]; then
            start=$(date +%s%N)
            clear
            echo -e "\nStart packaging..."
            rm -rf "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/"*
            "$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/Packed-rom/${current_workspace}.zip" "$WORK_DIR/$current_workspace/Ready-to-flash/*" -y -mx2
            echo -e "The ROM package has been packaged into the Ready-to-flash/Packed-rom directory of the workspace directory"
            end=$(date +%s%N)
            runtime=$(awk "BEGIN {print ($end - $start) / 1000000000}")
            runtime=$(printf "%.3f" "$runtime")
            echo "Time consumed: $runtime seconds"
        else
            echo "   Cancel packaging, return to workspace menu."
            return
        fi

        echo -n "Packaging completed, press any key to return..."
        read -n 1
    fi
}
