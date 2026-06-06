# SOS Screen (Flutter)

## Overview

This document captures the SOS screen design and implementation details for the Flutter mobile app.

## File Location

- Screen: `mobile_flutter/lib/pages/sos_page.dart`

## Goal

Build a visually strong emergency page that mirrors the React SOS screen style, while following Android-friendly Flutter UI patterns.

## Implemented UI

- Full-screen dark background with gradient styling.
- Subtle top-right radial glow, matching the visual language used in chat screen.
- Centered content layout with constrained max width for readability.
- Title: `Emergency SOS`.
- Subtitle explaining emergency use.
- Large circular red SOS hero button (UI-only for now).
- Emergency contact cards with icon + text rows.

## Visual Design Choices

- Base background color: `#050510`.
- Surface card color: dark translucent (`#141420` variant).
- Border color: `#2A2A3E`.
- Red accents for emergency affordance.
- Spacing/padding tuned for mobile screens.
- Scrollable container to prevent overflow on short-height devices.

## Functional Behavior (Current)

- No SOS trigger logic yet (intentionally not implemented).
- One interaction is implemented:
  - Tapping the phone icon on `Ambulance: 102` opens device dialer with `102` prefilled.
  - It does not auto-call.

## Dialer Integration

- Package used: `url_launcher`.
- Method: launch `tel:102` with external application mode.
- Purpose: user confirmation before placing an emergency call.

## Why This Is Safe

- Keeps user in control.
- Avoids accidental immediate emergency calls.
- Matches Android expected behavior for emergency shortcuts.

## Next Possible Enhancements

- Add press animation on SOS button.
- Add emergency contacts from user profile.
- Add confirmation sheet before dialer launch.
- Add localization for region-specific emergency numbers.
- Add accessibility labels for emergency controls.
