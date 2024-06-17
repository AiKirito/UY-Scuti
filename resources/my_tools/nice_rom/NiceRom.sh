#!/bin/bash


update_build_props() {
  declare -A lines_to_add=(
    [system]="persist.sys.background_blur_supported=true persist.sys.background_blur_status_default=true persist.sys.background_blur_mode=0 persist.sys.background_blur_version=2 debug.game.video.speed=1 debug.game.video.support=1"
    [vendor]="ro.vendor.se.type=HCE,UICC,eSE ro.vendor.audio.sfx.scenario=true"
    [product]="persist.sys.miui_animator_sched.sched_threads=2 persist.vendor.display.miui.composer_boost=4-7"
  )
  while IFS= read -r -d '' dir; do
    local type="${dir##*/}"
    local build_prop_path="$dir/build.prop"
    if [[ "$type" == "product" ]]; then
      build_prop_path="$dir/etc/build.prop"
    fi
    if { [[ "$type" == "system" && -d "$dir/framework" ]] || 
         [[ "$type" == "vendor" && -d "$dir/etc" ]] ||
         [[ "$type" == "product" && -d "$dir/etc" ]]; } && [[ -f "$build_prop_path" ]]; then
      IFS=$'\n' read -d '' -r -a current_lines < "$build_prop_path"
      for key in "${!lines_to_add[@]}"; do
        if [[ "$type" == "$key" ]]; then
          for line in ${lines_to_add[$key]}; do
            local prop_name=$(echo "$line" | cut -d '=' -f 1)
            sed -i "/$prop_name/d" "$build_prop_path"
            echo "$line" >> "$build_prop_path"
          done
        fi
      done
      echo "已更新 $type 文件夹的 $build_prop_path 文件。"
    fi
  done < <(find "$onepath" -type d \( -name 'system' -o -name 'vendor' -o -name 'product' \) -print0)
}

prevent_theme_reversion() {
  local apktool_path="$(dirname "$0")/bin/all/apktool/apktool_2.9.3.jar"

  while IFS= read -r -d '' system_ext_dir; do
    if [[ -d "$system_ext_dir/framework" && -f "$system_ext_dir/framework/miui-framework.jar" ]]; then
      java -jar "$apktool_path" d -f "$system_ext_dir/framework/miui-framework.jar" -o "$system_ext_dir/framework/miui-framework"

      while IFS= read -r -d '' smali_file; do
        echo "找到文件：$smali_file，开始修改内容..."
        sed -i '/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;/,/move-result-object [a-z0-9]*/{s/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;//;s/move-result-object \([a-z0-9]*\)/sget-object \1, Lmiui\/drm\/DrmManager\$DrmResult;->DRM_SUCCESS:Lmiui\/drm\/DrmManager\$DrmResult;/}' "$smali_file"
      done < <(find "$system_ext_dir/framework/miui-framework" -name "ThemeReceiver.smali" -print0)

      java -jar "$apktool_path" b -api 29 -c -f "$system_ext_dir/framework/miui-framework" -o "$system_ext_dir/framework/miui-framework.jar"
      rm -rf "$system_ext_dir/framework/miui-framework"
      echo "修改完成"
    fi
  done < <(find "$onepath" -type d -name 'system_ext' -print0)
}

invoke_native_installer() {
  local apktool_path="$(dirname "$0")/bin/all/apktool/apktool_2.9.3.jar"
  while IFS= read -r -d '' system_ext_dir; do
    if [[ -d "$system_ext_dir/framework" && -f "$system_ext_dir/framework/miui-services.jar" ]]; then
      java -jar "$apktool_path" d -f "$system_ext_dir/framework/miui-services.jar" -o "${system_ext_dir}/framework/miui-services"
      echo "正在修改 ..."
      local smali_file="${system_ext_dir}/framework/miui-services/smali/com/android/server/pm/PackageManagerServiceImpl.smali"
      if [[ -f "$smali_file" ]]; then

        sed -i '/.method public checkGTSSpecAppOptMode()V/,/.end method/c\.method public checkGTSSpecAppOptMode()V\n    .registers 1\n    return-void\n.end method' "$smali_file"

        sed -i '/.method public static isCTS()Z/,/.end method/c\.method public static isCTS()Z\n    .registers 1\n\n    const/4 v0, 0x1\n\n    return v0\n.end method' "$smali_file"
      fi
      
      java -jar "$apktool_path" b -c -f "${system_ext_dir}/framework/miui-services" -o "${system_ext_dir}/framework/miui-services.jar"
      rm -rf "${system_ext_dir}/framework/miui-services"
      echo "修改完成"
    fi
  done < <(find "$onepath" -type d -name 'system_ext' -print0)
}

remove_unsigned_app_verification() {
  local apktool_path="$(dirname "$0")/bin/all/apktool/apktool_2.9.3.jar"

  while IFS= read -r -d '' jarfile; do
    java -jar "$apktool_path" d -f -r "$jarfile" -o "${jarfile%.jar}"
    echo "正在检索 ..."

    while IFS= read -r -d '' smali_file; do
      if sed -n '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result-object [a-z0-9]*/p' "$smali_file" | grep -q 'invoke-static'; then
        sed -i '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result-object [a-z0-9]*/{s/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I//;s/move-result-object \([a-z0-9]*\)/const\/4 \1, 0x0/}' "$smali_file"
        echo "已修改：$smali_file"
      fi
    done < <(find "${jarfile%.jar}" -name '*.smali' -print0)

    java -jar "$apktool_path" b -c -f "${jarfile%.jar}" -o "$jarfile"
    rm -rf "${jarfile%.jar}"
    echo "修改完成"
  done < <(find "$onepath" -name "services.jar" -print0)
}

copy_dir_xiaomi() {
    declare -A dirs=(["app"]="app" ["data-app"]="data-app" ["priv-app"]="priv-app")
    while IFS= read -r -d '' dir; do
        if [ -d "$dir/bin" ] && [ -d "$dir/media" ] && [ -d "$dir/overlay" ] && [ ! -d "$(dirname "$dir")/etc" ]; then
            for src_dir in "${!dirs[@]}"; do
                dst_dir=${dirs[$src_dir]}
                while IFS= read -r -d '' subdir; do
                    subdir_name=$(basename "$subdir")
                    new_name=${subdir_name#file_locked_}
                    new_name="${new_name}_Extra"
                    mkdir -p "$dir/$dst_dir/$new_name"
                    while IFS= read -r -d '' file; do
                        base_name=$(basename "$file" | cut -d. -f1)
                        extension=$(basename "$file" | cut -s -d. -f2)
                        new_base_name=${base_name#Only_}
                        new_base_name="${new_base_name}_Extra"
                        if [ -n "$extension" ]; then
                            new_file_name="$new_base_name.$extension"
                        else
                            new_file_name="$new_base_name"
                        fi
                        cp -v "$file" "$dir/$dst_dir/$new_name/$new_file_name"
                    done < <(find "$subdir" -type f -print0)
                done < <(find "bin/xiaomi/add_for_product/$src_dir" -maxdepth 1 -type d -name "file_locked_*" -print0)
            done
        fi
    done < <(find "$onepath" -type d -name "product" -print0)
}


replace_files_xiaomi() {
    local src_dir="$(dirname "$0")/bin/xiaomi/replace"
    local dst_dir="$onepath"

    for src_file in "$src_dir"/*
    do
        local name=$(basename "$src_file")
        mv "$src_file" "$src_dir/$name"_ready_to_adjust
    done

    # 处理文件
    while IFS= read -r -d '' file; do
        local name=$(basename "$file")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == *"$name"_ready_to_adjust ]]; then
                rm -rf "$file"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$file")/$name" > /dev/null && echo "替换文件完成：$(dirname "$file")/$name"
            fi
        done
    done < <(find "$dst_dir" -type f -print0)

    # 处理目录
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == *"$name"_ready_to_adjust ]]; then
                rm -rf "$dir"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$dir")/$name" > /dev/null && echo "替换目录完成：$(dirname "$dir")/$name"
            fi
        done
    done < <(find "$dst_dir" -type d -print0)

    for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
    do
        mv  "$src_file_ready_to_adjust" "${src_file_ready_to_adjust%_ready_to_adjust*}"
    done
}

: <<'END'
replace_files_xiaomi() {
    local src_dir="$(dirname "$0")/bin/xiaomi/replace"
    local dst_dir="$onepath"

    for src_file in "$src_dir"/*
    do
        local name=$(basename "$src_file")
        mv "$src_file" "$src_dir/$name"_ready_to_adjust
    done

    find "$dst_dir" -type f -o -type d | while read -r file
    do
        local name=$(basename "$file")

        # 查找所有带 _ready_to_adjust 后缀的同名文件或文件夹
        for src_file_ready_to_adjust in "$src_dir/$name"_ready_to_adjust*
        do
            if [ -e "$src_file_ready_to_adjust" ]; then
                rm -rf "$file"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$file")/$name" > /dev/null && echo "替换文件完成：$(dirname "$file")/$name"
            fi
        done
    done
    # 在源目录中移除所有文件或文件夹的 _ready_to_adjust 后缀
    for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
    do
        mv  "$src_file_ready_to_adjust" "${src_file_ready_to_adjust%_ready_to_adjust*}"
    done
}
END

decode_csc() {
    local script_dir=$(dirname "$0")
    local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
    local input_file
    local output_file
    for file in "cscfeature.xml" "customer_carrier_feature.json"; do
        while IFS= read -r -d '' filepath; do
            echo "找到文件：$filepath"
            echo "正在解码 $file ..."
            input_file="$filepath"
            output_file="${filepath%.*}_decoded.${filepath##*.}"
            java -jar "$omc_decoder_path" -i "$input_file" -o "$output_file"
            rm -v "$input_file"  # 删除原始文件
        done < <(find "$onepath" -name "$file" -print0)
    done
}

encode_csc() {
    local script_dir=$(dirname "$0")
    local omc_decoder_path="$script_dir/bin/samsung/csc_tool/omc-decoder.jar"
    local input_file
    local output_file
    local original_file
    for file in "cscfeature_decoded.xml" "customer_carrier_feature_decoded.json"; do
        while IFS= read -r -d '' filepath; do
            echo "找到文件：$filepath"
            echo "正在编码 $file ..."
            input_file="$filepath"
            output_file="${filepath/_decoded/}"
            java -jar "$omc_decoder_path" -e -i "$input_file" -o "$output_file"
            rm -v "$input_file"  # 删除解码的文件
        done < <(find "$onepath" -name "$file" -print0)
    done
}

# 定义一个函数来执行 Deodex 操作
deodex() {
    local found=false
    for file in oat "*.art" "*.oat" "*.vdex" "*.odex" "*.fsv_meta" "*.bprof" "*.prof" ; do
        if find "$onepath" -name "$file" -print0 | xargs -0 | grep -q .; then
            found=true
            echo "正在删除 $file ..."
            find "$onepath" -name "$file" -not \( -name "" -o -name "" \) -print0 | xargs -0 rm -vrf
        fi
    done
    if [ "$found" = false ]; then
        echo "没有与 odex 有关的文件可删除"
    fi
}

# 定义一个函数来执行关键性 deodex 操作
deodex_key_files() {
  local found=false
  local files=("services.art" "services.odex" "services.vdex" "services.*.fsv_meta" "services.jar.bprof" "services.jar.prof" "miui-services.jar.fsv_meta" "miui-framework.jar.fsv_meta" "miui-services.odex" "miui-services.odex.fsv_meta" "miui-services.vdex" "miui-services.vdex.fsv_meta")
  for file in "${files[@]}"; do
    if find "$onepath" -name "$file" -print0 | xargs -0 | grep -q .; then
      found=true
      echo "正在删除 $file ..."
      find "$onepath" -name "$file" -print0 | xargs -0 rm -vrf
    fi
  done
  if [ "$found" = false ]; then
    echo "没有相关文件可删除"
  fi
}

# 定义一个函数来执行所有的删除操作
remove_all() {
    for opt in "${options_order[@]}"; do
            remove_files "${options[$opt]}"
    done
}

remove_files() {
    for file in $@; do
        while IFS= read -r -d '' dir
        do
            base_name=$(basename "$dir")
            if find "$dir" -iname "$base_name.apk" | grep -q .; then
                echo "正在删除 $dir ..."
                rm -vrf "$dir"
            fi
        done < <(find "$onepath" -depth -type d -iname "$file" -print0)
    done
}

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
                options_order=("删除小爱翻译" "删除小爱语音组件" "删除小爱通话" "删除互联互通服务 ROOT 验证" "删除浏览器" "删除音乐" "删除视频" "删除钱包" "删除广告与分析组件" "删除 Joyose 云控" "删除自带输入法" "删除传送门" "删除智能助理" "删除搜索功能" "删除悬浮球" "删除应用商店" "删除服务与反馈" "删除系统更新" "删除家人守护" "删除下载管理器" "删除可能不需要的应用" "删除所有" "HyperOS 替换" "HyperOS 添加" "禁用未签名验证" "调用原生安装器" "禁止主题还原" "添加新特性" "关键性 deodex" "Deodex" "返回工作域菜单" "退出程序")
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
                    ["删除可能不需要的应用"]="MiShop* Health* SmartHome wps-lite XMRemoteController ThirdAppAssistant MIUIVirtualSim MIUIVipAccount MIUIMiDrive* MIUIHuanji* MIUIEmail* MIGalleryLockscreen* MIUIGameCenter* MIUINotes* MIUIDuokanReader* MIUIYoupin* MIUINewHome_Removable* system"
                )
                brand_selected=true
                break
                ;;
            "OneUI")
                echo "已选择 OneUI"
options_order=("删除三星浏览器组件" "删除开机验证" "删除 Rec 恢复为官方" "解码 csc" "编码 csc" "关键性 deodex" "Deodex" "删除所有" "返回工作域菜单" "退出程序")
declare -A options
                options=(
                    ["删除三星浏览器组件"]="SBrowser SBrowserIntelligenceService"
                    ["删除开机验证"]="ActivationDevice_V2"
                    ["删除 Rec 恢复为官方"]="recovery-from-boot.p"
                    ["解码 csc"]=""
                    ["编码 csc"]=""
                    ["关键性 deodex"]=""
                    ["Deodex"]=""
                    ["删除所有"]=""
                    ["退出"]=""
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
        done
        if [ "$decode_selected" = true ] && [ "$encode_selected" = true ]; then
            echo "无效的选择：不能同时选择解码和编码"
            continue
        fi
        if [ "$deodex_selected" = true ] && [ "$services_jar_dex_selected" = true ]; then
            echo "无效的选择：不能同时选择 Deodex 和 关键性 deodex"
            continue
        fi
	deleted=false
        for selection in "${selections[@]}"; do
            opt=${options_order[$((selection-1))]}
            case $opt in
                "HyperOS 替换")
                    echo "已选择 HyperOS 替换"
                    replace_files_xiaomi
                    ;;
                "HyperOS 添加")
                    echo "已选择 HyperOS 添加"
                    copy_dir_xiaomi
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
        done
        break
    done
done
}
