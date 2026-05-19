import 'package:flutter/material.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({Key? key}) : super(key: key);

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Todos';

  // Lista de datos simulada para probar la búsqueda
  final List<Map<String, String>> _usersData = [
    {'name': 'Royser Villanueva', 'role': 'Administrador', 'status': 'Activo'},
    {'name': 'Javier Arteaga', 'role': 'Moderador', 'status': 'Activo'},
    {'name': 'Usuario Sospechoso', 'role': 'Usuario', 'status': 'Bloqueado'},
    {'name': 'Estudiante UPT', 'role': 'Usuario', 'status': 'Activo'},
  ];

  @override
  Widget build(BuildContext context) {
    // Lógica que filtra la lista en tiempo real
    final filteredData = _usersData.where((user) {
      final matchesSearch = user['name']!.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _selectedFilter == 'Todos' || user['status'] == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Fila de botones de filtro
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedFilter == 'Todos',
                  onSelected: (selected) => setState(() => _selectedFilter = 'Todos'),
                ),
                FilterChip(
                  label: const Text('Activos'),
                  selected: _selectedFilter == 'Activo',
                  selectedColor: Colors.green.shade200,
                  onSelected: (selected) => setState(() => _selectedFilter = 'Activo'),
                ),
                FilterChip(
                  label: const Text('Bloqueados'),
                  selected: _selectedFilter == 'Bloqueado',
                  selectedColor: Colors.red.shade200,
                  onSelected: (selected) => setState(() => _selectedFilter = 'Bloqueado'),
                ),
              ],
            ),
          ),
          const Divider(),
          // Lista de resultados filtrados
          Expanded(
            child: ListView.builder(
              itemCount: filteredData.length,
              itemBuilder: (context, index) {
                final user = filteredData[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['status'] == 'Activo' ? Colors.blue : const Color.fromARGB(255, 129, 39, 32),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(user['name']!),
                  subtitle: Text('Rol: ${user['role']} | Estado: ${user['status']}'),
                  trailing: const Icon(Icons.more_vert),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}