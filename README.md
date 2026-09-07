# codex-workflow

一个可跨项目复用的 Codex 多模型编排工作流。目标不是“尽量少调用模型”，而是在**不牺牲必要的分析、验证和 review 的前提下，把昂贵模型只用在高杠杆环节**。

现在包含两层可组合工作流：

- `dev-orchestrator`：软件开发生命周期，负责 evidence -> plan -> implement -> deterministic validation -> review/escalation；
- `ml-research-orchestrator`：正式 ML 研究生命周期，负责 hypothesis -> registered experiment -> smoke/pilot/full -> analysis -> bad cases -> decision -> claim evidence。

两者不会重复规划：研究 Skill 决定“实验要证明什么”，需要改代码时把一个有验收标准的窄任务交给开发 Skill，代码验证通过后再回到实验生命周期。

## 核心原则

- 默认用均衡模型处理日常任务；
- 用便宜模型做 repo 搜索、证据收集和重复工作；
- 复杂规划和非平凡 review 才升级到更强模型；
- GPT-6 Astra 只处理真正困难/高风险的窄问题；
- 测试、编译、类型检查、lint 等确定性工具优先于“让更贵模型想一遍”；
- 越昂贵的 agent，收到的上下文越小、越高信号；
- GitHub 网页分析与本地 Codex 执行通过标准 `Execution Packet` 交接，避免重复分析仓库；
- 正式 ML 实验先冻结问题/假设/指标，再逐级放大 compute；
- 训练完成不等于研究完成：Bad Case、Training Report、Decision 和 Claim Evidence 都属于实验产物。

## 默认角色映射

模型与工作流逻辑解耦。流程只引用角色；具体模型只配置在 `.codex/agents/*.toml`。

| 角色 | 默认模型 | 用途 |
| --- | --- | --- |
| primary | GPT-5.6 Terra / medium | 默认路由、普通本地任务 |
| explorer | GPT-5.6 Luna / low | repo 搜索、证据收集 |
| worker | GPT-5.6 Terra / medium | 日常实现 |
| planner | GPT-5.6 Sol / medium | 复杂/跨模块规划 |
| reviewer | GPT-5.6 Sol / medium | 非平凡 review、debug/research audit escalation |
| expert | GPT-6 Astra / medium | 关键疑难决策，默认只读 |

模型经济性或可用性变化时，只需调整 TOML，不需要修改 Skill 或 handoff 协议。

## 软件开发入口

### A. Local-first

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

### B. GitHub-first

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

网页端与本地端的关键交接物不是长篇分析，而是紧凑的 `Execution Packet v1`：目标、证据路径/符号、约束、风险、实施步骤、验收标准和验证命令。

## ML Research 工作流

`ml-research-orchestrator` 面向真正会产出技术结论的训练/评测任务，而不是“能跑就算完成”。

默认状态机：

```text
Research Question
   -> Experiment Contract
   -> L0 Unit/Synthetic
   -> L1 Offline Sample/Replay
   -> L2 Smoke
   -> L3 Pilot
   -> L4 Full Run
   -> L5 Analysis/Audit
   -> ACCEPT / REJECT / INCONCLUSIVE / FOLLOW_UP
```

正式实验至少冻结：

- research question / falsifiable hypothesis；
- baseline / treatment / changed variable；
- data/model/evaluator provenance；
- primary / secondary / guardrail metrics；
- compute budget；
- success/failure/stop criteria；
- leakage / reward-hacking / confounder 风险。

正式实验结束不能只有一个最终分数。默认要求：

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

其中：

- `training_report.md` 分析优化过程、异常时间段、reward/entropy/KL/clip/grad/action 等训练健康信号；
- `bad_case_report.md` 强制做失败 taxonomy、代表样本、reward/metric decomposition、退化策略审计和下一诊断；
- `decision.md` 只能给 `ACCEPT / REJECT / INCONCLUSIVE / FOLLOW_UP`，并区分 measured fact、interpretation 和 alternative explanation；
- `reports/claim_evidence.md` 把简历/面试/报告中的每个数字一路追到 experiment、result、config、commit、data/model/evaluator provenance；
- `reports/interview/` 在项目过程中持续沉淀“为什么这么做、实际遇到什么问题、怎么验证、还存在哪些限制”。

详细设计见 [`docs/ml-research-workflow.md`](docs/ml-research-workflow.md)。

## 风险路由（开发任务）

| 等级 | 典型任务 | 默认路径 |
| --- | --- | --- |
| R0 trivial | 文本/配置小改、机械修改 | primary 直接处理 + 确定性验证 |
| R1 standard | 普通 feature/bug/refactor/API/UI | explorer（按需） -> worker -> 验证；reviewer 按风险 |
| R2 complex | 跨模块、公开接口、数据模型、复杂根因 | explorer -> planner -> worker -> 验证 -> reviewer |
| R3 critical | auth/security/payment/破坏性 migration/concurrency/data loss | evidence -> planner -> expert（窄问题） -> worker -> 验证 -> reviewer |

worker 对同一未解决根因最多进行两次有意义的尝试；之后停止盲目 retry，先形成 Debug Packet 交给 reviewer，仍无法解决才升级 expert。ML 研究失败采用同样原则，但使用 `Research Debug Packet v1`。

## 安装到项目

### Core：普通软件项目

```bash
bash scripts/install.sh /path/to/your-project
```

安装：

- `.codex/agents/*.toml`；
- `.agents/skills/dev-orchestrator/`；
- Codex config/example；
- `AGENTS.md` workflow policy；
- 当安装源是 Git checkout 时写入 `.codex-workflow.lock`，记录 workflow commit/profile。

### ML Research：训练/研究项目

```bash
bash scripts/install.sh /path/to/your-project --profile ml-research
```

在 Core 基础上额外安装：

- `.agents/skills/ml-research-orchestrator/`；
- ML research policy；
- workflow lock 中记录 `ml-research` profile。

本地 Codex：

```text
$dev-orchestrator
实现 <有明确验收标准的开发任务>。

$ml-research-orchestrator
设计/执行/分析/审计 <EXP-ID 或研究问题>。
```

`codex-workflow` 保持领域无关：具体项目里的模型、数据集、reward、action space、安全阈值、GPU 约束，应放到目标项目自己的 project skill，而不是写进这个仓库。

## GitHub-first 的实际用法

### 开发规划

1. push 到明确 branch/commit；
2. ChatGPT/web 使用 [`prompts/github-analyze.md`](prompts/github-analyze.md)；
3. 输出 `Execution Packet v1`；
4. 本地 Codex 使用 [`prompts/codex-execute.md`](prompts/codex-execute.md)；
5. Codex 检查 commit drift 后执行。

Execution Packet 规范：

`.agents/skills/dev-orchestrator/references/execution-packet.md`

### 研究审计

正式 EXP/stage push 后，ChatGPT/web 使用：

[`prompts/github-research-audit.md`](prompts/github-research-audit.md)

网页端应独立检查：

`contract -> baseline/treatment -> result -> training health -> bad cases -> decision -> claim`

如果审计发现需要改代码，再生成一个窄的 implementation follow-up 交给 `dev-orchestrator`，不要让网页端与本地 Codex 同时重做整个实现。

## 为什么这样更省额度和 GPU

软件侧主要消除：

1. 高价模型扫仓库；
2. 高价模型做机械实现；
3. GitHub/web 与本地重复分析；
4. 无限 debug/review 循环。

ML 研究侧额外消除：

1. reward/metric 还没验证就直接跑 full training；
2. smoke 已经暴露结构问题仍继续烧 GPU；
3. 指标差就同时调多个变量；
4. 失败实验没有 taxonomy，下一次只能猜；
5. 项目结束后再靠记忆补实验故事和面试材料。

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
    ml-research-orchestrator/
      SKILL.md
      references/
        experiment-contract.md
        experiment-lifecycle.md
        reporting-protocol.md
        research-debug-packet.md
        claim-evidence.md
        interview-report.md
prompts/
  github-analyze.md
  github-research-audit.md
  codex-execute.md
docs/
  architecture.md
  ml-research-workflow.md
scripts/
  install.sh
```

## Skill、Agent、Plugin 的边界

- **Custom Agent**：决定“谁做”，绑定模型、reasoning、sandbox 和角色职责；
- **Skill**：决定“怎么做”，承载风险/实验生命周期、handoff、retry、review、completion gate；
- **AGENTS.md**：只放项目长期政策，保持短小；
- **Project Skill**：目标项目自己的模型/数据/reward/metrics/hardware invariants；
- **Plugin**：当前不是必需。工作流稳定且需要跨团队/产品分发时再考虑。

## 设计文档

- 通用开发编排：[`docs/architecture.md`](docs/architecture.md)
- ML Research 编排：[`docs/ml-research-workflow.md`](docs/ml-research-workflow.md)
