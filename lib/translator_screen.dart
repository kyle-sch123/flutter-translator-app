import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:html' if (dart.library.html) 'dart:html';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({Key? key}) : super(key: key);

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> {
  final TextEditingController _textController = TextEditingController();
  String _translatedText = '';
  String _selectedLanguage = 'en'; // Default to French
  bool _isLoading = false;
  bool _isLoadingAudio = false;
  String? _errorMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // For audio handling
  String? _audioUrl;
  bool _isPlaying = false;

  // Voice parameter controls
  double _pitchValue = 0.0; // Range from -20.0 to 20.0, default 0.0
  double _speakingRateValue = 1.0; // Range from 0.25 to 4.0, default 1.0

  // Language options
  final Map<String, String> _languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'ja': 'Japanese',
    'zh-CN': 'Chinese (Simplified)',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'ko': 'Korean',
  };

  // Map languages to Text-to-Speech language codes
  final Map<String, String> _ttsLanguageCodes = {
    'en': 'en-GB',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'ja': 'ja-JP',
    'zh-CN': 'cmn-CN',
    'ru': 'ru-RU',
    'pt': 'pt-PT',
    'ar': 'ar-XA',
    'hi': 'hi-IN',
    'ko': 'ko-KR',
  };

  // Voice name - using en-GB-Standard-B for all languages as specified
  final String _voiceName = 'en-GB-Standard-B';

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _translateText() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _audioUrl = null;
      _translatedText = '';
    });

    final text = _textController.text;

    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter text to translate';
        _isLoading = false;
      });
      return;
    }

    // If English is selected, simply use the input text as the translation
    if (_selectedLanguage == 'en') {
      setState(() {
        _translatedText = text;
        _isLoading = false;
      });

      // Generate audio for the text
      await _generateAudio();
      return;
    }

    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'];
      final url = Uri.parse(
          'https://translation.googleapis.com/language/translate/v2?key=AIzaSyAwYAXfeM7tzsGiu95aXemmNBjlIT2IkuI');

      final response = await http.post(
        url,
        body: jsonEncode({
          'q': text,
          'target': _selectedLanguage,
          'source': 'en',
          'format': 'text'
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Translation error: ${data['error']['message']}';
          _isLoading = false;
        });
        return;
      }

      final translatedText = data['data']['translations'][0]['translatedText'];

      setState(() {
        _translatedText = _decodeHtmlEntities(translatedText);
        _isLoading = false;
      });

      // Generate audio for the translated text
      await _generateAudio();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Helper method to decode HTML entities in translated text
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');
  }

  Future<void> _generateAudio() async {
    if (_translatedText.isEmpty) return;

    setState(() {
      _isLoadingAudio = true;
      _audioUrl = null;
    });

    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? 'AIzaSyAwYAXfeM7tzsGiu95aXemmNBjlIT2IkuI';
      final url = Uri.parse(
          'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey');

      // Get language code for the selected language
      final ttsLanguageCode = _ttsLanguageCodes[_selectedLanguage] ?? 'en-GB';

      final response = await http.post(
        url,
        body: jsonEncode({
          'input': {'text': _translatedText},
          'voice': {
            'languageCode': ttsLanguageCode,
            'name': _voiceName, // English (UK) Standard male voice for all languages
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'pitch': _pitchValue,           // Add pitch parameter
            'speakingRate': _speakingRateValue  // Add speaking rate parameter
          },
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        setState(() {
          _errorMessage = 'Audio generation error: ${data['error']['message']}';
          _isLoadingAudio = false;
        });
        return;
      }

      final audioContent = data['audioContent'];

      // For web, we create a data URL
      final audioDataUrl = 'data:audio/mp3;base64,$audioContent';

      setState(() {
        _audioUrl = audioDataUrl;
        _isLoadingAudio = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Audio generation error: $e';
        _isLoadingAudio = false;
      });
    }
  }

  // Toggle play/pause
  Future<void> _togglePlayPause() async {
    if (_audioUrl == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(UrlSource(_audioUrl!));
        setState(() {
          _isPlaying = true;
        });

        // Add listener to update state when audio completes
        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Audio playback error: $e';
      });
    }
  }

  // Download audio in web
  void _downloadAudio() {
    if (_audioUrl == null) return;

    final anchor = AnchorElement(href: _audioUrl)
      ..setAttribute('download', 'translation.mp3')
      ..click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Translator'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Web app status indicator
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.web,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Web App Ready',
                          style: TextStyle(
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Language selection
                  const Text(
                    'Select Target Language',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _languages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedLanguage = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Voice controls section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Voice Controls',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Pitch Slider
                        Text('Pitch: ${_pitchValue.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Slider(
                          value: _pitchValue,
                          min: -10.0,
                          max: 10.0,
                          divisions: 40,
                          label: _pitchValue.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() {
                              _pitchValue = value;
                            });
                          },
                        ),
                        const Text(
                          'Lower values produce deeper voices, higher values produce higher-pitched voices',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        // Speaking Rate Slider
                        Text('Speaking Rate: ${_speakingRateValue.toStringAsFixed(2)}x',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Slider(
                          value: _speakingRateValue,
                          min: 0.25,
                          max: 4.0,
                          divisions: 75,
                          label: '${_speakingRateValue.toStringAsFixed(2)}x',
                          onChanged: (value) {
                            setState(() {
                              _speakingRateValue = value;
                            });
                          },
                        ),
                        const Text(
                          'Controls how quickly the text is spoken (1.0 is normal speed)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Input text
                  Text(
                    _selectedLanguage == 'en' ? 'Text to Speak' : 'English Text',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _selectedLanguage == 'en'
                          ? 'Enter text to convert to speech'
                          : 'Enter text to translate',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),

                  // Translate button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _translateText,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(_selectedLanguage == 'en'
                        ? 'Generate Audio'
                        : 'Translate and Generate Audio'),
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),

                  // Translated text
                  if (_translatedText.isNotEmpty && _selectedLanguage != 'en') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Translation',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _translatedText,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _translatedText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Text copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Translation'),
                    ),
                  ],

                  // Audio controls
                  if (_isLoadingAudio)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_audioUrl != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Audio Player',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _togglePlayPause,
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                label: Text(_isPlaying ? 'Pause' : 'Play'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _downloadAudio,
                                icon: const Icon(Icons.download),
                                label: const Text('Download MP3'),
                              ),
                            ],
                          ),
                          if (_audioUrl != null) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Tip: Change voice settings and generate audio again to hear differences',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}