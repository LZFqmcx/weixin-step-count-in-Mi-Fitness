# 微信步数修改（通过小米运动健康）

通过 Root 权限修改「小米运动健康」App 步数，借助该 App 的微信绑定功能，将修改后的步数同步到**微信运动**。

## 原理

```
本工具修改本地小米运动健康 App 数据库
         ↓
小米运动健康自动将步数上传至小米云端
         ↓
小米运动健康绑定微信运动后同步至微信
         ↓
微信运动步数更新 ✓
```

小米运动健康（`com.mi.health`）将步数存储在 `fitness_data` 库的 `step_record` 表中。本工具通过 Root 权限直接写入该表并标记为待同步（`isUpload=0`），App 随后会自动将数据上传至小米云端，最终通过微信绑定同步到微信运动。

## 前置条件

- **一台已 Root 的 Android 手机**（推荐 Magisk）
- **Windows 电脑**：安装 [Android platform-tools](https://developer.android.com/tools/releases/platform-tools)（包含 adb.exe）
- **Python 3.x**：用于运行桌面图形界面客户端
- 手机上已安装**小米运动健康** App，并已**绑定微信运动**（在 App 设置中绑定）

## 文件说明

| 文件 | 用途 |
|------|------|
| `step_tool.py` | Windows 图形界面客户端 |
| `启动工具.bat` | 一键启动桌面客户端 |
| `小米运动健康步数修改.sh` | Android 端脚本（需要推送到手机） |
| `查看步数修改记录.sh` | Android 端查看脚本（推送到手机） |

## 快速开始

### 1. 推送脚本到手机

连接已 Root 的手机，开启 USB 调试：

```bash
adb root
adb push "小米运动健康步数修改.sh" /sdcard/stepmod.sh
adb push "查看步数修改记录.sh" /sdcard/viewlog.sh
```

> 如果手机 Magisk 弹出 Root 授权提示，请允许。

### 2. 启动桌面工具

双击 `启动工具.bat`，或命令行运行：

```bash
python step_tool.py
```

### 3. 修改步数

在图形界面中操作：

- **增加**：在今日步数基础上追加指定步数
- **减少**：在今日步数基础上减少指定步数
- **指定**：覆盖今日步数
- **清零**：删除今日所有步数记录

### 4. 同步到微信运动

1. 保持手机联网
2. 打开「小米运动健康」App
3. 等待数据同步（通常几秒内自动完成）
4. 打开「微信运动」查看步数已更新

如果未自动同步，可在小米运动健康 App 中下拉刷新，或在微信运动中手动刷新排行榜。

## 命令行用法

也可不依赖桌面客户端，直接通过 ADB 执行：

```bash
adb shell sh /sdcard/stepmod.sh add 10000    # 增加 10000 步
adb shell sh /sdcard/stepmod.sh set 20000    # 指定为 20000 步
adb shell sh /sdcard/stepmod.sh clear        # 清零
adb shell sh /sdcard/stepmod.sh view         # 查看详情
```

## 数据流向

```
[脚本修改数据库] → [小米运动健康] → [小米云端] → [微信运动]
     isUpload=0       自动上传         云端同步      绑定后同步
```

## 注意事项

- **必须 Root**，且在 Magisk 中授予 ADB shell Root 权限
- 修改前执行 `adb root` 使 adbd 以 root 模式运行
- 修改后如果步数未变化，杀掉小米运动健康进程重开
- 支持包名 `com.mi.health`、`com.xiaomi.health` 自动适配
- 不依赖具体小米设备型号，没有手环/手表也能使用

## 版本

v26.07.10
