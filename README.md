# codex-workflow

一个可跨项目复用的 Codex 多模型编排工作流。目标不是“尽量少调用模型”，而是在**不牺牲必要的分析、验证和 review 的前提下，把昂贵模型只用在高杠杆环节**。

核心原则：

- 默认用均衡模型处理日常任务；
- 用便宜模型做 repo 搜索、证据收集和重复工作；
- 复杂规划和非平凡 review 才升级到更强模型；
- GPT-6 Astra 只处理真正困难/高风险的窄问题；
- 测试、编译、类型检查、lint 等确定性工具优先于“让更贵模型想一遍”；
- 越昂贵的 agent，收到的上下文越小、越高信号；
- GitHub 网页分析与本地 Codex 执行通过标准 `Execution Packet` 交接，避免重复分析仓库。

## 默认角色映射

模型与工作流逻辑解耦。流程只引用角色；具体模型只配置在 `.codex/agents/*.toml`。

| 角色 | 默认模型 | 用途 |
| --- | --- | --- |
| primary | GPT-5.6 Terra / medium | 默认路由、普通本地任务 |
| explorer | GPT-5.6 Luna / low | repo 搜索、证据收集 |
| worker | GPT-5.6 Terra / medium | 日常实现 |
| planner | GPT-5.6 Sol / medium | 复杂/跨模块规划 |
| reviewer | GPT-5.6 Sol / medium | 非平凡 review、debug escalation |
| expert | GPT-6 Astra / medium | 关键疑难决策，默认只读 |

模型经济性或可用性变化时，只需调整 TOML，不需要修改 Skill、GitHub prompt 或 Execution Packet 协议。

## 两种入口，共用一套执行流程

### A. Local-first

适合大多数日常开发：

```text
需求
  -> $dev-orchestrator
  -> 风险分级
  -> 必要的 repo 探索
  -> 必要的规划
  -> 实现
  -> tests/build/type/lint
  -> 按风险 review / escalation
```

简单任务不会启动整套 agent。复杂度越高，才逐级使用 Sol/Astra。

### B. GitHub-first

适合你先把项目 push 到 GitHub，再让 ChatGPT 网页端分析和规划的场景：

```text
push exact commit to GitHub
        |
        v
ChatGPT/web 分析 repo/ref/commit
        |
        v
Execution Packet v1
        |
        v
复制到本地 Codex
        |
        v
检查本地 HEAD / packet 是否漂移
        |
        v
执行同一个 dev-orchestrator workflow
```

关键不是复制一篇长分析，而是复制一个紧凑的 Execution Packet：目标、证据路径/符号、约束、风险、实施步骤、验收标准和验证命令。这样 Codex 不需要重新把整个仓库理解一遍。

## 风险路由

| 等级 | 典型任务 | 默认路径 |
| --- | --- | --- |
| R0 trivial | 文本/配置小改、机械修改 | primary 直接处理 + 确定性验证 |
| R1 standard | 普通 feature/bug/refactor/API/UI | explorer（按需） -> worker -> 验证；reviewer 按风险 |
| R2 complex | 跨模块、公开接口、数据模型、复杂根因 | explorer -> planner -> worker -> 验证 -> reviewer |
| R3 critical | auth/security/payment/破坏性 migration/concurrency/data loss | evidence -> planner -> expert（窄问题） -> worker -> 验证 -> reviewer |

worker 对同一未解决根因最多进行两次有意义的尝试；之后停止盲目 retry，先交给 reviewer 诊断，仍无法解决才升级 expert。

## 快速安装到一个项目

克隆本仓库后：

```bash
bash scripts/install.sh /path/to/your-project
```

安装器会：

- 安装 `.codex/agents/*.toml`；
- 安装 `.agents/skills/dev-orchestrator/`；
- 项目没有 `.codex/config.toml` 时安装默认配置；已有配置则保留并生成 example 供合并；
- 项目没有 `AGENTS.md` 时安装 policy；已有文件时只追加一个短 workflow 段落。

然后在 Codex CLI / IDE 中：

```text
$dev-orchestrator

实现 <你的任务>。
```

对于非常小、明显的任务，可以直接描述需求，不必显式触发 workflow。

## GitHub-first 的实际用法

1. 将你希望分析的状态 push 到 GitHub，最好固定到明确 branch/commit。
2. 在 ChatGPT 网页端使用 [`prompts/github-analyze.md`](prompts/github-analyze.md) 的 prompt，并填入 repo/ref/task。
3. 网页端只输出 `Execution Packet v1`，不要让它生成大量实现代码。
4. 本地 Codex 使用 [`prompts/codex-execute.md`](prompts/codex-execute.md)，随后粘贴 packet。
5. Codex 先检查本地 HEAD 与 packet 的 source commit；没有明显 drift 就直接执行，发现 drift 才局部修正计划。

Execution Packet 的规范位于：

`.agents/skills/dev-orchestrator/references/execution-packet.md`

## 为什么这样更省额度

这套方案主要消除四类浪费：

1. **高价模型扫仓库**：搜索和 evidence gathering 下放给 Luna。
2. **高价模型做机械实现**：明确计划交给 Terra worker。
3. **重复分析**：GitHub web 已经形成 packet 时，本地只验证关键假设，不重新做 repo-wide planning。
4. **无限 debug/review 循环**：两次 worker retry 后升级诊断；满足 completion gate 后立即停止。

质量保障来自风险分级、确定性检查、必要的 Sol review 和关键场景的 Astra escalation，而不是让 Astra 从头到尾包办整个任务。

## 文件结构

```text
AGENTS.md
.codex/
  config.toml
  agents/
    explorer.toml
    worker.toml
    planner.toml
    reviewer.toml
    expert.toml
.agents/
  skills/
    dev-orchestrator/
      SKILL.md
      references/
        execution-packet.md
prompts/
  github-analyze.md
  codex-execute.md
docs/
  architecture.md
scripts/
  install.sh
```

## Skill、Agent、Plugin 的边界

- **Custom Agent**：决定“谁做”，绑定模型、reasoning、sandbox 和角色职责。
- **Skill**：决定“怎么做”，承载风险分级、阶段、handoff、retry、review 和 escalation 规则。
- **AGENTS.md**：只放项目长期政策，保持短小。
- **Plugin**：当前不是必需。等 workflow 稳定后，如果希望团队一键分发，或者希望把 planner skill 直接带到 ChatGPT 网页/桌面等产品中，再打包成 Plugin。

## 设计文档

详细说明见 [`docs/architecture.md`](docs/architecture.md)。
