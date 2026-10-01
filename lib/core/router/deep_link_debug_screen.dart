import 'package:flutter/material.dart';
import 'package:perfinance/core/router/deep_link_debug_log.dart';

/// Reachable via `perfinance://debug` — shows every deep link the app has
/// received this session, for debugging the Apple Pay Shortcuts automation.
class DeepLinkDebugScreen extends StatelessWidget {
  const DeepLinkDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: deep links')),
      body: ValueListenableBuilder<List<DeepLinkEvent>>(
        valueListenable: DeepLinkDebugLog.instance,
        builder: (context, events, _) {
          if (events.isEmpty) {
            return const Center(child: Text('Todavía no llegó ningún deep link.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final e = events[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.receivedAt.toIso8601String(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    e.uri.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                  if (e.uri.queryParameters.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...e.uri.queryParameters.entries.map(
                      (kv) => Text('${kv.key}: ${kv.value}', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
