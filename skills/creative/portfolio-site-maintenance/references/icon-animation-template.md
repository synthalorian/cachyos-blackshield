# Icon Animation Patterns

Every project icon (`.icon-XXXX`) needs a CSS animation. Add it in `css/style.css` before the `/* Hover boost */` comment (~line 1095).

## Patterns by Icon Type

### Bars/Waveform (icon-synth)
Staggered `barBounce` — each path child scales its Y with staggered delays.
```css
.icon-XXXX svg path {
  transform-origin: center bottom;
  animation: barBounce 1.6s ease-in-out infinite;
}
.icon-XXXX svg path:nth-child(1) { animation-delay: 0.0s; }
.icon-XXXX svg path:nth-child(2) { animation-delay: 0.15s; }
/* etc for each child */
```

### Sound Wave Pulse (icon-amp)
Opacity pulse on wave arc paths — staggered delays.
```css
.icon-XXXX svg path:nth-child(2),
.icon-XXXX svg path:nth-child(3) {
  animation: wavePulse 1.4s ease-in-out infinite;
  transform-origin: right center;
}
.icon-XXXX svg path:nth-child(2) { animation-delay: 0s; }
.icon-XXXX svg path:nth-child(3) { animation-delay: 0.25s; }
```

### Whole-SVG Transform (icon-wing, icon-janus, icon-forge, icon-bible, icon-rocket, icon-heart, icon-beacon, icon-sword)
Apply animation to the whole `<svg>` element with `transform-origin: center center`.
```css
.icon-XXXX svg {
  animation: XXXXAnim 2.5s ease-in-out infinite;
  transform-origin: center center;
}
```
Pick an animation that matches the icon's concept:
- Rotation/tilt: `transform: rotate(...)` — icon-janus, icon-forge
- Scale: `transform: scale(...)` or `scaleX(...)` — icon-bible, icon-psalm, icon-heart
- Translation: `transform: translateY(...)` — icon-rocket
- Opacity: `opacity: ...` — icon-sword
- Continuous spin: `transform: rotate(360deg)` — icon-beacon

### Node Pulse (icon-mesh)
Target `<circle>` elements with staggered delays.
```css
.icon-XXXX svg circle {
  animation: nodePulse 2s ease-in-out infinite;
  transform-origin: center center;
}
.icon-XXXX svg circle:nth-child(1) { animation-delay: 0s; }
/* etc */
```

### Tick-Tock Wobble (icon-clock)
```css
.icon-XXXX svg {
  animation: clockTick 3s ease-in-out infinite;
  transform-origin: 12px 12px;
}
@keyframes clockTick {
  0%, 100% { transform: rotate(0deg); }
  20% { transform: rotate(3deg); }
  40% { transform: rotate(-2deg); }
  60% { transform: rotate(1deg); }
  80% { transform: rotate(-0.5deg); }
}
```

## Universal Rules

- All animations get `animation-duration: 0.6s !important` on `.project-card:hover .project-icon svg`
- All get paused in `@media (prefers-reduced-motion: reduce)`
- Add the new keyframes after the icon class block
- Document the animation with a comment: `/* Description of animation */`
