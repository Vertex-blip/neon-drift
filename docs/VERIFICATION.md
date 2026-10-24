# Verification

The user story is: load the locally hosted 3D assets → choose a mode → start from a real pointer action → drive using keyboard or touch → complete the session → retain the personal record on the same browser.

## Automated simulation checks

12 Node tests cover acceleration/braking, mirrored steering, handbrake slip and recovery, frame-rate consistency, checkpoint order, two complete laps, combo caps, 90-second expiry, barrier momentum, time formatting and minute rollover, and drift scoring at different frame rates.

## Browser checks

Chrome DevTools Protocol drives actual pointer and keyboard events against the production Vite preview. The checks do not mutate the running car or race state. A read-only diagnostic snapshot exposes the current state for assertions.

- Desktop assets and controls at 1440 × 900.
- Paint selection and browser persistence.
- Both graphics settings.
- AudioContext activation from a real pointer event, plus mute toggle.
- Throttle movement, handbrake drift and recovery penalty.
- Paused simulation time, photo mode, instructions pausing play.
- Portrait menu at 390 × 844.
- Portrait gameplay blocks and displays rotation guidance.
- Landscape play at 844 × 390, pointer controls, and recovery from the pause menu.
- A full 90-second drift session ending in a result screen.
- A complete ordered 32-checkpoint, two-lap run using only steering/throttle/brake input.
- Personal record survives a page reload.

Screenshots in this directory are real browser captures. No uncaught JavaScript exceptions were observed in the completed test runs.

The final production-preview run completed all **32 checkpoints in 66.68 seconds**, with lap times **34.55 / 32.13 seconds** and no recovery penalty. Its saved time was unchanged after a full page reload. The interaction suite passed **18 browser assertions**, including the landscape fallback, and all **12 simulation tests** passed.

## Practical limits

Mobile layout and touch-style pointer input were tested in Chrome viewport emulation, not on a physical iPhone or Android handset. Fullscreen and orientation-lock availability depend on the browser, so a manual-rotation fallback is included. Web Audio startup and mute state were checked; audio was not evaluated through a physical speaker setup. Frame rate varies with GPU, browser and display resolution. This is arcade handling, not a real-world vehicle dynamics validation.

CI runs `npm ci`, `npm test` and `npm run build` before deploying GitHub Pages.
