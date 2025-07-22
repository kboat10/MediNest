import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/health_data_provider.dart';
import 'dart:math';
import 'package:flutter/services.dart';


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
  
  // Daily tip state
  String _dailyTip = '';
  bool _isLoadingTip = false;
  int _tipIndex = DateTime.now().millisecondsSinceEpoch % 10000;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadDailyTip();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadReminders(),
      _loadHealthNews(),
      _loadDailyTip(),
    ]);
  }

  Future<void> _loadDailyTip() async {
    setState(() {
      _isLoadingTip = true;
    });

    try {
      final tip = await ApiService.getHealthTip(seed: _tipIndex);
      setState(() {
        _dailyTip = tip;
      });
    } catch (e) {
      setState(() {
        _dailyTip = 'Stay hydrated and get enough sleep!';
      });
    } finally {
      setState(() {
        _isLoadingTip = false;
      });
    }
  }

  Future<void> _refreshTip() async {
    final random = Random();
    int newIndex;
    do {
      newIndex = random.nextInt(10000);
    } while (newIndex == _tipIndex);
    
    setState(() {
      _tipIndex = newIndex;
    });
    
    await _loadDailyTip();
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
    final condition = Provider.of<UserPreferencesProvider>(context).healthCondition;
    final Map<String, List<String>> conditionTips = {
      'Sickle Cell Disease': [
        'Drink plenty of water daily to prevent crises.',
        'Avoid extreme temperatures and stress.',
        'Take prescribed medications regularly.',
        'Seek medical attention for fever or pain crises.',
      ],
      'Hypertension': [
        'Monitor your blood pressure regularly.',
        'Reduce salt intake and eat a balanced diet.',
        'Exercise regularly and maintain a healthy weight.',
        'Take your blood pressure medication as prescribed.',
      ],
      'Diabetes': [
        'Monitor your blood sugar regularly.',
        'Eat a healthy, balanced diet and avoid sugary foods.',
        'Exercise regularly and maintain a healthy weight.',
        'Take your diabetes medication or insulin as prescribed.',
      ],
      'Asthma': [
        'Avoid known triggers and allergens.',
        'Use your inhaler as prescribed.',
        'Monitor your breathing and peak flow.',
        'Seek help if you have difficulty breathing.',
      ],
      'Heart Disease': [
        'Follow a heart-healthy diet.',
        'Exercise regularly as advised by your doctor.',
        'Take your heart medications as prescribed.',
        'Monitor for chest pain or shortness of breath.',
      ],
      'Chronic Kidney Disease': [
        'Limit salt and protein intake as advised.',
        'Monitor your blood pressure and blood sugar.',
        'Take medications as prescribed.',
        'Attend all scheduled checkups.',
      ],
      'COPD': [
        'Avoid smoking and air pollutants.',
        'Take your inhalers and medications as prescribed.',
        'Stay active but pace yourself.',
        'Seek help if you have trouble breathing.',
      ],
      'Pregnancy': [
        'Attend all prenatal appointments.',
        'Eat a balanced diet and take prenatal vitamins.',
        'Avoid alcohol, smoking, and certain medications.',
        'Stay active with safe exercises.',
      ],
      'None': [
        'Maintain a balanced diet and exercise regularly.',
        'Get enough sleep and manage stress.',
        'Stay hydrated and avoid smoking.',
        'Visit your doctor for regular checkups.',
      ],
    };
    final tips = (conditionTips[condition] ?? conditionTips['None']) ?? <String>[];
    final Map<String, List<String>> newsKeywords = {
      'Sickle Cell Disease': ['sickle cell', 'anemia', 'blood disorder', 'hemoglobin', 'pain crisis', 'vaso-occlusive'],
      'Hypertension': ['hypertension', 'blood pressure', 'cardiovascular', 'heart disease', 'stroke', 'bp'],
      'Diabetes': ['diabetes', 'blood sugar', 'insulin', 'glucose', 'diabetic', 'type 1', 'type 2', 'glycemic'],
      'Asthma': ['asthma', 'respiratory', 'breathing', 'inhaler', 'bronchial', 'allergy', 'wheeze'],
      'Heart Disease': ['heart', 'cardiac', 'cardiovascular', 'coronary', 'artery', 'heart attack', 'chest pain'],
      'Chronic Kidney Disease': ['kidney', 'renal', 'dialysis', 'nephrology', 'creatinine', 'kidney disease'],
      'COPD': ['copd', 'lung', 'respiratory', 'breathing', 'chronic obstructive', 'emphysema', 'bronchitis'],
      'Pregnancy': ['pregnancy', 'prenatal', 'maternal', 'pregnant', 'fetal', 'obstetric', 'birth'],
      'None': ['health', 'medical', 'wellness', 'nutrition', 'exercise', 'prevention'],
    };
    // Filter news and reminders by keywords if possible
    List<Map<String, dynamic>> filteredNews = _healthNews;
    List<Map<String, dynamic>> filteredReminders = _reminders;
    final keywords = newsKeywords[condition] ?? [];
    
    if (keywords.isNotEmpty && _healthNews.isNotEmpty) {
      // First try to find articles matching the user's condition
      filteredNews = _healthNews.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final summary = (item['summary'] ?? '').toString().toLowerCase();
        return keywords.any((kw) => title.contains(kw) || summary.contains(kw));
      }).toList();
      
      // If no condition-specific news found, show general health news
      if (filteredNews.isEmpty) {
        final generalKeywords = newsKeywords['None'] ?? [];
        filteredNews = _healthNews.where((item) {
          final title = (item['title'] ?? '').toString().toLowerCase();
          final summary = (item['summary'] ?? '').toString().toLowerCase();
          return generalKeywords.any((kw) => title.contains(kw) || summary.contains(kw));
        }).toList();
      }
      
      // If still no news, show all news
      if (filteredNews.isEmpty) {
        filteredNews = _healthNews;
      }
      
      filteredReminders = _reminders.where((item) {
        final text = (item['text'] ?? '').toString().toLowerCase();
        return keywords.any((kw) => text.contains(kw));
      }).toList();
    }
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
                  Consumer<UserPreferencesProvider>(
                    builder: (context, preferences, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 6,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: condition == 'Hypertension'
                                    ? [Color(0xFF7B1FA2), Color(0xFF512DA8)]
                                    : condition == 'Diabetes'
                                      ? [Color(0xFF009688), Color(0xFF43CEA2)]
                                      : condition == 'Sickle Cell Disease'
                                        ? [Color(0xFFD32F2F), Color(0xFFB71C1C)]
                                        : [Color(0xFF232A34), Color(0xFF181C1F)],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info, color: Colors.white, size: 36),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          condition.isNotEmpty && condition != 'None'
                                            ? '$condition Advice'
                                            : 'General Health Advice',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...tips.map((tip) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontSize: 16, color: Colors.white)),
                                        Expanded(child: Text(tip, style: const TextStyle(fontSize: 16, color: Colors.white70))),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ),
                  // Daily Health Tip
                  _buildSectionHeader(context, 'Daily Health Tip'),
                  Card(
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
                          _isLoadingTip
                            ? const Center(child: CircularProgressIndicator())
                            : Text(
                                _dailyTip,
                                style: const TextStyle(fontSize: 16),
                              ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _refreshTip,
                              icon: const Icon(Icons.refresh),
                              label: const Text('New Tip'),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                  onTap: _isLoadingReminders ? null : () => _showRemindersDialog(filteredReminders),
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
                  _buildSectionHeader(context, condition.isNotEmpty && condition != 'None' 
                      ? 'Health News for $condition' 
                      : 'General Health News'),
                  if (_isLoadingNews)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (filteredNews.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(Icons.newspaper, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              condition.isNotEmpty && condition != 'None' 
                                  ? 'No recent news found for $condition'
                                  : 'No health news available at the moment',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Check back later for updates or browse general health tips above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                            ...filteredNews.map((news) => Card(
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
                      );
                    },
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

  void _showRemindersDialog(List<Map<String, dynamic>> filteredReminders) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smart Reminders'),
        content: SizedBox(
          width: double.maxFinite,
          child: filteredReminders.isEmpty
              ? const Center(
                  child: Text('No reminders available'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = filteredReminders[index];
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
  const _SymptomCheckerWidget({Key? key}) : super(key: key);

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
  const _DrugLookupWidget({Key? key}) : super(key: key);

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

  String _generateGoogleSearchUrl(String drugName) {
    final encodedDrugName = Uri.encodeComponent(drugName.trim());
    return 'https://www.google.com/search?q=$encodedDrugName+medication+information+uses+side+effects';
  }

  void _copySearchUrl(String drugName) {
    final url = _generateGoogleSearchUrl(drugName);
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Google search link copied to clipboard!'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            // Show the URL in a dialog for manual opening
            _showUrlDialog(url);
          },
        ),
      ),
    );
  }

  void _showUrlDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drug Information Search'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy this link and paste it in your browser for detailed drug information:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                url,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard!')),
              );
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
                onChanged: (value) {
                  setState(() {}); // Refresh to update button state
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _drugController.text.trim().isEmpty 
                  ? null 
                  : () => _copySearchUrl(_drugController.text.trim()),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
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