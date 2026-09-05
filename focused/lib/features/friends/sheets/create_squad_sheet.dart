import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../models/friend_user.dart';
import '../../../providers/account_provider.dart';
import '../../../providers/friends_provider.dart';
import '../../../providers/task_mate_provider.dart';

void showCreateGroupDialog(BuildContext context) {
    final friendsProvider = context.read<FriendsProvider>();
    final taskMateProvider = context.read<TaskMateProvider>();
    final account = context.read<AccountProvider>();
    final myUid = account.user?.uid ?? '';
    final friends = friendsProvider.following
        .where((f) => f.uid != myUid)
        .toList();

    final nameController = TextEditingController();
    final selectedFriends = <FriendUser>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scheme = Theme.of(context).colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2B3D47)
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        SvgPicture.asset(
                          'assets/icon/group_icon.svg',
                          width: 26,
                          height: 26,
                          colorFilter: ColorFilter.mode(
                            scheme.primary,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create Task Squad',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Partner with up to 4 friends (up to 5 members total). Squad members can share up to 3 active tasks and earn double EXP (+200 EXP)!',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF77878F)
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Squad Name',
                        hintText: 'e.g. Focus Duo, Daily Grind',
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose up to 4 Friends (${selectedFriends.length}/4):',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'You have not followed any friends yet. Follow friends first to create a squad!',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF77878F)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final f = friends[i];
                            final isSelected = selectedFriends.any(
                              (sf) => sf.uid == f.uid,
                            );

                            return CheckboxListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              tileColor: scheme.surfaceContainerHigh,
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFF58CC02),
                                backgroundImage:
                                    f.photoUrl != null && f.photoUrl!.isNotEmpty
                                    ? NetworkImage(f.photoUrl!)
                                    : null,
                                onBackgroundImageError: f.photoUrl != null
                                    ? (_, __) {}
                                    : null,
                                child: f.photoUrl == null || f.photoUrl!.isEmpty
                                    ? Text(
                                        f.displayName.isNotEmpty
                                            ? f.displayName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                f.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : scheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                f.handle,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFF77878F)
                                      : scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              value: isSelected,
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    if (selectedFriends.length < 4) {
                                      selectedFriends.add(f);
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Maximum 4 friends can be added (5 members total).',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  } else {
                                    selectedFriends.removeWhere(
                                      (sf) => sf.uid == f.uid,
                                    );
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1CB0F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: selectedFriends.isEmpty
                            ? null
                            : () async {
                                final squadName =
                                    nameController.text.trim().isEmpty
                                    ? 'Task Squad'
                                    : nameController.text.trim();
                                Navigator.pop(ctx);
                                final ok = await taskMateProvider.createGroup(
                                  name: squadName,
                                  selectedFriends: selectedFriends,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: ok
                                          ? const Color(0xFF58CC02)
                                          : Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        ok
                                            ? '🎉 Squad "$squadName" created!'
                                            : 'Could not create squad. Max 3 groups allowed.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: const Text(
                          'Create Squad',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }