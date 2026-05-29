import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/services/accounts_services.dart';

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

  @override
  Widget build(BuildContext context) {
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
                    return ListTile(
                      leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                      title: Text(c.name),
                      subtitle: Text([
                        c.phone,
                        if (c.workField != null && c.workField!.isNotEmpty) c.workField!,
                      ].join(' • ')),
                      trailing: Icon(
                        c.isActive ? Icons.check_circle : Icons.block,
                        color: c.isActive ? Colors.green : Colors.red,
                      ),
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
