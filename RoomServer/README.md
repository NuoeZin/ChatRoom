# ChatRoom 聊天室服务器

与 GameMaker 客户端完全兼容的局域网聊天室服务端。`RoomServer` 同时提供 Java 版与 Python 版，并自带精简 Java 运行时。

## 目录结构

```
RoomServer/
  README.md
  start_java.bat        # 启动 Java 版
  start_python.bat      # 启动 Python 版
  selftest_java.bat     # Java 版自检

  Runtime/              # jlink 生成的精简 Java 运行时（java.base）

  java/
    Server.java
    SelfTest.java
    Server.class
    Server$Client.class
    SelfTest.class

  python/
    server.py
    selftest.py
    config.json
    wheattalk/
      __init__.py
      config.py         # 配置加载与校验
      protocol.py       # 10000 字节定长帧、消息解析
      server.py         # 服务器核心
      cli.py            # 命令行参数与启动流程
```

## 客户端界面

- 房间卡片只有右侧「连接」按钮可以加入房间。
- 房间卡片按名称的拼音/字母升序从上到下排列；中文使用拼音，英文按字母。
- 房间用 `IP:端口` 作为唯一标识；同一台机器上不同端口的多个房间会显示为不同卡片，连接时使用卡片上的端口。
- 每个房间启动时会生成 20 位数字/大写字母随机 ID；同名房间以 ID 区分，卡片上会显示短 ID 方便辨认。
- 字体文件和 `pinyin.txt` 放在 `datafiles/resources`，打包后输出到游戏目录的 `resources` 文件夹。
- 左上角返回按钮右侧有单图标刷新按钮；客户端每 20 秒自动刷新一次列表。
  刷新会重新启动房间列表（清空旧卡片并重新发现）；手动刷新和自动刷新都执行同样的重建。
- 点击超过 3 秒没有收到广播的卡片会被拒绝，避免进入已经关闭的房间。
- 中文（含繁体）和英文使用 `Minecraft.ttf`，其他语言的字母使用 `simhei.ttf`。
- 点击「连接」后先弹出昵称输入框（带「确定」「取消」）；确认昵称后会先做一次 TCP 连通性检测，
  3 秒内没有响应或连接失败则拒绝加入，并保留昵称供重试。
- 房间列表右上角是「手动连接」按钮；点击后用游戏内弹窗输入 IP/端口，再输入昵称。左上角是返回主界面的图标按钮。
- 聊天界面左上角是返回房间列表的图标按钮。
- 聊天界面左上角标题显示「房间名（自己的昵称）」；右上角三点按钮打开房间与个人信息弹窗。
- 输入框右侧有「发送」按钮；发送消息后输入框保持聚焦，光标继续闪烁，可直接继续输入。
- 房间列表与服务器成员列表支持鼠标滚轮，界面不再显示滚轮操作提示。
- 房间名和昵称都不能为空；仅输入空格也会被拒绝。
- 主界面右上角三点按钮打开关于对话框：显示 GitHub 仓库链接（单击复制到剪贴板）和内嵌的 my_drink 图片。

## Java 版

无需安装 Java：`Runtime` 已包含运行服务端所需的最小运行时。

```bat
cd F:\CodexWork\LocalChatRoom\RoomServer
start_java.bat
```

运行后会提示输入房间名。也可以带参数启动：

```bat
start_java.bat -n MyRoom -p 6510 -b 6511 -i 1.0
```

> 中文房间名建议使用交互输入（直接运行 `start_java.bat`）。

### 参数

| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `--name` | `-n` | 交互输入 | 聊天室名称 |
| `--port` | `-p` | 6510 | TCP 监听端口 |
| `--broadcast-port` | `-b` | 6511 | UDP 广播端口 |
| `--interval` | `-i` | 1.0 | 发现广播间隔（秒） |

### 编码说明（重要）

- `Server.java` 使用 UTF-8 编码。
- **不要在中文 Windows 上直接运行 `java Server.java`**：JDK 17 的源码模式会按系统编码（GBK）读取 UTF-8 源码，导致「请输入聊天室名称」变成「璇疯緭鍏ヨ亰澶╁鍚嶇О」。
- `start_java.bat` 运行的是用 `javac -encoding UTF-8` 预编译好的 `Server.class`，不会出现该乱码。
- 修改 Java 源码后，请重新编译：

```bat
cd java
javac -encoding UTF-8 Server.java SelfTest.java
```

### 自检

```bat
selftest_java.bat
```

脚本会优先用系统 `javac` 以 UTF-8 重新编译，再使用 `Runtime` 运行自检。

覆盖内容：空昵称拒绝、昵称注册、加入/离开通知、聊天转发、UDP 发现广播。

## Python 版

要求：Python 3.7+，仅使用标准库。

```bat
cd F:\CodexWork\LocalChatRoom\RoomServer
start_python.bat
```

### 配置文件

配置位于 `python/config.json`：

```json
{
  "room_name": "ChatRoom 聊天室",
  "port": 6510,
  "broadcast_port": 6511,
  "interval": 1.0,
  "max_users": 0
}
```

| 字段 | 说明 |
|------|------|
| `room_name` | 房间名称 |
| `port` | TCP 监听端口 |
| `broadcast_port` | UDP 广播端口 |
| `interval` | 发现广播间隔（秒） |
| `max_users` | 人数上限，0 表示不限制 |

命令行参数可以临时覆盖配置：

```bat
start_python.bat --name 测试房间 --max-users 8
start_python.bat --config D:\my_config.json
```

人数达到 `max_users` 后，新连接会在接入阶段被拒绝；`0` 表示无限制。

### Python 自检

```bat
cd python
python selftest.py
```

## 客户端连接

- **局域网用户**：客户端 → 加入 → 点击房间卡片右侧「连接」→ 输入昵称 → 确定。
- **本机用户**：客户端 → 加入 → 点击右上角「手动连接」→ 输入 `localhost`、`127.0.0.1` 或 `127.0.0.1:7000` → 输入昵称。
- **返回**：房间列表左上角返回主界面；聊天界面左上角返回房间列表。

## 协议说明

### 端口

| 端口 | 协议 | 用途 |
|------|------|------|
| 6510 | TCP | 客户端连接与消息收发 |
| 6511 | UDP | 局域网房间发现广播 |

### 消息格式

所有字符串均为 UTF-8 编码并以 `\0` 结尾。GameMaker 客户端每次收发使用 10000 字节定长帧，
服务器端按空终止符解析并忽略零填充，发送时同样使用 10000 字节定长帧。

| 类型 | 格式 | 方向 |
|------|------|------|
| 昵称注册 | `&name=<昵称>` | 客户端 → 服务器 |
| 聊天消息 | `<昵称>:<消息内容>` | 客户端 → 服务器 → 全体 |
| 加入通知 | `&coly=<昵称>已加入` | 服务器 → 全体（含加入者） |
| 离开通知 | `&coly=<昵称>已离开` | 服务器 → 剩余成员 |
| 发现广播 | `&sern=<房间名>\|<在线人数>\|<TCP端口>\|<房间ID>` | 服务器 → 局域网（UDP 6511） |

发现广播默认每秒一次；成员加入或离开时会立即补发一次，使客户端房间列表的人数快速刷新。

昵称超过 15 个字符时截断为前 12 个字符加 `...`，与 GameMaker 内置服务端保持一致。

## 防火墙

若客户端发现不了服务器，请检查 Windows 防火墙是否放行：

- **TCP 入站** 端口 6510
- **UDP 入站** 端口 6511

首次运行 Java / Python 版时 Windows 可能弹出防火墙提示，请允许访问专用网络。

## 与 GameMaker 内置服务端的关系

`obj_server` 与 `RoomServer` 功能一致，**不能同时运行**（会占用相同的 6510/6511 端口）。
选择其中一种作为房间主机即可。
