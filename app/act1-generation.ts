import { nextRandom, pickSeeded } from './seeded-rng.ts';
import type { SeededRng } from './seeded-rng.ts';

export type EnemyKey = 'folder' | 'cursor' | 'trash' | 'frozen' | 'memoryHog' | 'antivirus';
export type NodeKind = 'battle' | 'elite' | 'event' | 'boss' | 'secret';
export type EventKey = 'update' | 'unknownExe' | 'recursiveFolder' | 'printerGhost' | 'secretRoot';
export type MapNode = { id: string; tier: number; lane: number; kind: NodeKind; enemy?: EnemyKey; event?: EventKey; label: string; path: string; anomaly?: boolean; hidden?: boolean };

const BATTLES: { enemy: EnemyKey; label: string; path: string }[] = [
  { enemy: 'folder', label: 'Documents', path: 'C:\\Desktop\\Documents' },
  { enemy: 'cursor', label: 'Pointer Cache', path: 'C:\\Desktop\\System32' },
  { enemy: 'trash', label: 'Recycle Bin', path: 'C:\\Desktop\\$Recycle.Bin' },
  { enemy: 'frozen', label: 'Frozen App', path: 'C:\\Desktop\\Programs' },
];
const EVENTS: { event: EventKey; label: string; path: string }[] = [
  { event: 'update', label: 'System Update', path: 'C:\\Desktop\\Updates' },
  { event: 'unknownExe', label: 'Unknown.exe', path: 'C:\\Desktop\\Downloads' },
  { event: 'recursiveFolder', label: 'Folder (1) (1)', path: 'C:\\Desktop\\Desktop' },
  { event: 'printerGhost', label: 'Offline Printer', path: 'C:\\Desktop\\Devices' },
];

export function generateAct1Map(initialRng: SeededRng) {
  let rng = initialRng;
  const nodes: MapNode[] = [];
  for (let tier = 0; tier < 10; tier += 1) {
    for (let lane = 0; lane < 2; lane += 1) {
      const kindRoll = nextRandom(rng); rng = kindRoll.rng;
      const forceBattle = tier === 0 || (lane === 0 && tier < 3);
      const kind: NodeKind = forceBattle ? 'battle' : kindRoll.value < 0.2 ? 'event' : kindRoll.value < 0.34 && tier > 2 ? 'elite' : 'battle';
      if (kind === 'event') {
        const pick = pickSeeded(EVENTS, rng); rng = pick.rng;
        const anomalyRoll = nextRandom(rng); rng = anomalyRoll.rng;
        const anomaly = anomalyRoll.value < 0.22;
        nodes.push({ id: `t${tier}l${lane}`, tier, lane, kind, event: anomaly ? 'unknownExe' : pick.item.event, label: anomaly ? 'CORRUPTED ROUTE' : pick.item.label, path: anomaly ? 'C:\\Desktop\\???\\..\\YOU' : pick.item.path, anomaly });
      } else if (kind === 'elite') {
        nodes.push({ id: `t${tier}l${lane}`, tier, lane, kind, enemy: 'memoryHog', label: 'Memory Hog', path: 'C:\\Desktop\\TaskManager' });
      } else {
        const available = tier < 3 ? BATTLES.slice(0, 2) : BATTLES;
        const pick = pickSeeded(available, rng); rng = pick.rng;
        nodes.push({ id: `t${tier}l${lane}`, tier, lane, kind, ...pick.item });
      }
    }
  }
  const secretRoll = nextRandom(rng); rng = secretRoll.rng;
  nodes.push({ id: 'secret-root', tier: 8, lane: 2, kind: 'secret', event: 'secretRoot', label: 'C:\\Users\\???', path: 'ACCESS_REDACTED', anomaly: true, hidden: secretRoll.value >= 0.12 });
  nodes.push({ id: 'boss', tier: 10, lane: 0, kind: 'boss', enemy: 'antivirus', label: 'Security Center', path: 'C:\\Desktop\\Security' });
  return { nodes, rng };
}

export function deterministicPreview(seedRng: SeededRng) {
  const generated = generateAct1Map(seedRng);
  return {
    signature: generated.nodes.map((node) => `${node.tier}:${node.kind}:${node.enemy ?? node.event}:${node.anomaly ? 1 : 0}`).join('|'),
    rng: generated.rng,
  };
}
