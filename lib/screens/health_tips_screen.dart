import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../services/api_service.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/health_data_provider.dart';
import 'dart:math';

final tipIndexProvider = riverpod.StateProvider<int>((ref) => DateTime.now().millisecondsSinceEpoch % 10000);
final healthTipProvider = riverpod.FutureProvider.family<String, int>((ref, seed) async {
  return await ApiService.getHealthTip(seed: seed);
});

class HealthTipsScreen extends StatefulWidget {
  const HealthTipsScreen({Key? key}) : super(key: key);

  @override
  State<HealthTipsScreen> createState() => _HealthTipsScreenState();
}

class _HealthTipsScreenState extends State<HealthTipsScreen> {
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _healthNews = [];
  List<Map<String, dynamic>> _drugInteractions = [];
  bool _isLoadingReminders = true;
  bool _isLoadingNews = true;
  bool _isCheckingInteractions = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadReminders(),
      _loadHealthNews(),
    ]);
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoadingReminders = true;
    });

    try {
      final reminders = await ApiService.getMedicationReminders();
      setState(() {
        _reminders = reminders;
      });
    } catch (e) {
      setState(() {
        _reminders = [];
      });
    } finally {
      setState(() {
        _isLoadingReminders = false;
      });
    }
  }

  Future<void> _loadHealthNews() async {
    setState(() {
      _isLoadingNews = true;
    });

    try {
      final news = await ApiService.getHealthNews();
      setState(() {
        _healthNews = news;
      });
    } catch (e) {
      setState(() {
        _healthNews = [];
      });
    } finally {
      setState(() {
        _isLoadingNews = false;
      });
    }
  }

  Future<void> _checkDrugInteractions() async {
    setState(() {
      _isCheckingInteractions = true;
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      final drugNames = healthData.medications.map((m) => m.name).toList();
      
      if (drugNames.length >= 2) {
        final interactions = await ApiService.getDrugInteractions(drugNames);
        setState(() {
          _drugInteractions = interactions;
        });
      } else {
        setState(() {
          _drugInteractions = [];
        });
      }
    } catch (e) {
      setState(() {
        _drugInteractions = [];
      });
    } finally {
      setState(() {
        _isCheckingInteractions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Tips & Info'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<UserPreferencesProvider>(
        builder: (context, preferences, child) {
          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Health Tip (Riverpod)
                  _buildSectionHeader(context, 'Daily Health Tip'),
                  riverpod.Consumer(
                    builder: (context, ref, _) {
                      final tipIndex = ref.watch(tipIndexProvider);
                      final tipAsync = ref.watch(healthTipProvider(tipIndex));
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb,
                                    color: preferences.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Tip of the Day',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              tipAsync.when(
                                data: (tip) => Text(
                                  tip,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => const Text('Stay hydrated and get enough sleep!'),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    final random = Random();
                                    int newIndex;
                                    do {
                                      newIndex = random.nextInt(10000);
                                    } while (newIndex == tipIndex);
                                    ref.read(tipIndexProvider.notifier).state = newIndex;
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('New Tip'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Medication Reminders
                  _buildSectionHeader(context, 'Smart Reminders'),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Medication Reminders'),
                          subtitle: const Text('AI-powered reminders'),
                          leading: Icon(
                            Icons.notifications_active,
                            color: preferences.primaryColor,
                          ),
                          trailing: _isLoadingReminders
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _isLoadingReminders ? null : () => _showRemindersDialog(),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text('Drug Interactions'),
                          subtitle: const Text('Check for potential conflicts'),
                          leading: Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          trailing: _isCheckingInteractions
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _isCheckingInteractions ? null : _checkDrugInteractions,
                        ),
                      ],
                    ),
                  ),

                  // Health News
                  _buildSectionHeader(context, 'Health News'),
                  if (_isLoadingNews)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (_healthNews.isEmpty)
                    Card(
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('No health news available'),
                        ),
                      ),
                    )
                  else
                    ..._healthNews.map((news) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          news['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(news['summary']),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.source,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  news['source'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(DateTime.parse(news['date'])),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showNewsDetail(news),
                      ),
                    )),

                  // Symptom Checker
                  _buildSectionHeader(context, 'Symptom Checker'),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check your symptoms',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Enter a symptom to get suggestions (not medical advice)',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          _SymptomCheckerWidget(),
                        ],
                      ),
                    ),
                  ),

                  // Drug Information
                  _buildSectionHeader(context, 'Drug Information'),
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Look up medication information',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Get detailed information about medications from the FDA database',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          _DrugLookupWidget(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showRemindersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smart Reminders'),
        content: SizedBox(
          width: double.maxFinite,
          child: _reminders.isEmpty
              ? const Center(
                  child: Text('No reminders available'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _reminders[index];
                    return ListTile(
                      leading: Icon(
                        _getReminderIcon(reminder['type']),
                        color: _getReminderColor(reminder['type']),
                      ),
                      title: Text(reminder['title']),
                      subtitle: Text(reminder['message']),
                      trailing: Text(
                        reminder['time'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNewsDetail(Map<String, dynamic> news) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(news['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(news['summary']),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.source, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    news['source'],
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Published: ${_formatDate(DateTime.parse(news['date']))}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _getReminderIcon(String type) {
    switch (type) {
      case 'medication':
        return Icons.medication;
      case 'appointment':
        return Icons.calendar_today;
      case 'refill':
        return Icons.refresh;
      default:
        return Icons.notifications;
    }
  }

  Color _getReminderColor(String type) {
    switch (type) {
      case 'medication':
        return Colors.blue;
      case 'appointment':
        return Colors.green;
      case 'refill':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SymptomCheckerWidget extends StatefulWidget {
  @override
  State<_SymptomCheckerWidget> createState() => _SymptomCheckerWidgetState();
}

class _SymptomCheckerWidgetState extends State<_SymptomCheckerWidget> {
  final TextEditingController _symptomController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _symptomController.dispose();
    super.dispose();
  }

  Future<void> _checkSymptom() async {
    if (_symptomController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final suggestions = await ApiService.getSymptomSuggestions(_symptomController.text.trim());
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      setState(() {
        _suggestions = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _symptomController,
                decoration: const InputDecoration(
                  hintText: 'Enter symptom (e.g., headache, fever)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _checkSymptom,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check'),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._suggestions.map((suggestion) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                _getSeverityIcon(suggestion['severity']),
                color: _getSeverityColor(suggestion['severity']),
              ),
              title: Text(suggestion['symptom']),
              subtitle: Text(suggestion['suggestion']),
            ),
          )),
        ],
      ],
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'mild':
        return Icons.info;
      case 'moderate':
        return Icons.warning;
      case 'severe':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'mild':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _DrugLookupWidget extends StatefulWidget {
  @override
  State<_DrugLookupWidget> createState() => _DrugLookupWidgetState();
}

class _DrugLookupWidgetState extends State<_DrugLookupWidget> {
  final TextEditingController _drugController = TextEditingController();
  Map<String, dynamic>? _drugInfo;
  bool _isLoading = false;

  @override
  void dispose() {
    _drugController.dispose();
    super.dispose();
  }

  Future<void> _lookupDrug() async {
    if (_drugController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final drugInfo = await ApiService.getDrugInfo(_drugController.text.trim());
      setState(() {
        _drugInfo = drugInfo;
      });
    } catch (e) {
      setState(() {
        _drugInfo = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _drugController,
                decoration: const InputDecoration(
                  hintText: 'Enter drug name (e.g., aspirin)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _lookupDrug,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lookup'),
            ),
          ],
        ),
        if (_drugInfo != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _drugInfo!['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (_drugInfo!['brand_name'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Brand: ${_drugInfo!['brand_name']}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                  if (_drugInfo!['description'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Description:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_drugInfo!['description']),
                  ],
                  if (_drugInfo!['indications'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Indications:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(_drugInfo!['indications']),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
} 