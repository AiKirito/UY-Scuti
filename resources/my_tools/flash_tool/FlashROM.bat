@ECHO OFF
setlocal enabledelayedexpansion

REM 设置机型
set "right_device=Model_code"

set "PATH=%PATH%;%cd%\bin\windows"
set sg=1^>nul 2^>nul

for /f "tokens=2 delims=:" %%a in ('chcp') do set "locale=%%a"

:HOME
cls

if "!locale!"==" 936" (
    set "title=Fastboot 刷入工具"
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"
    set "keep_data_flash={04}[1] {01}保留全部数据并刷入{#}{#}{\n}"
    set "format_data_flash={04}[2] {01}格式化用户数据并刷入{#}{#}{\n}"
    set "select_project=请选择你要操作的项目："
    set "waiting_device={0D}————  正在等待设备  ————{#}{\n}{\n}"
    set "loaded_device=已加载设备："
    set "detected_compressed_file=检测到压缩文件，正在解压："
    set "disabled_avb_verification=已禁用 Avb2.0 校验"
    set "kept_data_reboot=已保留全部数据，准备重启！"
    set "formatting_data=正在格式化 DATA"
    set "execution_completed=执行完成，等待自动重启"
    set "retry_message=重试..."
    set "success_status=刷入成功"
    set "failure_status=刷入失败"
    set "device_mismatch_msg=此 ROM 仅适配 !right_device! ，但你的设备是 !DeviceCode!"
) else (
    set "title=Fastboot Flash Tool"
    set "one_title={F9}            Powered By {F0}Garden Of Joy            {#}{#}{\n}"
    set "keep_data_flash={04}[1]  {01}Keep all data and flash{#}{#}{\n}"
    set "format_data_flash={04}[2]  {01}Format user data and flash{#}{#}{\n}"
    set "select_project=Please select the project you want to operate:"
    set "waiting_device={0D}————  Waiting for device  ————{#}{\n}{\n}"
    set "loaded_device=Loaded device: "
    set "detected_compressed_file=Detected compressed file, decompressing: "
    set "disabled_avb_verification=Disabled Avb2.0 verification"
    set "kept_data_reboot=Kept all data, preparing to reboot！"
    set "formatting_data=Formatting DATA"
    set "execution_completed=Execution completed, waiting for automatic reboot"
    set "retry_message=Retrying..."
    set "success_status=Flash successful"
    set "failure_status=Flash failed"
    set "device_mismatch_msg=This ROM is only compatible with !right_device!, but your device is !DeviceCode!"
)

title !title!
:HOME
cls

REM 检查是否存在 .zst 文件
set "zst_exist="
for %%a in (images\*.zst) do set "zst_exist=1"
if defined zst_exist (
    for /f "delims=" %%a in ('dir /b "images\*.zst"') do (
        if exist "images\%%~nxa" (
            echo !detected_compressed_file!%%~na
            zstd --rm -d images\%%~nxa -o images\%%~na
        )
    )
	echo.
)

cho {F9}                                                {\n}
cho !one_title!
cho {F9}                                                {\n}{\n}
cho !keep_data_flash!
cho !format_data_flash!
ECHO.

set /p zyxz=!select_project!
if "!zyxz!" == "1" (
    set xz=1
    goto FLASH
) else if "!zyxz!" == "2" (
    set xz=2
    goto FLASH
)
goto HOME&pause

:FLASH
cls 

REM 显示等待设备的消息
cho !waiting_device!

REM 获取设备型号
for /f "tokens=2" %%a in ('fastboot getvar product 2^>^&1^|find "product"') do (
    set DeviceCode=%%a
)
REM 获取设备的分区类型
for /f "tokens=2" %%a in ('fastboot getvar slot-count 2^>^&1^|find "slot-count" ') do (
    set fqlx=%%a
)

REM 根据设备的分区类型设置变量 fqlx 的值
if "!fqlx!" == "2" (
    set fqlx=AB
) else (
    set fqlx=A
)

cls
ECHO.!loaded_device!!DeviceCode!
ECHO.
if not "!DeviceCode!"=="!right_device!" (
    cho !device_mismatch_msg!
    PAUSE
    GOTO :EOF
)

REM 遍历分区文件并刷入
for /f "delims=" %%b in ('dir /b images ^| findstr /v /i "super.img" ^| findstr /v /i "preloader_raw.img" ^| findstr /v /i "cust.img" ^| findstr /v /i "recovery.img" ^| findstr /v /i /b "vbmeta"') do (
    set "filename=%%~nb"
    if "!fqlx!"=="A" (
        set "retry=0"
        :retryA
        "fastboot" flash %%~nb images\%%~nxb
        if "!errorlevel!"=="0" (
            echo !filename!: !success_status!
            echo.
        ) else (
            echo !filename!: !failure_status!
            if "!retry!"=="0" (
                set "retry=1"
                echo !retry_message!
                goto retryA
            )
        )
    ) else (
        set "retry=0"
        :retryA
        "fastboot" flash %%~nb_a images\%%~nxb
        if "!errorlevel!"=="0" (
            echo !filename!_a: !success_status!
        ) else (
            echo !filename!_a: !failure_status!
            if "!retry!"=="0" (
                set "retry=1"
                echo !retry_message!
                goto retryA
            )
        )
        set "retry=0"
        :retryB
        "fastboot" flash %%~nb_b images\%%~nxb
        if "!errorlevel!"=="0" (
            echo !filename!_b: !success_status!
            echo.
        ) else (
            echo !filename!_b: !failure_status!
            if "!retry!"=="0" (
                set "retry=1"
                echo !retry_message!
                goto retryB
            )
        )
    )
)

REM MTK 机型专属
if exist images\preloader_raw.img (
    	fastboot flash preloader_a images\preloader_raw.img !sg!
    	fastboot flash preloader_b images\preloader_raw.img !sg!
    	fastboot flash preloader1 images\preloader_raw.img !sg!
    	fastboot flash preloader2 images\preloader_raw.img !sg!
	echo.
)
REM 对特定分区文件专门刷入
set "count=0"
for /R images\ %%i in (*.img) do (
	echo %%~ni | findstr /B "vbmeta" >nul && (
		fastboot --disable-verity --disable-verification flash %%~ni_a %%i
		fastboot --disable-verity --disable-verification flash %%~ni_b %%i
		set /a "count+=1"
	)
)
if !count! gtr 0 (
	echo !disabled_avb_verification!
	echo.
)

if exist images\cust.img (
	fastboot flash cust images\cust.img
	echo.
)
if exist images\super.img (
    	fastboot flash super images\super.img
	echo.
)

if "!xz!" == "1" (
    echo !kept_data_reboot!
) else if "!xz!" == "2" (
    echo !formatting_data!
    fastboot erase userdata
    fastboot erase metadata
)

if "!fqlx!" == "AB" (
    fastboot set_active a %sg%
)

fastboot reboot
echo.
echo !execution_completed!
pause
exit
