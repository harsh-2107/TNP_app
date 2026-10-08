import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_repository.dart';

class AdminActiveStudentsPage extends ConsumerWidget {
  const AdminActiveStudentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(adminRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Students Tracker'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: repository.getActiveStudents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final students = snapshot.data ?? [];
          if (students.isEmpty) {
            return const Center(child: Text('No active students found.'));
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(student['full_name'] ?? 'Unknown'),
                subtitle: Text('Last Active: ${student['last_active'] ?? 'N/A'}'),
                trailing: Text(student['bt_id'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
