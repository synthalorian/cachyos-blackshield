# External Resource Links — UI Pattern

SC:Synthesis is 100% offline but provides FleetYards.net links as a convenience for users
who want more detail (live pricing, community reviews, image galleries, patch status).

## Link Placement Rules

| Link Target | Screen | Placement | Widget |
|-------------|--------|-----------|--------|
| FleetYards ship page | Ship Detail | AppBar actions (info_outline icon) | `FleetYardsLink(uri, name)` |
| FleetYards ship page | Ship Compare | Below stat cards | `FleetYardsLink(uri, name)` |
| FleetYards ship page | Fleet screen | Integrated with remove/edit buttons | `FleetYardsLink(uri, name)` |
| FleetYards ship page | Ship List | Bottom of detail sheet or on-tap | launchUrl directly |
| Buy Me a Coffee | Settings | Dedicated card in links section | `BuyMeACoffeeButton()` |
| GitHub repo | Settings | Version card → "View on GitHub" | `openUrl()` |

## FleetYardsLink Widget

```dart
// core/widgets/fleetyards_link.dart
class FleetYardsLink extends StatelessWidget {
  final String uri;       // Full URL, e.g. 'https://fleetyards.net/ships/orig-100i'
  final String shipName;  // Display name for tooltip/accessibility

  const FleetYardsLink({super.key, required this.uri, required this.shipName});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.open_in_new),
      tooltip: 'View $shipName on FleetYards.net',
      onPressed: () => _openLink(context),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    try {
      await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }
}
```

**Key pattern:** Don't use `canLaunchUrl()`. Always use try/catch around `launchUrl()`.
See the url_launcher pitfall in the main SKILL.md for the full reasoning.

## When NOT to Add a FleetYards Link

- **Guide category detail sheets** — The guide shows reference data (factions, locations, commodities, components, stores). These don't have FleetYards equivalents.
- **Stanton map popups** — In-map location info popups are too small for an external link button.
- **Settings → Links section** — Instead, use dedicated buttons (GitHub, Buy Me a Coffee).

## BuyMeACoffeeButton Widget

```dart
// core/widgets/buy_me_a_coffee.dart
class BuyMeACoffeeButton extends StatelessWidget {
  const BuyMeACoffeeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.coffee),
      label: const Text('Buy me a coffee'),
      onPressed: () async {
        try {
          await launchUrl(
            Uri.parse('https://buymeacoffee.com/...'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
      },
    );
  }
}
```
