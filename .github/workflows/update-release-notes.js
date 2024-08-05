const github = require('@actions/github'); 
const context = github.context; 
 
const release_id = process.env.RELEASE_ID; 
const body =  
本次更新具有许多更新，建议认真阅读 
1、修复 SUPER 分区有时候无法被正确打包的问题 
2、SUPER 额外空间调整为1G，现在提供40MB的开销（注意AB分区是双倍，即80MB的开销大小） 
3、SUPER 打包现在具有错误识别，不符合 SUPER 检测的，会被禁止打包 
4、SUPER 分区现在在首次提取时会读取大小，适用于三星（三星的检测使得 SUPER 分区必须与官方文件的大小保持一致），在打包时会打印原始大小（三星一定要使用原始大小才能确保 SUPER 分区被正确刷入） 
5、提取支持更多格式，现在支持 ZIP，TAR，LZ4 文件的提取，对 ZIP 与 TAR 具有检测，能正确提取 payload 类型刷机包与本工具打包的刷机包以及三星奥丁格式刷机包，大大简化了操作 
6、一键打包功能已调整逻辑，支持 Fastboot(d) 与三星奥丁刷机包，对于三星刷机包，你只需要放入镜像文件，工具会自动识别所属分类并打包 
7、现在 ext 与 f2fs 在 super 中总是为可写入的，确保你的内核支持 
 
This update includes many improvements, please read carefully 
1. Fixed the issue where the SUPER partition could not be correctly packaged sometimes 
2. SUPER extra space adjusted to 1G, now providing 40MB overhead (note that AB partitions are doubled, i.e., 80MB overhead) 
3. SUPER packaging now has error recognition, packaging will be prohibited if it does not meet SUPER detection 
4. SUPER partition now reads the size during the first extraction, suitable for Samsung (Samsung detection requires the SUPER partition to be the same size as the official file), the original size will be printed during packaging (Samsung must use the original size to ensure the SUPER partition is correctly flashed) 
5. Extraction supports more formats, now supports ZIP, TAR, LZ4 file extraction, with detection for ZIP and TAR, can correctly extract payload type flash packages and flash packages packaged by this tool as well as Samsung Odin format flash packages, greatly simplifying the operation 
6. One-click packaging function has been adjusted, supporting Fastboot(d) and Samsung Odin flash packages, for Samsung flash packages, you only need to put in the image files, the tool will automatically recognize the category and package 
7. Now ext and f2fs in super are always writable, ensure your kernel supports it 
; 
 
await github.rest.repos.updateRelease({ 
  owner: context.repo.owner, 
  repo: context.repo.repo, 
  release_id: release_id, 
  body: body 
});
