Here’s a clean, plain-English **Requirements Document** for your **FITDJ** iOS app idea. It’s structured exactly as you asked—numbered, simple, and easy to follow.

---

# FITDJ iOS App – Requirements Document

## 1. App Overview

FITDJ is a workout app for iPhone. It gives people a personal trainer who talks to them during exercise while music plays in the background. The trainer voice comes from AI and tells you what to do for the specific exercise, when to rest, and gives encouragement. Music comes from Spotify and changes to match the workout’s speed. The app is for beginners and intermediate users who want fun, guided workouts with music at home or in the gym.

---

## 2. Main Goals

1. Help users follow guided workouts with clear steps.
2. Play Spotify music that matches the workout energy.
3. Use a trainer voice that talks over the music.
4. Keep track of workouts, progress, and streaks.
5. Offer simple subscription for premium access.

---

## 3. User Stories

* **US-001**: As a user, I want to sign up quickly so that I can start working out fast.
* **US-002**: As a user, I want to connect my Spotify account so that I can play my music.
* **US-003**: As a user, I want to pick a workout routine so that I know exactly what to do.
* **US-004**: As a user, I want to hear a trainer voice so that I stay motivated and know what to do.
* **US-005**: As a user, I want the music to lower in volume when the trainer speaks so that I can hear instructions clearly.
* **US-006**: As a user, I want to change the workout intensity mid-session so that I can make it easier or harder.
* **US-007**: As a user, I want to see videos of exercises so that I know the correct form.
* **US-008**: As a user, I want reminders and progress tracking so that I keep working out regularly.
* **US-009**: As a user, I want to try the app free for 7 days so that I can decide if I want to pay.

---

## 4. Features

* **F-001: Sign In and Onboarding**
  What: Sign in with Apple. Pick goals, equipment, and music preference.
  When: First time user opens app.
  If error: Show retry option.

* **F-002: Spotify Connect**
  What: Connect Spotify Premium. Show “Powered by Spotify.”
  When: During onboarding or in settings.
  If error: Play workout without music.

* **F-003: Workout Library**
  What: List of 8–10 pre-made workouts with length, difficulty, and equipment.
  When: After onboarding.
  If error: Show message “Workouts unavailable, try again later.”

* **F-004: Workout Player**
  What: Play workout with timers, exercise videos, trainer voice, and Spotify music.
  When: User taps “Start Workout.”
  If error: If music fails, keep trainer voice and timers running.

* **F-005: Trainer Voice**
  What: AI voice gives instructions, countdowns, and motivation.
  When: During workout.
  If error: If voice fails, show text captions.

* **F-006: Music Ducking**
  What: Music volume lowers when trainer speaks.
  When: Every cue.
  If error: Leave music playing at normal level.

* **F-007: Intensity Control**
  What: Buttons for “Easier” and “Harder.” Adjusts workout length and music energy.
  When: During workout.
  If error: Ignore tap and keep workout as-is.

* **F-008: Progress Tracking**
  What: Save completed workouts, streaks, and reminders.
  When: After workout ends.
  If error: Workout completes but progress may not save.

* **F-009: Subscription Paywall**
  What: 7-day free trial, then \$14.99/month or \$99/year.
  When: Before starting workouts (after trial).
  If error: Show message “Payment failed, try again.”

---

## 5. Screens

* **S-001: Splash / Sign In Screen**
  Shows app logo, “Sign in with Apple.” Leads to S-002.

* **S-002: Onboarding**
  Choose goals, equipment, music preference. Leads to S-003.

* **S-003: Spotify Connect**
  Connect Spotify Premium. If skipped, still allows workouts. Leads to S-004.

* **S-004: Home / Workout Library**
  List of workouts with titles, times, and levels. Tap → S-005.

* **S-005: Workout Detail**
  Shows workout plan, equipment, and preview video loops. Tap “Start Workout” → S-006.

* **S-006: Workout Player**
  Timer, exercise video loop, trainer voice cues, music controls, “Easier/Harder” buttons. On completion → S-007.

* **S-007: Workout Complete**
  Shows stats, streaks, and share button. Leads back to S-004.

* **S-008: Paywall**
  Shows free trial and subscription options. Appears before workouts if trial ended.

* **S-009: Settings**
  Change Spotify, manage subscription, view progress.

---

## 6. Data

* **D-001**: List of workouts with title, duration, equipment, difficulty.
* **D-002**: List of exercises with name, video, and tags.
* **D-003**: Voice cues (e.g., “10 seconds left”).
* **D-004**: User profile with goals, equipment, and preferences.
* **D-005**: Workout history with date, time, and completion.
* **D-006**: Subscription status and trial dates.

---

## 7. Extra Details

* Needs internet for Spotify and voice AI.
* Works offline for timers and pre-saved cues.
* Stores workout history and preferences on device + cloud.
* Needs microphone/audio permission for playback.
* Always in dark mode for workouts.
* Sends push notifications for reminders.

---

## 8. Build Steps

* **B-001**: Build S-001 and F-001 (Sign In). Save user profile (D-004).
* **B-002**: Add S-002 (Onboarding). Store choices in D-004.
* **B-003**: Add S-003 and F-002 (Spotify connect). Handle fallback if error.
* **B-004**: Build S-004 (Workout Library) with F-003. Load workouts from D-001.
* **B-005**: Build S-005 (Workout Detail). Show data from D-001 and D-002.
* **B-006**: Build S-006 (Workout Player) with F-004, F-005, F-006, F-007. Use voice cues (D-003).
* **B-007**: Add S-007 (Workout Complete) and F-008 (Progress Tracking). Save D-005.
* **B-008**: Build S-008 (Paywall) with F-009. Track D-006.
* **B-009**: Add S-009 (Settings). Manage Spotify, subscription, progress.
* **B-010**: Add push reminders, streaks, and extra polish.

## Environment Variables

SPOTIFY_CLIENT_ID=e565d85fc0e04aba9093b17589b5e1e3
SPOTIFY_CLIENT_SECRET=181ab31b7ee84e63a8fde0f27ec44a5b
SPOTIFY_REDIRECT_URI=fitdj://spotify-auth-callback
ELEVENLABS_API_KEY=sk_8897ac346a30c272330d29230fd2c327918acc4870da52e8

ELEVENLABS_VOICE_ID=egTToTzW6GojvddLj0zd

## Backup Environment Variables

ELEVENLABS_API_KEY=sk_af34df5101d4e23cf1b8137164cf638a7a5b643674d0eedd

ELEVENLABS_VOICE_ID=egTToTzW6GojvddLj0zd
---