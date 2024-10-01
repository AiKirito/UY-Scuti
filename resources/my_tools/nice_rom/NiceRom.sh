#!/bin/bash
source "$(dirname "$0")/resources/my_tools/nice_rom/bin/codes/features.sh"

add_path() {

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

onepath="$1"

# 定义一个数组来存储所有的 ROM
rom_brands=("HyperOS" "OneUI" "返回工作域菜单" "退出程序")

brand_selected=false
while true; do
    echo "=============================="
    echo "  请选择要修改的 ROM："
    echo "=============================="
    PS3="请输入你的选择："
    select brand in "${rom_brands[@]}"; do
        case $brand in
            "HyperOS")
                echo "已选择 HyperOS"
                options_order=("删除小爱翻译" "删除小爱语音组件" "删除小爱通话" "删除互联互通服务 ROOT 验证" "删除浏览器" "删除音乐" "删除视频" "删除钱包" "删除广告与分析组件" "删除 Joyose 云控" "删除自带输入法" "删除传送门" "删除智能助理" "删除搜索功能" "删除悬浮球" "删除应用商店" "删除服务与反馈" "删除系统更新" "删除家人守护" "删除下载管理器" "删除预装应用" "删除所有" "HyperOS 替换" "HyperOS 添加-product 分区" "禁用未签名验证" "禁用设备与热点名称检测" "调用原生安装器" "禁止主题还原" "添加新特性" "关键性 deodex" "Deodex" "移除 Avb2.0 校验" "返回工作域菜单" "退出程序")
                declare -A options
                options=(
                    ["删除小爱翻译"]="AiAsstVision*"
                    ["删除小爱语音组件"]="VoiceTrigger VoiceAssistAndroidT"
                    ["删除小爱通话"]="MIUIAiasstService"
                    ["删除互联互通服务 ROOT 验证"]="MiTrustService"
                    ["删除浏览器"]="MIUIBrowser MiBrowserGlobal"
                    ["删除音乐"]="MIUIMusic*"
                    ["删除视频"]="MIUIVideo*"
                    ["删除钱包"]="MIpay"
                    ["删除广告与分析组件"]="HybridAccessory HybridPlatform MSA* AnalyticsCore"
                    ["删除 Joyose 云控"]="Joyose"
                    ["删除自带输入法"]="SogouInput com.iflytek.inputmethod.miui BaiduIME"
                    ["删除传送门"]="MIUIContentExtension*"
                    ["删除智能助理"]="MIUIPersonalAssistant*"
                    ["删除搜索功能"]="MIUIQuickSearchBox"
                    ["删除悬浮球"]="MIUITouchAssistant*"
                    ["删除应用商店"]="MIUISuperMarket*"
                    ["删除服务与反馈"]="MIService"
                    ["删除系统更新"]="Updater"
                    ["删除家人守护"]="MIUIgreenguard"
                    ["删除下载管理器"]="DownloadProviderUi"
                    ["删除预装应用"]="MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim MIUIVipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUIGameCenter* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* system NewHome* MiRadio MiGameCenterSDKService"
                )
                brand_selected=true
                break
                ;;
            "OneUI")
                echo "已选择 OneUI"
options_order=("删除三星浏览器组件" "删除开机验证" "删除 Rec 恢复为官方" "删除主页负一屏" "删除动态表情相关组件" "删除 Bixby 语音组件" "删除微软输入法" "删除 Google 捆绑应用" "删除穿戴设备管理器" "删除系统更新" "删除主题商店" "删除 Knox 相关应用" "删除不常用应用" "删除所有" "ONEUI 替换" "ONEUI 添加-system 分区" "ONEUI 特性添加" "禁用未签名验证" "关键性 deodex" "Deodex" "移除 Avb2.0 校验" "解码 csc" "编码 csc" "返回工作域菜单" "退出程序")
declare -A options
                options=(
                    ["删除三星浏览器组件"]="SBrowser SBrowserIntelligenceService"
                    ["删除开机验证"]="ActivationDevice_V2"
                    ["删除 Rec 恢复为官方"]="recovery-from-boot.p"
                    ["删除主页负一屏"]="BixbyHomeCN_Disable"
                    ["删除动态表情相关组件"]="AREmoji AREmojiEditor AvatarEmojiSticker StickerFaceARAvatar"
                    ["删除 Bixby 语音组件"]="BixbyWakeup Bixby"
                    ["删除微软输入法"]="SwiftkeyIme SwiftkeySetting"
                    ["删除换机助手"]="SmartSwitchAgent SmartSwitchStub"
                    ["删除穿戴设备管理器"]="GearManagerStub"
                    ["删除 Google 捆绑应用"]="Maps Gmail2 YouTube DuoStub Messages Chrome64* "
                    ["删除系统更新"]="FotaAgent SOAgent7"
                    ["删除主题商店"]="ThemeStore"
                    ["删除 Knox 相关应用"]="Knox* SamsungBilling SamsungPass"
                    ["删除不常用应用"]="KidsHome_Installer"
)
                brand_selected=true
                break
                ;;
            "返回工作域菜单")
                return 0
               ;;
            "退出程序")
                clear
                exit 0
                ;;
            *)
                echo "无效的选择：$REPLY"
                ;;
        esac
    done
    if [ "$brand_selected" = true ]; then
        break
    fi
done

while true; do
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""
    echo "=============================="
    echo "  请选择要执行的操作："
    echo "=============================="
    PS3="请输入你的选择（多个选择请用逗号分隔，例如：1,3,5）："
    select opt in "${options_order[@]}"; do
        IFS=',' read -ra selections <<< "$REPLY"
        decode_selected=false
        encode_selected=false
        deodex_selected=false
        services_jar_dex_selected=false
        echo ""  # 添加空行
for selection in "${selections[@]}"; do
    # 检查选择是否有效
    if [[ $selection -lt 1 || $selection -gt ${#options_order[@]} ]]; then
        echo "无效的选择：$selection"
        continue
    fi
    index=$((selection-1))
    if [[ $index -lt 0 || $index -ge ${#options_order[@]} ]]; then
        echo "无效的选择：$selection"
        continue
    fi
    opt=${options_order[$index]}
            opt=${options_order[$((selection-1))]}
            # 如果在多选模式下选择了"退出"，则忽略"退出"
            if [[ ${#selections[@]} -gt 1 && "$opt" == "退出" ]]; then
                echo "多选择禁止退出。"
                continue
            fi
            if [ "$opt" == "解码 csc" ]; then
                decode_selected=true
            fi
            if [ "$opt" == "编码 csc" ]; then
                encode_selected=true
            fi
            if [ "$opt" == "Deodex" ]; then
                deodex_selected=true
            fi
            if [ "$opt" == "关键性 deodex" ]; then
                services_jar_dex_selected=true
            fi
            if [ "$opt" == "ONEUI 特性添加" ]; then
                oneui_feature_selected=true
            fi
        done
        if [ "$decode_selected" = true ] && [ "$encode_selected" = true ]; then
            echo "无效的选择：不能同时选择解码和编码"
            continue
        fi
        if [ "$deodex_selected" = true ] && [ "$services_jar_dex_selected" = true ]; then
            echo "无效的选择：不能同时选择 Deodex 和 关键性 deodex"
            continue
        fi
        if [ "$oneui_feature_selected" = true ] && ([ "$decode_selected" = true ] || [ "$encode_selected" = true ]); then
            echo "无效的选择：不能同时选择 ONEUI 特性添加 和 解码/编码 csc"
            continue
        fi
        deleted=false
        for selection in "${selections[@]}"; do
            opt=${options_order[$((selection-1))]}
            case $opt in
                "移除 Avb2.0 校验")
                    echo "已选择 移除 Avb2.0 校验"
                    remove_vbmeta_verification
                    remove_extra_vbmeta_verification
                    ;;
                "禁用设备与热点名称检测")
                    echo "已选择 禁用设备与热点名称检测"
                    remove_device_and_network_verification
                    ;;
                "HyperOS 替换")
                    echo "已选择 HyperOS 替换"
                    replace_files_xiaomi
                    ;;
                "HyperOS 添加-product 分区")
                    echo "已选择 HyperOS 添加-product 分区"
                    copy_dir_xiaomi
                    ;;
                "ONEUI 替换")
                    echo "已选择 ONEUI 替换"
                    replace_files_samsung
                    ;;
                "ONEUI 添加-system 分区")
                    echo "已选择 ONEUI 添加-system 分区"
                    copy_dir_samsung
                    ;;
                "ONEUI 特性添加")
                    echo "已选择 ONEUI 特性添加"
                    csc_feature_add
                    ;;
                "解码 csc")
                    echo "已选择 解码 csc"
                    decode_csc
                    ;;
                "编码 csc")
                    echo "已选择 编码 csc"
                    encode_csc
                    ;;
                "禁用未签名验证")
                    echo "已选择 禁用未签名验证"
                    remove_unsigned_app_verification
                    ;;
                "调用原生安装器")
                    echo "已选择 调用原生安装器"
                    invoke_native_installer
                    ;;
                "禁止主题还原")
                    echo "已选择 禁止主题还原"
                    prevent_theme_reversion
                    ;;
                "添加新特性")
                    echo "添加新特性"
                    update_build_props
                    ;;
                "Deodex")
                    echo "已选择 Deodex"
                    deodex
                    ;;
                "关键性 deodex")
                    echo "已选择 关键性 deodex"
                    deodex_key_files
                    ;;
                "删除所有")
                    if [[ ${#selections[@]} -gt 1 ]]; then
                        echo "删除所有在多选择中被禁用"
                    else
                        echo "已选择 删除所有"
                        remove_all
                    fi
                    ;;
                "返回工作域菜单")
                    return 0
                    ;;
                "退出程序")
                    clear
                    exit 0
                    ;;
                *)
                    echo "已选择 $opt"
                    remove_files "${options[$opt]}"
                    ;;
            esac
            echo ""  # 添加空行
        done
        break
    done
done
}
