#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/bin/codes/features.sh"

add_path() {
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
onepath="$1"

rom_brands=("HyperOS" "OneUI" "Return to Work Menu" "Exit Program")
brand_selected=false
while true; do
    echo "=============================="
    echo "  Select the ROM to modify:"
    echo "=============================="
    PS3="Enter your choice: "
    select brand in "${rom_brands[@]}"; do
        case $brand in
            "HyperOS")
                echo "Selected HyperOS"
                options_order=("Remove XiaoAi Translation" "Remove XiaoAi Voice Components" "Remove XiaoAi Call" "Remove Interconnect Service ROOT Verification" "Remove Browser" "Remove Music" "Remove Video" "Remove Wallet" "Remove Ads and Analytics Components" "Remove Joyose Cloud Control" "Remove Built-in Input Method" "Remove Portal" "Remove Smart Assistant" "Remove Search Function" "Remove Floating Ball" "Remove App Store" "Remove Service and Feedback" "Remove System Update" "Remove Family Guardian" "Remove Download Manager" "Remove Pre-installed Apps" "Remove All" "HyperOS Replace" "HyperOS Add-product Partition" "Disable Unsigned Verification" "Disable Device and Hotspot Name Detection" "Invoke Native Installer" "Prevent Theme Reversion" "Add New Features" "Critical Deodex" "Deodex" "Remove Avb2.0 Verification" "Return to Work Menu" "Exit Program")
                declare -A options
                options=(
                    ["Remove XiaoAi Translation"]="AiAsstVision*"
                    ["Remove XiaoAi Voice Components"]="VoiceTrigger VoiceAssistAndroidT"
                    ["Remove XiaoAi Call"]="MIUIAiasstService"
                    ["Remove Interconnect Service ROOT Verification"]="MiTrustService"
                    ["Remove Browser"]="MIUIBrowser MiBrowserGlobal"
                    ["Remove Music"]="MIUIMusic*"
                    ["Remove Video"]="MIUIVideo*"
                    ["Remove Wallet"]="MIpay"
                    ["Remove Ads and Analytics Components"]="HybridAccessory HybridPlatform MSA* AnalyticsCore"
                    ["Remove Joyose Cloud Control"]="Joyose"
                    ["Remove Built-in Input Method"]="SogouInput com.iflytek.inputmethod.miui BaiduIME"
                    ["Remove Portal"]="MIUIContentExtension*"
                    ["Remove Smart Assistant"]="MIUIPersonalAssistant*"
                    ["Remove Search Function"]="MIUIQuickSearchBox"
                    ["Remove Floating Ball"]="MIUITouchAssistant*"
                    ["Remove App Store"]="MIUISuperMarket*"
                    ["Remove Service and Feedback"]="MIService"
                    ["Remove System Update"]="Updater"
                    ["Remove Family Guardian"]="MIUIgreenguard"
                    ["Remove Download Manager"]="DownloadProviderUi"
                    ["Remove Pre-installed Apps"]="MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim MIUIVipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUIGameCenter* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* system NewHome* MiRadio MiGameCenterSDKService"
                )
                brand_selected=true
                break
                ;;
            "OneUI")
                echo "Selected OneUI"
                options_order=("Remove Samsung Browser Components" "Remove Boot Verification" "Remove Rec Restore to Official" "Remove Home Minus One Screen" "Remove Dynamic Emoji Components" "Remove Bixby Voice Components" "Remove Microsoft Input Method" "Remove Google Bundled Apps" "Remove Wearable Device Manager" "Remove System Update" "Remove Theme Store" "Remove Knox Related Apps" "Remove Uncommon Apps" "Remove All" "ONEUI Replace" "ONEUI Add-system Partition" "ONEUI Feature Add" "Disable Unsigned Verification" "Critical Deodex" "Deodex" "Remove Avb2.0 Verification" "Decode csc" "Encode csc" "Return to Work Menu" "Exit Program")
                declare -A options
                options=(
                    ["Remove Samsung Browser Components"]="SBrowser SBrowserIntelligenceService"
                    ["Remove Boot Verification"]="ActivationDevice_V2"
                    ["Remove Rec Restore to Official"]="recovery-from-boot.p"
                    ["Remove Home Minus One Screen"]="BixbyHomeCN_Disable"
                    ["Remove Dynamic Emoji Components"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
                    ["Remove Bixby Voice Components"]="BixbyWakeup Bixby"
                    ["Remove Microsoft Input Method"]="SwiftkeyIme SwiftkeySetting"
                    ["Remove Google Bundled Apps"]="Maps Gmail2 YouTube DuoStub Messages Chrome64* "
                    ["Remove System Update"]="FotaAgent SOAgent7"
                    ["Remove Theme Store"]="ThemeStore"
                    ["Remove Knox Related Apps"]="Knox* SamsungBilling SamsungPass"
                    ["Remove Uncommon Apps"]="KidsHome_Installer"
                )
                brand_selected=true
                break
                ;;
            "Return to Work Menu")
                return 0
                ;;
            "Exit Program")
                clear
                exit 0
                ;;
            *)
                echo "Invalid choice: $REPLY"
                ;;
        esac
    done
    if [ "$brand_selected" = true ]; then
        break
    fi
done

while true; do
    echo "=============================="
    echo "  Select the operation to perform:"
    echo "=============================="
    PS3="Enter your choice (multiple choices separated by commas, e.g., 1,3,5): "
    select opt in "${options_order[@]}"; do
        IFS=',' read -ra selections <<< "$REPLY"
        decode_selected=false
        encode_selected=false
        deodex_selected=false
        services_jar_dex_selected=false
        oneui_feature_selected=false
        for selection in "${selections[@]}"; do
            if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
                echo "Invalid choice: $selection"
                continue
            fi
            index=$((selection-1))
            if [[ $index -lt 0 || $index -ge ${#options_order[@]} ]]; then
                echo "Invalid choice: $selection"
                continue
            fi
            opt=${options_order[$index]}
            if [[ ${#selections[@]} -gt 1 && "$opt" == "Exit" ]]; then
                echo "Multiple selection prohibits exit."
                continue
            fi
            if [ "$opt" == "Decode csc" ]; then
                decode_selected=true
            fi
            if [ "$opt" == "Encode csc" ]; then
                encode_selected=true
            fi
            if [ "$opt" == "Deodex" ]; then
                deodex_selected=true
            fi
            if [ "$opt" == "Critical Deodex" ]; then
                services_jar_dex_selected=true
            fi
            if [ "$opt" == "ONEUI Feature Add" ]; then
                oneui_feature_selected=true
            fi
        done
        if [ "$decode_selected" = true ] && [ "$encode_selected" = true ]; then
            echo "Invalid choice: Cannot select both Decode and Encode"
            continue
        fi
        if [ "$deodex_selected" = true ] && [ "$services_jar_dex_selected" = true ]; then
            echo "Invalid choice: Cannot select both Deodex and Critical Deodex"
            continue
        fi
        if [ "$oneui_feature_selected" = true ] && ([ "$decode_selected" = true ] || [ "$encode_selected" = true ]); then
            echo "Invalid choice: Cannot select both ONEUI Feature Add and Decode/Encode csc"
            continue
        fi
        deleted=false
        for selection in "${selections[@]}"; do
            opt=${options_order[$((selection-1))]}
            case $opt in
                "Remove Avb2.0 Verification")
                    echo "Selected Remove Avb2.0 Verification"
                    remove_vbmeta_verification
                    remove_extra_vbmeta_verification
                    ;;
                "Disable Device and Hotspot Name Detection")
                    echo "Selected Disable Device and Hotspot Name Detection"
                    remove_device_and_network_verification
                    ;;
                "HyperOS Replace")
                    echo "Selected HyperOS Replace"
                    replace_files_xiaomi
                    ;;
                "HyperOS Add-product Partition")
                    echo "Selected HyperOS Add-product Partition"
                    copy_dir_xiaomi
                    ;;
                "ONEUI Replace")
                    echo "Selected ONEUI Replace"
                    replace_files_samsung
                    ;;
                "ONEUI Add-system Partition")
                    echo "Selected ONEUI Add-system Partition"
                    copy_dir_samsung
                    ;;
                "ONEUI Feature Add")
                    echo "Selected ONEUI Feature Add"
                    csc_feature_add
                    ;;
                "Decode csc")
                    echo "Selected Decode csc"
                    decode_csc
                    ;;
                "Encode csc")
                    echo "Selected Encode csc"
                    encode_csc
                    ;;
                "Disable Unsigned Verification")
                    echo "Selected Disable Unsigned Verification"
                    remove_unsigned_app_verification
                    ;;
                "Invoke Native Installer")
                    echo "Selected Invoke Native Installer"
                    invoke_native_installer
                    ;;
                "Prevent Theme Reversion")
                    echo "Selected Prevent Theme Reversion"
                    prevent_theme_reversion
                    ;;
                "Add New Features")
                    echo "Selected Add New Features"
                    update_build_props
                    ;;
                "Deodex")
                    echo "Selected Deodex"
                    deodex
                    ;;
                "Critical Deodex")
                    echo "Selected Critical Deodex"
                    deodex_key_files
                    ;;
                "Remove All")
                    if [[ ${#selections[@]} -gt 1 ]]; then
                        echo "Remove All is disabled in multiple selection"
                    else
                        echo "Selected Remove All"
                        remove_all
                    fi
                    ;;
                "Return to Work Menu")
                    return 0
                    ;;
                "Exit Program")
                    clear
                    exit 0
                    ;;
                *)
                    echo "Selected $opt"
                    remove_files "${options[$opt]}"
                    ;;
            esac
            echo ""  # Add a blank line
        done
        break
    done
done
}
