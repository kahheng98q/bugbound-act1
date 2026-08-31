import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { advanceBugProgress, BUGS, nextBugKey } from '../app/bug-engine.ts';

const action = (overrides = {}) => ({
  cardKind: 'skill',
  cost: 1,
  blockGained: 0,
  cardsDrawn: 0,
  energyAfterSpend: 2,
  ...overrides,
});

test('every Bug trigger is reachable by the starter deck', () => {
  const pageSource = readFileSync(new URL('../app/page.tsx', import.meta.url), 'utf8');
  assert.match(pageSource, /key: 'strike'.*cost: 1, kind: 'attack'/);
  assert.match(pageSource, /key: 'hotfix'.*cost: 1, kind: 'skill', block: 6/);
  assert.match(pageSource, /key: 'duck'.*cost: 1, kind: 'skill', draw: 2/);
  assert.match(pageSource, /const STARTER_DECK = \['strike'.*'hotfix'.*'duck'.*'pair'\]/);

  assert.equal(advanceBugProgress('overflow', 0, action({ energyAfterSpend: 0 })).triggered, true);
  assert.equal(advanceBugProgress('memory', 0, action({ cardsDrawn: 2 })).triggered, true);
  assert.equal(advanceBugProgress('firewall', 0, action({ blockGained: 6 })).triggered, true);

  const firstAttack = advanceBugProgress('hotPath', 0, action({ cardKind: 'attack' }));
  const secondAttack = advanceBugProgress('hotPath', firstAttack.progress, action({ cardKind: 'attack' }));
  assert.equal(firstAttack.triggered, false);
  assert.equal(secondAttack.triggered, true);

  let loopProgress = 0;
  for (let index = 0; index < 3; index += 1) loopProgress = advanceBugProgress('loop', loopProgress, action()).progress;
  assert.equal(loopProgress, 3);
  assert.equal(advanceBugProgress('loop', 2, action()).triggered, true);
});

test('mutation never repeats the current Trigger', () => {
  for (const bug of Object.keys(BUGS)) {
    assert.notEqual(nextBugKey(bug, () => 0), bug);
    assert.notEqual(nextBugKey(bug, () => 0.999999), bug);
  }
});

test('a new Trigger starts from zero but can trigger later in the same turn', () => {
  const hotPathFirst = advanceBugProgress('hotPath', 0, action({ cardKind: 'attack' }));
  const hotPathSecond = advanceBugProgress('hotPath', hotPathFirst.progress, action({ cardKind: 'attack' }));
  assert.equal(hotPathSecond.triggered, true);

  // Mutation resets progress. The triggering attack is not reused by the new Bug.
  let loopProgress = 0;
  assert.equal(loopProgress, 0);
  for (let index = 0; index < 2; index += 1) {
    const result = advanceBugProgress('loop', loopProgress, action());
    loopProgress = result.progress;
    assert.equal(result.triggered, false);
  }
  assert.equal(advanceBugProgress('loop', loopProgress, action()).triggered, true);
});

test('Block and Draw triggers do not depend on prior turn state', () => {
  assert.equal(advanceBugProgress('firewall', 99, action({ blockGained: 4 })).triggered, false);
  assert.equal(advanceBugProgress('firewall', 0, action({ blockGained: 5 })).triggered, true);
  assert.equal(advanceBugProgress('memory', 99, action()).triggered, false);
  assert.equal(advanceBugProgress('memory', 0, action({ cardsDrawn: 1 })).triggered, true);
});
