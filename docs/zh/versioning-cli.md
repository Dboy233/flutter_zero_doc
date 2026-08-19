# CLI 版本规范 / CLI Versioning

本规范定义 `flutter_zero_cli`（fluzer 工具）的版本号管理规则，以及与
`flutter_zero_template`（bricks 模板仓库）的兼容性约束。

CLI 与模板是两条独立的版本线，模板与 CLI 的兼容由命令的「版本适配器」按项目 `version` 范围决定，
CLI 运行时不再读取任何 `minCliVersion` 做门禁（该字段已从配置与注册表中移除）。

## 语义化版本（SemVer）

版本号格式 `主版本.次版本.补丁`（`MAJOR.MINOR.PATCH`），例如 `1.0.0`。

## CLI 版本号 bump 规则

| 位 | 触发条件 | 对模板的影响 | 备注 |
|----|----------|--------------|------|
| **PATCH** `1.0.x` | CLI bug 修复（如 http 超时未兜底、codemod 边界错误） | 无感 | 现有适配器仍覆盖 |
| **MINOR** `1.x.0` | 向下兼容地**新增**功能：新命令、registry 拉取支持、新环境变量 | 现有模板照常加载 | 现有适配器仍覆盖 |
| **MAJOR** `x.0.0` | **破坏性变更**：开始向 brick 传**新必填变量**而老模板没有、重写 codemod 注入逻辑导致老模板锚点失效 | 老模板可能生成失败 | 需同步推新模板或新增版本适配器 |

## 模板缓存

模板加载器（`TemplateSourceResolver`，实现见 `lib/src/template/template_source.dart`）的缓存与刷新规则：

> 缓存目录优先按模板版本号命名（`template_<版本>`），环境变量覆盖 / 回退时退化为按 URL 哈希命名。
> 模板注册表中不同版本的 `url` 天然命中不同缓存目录，旧版本缓存不会被误用，无需手动清理。
> 如需强制刷新，运行 `fluzer cache clean`。

> 模板来源选择（`create` 取 `version` 最大者、`new` 按精确 `version` 钉死）与版本适配器逻辑统一见 [版本约束规则](versioning-rules.md)。

## 版本适配（原 minCliVersion 门禁已移除）

2.0.0 起 `minCliVersion` 字段已从配置与注册表移除，CLI 不再据此门禁。模板与 CLI 的兼容改为由命令的**版本适配器**按项目 `version` 范围决定：

- **`create`（CLI 驱动）**：不校验版本。直接在模板注册表中取 `version` **最大**者下载（始终最新模板）；注册表拉取失败则**静默回退**内置 `defaultTemplateZipUrl`，保证总能创建项目。
- **`new` / `gen-l10n`（项目驱动）**：读取项目 `fluzer.yaml` 的 `version`，沿命令的适配器链选认领者；版本超出适配器支持范围则**终止并提示升级 CLI / 升级模板**，避免用不兼容的 CLI 生成坏代码。

> 完整的适配器选择与边界场景见 [版本约束规则](versioning-rules.md)。

## 兼容性契约分水岭（CLI 侧）

判断 bump 哪一位，关键看是否动了**契约**：

1. **Mason 变量契约**：若 CLI 开始向 brick 传新必填变量（超出 `name` + `package_name`），老模板未声明 → 破坏 → CLI MAJOR。
2. **生成代码结构契约**：`CodeMod`（`addImport` / `insertAtMethodEnd`）依赖生成代码的类名/方法名定位。若 CLI 重写注入逻辑导致老模板锚点失效 → CLI MAJOR。
3. **DI 注册锚点**：`registerFeatureModules()` 注入区域的方法签名变化 → CLI MAJOR。

> 经验法则：**只动"内容/内部实现"不 bump 主版本；动了"契约/锚点"必 bump 主版本并通知模板侧同步。**

## 发布流程（CLI）

1. 修改 CLI 代码。
2. 按上表 bump 版本号（`pubspec.yaml` 的 `version`）。
3. 若本次为 **MAJOR 且影响模板契约** → 通知模板侧发对应版本（并由该模板版本专属适配器覆盖其行为差异）。
4. 发版：`dart pub publish` 或 `dart pub global activate fluzer`。

## 相关文档

- 模板版本规范见 [模板版本管理](versioning-template.md)。
- 三版本约束关系与命令版本适配见 [版本约束规则](versioning-rules.md)。

<!-- source-footer -->

---

*本页原文：[docs/zh/versioning-cli.md](https://github.com/Dboy233/flutter_zero_doc/blob/main/docs/zh/versioning-cli.md)*

*[报告本页错误](https://github.com/Dboy233/flutter_zero_doc/issues/new?template=doc_bug_zh.md&title=%E3%80%90%E6%96%87%E6%A1%A3%E9%94%99%E8%AF%AF%E3%80%91docs%2Fzh%2Fversioning-cli.md)*
