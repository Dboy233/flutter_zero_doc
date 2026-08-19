# 模板版本规范 / Template Versioning

本规范定义 `flutter_zero_template`（bricks 模板仓库）的版本号管理规则，以及与
`flutter_zero_cli`（fluzer 工具）的兼容性约束。

模板与 CLI 是两条独立的版本线，模板与 CLI 的兼容由命令的「版本适配器」按项目 `version` 范围决定（`minCliVersion` 字段已移除）。

## 语义化版本（SemVer）

版本号格式 `主版本.次版本.补丁`（`MAJOR.MINOR.PATCH`），例如 `1.0.1`。

## 模板版本号 bump 规则

| 位 | 触发条件 | 对 CLI 的影响 | 版本适配器 |
|----|----------|--------------|---------------|
| **PATCH** `1.0.x` | 修复 bug、文案、布局错误、注释；模板文件小修。**不改 brick 变量契约、不改生成代码结构** | 无感，老 CLI 直接拉新 zip 即用 | 不变（现有适配器覆盖） |
| **MINOR** `1.x.0` | 向下兼容地**新增**内容：新增可选 brick、给 brick 加**带默认值的可选变量**、新增可选 DI 钩子 | 老 CLI 仍可用（不触发新内容即无影响） | 不变（现有适配器覆盖） |
| **MAJOR** `x.0.0` | **破坏性变更**：改/删 brick 的必填变量、改生成代码的类名/方法名（影响 CLI codemod 锚点）、删除某个 brick | 老 CLI 拉到后会生成失败 | **需新增版本专属适配器** |

## 兼容性契约分水岭

判断 bump 哪一位，关键看是否动了**契约**：

1. **Mason 变量契约**：feature brick 当前仅声明 `name` + `package_name`。只要这两个不变 → 顶多 PATCH/MINOR。
2. **生成代码结构契约**：CLI 的 `CodeMod`（`addImport` / `insertAtMethodEnd`）依赖类名、方法名定位锚点。模板若改了这些名字 → 破坏 CLI 注入 → MAJOR。
3. **DI 注册锚点**：`registerFeatureModules()` 的自动注入区域方法签名变化 → MAJOR。

> 经验法则：**只动"内容"不 bump 主版本；动了"契约/锚点"必 bump 主版本并为新模板版本新增专属适配器。**

## 何时需要新增版本适配器

- 模板 **PATCH / MINOR** → **通常无需**新增适配器。模板修 bug、加功能时，CLI 一行不用改，老 CLI 自动拉到新 zip，现有适配器即可覆盖。
- 模板 **MAJOR** → 若改动导致 `new`/`gen-l10n` 的执行流程出现**版本差异**（如 DI 注入锚点变化、目录结构调整），则需在对应命令的适配器链中**新增一个覆盖该版本范围的适配器**。老 CLI 运行时遇到超出适配器范围的版本会明确报错"请升级 CLI"，而非静默生成坏代码。

> 2.0.0 起不再用 `minCliVersion` 门禁。历史版本（如 1.0.1 曾因引用 `fluzer gen-l10n` 而把 `minCliVersion` 提到 `1.1.0`）仍能被现有适配器正常处理。

## 发布流程（模板）

1. 修改模板内容。
2. 打包：`zip -r bricks.zip bricks`。
3. 发 GitHub Release（固定版本号，如 `v1.0.1`，**不要用 `/latest`**，避免 302 与缓存陷阱）。
4. 更新 `template_registry.json`：
   - `version` → 新版本号
   - `url` → 新 Release 的 `bricks.zip` 固定链接
   - （`minCliVersion` 字段已移除，registry 只需维护 `version` + `url`）
5. 推送到 `main`，`raw.githubusercontent.com/<owner>/<repo>/main/template_registry.json` 即时生效。
6. **CLI 无需发版**（除非本次 MAJOR 的行为差异需要 CLI 侧新增版本适配器）。

## 相关文档

- CLI 版本规范见 [CLI版本管理](versioning-cli.md)。
- 三版本约束关系与命令版本适配见 [版本约束规则](versioning-rules.md)。

<!-- source-footer -->

---

*本页原文：[docs/zh/versioning-template.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/versioning-template.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Fversioning-template.md)*
