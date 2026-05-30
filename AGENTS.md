# Agent Guidelines :)

## iOS Iteration Workflow

- After every iOS app change iteration, run `npm run ios:install` first to build and install the freshly changed app on Eryu's phone.
- Prefer `npm run ios:install` over direct simulator or `xcrun simctl install` commands so the repository script controls the phone target and install behavior.
- If `npm run ios:install` cannot install on the phone, pause and ask whether Eryu wants to build/install to an iOS Simulator instead.
