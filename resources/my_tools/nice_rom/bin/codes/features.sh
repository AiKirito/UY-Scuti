#!/bin/bash

copy_dir_xiaomi() {
    # 声明一个关联数组，键和值分别代表源目录和目标目录
    declare -A dirs=(["app"]="app" ["data-app"]="data-app" ["priv-app"]="priv-app")
    
    # 读取 $onepath 目录中名称为 "product" 的目录
    while IFS= read -r -d '' dir; do
        # 检查目录中是否存在 bin、media 和 overlay 子目录，并且父目录中不存在 etc 目录
        if [ -d "$dir/bin" ] && [ -d "$dir/media" ] && [ -d "$dir/overlay" ] && [ ! -d "$(dirname "$dir")/etc" ]; then
            # 遍历关联数组中的每个源目录
            echo "添加的应用：" 
            for src_dir in "${!dirs[@]}"; do
                dst_dir=${dirs[$src_dir]}
                # 查找 bin/xiaomi/add_for_product/$src_dir 中名称匹配 file_locked_* 的子目录
                while IFS= read -r -d '' subdir; do
                    # 重命名子目录，去掉前缀 file_locked_ 并添加后缀 _Extra
                    subdir_name=$(basename "$subdir")
                    new_name="${subdir_name#file_locked_}_Extra"
                    # 创建新目录
                    mkdir -p "$dir/$dst_dir/$new_name"
                    # 查找子目录中的所有文件
                    while IFS= read -r -d '' file; do
                        # 重命名文件，去掉前缀 Only_ 并添加后缀 _Extra
                        base_name=$(basename "$file" | cut -d. -f1)
                        extension=$(basename "$file" | cut -s -d. -f2)
                        new_base_name=${base_name#Only_}
                        new_base_name="${new_base_name}_Extra"
                        if [ -n "$extension" ]; then
                            new_file_name="$new_base_name.$extension"
                        else
                            new_file_name="$new_base_name"
                        fi
                        # 打印目标路径
                        echo "$dir/$dst_dir/$new_name"
                        # 创建目标文件夹
                        mkdir -p "$(dirname "$dir/$dst_dir/$new_name/$new_file_name")"
                        # 复制文件到新目录
                        cp "$file" "$dir/$dst_dir/$new_name/$new_file_name"
                    done < <(find "$subdir" -type f -print0)
                done < <(find "bin/xiaomi/add_for_product/$src_dir" -maxdepth 1 -type d -name "file_locked_*" -print0)
            done
        fi
    done < <(find "$onepath" -type d -name "product" -print0)
}

copy_dir_samsung() {
    # 声明一个关联数组，键和值分别代表源目录和目标目录
    declare -A dirs=(["app"]="app" ["preload"]="preload" ["priv-app"]="priv-app")
    
    # 读取 $onepath 目录中名称为 "system" 的目录
    while IFS= read -r -d '' dir; do
        # 检查目录中是否存在 bin、media 和 preload 子目录，并且目录中存在 etc 子目录
        if [ -d "$dir/bin" ] && [ -d "$dir/media" ] && [ -d "$dir/preload" ] && [ -d "$dir/etc" ]; then
            # 遍历关联数组中的每个源目录
            echo "添加的应用：" 
            for src_dir in "${!dirs[@]}"; do
                dst_dir=${dirs[$src_dir]}
                # 查找 bin/samsung/add_for_system/$src_dir 中名称匹配 file_locked_* 的子目录
                while IFS= read -r -d '' subdir; do
                    # 重命名子目录，去掉前缀 file_locked_ 并添加后缀 _Extra
                    subdir_name=$(basename "$subdir")
                    new_name="${subdir_name#file_locked_}_Extra"
                    # 创建新目录
                    mkdir -p "$dir/$dst_dir/$new_name"
                    # 查找子目录中的所有文件
                    while IFS= read -r -d '' file; do
                        # 重命名文件，去掉前缀 Only_ 并添加后缀 _Extra
                        base_name=$(basename "$file" | cut -d. -f1)
                        extension=$(basename "$file" | cut -s -d. -f2)
                        new_base_name=${base_name#Only_}
                        new_base_name="${new_base_name}_Extra"
                        if [ -n "$extension" ]; then
                            new_file_name="$new_base_name.$extension"
                        else
                            new_file_name="$new_base_name"
                        fi
                        # 打印目标路径
                        echo "$dir/$dst_dir/$new_name"
                        # 创建目标文件夹
                        mkdir -p "$(dirname "$dir/$dst_dir/$new_name/$new_file_name")"
                        # 复制文件到新目录
                        cp "$file" "$dir/$dst_dir/$new_name/$new_file_name"
                    done < <(find "$subdir" -type f -print0)
                done < <(find "bin/samsung/add_for_system/$src_dir" -maxdepth 1 -type d -name "file_locked_*" -print0)
            done
        fi
    done < <(find "$onepath" -type d -name "system" -print0)
}

replace_files_samsung() {
    local src_dir="$(dirname "$0")/bin/samsung/replace"
    local dst_dir="$onepath"

    for src_file in "$src_dir"/*
    do
        local name=$(basename "$src_file")
        mv "$src_file" "$src_dir/$name"_ready_to_adjust
    done

    echo "替换的文件："
    # 处理文件
    while IFS= read -r -d '' file; do
        local name=$(basename "$file")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == "$src_dir/$name"_ready_to_adjust ]]; then
                rm -rf "$file"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$file")/$name" > /dev/null && echo "$(dirname "$file")/$name"
            fi
        done
    done < <(find "$dst_dir" -type f -print0)

    echo "替换的目录："
    # 处理目录
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == "$src_dir/$name"_ready_to_adjust ]]; then
                rm -rf "$dir"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$dir")/$name" > /dev/null && echo "$(dirname "$dir")/$name"
            fi
        done
    done < <(find "$dst_dir" -type d -print0)

    for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
    do
        mv  "$src_file_ready_to_adjust" "${src_file_ready_to_adjust%_ready_to_adjust*}"
    done
}

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

      echo "搜寻到的要修改的目标："
      while IFS= read -r -d '' smali_file; do
        echo "$smali_file"
        sed -i '/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;/,/move-result-object [a-z0-9]*/{s/invoke-static {.*}, Lmiui\/drm\/DrmManager;->isLegal(Landroid\/content\/Context;Ljava\/io\/File;Ljava\/io\/File;)Lmiui\/drm\/DrmManager$DrmResult;//;s/move-result-object \([a-z0-9]*\)/sget-object \1, Lmiui\/drm\/DrmManager\$DrmResult;->DRM_SUCCESS:Lmiui\/drm\/DrmManager\$DrmResult;/}' "$smali_file"
      done < <(find "$system_ext_dir/framework/miui-framework" -name "ThemeReceiver.smali" -print0)

      java -jar "$apktool_path" b -api 29 -c -f "$system_ext_dir/framework/miui-framework" -o "$system_ext_dir/framework/miui-framework.jar"
      rm -rf "$system_ext_dir/framework/miui-framework"
      echo "成功移除主题还原"
    fi
  done < <(find "$onepath" -type d -name 'system_ext' -print0)
}

invoke_native_installer() {
  local apktool_path="$(dirname "$0")/bin/all/apktool/apktool_2.9.3.jar"

  while IFS= read -r -d '' system_ext_dir; do
    if [[ -d "$system_ext_dir/framework" && -f "$system_ext_dir/framework/miui-services.jar" ]]; then
      java -jar "$apktool_path" d -f "$system_ext_dir/framework/miui-services.jar" -o "${system_ext_dir}/framework/miui-services"
      echo "搜寻到的要修改的目标："
      local smali_file="${system_ext_dir}/framework/miui-services/smali/com/android/server/pm/PackageManagerServiceImpl.smali"
      if [[ -f "$smali_file" ]]; then
        echo "$smali_file"
        sed -i '/.method public checkGTSSpecAppOptMode()V/,/.end method/c\.method public checkGTSSpecAppOptMode()V\n    .registers 1\n    return-void\n.end method' "$smali_file"

        sed -i '/.method public static isCTS()Z/,/.end method/c\.method public static isCTS()Z\n    .registers 1\n\n    const/4 v0, 0x1\n\n    return v0\n.end method' "$smali_file"
      fi
      
      java -jar "$apktool_path" b -c -f "${system_ext_dir}/framework/miui-services" -o "${system_ext_dir}/framework/miui-services.jar"
      rm -rf "${system_ext_dir}/framework/miui-services"
      echo "成功调用 Android 原生安装器"
    fi
  done < <(find "$onepath" -type d -name 'system_ext' -print0)
}

remove_unsigned_app_verification() {
  local apktool_path="$(dirname "$0")/bin/all/apktool/apktool_2.9.3.jar"

  while IFS= read -r -d '' jarfile; do
    java -jar "$apktool_path" d -f -r "$jarfile" -o "${jarfile%.jar}"
    echo "搜寻到的要修改的目标："
    while IFS= read -r -d '' smali_file; do
      if sed -n '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result [a-z0-9]*/p' "$smali_file" | grep -q 'invoke-static'; then
        sed -i '/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I/,/move-result [a-z0-9]*/{s/invoke-static {.*}, Landroid\/util\/apk\/ApkSignatureVerifier;->getMinimumSignatureSchemeVersionForTargetSdk(I)I//;s/move-result \([a-z0-9]*\)/const\/4 \1, 0x0/}' "$smali_file"
        echo "$smali_file"
      fi
    done < <(find "${jarfile%.jar}" -name '*.smali' -print0)

    java -jar "$apktool_path" b -c -f "${jarfile%.jar}" -o "$jarfile"
    rm -rf "${jarfile%.jar}"
    echo "成功移除未签名应用的校验"
  done < <(find "$onepath" -name "services.jar" -print0)
}

replace_files_xiaomi() {
    local src_dir="$(dirname "$0")/bin/xiaomi/replace"
    local dst_dir="$onepath"

    for src_file in "$src_dir"/*
    do
        local name=$(basename "$src_file")
        mv "$src_file" "$src_dir/$name"_ready_to_adjust
    done

    echo "替换的文件："
    # 处理文件
    while IFS= read -r -d '' file; do
        local name=$(basename "$file")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == "$src_dir/$name"_ready_to_adjust ]]; then
                rm -rf "$file"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$file")/$name" > /dev/null && echo "$(dirname "$file")/$name"
            fi
        done
    done < <(find "$dst_dir" -type f -print0)

    echo "替换的目录："
    # 处理目录
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
        do
            if [[ "$src_file_ready_to_adjust" == "$src_dir/$name"_ready_to_adjust ]]; then
                rm -rf "$dir"
                cp -r "$src_file_ready_to_adjust" "$(dirname "$dir")/$name" > /dev/null && echo "$(dirname "$dir")/$name"
            fi
        done
    done < <(find "$dst_dir" -type d -print0)

    for src_file_ready_to_adjust in "$src_dir"/*_ready_to_adjust
    do
        mv  "$src_file_ready_to_adjust" "${src_file_ready_to_adjust%_ready_to_adjust*}"
    done
}

csc_feature_add() {
    local csc_features_need_path="$(dirname "$0")/bin/samsung/csc_add/csc_features_need"
    local lines=("SupportRealTimeNetworkSpeed" "VoiceCall_ConfigRecording" "Camera_EnableCameraDuringCall" "Camera_EnableCameraDuringCall")  # 网速显示，通话录音

    decode_csc > /dev/null 2>&1

    while IFS= read -r -d '' filepath; do
        for line in "${lines[@]}"; do
            if grep -q "$line" "$filepath"; then
                sed -i "/$line/d" "$filepath"
            fi
        done
    done < <(find "$onepath" -name "cscfeature_decoded.xml" -print0)

    while IFS= read -r line; do
        while IFS= read -r -d '' filepath; do
            gawk -i inplace -v line="$line" '{if (NR==FNR && /<\/FeatureSet>/) {print line} print}' "$filepath"
        done < <(find "$onepath" -name "cscfeature_decoded.xml" -print0)
    done < "$csc_features_need_path"

    echo "添加特性："
    while IFS= read -r line; do
        echo "$line"
    done < "$csc_features_need_path"

    encode_csc > /dev/null 2>&1
}

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
            rm "$input_file"  # 删除原始文件
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
            rm "$input_file"  # 删除解码的文件
        done < <(find "$onepath" -name "$file" -print0)
    done
}

deodex() {
    local found=false
    echo "删除列表："
    for file in oat "*.art" "*.oat" "*.vdex" "*.odex" "*.fsv_meta" "*.bprof" "*.prof"; do
        if find "$onepath" -name "$file" -print0 | xargs -0 | grep -q .; then
            found=true
            find "$onepath" -name "$file" -not \( -name "" -o -name "" \) -print0 | xargs -0 -I {} sh -c 'echo {}; rm -rf {}'
        fi
    done
    if [ "$found" = false ]; then
        echo "没有与 odex 有关的文件可删除"
    fi
}

deodex_key_files() {
    local found=false
    local files=("services.art" "services.odex" "services.vdex" "services.*.fsv_meta" "services.jar.bprof" "services.jar.prof" "miui-services.jar.fsv_meta" "miui-framework.jar.fsv_meta" "miui-services.odex" "miui-services.odex.fsv_meta" "miui-services.vdex" "miui-services.vdex.fsv_meta")
    echo "关键性删除列表："
    for file in "${files[@]}"; do
        if find "$onepath" -name "$file" -print0 | xargs -0 | grep -q .; then
            found=true
            find "$onepath" -name "$file" -print0 | xargs -0 -I {} sh -c 'echo {}; rm -rf {}'
        fi
    done
    if [ "$found" = false ]; then
        echo "没有相关文件可删除"
    fi
}

remove_all() {
    for opt in "${options_order[@]}"; do
            remove_files "${options[$opt]}"
    done
}

remove_files() {
    exclude_files=("samsungpass" "KnoxDesktopLauncher")
    exclude_string=""
    for exclude in "${exclude_files[@]}"; do
        exclude_string+=" -not -iname $exclude"
    done
    for file in $@; do
        while IFS= read -r -d '' dir
        do
            base_name=$(basename "$dir")
            if find "$dir" -iname "$base_name.apk" | grep -q .; then
                echo "$dir ..."
                rm -rf "$dir"
            fi
        done < <(find "$onepath" -depth -type d -iname "$file" $exclude_string -print0)
    done
}

