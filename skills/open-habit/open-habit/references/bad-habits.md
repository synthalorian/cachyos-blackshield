# Bad Habits (Quit Tracking) Reference

## How it works

Bad habits use a **marker prefix** pattern — no schema changes needed.

The backend stores bad habits with the name prefixed by `🚫 `. The frontend strips this prefix when displaying and uses it to detect bad habits.

## Creating a bad habit

From the Flutter UI (Habits tab), toggle the Build/Quit switch in the add dialog. This calls `HabitNotifier.addBadHabit()`:

```dart
await notifier.addBadHabit("Smoking", "General", 10);
// Stored in DB as: name="🚫 Smoking", category="General", xp=10
```

## Detection & display flow

```dart
// In HabitNotifier._toUiHabit():
final name = h.name;
Habit(
  name: name.startsWith('🚫 ') ? name.substring(2) : name,  // Strip prefix
  completed: completed,
  isBad: name.startsWith('🚫 '),                              // Detect bad
);
```

## Card rendering (habit_card.dart)

Visual differences from healthy habits:
- `accentColor` = `Color(0xFFFF007F)` (neon magenta) instead of category color
- Emoji badge uses the same rose accent
- Check button shows `Icons.block_rounded` instead of `Icons.check_rounded`
- "QUIT" label appears as a small pill badge above the habit name
- XP badge shows shield: `'+${habit.xp} 🛡️'`
- Completed text gets strike-through

## XP model

Bad habits award the same XP as Easy difficulty (10 XP). The psychological framing is reversed:
- Healthy habit: "I did the thing → +10 XP"
- Bad habit: "I resisted the thing → +10 XP"
- Same streak tracking, same achievement unlocks

## Adding to the suggestion list

In `habit_categories.dart`, `HabitLibrary.habits` includes bad habits like:
```dart
SuggestedHabit(name: 'No Smoking', category: 'General', 
    description: 'One day without smoking', difficulty: 'Hard', emoji: '🚭'),
SuggestedHabit(name: 'No Social Media', category: 'Productivity',
    description: 'No social media today', difficulty: 'Hard', emoji: '📵'),
```

The Bad Habit guide in Settings (`_BadHabitsGuideScreen`) shows 10 suggestions.

## Limitations

- Bad habits don't have a separate DB flag or API field — they rely entirely on the `🚫 ` prefix convention
- Cannot distinguish "completed" (resisted today) from "missed" without checking the date
- XP is identical to Easy habits — a system where bad habits give scaled XP based on streak length would be more motivational
