// Resolve the highest published version of @deepseek-ai/dsh on npm.
// Tracks the newest publish across ALL dist-tags (latest / next / alpha / ...),
// so dev previews published on the alpha channel are still picked up.
// Usage: node latest-dsh-version.mjs
import { execSync } from 'node:child_process';

const json = execSync('npm view @deepseek-ai/dsh versions --json', { encoding: 'utf8' });
const versions = JSON.parse(json);

const parse = (v) => {
  const m = /^(\d+)\.(\d+)\.(\d+)(?:-(?:([a-zA-Z]+)\.)?(\d+))?$/.exec(v);
  if (!m) return null;
  return { core: [+m[1], +m[2], +m[3]], pre: m[4] ?? '', preN: m[5] ? +m[5] : 0, raw: v };
};

const cmp = (a, b) => {
  for (let i = 0; i < 3; i++) {
    if (a.core[i] !== b.core[i]) return a.core[i] - b.core[i];
  }
  if (!a.pre && !b.pre) return 0;
  if (!a.pre) return 1; // release > prerelease
  if (!b.pre) return -1;
  if (a.pre !== b.pre) return a.pre < b.pre ? -1 : 1;
  return a.preN - b.preN;
};

const parsed = versions.map(parse).filter(Boolean);
parsed.sort(cmp);
console.log(parsed[parsed.length - 1].raw);