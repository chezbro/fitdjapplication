# ExerciseDB Integration

This document explains how to use the ExerciseDB integration in the FITDJ Application.

## Overview

The ExerciseDB integration provides access to over 5,000 exercises from the [ExerciseDB API](https://github.com/ExerciseDB/exercisedb-api). The integration includes:

- **ExerciseDBService**: Fetches and caches exercises from the API
- **ExerciseDBWorkoutBuilder**: Creates workouts using ExerciseDB exercises
- **ExerciseDBManagerView**: UI for managing the integration
- **WorkoutDataService Integration**: Combines ExerciseDB workouts with existing workouts

## Setup

### 1. Fetch Exercises

1. Open the app and navigate to the ExerciseDB Manager
2. Tap "Fetch Exercises" to download and cache exercises
3. The app will fetch all available exercises (up to 5,000)
4. Exercises are cached locally for 30 days

## Features

### Automatic Workout Generation

Once exercises are cached, the app automatically generates:

- **Muscle Group Workouts**: Chest, Back, Shoulders, Arms, Legs, Core
- **Equipment Workouts**: Bodyweight, Dumbbells, Kettlebells, Resistance Bands, Yoga Mat
- **Difficulty Workouts**: Beginner, Intermediate, Advanced
- **Specialized Workouts**: HIIT, Strength Training, Cardio, Flexibility

### Custom Workout Creation

You can create custom workouts using ExerciseDB exercises:

```swift
let customWorkout = workoutDataService.createCustomWorkout(
    name: "My Custom Workout",
    description: "A personalized workout",
    duration: 45,
    difficulty: .intermediate,
    targetMuscleGroups: [.chest, .arms],
    equipment: [.dumbbells]
)
```

### Exercise Search

Search through the ExerciseDB exercises:

```swift
let chestExercises = workoutDataService.searchExercises(query: "chest")
let dumbbellExercises = workoutDataService.getExercisesForEquipment("dumbbell")
```

## Caching Strategy

The integration uses a smart caching strategy to minimize API usage:

- **Initial Fetch**: Downloads all exercises (1-2 API requests)
- **Local Cache**: Stores exercises locally for 30 days
- **Automatic Refresh**: Refreshes cache every 30 days
- **Manual Refresh**: Users can manually refresh the cache

## API Usage

The ExerciseDB API is free and open with no rate limits for basic usage:

- **Initial setup**: ~2 requests (to fetch all exercises)
- **Monthly refresh**: ~2 requests
- **Total monthly usage**: ~4 requests

## Data Mapping

The integration maps ExerciseDB data to the app's data models:

### Equipment Mapping
- `body weight` → `.none`
- `dumbbell` → `.dumbbells`
- `barbell` → `.barbell`
- `kettlebell` → `.kettlebells`
- `resistance band` → `.resistanceBands`
- `yoga mat` → `.yogaMat`

### Muscle Group Mapping
- `chest` → `.chest`
- `back` → `.back`
- `shoulders` → `.shoulders`
- `arms/biceps/triceps` → `.arms`
- `legs/quadriceps/hamstrings/calves` → `.legs`
- `core/abs/abdominals` → `.core`

### Exercise Duration
- `weight_reps` → 60 seconds
- `cardio` → 45 seconds
- `stretching` → 90 seconds
- `bodyweight` → 45 seconds

## Error Handling

The integration includes comprehensive error handling:

- **Network errors**: Graceful fallback to cached data
- **API key errors**: Clear error messages
- **Rate limiting**: Automatic retry with exponential backoff
- **Invalid responses**: Fallback to default values

## Security Considerations

- No API keys required - the service is completely open
- All API requests use HTTPS
- No sensitive user data is sent to ExerciseDB
- All data is cached locally for offline use

## Troubleshooting

### Common Issues

1. **"No cached exercises"**: Run the initial fetch
2. **"Network error"**: Check internet connection
3. **"API unavailable"**: The ExerciseDB service may be temporarily down

### Debug Information

Check the cache status in the ExerciseDB Manager:
- Number of cached exercises
- Last fetch date
- Error messages

## Future Enhancements

Potential improvements for the integration:

1. **Offline Mode**: Full offline functionality with cached exercises
2. **Smart Caching**: Only fetch updated exercises
3. **User Preferences**: Customize exercise selection based on user preferences
4. **Analytics**: Track which exercises are most popular
5. **Social Features**: Share custom workouts with other users

## Support

For issues with the ExerciseDB integration:

1. Check the ExerciseDB Manager for error messages
2. Ensure you have an active internet connection
3. Try refreshing the exercise cache
4. Check the ExerciseDB API status

For ExerciseDB API issues, visit their [GitHub repository](https://github.com/ExerciseDB/exercisedb-api).
