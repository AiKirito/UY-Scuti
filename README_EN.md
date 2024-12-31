
# UY Scuti
**| [English](README_EN.md) | Simplified Chinese |**

The purpose of this tool is to solve the issues with unpacking, repacking, and modifying IMG files.  
This tool has been tested on WSL2 and Ubuntu, and it works fine. The required packages for installation are:

**sudo apt update**  
**sudo apt install lz4 python3 openjdk-21-jdk device-tree-compiler**

Other Linux-based systems are yet to be tested, but they should work fine. To grant permissions for the tool, run:

**chmod 777 -R ./**

Then, to start the tool, simply enter:

**./start.sh**

**This tool only supports IMG partition files, standard ZIP flashable packages, Samsung TAR flashable packages, LZ4 file extraction, and payload.bin extraction. Older versions and other partition formats are not supported and will not be supported.**

If you are using this tool for the first time, please make sure to read the instructions below carefully. Any issues already addressed in the documentation will be ignored.

---

## Main Menu

- **Choose Work Domain**: Select a work domain. After selection, all subsequent operations will be based on this directory.
  
- **Create Work Domain**: Create a new work domain with any name (spaces and Chinese characters are allowed). The work domain limits the scope of your operations.
  
- **Delete Work Domain**: Delete an existing work domain.
  
- **Change Language Setting**: Toggle between Simplified Chinese and English.
  
- **Exit Program**: Exit the tool.

---

## Work Domain Menu

- **Extract Partition Files**: Supports extraction of EROFS, EXT, F2FS, VBMETA, DTBO, BOOT, PAYLOAD, SUPER, SPARSE, TAR, ZIP, and LZ4 files. Select `ALL` to extract all partitions, or `S` for simple recognition mode. The simple mode automatically recognizes SUPER and its sub-partitions. For Samsung ROMs, it also recognizes optics.img and vbmeta files, depending on the presence of optics.img in the work domain directory. Only supported partitions will be displayed in the extraction list. If a partition file is not shown, the tool does not support it. The tool supports SUPER partition recognition for Xiaomi and OnePlus ROMs.
  
- **Repack Partition Files**: Repack the extracted partition files. If the original partition was EROFS, EXT, or F2FS, you will need to select the target file format (EROFS, EXT, or F2FS). For other formats, the tool automatically detects the appropriate format.

- **Repack SUPER Partition**: If you have extracted sub-partitions and placed them into the `Extracted-files/super` folder in the work domain directory (note: this happens automatically if you repack SUPER partitions), use this function to repack them. Ensure that the dynamic partition type matches your device's partition scheme. Whether to use sparse format depends on the ROM’s support.

- **One-Click Modification**: Built-in quick modification solutions for HyperOS and OneUI.

- **Build Flashable Package**: Quickly move repacked partitions to the `Ready-to-flash/images` directory using the new "Easy Move" feature. Supports both multi-part and full package compression, with custom size. The device code must match your device to avoid conflicts. The default package name will match the work domain name. The flash package is designed for line flashing and the script disables AVB2.0 verification by default, so no additional modifications are needed.

- **Return to Main Menu**: Return to the main menu.

- **Exit Program**: Exit the tool.

---

---

## One-Click Modification Overview (Key Features)

1. **HyperOS / ONEUI Replacement**  
   - Description: This feature allows you to replace any file or folder in the system partition. To use it, locate the `resources/my_tools/nice_rom/bin/samsun(xiaomi)/replace` directory and follow these steps:
     - Suppose you have extracted a file from the system partition (for example, named `1`).
     - Place this file (or folder) in the `replace` directory.
     - After using this feature, the file (or folder) named `1` in the `replace` directory will replace the corresponding file (or folder) in the system partition.
     - **Note**: The `1` file is just an example—you can replace any file or folder, not just the one in the example.

2. **HyperOS / ONEUI Additions**  
   - Description: This feature allows you to add APK files to a specified directory in the partition. Depending on the system you are using, the operation is as follows:
   
   **HyperOS Add to Product Partition**  
   - Path: `resources/my_tools/nice_rom/bin/xiaomi/add_for_product`
   - Inside this directory, there are subdirectories such as `app`, `data-app`, and `priv-app`.
   - You can place your APK files into any of these subdirectories by following the naming rules:
     - For example, if you want to add `1.apk` to the `product/app` directory:
       - Create a directory at `resources/my_tools/nice_rom/bin/xiaomi/add_for_product/app/file_locked_1`.
       - Place `Only_1.apk` in the `file_locked_1` directory.
     - This will add the APK to the target directory.
     - **Note**: This feature only works for the Product partition, and APKs placed in the `data-app` directory are uninstallable.

   **ONEUI Add to System Partition**  
   - The process is the same as for HyperOS, but this feature applies to the System partition for Samsung devices.
   - For Samsung devices, uninstallable APKs will be placed in the `preload` directory.

3. **ONEUI Feature Addition**  
   - Description: This feature requires extracting the `optics.img` partition content first.
   - Operation: It automatically decodes the CSC (Customer Service Code) file to add various features specific to Samsung's ONEUI.
   - Path: `resources/my_tools/nice_rom/bin/samsung/csc_add/csc_features_need`
   - Place the features you want to add into this directory.

---

---

## HyperOS Modification Guide (Tested)

1. Create a new work domain and select it immediately.
2. Move the ROM or partition files into the work domain directory and extract them once.
3. Use "Simple Recognition" to automatically filter the SUPER sub-partition. Before using this feature, ensure that all IMG files are extracted. Then, use the "Extract All" function to extract partition contents.
4. Use "One-Click Modification" and follow the prompts to modify the files as needed.
5. Repack all extracted partition files. The file system type for repacking depends on your kernel.
6. Move the repacked sub-partitions to the `Extracted-files/super` folder in the selected work domain.
7. Use the "SUPER Repack" function. Ensure that the dynamic partition type matches your device, and the size will be calculated automatically.
8. Move the repacked SUPER partition to the `Ready-to-flash/images` directory. "Simple Recognition" will automatically move other partitions there.
9. Use the Fastboot(d) repack function to complete the ROM modification.

## OneUI Modification Guide (Untested)

1. Create a new work domain and select it immediately.
2. Move the ROM or partition files into the work domain directory and extract them once.
3. Use "Simple Recognition" to automatically filter the SUPER sub-partition. Before using this feature, ensure all IMG files are extracted, then use "Extract All" to extract partition contents.
4. Use "One-Click Modification": Follow the prompts for modifications. For Samsung, removing the vbmeta verification is necessary.
5. Repack all extracted partition files. The file system type for repacking depends on your kernel.
6. Move the repacked sub-partitions to the `Extracted-files/super` folder in the selected work domain.
7. Use the "SUPER Repack" function. For Samsung devices, the SUPER partition must match the official size.
8. Move the repacked SUPER partition to the `Ready-to-flash/images` directory. "Simple Recognition" will automatically move other partitions there.
9. Use the Odin ROM repack function to complete the Samsung ROM modification. Whether the device boots up needs testing.

---

Certainly! Here’s the updated translation for the acknowledgements section with the new changes:

---

## Acknowledgements

1. [**TIK**](https://github.com/ColdWindScholar/TIK) - Magic number reference.
2. [**ext4**](https://github.com/cubinator/ext4) - EXT file system handling.
3. [**android-tools**](https://github.com/nmeum/android-tools) - A rich set of Android tools.
4. [**Android_boot_image_editor**](https://github.com/cfig/Android_boot_image_editor) - Extraction and repacking of `vbmeta`, `boot`, and `vendor_boot` images.
5. [**f2fsUnpack**](https://github.com/thka2016/f2fsUnpack) - F2FS file extraction.
6. [**payload-dumper-go**](https://github.com/ssut/payload-dumper-go) - Extraction of `payload.bin` files.
7. [**erofs-extract**](https://github.com/sekaiacg/erofs-utils) - EROFS file extraction.
8. [**7zip**](https://github.com/ip7z/7zip/releases) - SUPER partition extraction and ROM package repacking.
9. [**Apktool**](https://github.com/iBotPeaches/Apktool) - APK decompiling.
10. [**OmcTextDecoder**](https://github.com/fei-ke/OmcTextDecoder) - Samsung CSC encoding and decoding.

---
