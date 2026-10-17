#!/usr/bin/env node
// 代书 (Daishu) 经济平衡蒙特卡洛模拟
// 忠实移植自:
//   scripts/NPCManager.gd   — base_fee/perfect_bonus 公式、词库规模
//   scripts/JudgeSystem.gd  — 三档判定与计费
//   scripts/PlayerManager.gd— 起始金钱/摊位费/结局规则

const POOL = { salutation: 3, body: 6, signature: 3 }; // 各槽位词库大小(阶段1扩充后)

function baseFee(day) { return 12 + Math.floor((day - 1) / 3); }
function perfectBonus(day) { return 8 + (day - 1); }

// 按槽位命中概率作答: p=命中率, blankRate=留空率(留空=格式错误,扣钱)
function genAnswers(p, blankRate) {
  const slots = ['salutation', 'body1', 'body2', 'body3', 'signature'];
  const ans = {};
  for (const s of slots) {
    if (Math.random() < blankRate) { ans[s] = ''; continue; }
    if (Math.random() < p) { ans[s] = 'correct'; continue; }
    ans[s] = 'wrong'; // 错但必在池内(格式无错, 仅内容不中)
  }
  return ans;
}

// 不看故事: 每槽按词库大小均匀随机(必然在池内)
function genAnswersRandom() {
  const pick = (n) => (Math.random() < 1 / n ? 'correct' : 'wrong');
  return {
    salutation: pick(POOL.salutation),
    body1: pick(POOL.body),
    body2: pick(POOL.body),
    body3: pick(POOL.body),
    signature: pick(POOL.signature),
  };
}

// JudgeSystem.judge 计费移植 (cfg.baseAdd/bonusMul 用于灵敏度扫描)
// 与 scripts/JudgeSystem.gd 保持同步: 5/5=base+bonus, 4/5=base+0.7*bonus, <=3/5=0.6*base, 空槽=-2/个
function judgeFee(answers, day, cfg) {
  let format = 0, correct = 0;
  for (const s of Object.keys(answers)) {
    const v = answers[s];
    if (v === '') { format++; continue; }
    if (v === 'correct') correct++;
  }
  const base = baseFee(day) + (cfg.baseAdd ?? 0);
  const bonus = perfectBonus(day) * (cfg.bonusMul ?? 1);
  if (format > 0) return -2 * format;
  if (correct === 5) return base + bonus;
  if (correct === 4) return base + Math.floor(bonus * 0.7);
  return Math.floor(base * 0.6);
}

// 单局模拟
function playGame(cfg, mode) {
  const { totalDays, npcPerDay, stallFee, target, startMoney } = cfg;
  let money = startMoney;
  let day = 1;
  for (; day <= totalDays; day++) {
    for (let n = 0; n < npcPerDay; n++) {
      const ans = mode.random ? genAnswersRandom() : genAnswers(mode.p, mode.blankRate ?? 0);
      money += judgeFee(ans, day, cfg);
      if (money < 0) return { success: false, failedNeg: true, finalMoney: money, dayReached: day };
    }
    money -= stallFee;
    if (money < 0) return { success: false, failedNeg: true, finalMoney: money, dayReached: day };
  }
  return { success: money >= target, failedNeg: false, finalMoney: money, dayReached: totalDays };
}

function summarize(results) {
  let success = 0, failNeg = 0, failTarget = 0;
  const finals = [];
  for (const r of results) {
    if (r.success) success++;
    else if (r.failedNeg) failNeg++;
    else failTarget++;
    finals.push(r.finalMoney);
  }
  finals.sort((a, b) => a - b);
  const q = (k) => finals[Math.min(finals.length - 1, Math.floor(k * finals.length))];
  return {
    successRate: success / results.length,
    failNegRate: failNeg / results.length,
    failTargetRate: failTarget / results.length,
    p10: q(0.10), p50: q(0.50), p90: q(0.90),
  };
}

function simulate(cfg, mode, games) {
  const results = [];
  for (let i = 0; i < games; i++) results.push(playGame(cfg, mode));
  return summarize(results);
}

// ---------------------------------------------------------------------------
// CLI：允许临时改参数做扫描，不必改代码（默认参数 = 当前实现，输出与旧版一致）
//   node tools/balance_sim.mjs
//   node tools/balance_sim.mjs --target 525
//   node tools/balance_sim.mjs --targets 500,525,550,575,600   # 细扫目标值
//   node tools/balance_sim.mjs --bonus-mul 0.75 --targets 500,525
//   node tools/balance_sim.mjs --games 50000 --stall 12
// ---------------------------------------------------------------------------
function parseArgs(argv) {
  const out = { targets: null, overrides: {} };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    const v = argv[i + 1];
    switch (k) {
      case '--target': out.overrides.target = Number(v); i++; break;
      case '--stall': out.overrides.stallFee = Number(v); i++; break;
      case '--npc': out.overrides.npcPerDay = Number(v); i++; break;
      case '--start': out.overrides.startMoney = Number(v); i++; break;
      case '--days': out.overrides.totalDays = Number(v); i++; break;
      case '--games': out.games = Number(v); i++; break;
      case '--bonus-mul': out.overrides.bonusMul = Number(v); i++; break;
      case '--base-add': out.overrides.baseAdd = Number(v); i++; break;
      case '--targets':
        out.targets = String(v).split(',').map(Number).filter((n) => Number.isFinite(n));
        i++;
        break;
      default:
        if (k.startsWith('--')) {
          console.error(`未知参数：${k}（可用：--target --stall --npc --start --days --games --bonus-mul --base-add --targets）`);
          process.exit(2);
        }
    }
  }
  return out;
}

const CLI = parseArgs(process.argv.slice(2));

const GAMES = CLI.games && Number.isFinite(CLI.games) && CLI.games > 0 ? CLI.games : 20000;
const BASE_CFG = {
  totalDays: 10,
  npcPerDay: 3,
  stallFee: 10,
  target: 500,
  startMoney: 100,
  ...CLI.overrides,
};


const strategies = [
  ['最优（读懂故事，每槽必中）', { p: 1.0 }],
  ['熟练（90% 命中）', { p: 0.9 }],
  ['一般（75% 命中）', { p: 0.75 }],
  ['粗心（60% 命中）', { p: 0.6 }],
  ['偶尔留空（90%命中+5%空槽）', { p: 0.9, blankRate: 0.05 }],
  ['不看故事（池内随机）', { random: true }],
];

console.log('========== 当前数值 (10天/3NPC/摊位10/目标500/起始100) ==========');
for (const [name, mode] of strategies) {
  const s = simulate(BASE_CFG, mode, GAMES);
  console.log(`${name.padEnd(28)} 成功 ${(s.successRate * 100).toFixed(1)}% | 负钱失败 ${(s.failNegRate * 100).toFixed(1)}% | 未达标 ${(s.failTargetRate * 100).toFixed(1)}% | 终局钱 p10/p50/p90 = ${s.p10}/${s.p50}/${s.p90}`);
}

console.log('\n========== 参数扫描 (成功率: 最优 | 一般75% | 随机) ==========');
const sweep = [
  ['目标 400', { ...BASE_CFG, target: 400 }],
  ['目标 500 (当前)', { ...BASE_CFG }],
  ['目标 600', { ...BASE_CFG, target: 600 }],
  ['摊位费 5', { ...BASE_CFG, stallFee: 5 }],
  ['摊位费 15', { ...BASE_CFG, stallFee: 15 }],
  ['NPC 2/天', { ...BASE_CFG, npcPerDay: 2 }],
  ['NPC 4/天', { ...BASE_CFG, npcPerDay: 4 }],
  ['起始 50', { ...BASE_CFG, startMoney: 50 }],
  ['起始 150', { ...BASE_CFG, startMoney: 150 }],
];
for (const [label, cfg] of sweep) {
  const opt = simulate(cfg, { p: 1.0 }, GAMES);
  const med = simulate(cfg, { p: 0.75 }, GAMES);
  const rnd = simulate(cfg, { random: true }, GAMES);
  console.log(`${label.padEnd(14)} 最优 ${(opt.successRate * 100).toFixed(1)}% | 一般75% ${(med.successRate * 100).toFixed(1)}% | 随机 ${(rnd.successRate * 100).toFixed(1)}%`);
}

console.log('\n========== 报酬公式灵敏度 (最优策略) ==========');
const bonusSweep = [
  ['perf_bonus ×1 (当前)', {}],
  ['perf_bonus ×0.5', { bonusMul: 0.5 }],
  ['perf_bonus ×1.5', { bonusMul: 1.5 }],
  ['base_fee +2', { baseAdd: 2 }],
  ['base_fee -2', { baseAdd: -2 }],
];
for (const [label, tweak] of bonusSweep) {
  const cfg = { ...BASE_CFG, ...tweak };
  const s = simulate(cfg, { p: 1.0 }, GAMES);
  console.log(`${label.padEnd(20)} 成功 ${(s.successRate * 100).toFixed(1)}% | 终局 p50 ${s.p50}`);
}

// 细扫目标值：给"目标金额怎么定"提供数据（只在 --targets 时输出）
if (CLI.targets && CLI.targets.length > 0) {
  const { target: _ignored, ...rest } = BASE_CFG;
  console.log('\n========== 目标金额细扫（其余参数同当前配置） ==========');
  console.log('目标'.padEnd(10) + '最优'.padEnd(10) + '90%命中'.padEnd(12) + '75%命中'.padEnd(12) + '60%命中'.padEnd(12) + '随机'.padEnd(10) + '最优终局 p50');
  for (const t of CLI.targets) {
    const cfg = { ...rest, target: t };
    const opt = simulate(cfg, { p: 1.0 }, GAMES);
    const p90 = simulate(cfg, { p: 0.9 }, GAMES);
    const p75 = simulate(cfg, { p: 0.75 }, GAMES);
    const p60 = simulate(cfg, { p: 0.6 }, GAMES);
    const rnd = simulate(cfg, { random: true }, GAMES);
    const pct = (x) => `${(x * 100).toFixed(1)}%`;
    console.log(
      String(t).padEnd(10) + pct(opt.successRate).padEnd(10) + pct(p90.successRate).padEnd(12) +
      pct(p75.successRate).padEnd(12) + pct(p60.successRate).padEnd(12) + pct(rnd.successRate).padEnd(10) +
      String(opt.p50)
    );
  }
}
