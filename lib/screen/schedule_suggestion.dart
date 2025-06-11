import 'package:flutter/foundation.dart';
import 'package:hangout/utils/prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:hangout/providers/setting_provider.dart';
import 'package:provider/provider.dart';
import 'package:hangout/widget/loading_hint.dart';
import 'package:hangout/widget/dialog.dart';
import 'package:hangout/widget/gemini.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class ResultPage extends StatefulWidget {
  final String initialPrompt;
  final LatLng? selectedLocation;

  const ResultPage({
    super.key,
    required this.initialPrompt,
    this.selectedLocation,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  Future<List<Map<String, dynamic>>>? _chatResult;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
        model: Provider.of<SettingProvider>(context, listen: false).geminiModel,
        apiKey:
            Provider.of<SettingProvider>(context, listen: false).geminiAPIKey,
        generationConfig: GenerationConfig(
          responseMimeType: "application/json",
        ));
    _chat = _model.startChat();

    _chatResult = _sendPrompt(widget.initialPrompt);
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _regenerateWithFeedback() async {
    String? feedback = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('Regenerate Suggestions')),
            if (Provider.of<SettingProvider>(context, listen: false).debugMode)
              IconButton(
                tooltip: 'Show Raw Chat',
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => GeminiChatRoomDialog(
                      chat: _chat,
                    ),
                  );
                },
                icon: Icon(Icons.warning),
              ),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "Not Satisfied? Please provide some feedback and regenerate for you:",
                  style: Theme.of(context).textTheme.labelLarge),
              TextField(
                controller: _feedbackController,
                decoration: const InputDecoration(
                  hintText: 'Feedback here',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _feedbackController.text),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (feedback != null) {
      if (feedback.isEmpty) {
        feedback = 'Suggest another schedule';
      }
      setState(() {
        _chatResult = _sendPrompt(
            '''The user provided the following feedback of the result suggested: 
"""
$feedback
"""
$PROMPT_REQUIREMENTS
''');
      });
      _feedbackController.clear();
    }
  }

  Future<List<Map<String, dynamic>>> _sendPrompt(String prompt) {
    return _chat.sendMessage(Content.text(prompt)).then((response) {
      final List<dynamic> jsonList = jsonDecode(response.text??"[]");
      return jsonList.map((item) => Map<String, dynamic>.from(item)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _chatResult,
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) =>
          Scaffold(
        appBar: AppBar(
          title: const Text('Suggestions'),
          actions: [
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data!.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _regenerateWithFeedback,
                tooltip: 'Regenerate suggestions',
              ),
          ],
        ),
        body: Builder(
          builder: (context) {
            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            } else if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.data == null || snapshot.data!.isEmpty) {
                return const Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: Text('No suggestions found.')),
                    ),
                  ],
                );
              }
              return ScheduleSuggestion(
                  activities: snapshot.data!, center: widget.selectedLocation);
            } else {
              return const Center(
                child: LoadingHint(
                  text: 'Generating your hangout...',
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class ScheduleSuggestion extends StatefulWidget {
  final List<Map<String, dynamic>> activities;
  final LatLng? center;

  const ScheduleSuggestion({
    super.key,
    required this.activities,
    this.center,
  });

  @override
  State<ScheduleSuggestion> createState() => _ScheduleSuggestionState();
}

class _ScheduleSuggestionState extends State<ScheduleSuggestion> {
  final MapController _mapController = MapController(); // Add this
  bool _showSideBySide = false;
  Map<String, Color> _activityTypeColors = {};
  final List<Marker> _markers = [];
  final List<String> _failMarker = [];
  bool _isLoading = true;
  double? _avgLat;
  double? _avgLng;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    _activityTypeColors = _generateActivityTypeColors();
    await _updateActivitiesLatLng();
    _generateMarkers();
    setState(() => _isLoading = false);
  }

  Map<String, Color> _generateActivityTypeColors() {
    final colors = <String, Color>{};
    final types =
        widget.activities.map((a) => a['activityType'] as String).toSet();
    final colorList = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    for (var i = 0; i < types.length; i++) {
      colors[types.elementAt(i)] = colorList[i % colorList.length];
    }
    return colors;
  }

  Future<void> _updateActivitiesLatLng() async {
    _avgLat = widget.center?.latitude;
    _avgLng = widget.center?.longitude;

    int successCount = (_avgLat != null && _avgLng != null) ? 1 : 0;
    _failMarker.clear();

    // Add async here
    final futures = widget.activities.asMap().entries.map((entry) async {
      final index = entry.key;
      final activity = entry.value;
      final location = activity['location'] as Map<String, dynamic>;
      final address = location['address'] as String;

      try {
        final latLng = await _getCoordinatesFromAddress(address);
        if (latLng != null) {
          // Update the location map with lat and lng
          location['lat'] = latLng.latitude;
          location['lng'] = latLng.longitude;

          _avgLat = (_avgLat ?? 0) + latLng.latitude;
          _avgLng = (_avgLng ?? 0) + latLng.longitude;
          successCount++;
        } else {
          throw Exception(
              'Failed to get coordinates for $index location from address: $address');
        }
      } catch (e) {
        _failMarker
            .add('Error getting coordinates for location $index\nDetails:\n$e');
        if (kDebugMode) {
          print('Error $index geocoding address: $address\nerror: $e');
        }
      }
    });

    // Wait for all futures to complete
    await Future.wait(futures);
    _avgLat = _avgLat != null ? _avgLat! / successCount : 0;
    _avgLng = _avgLng != null ? _avgLng! / successCount : 0;
  }

  void _generateMarkers() {
    _markers.clear(); // Clear existing markers

    for (var i = 0; i < widget.activities.length; i++) {
      final activity = widget.activities[i];
      final location = activity['location'] as Map<String, dynamic>;

      // Check if lat and lng exist and are valid numbers
      if (location['lat'] != null && location['lng'] != null) {
        try {
          final lat = location['lat'] is double
              ? location['lat']
              : double.parse(location['lat'].toString());
          final lng = location['lng'] is double
              ? location['lng']
              : double.parse(location['lng'].toString());

          final latLng = LatLng(lat, lng);
          _markers.add(
            Marker(
              point: latLng,
              width: 40,
              height: 40,
              child: _buildMarker(i, activity),
            ),
          );
        } catch (e) {
          print('Error creating marker for activity $i: $e');
        }
      }
    }
  }

  Future<LatLng?> _getCoordinatesFromAddress(String address) async {
    final url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(address)}&format=json';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Hangout/1.0',
          'Referer': 'https://hangout.itdogtics.com/',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        if (results.isNotEmpty) {
          final result = results.first;
          return LatLng(
            double.parse(result['lat']),
            double.parse(result['lon']),
          );
        } else {
          throw Exception('No results found for address: $address');
        }
      } else {
        throw Exception('Failed to fetch coordinates (Code ${response.statusCode}) for address: $address');
      }
    } catch (e) {
      throw Exception('Error fetching coordinates: $e');
    }
  }

  Widget _buildMarker(int index, Map<String, dynamic> activity) {
    Color? color = _activityTypeColors[activity['activityType']];
    return GestureDetector(
      onTap: () => _showActivityDetails(context, index, color, activity),
      child: Container(
        decoration: BoxDecoration(
          color: _activityTypeColors[activity['activityType']],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityDetails(BuildContext context, int index, Color? color,
      Map<String, dynamic> activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: ActivityCard(
            activity: activity,
            index: index,
            color: color,
            onLocate: (latLng) {
              Navigator.pop(context); // Close the bottom sheet
              _mapController.move(latLng, 15.0); // Zoom to the location
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingHint(text: "Preparing your hangout...");
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 800;

        // Set default side-by-side state based on screen size
        if (isLargeScreen && !_showSideBySide) {
          _showSideBySide = true;
        } else if (!isLargeScreen && _showSideBySide) {
          _showSideBySide = false;
        }

        return StatefulBuilder(
          builder: (context, setState) => Stack(
            children: [
              // Main content (Map or List)
              _buildMapView(),
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _showSideBySide = true),
                    label: const Text('Details'),
                    icon: const Icon(Icons.list),
                  ),
                ),
              ),
              // Overlay drawer - always present but animated
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                right: _showSideBySide ? 0 : -constraints.maxWidth,
                top: 0,
                bottom: 0,
                width: isLargeScreen
                    ? constraints.maxWidth * 0.4
                    : constraints.maxWidth * 0.8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drawer header with close button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Activities',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() => _showSideBySide = false);
                                }),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                        child: Text(
                          "Schedule generated by AI. Powered by Gemini.  Map data provided by OpenStreetMap.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Divider(),
                      // Activities list
                      Expanded(
                        child: _buildListView(),
                      ),
                    ],
                  ),
                ),
              ),
              if (Provider.of<SettingProvider>(context, listen: false)
                      .debugMode &&
                  _failMarker.isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FloatingActionButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('Location Decoding Errors'),
                                ),
                              ],
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _failMarker
                                    .map((error) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Text(error),
                                        ))
                                    .toList(),
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
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            _failMarker.length.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_avgLat!, _avgLng!),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          tileProvider: CancellableNetworkTileProvider(),
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        MarkerLayer(markers: _markers),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: widget.activities.length,
      itemBuilder: (context, index) {
        return ActivityCard(
          activity: widget.activities[index],
          index: index,
          color: _activityTypeColors[widget.activities[index]['activityType']]!,
          onLocate: (latLng) {
            _mapController.move(latLng, 15.0); // Zoom to the location
          },
        );
      },
    );
  }
}

class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final int index;
  final Color? color;
  final Function(LatLng)? onLocate; // Add this callback

  const ActivityCard({
    super.key,
    required this.activity,
    required this.index,
    this.color,
    this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final location = activity['location'] as Map<String, dynamic>;
    final startTime = DateTime.parse(activity['startDateTime']);
    final duration = activity['durationMinutes'] as int;
    final endTime = startTime.add(Duration(minutes: duration));

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Text('${index + 1}',
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['name'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        activity['activityType'],
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(activity['description']),
            const SizedBox(height: 8),
            _buildInfoRowWithSearch(Icons.location_on, location['name']),
            _buildInfoRow(Icons.access_time,
                '${DateFormat.jm().format(startTime)} - ${DateFormat.jm().format(endTime)}'),
            if (activity['tips'] != null)
              _buildInfoRow(Icons.lightbulb, activity['tips']),
            if (activity['transitToNext'] != null)
              _buildTransitInfo(activity['transitToNext']),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchMaps(location['address']),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 8),
                if (onLocate != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        try {
                          final lat = location['lat'] is double
                              ? location['lat']
                              : double.parse(location['lat'].toString());
                          final lng = location['lng'] is double
                              ? location['lng']
                              : double.parse(location['lng'].toString());
                          final latLng = LatLng(lat, lng);
                          onLocate!(latLng);
                        } catch (e) {
                          showDialog(
                            context: context,
                            builder: (context) => ConfirmationDialogBody(
                              text: 'Unable to locate ${location['name']}',
                              actionButtons: [
                                FilledButton(
                                  onPressed: () {
                                    _launchGoogleSearch(location['name']);
                                  },
                                  child: const Text('Search'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Locate'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRowWithSearch(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: icon == Icons.location_on
                ? InkWell(
                    onTap: () => _launchGoogleSearch(text),
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(text),
          ),
        ],
      ),
    );
  }

  Future<void> _launchGoogleSearch(String query) async {
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildTransitInfo(Map<String, dynamic> transit) {
    return Card(
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Next Transit:'),
            _buildInfoRow(Icons.directions_walk,
                '${transit['mode']} (${transit['durationMinutes']} mins)'),
            if (transit['details'] != null) Text(transit['details']),
          ],
        ),
      ),
    );
  }

  Future<void> _launchMaps(String address) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }
}

class ActivityDetailsCard extends StatelessWidget {
  final int index;
  final Color? color;
  final Map<String, dynamic> activity;

  const ActivityDetailsCard({
    super.key,
    required this.index,
    this.color,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ActivityCard(
          activity: activity,
          index: index,
          color: color,
        );
      },
    );
  }
}
