const fs = require('fs');
const path = require('path');

// Post-build rewrite of absolute asset paths to relative.
// SvelteKit's adapter-static emits build/index.html with paths like
//   /_app/immutable/entry/start.XXXX.js
//   /favicon.png
// These 404 when loaded from file:// in a Tauri release build.
// This script converts them to ./_app/... and ./favicon.png etc.

const indexPath = path.join(__dirname, '..', 'build', 'index.html');
const html = fs.readFileSync(indexPath, 'utf8');

const fixed = html
  .replaceAll('="/_app/', '="./_app/')
  .replaceAll('="/favicon.png"', '="./favicon.png"')
  .replaceAll('="/svelte.svg"', '="./svelte.svg"')
  .replaceAll('="/tauri.svg"', '="./tauri.svg"')
  .replaceAll('="/vite.svg"', '="./vite.svg"');

if (fixed !== html) {
  fs.writeFileSync(indexPath, fixed, 'utf8');
  console.log('Fixed asset paths in build/index.html');
} else {
  console.log('No path fixes needed');
}
