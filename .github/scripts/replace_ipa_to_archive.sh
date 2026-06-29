#!/bin/sh
set -eu

# usage: ./replace_ipa_to_archive.sh <xcarchive_path> <obfuscated_ipa_path>
# This script replaces the app bundle inside the .xcarchive with the obfuscated
# ipa contents, then regenerates dSYM and strips symbols as described in the
# iJiaMi IPA hardening guide.
if [ "$#" -ne 2 ]; then
  echo "usage : $0 xcarchive文件夹全路径 加固后的ipa文件全路径"
  exit 1
fi

xcarchive_file_path=$1
obf_ipa_file_path=$2

if [ ! -d "$xcarchive_file_path" ]; then
  echo "xcarchive folder not found: $xcarchive_file_path"
  exit 1
fi

if [ ! -f "$obf_ipa_file_path" ]; then
  echo "obfuscated ipa not found: $obf_ipa_file_path"
  exit 1
fi

echo "xcarchive文件夹全路径: ${xcarchive_file_path}"
echo "加固后的ipa文件全路径: ${obf_ipa_file_path}"

obf_ipa_filename=$(basename "$obf_ipa_file_path")
timestr=$(date +%s%N | cut -b1-13)

echo "${obf_ipa_filename}"
echo "${timestr}"

echo "开始创建临时目录>>>BEGIN"
tmp_dir_path=$(/usr/bin/mktemp -d -t "${obf_ipa_filename}${timestr}")
echo "创建临时目录完成===END: ${tmp_dir_path}"

echo "开始解压加固包>>>BEGIN"
/usr/bin/unzip "$obf_ipa_file_path" -d "$tmp_dir_path" > /dev/null 2>&1
echo "解压加固包完成===END"

app_dir_path=$(find "$tmp_dir_path/Payload" -type d -name "*.app" | sort | head -n 1)
if [ -z "$app_dir_path" ]; then
  echo "No .app bundle found in obfuscated ipa"
  exit 1
fi

app_dir_name=$(basename "$app_dir_path")
app_info_plist="${tmp_dir_path}/Payload/${app_dir_name}/Info.plist"
if [ ! -f "$app_info_plist" ]; then
  echo "Info.plist not found in obfuscated ipa: $app_info_plist"
  exit 1
fi

app_dir_basename=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$app_info_plist")

echo "app包名字: ${app_dir_name}"
echo "可执行文件名称: ${app_dir_basename}"

echo "开始替换加固包>>>BEGIN"
cp -rf "${tmp_dir_path}/Payload/${app_dir_name}" "${xcarchive_file_path}/Products/Applications/"

if [ -d "${tmp_dir_path}/SwiftSupport" ]; then
  cp -rf "${tmp_dir_path}/SwiftSupport" "${xcarchive_file_path}"
fi

if [ -d "${tmp_dir_path}/Symbols" ]; then
  cp -rf "${tmp_dir_path}/Symbols" "${xcarchive_file_path}"
fi
echo "加固包替换完成===END"

echo "开始提取加固包中的dSYM符号文件>>>BEGIN"
/usr/bin/dsymutil "${xcarchive_file_path}/Products/Applications/${app_dir_name}/${app_dir_basename}" -o "${xcarchive_file_path}/dSYMs/${app_dir_name}.dSYM"
echo "提取加固包中的dSYM符号文件完成===END"

echo "开始剔除程序符号信息>>>BEGIN"
/usr/bin/strip "${xcarchive_file_path}/Products/Applications/${app_dir_name}/${app_dir_basename}"
echo "剔除程序符号信息完成===END"

echo "加固包替换完成"
