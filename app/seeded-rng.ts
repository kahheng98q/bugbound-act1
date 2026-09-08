export type SeededRng = { seed: string; state: number; calls: number };

export function normalizeSeed(value: string) {
  const cleaned = value.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '').slice(0, 24);
  return cleaned || 'DEBUG-0001';
}

export function seedToState(seed: string) {
  let hash = 2166136261;
  for (const character of normalizeSeed(seed)) {
    hash ^= character.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0 || 0x6d2b79f5;
}

export function createRng(seed: string): SeededRng {
  const normalized = normalizeSeed(seed);
  return { seed: normalized, state: seedToState(normalized), calls: 0 };
}

export function nextRandom(rng: SeededRng) {
  const state = (rng.state + 0x6d2b79f5) >>> 0;
  let value = state;
  value = Math.imul(value ^ (value >>> 15), value | 1);
  value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
  const random = ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  return { value: random, rng: { ...rng, state, calls: rng.calls + 1 } };
}

export function randomInt(rng: SeededRng, maxExclusive: number) {
  const result = nextRandom(rng);
  return { value: Math.floor(result.value * maxExclusive), rng: result.rng };
}

export function shuffleSeeded<T>(items: T[], rng: SeededRng) {
  const copy = [...items];
  let cursor = rng;
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const roll = randomInt(cursor, index + 1);
    cursor = roll.rng;
    [copy[index], copy[roll.value]] = [copy[roll.value], copy[index]];
  }
  return { items: copy, rng: cursor };
}

export function pickSeeded<T>(items: readonly T[], rng: SeededRng) {
  const roll = randomInt(rng, items.length);
  return { item: items[roll.value], rng: roll.rng };
}
