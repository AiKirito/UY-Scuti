# UY Sct
**| English | [Simplified Chinese](README.md) |**

This tool is designed to solve the problems of unpacking, packing, and modifying img files.\
This tool can be used for testing on both WSL and Ubuntu. Install the necessary packages with the following commands:

**sudo apt update** \
**sudo apt install lz4 python3 openjdk-21-jdk device-tree-compiler**

To give the tool permissions, use:

**chmod 777 -R ./*** 

Then you can start the tool by simply entering:

**./start.sh**

**This tool only supports partition files in img format, regular ZIP ROM, Samsung TAR ROM, lz4 file extraction and payload.bin extraction.\
It does not support old version partition files in other formats.\
The first time you use this tool, you must read the following instructions carefully.\
If you ask questions that are stated in the instructions without careful reading, I will ignore them.**

----

Main Menu

> Select Workspace: Select a workspace. After selection, subsequent operations will be based on the path of this workspace.

> Create Workspace: Create a workspace. You can name it anything, allowing spaces and Chinese characters. The purpose of the workspace is to limit the scope of use.

> Delete Workspace: Delete a workspace.

> Change Language Settings: Supports switching between Simplified Chinese and English.

> Exit Program

----

Workspace Menu

> Partition File Extraction: Supports the extraction of files identified by EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE, TAR, ZIP, and LZ4. Press ALL to extract all files, or press S to start simplified recognition. The purpose of simplified recognition is to automatically identify super and its sub-partitions under normal circumstances. For Samsung ROMs, it will also recognize optics.img and vbmeta files, depending on whether optics.img exists in the working directory. The extracted partition file list will only display recognizable partitions. If you find that the partition file you placed is not displayed, it means the tool does not support the recognition of that partition file. This implementation is because displaying unsupported files in the list is meaningless. It supports the recognition of super partitions for Xiaomi and OnePlus devices.

> Partition File Packaging: Package the extracted partition files. If the original identifier is EROFS, EXT, F2FS, then you need to choose the packaging format after packaging, you can choose EROFS, EXT, F2FS packaging format, the original identifier is other supported formats, no need to choose, automatic recognition.

> SUPER Partition Packaging: First, you need to manually place the packaged sub-partition files in the Extracted-files/super folder of the workspace directory, and then use this function. The dynamic partition type should be consistent with the original. Suppose your model is a VAB dynamic partition, the packaging must also be a VAB dynamic partition. Whether to choose the sparse format may depend on whether the ROM supports it. For example, the official system of OnePlus, using the sparse format image will cause recognition problems.

> One-click Modification: Built-in HyperOS, OneUI quick modification scheme, supports more content for HyperOS, there is no problem in modifying MIUI 14 and later versions, does not support old versions, old versions involve card rice problems, if you still want to modify, solve the card rice code problem yourself.

> Build Flash Package: Supports volume and full package compression, size customization, model code needs to strictly comply with your use of the model to avoid conflicts, and the default package name is consistent with the workspace name, this flash package is a line flash package, the script defaults to disable AVB2.0 verification, so no additional modification is required.

> Return to Main Menu

> Exit Program

----

## HyperOS Modification Tutorial (Tested)
1. **Create and select a workspace**: Create a new workspace and immediately select it.
2. Move the ROM package or partition files into the workspace directory. If it's a ROM package, it will eventually be extracted into partition files.
3. Use the simple recognition feature to automatically filter out the `SUPER` sub-partition, then use the extract all feature.
4. Use the one-click modification feature. Follow the prompts to make the necessary modifications.
5. Pack all the extracted partition files. The file system used for packing depends on your kernel.
6. Move the packed sub-partitions into the `Extracted-files/super` directory within the selected workspace.
7. Use the `SUPER` packing feature. Ensure the packed dynamic partition matches your device. The size will be automatically calculated. Follow the prompts to choose the appropriate options.
8. Move the packed `SUPER` partition into the `Ready-to-flash/images` directory within the selected workspace. Note that the simple recognition feature has already moved the other partitions here!
9. Use the `Fastboot(d)` packing feature. This completes the creation of a modified ROM.

## OneUI Modification Tutorial (Untested)
1. **Create and select a workspace**: Create a new workspace and immediately select it.
2. Move the ROM package or partition files into the workspace directory. If it's a ROM package, it will eventually be extracted into partition files.
3. Use the simple recognition feature to automatically filter out the `SUPER` sub-partition, then use the extract all feature.
4. Use the one-click modification feature. Follow the prompts to make the necessary modifications. For Samsung devices, removing vbmeta verification is necessary.
5. Pack all the extracted partition files. The file system used for packing depends on your kernel.
6. Move the packed sub-partitions into the `Extracted-files/super` directory within the selected workspace.
7. Use the `SUPER` packing feature. For Samsung devices, the packed `SUPER` partition file must match the official size.
8. Move the packed `SUPER` partition into the `Ready-to-flash/images` directory within the selected workspace. Note that the simple recognition feature has already moved the other partitions here!
9. Use the `Odin Rom` packing feature. This completes the creation of a modified Samsung ROM, but whether it can boot needs to be tested.

----

Thanks to: \
1、 https://github.com/ColdWindScholar/TIK \
2、 https://github.com/cubinator/ext4 \
3、 https://github.com/nmeum/android-tools \
4、 https://github.com/cfig/Android_boot_image_editor
and so on......
