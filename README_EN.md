# UY Sct
**| English | [Simplified Chinese](README.md) |**

This tool is designed to solve the problems of unpacking, packing, and modifying img files. It has been tested and can be used on WSL and Ubuntu. Other Linux kernel systems are pending testing, but it is expected that they can all work normally. To give the tool permissions, use:

**CHMOD 777 -R ./*** 

Then you can start the tool by simply entering:

**./start.sh**

**Please note that this tool requires the installation of some packages. The tool will automatically detect and inform you. Install the missing packages according to the prompts to run normally. This tool only supports img format partition files and the extraction of payload.bin in card flash package files. Older versions of other formats of partition files are not supported and will not be supported. The first time you use this tool, you must read the following instructions carefully. If you ask questions that are stated in the instructions without careful reading, I will ignore them.**

----

Main Menu

> Select Workspace: Select a workspace. After selection, subsequent operations will be based on the path of this workspace.

> Create Workspace: Create a workspace. You can name it anything, allowing spaces and Chinese characters. The purpose of the workspace is to limit the scope of use.

> Delete Workspace: Delete a workspace.

> Change Language Settings: Supports switching between Simplified Chinese and English.

> Exit Program

----

Workspace Menu

> Partition File Extraction: Supports the extraction of files with EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE partition identifiers (special reminder, the file identifiers of Recovery.img and Boot.img are both BOOT, so they can both be extracted). Press ALL to extract all, press S to start simple recognition. The function of simple recognition is to automatically recognize the sub-partitions of the SUPER partition file for modification. The list of extracted partition files will only display recognizable partitions. If you find that the partition file you put in is not displayed, it means that the tool does not support the recognition of this partition file. The reason for this implementation is that unsupported files are meaningless to display on the list. At present, simple recognition supports standard SUPER sub-partition recognition, as well as Xiaomi Qualcomm, Xiaomi MTK, OnePlus, etc. If your model has other special SUPER structures, feedback to me, or add it yourself.

> Partition File Packaging: Package the extracted partition files. If the original identifier is EROFS, EXT, F2FS, then you need to choose the packaging format after packaging, you can choose EROFS, EXT4 packaging format, the original identifier is other supported formats, no need to choose, automatic recognition.

> SUPER Partition Packaging: First, you need to manually place the packaged sub-partition files in the Extracted-files/super folder of the workspace directory, and then use this function. The dynamic partition type should be consistent with the original. Suppose your model is a VAB dynamic partition, the packaging must also be a VAB dynamic partition. Whether to choose the sparse format may depend on whether the ROM supports it. For example, the official system of OnePlus, using the sparse format image will cause recognition problems.

> One-click Modification: Built-in HyperOS, OneUI quick modification scheme, supports more content for HyperOS, there is no problem in modifying MIUI 14 and later versions, does not support old versions, old versions involve card rice problems, if you still want to modify, solve the card rice code problem yourself.

> Build Flash Package: Supports volume and full package compression, size customization, model code needs to strictly comply with your use of the model to avoid conflicts, and the default package name is consistent with the workspace name, this flash package is a line flash package, the script defaults to disable AVB2.0 verification, so no additional modification is required.

> Return to Main Menu

> Exit Program

----

## How to use UY Sct to complete a simple modification of a ROM (here is an example of HyperOS)?
1. Create a workspace, the name allows Chinese English spaces and symbols allowed by Windows Explorer.
2. Select the workspace.
3. Move the img or payload.bin file to the created workspace directory, and then use the extraction function.
4. Use simple recognition to automatically filter out SUPER sub-partitions, and then use all extractions.
5. Use one-click modification, what needs to be modified, see the prompt for use.
6. Package all extracted partition files, use all packages, whether to package EROFS or EXT4 depends on your kernel.
7. Move the packaged sub-partition to the Extracted-files/super inside the selected workspace.
8. Use the SUPER packaging function, ensure that the packaged dynamic partition is consistent with your device, the size will be automatically calculated, choose according to the prompt.
9. Move the packaged SUPER partition to the Ready-to-flash/images directory of the selected workspace. Note that "simple recognition" has automatically moved other partitions to this!
10. Use the packaging function, so a modified ROM production is completed.

----

Thanks to: \
1、 https://github.com/ColdWindScholar/TIK \
2、 https://github.com/cubinator/ext4 \
3、 https://github.com/nmeum/android-tools \
4、 https://github.com/cfig/Android_boot_image_editor
and so on......
