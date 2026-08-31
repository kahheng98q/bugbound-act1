'use client';

import { useEffect, useMemo, useState } from 'react';
import type { CSSProperties } from 'react';

type CardKind = 'attack' | 'skill' | 'power';
type Card = {
  id: number;
  name: string;
  code: string;
  art: string;
  cost: number;
  kind: CardKind;
  damage?: number;
  block?: number;
  heal?: number;
  draw?: number;
  energy?: number;
  selfDamage?: number;
};

type BugKey = 'overflow' | 'memory' | 'hotPath' | 'firewall' | 'bloodPact';
type Bug = {
  name: string;
  code: string;
  category: string;
  icon: string;
  trigger: string;
  reward: string;
  risk: string;
};

const BUGS: Record<BugKey, Bug> = {
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
    code: 'BUG_HAND_02',
    category: 'DRAW / HAND',
    icon: '▦',
    trigger: '手上至少有 5 张牌时，打出抽牌卡',
    reward: '额外抽 2 张牌',
    risk: '失去 2 HP（无法格挡）',
  },
  hotPath: {
    name: 'Hot Path',
    code: 'BUG_ATTACK_03',
    category: 'ATTACK',
    icon: '⚔',
    trigger: '打出本回合第 2 张及之后的 Attack',
    reward: '额外造成 5 点伤害',
    risk: '失去 2 HP（无法格挡）',
  },
  firewall: {
    name: 'Firewall Backdoor',
    code: 'BUG_BLOCK_04',
    category: 'DEFEND',
    icon: '⬡',
    trigger: '已有至少 5 Block 时，再打出格挡牌',
    reward: '额外获得 8 Block',
    risk: '下一回合少 1 Energy（可叠加）',
  },
  bloodPact: {
    name: 'Blood Pact',
    code: 'BUG_HP_05',
    category: 'HP / DAMAGE',
    icon: '♥',
    trigger: 'HP 为 36 或以下时打出任意牌',
    reward: '恢复 1 Energy',
    risk: '失去 2 HP（无法格挡）',
  },
};

const BASE_DECK: Omit<Card, 'id'>[] = [
  { name: 'Compile Strike', code: 'compile()', art: '/card-art/compile-strike.webp', cost: 1, kind: 'attack', damage: 6 },
  { name: 'Hotfix', code: 'patch --quick', art: '/card-art/hotfix.webp', cost: 1, kind: 'skill', block: 6 },
  { name: 'Rubber Duck', code: 'explain(issue)', art: '/card-art/rubber-duck.webp', cost: 1, kind: 'skill', draw: 2 },
  { name: 'Refactor', code: 'clean(codebase)', art: '/card-art/refactor.webp', cost: 2, kind: 'attack', damage: 11 },
  { name: 'Cache Shield', code: 'memoize(defense)', art: '/card-art/cache-shield.webp', cost: 2, kind: 'skill', block: 12 },
  { name: 'Stack Trace', code: 'trace(stack)', art: '/card-art/stack-trace.webp', cost: 1, kind: 'attack', damage: 4, draw: 1 },
  { name: 'Rollback', code: 'git revert pain', art: '/card-art/rollback.webp', cost: 1, kind: 'skill', heal: 5 },
  { name: 'Garbage Collect', code: 'gc.collect()', art: '/card-art/garbage-collect.webp', cost: 1, kind: 'skill', damage: 4, block: 4 },
  { name: 'Pair Program', code: 'await teammate()', art: '/card-art/pair-program.webp', cost: 0, kind: 'skill', energy: 1 },
  { name: 'Overclock', code: 'cpu++', art: '/card-art/overclock.webp', cost: 2, kind: 'attack', damage: 15, selfDamage: 3 },
  { name: 'Unit Test', code: 'expect(safe)', art: '/card-art/unit-test.webp', cost: 1, kind: 'skill', block: 5, draw: 1 },
  { name: 'Ship It', code: 'deploy --force', art: '/card-art/ship-it.webp', cost: 3, kind: 'attack', damage: 22 },
];

const shuffle = <T,>(items: T[]) => {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
};

type Game = {
  playerHp: number;
  enemyHp: number;
  block: number;
  energy: number;
  turn: number;
  deck: Card[];
  discard: Card[];
  hand: Card[];
  bug: BugKey;
  bugTriggers: number;
  bugTurnTriggers: number;
  enemyStrength: number;
  energyDebt: number;
  attacksThisTurn: number;
  lastBugEvent: string | null;
  log: string[];
  status: 'playing' | 'won' | 'lost';
};

let nextCardId = 1;

function freshGame(randomize = true, forcedBug?: BugKey): Game {
  const sourceCards = BASE_DECK.map((card) => ({ ...card, id: nextCardId++ }));
  const cards = randomize ? shuffle(sourceCards) : sourceCards;
  const bugKeys = Object.keys(BUGS) as BugKey[];
  const bug = forcedBug ?? (randomize ? bugKeys[Math.floor(Math.random() * bugKeys.length)] : 'overflow');
  return {
    playerHp: 48,
    enemyHp: 72,
    block: 0,
    energy: 3,
    turn: 1,
    deck: cards.slice(5),
    discard: [],
    hand: cards.slice(0, 5),
    bug,
    bugTriggers: 0,
    bugTurnTriggers: 0,
    enemyStrength: 0,
    energyDebt: 0,
    attacksThisTurn: 0,
    lastBugEvent: null,
    log: [`ACTIVE BUG：${BUGS[bug].name}`, '每次触发都有 Reward 与 Risk。要贪到什么程度，由你决定。'],
    status: 'playing',
  };
}

function drawCards(game: Game, count: number) {
  const drawn: Card[] = [];
  for (let i = 0; i < count; i++) {
    if (!game.deck.length) {
      if (!game.discard.length) break;
      game.deck = shuffle(game.discard);
      game.discard = [];
      game.log.unshift('↻ discard.log 已重新载入 deck.memory');
    }
    const card = game.deck.shift();
    if (card) drawn.push(card);
  }
  game.hand.push(...drawn);
  return drawn.length;
}

function recordBug(game: Game, reward: string, risk: string) {
  game.bugTriggers += 1;
  game.bugTurnTriggers += 1;
  game.lastBugEvent = `+ ${reward}  /  − ${risk}`;
  game.log.unshift(`🐛 ${BUGS[game.bug].name} #${game.bugTriggers} // REWARD: ${reward} // RISK: ${risk}`);
}

function resolveCard(game: Game, card: Card) {
  if (card.damage) game.enemyHp = Math.max(0, game.enemyHp - card.damage);
  if (card.block) game.block += card.block;
  if (card.heal) game.playerHp = Math.min(48, game.playerHp + card.heal);
  if (card.selfDamage) game.playerHp = Math.max(0, game.playerHp - card.selfDamage);
  if (card.energy) game.energy += card.energy;
  if (card.draw) drawCards(game, card.draw);

  const effects = [
    card.damage ? `${card.damage} damage` : '',
    card.block ? `${card.block} block` : '',
    card.heal ? `${card.heal} repair` : '',
    card.draw ? `draw ${card.draw}` : '',
    card.energy ? `+${card.energy} energy` : '',
  ].filter(Boolean).join(' · ');
  game.log.unshift(`> ${card.name} // ${effects}`);
}

function enemyIntent(turn: number, strength: number) {
  const base = turn % 3 === 0 ? 12 : turn % 2 === 0 ? 9 : 7;
  return base + strength;
}

export default function Page() {
  const [game, setGame] = useState<Game>(() => freshGame(false));
  useEffect(() => {
    const requestedBug = new URLSearchParams(window.location.search).get('bug');
    const bugKeys = Object.keys(BUGS) as BugKey[];
    const forcedBug = bugKeys.find((key) => key === requestedBug);
    setGame(freshGame(!forcedBug, forcedBug));
  }, []);
  const bugInfo = BUGS[game.bug];
  const intent = enemyIntent(game.turn, game.enemyStrength);

  const playCard = (card: Card) => {
    if (game.status !== 'playing' || card.cost > game.energy) return;
    setGame((previous) => {
      const next: Game = structuredClone(previous);
      const played = next.hand.find((item) => item.id === card.id);
      if (!played || played.cost > next.energy) return previous;
      const handBefore = next.hand.length;
      const blockBefore = next.block;
      next.hand = next.hand.filter((item) => item.id !== card.id);
      next.energy -= played.cost;
      resolveCard(next, played);
      next.discard.push(played);

      if (played.kind === 'attack') next.attacksThisTurn += 1;

      if (next.bug === 'overflow' && played.cost > 0 && next.energy === 0) {
        drawCards(next, 2);
        next.energy += 1;
        next.enemyStrength += 1;
        recordBug(next, '抽 2，+1 Energy', '敌人 +1 攻击力');
      }

      if (next.bug === 'memory' && played.draw && handBefore >= 5) {
        drawCards(next, 2);
        next.playerHp = Math.max(0, next.playerHp - 2);
        recordBug(next, '额外抽 2', '失去 2 HP');
      }

      if (next.bug === 'hotPath' && played.kind === 'attack' && next.attacksThisTurn >= 2) {
        next.enemyHp = Math.max(0, next.enemyHp - 5);
        next.playerHp = Math.max(0, next.playerHp - 2);
        recordBug(next, '额外 5 伤害', '失去 2 HP');
      }

      if (next.bug === 'firewall' && played.block && blockBefore >= 5) {
        next.block += 8;
        next.energyDebt += 1;
        recordBug(next, '+8 Block', '下一回合 -1 Energy');
      }

      if (next.bug === 'bloodPact' && next.playerHp <= 36) {
        next.energy += 1;
        next.playerHp = Math.max(0, next.playerHp - 2);
        recordBug(next, '+1 Energy', '失去 2 HP');
      }

      if (next.playerHp <= 0) {
        next.status = 'lost';
        next.log.unshift('✕ PROCESS TERMINATED BY BUG RISK');
      } else if (next.enemyHp <= 0) {
        next.status = 'won';
        next.log.unshift('✓ PROD_DAEMON terminated. Build survived.');
      }
      return next;
    });
  };

  const endTurn = () => {
    if (game.status !== 'playing') return;
    setGame((previous) => {
      const next: Game = structuredClone(previous);
      const attack = enemyIntent(next.turn, next.enemyStrength);
      const damageTaken = Math.max(0, attack - next.block);
      next.playerHp = Math.max(0, next.playerHp - damageTaken);
      next.log.unshift(`! PROD_DAEMON 攻击 ${attack} // 损失 ${damageTaken} HP`);
      if (next.playerHp <= 0) {
        next.status = 'lost';
        next.log.unshift('✕ PROCESS TERMINATED');
        return next;
      }
      next.block = 0;
      next.turn += 1;
      next.energy = Math.max(0, 3 - next.energyDebt);
      if (next.energyDebt > 0) next.log.unshift(`⚠ ENERGY DEBT // 本回合 -${next.energyDebt} Energy`);
      next.energyDebt = 0;
      next.attacksThisTurn = 0;
      next.bugTurnTriggers = 0;
      next.lastBugEvent = null;
      drawCards(next, Math.max(0, 5 - next.hand.length));
      next.log.unshift(`— TURN ${next.turn} // Energy restored`);
      return next;
    });
  };

  const reset = () => setGame(freshGame());
  const canPlay = useMemo(() => game.hand.some((card) => card.cost <= game.energy), [game.hand, game.energy]);

  return (
    <main>
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark">B_</span>
          <div>
            <h1>BUGBOUND</h1>
            <p>roguelike deckbuilder // demo 2</p>
          </div>
        </div>
        <button className="ghost-button" onClick={reset}>↻ NEW RUN</button>
      </header>

      <section className="mission-line" aria-label="Demo goal">
        <span>MISSION</span>
        <p>触发 Bug → 领取 Reward → 承受 Risk → 决定还要不要继续贪</p>
        <span className="turn">TURN {String(game.turn).padStart(2, '0')}</span>
      </section>

      <div className="workspace">
        <section className="battle-panel">
          <div className="combatants">
            <div className="actor player">
              <div className="avatar" aria-hidden="true">{'{ }'}</div>
              <div className="actor-copy">
                <div className="eyebrow">PLAYER_PROCESS</div>
                <h2>Junior Dev</h2>
                <StatBar label="HP" value={game.playerHp} max={48} tone="green" />
                <div className="mini-stats"><span>🛡 {game.block} BLOCK</span><span>⚡ {game.energy}/3 ENERGY</span></div>
                {game.energyDebt > 0 && <div className="energy-debt">NEXT TURN −{game.energyDebt} ENERGY</div>}
              </div>
            </div>

            <div className="versus">VS</div>

            <div className="actor enemy">
              <div className="actor-copy">
                <div className="eyebrow danger">HOSTILE_PROCESS</div>
                <h2>Prod Daemon</h2>
                <StatBar label="HP" value={game.enemyHp} max={72} tone="red" />
                <div className="intent"><span>NEXT CALL</span><strong>⚔ {intent} DAMAGE</strong></div>
                {game.enemyStrength > 0 && (
                  <div className="enemy-mods">
                    <span>+{game.enemyStrength} STR</span>
                  </div>
                )}
              </div>
              <div className="avatar enemy-avatar" aria-hidden="true">☠</div>
            </div>
          </div>

          <div className="hand-zone">
            <div className="zone-heading">
              <div><span>HAND_BUFFER</span><small>{game.hand.length} cards · deck {game.deck.length} · discard {game.discard.length}</small></div>
              <button className="end-button" onClick={endTurn} disabled={game.status !== 'playing'}>
                END TURN <b>↵</b>
              </button>
            </div>

            <div className="cards" aria-label="Your hand">
              {game.hand.map((card, index) => {
                const disabled = card.cost > game.energy || game.status !== 'playing';
                return (
                  <button
                    key={card.id}
                    className={`card drawn-card ${card.kind}`}
                    style={{ '--draw-order': index } as CSSProperties}
                    disabled={disabled}
                    onClick={() => playCard(card)}
                  >
                    <span className="cost">{card.cost}</span>
                    <span className="kind">{card.kind.toUpperCase()}</span>
                    <span className="card-art" aria-hidden="true"><img src={card.art} alt="" /></span>
                    <strong>{card.name}</strong>
                    <code>{card.code}</code>
                    <span className="effect">{describeCard(card)}</span>
                    <span className="run">{disabled ? (game.status === 'playing' ? 'INSUFFICIENT ENERGY' : 'PROCESS LOCKED') : 'CLICK TO RUN'}</span>
                  </button>
                );
              })}
              {!game.hand.length && <div className="empty-hand">HAND_BUFFER EMPTY</div>}
            </div>
            {!canPlay && game.status === 'playing' && <p className="hint">没有可出的牌了——结束回合，让系统继续运行。</p>}
          </div>
        </section>

        <aside className="sidebar">
          <section className={`bug-monitor ${game.lastBugEvent ? 'triggered' : ''}`}>
            <div className="panel-title"><span>BUG_MONITOR // {bugInfo.category}</span><i className="pulse" /></div>
            <div className="bug-head">
              <div className="bug-symbol" aria-hidden="true">{bugInfo.icon}</div>
              <div><span>{bugInfo.code}</span><h3>{bugInfo.name}</h3></div>
            </div>
            <div className="bug-rule trigger"><span>TRIGGER</span><p>{bugInfo.trigger}</p></div>
            <div className="bug-rule reward"><span>REWARD</span><p>{bugInfo.reward}</p></div>
            <div className="bug-rule risk"><span>RISK</span><p>{bugInfo.risk}</p></div>
            <div className="trigger-count">
              <div><span>THIS TURN</span><strong>{game.bugTurnTriggers}</strong></div>
              <div><span>THIS BATTLE</span><strong>{game.bugTriggers}</strong></div>
            </div>
            {game.lastBugEvent && <div key={game.bugTriggers} className="bug-feedback">🐛 TRIGGERED #{game.bugTriggers}<small>{game.lastBugEvent}</small></div>}
            <p className="bug-note">只由你打出的牌触发；Bug 效果不会再次触发 Bug。</p>
          </section>

          <section className="terminal">
            <div className="panel-title"><span>RUNTIME_LOG</span><i className="live-dot" /></div>
            <div className="log-lines" aria-live="polite">
              {game.log.slice(0, 9).map((line, index) => <p key={`${line}-${index}`} className={line.includes('BUG') || line.includes('🐛') ? 'alert' : ''}>{line}</p>)}
            </div>
          </section>
        </aside>
      </div>

      {game.status !== 'playing' && (
        <div className="overlay" role="dialog" aria-modal="true">
          <div className={`result ${game.status}`}>
            <span>{game.status === 'won' ? 'BUILD PASSED' : 'FATAL ERROR'}</span>
            <h2>{game.status === 'won' ? '你让 Bug 为你工作了。' : '进程已崩溃。'}</h2>
            <p>{game.status === 'won' ? `本局 Bug：${bugInfo.name} · 共触发 ${game.bugTriggers} 次` : `本局 Bug：${bugInfo.name} · 触发 ${game.bugTriggers} 次。换一种贪法再试。`}</p>
            <button onClick={reset}>RUN AGAIN ↻</button>
          </div>
        </div>
      )}
    </main>
  );
}

function StatBar({ label, value, max, tone }: { label: string; value: number; max: number; tone: string }) {
  return (
    <div className="stat-wrap">
      <div className="stat-label"><span>{label}</span><strong>{value}/{max}</strong></div>
      <div className={`stat-bar ${tone}`}><i style={{ width: `${Math.max(0, value / max) * 100}%` }} /></div>
    </div>
  );
}

function describeCard(card: Card) {
  const parts = [];
  if (card.damage) parts.push(`造成 ${card.damage} 伤害`);
  if (card.block) parts.push(`获得 ${card.block} 格挡`);
  if (card.heal) parts.push(`修复 ${card.heal} HP`);
  if (card.draw) parts.push(`抽 ${card.draw} 张牌`);
  if (card.energy) parts.push(`获得 ${card.energy} Energy`);
  if (card.selfDamage) parts.push(`自身损失 ${card.selfDamage} HP`);
  return parts.join('。');
}
