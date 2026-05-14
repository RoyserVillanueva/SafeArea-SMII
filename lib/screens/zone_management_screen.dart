// zone_management_screen.dart
import 'package:flutter/material.dart';

class ZoneManagementScreen extends StatelessWidget {
  const ZoneManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Zonas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt),
            tooltip: 'Agregar nueva zona',
            onPressed: () {
              // TODO: Abrir formulario para crear una zona
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          Card(
            elevation: 2,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.security, color: Colors.white),
              ),
              title: const Text('Zona Segura - Campus UPT'),
              subtitle: const Text('Estado: Activa | Radio: 500m'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                onPressed: () {
                  // TODO: Editar zona
                },
              ),
            ),
          ),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.warning, color: Colors.white),
              ),
              title: const Text('Zona de Riesgo - Avenida Principal'),
              subtitle: const Text('Estado: Activa | Radio: 250m'),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueGrey),
                onPressed: () {
                  // TODO: Editar zona
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}