# Contributing

Run `npm ci`, `npm test`, and `npm run build` on Node.js 22.12+. For driving changes, test keyboard and touch input, pause on focus loss, recovery penalties, checkpoint order and a full two-lap finish. For visuals, check desktop and mobile screenshots and both quality settings. Preserve original asset attribution and avoid committing credentials, dependency folders, or generated builds.

Gameplay rules live in `src/game.js`, independent of WebGL. Prefer deterministic tests for scoring and physics changes. Browser diagnostics are available as the read-only `window.__NEON__` snapshot; it cannot alter the simulation.
