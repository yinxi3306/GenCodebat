# GenCodebat

在 **Windows** 上从**另一个项目目录**中随机选取源码文件，每次运行独立随机抽取**两段**各 **连续 10 行**，以**追加**方式写入 `snippets\Function.class` 与 `snippets\FunctionTest.class`（文件不存在会创建空文件）。不执行 Git 提交或推送。

> 说明：`.class` 在此处用作**文本累积容器**，并非 Java 字节码；请勿用真实编译产物覆盖后期待 JVM 加载。

## 环境要求

- Windows
- **PowerShell 5.1 或更高版本**（Windows 自带）
- 将本仓库（或至少 `random_copy_push.bat` 与 `random_copy_push.ps1`）放在你希望生成 `snippets` 的目录中

## 使用方法

### 方式一：双击 / 拖拽（推荐）

1. 准备好**源项目**的文件夹路径（例如 `D:\workspace\OtherRepo`）。
2. **拖拽**该文件夹到 `random_copy_push.bat` 上松开，或在命令行中传入路径（见方式二）。
3. 运行结束后窗口会 **暂停**，按任意键关闭；成功时会看到追加到的两个路径：`Function.class` 与 `FunctionTest.class`。

若未传入路径，脚本会打印用法并暂停，不会生成文件。

### 方式二：命令提示符（cmd）

```bat
cd /d D:\workspace\GenCodebat
random_copy_push.bat D:\workspace\OtherRepo
```

### 方式三：直接调用 PowerShell

在**脚本所在目录**执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\random_copy_push.ps1 -SourceRoot "D:\workspace\OtherRepo"
```

`-SourceRoot` 必须是**已存在的目录**。

## 输出说明

- **目录**：与 `.bat` / `.ps1` 同级的 `snippets\`（不存在会自动创建）。
- **固定文件**（每次运行**在文件末尾追加**，不新建时间戳文件）：
  - `snippets\Function.class` — 第一段随机 10 行
  - `snippets\FunctionTest.class` — 第二段随机 10 行（与第一段独立随机，可能来自同一源文件的不同位置）
- **每次追加的块格式**（UTF-8，无 BOM）：
  - 空行 + `===== yyyyMMdd_HHmmss =====`（同一次运行两段使用同一时间戳）
  - `# source: <源文件完整路径>`
  - `# lines: <起始行>-<结束行>`
  - 空行 + 连续 10 行正文

## 抽样规则

**会扫描的扩展名：**

`.cs` `.ts` `.tsx` `.js` `.jsx` `.py` `.java` `.go` `.rs` `.md` `.txt`

**路径中若包含以下目录名则跳过整段路径下的匹配**（不进入这些目录参与随机）：

`.git` `node_modules` `bin` `obj` `dist` `build`

**其他规则：**

- 随机尝试最多 50 次，直到选中「至少 10 行」且通过简单二进制检测（如前 64KB 内无 `0x00`、文件不大于 2MB）的文本类文件。
- 文本编码：优先按 UTF-8 严格解析，失败则回退为系统默认编码。

若源目录下没有符合扩展名的文件，或始终找不到满足条件的 10 行文本，脚本会报错并以非零退出码结束。

## 退出码（`random_copy_push.ps1`）

| 码 | 含义 |
|----|------|
| 0 | 成功 |
| 2 | `SourceRoot` 不是目录 |
| 5 | 源目录下没有匹配的候选文件 |
| 6 | 为第一段或第二段抽样时，多次尝试后仍找不到至少 10 行的合适文件 |

## 测试示例数据

仓库中的 `_smoke_src\sample.txt` 可用于本地试跑：

```bat
random_copy_push.bat D:\workspace\GenCodebat\_smoke_src
```

（请按你本机实际路径修改。）

## 许可与合规

从其他项目复制代码时，请确保你有权使用该源码，并遵守对方许可证。本工具仅做技术抽样，不提供法律判断。

## 文件说明

| 文件 | 作用 |
|------|------|
| `random_copy_push.bat` | 校验参数、调用 PowerShell、结束时 `pause` 便于双击查看输出 |
| `random_copy_push.ps1` | 随机选文件、增量追加到 `snippets\Function.class` 与 `FunctionTest.class` |

> 历史原因脚本名仍含 `push`，当前版本**不会**执行 `git commit` / `git push`。
