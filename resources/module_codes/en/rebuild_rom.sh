function rebuild_rom {
	keep_clean
	mkdir -p "$WORK_DIR/$current_workspace/Ready-to-flash/images"
	while true; do
		echo -e "\n   Please place the partition files to be flashed into the Ready-to-flash/images folder in the selected workspace directory"
		echo -e "\n   [1] Fastboot(d) Rom    " "[2] Odin Rom    " "[Q] Cancel packaging\n"
		# Check if there are img files
		if compgen -G "$WORK_DIR/$current_workspace/Repacked/*.img" >/dev/null; then
			echo -e "   [M] Quick Move\n"
		fi
		echo -n "   Choose your action:"
		read main_choice
		main_choice=$(echo "$main_choice" | tr '[:upper:]' '[:lower:]')
		if [[ "$main_choice" == "1" || "$main_choice" == "2" || "$main_choice" == "q" || "$main_choice" == "m" ]]; then
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
			echo -n "   Please enter your device model:"
			read device_model
			device_model=$(echo "$device_model" | tr '[:upper:]' '[:lower:]')
			if [[ "$device_model" == "q" ]]; then
				echo "   Cancel packaging, returning to workspace menu."
				return
			elif [[ "$device_model" =~ ^[0-9a-zA-Z]+$ ]]; then
				break
			else
				clear
				echo -e "\n   Invalid model, please re-enter."
			fi
		done
		sed "s/set \"right_device=\w*\"/set \"right_device=$device_model\"/g" "$TOOL_DIR/flash_tool/FlashROM.bat" >"$TOOL_DIR/flash_tool/StartFlash.bat"
		clear
		while true; do
			echo -e "\n   [1] Split Compression    " "[2] Full Compression    " "[Q] Return to workspace menu\n"
			echo -n "   Please enter the compression method:"
			read compression_choice
			if [[ "$compression_choice" == "1" || "$compression_choice" == "2" || "$compression_choice" == "q" ]]; then
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
				echo -n "   Please enter the split size:"
				read volume_size
				if [[ "$volume_size" =~ ^[0-9]+[mgkMGK]$ || "$volume_size" == "q" ]]; then
					break
				else
					clear
					echo -e "\n   Invalid split size, please re-enter."
				fi
			done
			if [[ "$volume_size" == "q" ]]; then
				echo "   Cancel packaging, returning to workspace menu."
				return
			fi
			clear
			start=$(python3 "$TOOL_DIR/get_right_time.py")
			echo -e "\nStarting packaging..."
			find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
			"$TOOL_DIR/7z" a -tzip -v${volume_size} "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
			echo -e "Fastboot(d) Rom packaging completed"
			end=$(python3 "$TOOL_DIR/get_right_time.py")
			runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
			echo "Time taken: $runtime seconds"
		elif [[ "$compression_choice" == "2" ]]; then
			start=$(python3 "$TOOL_DIR/get_right_time.py")
			clear
			echo -e "\nStarting packaging..."
			find "$WORK_DIR/$current_workspace/Ready-to-flash" -mindepth 1 -maxdepth 1 -not -name 'images' -exec rm -rf {} +
			"$TOOL_DIR/7z" a -tzip "$WORK_DIR/$current_workspace/Ready-to-flash/${current_workspace}.zip" "$TOOL_DIR/flash_tool/bin" "$TOOL_DIR/flash_tool/StartFlash.bat" "$WORK_DIR/$current_workspace/Ready-to-flash/images" -y -mx1
			echo -e "Fastboot(d) Rom packaging completed"
			end=$(python3 "$TOOL_DIR/get_right_time.py")
			runtime=$(echo "scale=3; if ($end - $start < 1) print 0; $end - $start" | bc)
			echo "Time taken: $runtime seconds"
		else
			echo "   Cancel packaging, returning to workspace menu."
			return
		fi
		echo -n "Press any key to return to workspace menu..."
		read -n 1
	elif [[ "$main_choice" == "2" ]]; then
		clear
		# Define base path
		BASE_PATH="$WORK_DIR/$current_workspace/Ready-to-flash/images"
		# Initialize empty arrays
		AP_FILES=()
		CP_FILES=()
		BL_FILES=()
		CSC_FILES=()
		# Check if modem.bin file exists
		if [[ -f "$BASE_PATH/modem.bin" ]]; then
			while true; do
				echo -e "\n   Does your device have a separate baseband partition?"
				echo -e "\n   [1] Yes    " "[2] No\n"
				echo -n "   Choose your action:"
				read baseband_choice
				if [[ "$baseband_choice" == "1" || "$baseband_choice" == "2" ]]; then
					break
				else
					clear
					echo -e "\n   Invalid option, please re-enter."
				fi
			done
		else
			baseband_choice="2"
		fi
		clear
		# Check if there is a .pit file
		if compgen -G "$BASE_PATH/*.pit" >/dev/null; then
			while true; do
				echo -e "\n   Does your device need to retain data?"
				echo -e "\n   [1] Yes    " "[2] No\n"
				echo -n "   Choose your action:"
				read retain_data_choice
				if [[ "$retain_data_choice" == "1" || "$retain_data_choice" == "2" ]]; then
					break
				else
					clear
					echo -e "\n   Invalid option, please re-enter."
				fi
			done
		else
			retain_data_choice="2"
		fi
		clear
		echo -e "\nStarting packaging Odin Rom..."
		# Check and add files to AP_FILES array
		while IFS= read -r -d '' file; do
			AP_FILES+=("$(basename "$file")")
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "boot.img" -o -name "dtbo.img" -o -name "init_boot.img" -o -name "misc.bin" -o -name "persist.img" -o -name "recovery.img" -o -name "super.img" -o -name "vbmeta_system.img" -o -name "vendor_boot.img" -o -name "vm-bootsys.img" \) -print0)
		# Check and add modem.bin file to the appropriate array
		while IFS= read -r -d '' file; do
			if [[ "$baseband_choice" == "1" ]]; then
				CP_FILES+=("$(basename "$file")")
			else
				AP_FILES+=("$(basename "$file")")
			fi
		done < <(find "$BASE_PATH" -maxdepth 1 -name "modem.bin" -print0)
		# Check and add files to BL_FILES array
		while IFS= read -r -d '' file; do
			BL_FILES+=("$(basename "$file")")
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "vbmeta.img" -o -regex ".*\.\(elf\|mbn\|bin\|fv\|melf\)" \) ! -name "modem.bin" ! -name "misc.bin" -print0)
		# Check and add files to CSC_FILES array
		while IFS= read -r -d '' file; do
			if [[ "$retain_data_choice" == "1" ]]; then
				# If choosing to retain data, only add cache.img, optics.img, and prism.img
				if [[ "$(basename "$file")" == "cache.img" || "$(basename "$file")" == "optics.img" || "$(basename "$file")" == "prism.img" ]]; then
					CSC_FILES+=("$(basename "$file")")
				fi
			else
				# Otherwise, add all related files
				CSC_FILES+=("$(basename "$file")")
			fi
		done < <(find "$BASE_PATH" -maxdepth 1 \( -name "cache.img" -o -name "*.pit" -o -name "omr.img" -o -name "optics.img" -o -name "prism.img" \) -print0)
		# Package AP files
		if [[ ${#AP_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/AP-${current_workspace}.tar" "${AP_FILES[@]/#/$BASE_PATH/}"
		fi
		# Package BL files
		if [[ ${#BL_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/BL-${current_workspace}.tar" "${BL_FILES[@]/#/$BASE_PATH/}"
		fi
		# Package CP files
		if [[ ${#CP_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CP-${current_workspace}.tar" "${CP_FILES[@]/#/$BASE_PATH/}"
		fi
		# Package CSC files
		if [[ ${#CSC_FILES[@]} -gt 0 ]]; then
			"$TOOL_DIR/7z" a -ttar -mx1 "$WORK_DIR/$current_workspace/Ready-to-flash/CSC-${current_workspace}.tar" "${CSC_FILES[@]/#/$BASE_PATH/}"
		fi
		echo -e "Odin Rom packaging completed"
		echo -n "Press any key to return to workspace menu..."
		read -n 1
	elif [[ "$main_choice" == "m" ]]; then
		clear
		find "$WORK_DIR/$current_workspace/Repacked" -name '*.img' -exec mv {} "$WORK_DIR/$current_workspace/Ready-to-flash/images" \;
		rebuild_rom
		return
	else
		echo "   Cancel packaging, returning to workspace menu."
	fi
}
