import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../data/notice.dart';
import '../data/notice_repository.dart';
import 'create_notice_dialog.dart';

enum _StatusFilter { all, draft, published, closed }

/// Admin's notice management list (Set 17 section 9) - search by title,
/// type/audience/status filters, all client-side over [allNoticesProvider]
/// at this project's scale, matching `AcademicWorkListScreen`'s
/// established pattern exactly.
class NoticesListScreen extends ConsumerStatefulWidget {
  const NoticesListScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<NoticesListScreen> createState() => _NoticesListScreenState();
}

class _NoticesListScreenState extends ConsumerState<NoticesListScreen> {
  final _searchController = TextEditingController();
  NoticeType? _typeFilter;
  NoticeAudience? _audienceFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

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

  bool _matches(Notice notice) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty && !notice.title.toLowerCase().contains(search)) {
      return false;
    }
    if (_typeFilter != null && notice.type != _typeFilter) return false;
    if (_audienceFilter != null && notice.audience != _audienceFilter) return false;
    final matchesStatus = switch (_statusFilter) {
      _StatusFilter.all => true,
      _StatusFilter.draft => notice.status == NoticeStatus.draft,
      _StatusFilter.published => notice.status == NoticeStatus.published,
      _StatusFilter.closed => notice.status == NoticeStatus.closed,
    };
    return matchesStatus;
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(allNoticesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateNoticeDialog(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    label: 'Search by title',
                    suffixIcon: const Icon(Icons.search),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        DropdownButton<NoticeType?>(
                          value: _typeFilter,
                          hint: const Text('Type'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All types')),
                            for (final type in NoticeType.values)
                              DropdownMenuItem(value: type, child: Text(type.label)),
                          ],
                          onChanged: (value) => setState(() => _typeFilter = value),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        DropdownButton<NoticeAudience?>(
                          value: _audienceFilter,
                          hint: const Text('Audience'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All audiences')),
                            for (final audience in NoticeAudience.values)
                              DropdownMenuItem(value: audience, child: Text(audience.label)),
                          ],
                          onChanged: (value) => setState(() => _audienceFilter = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<_StatusFilter>(
                    segments: const [
                      ButtonSegment(value: _StatusFilter.all, label: Text('All')),
                      ButtonSegment(value: _StatusFilter.draft, label: Text('Draft')),
                      ButtonSegment(value: _StatusFilter.published, label: Text('Published')),
                      ButtonSegment(value: _StatusFilter.closed, label: Text('Closed')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (selection) =>
                        setState(() => _statusFilter = selection.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: noticesAsync.when(
                loading: () => const LoadingView(),
                error: (error, stackTrace) =>
                    ErrorView(message: 'Unable to load notices. Please try again.\n$error'),
                data: (notices) {
                  final filtered = notices.where(_matches).toList();
                  if (filtered.isEmpty) {
                    return const EmptyView(message: 'No notices found.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) => _NoticeTile(
                      notice: filtered[index],
                      onTap: () => context.push('${widget.basePath}/${filtered[index].noticeId}'),
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

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(notice.title),
        subtitle: Text(
          '${notice.type.label} - ${notice.audience.label}\n'
          'Created ${dateKey(notice.createdAt)}'
          '${notice.publishedAt != null ? ' - Published ${dateKey(notice.publishedAt!)}' : ''}',
        ),
        isThreeLine: true,
        trailing: Chip(label: Text(notice.status.label)),
        onTap: onTap,
      ),
    );
  }
}
