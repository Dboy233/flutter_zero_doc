# fluzer —— 脚手架 CLI

`fluzer` 是 Flutter Zero 模板的命令行工具，提供四组命令：

- **`create`**：从模板一键生成全新的 Flutter 项目（含完整 core 基础设施、示例模块、配置）。
- **`new`**：在已有模板项目里新增功能模块骨架，并**自动注册到 DI**。
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
| `fluzer new <feature_name>` | 在当前模板项目内新增功能模块并注册 DI | `--build-runner` / `--no-build-runner` |
| `fluzer create <project_name>` | 从模板创建全新 Flutter 项目 | `--org`、`--build-runner` / `--no-build-runner` |
| `fluzer cache list` | 查看已下载缓存的模板版本 | — |
| `fluzer cache clean` | 清空所有缓存的模板版本 | — |
| `fluzer version` | 打印 CLI 版本并检查 pub.dev 更新 | — |

---

## 3. `new` —— 新增功能模块

必须在 **Flutter Zero 模板项目根目录**（含 `flutter_zero_config.yaml`）下执行。

执行流程：

1. 校验功能名（必须是 `snake_case`，小写字母开头，例如 `user_profile`）。
2. 检查 `lib/features/<name>/` 是否已存在。
3. 用 Mason 渲染 `feature` brick（仅传 brick 声明的 `name` + `package_name` 变量，类名大小写由 brick 内 Mustache 过滤器处理）。
4. 通过 `FeatureRegistration`（底层 `CodeMod`）把模块写入 `lib/core/di/injection_base.dart` 的 `registerFeatureModules()`。
5. 按需运行 `build_runner`。

```bash
fluzer new user

# 选项
#   --build-runner      生成后运行 build_runner（默认启用）
#   --no-build-runner   跳过 build_runner（之后可手动 dart run build_runner build）
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
7. 按需执行 `build_runner`。

```bash
fluzer create my_app

# 选项
#   --org <org>           组织标识（默认 com.example，影响 bundle ID）
#   --build-runner        生成后运行 build_runner（默认启用）
#   --no-build-runner     跳过 build_runner
```

> 注意：当前版本 `create` 不再接收 `--desc`（项目描述）。项目描述请在生成后手动编辑 `pubspec.yaml`。

目标目录已存在时会报错并清理命令自身创建的半成品目录（**不会删除你已有的同名目录内容**——仅当目录由本次命令创建时才清理；若该目录原本就存在，`create` 会直接提示你换名，不做任何删除）。

创建成功后提示后续步骤：`cd my_app` →（可选）`fluzer new my_feature` → `flutter run`。

---

## 5. `version` —— 查看版本与检查更新

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

## 6. `cache` —— 管理模板缓存

`fluzer` 会把远程拉取的模板 zip 缓存到系统临时目录的 `fluzer_cache/` 下（目录名 `template_<版本>` 或回退的 `fluzer_<哈希>`）。`cache` 命令用于查看与清理：

```bash
fluzer cache list     # 列出所有已缓存的模板版本
fluzer cache clean    # 清空所有缓存的模板版本
```

- `cache list`：打印 `fluzer_cache/` 下全部缓存版本目录（按名排序）；目录不存在或为空时给出提示，不报错。
- `cache clean`：删除所有缓存版本子目录，**保留 `version_check.json`**（这是 `version` 命令的更新检查缓存，不属于模板缓存）。
- 不带子命令运行 `fluzer cache` 会打印帮助信息（列出 `list` / `clean` 用法）。

> 想强制重新拉取某个模板版本时，先 `fluzer cache clean` 再执行 `create` / `new` 即可。

---

## 7. 模板来源解析

`new` 与 `create` 都依赖 `resolveBrickLoader()` 决定从哪加载 Mason brick。解析优先级：

1. **`FLUZER_BRICKS_DIR`** 非空 → `LocalBrickLoader`（本地开发 / 调试，指向 `bricks/` 根目录）。
2. **`FLUZER_TEMPLATE_ZIP_URL`** 非空 → 强制使用该 URL 的 `RemoteBrickLoader`（测试 / 调试）。
3. 否则走**远程 registry**：从 `templateRegistryUrl` 拉取 `template_registry.json`，在 `minCliVersion <= cliVersion` 的记录里选 `version` 最大者的 zip URL；拉取失败（或直连超时 5s）则回退 `defaultTemplateZipUrl`。

```bash
# 本地调试：直接读本地 bricks 目录
export FLUZER_BRICKS_DIR=../flutter_zero_template/bricks
fluzer new user

# 调试：强制指定某个远程 zip
export FLUZER_TEMPLATE_ZIP_URL=https://github.com/<owner>/<repo>/releases/download/1.0.0/bricks.zip
fluzer create demo
```

`RemoteBrickLoader` 下载 zip 后缓存到临时目录：能用 registry 版本号时按 `template_<版本>` 命名缓存目录，环境变量覆盖 / 回退时退化为按 URL 哈希命名；不同版本互不覆盖，且解压时做了路径校验（防 Zip Slip）。

> **发布前必做**：把 `template_config.dart` 里的 `templateRegistryUrl`、`defaultTemplateZipUrl` 占位符（`https://github.com/<owner>/<repo>/...`）替换为真实地址，并把 `cliVersion` 与 `pubspec.yaml` 对齐。registry 采用「兼容性桶」结构，详见[《CLI 版本管理》](../versioning-cli.md)。

---

## 8. 配置文件 `flutter_zero_config.yaml`

`new` 命令依赖模板项目根目录的 `flutter_zero_config.yaml`。`ProjectConfig.load()` 会向上查找该文件并校验项目结构。

```yaml
version: 1.0.0            # 模板版本，须 >= 最低支持版本 (1.0.0)
template_name: flutter_zero
```

校验项：

- `version` 为合法字符串且 `>= 1.0.0`。
- `template_name` 必须恰好为 `flutter_zero`。
- 根目录存在 `pubspec.yaml`（读取 `name` 作为 `package_name`）、存在 `lib/`、`lib/core/di/injection_base.dart`。

任一项不满足都会抛出 `CliException` 并终止，提示你在正确的模板项目根目录下执行。

---

## 9. 目录结构

```
fluzer/
├── bin/
│   └── fluzer.dart                     # 入口 / Entry point
├── lib/
│   └── src/
│       ├── fluzer.dart                 # CLI 根控制器（CommandRunner 装配 + 根异常兜底 + UsageException 打印帮助）
│       ├── commands/
│       │   ├── create_command.dart     # create 命令（7 步流程 + 注入执行器）
│       │   ├── new_command.dart        # new 命令（渲染 + 注册 DI）
│       │   ├── cache_command.dart      # cache 命令（list / clean 缓存）
│       │   └── version_command.dart    # version 命令（可注入更新检查）
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
│       │   ├── template_source.dart     # 模板来源解析：选 BrickLoader
│       │   ├── template_config.dart     # 集中配置：registry/zip URL、镜像前缀、缓存目录名
│       │   └── semantic_version.dart    # SemVer 解析与比较（统一版本比较逻辑）
│       ├── http/
│       │   └── http_client.dart         # FluzerHttpClient：统一 Dio 实例 + 镜像降级重试
│       ├── process/
│       │   └── process_runner.dart      # ProcessRunner：统一进程执行（flutter / dart）
│       ├── util/
│       │   ├── string_case.dart         # 命名转换工具
│       │   └── regular_utils.dart        # 通用工具（如从 URL 提取版本号）
│       └── version/
│           └── version_check.dart       # pub.dev 更新检查（可用结果 24h 缓存、不可用结果 10min 缓存）
├── test/
│   ├── fluzer_test.dart                 # 命令层 + 版本检查单元测试
│   └── brick_test.dart                  # brick 渲染冒烟测试
└── pubspec.yaml
```

---

## 10. 技术栈

| 类别 | 方案 |
|------|------|
| 参数解析 / CLI 框架 | `args`（CommandRunner + Command） |
| 日志输出 | `mason_logger`（彩色控制台） |
| 模板渲染 | `mason`（brick + Mustache 过滤器） |
| 模板下载 / 解压 | `dio` + `archive` |
| AST 代码修改 | `analyzer` + `codemod_recipe`（封装为 `CodeMod`） |
| YAML 解析 | `yaml` |
| 路径操作 | `path` |

---

## 11. 开发与测试

### 本地调试

在 `flutter_zero_cli` 目录内用 `dart run bin/fluzer.dart ...`，并通过环境变量 `FLUZER_BRICKS_DIR` / `FLUZER_TEMPLATE_ZIP_URL` 指向本地或指定远程模板，避免每次都走 registry。

### 注入执行器便于测试

命令与版本检查均通过 typedef 注入外部实现，便于单测：

- `CreateCommand`：`CreateFlutterCreateRunner` / `CreateFlutterPubGetRunner` / `CreateFlutterGenL10nRunner` / `CreateBuildRunnerRunner` 与 `BrickLoader`。
- `NewCommand`：`BuildRunnerRunner` 与 `BrickLoader`。
- `VersionCommand`：`CheckForUpdate`（默认 `checkForUpdate`，查询 pub.dev）。

### 运行测试

```bash
dart analyze   # 0 issues
dart test      # 含命令层（create/new/version）与网络降级路径
```

测试覆盖要点：项目名 / 功能名校验、目标目录已存在、完整生成流程、`flutter create` 失败时的清理、版本检查的有更新 / 已最新 / 不可用三种分支、`cache` 的 list / clean。

---

## 12. 常见排查

- **`new` 报「未找到 flutter_zero_config.yaml」**：请 `cd` 到模板项目根目录（含该文件）再执行。
- **`create` 报「目录已存在」**：换一个项目名；已存在的目录不会被删除。
- **`version` 一直提示「无法检查更新」**：包尚未发布到 pub.dev，或网络受限——属正常降级，不影响其它命令。
- **模板拉取慢 / 想固定版本**：用 `FLUZER_TEMPLATE_ZIP_URL` 指定具体 Release 的 zip 链接。
- **`cache list` 为空**：尚未创建过项目或拉取过远程模板，缓存目录为空属正常。
- **想强制刷新模板**：先 `fluzer cache clean` 清空缓存，下次 `create` / `new` 会重新下载。
