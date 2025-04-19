import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:clipboard/clipboard.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joke Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            height: 1.5,
          ),
        ),
      ),
      home: const JokeScreen(),
    );
  }
}

class JokeScreen extends StatefulWidget {
  const JokeScreen({super.key});

  @override
  State<JokeScreen> createState() => _JokeScreenState();
}

class _JokeScreenState extends State<JokeScreen> with SingleTickerProviderStateMixin {
  String _joke = 'Ready for a laugh?';
  String _jokeTitle = '';
  bool _isLoading = false;
  late GenerativeModel _model;
  String? _errorMessage;
  final TextEditingController _inputController = TextEditingController();
  final List<String> _randomTopics = [
    'animals', 'programmers', 'school', 'food',
    'sports', 'weather', 'doctors', 'kids',
    'parents', 'work', 'technology', 'travel'
  ];
  final Random _random = Random();
  final List<Map<String, String>> _jokeHistory = [];
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _isFavorite = false;
  final List<String> _favoriteJokes = [];
  int _jokeRating = 0;
  String _selectedJokeType = 'random';
  final List<String> _jokeTypes = ['random', 'pun', 'knock-knock', 'dad joke', 'one-liner'];

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _joke = 'Error: API key not found in .env file';
      _errorMessage = 'Please add GEMINI_API_KEY to your .env file';
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey ?? '',
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.teal[100],
      end: Colors.teal[50],
    ).animate(_animationController);

    // Only start animation when a new joke is generated, not continuously
  }

  @override
  void dispose() {
    _inputController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateJoke([String? topic]) async {
    final jokeTopic = topic ?? _inputController.text.trim();
    
    if (jokeTopic.isEmpty && topic == null) {
      setState(() {
        _joke = 'Please enter a topic first!';
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _joke = 'Generating your joke...';
      _jokeTitle = jokeTopic;
      _errorMessage = null;
      _isFavorite = false;
      _jokeRating = 0;
    });

    try {
      String prompt;
      switch (_selectedJokeType) {
        case 'pun':
          prompt = 'Tell me a clever pun about $jokeTopic. Make it witty and family-friendly.';
          break;
        case 'knock-knock':
          prompt = 'Tell me a knock-knock joke about $jokeTopic. Format it properly with who\'s there and punchline.';
          break;
        case 'dad joke':
          prompt = 'Tell me a cheesy dad joke about $jokeTopic. Make it intentionally corny.';
          break;
        case 'one-liner':
          prompt = 'Tell me a short one-liner joke about $jokeTopic. Just one sentence.';
          break;
        default:
          prompt = 'Tell me a funny, short, family-friendly joke about $jokeTopic. '
              'Return only the joke without any additional text or explanation.';
      }

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from API');
      }

      final newJoke = response.text!.trim();
      setState(() {
        _joke = newJoke;
        _isLoading = false;
        _jokeHistory.insert(0, {
          'topic': jokeTopic,
          'joke': newJoke,
          'time': DateTime.now().toString().substring(11, 16),
          'type': _selectedJokeType,
          'rating': '0',
        });
      });

      _animationController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        _joke = 'Failed to get a joke';
        _errorMessage = 'Error: ${e.toString()}\nCheck your API key and internet connection';
        _isLoading = false;
      });
    }
  }

  void _generateRandomJoke() {
    final randomTopic = _randomTopics[_random.nextInt(_randomTopics.length)];
    _inputController.text = randomTopic;
    _generateJoke(randomTopic);
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      if (_isFavorite) {
        _favoriteJokes.add(_joke);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites!'), duration: Duration(seconds: 1)),
        );
      } else {
        _favoriteJokes.remove(_joke);
      }
    });
  }

  void _rateJoke(int rating) {
    setState(() {
      _jokeRating = rating;
      if (_jokeHistory.isNotEmpty) {
        _jokeHistory.first['rating'] = rating.toString();
      }
    });
  }

  void _shareJoke() {
    Share.share('Check out this joke about $_jokeTitle:\n\n$_joke\n\nShared from Joke Generator App');
  }

  Future<void> _shareAsPdf() async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Joke about $_jokeTitle',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  _joke,
                  style: const pw.TextStyle(fontSize: 18),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated by Joke Generator App',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/joke.pdf");
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out this joke about $_jokeTitle!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  void _copyToClipboard() {
    FlutterClipboard.copy('$_jokeTitle joke:\n$_joke').then(() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard!'), duration: Duration(seconds: 1)),
      );
    } as FutureOr Function(void value));
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Joke History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      _jokeHistory.clear();
                    });
                    Navigator.pop(context);
                  },
                  tooltip: 'Clear History',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _jokeHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No jokes generated yet!',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _jokeHistory.length,
                      itemBuilder: (context, index) {
                        final item = _jokeHistory[index];
                        return Dismissible(
                          key: Key(item['joke']!),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            setState(() {
                              _jokeHistory.removeAt(index);
                            });
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'About ${item['topic']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            item['time']!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.secondary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '(${item['type']})',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item['joke']!),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      ...List.generate(5, (i) => Icon(
                                        Icons.star,
                                        color: i < int.parse(item['rating']!) 
                                            ? Colors.amber 
                                            : Colors.grey,
                                        size: 16,
                                      )),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.content_copy, size: 18),
                                        onPressed: () {
                                          FlutterClipboard.copy(item['joke']!);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Copied to clipboard!'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFavorites(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Favorite Jokes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(),
            Expanded(
              child: _favoriteJokes.isEmpty
                  ? Center(
                      child: Text(
                        'No favorite jokes yet!',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _favoriteJokes.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text(_favoriteJokes[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _favoriteJokes.removeAt(index);
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _joke = _favoriteJokes[index];
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joke Generator'),
        centerTitle: true,
        elevation: 4,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _isLoading ? null : _generateRandomJoke,
            tooltip: 'Random Joke',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _isLoading ? null : () => _showHistory(context),
            tooltip: 'Joke History',
          ),
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: _isLoading ? null : () => _showFavorites(context),
            tooltip: 'Favorites',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _colorAnimation.value ?? Colors.teal[100]!, // Null check added
                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedJokeType,
                                  items: _jokeTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(type.capitalize()),
                                    );
                                  }).toList(),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedJokeType = value!;
                                          });
                                        },
                                  decoration: InputDecoration(
                                    labelText: 'Joke Type',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _inputController,
                                  decoration: InputDecoration(
                                    labelText: 'Enter a topic',
                                    hintText: 'e.g., cats, school, programmers',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.send),
                                      onPressed: _isLoading ? null : () => _generateJoke(),
                                    ),
                                  ),
                                  enabled: !_isLoading,
                                  onSubmitted: (_) => _isLoading ? null : _generateJoke(),
                                ),
                                const SizedBox(height: 24),
                                if (_jokeTitle.isNotEmpty) ...[
                                  Text(
                                    'About $_jokeTitle',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                ],
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    key: ValueKey(_joke),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      _joke,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                if (_jokeTitle.isNotEmpty && !_isLoading) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                                          color: _isFavorite ? Colors.red : null,
                                        ),
                                        onPressed: _toggleFavorite,
                                        tooltip: 'Add to favorites',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.share),
                                        onPressed: _shareJoke,
                                        tooltip: 'Share as text',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf),
                                        onPressed: _shareAsPdf,
                                        tooltip: 'Share as PDF',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.content_copy),
                                        onPressed: _copyToClipboard,
                                        tooltip: 'Copy to clipboard',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      return IconButton(
                                        icon: Icon(
                                          Icons.star,
                                          color: index < _jokeRating 
                                              ? Colors.amber 
                                              : Colors.grey,
                                        ),
                                        onPressed: () => _rateJoke(index + 1),
                                      );
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _generateJoke(),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.emoji_emotions_outlined),
                            label: Text(_isLoading ? 'Generating...' : 'Get Joke'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : _generateRandomJoke,
                            icon: const Icon(Icons.shuffle),
                            label: const Text('Random'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              onPressed: _isLoading ? null : _generateRandomJoke,
              tooltip: 'Random Joke',
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.shuffle, color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (_jokeHistory.isNotEmpty)
              FloatingActionButton(
                onPressed: _isLoading ? null : () => _showHistory(context),
                tooltip: 'Joke History',
                backgroundColor: Theme.of(context).colorScheme.secondary,
                mini: true,
                child: const Icon(Icons.history, color: Colors.white),
              ),
            const SizedBox(height: 8),
            if (_favoriteJokes.isNotEmpty)
              FloatingActionButton(
                onPressed: _isLoading ? null : () => _showFavorites(context),
                tooltip: 'Favorite Jokes',
                backgroundColor: Colors.pink,
                mini: true,
                child: const Icon(Icons.favorite, color: Colors.white),
              ),
          ],
        ),

    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}