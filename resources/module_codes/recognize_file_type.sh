function recognize_file_type() {
  local file=$1
  # 检查文件是否存在
  if [ ! -f "$file" ]; then
    return
  fi
  # 定义你想要搜索的 "魔数"
  local magic_erofs=$(xxd -p -l 4 -s 1024 "$file" | tr -d '\0')
  local magic_f2fs=$(xxd -p -l 4 -s 1024 "$file" | tr -d '\0')
  local magic_ext=$(xxd -p -l 2 -s 1080 "$file" | tr -d '\0')
  local magic_sparse=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0')
  local magic_payload=$(head -c 4 "$file" | tr -d '\0')
  local magic_vbmeta=$(head -c 4 "$file" | tr -d '\0')
  local magic_dtbo=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0')
  local magic_boot=$(head -c 8 "$file" | tr -d '\0')
  local magic_super1=$(head -c 4 "$file" | tr -d '\0')
  local magic_super2=$(dd if="$file" bs=1 skip=4096 count=4 2>/dev/null | tr -d '\0')
  local magic_vendor_boot=$(head -c 8 "$file" | tr -d '\0')  # 新增的魔数判定

  if [[ "$magic_erofs" == "e2e1f5e0" ]]; then
    echo "erofs"
  elif [[ "$magic_f2fs" == "1020f5f2" ]]; then
    echo "f2fs"
  elif [[ "$magic_ext" == "53ef" ]]; then
    echo "ext"
  elif [[ "$magic_sparse" == "3aff26ed" ]]; then
    echo "sparse"
  elif [[ "$magic_payload" == "CrAU" ]]; then
    echo "payload"
  elif [[ "$magic_vbmeta" == "AVB0" ]]; then
    echo "vbmeta"
  elif [[ "$magic_dtbo" == "d7b7ab1e" ]]; then
    echo "dtbo"
  elif [[ "$magic_boot" == "ANDROID!" ]]; then
    echo "boot"
  elif [[ "$magic_vendor_boot" == "VNDRBOOT" ]]; then  # 新增的条件
    echo "vendor_boot"
  elif [[ "$magic_super1" == "gDla" ]] || [[ "$magic_super2" == "gDla" ]]; then
    echo "super"
  else
    echo "unknown"
  fi
}
