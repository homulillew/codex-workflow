# codex-workflow

可跨项目复用的 Codex 多模型编排与 ML Research 工作流。目标不是“尽量少调用模型”，而是在**不牺牲分析、验证和 review 的前提下，提升每单位模型额度与 GPU compute 的有效产出**。

当前包含两层可组合 Skill：

- `dev-orchestrator`：`evidence -> plan -> implement -> deterministic validation -> review/escalation`
- `ml-research-orchestrator`：`hypothesis -> registered experiment -> smoke/pilot/full -> analysis -> bad cases -> decision -> claim evidence`

研究 Skill 决定“实验要证明什么”；需要改代码时，把一个边界明确、带验收标准的实现任务交给开发 Skill，验证完成后再回到研究生命周期。

## 核心原则

- 便宜模型做 repo 搜索、证据收集和重复工作；
- 确定性测试优先于“再让模型想一遍”；
- 越昂贵的 agent，收到的上下文越小、越高信号；
- **风险/后果决定验证与 review 强度，推理复杂度决定模型强度**；
- GPT-6 `expert` 服务 C3 最困难的算法/方法论/根因/跨域综合推理，不是通用“高危审批人”；
- 明显 C3 的问题可以在证据压缩后前置调用 expert，不需要人为制造一次 Sol/worker 失败；
- GitHub/web 与本地 Codex 使用 `Execution Packet v1` 交接，避免重复扫描仓库；
- 正式 ML 实验先冻结 hypothesis / baseline / metrics，再逐级放大 compute；
- 训练跑完不等于研究完成：Training Report、Bad Case、Decision、Claim Evidence 都是一等产物；
- 下游项目 vendor 固定 workflow 快照，不动态跟随 `main`；
- upstream upgrade 必须显式、可审计，并保护 project-owned 文件。

## 默认角色映射

工作流只引用角色；模型绑定集中在 `.codex/agents/*.toml`。

| 角色 | 默认模型 | 核心问题 |
| --- | --- | --- |
| `primary` | GPT-5.6 Terra | 普通任务如何快速完成？ |
| `explorer` | GPT-5.6 Luna | 事实/代码/证据在哪里？ |
| `worker` | GPT-5.6 Terra | 明确方案怎么实现？ |
| `planner` | GPT-5.6 Sol | 复杂但常规的问题应该怎么组织？ |
| `reviewer` | GPT-5.6 Sol | 实现/实验解释是否正确，哪里有缺口？ |
| `expert` | GPT-6 Astra | 剩下这个真正困难、非套路化的技术问题，正确判断是什么？ |

一句话：**Luna 找，Terra 做，Sol 组织和检查，GPT-6 想最难的部分。**

## 二维路由：Risk × Reasoning Complexity

### Risk / Consequence

回答：**做错了后果有多严重？**

- `R0`：低后果、可逆、容易验证
- `R1`：普通后果、常规 feature/fix
- `R2`：高影响、较大 blast radius / public interface / data-model 等
- `R3`：关键后果，例如安全、支付、不可逆数据、严重隐私/合规等

Risk 决定：测试深度、review、回滚、保护措施和 acceptance criteria。

### Reasoning Complexity

回答：**这个技术问题本身有多难？**

- `C0`：机械修改
- `C1`：标准实现/已知模式
- `C2`：复杂但常规的跨模块规划、架构、debug、trade-off
- `C3`：真正困难/非套路化的问题，例如新算法、reward/objective、方法论、多个竞争根因、深度跨域综合

Complexity 决定：是否需要更强 reasoning role。**C3 才是 `expert` 的正常触发器。**

| | C0/C1 | C2 | C3 |
| --- | --- | --- | --- |
| R0/R1 | primary/worker | planner + worker | evidence -> planner -> expert -> worker |
| R2/R3 | 相同模型路径，但加强 safeguards/review | planner + mandatory review | expert reasoning + mandatory risk-specific review |

例子：

- `R3/C1`：沿现有模式增加一个简单 auth guard -> Terra + 强测试 + Sol review，不因“高危”自动调用 GPT-6。
- `R1/C3`：为内部实验设计一个新的 RL reward / optimization algorithm -> 可以直接进入 GPT-6 reasoning lane。
- `R3/C3`：新的一致性/安全算法且失败后果高 -> GPT-6 解决概念瓶颈，同时使用 R3 级 safeguards。

详细设计：[`docs/architecture.md`](docs/architecture.md)

## GPT-6 / `expert` 的职责

适合：

- novel algorithm / objective / reward / verifier / protocol / architecture design；
- 多个有证据支持的 competing hypotheses 的困难根因分析；
- methodology-critical research decision；
- algorithm + data + training dynamics + systems + evaluation 的深层综合；
- 一个概念选择如果错了会让大量后续实验失效/浪费的高杠杆问题。

不适合：

- repo-wide 搜索；
- routine implementation；
- 普通 code review；
- 仅仅因为任务涉及 security/payment 就调用；
- 日志汇总、Bad Case 分类、普通报告生成。

推荐上下文压缩：

```text
raw repo / raw experiment
      ↓
Evidence Packet
      ↓
Sol structures options / hypotheses
      ↓
Decision or Research Debug Packet
      ↓
GPT-6 expert
      ↓
bounded implementation / discriminating experiment
```

## 软件开发入口

### Local-first

```text
需求
  -> $dev-orchestrator
  -> classify Risk + Complexity
  -> evidence
  -> C2: planner
  -> C3: planner compress -> expert
  -> implement
  -> tests/build/type/lint
  -> review proportional to Risk
```

### GitHub-first

```text
push exact commit
        ↓
ChatGPT/web 分析 repo/ref/commit
        ↓
Execution Packet v1
        ↓
本地 Codex drift check
        ↓
$dev-orchestrator
        ↓
implement + deterministic validation
```

GitHub-first prompt：

- `prompts/github-analyze.md`
- `prompts/codex-execute.md`

Execution Packet 规范：

- `.agents/skills/dev-orchestrator/references/execution-packet.md`

## ML Research 工作流

正式研究实验使用：

```text
Research Question
   -> Experiment Contract
   -> reasoning-complexity classification
   -> C3 algorithm/methodology decision? -> expert
   -> L0 Unit/Synthetic
   -> L1 Offline Sample/Replay
   -> L2 Smoke
   -> L3 Pilot
   -> L4 Full Run
   -> L5 Analysis/Audit
   -> ACCEPT / REJECT / INCONCLUSIVE / FOLLOW_UP
```

ML Research 中典型 C3：

- 新算法 / reward / objective / verifier 设计；
- 信息充分性、停止准则等 methodology-critical operational definition；
- 训练退化中多个 competing root causes 经过证据收集仍难区分；
- headline metric 与 guardrail 冲突，因果解释本身很复杂；
- 下一步实验选择需要跨算法、训练动态、系统和 evaluation 综合判断。

正式实验至少冻结：

- research question / falsifiable hypothesis；
- baseline / treatment / changed variable；
- data/model/evaluator provenance；
- primary / secondary / guardrail metrics；
- compute budget；
- success/failure/stop criteria；
- leakage / reward-hacking / confounder 风险。

推荐实验产物：

```text
experiments/EXP-XXX/
  brief.yaml
  config.yaml
  result.json
  samples.jsonl
  reports/
    run_report.md
    training_report.md
    bad_case_report.md
    decision.md
```

重点协议：

- Experiment Contract：`.agents/skills/ml-research-orchestrator/references/experiment-contract.md`
- Lifecycle：`.agents/skills/ml-research-orchestrator/references/experiment-lifecycle.md`
- Reporting：`.agents/skills/ml-research-orchestrator/references/reporting-protocol.md`
- Research Debug Packet：`.agents/skills/ml-research-orchestrator/references/research-debug-packet.md`
- Claim Evidence：`.agents/skills/ml-research-orchestrator/references/claim-evidence.md`
- Interview Evidence：`.agents/skills/ml-research-orchestrator/references/interview-report.md`
- GitHub independent audit：`prompts/github-research-audit.md`

详细设计：[`docs/ml-research-workflow.md`](docs/ml-research-workflow.md)

## 安装

### Core

```bash
bash scripts/install.sh /path/to/project
```

安装：

- `.codex/agents/*.toml`
- `.agents/skills/dev-orchestrator/**`
- workflow-managed `AGENTS.md` block
- `.codex/codex-workflow.config.example.toml`
- 当项目缺少 `.codex/config.toml` 时创建初始 config
- `.codex-workflow.lock`
- `.codex-workflow.manifest`

### ML Research

```bash
bash scripts/install.sh /path/to/project --profile ml-research
```

额外安装：

- `.agents/skills/ml-research-orchestrator/**`
- ML research `AGENTS.md` managed block

项目自己的模型、数据集、reward、action space、安全阈值、GPU 约束，应放在目标项目自己的 repo-local project Skill，而不是写进 `codex-workflow`。

## 上游/下游关系

推荐关系：

```text
codex-workflow
  reusable upstream
        │
        │ exact reviewed commit
        ▼
 install / explicit upgrade
        ▼
target project
  vendored workflow snapshot
  + project-local Skill
  + code / experiments / evidence / reports
```

**不要让目标项目动态跟随 `codex-workflow/main`。**

目标项目应提交：

- vendored workflow-owned files；
- `.codex-workflow.lock`；
- `.codex-workflow.manifest`。

其中 commit 是真正的 reproducibility anchor。

## 安全升级

当前 workflow 支持显式升级：

```bash
bash scripts/update.sh /path/to/project
```

等价于：

```bash
bash scripts/install.sh /path/to/project --upgrade
```

升级规则：

- 未显式提供 `--profile` 时保留目标项目已有 profile；
- 支持 `core -> ml-research` promotion；
- 自动 `ml-research -> core` downgrade 被拒绝；
- workflow-owned 文件根据 `.codex-workflow.manifest` 做 SHA-256 divergence 检查；
- 本地修改过的 managed file 会阻止升级；
- `.codex/config.toml`、project Skill、docs、experiments、reports 等 project-owned 内容不会被覆盖；
- `AGENTS.md` 只更新 codex-workflow marker 内的 managed block；
- upstream 删除的 managed file 只有在下游未修改时才会安全删除；
- 旧 lock v1 可根据记录的 `workflow_commit` 与 Git history 迁移到 lock v2。

如果确定本地 managed 修改可以丢弃：

```bash
bash scripts/update.sh /path/to/project --force-managed
```

默认禁止从 dirty upstream checkout 安装/升级。仅测试场景可以显式：

```bash
bash scripts/update.sh /path/to/project --allow-dirty-source
```

详细协议：[`docs/versioning-and-upgrades.md`](docs/versioning-and-upgrades.md)

## Lock v2

示例：

```yaml
lock_version: 2
workflow_repository: "https://github.com/example/codex-workflow.git"
workflow_version: "0.4.0"
workflow_commit: "<exact-commit>"
profile: "ml-research"
source_dirty: false
managed_manifest: ".codex-workflow.manifest"
```

`.codex-workflow.manifest` 记录 workflow-owned 文件和安装时 SHA-256。它用于区分“安全 upstream update”和“下游本地 divergence”。

## 本地 Codex

```text
$dev-orchestrator
实现 <有明确验收标准的开发任务>。

$ml-research-orchestrator
设计/执行/分析/审计 <EXP-ID 或研究问题>。
```

## CI / 验证

```bash
bash -n scripts/install.sh
bash -n scripts/update.sh
bash -n tests/test-install.sh
bash tests/test-install.sh
```

测试覆盖：

- core / ml-research fresh install；
- install idempotency；
- project-owned config / AGENTS 内容保留；
- managed divergence 拦截；
- explicit `--force-managed`；
- obsolete managed file 安全删除；
- core -> ml-research promotion；
- downgrade refusal；
- legacy lock v1 -> v2 migration；
- downstream expert / orchestrator 安装后包含 Risk × Complexity 与 C3 路由语义。

## 目录

```text
AGENTS.md
VERSION
.codex/
  config.toml
  agents/
.agents/
  skills/
    dev-orchestrator/
    ml-research-orchestrator/
policies/
  ml-research-agent-policy.md
prompts/
  github-analyze.md
  github-research-audit.md
  codex-execute.md
docs/
  architecture.md
  ml-research-workflow.md
  versioning-and-upgrades.md
scripts/
  install.sh
  update.sh
tests/
  test-install.sh
.github/
  workflows/
    ci.yml
```

## Skill / Agent / Project 的边界

- **Custom Agent**：决定“谁做”；模型强度按 reasoning complexity 路由。
- **Skill**：决定“怎么做”，包括 Risk × Complexity 分类与 lifecycle。
- **AGENTS.md**：短、稳定的仓库级 policy/navigation。
- **Project Skill**：目标项目自己的领域/方法/硬约束。
- **codex-workflow**：只保存跨项目通用 workflow，不保存 Medical/SQL/VLM 等项目专属语义。

## 设计文档

- 开发编排：[`docs/architecture.md`](docs/architecture.md)
- ML Research：[`docs/ml-research-workflow.md`](docs/ml-research-workflow.md)
- 下游版本与升级：[`docs/versioning-and-upgrades.md`](docs/versioning-and-upgrades.md)
