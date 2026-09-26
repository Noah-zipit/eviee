import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../history/database.dart';
import '../providers/app_providers.dart';
import '../chat/chat_screen.dart';
import '../chat/chat_session.dart';
import '../home/home_screen.dart';

/// Sidebar: conversation history, newest first, with search and delete.
class ConversationsDrawer extends ConsumerStatefulWidget {
  const ConversationsDrawer({super.key});

  @override
  ConsumerState<ConversationsDrawer> createState() =>
      _ConversationsDrawerState();
}

class _ConversationsDrawerState extends ConsumerState<ConversationsDrawer> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(themeTokensProvider);
    final db = ref.watch(appDatabaseProvider);

    return Drawer(
      backgroundColor: t.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Chats', style: uiStyle(t, weight: FontWeight.w700, size: 18)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New chat',
                    icon: Icon(Icons.add_circle_outline, color: t.accent),
                    onPressed: () {
                      ref.read(chatSessionProvider.notifier).newSession();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                style: uiStyle(t, size: 14),
                decoration: InputDecoration(
                  hintText: 'Search chats…',
                  prefixIcon:
                      Icon(Icons.search_outlined, color: t.foreground2, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Conversation>>(
                future: db.searchConversations(_query),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text('No conversations yet.',
                          style: uiStyle(t, size: 13, color: t.foreground2)),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final c = items[i];
                      return Dismissible(
                        key: ValueKey(c.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: const Color(0xFFEF4444),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await db.deleteConversation(c.id);
                          if (context.mounted) setState(() {});
                          return false;
                        },
                        child: ListTile(
                          title: Text(c.title,
                              style: uiStyle(t, size: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            DateFormat('MMM d, HH:mm').format(c.updatedAt),
                            style: monoStyle(t, size: 10.5),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 17, color: t.foreground2),
                            onPressed: () async {
                              await db.deleteConversation(c.id);
                              setState(() {});
                            },
                          ),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref
                                .read(chatSessionProvider.notifier)
                                .openConversation(c.id);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ChatScreen()),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
