import 'package:flutter/material.dart';

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
            // Vista 1: Reportes Pendientes
            _PendingReportsList(),
            // Vista 2: Reportes ya resueltos
            _ResolvedReportsList(),
          ],
        ),
      ),
    );
  }
}

class _PendingReportsList extends StatelessWidget {
  const _PendingReportsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5, // Número de ejemplo de reportes
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 2,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.warning, color: Colors.white),
            ),
            title: Text('Reporte de Incidencia #${100 + index}'),
            subtitle: const Text('Contenido pendiente de revisión por el moderador.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Aprobar / Validar',
                  onPressed: () {
                    // TODO: Lógica para aprobar
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Rechazar / Eliminar',
                  onPressed: () {
                    // TODO: Lógica para rechazar
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResolvedReportsList extends StatelessWidget {
  const _ResolvedReportsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.grey.shade100,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.done_all, color: Colors.white),
            ),
            title: Text('Reporte Revisado #${90 + index}'),
            subtitle: const Text('Acción tomada: Incidencia cerrada.'),
          ),
        );
      },
    );
  }
}