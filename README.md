# 盾牌座 UY 
**| [English](README_EN.md) | 简体中文 |**

该工具的目的是为了解决解包，打包，修改 img 麻烦的问题\
使用该工具在 WSL 和 Ubuntu 测试均可使用，安装所需要的包：

**sudo apt update** \
**sudo apt install lz4 python3 openjdk-21-jdk device-tree-compiler**


其它 Linux 内核系统待测试，推测都能正常工作，为工具给予权限：

**chmod 777 -R ./***

然后即可启动工具，只需输入：

**./start.sh**

**该工具仅支援 img 格式的分区文件、常规的 ZIP 刷入包、三星的 TAR 刷入包、lz4 文件提取以及 payload.bin 的提取，老版本的其它格式的分区文件不支援，也不会支援\
首次使用该工具，你一定要仔细阅读下面的说明，如果你不仔细阅读而提出在说明中有表述的内容，我会无视**

----

主菜单

> 选择工作域：选中一个工作域，选中后，后续的操作都将基于该工作域的路径

>建立工作域：建立一个工作域，任意命名，允许空格和中文，工作域的作用是限制使用范围

> 删除工作域：删除一个工作域

> 更改语言设置：支持简体中文与英文切换

> 退出程序

----

工作域菜单

> 分区文件提取：支持 EROFS、EXT、F2FS、VBMETA、DTBO、BOOT、PAYLOAD、SUPER、SPARSE、TAR、ZIP、LZ4 标识的文件提取。按 ALL 即可提取所有，按 S 即可启动简易识别，简易识别的作用在通常情况下自动识别 super 和它的子分区。如果是三星 Rom，还会识别 optics.img 和 vbmeta 文件，这取决于工作域目录下是否有 optics.img 存在，提取分区文件列表只会展示可识别的分区，如果你发现你放入的分区文件不显示，说明工具不支持该分区文件的识别，之所以要这样实现，是因为不支持的文件显示在列表上毫无意义，支持小米与一加的 super 识别。

> 分区文件打包：打包提取后的分区文件，如果原本标识是 EROFS、EXT、F2FS，则打包后需要选择打包的格式，可选 EROFS、EXT、F2FS 打包格式，原本标识为支持格式中的其它，则无需选择，自动识别

> SUPER 分区打包：首先要自行将打包的子分区文件放置到工作域目录的 Extracted-files/super 文件夹，然后使用该功能，动态分区类型要保持与原来的一致，假设你的机型是 VAB 动态分区，打包也得是 VAB 动态分区，而是否选择稀疏格式，这个可能取决于 ROM 是否支持，例如一加的官方系统，使用稀疏格式镜像会导致识别问题

> 一键修改：内置了 HyperOS, OneUI 的快速修改方案，对 HyperOS 支持内容较多，在 MIUI 14 及之后的版本修改是没有任何问题的，不支持老版本，老版本牵涉到卡米问题，如果仍然想修改，自行解决卡米代码的问题

> 构建刷机包：支持分卷与完整包压缩，大小自定义，机型代码需要严格遵守你的使用的机型，避免冲突，而默认打包名与工作域名称一致，本刷机包为线刷包，脚本默认禁用 AVB2.0 校验，因此无需额外修改

> 返回主菜单

> 退出程序

<br>
<br>
<br>
<br>
<br>
<br>

## HyperOS 修改教程（测试通过）
1. 创建并选中一个工作域：创建一个新的工作域并立即选中它。
2. 将 Rom 包或者分区文件移动到工作域目录当中，这里如果是 Rom 包最终会提取到分区文件。
3. 使用简易识别自动筛选出 SUPER 子分区，然后再使用全部提取。
4. 使用一键修改，需要修改什么，自己看提示使用。
5. 打包所有提取的分区文件，打包的文件系统取决于你的内核。
6. 将打包的子分区移动到选中工作域 Extracted-files/super 里面。
7. 使用 SUPER 打包功能，保证打包的动态分区与你的设备一致，大小会自动计算，根据提示来选择。
8. 将打包好的 SUPER 分区移动到选中工作域的 Ready-to-flash/images 目录，注意“简易识别”已自动将其它分区移动到这！
9. 使用 Fastboot(d) 打包功能，这样一个修改的 ROM 制作完成。

## OneUI 修改教程（未测试）
1. 创建并选中一个工作域：创建一个新的工作域并立即选中它。
2. 将 Rom 包或者分区文件移动到工作域目录当中，这里如果是 Rom 包最终会提取到分区文件。
3. 使用简易识别：自动筛选出 `SUPER` 子分区，然后再使用全部提取。
4. 使用一键修改：需要修改什么，自己看提示使用，对于三星，移除 vbmeta 验证是必要的。
5. 打包所有提取的分区文件：打包的文件系统取决于你的内核。
6. 将打包的子分区移动到选中工作域 Extracted-files/super 里面。
7. 使用 SUPER 打包功能：对于三星设备，打包的 SUPER 分区文件必须保持和官方大小一致。
8. 将打包好的 SUPER 分区移动到选中工作域的 Ready-to-flash/images 目录，注意“简易识别”已自动将其它分区移动到这！
9. 使用 Odin Rom 打包功能：这样一个修改的三星 ROM 制作完成，但是能不能开机需要测试。

<br><br><br>

---

# 感谢 

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - 魔数参考。
2. [**ext4**](https://github.com/cubinator/ext4) 和 [**extfstools**](https://github.com/nlitsme/extfstools) - ext 镜像配置文件和文件提取。
3. [**android-tools**](https://github.com/nmeum/android-tools) - 提供了丰富的 Android 工具集。
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - vbmeta、boot、vendor_boot 的提取与打包。
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - f2fs 文件提取。
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - payload.bin 文件提取。
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-extract) - erofs 文件提取。
8. [**7zip**](https://github.com/ip7z/7zip/releases) - super 分区提取及 Rom 包打包。
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - 反编译。
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - 三星 CSC 编码与解码。
