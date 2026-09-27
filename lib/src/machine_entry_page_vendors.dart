// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

class _VendorPartUsage {
  _VendorPartUsage({
    required this.vendorName,
    required this.oemPn,
    required this.vendorPn,
    required this.vendorUrl,
    required this.vendorPhoneNumber,
    required this.estimatedLeadTime,
  });

  final String vendorName;
  final String oemPn;
  final String vendorPn;
  final String vendorUrl;
  final String vendorPhoneNumber;
  final String estimatedLeadTime;
  final Set<String> machineNames = <String>{};
  final Set<String> subAssemblyNames = <String>{};
  final Set<String> taskTypes = <String>{};
  int occurrences = 0;
}

enum _VendorSortMode { vendorNameAsc, usageCountDesc, leadTimeAsc }

extension _MachineEntryPageVendorsExtension on _MachineEntryPageState {
  Widget _buildVendorsTab() {
    final grouped = _collectVendorPartUsage(
      searchQuery: _vendorsSearchQuery,
      includeUnspecifiedVendor: _vendorsIncludeUnspecifiedVendors,
    );
    final vendorNames = grouped.keys.toList(growable: false)
      ..sort((a, b) => _compareVendorNames(a, b, grouped));

    var totalPartRows = 0;
    var totalOccurrences = 0;
    for (final entries in grouped.values) {
      totalPartRows += entries.length;
      for (final usage in entries) {
        totalOccurrences += usage.occurrences;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: _vendorsSearchQuery,
                  decoration: const InputDecoration(
                    labelText: 'Search vendors or parts',
                    prefixIcon: Icon(Icons.search_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _vendorsSearchQuery = value;
                    });
                    _schedulePersistVendorsSearchPreferences();
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include "Unspecified Vendor" rows'),
                  value: _vendorsIncludeUnspecifiedVendors,
                  onChanged: (value) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _vendorsIncludeUnspecifiedVendors = value;
                    });
                    unawaited(_persistVendorsTabPreferences());
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<_VendorSortMode>(
                  initialValue: _vendorsSortMode,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                  ),
                  items: _VendorSortMode.values
                      .map(
                        (mode) => DropdownMenuItem<_VendorSortMode>(
                          value: mode,
                          child: Text(_vendorSortModeLabel(mode)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null || !mounted) {
                      return;
                    }
                    setState(() {
                      _vendorsSortMode = value;
                    });
                    unawaited(_persistVendorsTabPreferences());
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    Chip(label: Text('Vendors: ${vendorNames.length}')),
                    Chip(label: Text('Unique Parts: $totalPartRows')),
                    Chip(label: Text('Part Usages: $totalOccurrences')),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _copyVendorsCsvToClipboard(grouped);
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Copy CSV Export'),
                    ),
                    if (_vendorsSearchQuery.trim().isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _vendorsSearchQuery = '';
                          });
                          unawaited(_persistVendorsTabPreferences());
                        },
                        icon: const Icon(Icons.clear_outlined),
                        label: const Text('Clear Search'),
                      ),
                  ],
                ),
                if (_showRandomizeButtons) ...[
                  const SizedBox(height: 10),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Add Random Machines (populates vendor data)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Vendors are derived from required parts on machines. '
                    'Adding random machines with vendor-tagged parts will populate this tab.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _bulkRandomMachinesController,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: false,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Machine count',
                            helperText: '1 to 500',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final count = int.tryParse(
                                  _bulkRandomMachinesController.text.trim(),
                                );
                                if (count == null ||
                                    count < 1 ||
                                    count > 500) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Enter a whole number between 1 and 500.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await _appendRandomMachinesWithRowCount(count);
                              },
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Add Random Machines'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (vendorNames.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _vendorsSearchQuery.trim().isEmpty
                    ? 'No vendor/parts data found in machine inputs yet. Add required parts inside machine maintenance tasks to populate this tab.'
                    : 'No vendor/part rows match your current search/filter.',
              ),
            ),
          )
        else
          for (final vendorName in vendorNames)
            _buildVendorCard(vendorName, grouped[vendorName] ?? const []),
      ],
    );
  }

  Widget _buildVendorCard(String vendorName, List<_VendorPartUsage> entries) {
    final sortedEntries = List<_VendorPartUsage>.from(entries)
      ..sort(_comparePartUsage);
    final machineCount = sortedEntries
        .expand((entry) => entry.machineNames)
        .toSet()
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(vendorName),
        subtitle: Text(
          '${sortedEntries.length} parts across $machineCount machines',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final usage in sortedEntries)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OEM PN: ${usage.oemPn.isEmpty ? '-' : usage.oemPn} | Vendor PN: ${usage.vendorPn.isEmpty ? '-' : usage.vendorPn}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (usage.vendorUrl.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('URL:'),
                        TextButton(
                          onPressed: () async {
                            await _openVendorUrl(usage.vendorUrl);
                          },
                          child: Text(usage.vendorUrl),
                        ),
                      ],
                    ),
                  if (usage.vendorPhoneNumber.isNotEmpty)
                    Text('Phone: ${usage.vendorPhoneNumber}'),
                  if (usage.estimatedLeadTime.isNotEmpty)
                    Text('Lead Time: ${usage.estimatedLeadTime}'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Usages: ${usage.occurrences}')),
                      Chip(label: Text('Machines: ${usage.machineNames.length}')),
                      Chip(
                        label: Text(
                          'Sub-Assemblies: ${usage.subAssemblyNames.length}',
                        ),
                      ),
                      Chip(label: Text('Task Types: ${usage.taskTypes.length}')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (usage.machineNames.isNotEmpty)
                    Text('Machines: ${usage.machineNames.join(', ')}'),
                  if (usage.subAssemblyNames.isNotEmpty)
                    Text('Sub-Assemblies: ${usage.subAssemblyNames.join(', ')}'),
                  if (usage.taskTypes.isNotEmpty)
                    Text('Task Types: ${usage.taskTypes.join(', ')}'),
                  const Divider(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<_VendorPartUsage>> _collectVendorPartUsage({
    String searchQuery = '',
    bool includeUnspecifiedVendor = true,
  }) {
    final byVendorAndPart = <String, _VendorPartUsage>{};
    final normalizedQuery = searchQuery.trim().toLowerCase();

    for (final machine in _machines) {
      final machineName = machine.name.trim().isEmpty
          ? 'Unnamed Machine'
          : machine.name.trim();
      for (final subAssembly in machine.subAssemblies) {
        final subAssemblyName = subAssembly.name.trim().isEmpty
            ? 'Unnamed Sub-Assembly'
            : subAssembly.name.trim();

        for (final task in subAssembly.maintenanceTasks) {
          final taskType = task.taskType.trim().isEmpty
              ? 'Unspecified Task'
              : task.taskType.trim();

          for (final part in task.requiredParts) {
            if (part.isEmpty) {
              continue;
            }

            final vendorName = part.vendorName.trim().isEmpty
                ? 'Unspecified Vendor'
                : part.vendorName.trim();
            if (!includeUnspecifiedVendor &&
                vendorName.toLowerCase() == 'unspecified vendor') {
              continue;
            }

            final oemPn = part.oemPn.trim();
            final vendorPn = part.vendorPn.trim();
            final vendorUrl = part.vendorUrl.trim();
            final vendorPhone = part.vendorPhoneNumber.trim();
            final leadTime = part.estimatedLeadTime.trim();

            final key = [
              vendorName.toUpperCase(),
              oemPn.toUpperCase(),
              vendorPn.toUpperCase(),
              vendorUrl.toLowerCase(),
              vendorPhone,
              leadTime,
            ].join('|');

            final usage = byVendorAndPart.putIfAbsent(
              key,
              () => _VendorPartUsage(
                vendorName: vendorName,
                oemPn: oemPn,
                vendorPn: vendorPn,
                vendorUrl: vendorUrl,
                vendorPhoneNumber: vendorPhone,
                estimatedLeadTime: leadTime,
              ),
            );

            usage.occurrences += 1;
            usage.machineNames.add(machineName);
            usage.subAssemblyNames.add(subAssemblyName);
            usage.taskTypes.add(taskType);
          }
        }
      }
    }

    if (normalizedQuery.isNotEmpty) {
      byVendorAndPart.removeWhere((_, usage) {
        final haystack = [
          usage.vendorName,
          usage.oemPn,
          usage.vendorPn,
          usage.vendorUrl,
          usage.vendorPhoneNumber,
          usage.estimatedLeadTime,
          ...usage.machineNames,
          ...usage.subAssemblyNames,
          ...usage.taskTypes,
        ].join(' ').toLowerCase();
        return !haystack.contains(normalizedQuery);
      });
    }

    final grouped = <String, List<_VendorPartUsage>>{};
    for (final usage in byVendorAndPart.values) {
      grouped.putIfAbsent(usage.vendorName, () => <_VendorPartUsage>[]).add(usage);
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) {
        final aOem = a.oemPn.toLowerCase();
        final bOem = b.oemPn.toLowerCase();
        if (aOem != bOem) {
          return aOem.compareTo(bOem);
        }
        return a.vendorPn.toLowerCase().compareTo(b.vendorPn.toLowerCase());
      });
    }

    return grouped;
  }

  String _vendorSortModeLabel(_VendorSortMode mode) {
    switch (mode) {
      case _VendorSortMode.vendorNameAsc:
        return 'Vendor Name (A-Z)';
      case _VendorSortMode.usageCountDesc:
        return 'Usage Count (High to Low)';
      case _VendorSortMode.leadTimeAsc:
        return 'Lead Time (A-Z)';
    }
  }

  int _compareVendorNames(
    String a,
    String b,
    Map<String, List<_VendorPartUsage>> grouped,
  ) {
    switch (_vendorsSortMode) {
      case _VendorSortMode.vendorNameAsc:
        return a.toLowerCase().compareTo(b.toLowerCase());
      case _VendorSortMode.usageCountDesc:
        final aTotal = _vendorUsageTotal(grouped[a] ?? const []);
        final bTotal = _vendorUsageTotal(grouped[b] ?? const []);
        if (aTotal != bTotal) {
          return bTotal.compareTo(aTotal);
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
      case _VendorSortMode.leadTimeAsc:
        final aLead = _vendorLeadTimeKey(grouped[a] ?? const []);
        final bLead = _vendorLeadTimeKey(grouped[b] ?? const []);
        final compareLead = aLead.compareTo(bLead);
        if (compareLead != 0) {
          return compareLead;
        }
        return a.toLowerCase().compareTo(b.toLowerCase());
    }
  }

  int _comparePartUsage(_VendorPartUsage a, _VendorPartUsage b) {
    switch (_vendorsSortMode) {
      case _VendorSortMode.vendorNameAsc:
        final compareOem = a.oemPn.toLowerCase().compareTo(b.oemPn.toLowerCase());
        if (compareOem != 0) {
          return compareOem;
        }
        return a.vendorPn.toLowerCase().compareTo(b.vendorPn.toLowerCase());
      case _VendorSortMode.usageCountDesc:
        if (a.occurrences != b.occurrences) {
          return b.occurrences.compareTo(a.occurrences);
        }
        return a.oemPn.toLowerCase().compareTo(b.oemPn.toLowerCase());
      case _VendorSortMode.leadTimeAsc:
        final aLead = a.estimatedLeadTime.trim().toLowerCase();
        final bLead = b.estimatedLeadTime.trim().toLowerCase();
        final compareLead = aLead.compareTo(bLead);
        if (compareLead != 0) {
          return compareLead;
        }
        return a.oemPn.toLowerCase().compareTo(b.oemPn.toLowerCase());
    }
  }

  int _vendorUsageTotal(List<_VendorPartUsage> entries) {
    var total = 0;
    for (final entry in entries) {
      total += entry.occurrences;
    }
    return total;
  }

  String _vendorLeadTimeKey(List<_VendorPartUsage> entries) {
    final leadTimes = entries
        .map((entry) => entry.estimatedLeadTime.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList(growable: false)
      ..sort();
    if (leadTimes.isEmpty) {
      return 'zzz';
    }
    return leadTimes.first;
  }

  Future<void> _copyVendorsCsvToClipboard(
    Map<String, List<_VendorPartUsage>> grouped,
  ) async {
    final rows = <List<String>>[
      <String>[
        'vendorName',
        'oemPn',
        'vendorPn',
        'vendorUrl',
        'vendorPhoneNumber',
        'estimatedLeadTime',
        'occurrences',
        'machineNames',
        'subAssemblyNames',
        'taskTypes',
      ],
    ];

    final vendorNames = grouped.keys.toList(growable: false)
      ..sort((a, b) => _compareVendorNames(a, b, grouped));
    for (final vendorName in vendorNames) {
      final entries = List<_VendorPartUsage>.from(
        grouped[vendorName] ?? const <_VendorPartUsage>[],
      )..sort(_comparePartUsage);
      for (final usage in entries) {
        rows.add(<String>[
          usage.vendorName,
          usage.oemPn,
          usage.vendorPn,
          usage.vendorUrl,
          usage.vendorPhoneNumber,
          usage.estimatedLeadTime,
          usage.occurrences.toString(),
          usage.machineNames.join(' | '),
          usage.subAssemblyNames.join(' | '),
          usage.taskTypes.join(' | '),
        ]);
      }
    }

    final csv = rows
        .map(
          (row) => row
              .map((value) => '"${value.replaceAll('"', '""')}"')
              .join(','),
        )
        .join('\n');

    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vendors CSV copied to clipboard.')),
    );
  }

  Future<void> _openVendorUrl(String rawUrl) async {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid URL: $rawUrl')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open URL: $normalized')),
    );
  }

  Future<void> _loadVendorsTabPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final search =
        preferences.getString(_MachineEntryPageState._vendorsSearchPreferenceKey) ??
        '';
    final sortName =
        preferences.getString(_MachineEntryPageState._vendorsSortPreferenceKey) ??
        _VendorSortMode.vendorNameAsc.name;
    final includeUnspecified =
        preferences.getBool(
          _MachineEntryPageState._vendorsIncludeUnspecifiedPreferenceKey,
        ) ??
        true;

    final parsedSort = _VendorSortMode.values.firstWhere(
      (mode) => mode.name == sortName,
      orElse: () => _VendorSortMode.vendorNameAsc,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _vendorsSearchQuery = search;
      _vendorsSortMode = parsedSort;
      _vendorsIncludeUnspecifiedVendors = includeUnspecified;
    });
  }

  Future<void> _persistVendorsTabPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _MachineEntryPageState._vendorsSearchPreferenceKey,
      _vendorsSearchQuery,
    );
    await preferences.setString(
      _MachineEntryPageState._vendorsSortPreferenceKey,
      _vendorsSortMode.name,
    );
    await preferences.setBool(
      _MachineEntryPageState._vendorsIncludeUnspecifiedPreferenceKey,
      _vendorsIncludeUnspecifiedVendors,
    );
  }

  void _schedulePersistVendorsSearchPreferences() {
    _vendorsSearchPersistDebounce?.cancel();
    _vendorsSearchPersistDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        unawaited(_persistVendorsTabPreferences());
      },
    );
  }
}
