import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { deterministicPreview, generateAct1Map } from '../app/act1-generation.ts';
import { createRng, nextRandom, normalizeSeed, shuffleSeeded } from '../app/seeded-rng.ts';

function gameplayTrace(seed) {
  let rng = createRng(seed);
  const map = generateAct1Map(rng); rng = map.rng;
  const deck = shuffleSeeded(['strike', 'strike', 'hotfix', 'duck', 'pair', 'test'], rng); rng = deck.rng;
  const rewards = shuffleSeeded(['trace', 'rollback', 'cache', 'ship', 'gc'], rng); rng = rewards.rng;
  const enemyRolls = [];
  for (let index = 0; index < 8; index += 1) { const result = nextRandom(rng); rng = result.rng; enemyRolls.push(result.value) }
  return { map: map.nodes, openingHand: deck.items.slice(0, 5), rewards: rewards.items.slice(0, 3), enemyRolls, finalRng: rng };
}

test('same seed and same operation sequence produces an identical complete trace', () => {
  assert.deepEqual(gameplayTrace('BUG-404-LOL'), gameplayTrace('bug-404-lol'));
});

test('different seeds produce different Act 1 worlds', () => {
  assert.notEqual(deterministicPreview(createRng('ALPHA')).signature, deterministicPreview(createRng('OMEGA')).signature);
});

test('Act 1 offers ten planned route tiers before Antivirus', () => {
  const { nodes } = generateAct1Map(createRng('MAP-CHECK'));
  assert.equal(nodes.filter((node) => node.tier < 10 && node.kind !== 'secret').length, 20);
  assert.equal(nodes.filter((node) => node.kind === 'boss' && node.tier === 10).length, 1);
  assert.equal(nodes.filter((node) => node.anomaly).length > 0, true);
});

test('seed input is normalized for reliable sharing', () => {
  assert.equal(normalizeSeed('  bug 404!!  '), 'BUG404');
});

test('gameplay source contains no unseeded Math.random calls', () => {
  const files = ['../app/page.tsx', '../app/bug-engine.ts', '../app/act1-generation.ts', '../app/seeded-rng.ts'];
  for (const file of files) assert.doesNotMatch(readFileSync(new URL(file, import.meta.url), 'utf8'), /Math\.random\s*\(/, file);
});
