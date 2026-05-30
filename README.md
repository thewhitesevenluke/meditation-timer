# Golden Meditation

Golden Meditation is an iOS-first meditation timer. The production iPhone app is native SwiftUI, while the React + Vite code lives under `web/` as the web layer.

## Start Here

- iOS app notes: [`ios/README.md`](ios/README.md)
- Web source: [`web/`](web/)

## Common Commands

```sh
npm install
npm run build
npm run ios:sync
npm run ios:open
```

## Web Deployment

For Vercel, keep the project root at the repository root. `vercel.json` sets the build command to `npm run build` and the output directory to `web/dist`.
