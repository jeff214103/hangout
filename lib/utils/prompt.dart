const PROMPT_REQUIREMENTS = """
Requirements of the suggestion
1. Be clear and easy to follow
2. Be specific and detailed for map and activity
3. Never suggest places like non-public areas (i.e. home, company, etc.)
4. Depends on the preference, you may suggest that might not surround with the given area
5. The current location is just the starting point, you should suggest a trip from the starting point to another location
6. Assume the trip could end anywhere, so it is not necessary to include the end location

Strictly return in the following JSON format:
[
    {
      "name": <String>,
      "description": <String>,
      "activityType": <String>,
      "location": {
        "name": <String>,
        "address": <String>,
      },
      "startDateTime": <String>, // ISO 8601 format for precise time (e.g., 'YYYY-MM-DDTHH:mm:ss')
      "durationMinutes": <int>, // Duration of the activity itself in minutes
      "estimatedEndTime": <string>, // Calculated end time of activity
      "tips":  <String>,
      "transitToNext": { // Details for travel to the *next* activity (Lunch)
        "durationMinutes": <int>,
        "mode": <String>, // e.g., 'Walk', 'Public Transit', 'Car', 'Bike'
        "details": <String>
   },
....
]""";
