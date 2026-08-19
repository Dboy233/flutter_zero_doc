# 发布流程（RELEASE）

> 本文描述 `flutter_zero` 三仓库（`flutter_zero_app` / `flutter_zero_cli` / `flutter_zero_template`）的
> 开发、验证与发布流程。
>
> **核心原则：模板与 CLI 解耦发布。** 模板可独立高频发版，CLI 在大多数情况下无需跟随发布；
> 两者通过 `template_registry.json` 的版本列表衔接（`create` 取最大 `version`、`new` 精确匹配 `version`）。

---

## 0. 前置知识

| 主题 | 文档 |
|------|------|
| 三仓库职责与架构 | [架构总览](architecture/index.md) |
| 模板版本规则（SemVer bump） | [模板版本管理](versioning-template.md) |
| CLI 版本规则与兼容逻辑 | [CLI 版本管理](versioning-cli.md) |
| 模板分发机制（registry） | `flutter_zero_template/template_registry.json` |

**版本规则一句话**：

- **PATCH(0.0.x)** = 修 bug / 内容小修，不改契约 → CLI 躺着不动
- **MINOR(0.x.0)** = 向下兼容新增（带默认值的可选变量、可选 brick） → CLI 躺着不动
- **MAJOR(x.0.0)** = 破坏性（改 brick 变量契约 / 生成代码结构 / DI 锚点） → 必新增版本适配器

---

## 1. 整体流程

```
阶段 A：模板开发与验证（app → template → 本地验证）
阶段 B：CLI 调整（按需）
阶段 C：发布（解耦）—— 模板几乎总能不带 CLI 动
```

> ⚠️ **关键纠正**：模板发版 ≠ CLI 必须发版。模板 PATCH/MINOR 时 CLI 完全不用发布，
> 因为 `template_registry.json` 会自动指向新模板，老 CLI 运行时自动拉到最新兼容版本。

---

## 阶段 A：模板开发与验证

### A1. 在 `flutter_zero_app` 验证架构与模板
实现 / 验证业务、架构、模板结构。`flutter_zero_app` 是模板的**验证项目**，也是同步脚本的输入源。

### A2. 同步模板到 `flutter_zero_template`
用同步脚本把 app 同步进 `bricks/`：
```bash
cd flutter_zero_template
dart run scripts/sync_project_brick.dart
```
脚本会拷贝 + 内容替换（`flutter_zero_app` → `{{name}}`）+ 重命名 + 文件覆盖（见脚本内变量配置）。

### A3. 本地用 mason 验证 brick 生成
确保两种 brick 都能正确渲染（需全局安装 mason：`dart pub global activate mason_cli`）：
```bash
# 进入模板目录
cd flutter_zero_template

# （可选）初始化目录
mason init

# 将brick添加至mason本地运行
mason add feature --path brick/feature

# 验证feature模板生成
mason make feature --name demo --package_name demo
```
以上命令会在当前目录(flutter_zero_template)中生成一个目录，检查目录中内容是否正确。

### A4. 用 CLI 本地模式端到端验证
通过环境变量让 CLI 从本地加载模板（不触网）：
```bash
cd flutter_zero_cli
FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart new demo
FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart create demo_app
```

---

## 阶段 B：CLI 调整（按需）

### B1. 修改 `flutter_zero_cli`
当模板的**变量契约**或 **codemod 锚点**（类名 / 方法名 / DI 注入区域）变化时，调整 CLI 代码。

### B2. 验证
```bash
cd flutter_zero_cli
dart analyze
dart test
```
必须 **0 issues + 全绿** 才进入发布。

---

## 阶段 C：发布（解耦）

### C1. 发布模板（核心步骤，通常独立于 CLI）

1. **判定 bump**：按 [模板版本管理](versioning-template.md) 决定 PATCH / MINOR / MAJOR。
2. **打包**：
   ```bash
   cd flutter_zero_template
   zip -r bricks.zip bricks     # 顶层直接是 bricks/...
   ```
3. **发 GitHub Release**（**固定版本 URL**，不要用 `/latest` 重定向链接）：
   ```bash
   gh release create v1.0.1 bricks.zip --title "Templates v1.0.1"
   # 得到固定链接：
   # https://github.com/OWNER/REPO/releases/download/v1.0.1/bricks.zip
   ```
4. **更新 `template_registry.json`**（版本列表，只需 `version` + `url`）：
   - **PATCH / MINOR** → 更新对应 `version` 条目的 `url`（指向新 Release）
   - **MAJOR** → 新增一条（新的 `version` + `url`），旧条目保留
5. **推到 main**（保证 raw URL 稳定可达）：
   ```bash
   git add template_registry.json && git commit -m "chore: 更新模板注册表至 v1.0.1" && git push
   ```

> ✅ 到此，老 CLI 用户下次运行会自动拉到新模板，**CLI 无需任何改动**。

### C2. 判断 CLI 是否要发版

| 场景 | CLI 是否发版 |
|------|------|
| 模板 PATCH / MINOR | **不发**（registry 已指向新模板） |
| 模板 MAJOR（行为差异需新增适配器） | 若 CLI 侧需新增版本适配器，则发；否则仅 registry 更新即可 |
| CLI 自身有改动 / bug 修复 / 新功能 | 发 |

### C3. 发布 CLI（仅当 C2 判定需要）

1. 更新 `lib/src/config/template_config.dart` 的 `cliVersion` 常量（**必须与 `pubspec.yaml` 同步**）。
2. 若模板 MAJOR，确认对应命令（`new`/`gen-l10n`）的版本适配器已覆盖该模板版本。
3. 重新跑 `dart analyze` + `dart test`。
4. 发布：
   ```bash
   cd flutter_zero_cli
   dart pub publish
   ```

### C4. 发布后验证

- **版本提示**：`fluzer version` 应能看到新版本提示（CLI 已发布到 pub.dev 后）。
- **真实拉取**：通过真实 registry（`template_registry.json` 指向的 Release 链接），验证 `fluzer new` 端到端拉到新模板并正确生成。

---

## 2. 发布前检查清单（Checklist）

**模板发布前**

- [ ] 按 [模板版本管理](versioning-template.md) 判定 bump 类型
- [ ] `bricks.zip` 已打包，顶层为 `bricks/`
- [ ] GitHub Release 用**固定版本 URL**（非 `/latest`）
- [ ] `template_registry.json` 已更新（PATCH/MINOR 改对应条目 `url`，MAJOR 新增条目）
- [ ] `template_registry.json` 已推到 main

**CLI 发布前**

- [ ] `cliVersion` 常量与 `pubspec.yaml` 版本一致
- [ ] `dart analyze` 0 issues
- [ ] `dart test` 全绿
- [ ] 占位 URL 已替换为真实地址（见附录 3.1）
- [ ] `CHANGELOG.md` 与 `CHANGELOG_CN.md` 顶部已同步新增，且中英文内容对齐
- [ ] `dart pub publish --dry-run` 预检通过（确认无 missing dependency 等错误）
- [ ] 若改过 i18n 文案，已执行 `dart run slang` 重新生成 `strings*.g.dart`
- [ ] `pubspec.yaml` 的 `dependencies` 已显式声明 `intl`（slang 纯 Dart 模式生成物仍 `import 'package:intl/intl.dart'`）
- [ ] `dart pub publish` 成功

---

## 3. 附录

### 3.1 占位待替换（发布前必填）

位置：`flutter_zero_cli/lib/src/config/template_config.dart`

- `templateRegistryUrl` → 真实 raw URL
  `https://raw.githubusercontent.com/OWNER/REPO/main/template_registry.json`
- `defaultTemplateZipUrl` → 真实 Release **固定版本** URL（作为拉取失败时的兜底）
- `cliVersion` → 与 `pubspec.yaml` 同步（每次 CLI 发版必改）

> ⚠️ **禁止修改 `minimumSupportedVersion`**：该常量表示「CLI 能接受的最老模板版本门槛」，
> 与 CLI 自身版本（`cliVersion`）无关。若顺手把它改成 CLI 版本，会错误排斥 `1.0.x` 等正常旧模板，
> 破坏版本下限校验。它应始终保持 `1.0.0` 不变。

### 3.2 命令速查

| 用途 | 命令 |
|------|------|
| 同步模板 | `cd flutter_zero_template && dart run scripts/sync_project_brick.dart` |
| 本地验证 brick | `mason make feature --name demo --package_name demo` |
| CLI 本地加载模板 | `FLUZER_BRICKS_DIR=../flutter_zero_template/bricks dart run bin/fluzer.dart new demo` |
| CLI 查版本更新 | `fluzer version`（发布后用全局命令） |
| 发模板 | `zip -r bricks.zip bricks` + `gh release create vX.Y.Z bricks.zip` + 更新 registry + push |
| 发 CLI | `dart pub publish` |

---

> 文档维护：本流程随发布实践演进。若发现步骤与实际不符，优先更新本文与两份 `versioning-xxx.md`。

<!-- source-footer -->

---

*本页原文：[docs/zh/release.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/release.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Frelease.md)*
