import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hangout/screen/chat.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class QueryForm extends StatefulWidget {
  const QueryForm({super.key});

  @override
  State<QueryForm> createState() => _QueryFormState();
}

class _QueryFormState extends State<QueryForm> {
  final _formKey = GlobalKey<FormState>();
  bool _showAdvancedOptions = false;

  // Form controllers
  final _locationController =
      TextEditingController(text: 'Vancouver, British Columbia, Canada');
  final _peopleController = TextEditingController(text: '1');
  TimeOfDay _fromTime = TimeOfDay.now();
  TimeOfDay _toTime =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));

  // Advanced options
  String _activityType = 'No Preference';
  String _environment = 'No Preference';
  String _cost = 'No Preference';
  String _pace = 'No Preference';
  String _transitPreference = 'No Preference';
  final List<String> _ambience = [];
  String _weather = 'No Preference';
  String _energyLevel = 'No Preference';
  String _accessibility = 'No Preference';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      // Here you would typically reverse geocode the position to get the address
      // For now, we'll just use the coordinates
      setState(() {
        _locationController.text =
            '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      // Handle error or keep default location
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Basic Fields
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Current Location',
              icon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _peopleController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of People',
              icon: Icon(Icons.people),
            ),
            validator: (value) {
              if (value == null ||
                  int.tryParse(value) == null ||
                  int.parse(value) < 1) {
                return 'Please enter a valid number (minimum 1)';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Time Selection
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text('From'),
                  subtitle: Text(_fromTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _fromTime,
                    );
                    if (picked != null) {
                      setState(() => _fromTime = picked);
                    }
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text('To'),
                  subtitle: Text(_toTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _toTime,
                    );
                    if (picked != null) {
                      setState(() => _toTime = picked);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Advanced Options Toggle
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showAdvancedOptions = !_showAdvancedOptions;
              });
            },
            icon: Icon(
                _showAdvancedOptions ? Icons.expand_less : Icons.expand_more),
            label: Text(_showAdvancedOptions
                ? 'Hide Advanced Options'
                : 'Show Advanced Options'),
          ),

          if (_showAdvancedOptions) ...[
            _buildAdvancedOptions(),
          ],

          const SizedBox(height: 24),

          // Submit Button
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                FirebaseAnalytics.instance
            .logEvent(name: 'receipt_gemini_request', parameters: {
          'status': "empty",
        });
                final prompt = _generatePrompt();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      initialPrompt: prompt,
                    ),
                  ),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Generate Suggestions'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      children: [
        _buildDropdown('Activity Type', _activityType,
            ['Chill', 'Intense', 'Balanced Mix']),
        _buildDropdown('Environment', _environment, ['Indoor', 'Outdoor']),
        _buildDropdown(
            'Cost', _cost, ['Free', 'Low Cost', 'Moderate', 'High End']),
        _buildDropdown('Pace', _pace, [
          'Few, Longer Activities',
          'Many, Shorter Activities',
          'Balanced Mix'
        ]),
        _buildDropdown('Transit Preference', _transitPreference, [
          'Walkable Only',
          'Minimal Transition Time',
          'Ample Transition Time'
        ]),
        _buildMultiSelect('Ambience', _ambience, [
          'Local Vibe',
          'Tourist Hotspots',
          'Quiet/Calm',
          'Lively/Energetic',
          'Family-Friendly',
          'Romantic',
          'Educational',
          'Historical',
          'Modern/Contemporary'
        ]),
        _buildDropdown(
            'Weather', _weather, ['Raining', 'Hot', 'Cold', 'Shine']),
        _buildDropdown('Energy Level', _energyLevel,
            ['Feeling Low Energy', 'Normal Energy', 'High Energy/Adventurous']),
        _buildDropdown('Accessibility', _accessibility, [
          'Easy Access',
          'Requires Minimal Walking',
          'Driving/Parking Friendly'
        ]),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: (["No Preference"] + options).map((String option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              switch (label) {
                case 'Activity Type':
                  _activityType = newValue;
                  break;
                case 'Environment':
                  _environment = newValue;
                  break;
                case 'Cost':
                  _cost = newValue;
                  break;
                case 'Pace':
                  _pace = newValue;
                  break;
                case 'Transit Preference':
                  _transitPreference = newValue;
                  break;
                case 'Weather':
                  _weather = newValue;
                  break;
                case 'Energy Level':
                  _energyLevel = newValue;
                  break;
                case 'Accessibility':
                  _accessibility = newValue;
                  break;
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildMultiSelect(
      String label, List<String> selected, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Wrap(
            spacing: 8.0,
            children: options.map((String option) {
              return FilterChip(
                label: Text(option),
                selected: selected.contains(option),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _ambience.add(option);
                    } else {
                      _ambience.remove(option);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _generatePrompt() {
    final duration = _calculateDuration();
    final ambienceStr =
        _ambience.isEmpty ? 'No specific preference' : _ambience.join(', ');

    return '''
Please suggest a schedule for ${_peopleController.text} people in ${_locationController.text} with the following preferences:

Time: ${_fromTime.format(context)} to ${_toTime.format(context)} ($duration)
Activity Type: $_activityType
Environment: $_environment
Cost Level: $_cost
Pace: $_pace
Transit Preference: $_transitPreference
Ambience: $ambienceStr
Current Weather: $_weather
Energy Level: $_energyLevel
Accessibility: $_accessibility

Please provide a detailed schedule that includes:
1. Specific locations or activities
2. Estimated time for each activity
3. Travel time between locations
4. Brief description of each suggested place
5. Any relevant tips or considerations based on the weather and preferences

Format the response in a clear, easy-to-follow structure.
''';
  }

  String _calculateDuration() {
    final fromMinutes = _fromTime.hour * 60 + _fromTime.minute;
    final toMinutes = _toTime.hour * 60 + _toTime.minute;

    // Handle case where end time is on the next day
    final durationMinutes = toMinutes < fromMinutes
        ? (24 * 60 - fromMinutes) +
            toMinutes // Time until midnight + time from midnight
        : toMinutes - fromMinutes;

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '$hours hours $minutes minutes' : '$hours hours';
    } else {
      return '$minutes minutes';
    }
  }
}
