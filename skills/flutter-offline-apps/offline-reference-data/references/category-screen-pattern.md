# Category Hub Screen Pattern

Pattern for a reference guide hub with category cards that navigate to detail views.

## Data Flow
```
Bundled JSON (assets/data/) → Dart Service (ReferenceDatabase) → Category Hub Screen → Detail Screen → Item Bottom Sheet
```

## Hub Screen Structure

### Category Model
```dart
class _Category {
  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}
```

### Responsive Grid Layout
```dart
GridView.count(
  crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
  childAspectRatio: 1.1,
  padding: EdgeInsets.all(16),
  children: categories.map((cat) => _CategoryCard(...)).toList(),
)
```

### Glassmorphism Card
```dart
Card(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(color: iconColor.withValues(alpha: 0.2)),
  ),
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [surface.withValues(alpha: 0.7), surface, surface.withValues(alpha: 0.85)],
      ),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(cat.icon, color: iconColor, size: 28),
          ),
          Text(cat.title, style: titleSmall),
          Text(cat.subtitle, style: bodySmall),
        ],
      ),
    ),
  ),
)
```

## Navigation Routing

### Special Cases
When one category needs a different screen (e.g., Locations → Interactive Map):

```dart
void _openCategory(_Category category) {
  // Special case route
  if (category.id == 'locations') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StantonMapScreen()));
    return;
  }
  // Generic route
  Navigator.push(context, MaterialPageRoute(builder: (_) => GuideCategoryScreen(items: data)));
}
```

## Detail Bottom Sheet (Item Tap)

Show `showModalBottomSheet` with:
- Rounded top (BorderRadius.vertical(top: Radius.circular(20)))
- Name + type badge (color-coded)
- Category-specific fields (reputation tiers, reward range, services, price)
- Description text
- Close button

Use `resolveTypeLabel` and `resolveTypeColor` helpers to render badges dynamically based on the item's field content (type, isIllegal flag, etc.).
