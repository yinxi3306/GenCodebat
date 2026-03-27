# GenCodebat

## 项目介绍

GenCodebat 是一套在 **Windows** 上运行的小型工具：从**你指定的另一个项目目录**里**随机**挑选文本类源码文件，每次运行独立抽取**两段**各 **连续 10 行**，以 **UTF-8（无 BOM）追加** 的方式写入两个固定片段文件（默认文件名为 `Function.class` 与 `FunctionTest.class`）。

设计目的包括：在本地积累「从真实代码库中随机截取的片段」、配合脚本做重复抽样、或通过 `random_copy_push_and_git.bat` 在每次追加后自动提交并推送到远程。

> **关于 `.class` 后缀**：此处仅作为**文本累积容器**的文件名约定，**不是** Java 编译产生的字节码。请勿用真实 `.class` 字节码覆盖后仍期望被 JVM 正常加载。

---

## 技术栈与实现要点

| 层面 | 技术 / 做法 |
|------|-------------|
| 运行时 | **cmd**（`.bat` 入口）、**PowerShell 5.1+**（核心逻辑 `random_copy_push.ps1`） |
| 配置 | 可选 **`gencodebat.config.json`**（UTF-8 JSON），由 PowerShell `ConvertFrom-Json` 读取 |
| 文件发现 | `Get-ChildItem -Recurse -File`，按扩展名白名单过滤，并按路径段排除常见构建/依赖目录 |
| 「像文本」判断 | 文件大小上限 **2MB**；读取前 **64KB** 检查是否含 **NUL（0x00）**，含则视为二进制并跳过 |
| 编码 | 读文件优先 **UTF-8（带 BOM 检测的严格模式）**，失败则回退 **系统默认编码** |
| 随机抽样 | 在候选文件集合上随机选文件；若该行数 ≥10，再随机起始行，取连续 10 行；**每段最多尝试 50 次** |
| 两段独立性 | 第一段写入「函数片段」文件、第二段写入「测试片段」文件；两次抽样**相互独立**（可能来自同一文件不同位置） |
| 写入 | `File.AppendAllText`，块首带**时间戳**与**源路径、行号**元数据，便于追溯 |
| Git 批处理 | `random_copy_push_and_git.bat` 通过 `-EmitOutputPaths` 从配置解析两个输出文件的**绝对路径**，再 `git add` / `commit` / `push`；循环次数由配置项 **`Iterations`** 决定 |

---

## 环境要求

- Windows  
- **PowerShell 5.1 或更高**（系统自带即可）  
- 将本仓库（或至少 `random_copy_push.bat`、`random_copy_push.ps1` 及可选的 `gencodebat.config.json`）放在你希望作为**工作根目录**的位置（输出路径可配置，见下文）

---

## 配置文件 `gencodebat.config.json`

与脚本同目录放置。字段说明：

| 字段 | 含义 |
|------|------|
| `SourceRoot` | 要扫描的**源项目根目录**（完整或相对脚本目录的路径）。 |
| `OutputBaseDirectory` | 输出根目录；**空字符串**表示脚本所在目录。相对路径相对于脚本目录解析。 |
| `SnippetDirectory` | 输出根下的子目录名，默认 `snippets`。 |
| `FunctionClassFile` | 第一段 10 行写入的文件名，默认 `Function.class`。 |
| `FunctionTestClassFile` | 第二段 10 行写入的文件名，默认 `FunctionTest.class`。 |
| `Iterations` | 仅被 **`random_copy_push_and_git.bat`** 使用：抽样并尝试 **Git 提交/推送** 的**轮数**；缺省或非法时按 **10**；解析成功后与 **1** 取较大值（避免 0 或负数）。 |

**最终输出路径**为：

`[OutputBaseDirectory 或脚本目录]\[SnippetDirectory]\[FunctionClassFile]`  
`[OutputBaseDirectory 或脚本目录]\[SnippetDirectory]\[FunctionTestClassFile]`

命令行传入的 **`-SourceRoot` / `random_copy_push.bat` 的第一个参数** 会**覆盖**配置中的 `SourceRoot`；输出路径仍按配置文件（及上述默认值）计算。

---

## 使用方法

### `random_copy_push.bat`（仅追加片段，不执行 Git）

**有源目录参数（可拖拽文件夹到 bat 上）：**

```bat
cd /d D:\workspace\GenCodebat
random_copy_push.bat D:\workspace\OtherRepo
```

**无参数**：要求同目录存在 **`gencodebat.config.json`**，且其中已设置 **`SourceRoot`**。

**仅使用配置、且不要结束暂停**（供其它脚本调用）：将第一参数设为 **`NOPAUSE`**：

```bat
random_copy_push.bat NOPAUSE
```

**带源目录且跳过暂停**：

```bat
random_copy_push.bat D:\workspace\OtherRepo NOPAUSE
```

运行成功时会在控制台打印两个输出文件的**完整路径**。

---

### `random_copy_push.ps1`（直接调用）

在脚本所在目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\random_copy_push.ps1 -SourceRoot "D:\workspace\OtherRepo"
```

若已配置好 `gencodebat.config.json` 中的 `SourceRoot`，可省略 `-SourceRoot`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\random_copy_push.ps1
```

可选参数：

- **`-ConfigPath`**：指定其它 JSON 配置文件路径。  
- **`-EmitOutputPaths`**：只向标准输出打印一行 `路径1|路径2`（两个片段文件的绝对路径，分隔符为 `|`），然后退出（用于批处理解析）。  
- **`-EmitIterations`**：只输出一行整数（来自配置的 `Iterations`，规则见上），然后退出。

---

### `random_copy_push_and_git.bat`（多轮：追加 + 提交 + 推送）

在**当前目录为 Git 仓库**的前提下：

1. 从配置读取 **`Iterations`**（通过 `random_copy_push.ps1 -EmitIterations`）。  
2. 用 **`-EmitOutputPaths`** 解析两个片段文件路径，供 `git add` 使用。  
3. 对 `i = 1 .. Iterations` 循环：调用 **`random_copy_push.bat`（NOPAUSE）** → **`git add`** 两个文件 → 若有暂存变更则 **`git commit`**（说明中含轮次）→ **`git push origin HEAD`**。

**无参数**：需要 **`gencodebat.config.json`**（内含 `SourceRoot` 等）。  
**有参数**：第一个参数为源项目目录路径（可含空格，脚本内已加引号传递）。

任一轮抽样失败、提交失败或推送失败会暂停并以非零退出码结束。

---

## 输出文件格式

输出目录不存在时会自动创建；片段文件若不存在会创建**空文件**后再追加。

每次追加的**块格式**（UTF-8，无 BOM）：

1. 空行  
2. `===== yyyyMMdd_HHmmss =====`（同一次运行两段共用同一时间戳）  
3. `# source: <源文件完整路径>`  
4. `# lines: <起始行>-<结束行>`  
5. 空行  
6. 连续 **10 行**正文  

---

## 抽样规则

**允许的扩展名：**

`.cs` `.ts` `.tsx` `.js` `.jsx` `.py` `.java` `.go` `.rs` `.md` `.txt`

**路径中若任一段目录名为以下之一，则该路径下文件不参与候选**（简化实现：按路径分段匹配目录名）：

`.git` `node_modules` `bin` `obj` `dist` `build`

**其它规则简述：**

- 候选为空 → 退出码 **5**。  
- 每一段抽样若 **50 次尝试**后仍得不到「至少 10 行」的合格文本 → 退出码 **6**。  
- `SourceRoot` 不是目录 → 退出码 **2**。  

---

## 退出码（`random_copy_push.ps1`）

| 码 | 含义 |
|----|------|
| 0 | 成功 |
| 2 | `SourceRoot` 未配置或不是目录 |
| 5 | 源目录下没有匹配的候选文件 |
| 6 | 第一段或第二段在多次尝试后仍无法得到至少 10 行文本 |

---

## 本地试跑示例

仓库内 **`_smoke_src\sample.txt`** 可作为最小源目录（请按本机路径修改）：

```bat
random_copy_push.bat D:\workspace\GenCodebat\_smoke_src
```

若已把 `gencodebat.config.json` 中的 `SourceRoot` 指向 `_smoke_src`，也可直接双击 `random_copy_push.bat`（无参）。

---

## 仓库文件说明

| 文件 | 作用 |
|------|------|
| `gencodebat.config.json` | 源目录、输出目录与文件名、`Iterations` 等配置 |
| `random_copy_push.bat` | 校验参数或读取配置，调用 `random_copy_push.ps1`，默认结束时 `pause` |
| `random_copy_push.ps1` | 递归扫描、随机抽样、追加写入；支持 `-EmitOutputPaths` / `-EmitIterations` |
| `random_copy_push_and_git.bat` | 按 `Iterations` 循环执行抽样，并对配置中的两个片段文件执行 `git add` / `commit` / `push` |

> 脚本文件名中的 **`push`** 来自历史命名：**`random_copy_push.ps1` 本身不执行 Git**；需要自动推送时请使用 **`random_copy_push_and_git.bat`**。

---

## 许可与合规

从其它项目复制或抽样代码时，请确保你有权使用该源码，并遵守对方许可证。本工具只做技术层面的文件抽样与追加，不提供法律判断。
