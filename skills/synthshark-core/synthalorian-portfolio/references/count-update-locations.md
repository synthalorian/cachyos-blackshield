# Count Update Locations

After adding or removing a featured project, update **all three** of these:

## 1. HTML fallback (index.html, ~line 126)
```html
<div class="stat-card" data-stat="projects" data-fallback="13">
    <div class="stat-number" data-live="true">13</div>
```

## 2. JS counter (js/main.js, ~line 243)
```js
case 'projects': value = 13; break;
```

## 3. Verify
```bash
grep -c 'project-card' index.html     # should equal N
grep 'data-fallback' index.html | grep projects  # should equal N
grep "case 'projects'" js/main.js     # should equal N
```

All three must show the same number. The JS counter is what shows after the live GitHub API fetch; the HTML fallback shows before/during fetch.