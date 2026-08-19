# fluzer —— 脚手架 CLI

`fluzer` 是 Flutter Zero 模板的命令行工具，提供五组命令：

- **`create`**：从模板一键生成全新的 Flutter 项目（含完整 core 基础设施、示例模块、配置）。
- **`new`**：在已有模板项目里新增功能模块骨架，并**自动注册到 DI**。
- **`gen-l10n`**：执行 `flutter gen-l10n` 并生成类型安全的 `L10nCode` 访问层，**自动接线** `defaultToastHandle`。
- **`cache`**：查看或清空本地下载的模板缓存（`cache list` / `cache clean`）。
- **`version`**：查看 CLI 自身版本并检查是否有更新。

> 模板与 CLI 解耦：CLI 通过 Mason brick（在 `flutter_zero_template/bricks/` 下）渲染代码，brick 的变量契约与生成结构独立演进，模板可高频发版而不必升级 CLI。

---

## 1. 快速开始

### 开发模式（在 `flutter_zero_cli` 目录内）

```bash
dart run bin/fluzer.dart new user
dart run bin/fluzer.dart create my_app
dart run bin/fluzer.dart cache list
dart run bin/fluzer.dart version
```

### 全局安装

```bash
dart pub global activate fluzer

fluzer new user        # 新增功能模块
fluzer create my_app   # 创建新项目
fluzer cache list      # 查看已缓存的模板版本
fluzer version         # 查看版本 + 检查更新
```

> CLI 在 `pubspec.yaml` 中注册了可执行名 `fluzer`，因此 `global activate` 后可直接用 `fluzer` 调用。

---

## 2. 命令一览

| 命令 | 作用 | 常用选项 |
|------|------|----------|
| `fluzer new <feature_name>` | 在当前模板项目内新增功能模块并注册 DI | — |
| `fluzer create <project_name>` | 从模板创建全新 Flutter 项目 | `--org` |
| `fluzer gen-l10n` | 生成 L10nCode 访问层并自动接线 toast 分发 | `--skip-handle-patch` / `--force-handle-patch` |
| `fluzer cache list` | 查看已下载缓存的模板版本 | — |
| `fluzer cache clean` | 清空所有缓存的模板版本 | — |
| `fluzer version` | 打印 CLI 版本并检查 pub.dev 更新 | — |

---

### 全局选项（适用于所有命令）

`fluzer` 有两个全局开关，写在子命令之前（例如 `fluzer --locale en create my_app`）：

| 选项 | 作用 |
|------|------|
| `--locale` / `-L` | 切换 **CLI 自身界面语言**（与模板项目国际化无关），支持 `zh` / `en` / `ja`。四种写法：`--locale en`、`--locale=en`、`-L en`、`-Len`。未指定时解析优先级：`--locale` > 环境变量 `LANG`/`LC_ALL`/`LANGUAGE` > `Platform.localeName` > 默认 `zh`；无法识别的值静默回退 `zh`。 |
| `--log` / `-l` | 调试（verbose）模式：透传子进程实时输出、显示下载进度条、异常带完整堆栈、不显示 spinner。**任何 CLI 异常排查，先加 `-l` 重跑。** |

> 界面文案由 `slang` 生成（纯 Dart 模式）。

## 3. `new` —— 新增功能模块

必须在 **Flutter Zero 模板项目根目录**（含 `fluzer.yaml`，旧项目使用的 `flutter_zero_config.yaml` 仍可识别）下执行。

执行流程：

1. 加载 `fluzer.yaml`（或兼容的 `flutter_zero_config.yaml`），校验 `version`（字符串非空且 `>= 1.0.0` 下限）与 `template_name`。
2. 按项目 `version` 选择**版本适配器**（AdapterCommand）：版本超出当前 CLI 适配器支持范围时报错「请升级 fluzer」或「请升级模板/CLI」，否则进入命令。
3. 按项目 `version` **精确钉死**解析模板来源（从 registry 取同名版本）。
4. 校验功能名（必须是 `snake_case`，小写字母开头，例如 `user_profile`）。
5. 检查 `lib/features/<name>/` 是否已存在。
6. 用 Mason 渲染 `feature` brick（仅传 brick 声明的 `name` + `package_name` 变量，类名大小写由 brick 内 Mustache 过滤器处理）。
7. 通过 `FeatureRegistration`（底层 `CodeMod`）把模块写入 `lib/core/di/injection_base.dart` 的 `registerFeatureModules()`。
8. 运行 `build_runner`，仅构建新模块（`--build-filter lib/features/<name>/**.dart`）。

```bash
fluzer new user
```

> 生成的模块包含 `data/`、`domain/`、`presentation/` 骨架，并自动生成 `<name>_module.dart`。
> 关于新增模块后如何写业务逻辑，见[《编写第一个功能模块》](../getting-started/your-first-feature.md)。

---

## 4. `create` —— 创建新项目

执行步骤：

1. 校验项目名（小写字母开头，只含小写字母、数字、下划线）。
2. 用 Mason 渲染 `project` brick 到当前目录（变量仅 `name`），直接生成 `./<name>` 项目目录。
3. 执行 `flutter create . --org --project-name`。
4. 清理 `flutter create` 生成的默认 `test/widget_test.dart`（模板自带 `home_page_test.dart`）。
5. 执行 `flutter pub get`。
6. 执行 `flutter gen-l10n`。

```bash
fluzer create my_app

# 选项
#   --org <org>           组织标识（默认 com.example，影响 bundle ID）
```

> 注意：当前版本 `create` 不再接收 `--desc`（项目描述）。项目描述请在生成后手动编辑 `pubspec.yaml`。

目标目录已存在时会报错并清理命令自身创建的半成品目录（**不会删除你已有的同名目录内容**——仅当目录由本次命令创建时才清理；若该目录原本就存在，`create` 会直接提示你换名，不做任何删除）。

创建成功后提示后续步骤：`cd my_app` →（可选）`fluzer new my_feature` → `flutter run`。

---

## 5. `gen-l10n` —— 生成类型安全的国际化访问层

必须在 **Flutter Zero 模板项目根目录**下执行。在 `flutter gen-l10n` 的基础上，自动生成一套类型安全的国际化访问层，让 BLoC 无需 `BuildContext` 也能传递国际化信息。

执行流程：

1. 校验项目配置并解析 `l10n.yaml`（读取 `arb-dir` / `output-dir` / `output-class`，缺省回退模板约定值）。
2. 校验 ARB 目录存在且包含 `.arb` 文件。
3. 执行 `flutter gen-l10n`。
4. 解析生成的 `AppLocalizations` 抽象类成员（括号计数扫描限定类体，参数保留声明类型）。
5. 生成三个文件到 `output-dir`（默认 `lib/l10n/gen/`）：
   - **`l10n_code.dart`** — `L10nCode` 值对象：`code` + `parameters` 字段、无参 `static const` 常量、有参 typed factory、`toString`/`parse` 对称序列化（编码/解码只发生在序列化边界）、`==`/`hashCode`。
   - **`l10n_code_ext.dart`** — `typeS()` / `typeE()` / `typeI()` / `typeW()` toast 类型标记扩展，以及 `toToastEffect()` 直达方法。
   - **`l10n_toast_effect_helper.dart`** — 覆盖全部 ARB key 的集中式 switch 分发器，按参数声明类型反序列化（`int.tryParse`、`DateTime.tryParse` 等）。
6. 自动接线 `defaultToastHandle`：AST 定位 `effect.l10nCode != null` 分支并替换为 helper 调用（详见下文「自动接线」）。

```bash
fluzer gen-l10n

# 选项
#   --skip-handle-patch    跳过 defaultToastHandle 自动接线
#   --force-handle-patch   l10nCode 分支已被自定义时也强制覆盖（覆盖前打印原文）
```

### 在 BLoC 中使用

```dart
// 无参 + 类型标记 → 一步到位发出 ToastEffect
emitEffect(L10nCode.homeRefreshSuccess.typeI().toToastEffect());

// 有参（类型与 ARB placeholder 声明一致）
emitEffect(L10nCode.requestFailed('E1001').typeE().toToastEffect());

// 等价的手动写法
emitEffect(ToastEffect(l10nCode: L10nCode.homeRefreshSuccess.typeI().toString()));
```

不再需要逐 feature 编写 ToastEffect 处理器——所有 l10nCode 由 `L10nToastEffectHelper` 统一分发到 `ToastService` 的 `showSuccess` / `showError` / `showInfo` / `showWarning`。

### 自动接线的三态检测

`gen-l10n` 会修改 `lib/core/effect/effect_handle/default_toast_effect_handle.dart` 并补齐 import。为保护开发者修改，patch 前会识别分支当前状态：

| 状态 | 判定 | 行为 |
|------|------|------|
| 模板态 | 分支含 `assert(` 兜底（模板原始形态） | 执行替换，日志打印被替换原文 |
| 已接线态 | 分支已含 `L10nToastEffectHelper` | 幂等跳过（反复执行安全） |
| 自定义态 | 其他（开发者改过该分支） | 跳过并警告，不覆盖；`--force-handle-patch` 可强制 |

对其他代码（如 `_handleErrorCode` 中自行添加的 errorCode case）**零影响**——patch 基于 AST 精确定位分支，只替换该分支块内容。

> **为什么模板不直接预接线？** 三个 gen 文件在首次 `gen-l10n` 前不存在，模板若直接引用会导致新项目编译失败。保持 assert 兜底 + 首次 `gen-l10n` 自动接线是唯一不自洽矛盾的方案。

### ARB placeholder 类型

arb 中声明了类型的 placeholder 会原样保留到 `L10nCode` factory 签名与 helper 反序列化中：

```json
"@counterValue": { "placeholders": { "count": { "type": "int" } } }
```

```dart
// 生成的 factory 保留 int 类型
L10nCode.counterValue(5);
// helper 中按类型还原
l.counterValue(int.tryParse(l10nCode.parameters['count'] ?? '') ?? 0)
```

支持的类型：`Object` / `String` / `int` / `double` / `num` / `bool` / `DateTime`（DateTime 以 ISO-8601 序列化）。

> 生成的三个文件均为**全量再生成**产物（建议加入 `.gitignore`，模板项目默认已忽略 `lib/l10n/gen/`）。文件头带有 CLI 版本号，便于追溯。

---

## 6. `version` —— 查看版本与检查更新

```bash
fluzer version
```

- 打印 CLI 版本（来自 `cliVersion` 常量，须与 `pubspec.yaml` 的 `version` 同步）。
- 查询 pub.dev 检查是否有新版本：
  - 默认查询包名 `fluzer`；未发布时 pub.dev 返回 404，**静默降级**为「无法检查更新」，不影响主流程。
  - 结果按包名缓存 **24 小时**（不可用结果缓存 **10 分钟**），避免每次启动都打 API。
  - 网络异常 / 限流同样静默降级。
  - 发现新版本会提示：运行 `dart pub global activate fluzer` 升级。

---

## 7. `cache` —— 管理模板缓存

`fluzer` 会把远程拉取的模板 zip 缓存到系统临时目录的 `fluzer_cache/` 下（目录名 `template_<版本>` 或回退的 `fluzer_<哈希>`）。`cache` 命令用于查看与清理：

```bash
fluzer cache list     # 列出所有已缓存的模板版本
fluzer cache clean    # 清空所有缓存的模板版本
```

- `cache list`：打印 `fluzer_cache/` 下全部缓存版本目录（按名排序）；目录不存在或为空时给出提示，不报错。
- `cache clean`：删除所有缓存版本子目录，**保留 `version_check.json`**（这是 `version` 命令的更新检查缓存，不属于模板缓存）。
- 不带子命令运行 `fluzer cache` 会抛 `UsageException` 并打印错误与用法，返回退出码 **64**（`ExitCode.usage`）。

> 想强制重新拉取某个模板版本时，先 `fluzer cache clean` 再执行 `create` / `new` 即可。

---

## 8. 模板来源解析

`new` 与 `create` 都依赖 `TemplateSourceResolver.resolve()` 决定从哪加载 Mason brick。解析优先级：

1. **`FLUZER_BRICKS_DIR`** 非空 → `LocalBrickLoader`（本地开发 / 调试，指向 `bricks/` 根目录）。
2. **`FLUZER_TEMPLATE_ZIP_URL`** 非空 → 强制使用该 URL 的 `RemoteBrickLoader`（测试 / 调试）。
3. 否则走**远程 registry**：从 `templateRegistryUrl` 拉取 `template_registry.json`，`create` 直接取 `version` 最大者（始终使用最新模板，不再按 `minCliVersion` 过滤）的 zip URL；`new` 则按项目 `version` 精确匹配。`create`/`new` 拉取时直连 URL 与全部镜像前缀**同时并发竞速**，首个成功者胜出、其余取消（超时：文本 30s / 文件 180s），不存在「先等直连超时再回退镜像」。

```bash
# 本地调试：直接读本地 bricks 目录
export FLUZER_BRICKS_DIR=../flutter_zero_template/bricks
fluzer new user

# 调试：强制指定某个远程 zip
export FLUZER_TEMPLATE_ZIP_URL=https://github.com/<owner>/<repo>/releases/download/1.0.0/bricks.zip
fluzer create demo
```

`RemoteBrickLoader` 下载 zip 后缓存到临时目录：能用 registry 版本号时按 `template_<版本>` 命名缓存目录，环境变量覆盖 / 回退时退化为按 URL 哈希命名；不同版本互不覆盖，且解压时做了路径校验（防 Zip Slip）。

> **发布前必做**：把 `template_config.dart` 里的 `templateRegistryUrl`、`defaultTemplateZipUrl` 占位符（`https://github.com/<owner>/<repo>/...`）替换为真实地址，并把 `cliVersion` 与 `pubspec.yaml` 对齐。registry 为 `templates` 版本列表（`version` + `url`），`create` 取最大 `version`、`new` 按精确 `version` 匹配，详见[《CLI 版本管理》](../versioning-cli.md)。

---

## 9. 配置文件 `fluzer.yaml`（兼容 `flutter_zero_config.yaml`）

`new` / `gen-l10n` 命令依赖模板项目根目录的 `fluzer.yaml`（v2 配置名；旧项目使用的 `flutter_zero_config.yaml` 仍可识别）。`ProjectConfig.load()` 会向上查找任一文件名并校验。

```yaml
version: 1.0.0            # 模板版本（项目「出生」时使用的模板版本）
template_name: flutter_zero
```

校验项：

- `version` 为合法非空字符串且 `>= 1.0.0`（CLI 接受的最老模板版本下限）。
- `template_name` 必须恰好为 `flutter_zero`。
- 根目录存在 `pubspec.yaml`（读取 `name` 作为 `package_name`）。

> ⚠️ `minCliVersion` 字段已**移除**：CLI 不再依据配置里的 `minCliVersion` 做版本门禁，模板与 CLI 的兼容由命令的「版本适配器」按 `version` 范围决定（见 [版本约束规则](../versioning-rules.md)）。`lib/`、`lib/core/di/injection_base.dart` 等内部结构也不再在此校验——CLI 力求适配所有模板版本，结构差异交给各版本适配器处理。

任一项不满足都会抛出 `CliException` 并终止，提示你在正确的模板项目根目录下执行。

---

## 10. 目录结构

```
fluzer/
├── bin/
│   └── fluzer.dart                     # 入口 / Entry point
├── lib/
│   └── src/
│       ├── fluzer.dart                 # CLI 根控制器（CommandRunner 装配 + 根异常兜底 + UsageException 打印帮助）
│       ├── commands/
│       │   ├── base_command.dart        # 命令基类（收参 + buildContext + execute + 注入点）
│       │   ├── command_context.dart     # 命令上下文基类（携带版本信息）
│       │   ├── command_adapter.dart     # 版本适配器接口（spec / canHandle / run）
│       │   ├── adapter_command.dart     # 版本感知命令基类（读版本→选适配器→委托执行）
│       │   ├── new/                     # new 命令
│       │   │   ├── new_command.dart     # 入口（AdapterCommand，选 NewV1V2Adapter）
│       │   │   ├── new_context.dart     # 上下文
│       │   │   └── adapters/
│       │   │       ├── base_new_adapter.dart
│       │   │       └── new_v1v2_adapter.dart   # 1.0.0+ 适配器（按 version 钉死下载）
│       │   ├── gen_l10n/                # gen-l10n 命令
│       │   │   ├── gen_l10n_command.dart
│       │   │   ├── gen_l10n_context.dart
│       │   │   └── adapters/
│       │   │       ├── base_gen_l10n_adapter.dart
│       │   │       └── gen_l10n_v1v2_adapter.dart  # 1.0.0+ 通用适配器
│       │   ├── create/                  # create 命令
│       │   │   ├── create_command.dart  # 6 步流程 + 注入执行器
│       │   │   └── create_context.dart
│       │   ├── cache/                   # cache 命令
│       │   │   ├── cache_command.dart
│       │   │   └── cache_context.dart
│       │   └── version/                 # version 命令
│       │       ├── version_command.dart
│       │       ├── version_context.dart
│       │       └── version_spec.dart    # RangeSpec / AnySpec 版本区间
│       ├── gen_l10n/
│       │   ├── l10n_config.dart         # l10n.yaml 解析（arb-dir/output-dir/output-class）
│       │   ├── l10n_parser.dart         # AppLocalizations 解析（类体括号扫描 + L10nParam 类型）
│       │   ├── l10n_code_generator.dart # 三个 gen 文件的纯函数生成器（dart_style 格式化）
│       │   └── toast_handle_patcher.dart # defaultToastHandle AST 接线（三态检测）
│       │   └── l10n_param_type.dart     # L10nParamType 参数类型注册表
│       ├── codemod/
│       │   ├── code_mod.dart           # AST 编辑核心（CodeMod：addImport 排序 / insertAtMethodEnd 幂等）
│       │   ├── codemod_file_editor.dart # 通用文件编辑封装
│       │   ├── feature_registration.dart # DI 注册封装（依赖 CodeMod）
│       │   ├── insert_at_method_end_transform.dart # 方法末尾插入转换
│       │   └── ordered_import_transform.dart # import 顺序插入转换
│       ├── config/
│       │   └── project_config.dart     # 项目配置加载 + CliException
│       ├── template/
│       │   ├── brick_loader.dart        # BrickLoader 抽象 + Local / Remote 加载器
│       │   ├── brick_renderer.dart      # Mason 渲染封装（BrickRenderer.generate）
│       │   ├── feature_generator.dart   # 功能模块生成器（渲染 + 调 FeatureRegistration）
│       │   ├── template_source.dart     # 模板来源解析：TemplateSourceResolver
│       │   ├── template_version_reader.dart # 项目模板 version 读取（TemplateVersionReader）
│       │   ├── template_config.dart     # 集中配置（实际位于 lib/src/config/）：registry/zip URL、镜像前缀、缓存目录名
│       │   └── semantic_version.dart    # SemVer 解析与比较（实际位于 lib/src/util/）
│       ├── http/
│       │   ├── http_client.dart         # FluzerHttpClient：统一 Dio 实例 + 镜像竞速下载
│       │   └── race_http_client.dart    # 并发竞速下载器（直连 + 镜像前缀同时发起）
│       ├── i18n/
│       │   ├── i18n.dart                # 界面文案入口（MessagesProvider，支持 zh/en/ja）
│       │   ├── resources/*.i18n.json    # slang 源文案（zh/en/ja）
│       │   └── gen/strings*.g.dart      # slang 生成的类型安全访问层
│       ├── logging/
│       │   └── spinner.dart            # runWithSpinner：spinner 包裹 + verbose 模式降级
│       ├── process/
│       │   └── process_runner.dart      # ProcessRunner：统一进程执行（flutter / dart）
│       ├── util/
│       │   ├── string_case.dart         # 命名转换工具
│       │   └── regular_utils.dart        # 通用工具（如从 URL 提取版本号）
│       └── version/
│           ├── version_check.dart        # pub.dev 更新检查（可用 24h / 不可用 10min 缓存）
│           └── version_update_notifier.dart  # VersionUpdateNotifier：启动非阻断版本提示（new/gen-l10n/create 显式 opt-in）
├── test/
│   ├── fluzer_test.dart                 # 命令层（create/new/version/cache）+ 版本检查 + brick 渲染
│   ├── brick_test.dart                  # brick 渲染冒烟测试
│   ├── gen_l10n_test.dart               # l10n 解析与代码生成单元测试
│   ├── toast_handle_patcher_test.dart   # 自动接线三态 / 幂等 / 误触防护测试
│   ├── template_source_test.dart        # 模板来源解析（注册表 / 精确钉死 / 回退）
│   ├── version_check_test.dart          # 更新检查缓存与降级
│   ├── version_update_notifier_test.dart # 启动版本提示行为（VersionUpdateNotifier）
│   ├── http_client_test.dart            # HTTP 下载单测
│   ├── race_http_client_test.dart       # 并发竞速下载单测
│   ├── i18n_test.dart                   # 界面文案加载与回退
│   ├── process_runner_test.dart         # 子进程执行（stdin / 退出码）
│   ├── project_config_test.dart         # 配置加载与校验
│   ├── semantic_version_test.dart       # 版本比较
│   ├── spinner_test.dart                # spinner 行为
│   ├── util_test.dart                   # 工具函数
│   ├── text_url_extract_test.dart       # URL 版本号提取
│   ├── debug_flag_test.dart             # --log 调试标志
│   └── test_utils.dart                  # 测试辅助（安全删临时目录）
└── pubspec.yaml
```

---

## 11. 技术栈

| 类别 | 方案 |
|------|------|
| 参数解析 / CLI 框架 | `args`（CommandRunner + Command） |
| 日志输出 | `mason_logger`（彩色控制台） |
| 模板渲染 | `mason`（brick + Mustache 过滤器） |
| 模板下载 / 解压 | `dio` + `archive` |
| AST 代码修改 | `analyzer` + `codemod_recipe`（封装为 `CodeMod`） |
| 生成代码格式化 | `dart_style`（库内格式化，无需子进程） |
| YAML 解析 | `yaml` |
| 路径操作 | `path` |
| 国际化界面 | `slang ^4.19.0`（纯 Dart 模式，`flutter_integration: false`）+ `intl ^0.20.3` |

---

## 12. 开发与测试

### 本地调试

在 `flutter_zero_cli` 目录内用 `dart run bin/fluzer.dart ...`，并通过环境变量 `FLUZER_BRICKS_DIR` / `FLUZER_TEMPLATE_ZIP_URL` 指向本地或指定远程模板，避免每次都走 registry。

### 注入执行器便于测试

命令与版本检查均通过 typedef 注入外部实现，便于单测：

- `CreateCommand`：`ProcessRunner`（统一执行 flutter/dart 子进程）/ `BrickLoader` / `VersionCheckService` / `Translations`。
- `NewCommand`：`ProcessRunner` 与 `BrickLoader`。
- `VersionCommand`：`VersionCheckService`（`peekCachedUpdate()` / `checkForUpdate()`，查询 pub.dev）。

### 运行测试

```bash
dart analyze   # 0 issues
dart test      # 含命令层（create/new/version）与网络降级路径
```

测试覆盖要点：项目名 / 功能名校验、目标目录已存在、完整生成流程、`flutter create` 失败时的清理、版本检查的有更新 / 已最新 / 不可用三种分支、`cache` 的 list / clean。

---

## 13. 常见排查

- **`new` 报「未找到 fluzer.yaml（或 flutter_zero_config.yaml）」**：请 `cd` 到模板项目根目录（含该文件）再执行。
- **`create` 报「目录已存在」**：换一个项目名；已存在的目录不会被删除。
- **`version` 一直提示「无法检查更新」**：包尚未发布到 pub.dev，或网络受限——属正常降级，不影响其它命令。
- **模板拉取慢 / 想固定版本**：用 `FLUZER_TEMPLATE_ZIP_URL` 指定具体 Release 的 zip 链接。
- **`cache list` 为空**：尚未创建过项目或拉取过远程模板，缓存目录为空属正常。
- **想强制刷新模板**：先 `fluzer cache clean` 清空缓存，下次 `create` / `new` 会重新下载。
- **任何命令异常 / 下载卡住**：加 `-l`（或 `--log`）重跑，查看子进程真实输出、下载进度与完整堆栈。
- **`build_runner` 缓存损坏（如 freezed 生成物陈旧）**：删除 `.dart_tool/build` 及所有 `*.freezed.dart` / `*.g.dart` 后重新生成。

<!-- source-footer -->

---

*本页原文：[docs/zh/cli/README.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/cli/README.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Fcli%2FREADME.md)*
