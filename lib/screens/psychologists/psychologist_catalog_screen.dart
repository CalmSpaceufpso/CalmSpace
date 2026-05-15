import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/psychologist_model.dart';
import '../../providers/psychologist_provider.dart';
import 'psychologist_detail_screen.dart';
import 'widgets/psychologist_card.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/filter_chips_widget.dart';
import 'widgets/loading_skeleton_widget.dart';
import 'widgets/empty_state_widget.dart';

class PsychologistCatalogScreen extends StatefulWidget {
  const PsychologistCatalogScreen({super.key});

  @override
  State<PsychologistCatalogScreen> createState() =>
      _PsychologistCatalogScreenState();
}

class _PsychologistCatalogScreenState
    extends State<PsychologistCatalogScreen> {
  static const Color _primary  = Color(0xFF1D35B4);
  static const Color _bg       = Color(0xFFF4F6FB);
  static const Color _textMain = Color(0xFF1E293B);
  static const Color _textSub  = Color(0xFF64748B);

  String  _search            = '';
  String? _selectedSpecialty;
  String? _selectedModalidad;
  bool    _onlyAvail         = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await context.read<PsychologistProvider>().loadPsychologists();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<PsychologistModel> _filtered(List<PsychologistModel> all) {
    return all.where((p) {
      final matchSearch = p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.specialty.toLowerCase().contains(_search.toLowerCase());
      final matchSpec   = _selectedSpecialty == null || p.specialty == _selectedSpecialty;
      final matchMod    = _selectedModalidad == null ||
          (p.modalidad?.toLowerCase() == _selectedModalidad!.toLowerCase());
      final matchAvail  = !_onlyAvail || p.isAvailable;
      return matchSearch && matchSpec && matchMod && matchAvail;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedSpecialty != null || _selectedModalidad != null || _onlyAvail;

  void _clearFilters() => setState(() {
        _selectedSpecialty = null;
        _selectedModalidad = null;
        _onlyAvail = false;
      });

  List<String> _specialties(List<PsychologistModel> all) =>
      all.map((p) => p.specialty).toSet().toList()..sort();

  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<PsychologistProvider>();
    final filtered  = _filtered(provider.psychologists);
    final specialties = _specialties(provider.psychologists);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Psicólogos',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _textMain,
                    letterSpacing: -0.5)),
            Text('Encuentra tu acompañante ideal',
                style: TextStyle(
                    fontSize: 12,
                    color: _textSub,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: _primary),
            tooltip: 'Actualizar',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Buscador ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SearchBarWidget(
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),

            // ── Filtros ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                child: FilterChipsWidget(
                  specialties: specialties,
                  selectedSpecialty: _selectedSpecialty,
                  selectedModalidad: _selectedModalidad,
                  hasActiveFilters: _hasActiveFilters,
                  onSpecialtySelected: (v) =>
                      setState(() => _selectedSpecialty = v),
                  onModalidadSelected: (v) =>
                      setState(() => _selectedModalidad = v),
                  onClearFilters: _clearFilters,
                ),
              ),
            ),

            // ── Contador ───────────────────────────────────────────────
            if (!provider.isLoading && _error == null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    '${filtered.length} psicólogo${filtered.length != 1 ? 's' : ''} encontrado${filtered.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _textSub,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

            // ── Contenido ──────────────────────────────────────────────
            if (provider.isLoading)
              const SliverToBoxAdapter(child: LoadingSkeletonWidget())
            else if (_error != null)
              SliverFillRemaining(
                child: EmptyStateWidget(
                  searchQuery: _search,
                  hasFilters: _hasActiveFilters,
                  onClearFilters: _clearFilters,
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: EmptyStateWidget(
                  searchQuery: _search,
                  hasFilters: _hasActiveFilters,
                  onClearFilters: _clearFilters,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PsychologistCard(
                        psychologist: filtered[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PsychologistDetailScreen(
                                psychologist: filtered[i]),
                          ),
                        ),
                      ),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}