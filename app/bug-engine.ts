export type BugKey = 'overflow' | 'memory' | 'hotPath' | 'firewall' | 'loop';

export type Bug = {
  name: string;
  code: string;
  category: string;
  icon: string;
  trigger: string;
  reward: string;
  risk: string;
  target?: number;
  progressLabel?: string;
};

export type BugAction = {
  cardKind: 'attack' | 'skill';
  cost: number;
  blockGained: number;
  cardsDrawn: number;
  energyAfterSpend: number;
};

export const BUGS: Record<BugKey, Bug> = {
  overflow: {
    name: 'Overflow',
    code: 'BUG_ENERGY_01',
    category: 'ENERGY',
    icon: '⚡',
    trigger: '主动把 Energy 刚好用到 0',
    reward: '抽 2 张牌，并恢复 1 Energy',
    risk: '敌人永久获得 +1 攻击力',
  },
  memory: {
    name: 'Memory Leak',
    code: 'BUG_DRAW_02',
    category: 'DRAW',
    icon: '▦',
    trigger: '通过牌效果抽至少 1 张牌',
    reward: '额外抽 2 张牌',
    risk: '失去 2 HP（无法格挡）',
  },
  hotPath: {
    name: 'Hot Path',
    code: 'BUG_ATTACK_03',
    category: 'ATTACK',
    icon: '⚔',
    trigger: '打出 2 张 Attack',
    reward: '额外造成 6 点伤害',
    risk: '失去 2 HP（无法格挡）',
    target: 2,
    progressLabel: 'ATTACKS',
  },
  firewall: {
    name: 'Firewall Backdoor',
    code: 'BUG_BLOCK_04',
    category: 'BLOCK',
    icon: '⬡',
    trigger: '用一张牌获得至少 5 Block',
    reward: '额外获得 8 Block',
    risk: '下一回合少 1 Energy（可叠加）',
  },
  loop: {
    name: 'Infinite Loop',
    code: 'BUG_INPUT_05',
    category: 'CARDS',
    icon: '∞',
    trigger: '继续打出 3 张任意牌',
    reward: '恢复 2 Energy',
    risk: '失去 3 HP（无法格挡）',
    target: 3,
    progressLabel: 'CARDS',
  },
};

export function nextBugKey(current: BugKey, random: () => number): BugKey {
  const candidates = (Object.keys(BUGS) as BugKey[]).filter((key) => key !== current);
  const index = Math.min(candidates.length - 1, Math.floor(random() * candidates.length));
  return candidates[index];
}

export function advanceBugProgress(bug: BugKey, progress: number, action: BugAction) {
  if (bug === 'hotPath') {
    const nextProgress = action.cardKind === 'attack' ? progress + 1 : progress;
    return { progress: nextProgress, triggered: nextProgress >= 2 };
  }

  if (bug === 'loop') {
    const nextProgress = progress + 1;
    return { progress: nextProgress, triggered: nextProgress >= 3 };
  }

  if (bug === 'overflow') return { progress: 0, triggered: action.cost > 0 && action.energyAfterSpend === 0 };
  if (bug === 'memory') return { progress: 0, triggered: action.cardsDrawn > 0 };
  return { progress: 0, triggered: action.blockGained >= 5 };
}
