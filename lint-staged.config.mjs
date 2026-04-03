import path from 'node:path';

const root = process.cwd();

function relTo(dirFromRoot, files) {
  const base = path.join(root, ...dirFromRoot.split('/'));
  return files.map((f) => path.relative(base, path.resolve(f)));
}

export default {
  '*.{json,md,css,yml,yaml,mjs,cjs}': ['prettier --write'],
  'apps/api/**/*.{ts,tsx}': (files) => {
    const rel = relTo('apps/api', files).join(' ');
    return rel
      ? [
          `pnpm --filter api exec eslint --fix --max-warnings 10 --no-warn-ignored ${rel}`,
          `prettier --write ${files.map((f) => JSON.stringify(f)).join(' ')}`,
        ]
      : [];
  },
  'apps/web/**/*.{ts,tsx}': (files) => {
    const rel = relTo('apps/web', files).join(' ');
    return rel
      ? [
          `pnpm --filter web exec eslint --fix --max-warnings 10 --no-warn-ignored ${rel}`,
          `prettier --write ${files.map((f) => JSON.stringify(f)).join(' ')}`,
        ]
      : [];
  },
  'packages/shared/**/*.ts': (files) => {
    const rel = relTo('packages/shared', files).join(' ');
    return rel
      ? [
          `pnpm --filter @repo/shared exec eslint --fix --max-warnings 10 --no-warn-ignored ${rel}`,
          `prettier --write ${files.map((f) => JSON.stringify(f)).join(' ')}`,
        ]
      : [];
  },
};
