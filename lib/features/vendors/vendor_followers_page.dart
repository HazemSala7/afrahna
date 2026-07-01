import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/services.dart';
import '../../core/theme.dart';

/// Shows a vendor owner the list of users who follow their shop + the count.
class VendorFollowersPage extends StatefulWidget {
  const VendorFollowersPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<VendorFollowersPage> createState() => _VendorFollowersPageState();
}

class _VendorFollowersPageState extends State<VendorFollowersPage> {
  late Future<({List<UserModel> users, int total})> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = VendorService().followers(widget.vendorId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المتابعون')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: FutureBuilder<({List<UserModel> users, int total})>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final e = snap.error;
              return ListView(children: [
                const SizedBox(height: 80),
                Center(
                    child:
                        Text(e is ApiException ? e.message : e.toString())),
              ]);
            }
            final users = snap.data?.users ?? const <UserModel>[];
            final total = snap.data?.total ?? users.length;
            return Column(
              children: [
                _CountHeader(total: total),
                Expanded(
                  child: users.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 100),
                          Icon(Icons.group_outlined,
                              size: 56, color: AppColors.primary),
                          SizedBox(height: 10),
                          Center(child: Text('لا يوجد متابعون بعد')),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _FollowerTile(user: users[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$total',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'إجمالي المتابعين',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowerTile extends StatelessWidget {
  const _FollowerTile({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (user.avatar ?? '').isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: hasAvatar ? NetworkImage(user.avatar!) : null,
            child: hasAvatar
                ? null
                : Text(
                    user.name.isNotEmpty
                        ? user.name.characters.first.toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isNotEmpty ? user.name : 'مستخدم',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                if (user.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phone,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
