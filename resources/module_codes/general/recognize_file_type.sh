function recognize_file_type() {
	local file=$1
	# 检查文件是否存在
	if [ ! -f "$file" ]; then
		return
	fi
	# 定义你想要搜索的 "魔数"
	local magic_boot=$(head -c 8 "$file" | tr -d '\0')
	local magic_dtbo=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0')
	local magic_dtb=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0') # 新增的魔数判定
	local magic_erofs=$(xxd -p -l 4 -s 1024 "$file" | tr -d '\0')
	local magic_ext=$(xxd -p -l 2 -s 1080 "$file" | tr -d '\0')
	local magic_f2fs=$(xxd -p -l 4 -s 1024 "$file" | tr -d '\0')
	local magic_payload=$(head -c 4 "$file" | tr -d '\0')
	local magic_sparse=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0')
	local magic_super1=$(head -c 4 "$file" | tr -d '\0')
	local magic_super2=$(dd if="$file" bs=1 skip=4096 count=4 2>/dev/null | tr -d '\0')
	local magic_vbmeta=$(head -c 4 "$file" | tr -d '\0')
	local magic_vendor_boot=$(head -c 8 "$file" | tr -d '\0')
	local magic_7z=$(head -c 2 "$file" | tr -d '\0')
	local magic_zip=$(head -c 2 "$file" | tr -d '\0')
	local magic_tar=$(dd if="$file" bs=1 skip=257 count=5 2>/dev/null | tr -d '\0')
	local magic_lz4=$(xxd -p -l 4 -s 0 "$file" | tr -d '\0')

	if [[ "$magic_boot" == "ANDROID!" ]]; then
		echo "boot"
	elif [[ "$magic_dtbo" == "d7b7ab1e" ]]; then
		echo "dtbo"
	elif [[ "$magic_dtb" == "d00dfeed" ]]; then
		echo "dtb"
	elif [[ "$magic_erofs" == "e2e1f5e0" ]]; then
		echo "erofs"
	elif [[ "$magic_ext" == "53ef" ]]; then
		echo "ext"
	elif [[ "$magic_f2fs" == "1020f5f2" ]]; then
		echo "f2fs"
	elif [[ "$magic_payload" == "CrAU" ]]; then
		echo "payload"
	elif [[ "$magic_sparse" == "3aff26ed" ]]; then
		echo "sparse"
	elif [[ "$magic_super1" == "gDla" ]] || [[ "$magic_super2" == "gDla" ]]; then
		echo "super"
	elif [[ "$magic_vbmeta" == "AVB0" ]]; then
		echo "vbmeta"
	elif [[ "$magic_vendor_boot" == "VNDRBOOT" ]]; then
		echo "vendor_boot"
	elif [[ "$magic_7z" == "7z" ]]; then
		echo "7z"
	elif [[ "$magic_zip" == "PK" ]]; then
		echo "zip"
	elif [[ "$magic_tar" == "ustar" ]]; then
		echo "tar"
	elif [[ "$magic_lz4" == "03214c18" ]] || [[ "$magic_lz4" == "04224d18" ]]; then
		echo "lz4"
	else
		echo "unknown"
	fi
}
