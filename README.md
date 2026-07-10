# 小米运动健康步数修改

通过 Root 权限直接修改「小米运动健康」App 的步数数据库，支持云端同步到同账号下的其他设备和微信步数。

## 原理

`com.mi.health` App 将步数存储在 `fitness_data` 库的 `step_record` 表中。本工具通过 Root 权限直接写入该表并标记为待同步（`isUpload=0`），App 随后会自动将数据上传至小米云端，同步到同账号下的其他设备。

## 环境要求

- **Android 手机**：已 Root（Magisk）
- **Windows 电脑**：安装 Android platform-tools（包含 adb.exe）
- **Python 3.x**：用于运行图形界面客户端

## 文件说明

| 文件 | 用途 |
|------|------|
| `step_tool.py` | Windows 图形界面客户端 |
| `启动工具.bat` | 一键启动 Python 客户端 |
| `小米运动健康步数修改.sh` | Android 端修改脚本（推送到手机） |
| `查看步数修改记录.sh` | Android 端查看脚本（推送到手机） |

## 快速开始

### 1. 推送脚本到手机

```bash
adb root
adb push "小米运动健康步数修改.sh" /sdcard/stepmod.sh
adb push "查看步数修改记录.sh" /sdcard/viewlog.sh
```

### 2. 启动桌面工具

双击 `启动工具.bat`，或终端运行：

```bash
python step_tool.py
```

### 3. 修改步数

在图形界面中选择操作并输入步数：

- **增加**：在今日步数基础上追加指定步数
- **减少**：在今日步数基础上减少指定步数
- **指定**：覆盖今日步数（先清零再写入）
- **清零**：删除今日所有步数记录

### 4. 云端同步

修改后保持手机联网，打开小米运动健康 App，步数将自动同步至：

- 同账号下的其他小米/澎湃设备
- 微信步数（已绑定微信的情况下）

## 命令行用法

也可不依赖桌面客户端，通过 ADB 直接执行：

```bash
# 增加 10000 步
adb shell sh /sdcard/stepmod.sh add 10000

# 指定步数
adb shell sh /sdcard/stepmod.sh set 20000

# 步数清零
adb shell sh /sdcard/stepmod.sh clear

# 查看今日详情
adb shell sh /sdcard/stepmod.sh view
```

## 注意事项

- 需要手机已 Root，且在弹窗中授予 ADB shell Root 权限
- 修改前先执行 `adb root` 使 adbd 以 root 权限运行
- 修改后 App 需重新读取数据库，若有缓存可杀掉 App 重开
- 支持 `com.mi.health`、`com.xiaomi.health` 等常见包名自动适配

## 版本

v26.07.10
