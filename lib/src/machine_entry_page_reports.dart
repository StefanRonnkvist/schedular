// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageReportsExtension on _MachineEntryPageState {
  Widget _buildMaintenanceDueTab() {
    _ensureMachinesVisible();
    final visibleMachines = _getFilteredMachines();

    return ListView(
      children: [
        _buildTaskFilterCard(),
        const SizedBox(height: 16),
        _buildMachineList(
          visibleMachines,
          showActions: false,
          editableDetails: true,
          emptyMessage: _hasTaskFilter
              ? 'No machines match the selected task filter.'
              : 'No machines added yet.',
        ),
      ],
    );
  }

  List<WorkOrderReport> _fallbackWorkOrderReports() {
    final workOrders = _buildWorkOrderItemsForNextFiveDays();
    return workOrders
        .map(
          (item) => WorkOrderReport(
            id: item.subAssembly.id ?? -1,
            subAssemblyId: item.subAssembly.id ?? -1,
            machineName: item.machine.name,
            subAssemblyName: item.subAssembly.name,
            status: 'Pending',
            assignedEmployees: const <String>[],
            notes:
                'Due ${_formatDate(item.projectedNextDate)} (${item.daysUntilDue == 0 ? 'today' : 'in ${item.daysUntilDue} day${item.daysUntilDue == 1 ? '' : 's'}'})',
            enteredAtUtc: item.projectedNextDate.toUtc().toIso8601String(),
          ),
        )
        .toList(growable: false);
  }

  Widget _buildReportsTab() {
    _ensureMachinesVisible();
    return FutureBuilder<List<WorkOrderReport>>(
      future: MachineDatabase.instance.getAllWorkOrdersReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reports: ${snapshot.error}'),
          );
        }

        final persistedReports = snapshot.data ?? const <WorkOrderReport>[];
        final reports = persistedReports.isEmpty
            ? _fallbackWorkOrderReports()
            : persistedReports;
        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No work orders found.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _switchToTab(_AppTab.workOrders),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Go to Work Orders'),
                ),
              ],
            ),
          );
        }

        final groupedByStatus = <String, List<WorkOrderReport>>{};
        for (final report in reports) {
          if (!groupedByStatus.containsKey(report.status)) {
            groupedByStatus[report.status] = [];
          }
          groupedByStatus[report.status]!.add(report);
        }

        final statusOrder = ['Work Complete', 'Partial', 'Bypass'];
        final orderedStatuses = statusOrder
            .where((s) => groupedByStatus.containsKey(s))
            .toList();
        final remainingStatuses =
            groupedByStatus.keys
                .where((status) => !orderedStatuses.contains(status))
                .toList(growable: false)
              ..sort();
        orderedStatuses.addAll(remainingStatuses);

        return ListView(
          children: [
            ...orderedStatuses.map((status) {
              final statusReports = groupedByStatus[status]!;
              return _buildReportStatusSection(status, statusReports);
            }),
          ],
        );
      },
    );
  }

  Widget _buildReportStatusSection(
    String status,
    List<WorkOrderReport> reports,
  ) {
    final statusColor = _colorForWorkOrderStatus(status);
    final statusLabel = _labelForWorkOrderStatus(status);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${reports.length} work order${reports.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...reports.map((report) => _buildWorkOrderReportCard(report)),
        ],
      ),
    );
  }

  Widget _buildWorkOrderReportCard(WorkOrderReport report) {
    final statusColor = _colorForWorkOrderStatus(report.status);
    final statusLabel = _labelForWorkOrderStatus(report.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.machineName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.subAssemblyName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(statusLabel),
                  avatar: Icon(Icons.circle, size: 10, color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (report.assignedEmployees.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.assignedEmployees.join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (report.notes.trim().isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.notes,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatWorkOrderDate(report.enteredAtUtc),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForWorkOrderStatus(String status) {
    switch (status) {
      case 'Pending':
        return Colors.blue;
      case 'Work Complete':
        return Colors.green;
      case 'Partial':
        return Colors.orange;
      case 'Bypass':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _labelForWorkOrderStatus(String status) {
    switch (status) {
      case 'Pending':
        return 'Pending';
      case 'Work Complete':
        return 'Completed';
      case 'Partial':
        return 'Partialed';
      case 'Bypass':
        return 'Bypassed';
      default:
        return status;
    }
  }

  String _formatWorkOrderDate(String enteredAtUtc) {
    try {
      return _formatDate(DateTime.parse(enteredAtUtc).toLocal());
    } catch (_) {
      return enteredAtUtc;
    }
  }
}
