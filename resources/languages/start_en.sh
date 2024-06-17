#!/bin/bash

# Define the packages to check
packages=("lz4" "python3" "dtc")
missing_packages=()

# Check if each package is installed
for package in "${packages[@]}"; do
  if ! command -v $package &> /dev/null
  then
      missing_packages+=($package)
  fi
done

# If there are uninstalled packages, print them out together
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo "The following packages are missing: ${missing_packages[@]}. Please install them first and then run this script."
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Import various modules
source "$(dirname "$0")/resources/module_codes/recognize_file_type.sh"
source "$(dirname "$0")/resources/module_codes/switch_languages.sh"
source "$(dirname "$0")/resources/module_codes/en/extract.sh"
source "$(dirname "$0")/resources/module_codes/en/make_super.sh"
source "$(dirname "$0")/resources/module_codes/en/make_img.sh"
source "$(dirname "$0")/resources/module_codes/en/rebuild_rom.sh"
source "$(dirname "$0")/resources/my_tools/nice_rom/NiceRom.sh"

# Define the paths of the tools and working directories
TOOL_DIR="$(dirname "$0")/resources/my_tools"
WORK_DIR="$(dirname "$0")/my_workspaces"

# Define the current workspace
current_workspace=""

function show_main_menu {
  clear
  echo -e "\n\n $(tput setaf 5)"
  echo -e "   ══════════════════════════\n"
  echo -e "            UY SCT         "
  echo -e "\n   ══════════════════════════\n $(tput sgr0)"
  echo -e "   [01] Select Workspace\n"
  echo -e "   [02] Create Workspace\n"
  echo -e "   [03] Delete Workspace\n"
  echo -e "   [04] Change Language Settings\n"
  echo -e "   [05] Exit Program\n"
  echo -n "   Please select an operation: "
}



# Function to show the workspace menu
function show_workspace_menu {
  echo -e "\n\n $(tput setaf 1)"
  echo -e "   ══════════════════════════\n"
  echo -e "           Workspace Menu        "
  echo -e "\n   ══════════════════════════\n $(tput sgr0)"
  echo -e "   [01] Extract Partition File\n"
  echo -e "   [02] Package Partition File\n"
  echo -e "   [03] Package SUPER Partition\n"
  echo -e "   [04] One-Click Modification\n"
  echo -e "   [05] Build Flash Package\n"
  echo -e "   [06] Return to Main Menu\n"
  echo -e "   [07] Exit Program\n" 
  echo -n "   Please select an operation: "
}

function create_workspace {
  while true; do
    echo ""
    echo -n "   Please enter the name of the new workspace: "
    read workspace
    if [ -z "$workspace" ]; then
      clear
      echo -e "\n   You did not make a valid input."
      continue
    fi
    if echo "$workspace" | grep -Pvq "^[a-zA-Z0-9_\-\.\,\;\[\]\{\}\(\)\@\#\$\%\^\&\*\+\=\!\<\>\?\/\~\`\|\p{Han}\s]*$"; then
      clear
      echo -e "\n   Disallowed workspace name."
    else
      if [ -d "$WORK_DIR/$workspace" ]; then
        echo "   Workspace $workspace already exists, no need to create."
        echo -n "   Press any key to return to the main menu..."
        read -n 1
        return
      else
        mkdir -p "$WORK_DIR/$workspace"
        echo "   Workspace $workspace has been created."
        echo -n "   Press any key to return to the main menu..."
        read -n 1
        return
      fi
    fi
  done
}


function select_workspace {
  local workspaces=("$WORK_DIR"/*)
  if [ -z "$(ls -A "$WORK_DIR")" ]; then
    echo -e "\n"
    echo -n "   No available workspace, press any key to return."
    read -n 1
    return
  fi

  while true; do
    echo -e "\n"
    echo -e "   The following are all available workspaces:\n"
    local i=1
    for workspace in "${workspaces[@]}"; do
      if [ -d "$workspace" ]; then
        printf "   [%02d] %s\n\n" "$i" "$(basename "$workspace")"
        i=$((i+1))
      fi
    done
    echo -e "\n   [Q] Return to Main Menu\n"
    echo -n "   Please enter the number of the workspace to select: "
    read choice
    if [[ "$choice" =~ ^[Qq]$ ]]; then
      return
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
      workspace=$(ls -d "$WORK_DIR"/* | sed -n "${choice}p")
      if [ -d "$workspace" ]; then
        current_workspace="$(basename "$workspace")"
        echo "   You have selected workspace '$current_workspace'."
        workspace_menu
        break
      else
        clear
        echo -e "\n   The workspace number does not exist, please re-enter."
      fi
    else
      clear
      echo -e "\n   Invalid input, please re-enter."
    fi
  done
}

function delete_workspace {
  if [ -z "$(ls -A "$WORK_DIR")" ]; then
    echo -e "\n"
    echo -n "   No workspace to delete, press any key to return."
    read -n 1
    return
  fi

  while true; do
    echo -e "\n"
    echo -e "   The following are all workspaces:\n"
    local i=1
    for workspace in "$WORK_DIR"/*; do
      if [ -d "$workspace" ]; then
        printf "   [%02d] %s\n\n" "$i" "$(basename "$workspace")"
        i=$((i+1))
      fi
    done
    echo -e "\n   [Q] Return to Main Menu\n"
    echo -n "   Please enter the number of the workspace to delete: "
    read choice
    if [[ "$choice" =~ ^[Qq]$ ]]; then
      return
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
      workspace=$(ls -d "$WORK_DIR"/* | sed -n "${choice}p")
      if [ -d "$workspace" ]; then
        rm -rf "$workspace"
        echo "   Workspace $(basename "$workspace") has been deleted."
        echo -n "   Press any key to return to the main menu..."
        read -n 1
        return
      else
        clear
        echo -e "\n   The workspace number does not exist, please re-enter."
      fi
    else
      clear
      echo -e "\n   Invalid input, please re-enter."
    fi
  done
}

# Add new functions in the workspace menu function
function workspace_menu {
  while true; do
    clear
    show_workspace_menu
    read choice
    case "$choice" in
      1)
        clear
        extract_img
        ;;
      2)
        clear
        package_regular_image
        ;;
      3)
        clear
        preprocess_files
        package_super_image
        ;;
      4)
        clear
        one_click_modify
        ;;
      5)
        clear
        rebuild_rom
        ;;
      6)
        clear
        return
        ;;
      7)
	clear
        exit 0
        ;;
      *)
        clear
        echo "   Invalid selection, please re-enter."
        ;;
    esac
  done
}

function one_click_modify {
  pushd . > /dev/null
  local workspace_path=$(realpath "$WORK_DIR/$current_workspace")
  echo -e "\n"
  add_path "$workspace_path"
  popd
}

# Main loop
while true; do
  clear
  show_main_menu
  read choice
  case "$choice" in
    1)
      clear
      select_workspace
      ;;
    2)
      clear
      create_workspace
      ;;
    3)
      clear
      delete_workspace
      ;;
    4)
      clear
      echo -e "\n   [1] English\n"
      echo -e "   [2] Chinese\n"
      echo -n "   Please select new language settings: "
      read new_language
      if [ "$new_language" = "1" ]; then
        replace_script "start_en.sh"
        exec "$(dirname "$0")/start.sh"
      elif [ "$new_language" = "2" ]; then
        replace_script "start_cn.sh"
        exec "$(dirname "$0")/start.sh"
      else
        echo "   Invalid selection, please re-enter."
      fi
      ;;
    5)
      clear
      exit 0
      ;;
    *)
      echo "   Invalid selection, please re-enter."
      ;;
  esac
done
