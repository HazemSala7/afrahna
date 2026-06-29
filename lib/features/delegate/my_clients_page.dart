import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';
import '../../core/services/services.dart';
import '../../core/state/session.dart';
import '../vendors/edit_vendor_page.dart';

class MyClientsPage extends StatefulWidget {
  const MyClientsPage({super.key});

  @override
  State<MyClientsPage> createState() => _MyClientsPageState();
}

class _MyClientsPageState extends State<MyClientsPage> {
  final _service = DelegateService();
  late Future<List<UserModel>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _service.myClients();
  }

  void _refresh() {
    setState(() => _future = _service.myClients(search: _search));
  }

  /// Open the client's shop (vendor) for full editing. Requires the delegate
  /// to hold the `edit_vendor` permission (admins always allowed).
  Future<void> _editClient(UserModel client) async {
    final me = context.read<SessionController>().user;
    final canEdit = me != null && me.hasPermission('edit_vendor');
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية تعديل بيانات المعلن')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final vendors = await VendorService().list(
        userId: client.id,
        activeOnly: false,
        perPage: 1,
      );
      if (!mounted) return;
      Navigator.pop(context); // close spinner
      if (vendors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد محل مرتبط بهذا المعلن بعد')),
        );
        return;
      }
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditVendorPage(vendor: vendors.first)),
      );
      if (changed == true) _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionController>().user;
    final canEdit = me != null && me.hasPermission('edit_vendor');
    return Scaffold(
      appBar: AppBar(
        title: const Text('عملائي'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'بحث بالاسم أو الهاتف',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                _search = v;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UserModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final err = snap.error;
                  return Center(
                    child: Text(err is ApiException ? err.message : err.toString()),
                  );
                }
                final clients = snap.data ?? const [];
                if (clients.isEmpty) {
                  return const Center(child: Text('لا يوجد عملاء بعد'));
                }
                return ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final c = clients[i];
                    final hasShop = c.vendorName != null && c.vendorName!.isNotEmpty;
                    // Title shows the company (shop) name; the owner's username
                    // and phone go underneath so the delegate can match shop ↔ owner.
                    final title = hasShop ? c.vendorName! : c.name;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (c.vendorLogo != null && c.vendorLogo!.isNotEmpty)
                            ? NetworkImage(c.vendorLogo!)
                            : null,
                        child: (c.vendorLogo == null || c.vendorLogo!.isEmpty)
                            ? Text(title.isNotEmpty ? title[0] : '?')
                            : null,
                      ),
                      title: Text(title),
                      subtitle: Text([
                        if (hasShop) 'المستخدم: ${c.name}',
                        c.phone,
                        if (c.workField != null && c.workField!.isNotEmpty) c.workField!,
                      ].join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            c.isActive ? Icons.check_circle : Icons.block,
                            color: c.isActive ? Colors.green : Colors.red,
                          ),
                          if (canEdit) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.edit, color: Colors.grey),
                          ],
                        ],
                      ),
                      onTap: canEdit ? () => _editClient(c) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
