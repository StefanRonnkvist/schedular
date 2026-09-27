// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageContractorsExtension on _MachineEntryPageState {
  void _fillRandomContractorCompanyValues({
    required TextEditingController nameController,
    required TextEditingController addressController,
    required TextEditingController phoneController,
    required TextEditingController faxController,
    required TextEditingController urlController,
    required TextEditingController skillsController,
    required TextEditingController licensesController,
    Random? random,
  }) {
    final rng = random ?? Random();
    const companyPrefixes = <String>[
      'North',
      'Prime',
      'Summit',
      'Atlas',
      'Precision',
      'Rapid',
    ];
    const companyDomains = <String>[
      'Mechanical',
      'Industrial',
      'Field Services',
      'Plant Support',
      'Maintenance Group',
      'Automation',
    ];

    final prefix = companyPrefixes[rng.nextInt(companyPrefixes.length)];
    final domain = companyDomains[rng.nextInt(companyDomains.length)];
    final numeric = 10 + rng.nextInt(90);
    final companyName = '$prefix $domain $numeric';
    final companySlug = companyName.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );

    nameController.text = companyName;
    addressController.text =
        '${100 + rng.nextInt(900)} Industry Ave, Suite ${1 + rng.nextInt(40)}';
    phoneController.text =
        '+1-555-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}';
    faxController.text =
        '+1-555-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}';
    urlController.text = 'https://$companySlug.example.com';
    skillsController.text = _pickRandomSubset(
      _availableSkillTypes,
      rng,
    ).join(', ');
    licensesController.text = _pickRandomSubset(
      _licenseTypeOptions,
      rng,
    ).join(', ');
  }

  void _fillRandomContractorEmployeeValues({
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
    Random? random,
  }) {
    final rng = random ?? Random();
    const firstNames = <String>[
      'Jamie',
      'Avery',
      'Cory',
      'Drew',
      'Logan',
      'Skyler',
      'Parker',
      'Reese',
    ];
    const lastNames = <String>[
      'Berg',
      'Shah',
      'Adams',
      'Brown',
      'Clark',
      'Diaz',
      'Evans',
      'Fischer',
    ];

    final first = firstNames[rng.nextInt(firstNames.length)];
    final last = lastNames[rng.nextInt(lastNames.length)];
    final suffix = 10 + rng.nextInt(90);
    nameController.text = '$first $last';
    emailController.text =
        '${first.toLowerCase()}.${last.toLowerCase()}$suffix@example.com';
    phoneController.text =
        '+1-555-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}';
  }

  Widget _buildContractorsTab() {
    return FutureBuilder<List<ContractorCompany>>(
      future: MachineDatabase.instance.getContractorCompanies(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load contractors: ${snapshot.error}'),
          );
        }

        final companies = snapshot.data ?? const <ContractorCompany>[];

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_showRandomizeButtons) ...[
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _bulkRandomContractorsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Count',
                          helperText: '1 to 500',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final count = int.tryParse(
                          _bulkRandomContractorsController.text.trim(),
                        );
                        if (count == null || count < 1 || count > 500) {
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
                        await _appendRandomContractorsWithRowCount(count);
                        if (context.mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Add Random Contractors'),
                    ),
                  ],
                  FilledButton.icon(
                    onPressed: () async {
                      await _showContractorCompanyDialog();
                    },
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add Contractor Company'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (companies.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No contractor companies saved yet.'),
                ),
              )
            else
              ...companies.map((company) {
                return _buildContractorCompanyCard(company);
              }),
          ],
        );
      },
    );
  }

  Widget _buildContractorCompanyCard(ContractorCompany company) {
    final skills = company.matchedSkills;
    final licenses = company.matchedLicenses;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    company.companyName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Company',
                  onPressed: () async {
                    await _showContractorCompanyDialog(existing: company);
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete Company',
                  onPressed: () async {
                    final id = company.id;
                    if (id == null) {
                      return;
                    }
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Delete Contractor Company'),
                          content: Text('Delete "${company.companyName}"?'),
                          actions: _dialogActionsForContext(dialogContext, [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Delete'),
                            ),
                          ]),
                        );
                      },
                    );
                    if (shouldDelete != true) {
                      return;
                    }

                    try {
                      await MachineDatabase.instance.deleteContractorCompany(
                        id,
                      );
                      if (!mounted) {
                        return;
                      }
                      setState(() {});
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      _showErrorSnackBar(
                        'Failed to delete contractor company.',
                        error,
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (company.address.trim().isNotEmpty)
              Text('Address: ${company.address}'),
            if (company.phoneNumber.trim().isNotEmpty)
              Text('Phone: ${company.phoneNumber}'),
            if (company.faxNumber.trim().isNotEmpty)
              Text('Fax: ${company.faxNumber}'),
            if (company.companyUrl.trim().isNotEmpty)
              Text('URL: ${company.companyUrl}'),
            const SizedBox(height: 8),
            Text(
              'Matched Skills',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.isEmpty
                  ? const [Chip(label: Text('None'))]
                  : skills.map((skill) => Chip(label: Text(skill))).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Matched Licenses',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: licenses.isEmpty
                  ? const [Chip(label: Text('None'))]
                  : licenses
                        .map((license) => Chip(label: Text(license)))
                        .toList(),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contractor Employees',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final companyId = company.id;
                    if (companyId == null) {
                      return;
                    }
                    await _showContractorEmployeeDialog(companyId: companyId);
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Employee'),
                ),
              ],
            ),
            _buildContractorEmployeesList(company),
          ],
        ),
      ),
    );
  }

  Widget _buildContractorEmployeesList(ContractorCompany company) {
    final companyId = company.id;
    if (companyId == null) {
      return const Text('Company must be saved before adding employees.');
    }

    return FutureBuilder<List<ContractorEmployeeContact>>(
      future: MachineDatabase.instance.getContractorEmployees(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Failed to load contractor employees: ${snapshot.error}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          );
        }

        final contacts = snapshot.data ?? const <ContractorEmployeeContact>[];
        if (contacts.isEmpty) {
          return const Text('No contractor employees saved yet.');
        }

        return Column(
          children: contacts
              .map((contact) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(contact.fullName),
                  subtitle: Text(
                    [
                      if (contact.email.trim().isNotEmpty) contact.email.trim(),
                      if (contact.phoneNumber.trim().isNotEmpty)
                        contact.phoneNumber.trim(),
                    ].join(' | '),
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Edit Employee',
                        onPressed: () async {
                          await _showContractorEmployeeDialog(
                            companyId: companyId,
                            existing: contact,
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete Employee',
                        onPressed: () async {
                          final id = contact.id;
                          if (id == null) {
                            return;
                          }
                          try {
                            await MachineDatabase.instance
                                .deleteContractorEmployee(id);
                            if (!mounted) {
                              return;
                            }
                            setState(() {});
                          } catch (error) {
                            if (!mounted) {
                              return;
                            }
                            _showErrorSnackBar(
                              'Failed to delete contractor employee.',
                              error,
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _showContractorCompanyDialog({
    ContractorCompany? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.companyName ?? '',
    );
    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );
    final phoneController = TextEditingController(
      text: existing?.phoneNumber ?? '',
    );
    final faxController = TextEditingController(
      text: existing?.faxNumber ?? '',
    );
    final urlController = TextEditingController(
      text: existing?.companyUrl ?? '',
    );
    final skillsController = TextEditingController(
      text: (existing?.matchedSkills ?? const <String>[]).join(', '),
    );
    final licensesController = TextEditingController(
      text: (existing?.matchedLicenses ?? const <String>[]).join(', '),
    );

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Add Contractor Company'
                  : 'Edit Contractor Company',
            ),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Contractor Company Name *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: faxController,
                      decoration: const InputDecoration(
                        labelText: 'Fax Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'Company URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: skillsController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Matched Skills (comma-separated)',
                        hintText: _availableSkillTypes.join(', '),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: licensesController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Matched Licenses (comma-separated)',
                        hintText: _licenseTypeOptions.join(', '),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_showRandomizeButtons) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _fillRandomContractorCompanyValues(
                              nameController: nameController,
                              addressController: addressController,
                              phoneController: phoneController,
                              faxController: faxController,
                              urlController: urlController,
                              skillsController: skillsController,
                              licensesController: licensesController,
                            );
                          },
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Random Values'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      final companyName = nameController.text.trim();
      if (companyName.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contractor company name is required.')),
        );
        return;
      }

      final nextCompany = ContractorCompany(
        id: existing?.id,
        companyName: companyName,
        address: addressController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        faxNumber: faxController.text.trim(),
        companyUrl: urlController.text.trim(),
        matchedSkills: _parseTagInput(skillsController.text),
        matchedLicenses: _parseTagInput(licensesController.text),
      );

      await MachineDatabase.instance.upsertContractorCompany(nextCompany);
      if (!mounted) {
        return;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Contractor company added.'
                : 'Contractor company updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save contractor company.', error);
    } finally {
      nameController.dispose();
      addressController.dispose();
      phoneController.dispose();
      faxController.dispose();
      urlController.dispose();
      skillsController.dispose();
      licensesController.dispose();
    }
  }

  Future<void> _showContractorEmployeeDialog({
    required int companyId,
    ContractorEmployeeContact? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.fullName ?? '',
    );
    final emailController = TextEditingController(text: existing?.email ?? '');
    final phoneController = TextEditingController(
      text: existing?.phoneNumber ?? '',
    );

    try {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              existing == null
                  ? 'Add Contractor Employee'
                  : 'Edit Contractor Employee',
            ),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_showRandomizeButtons) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _fillRandomContractorEmployeeValues(
                            nameController: nameController,
                            emailController: emailController,
                            phoneController: phoneController,
                          );
                        },
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Random Values'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      if (shouldSave != true) {
        return;
      }

      final fullName = nameController.text.trim();
      if (fullName.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contractor employee name is required.'),
          ),
        );
        return;
      }

      final contact = ContractorEmployeeContact(
        id: existing?.id,
        contractorCompanyId: companyId,
        fullName: fullName,
        email: emailController.text.trim(),
        phoneNumber: phoneController.text.trim(),
      );

      await MachineDatabase.instance.upsertContractorEmployee(contact);
      if (!mounted) {
        return;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Contractor employee added.'
                : 'Contractor employee updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save contractor employee.', error);
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  List<String> _parseTagInput(String raw) {
    final normalized = raw
        .split(RegExp(r'[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final seen = <String>{};
    final deduped = <String>[];
    for (final value in normalized) {
      final key = value.toUpperCase();
      if (seen.add(key)) {
        deduped.add(value);
      }
    }
    return deduped;
  }
}
