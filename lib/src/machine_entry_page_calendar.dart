// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageCalendarExtension on _MachineEntryPageState {
  static const List<String> _forecastPartBucketOrder = <String>[
    'Overdue',
    'Today',
    'Week',
    'Month',
    'Quarter',
    'Semi-Annual',
    'Annual',
    'Biannual',
    'Greater than Biannual',
    'Unavailable',
  ];

  /// Adds HTTPS when no scheme is supplied and returns a parseable vendor URL.
  /// Empty or syntactically invalid values return `null`.
  String? _normalizedVendorUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    return uri.toString();
  }

  /// Formats a nullable day offset for display in task-level due-date details.
  String _dueInLabel(int? daysUntilDue) {
    if (daysUntilDue == null) {
      return 'Unavailable';
    }
    if (daysUntilDue < 0) {
      final overdueDays = daysUntilDue.abs();
      return 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}';
    }
    if (daysUntilDue == 0) {
      return 'Today';
    }
    if (daysUntilDue == 1) {
      return '1 day';
    }
    return '$daysUntilDue days';
  }

  /// Maps a nullable day offset to the mutually exclusive forecast ranges used
  /// by required-parts summaries.
  String _forecastBucketLabelForDays(int? daysUntilDue) {
    if (daysUntilDue == null) {
      return 'Unavailable';
    }
    if (daysUntilDue < 0) {
      return 'Overdue';
    }
    if (daysUntilDue == 0) {
      return 'Today';
    }
    if (daysUntilDue <= 7) {
      return 'Week';
    }
    if (daysUntilDue <= 31) {
      return 'Month';
    }
    if (daysUntilDue <= 92) {
      return 'Quarter';
    }
    if (daysUntilDue <= 183) {
      return 'Semi-Annual';
    }
    if (daysUntilDue <= 365) {
      return 'Annual';
    }
    if (daysUntilDue <= 730) {
      return 'Biannual';
    }
    return 'Greater than Biannual';
  }

  /// Counts non-overdue tasks in mutually exclusive forecast ranges.
  ///
  /// Overdue items are omitted because their status is presented separately;
  /// [bypassed] and [partial] are supplied by the caller's filtering logic.
  List<({String label, int count})> _dueBucketCounts(
    List<_EstimatedTaskItem> items, {
    int bypassed = 0,
    int partial = 0,
  }) {
    int today = 0;
    int week = 0;
    int month = 0;
    int quarter = 0;
    int semiAnnual = 0;
    int annual = 0;
    int biAnnual = 0;
    int greaterThanBiAnnual = 0;

    for (final item in items) {
      final dueDays = item.daysUntilDue;
      if (dueDays < 0) {
        continue;
      }

      if (dueDays == 0) {
        today += 1;
      } else if (dueDays <= 7) {
        week += 1;
      } else if (dueDays <= 31) {
        month += 1;
      } else if (dueDays <= 92) {
        quarter += 1;
      } else if (dueDays <= 183) {
        semiAnnual += 1;
      } else if (dueDays <= 365) {
        annual += 1;
      } else if (dueDays <= 730) {
        biAnnual += 1;
      } else {
        greaterThanBiAnnual += 1;
      }
    }

    return [
      (label: 'Bypassed', count: bypassed),
      (label: 'Partial', count: partial),
      (label: 'Today', count: today),
      (label: 'Week', count: week),
      (label: 'Month', count: month),
      (label: 'Quarter', count: quarter),
      (label: 'Semi-Annual', count: semiAnnual),
      (label: 'Annual', count: annual),
      (label: 'Biannual', count: biAnnual),
      (label: 'Greater than Biannual', count: greaterThanBiAnnual),
    ];
  }

  /// Flattens every machine task into a calendar item with a day-level due
  /// offset, then sorts the result by machine, subassembly, and task type.
  List<_EstimatedTaskItem> _buildEstimatedTasksForCalendar() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final items = <_EstimatedTaskItem>[];
    for (final machine in _machines) {
      for (final subAssembly in machine.subAssemblies) {
        for (final task in subAssembly.maintenanceTasks) {
          final projected = _projectedNextDateForTask(machine, task);
          final dueDate = projected == null
              ? null
              : DateTime(projected.year, projected.month, projected.day);
          final daysUntilDue = dueDate?.difference(todayStart).inDays;
          items.add(
            _EstimatedTaskItem(
              machine: machine,
              subAssembly: subAssembly,
              task: task,
              projectedDate: projected,
              daysUntilDue: daysUntilDue,
            ),
          );
        }
      }
    }

    items.sort((a, b) {
      final machineCmp = a.machine.name.compareTo(b.machine.name);
      if (machineCmp != 0) {
        return machineCmp;
      }

      final subAssemblyCmp = a.subAssembly.name.compareTo(b.subAssembly.name);
      if (subAssemblyCmp != 0) {
        return subAssemblyCmp;
      }

      return a.task.taskType.compareTo(b.task.taskType);
    });

    return items;
  }

  Map<String, List<({_EstimatedTaskItem item, RequiredPart part})>>
  _buildForecastRequiredPartGroups(List<_EstimatedTaskItem> items) {
    final grouped =
        <String, List<({_EstimatedTaskItem item, RequiredPart part})>>{};

    for (final item in items) {
      final bucket = _forecastBucketLabelForDays(item.daysUntilDue);
      for (final part in item.task.requiredParts.where(
        (part) => !part.isEmpty,
      )) {
        grouped
            .putIfAbsent(
              bucket,
              () => <({_EstimatedTaskItem item, RequiredPart part})>[],
            )
            .add((item: item, part: part));
      }
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) {
        final dateCompare = a.item.projectedDate.compareTo(
          b.item.projectedDate,
        );
        if (dateCompare != 0) {
          return dateCompare;
        }
        final machineCompare = a.item.machine.name.toLowerCase().compareTo(
          b.item.machine.name.toLowerCase(),
        );
        if (machineCompare != 0) {
          return machineCompare;
        }
        final subAssemblyCompare = a.item.subAssembly.name
            .toLowerCase()
            .compareTo(b.item.subAssembly.name.toLowerCase());
        if (subAssemblyCompare != 0) {
          return subAssemblyCompare;
        }
        return a.item.task.taskType.toLowerCase().compareTo(
          b.item.task.taskType.toLowerCase(),
        );
      });
    }

    return grouped;
  }

  Widget _buildForecastRequiredPartsSection(List<_EstimatedTaskItem> items) {
    final grouped = _buildForecastRequiredPartGroups(items);
    final orderedBuckets = _forecastPartBucketOrder
        .where(grouped.containsKey)
        .toList(growable: false);
    final bucketFilterOptions = <String>['All', ...orderedBuckets];
    final selectedBucket =
        bucketFilterOptions.contains(_forecastPartsSelectedBucket)
        ? _forecastPartsSelectedBucket
        : 'All';
    final visibleBuckets = selectedBucket == 'All'
        ? orderedBuckets
        : <String>[selectedBucket];

    if (orderedBuckets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Required Parts by Forecast Group',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('No required parts found in forecasted maintenance tasks.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Required Parts by Forecast Group',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Parts are grouped by the same forecast buckets used in the calendar summary.',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedBucket,
              decoration: const InputDecoration(
                labelText: 'Visible Forecast Bucket',
                border: OutlineInputBorder(),
              ),
              items: bucketFilterOptions
                  .map(
                    (bucket) => DropdownMenuItem<String>(
                      value: bucket,
                      child: Text(bucket),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null || !mounted) {
                  return;
                }
                setState(() {
                  _forecastPartsSelectedBucket = value;
                });
                unawaited(_persistForecastTabPreferences());
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await _exportForecastRequiredPartsCsvToFile(
                  grouped,
                  visibleBuckets,
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: Text(
                selectedBucket == 'All'
                    ? 'Export Forecast Parts CSV'
                    : 'Export "$selectedBucket" Parts CSV',
              ),
            ),
            const SizedBox(height: 12),
            ...visibleBuckets.map((bucket) {
              final rows =
                  grouped[bucket] ??
                  const <({_EstimatedTaskItem item, RequiredPart part})>[];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$bucket (${rows.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Due Date')),
                          DataColumn(label: Text('Machine')),
                          DataColumn(label: Text('Sub-Assembly')),
                          DataColumn(label: Text('Task')),
                          DataColumn(label: Text('OEM PN')),
                          DataColumn(label: Text('Vendor PN')),
                          DataColumn(label: Text('Vendor')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Lead Time')),
                          DataColumn(label: Text('URL')),
                        ],
                        rows: rows
                            .map((row) {
                              final item = row.item;
                              final part = row.part;
                              final normalizedVendorUrl = _normalizedVendorUrl(
                                part.vendorUrl,
                              );
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '${_formatDate(item.projectedDate)} (${_dueInLabel(item.daysUntilDue)})',
                                    ),
                                  ),
                                  DataCell(Text(item.machine.name)),
                                  DataCell(Text(item.subAssembly.name)),
                                  DataCell(Text(item.task.taskType)),
                                  DataCell(
                                    Text(
                                      part.oemPn.trim().isEmpty
                                          ? '-'
                                          : part.oemPn.trim(),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      part.vendorPn.trim().isEmpty
                                          ? '-'
                                          : part.vendorPn.trim(),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      part.vendorName.trim().isEmpty
                                          ? '-'
                                          : part.vendorName.trim(),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      part.vendorPhoneNumber.trim().isEmpty
                                          ? '-'
                                          : part.vendorPhoneNumber.trim(),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      part.estimatedLeadTime.trim().isEmpty
                                          ? '-'
                                          : part.estimatedLeadTime.trim(),
                                    ),
                                  ),
                                  DataCell(
                                    normalizedVendorUrl == null
                                        ? const Text('-')
                                        : TextButton(
                                            onPressed: () async {
                                              await _openVendorUrl(
                                                normalizedVendorUrl,
                                              );
                                            },
                                            child: const Text('Open'),
                                          ),
                                  ),
                                ],
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _exportForecastRequiredPartsCsvToFile(
    Map<String, List<({_EstimatedTaskItem item, RequiredPart part})>> grouped,
    List<String> orderedBuckets,
  ) async {
    final rows = <List<String>>[
      <String>[
        'forecastBucket',
        'dueDate',
        'dueIn',
        'machine',
        'subAssembly',
        'task',
        'oemPn',
        'vendorPn',
        'vendor',
        'phone',
        'leadTime',
        'url',
      ],
    ];

    for (final bucket in orderedBuckets) {
      final entries =
          grouped[bucket] ??
          const <({_EstimatedTaskItem item, RequiredPart part})>[];
      for (final entry in entries) {
        final item = entry.item;
        final part = entry.part;
        rows.add(<String>[
          bucket,
          _formatDate(item.projectedDate),
          _dueInLabel(item.daysUntilDue),
          item.machine.name,
          item.subAssembly.name,
          item.task.taskType,
          part.oemPn.trim(),
          part.vendorPn.trim(),
          part.vendorName.trim(),
          part.vendorPhoneNumber.trim(),
          part.estimatedLeadTime.trim(),
          _normalizedVendorUrl(part.vendorUrl) ?? part.vendorUrl.trim(),
        ]);
      }
    }

    final csv = rows
        .map(
          (row) =>
              row.map((value) => '"${value.replaceAll('"', '""')}"').join(','),
        )
        .join('\n');

    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final bucketSuffix = orderedBuckets.length == 1
        ? '_${orderedBuckets.first.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}'
        : '';

    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Forecast Parts CSV',
      fileName: 'forecast_parts_$yyyy$mm$dd$bucketSuffix.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    if (result == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Forecast parts CSV exported to: $result')),
    );
  }

  Future<void> _loadForecastTabPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final bucket =
        preferences.getString(
          _MachineEntryPageState._forecastPartsBucketPreferenceKey,
        ) ??
        'All';

    if (!mounted) {
      return;
    }

    setState(() {
      _forecastPartsSelectedBucket = bucket;
    });
  }

  Future<void> _persistForecastTabPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _MachineEntryPageState._forecastPartsBucketPreferenceKey,
      _forecastPartsSelectedBucket,
    );
  }

  Future<void> _printSchedulePdf() async {
    final items = _buildEstimatedTasksForCalendar();
    final statusCounts = await MachineDatabase.instance
        .getWorkOrderStatusCounts();
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yyyy = now.year.toString().padLeft(4, '0');
    final fileName = 'schedule$mm$dd$yyyy.pdf';
    final dueBuckets = _dueBucketCounts(
      items,
      bypassed: statusCounts['Bypass'] ?? 0,
      partial: statusCounts['Partial'] ?? 0,
    );

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              '$fileName | ${_formatDate(now)} | Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              'Schedule Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: ${_formatDate(now)}'),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 10,
              runSpacing: 6,
              children: dueBuckets
                  .map((bucket) => pw.Text('${bucket.label}: ${bucket.count}'))
                  .toList(growable: false),
            ),
            pw.SizedBox(height: 12),
            ...items.map((item) {
              final dueDate = _formatDate(item.projectedDate);
              final dueIn = _dueInLabel(item.daysUntilDue);
              final requiredParts = item.task.requiredParts
                  .where((part) => !part.isEmpty)
                  .toList(growable: false);
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.task.taskType,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('Due Date: $dueDate ($dueIn)'),
                    pw.Text('Machine: ${item.machine.name}'),
                    pw.Text('Sub-Assembly: ${item.subAssembly.name}'),
                    pw.Text(
                      'Interval: ${item.task.timeValue} ${item.task.timeCategory}',
                    ),
                    pw.Text(
                      'Component: ${item.subAssembly.subCategory} | Location: ${item.subAssembly.location}',
                    ),
                    if (requiredParts.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Required Parts:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      ...requiredParts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final part = entry.value;
                        final details = <String>[];
                        if (part.oemPn.trim().isNotEmpty) {
                          details.add('OEM: ${part.oemPn.trim()}');
                        }
                        if (part.vendorPn.trim().isNotEmpty) {
                          details.add('Vendor PN: ${part.vendorPn.trim()}');
                        }
                        if (part.vendorName.trim().isNotEmpty) {
                          details.add('Vendor: ${part.vendorName.trim()}');
                        }
                        if (part.vendorPhoneNumber.trim().isNotEmpty) {
                          details.add(
                            'Phone: ${part.vendorPhoneNumber.trim()}',
                          );
                        }
                        if (part.estimatedLeadTime.trim().isNotEmpty) {
                          details.add(
                            'Lead Time: ${part.estimatedLeadTime.trim()}',
                          );
                        }
                        final normalizedVendorUrl = _normalizedVendorUrl(
                          part.vendorUrl,
                        );

                        return pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${index + 1}. ${details.join(' | ')}'),
                            if (normalizedVendorUrl != null)
                              pw.UrlLink(
                                destination: normalizedVendorUrl,
                                child: pw.Text(
                                  'Link: $normalizedVendorUrl',
                                  style: pw.TextStyle(
                                    color: PdfColors.blue,
                                    decoration: pw.TextDecoration.underline,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    final pdfBytes = await document.save();
    await _presentPdfForPrinting(
      fileName,
      pdfBytes,
      successMessage:
          'Opened $fileName in your default PDF viewer. Use the viewer print command to print it.',
    );
  }

  Widget _buildCalendarTab() {
    _ensureMachinesVisible();
    final items = _buildEstimatedTasksForCalendar();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'All maintenance tasks listed in due order. Tasks without a '
                  'date-based interval appear at the end as Unavailable.',
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, int>>(
                  future: MachineDatabase.instance.getWorkOrderStatusCounts(),
                  builder: (context, snapshot) {
                    final statusCounts = snapshot.data ?? const <String, int>{};
                    final bypassedCount = statusCounts['Bypass'] ?? 0;
                    final partialCount = statusCounts['Partial'] ?? 0;
                    final dueBuckets = _dueBucketCounts(
                      items,
                      bypassed: bypassedCount,
                      partial: partialCount,
                    );

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: dueBuckets
                            .map(
                              (bucket) => Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bucket.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${bucket.count}'),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildForecastRequiredPartsSection(items),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No maintenance tasks are available to display.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _reloadMachinesFromDatabase(showFeedback: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload Data'),
                  ),
                ],
              ),
            ),
          )
        else
          ...items.map(_buildScheduleTaskCard),
      ],
    );
  }

  Widget _buildScheduleTaskCard(_EstimatedTaskItem item) {
    final dueDate = _formatDate(item.projectedDate);
    final dueIn = _dueInLabel(item.daysUntilDue);
    final machineLicenseTrades = _machineLicenseTradeLabels(item.machine);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.task.taskType,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Due Date: $dueDate ($dueIn)'),
            Text('Machine: ${item.machine.name}'),
            Text('Sub-Assembly: ${item.subAssembly.name}'),
            Text('Interval: ${item.task.timeValue} ${item.task.timeCategory}'),
            Text('Component: ${item.subAssembly.subCategory}'),
            Text('Location: ${item.subAssembly.location}'),
            const SizedBox(height: 8),
            Text(
              'Required Trades',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: machineLicenseTrades.isEmpty
                  ? const [Chip(label: Text('None'))]
                  : machineLicenseTrades
                        .map((trade) => Chip(label: Text(trade)))
                        .toList(growable: false),
            ),
            if (item.task.requiredParts.any((p) => !p.isEmpty)) ...[
              const SizedBox(height: 10),
              Text(
                'Required Parts',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: item.task.requiredParts
                    .where((part) => !part.isEmpty)
                    .map(
                      (part) => Tooltip(
                        message: [
                          if (part.vendorUrl.trim().isNotEmpty)
                            'Tap chip to open vendor link',
                          if (part.vendorUrl.trim().isNotEmpty)
                            'URL: ${part.vendorUrl.trim()}',
                          if (part.vendorPhoneNumber.trim().isNotEmpty)
                            'Phone: ${part.vendorPhoneNumber.trim()}',
                        ].join('\n'),
                        child: ActionChip(
                          onPressed: part.vendorUrl.trim().isEmpty
                              ? null
                              : () async {
                                  await _openVendorUrl(part.vendorUrl);
                                },
                          avatar: Icon(
                            part.vendorUrl.trim().isEmpty
                                ? Icons.inventory_2_outlined
                                : Icons.open_in_new_outlined,
                            size: 18,
                          ),
                          label: Text(_requiredPartChipLabel(part)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
