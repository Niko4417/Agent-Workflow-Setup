# Target-side templates (apply with maintainer coordination)

These touch the **target repo's committed files** (`package.json`, `.husky/`,
`.github/`). On `oscharko-dev/Keiko` that means a PR for the maintainer — do not
apply unilaterally. They are kept here as ready-to-apply snippets.

What's already usable WITHOUT touching the target repo:

- `scripts/verify.sh` — local CI mirror (invokes existing npm scripts; no
  `package.json` change). Run from the Keiko root before opening a PR.

## 1. lint-staged (fast pre-commit on changed files)

Add to the target `package.json` (see `lint-staged.config.json`), then:

```bash
npm i -D husky lint-staged
npx husky init
cp templates/husky-pre-commit <target>/.husky/pre-commit
```

## 2. pre-commit hook

`husky-pre-commit` runs lint-staged + a secret scan on staged files.

## 3. PR template evidence section

Append `pr-template-evidence.md` to `.github/pull_request_template.md` so every
PR carries verification evidence (commands, test output, CI links).
