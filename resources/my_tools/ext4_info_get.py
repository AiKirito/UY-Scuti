#!/usr/bin/env python3

import os
import sys
import ext4
import re
import struct
import argparse
from collections import Counter

def get_most_common_context(context_file_path):
    # 创建一个 Counter 对象来存储每种上下文的出现次数
    context_counter = Counter()

    # 打开上下文文件
    with open(context_file_path, 'r') as f:
        # 遍历文件的每一行
        for line in f:
            # 分割每一行以获取上下文
            _, context = line.strip().split(' ', 1)
            # 只获取空格右边的第一个内容
            context = context.split()[0]
            # 更新上下文的出现次数
            context_counter[context] += 1

    # 获取出现次数最多的上下文
    most_common_context, _ = context_counter.most_common(1)[0]

    return most_common_context

# 创建一个解析器
parser = argparse.ArgumentParser(description='处理 ext4 镜像文件并生成配置文件。')
parser.add_argument('image_path', type=str, help='ext4 镜像文件的路径')
parser.add_argument('output_dir', type=str, help='输出文件的目录')

# 解析命令行参数
if len(sys.argv) < 3:
    parser.print_help(sys.stderr)
    sys.exit(1)

args = parser.parse_args()

# 从命令行参数中获取 ext4 镜像文件的路径和输出文件的目录
image_path = args.image_path
output_dir = args.output_dir

# 获取文件名作为前缀
prefix = os.path.basename(image_path).split('.')[0]

# 为输出文件生成一个唯一的文件名
config_output_path = os.path.join(output_dir, f"{prefix}_fs_config")
context_output_path = os.path.join(output_dir, f"{prefix}_file_contexts")

# 打开 ext4 镜像文件
f = open(image_path, "rb")

# 创建一个 Volume 对象
volume = ext4.Volume(f)

# 创建一个空的字典来存储 file_contexts 信息
file_contexts = {}

# 创建一个空的列表来存储 fs_config 信息
fs_config = []

# 创建一个栈来保存待处理的目录
stack = [(volume.root, "")]

# 创建一个集合来保存已经访问过的路径
visited = set()

while stack:
    inode, path = stack.pop()

    # 检查路径是否已经访问过
    if path in visited:
        continue

    # 将路径添加到已访问集合
    visited.add(path)

    # 检查 inode 是否是目录
    if inode.is_dir:  # 使用 inode.is_dir 来获取是否是目录的信息
        # 遍历这个 inode 的所有目录项
        for entry in inode.open_dir():
            # 忽略名称为 "." 或 ".." 的目录项
            if entry[0] in [".", ".."]:
                continue

            # 获取这个目录项的完整路径
            if path == "/":
                full_path = path + entry[0]   # 使用 entry[0] 来获取文件名
            else:
                full_path = path + "/" + entry[0]

            # 获取这个目录项的 inode 对象
            sub_inode = volume.get_inode(entry[1], entry[2])  # 使用 entry[1] 和 entry[2] 来获取 inode

            # 检查这个目录项是否是符号链接
            if sub_inode.inode.i_links_count == 0:
                # 获取符号链接指向的路径
                link_target = sub_inode.read().decode('utf-8')
                # 将这个路径添加到处理栈中
                stack.append((volume.get_inode_by_path(link_target), full_path + '/' + link_target))
            else:
                # 获取文件或目录的信息
                owner = sub_inode.inode.i_uid
                group = sub_inode.inode.i_gid
                mode = sub_inode.inode.i_mode & 0o777  # 只保留权限位
                capabilities = None  # 假设没有特殊的能力

                # 获取这个目录项的 SELinux
                for xattr in sub_inode.xattrs():  # 使用 sub_inode.xattrs() 来获取所有的扩展属性
                    if xattr[0] == "security.selinux":
                        # 将这个文件的 SELinux 存储到字典中
                        file_contexts[full_path] = xattr[1]
                    elif xattr[0] == "security.capability":
                        # 将这个文件的特殊能力存储到字典中
                        r = struct.unpack('<5I', xattr[1])
                        if r[1] > 65535:
                            cap = hex(int(f'{r[3]:04x}{r[1]:04x}', 16)).upper()
                        else:
                            cap = hex(int(f'{r[3]:04x}{r[2]:04x}{r[1]:04x}', 16)).upper()
                        capabilities = f"capabilities={cap}"

                # 将信息添加到 fs_config 列表中
                fs_config.append((full_path, owner, group, mode, capabilities))

                # 如果这个目录项是一个目录，将它添加到栈中以便后续处理
                if sub_inode.is_dir:
                    stack.append((sub_inode, full_path))
                    for sub_entry in sub_inode.open_dir():
                        if sub_entry[0] not in ['.', '..']:
                            sub_sub_inode = volume.get_inode(sub_entry[1], sub_entry[2])  # 获取子目录的 inode
                            stack.append((sub_sub_inode, full_path + '/' + sub_entry[0]))  # 将子目录添加到栈中

# 检查 output_dir 是否存在，如果不存在，就创建它
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# 将 file_contexts 信息输出到一个文本文件中
with open(context_output_path, "w") as f:
    for path, context in file_contexts.items():
        escaped_path = re.escape(path)  # 对路径中的特殊字符进行转义
        f.write(f"/{prefix}{escaped_path} {context.decode('utf8', errors='replace')}\n")

# 将 fs_config 信息输出到一个文本文件中
with open(config_output_path, "w") as f:
    for path, owner, group, mode, capabilities in fs_config:
        if capabilities is not None:
            f.write(f"{prefix}{path} {owner} {group} 0{mode:o} {capabilities}\n")
        else:
            f.write(f"{prefix}{path} {owner} {group} 0{mode:o}\n")

# 获取出现次数最多的上下文
most_common_context = get_most_common_context(context_output_path)

with open(context_output_path, 'r') as f:
    lines = f.readlines()

# 在列表的开始处添加一行，表示根目录/的上下文
lines.insert(0, f"/ {most_common_context}\n")
lines.insert(1, f"/{prefix} {most_common_context}\n")
lines.insert(2, f"/{prefix}/ {most_common_context}\n")

# 将修改后的列表写回到上下文文件中
with open(context_output_path, 'w') as f:
    f.writelines(lines)

with open(config_output_path, 'r') as f:
    lines = f.readlines()

# 在列表的开始处添加新的行
lines.insert(0, f"/ 0 0 0755\n")
lines.insert(1, f"/{prefix} 0 0 0755\n")
lines.insert(2, f"/{prefix}/ 0 0 0755\n")

# 将修改后的列表写回到配置文件中
with open(config_output_path, 'w') as f:
    f.writelines(lines)

# 在所有操作完成后关闭文件
f.close()
