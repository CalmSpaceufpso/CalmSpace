import 'package:flutter/material.dart';

import 'widgets/search_bar_widget.dart';

class PsychologistCatalogScreen extends StatefulWidget {
  const PsychologistCatalogScreen({super.key});

  @override
  State<PsychologistCatalogScreen> createState() =>
      _PsychologistCatalogScreenState();
}

class _PsychologistCatalogScreenState
    extends State<PsychologistCatalogScreen> {

  final List<String> psychologists = [
    'Ana López',
    'Carlos Pérez',
    'Laura Gómez',
    'Andrés Ruiz',
    'Mariana Torres',
  ];

  String search = '';

  @override
  Widget build(BuildContext context) {

    final filteredPsychologists = psychologists.where((psychologist) {
      return psychologist
          .toLowerCase()
          .contains(search.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Psicólogos'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 🔍 Barra de búsqueda
            SearchBarWidget(
              onChanged: (value) {
                setState(() {
                  search = value;
                });
              },
            ),

            const SizedBox(height: 20),

            // 📋 Lista
            Expanded(
              child: ListView.builder(
                itemCount: filteredPsychologists.length,
                itemBuilder: (context, index) {

                  final psychologist =
                      filteredPsychologists[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(psychologist),
                      subtitle: const Text(
                        'Especialista en ansiedad',
                      ),
                    ),
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