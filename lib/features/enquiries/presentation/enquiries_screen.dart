import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../academics/data/academics_repositories.dart';
import '../data/enquiry.dart';
import '../data/enquiry_repository.dart';

enum _StatusFilter { all, newEnquiry, contacted, followUp, admissionDone, notInterested }

enum _TypeFilter { all, admission, callback }

/// Admin manages visitor enquiries submitted from the public site (Set 5,
/// extended Set 18 with search/class/board/status/type filters). There is
/// deliberately no separate "telecaller" role - admin does this directly.
class EnquiriesScreen extends ConsumerStatefulWidget {
  const EnquiriesScreen({super.key});

  @override
  ConsumerState<EnquiriesScreen> createState() => _EnquiriesScreenState();
}

class _EnquiriesScreenState extends ConsumerState<EnquiriesScreen> {
  final _searchController = TextEditingController();
  String? _classFilter;
  String? _boardFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;
  _TypeFilter _typeFilter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Enquiry enquiry) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      final matchesName = enquiry.name.toLowerCase().contains(search);
      final matchesPhone = enquiry.primaryPhone.contains(search) ||
          (enquiry.secondaryPhone?.contains(search) ?? false);
      if (!matchesName && !matchesPhone) return false;
    }
    if (_classFilter != null && enquiry.classId != _classFilter) return false;
    if (_boardFilter != null && enquiry.boardId != _boardFilter) return false;
    final matchesType = switch (_typeFilter) {
      _TypeFilter.all => true,
      _TypeFilter.admission => enquiry.enquiryType == EnquiryType.admission,
      _TypeFilter.callback => enquiry.enquiryType == EnquiryType.callback,
    };
    if (!matchesType) return false;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.newEnquiry => enquiry.status == EnquiryStatus.newEnquiry,
      _StatusFilter.contacted => enquiry.status == EnquiryStatus.contacted,
      _StatusFilter.followUp => enquiry.status == EnquiryStatus.followUp,
      _StatusFilter.admissionDone => enquiry.status == EnquiryStatus.admissionDone,
      _StatusFilter.notInterested => enquiry.status == EnquiryStatus.notInterested,
    };
    return matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final enquiriesAsync = ref.watch(allEnquiriesProvider);
    final classesAsync = ref.watch(allSchoolClassesProvider);
    final boardsAsync = ref.watch(allBoardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Visitor enquiries')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by name or phone',
                    suffixIcon: const Icon(Icons.search),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DropdownButton<_TypeFilter>(
                          value: _typeFilter,
                          items: const [
                            DropdownMenuItem(value: _TypeFilter.all, child: Text('All types')),
                            DropdownMenuItem(
                              value: _TypeFilter.admission,
                              child: Text('Admission'),
                            ),
                            DropdownMenuItem(
                              value: _TypeFilter.callback,
                              child: Text('Callback'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _typeFilter = value ?? _typeFilter),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String?>(
                          value: _classFilter,
                          hint: const Text('Class'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All classes')),
                            for (final schoolClass in classesAsync.valueOrNull ?? const [])
                              DropdownMenuItem(
                                value: schoolClass.classId,
                                child: Text(schoolClass.name),
                              ),
                          ],
                          onChanged: (value) => setState(() => _classFilter = value),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<String?>(
                          value: _boardFilter,
                          hint: const Text('Board'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All boards')),
                            for (final board in boardsAsync.valueOrNull ?? const [])
                              DropdownMenuItem(value: board.boardId, child: Text(board.name)),
                          ],
                          onChanged: (value) => setState(() => _boardFilter = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_StatusFilter>(
                      segments: const [
                        ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                        ButtonSegment(value: _StatusFilter.newEnquiry, label: Text('New')),
                        ButtonSegment(value: _StatusFilter.contacted, label: Text('Contacted')),
                        ButtonSegment(value: _StatusFilter.followUp, label: Text('Follow-up')),
                        ButtonSegment(
                          value: _StatusFilter.admissionDone,
                          label: Text('Admitted'),
                        ),
                        ButtonSegment(
                          value: _StatusFilter.notInterested,
                          label: Text('Not interested'),
                        ),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (selection) =>
                          setState(() => _statusFilter = selection.first),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: enquiriesAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Could not load enquiries.\n$error'),
                data: (enquiries) {
                  final filtered = enquiries.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(message: 'No enquiries found.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _EnquiryTile(enquiry: filtered[index]),
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

class _EnquiryTile extends StatelessWidget {
  const _EnquiryTile({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      enquiry.enquiryType.label,
      if (enquiry.className != null) enquiry.className!,
      if (enquiry.boardDisplay != null) enquiry.boardDisplay!,
      enquiry.primaryPhone,
    ];
    return Card(
      child: ListTile(
        title: Text(enquiry.name),
        subtitle: Text(subtitleParts.join(' - ')),
        trailing: Chip(label: Text(enquiry.status.label)),
        onTap: () =>
            context.push('${AppRoutes.adminEnquiries}/${enquiry.enquiryId}'),
      ),
    );
  }
}
