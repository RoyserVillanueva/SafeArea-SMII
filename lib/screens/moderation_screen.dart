import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/report_model.dart';
import '../widgets/report_card.dart';
import 'report_detail_screen.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Dos pestañas: Pendientes y Resueltos
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderación'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pendientes', icon: Icon(Icons.pending_actions)),
              Tab(text: 'Historial', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ModerationReportsList(
              title: 'Reportes pendientes',
              emptyMessage: 'No hay reportes pendientes por revisar.',
              statusFilters: ['activo', 'en_proceso'],
              emptyIcon: Icons.inbox_outlined,
            ),
            _ModerationReportsList(
              title: 'Historial de reportes',
              emptyMessage: 'No hay reportes resueltos aún.',
              statusFilters: ['resuelto'],
              emptyIcon: Icons.done_all_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationReportsList extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<String> statusFilters;
  final IconData emptyIcon;

  const _ModerationReportsList({
    required this.title,
    required this.emptyMessage,
    required this.statusFilters,
    required this.emptyIcon,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildReportsStream() {
    try {
      final query = FirebaseFirestore.instance
          .collection('reports')
          .where('isActive', isEqualTo: true)
          .where('status', whereIn: statusFilters)
          .orderBy('createdAt', descending: true);

      return query.snapshots().handleError((Object error, StackTrace stackTrace) {
        debugPrint('🔥 Firestore error en "$title": $error');
        debugPrintStack(stackTrace: stackTrace);
        throw error;
      });
    } catch (error, stackTrace) {
      debugPrint('🔥 Error construyendo query en "$title": $error');
      debugPrintStack(stackTrace: stackTrace);
      return Stream<QuerySnapshot<Map<String, dynamic>>>.error(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📡 Cargando moderación "$title" con filtros: $statusFilters');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('⚠️ snapshot.hasError en "$title": ${snapshot.error}');
          // Mostrar el error explícitamente en pantalla y permitir selección/copia
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.error_outline, size: 96, color: Colors.red.shade700),
                const SizedBox(height: 24),
                Text(
                  'Error cargando reportes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.red.shade700),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ Stream en espera para "$title"...');
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _StateMessage(
            icon: emptyIcon,
            title: title,
            message: emptyMessage,
          );
        }

        final reports = snapshot.data!.docs
            .map((doc) => Report.fromMap(doc.data() as Map<String, dynamic>))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final report = reports[index];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ReportCard(
                report: report,
                maskLocation: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(report: report),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}