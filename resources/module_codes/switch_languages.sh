# 替换脚本
function replace_script {
  cp "$(dirname "$0")/resources/languages/$1" "$(dirname "$0")/start.sh"
}