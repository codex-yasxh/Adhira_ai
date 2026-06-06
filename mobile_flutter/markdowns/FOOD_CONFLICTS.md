# Food-Medication Conflicts

## Scope

The food conflict feature checks selected foods against current medicines and reports possible medication-food conflicts.

## Files

| Purpose | File |
| --- | --- |
| Flutter screen | `mobile_flutter/lib/pages/food_conflict_page.dart` |
| Medicine navigation source | `mobile_flutter/lib/pages/medicines_page.dart` |
| Backend endpoint | `backend/main.py` (`/food/conflicts`) |
| Backend table SQL | `backend/food_conflicts_schema.sql` |

## Current Flutter Behavior

The current Flutter screen performs conflict detection locally.

Flow:

1. `MedicinesPage` passes medicine names into `FoodConflictPage`.
2. User selects food chips grouped by category.
3. User taps `Detect Conflicts`.
4. Flutter compares selected foods against local maps:
   - `_foodCategories`
   - `_medicationConflicts`
   - `_medicationMap`
5. Results are displayed immediately.

## Current Local Rules

Medication mappings include:

- Paracetamol
- Ibuprofen
- Aspirin maps to Ibuprofen
- Amoxicillin
- Azithromycin maps to Amoxicillin
- Metformin
- Glucophage maps to Metformin

Food categories include citrus, caffeine, dairy, alcohol, leafy greens, high fat, high sugar, spicy, and high sodium.

## Backend Capability

The FastAPI backend also has:

- `POST /food/conflicts`
- `GET /food/conflicts/history`

The backend computes conflicts in memory and optionally persists checks to Supabase `food_conflicts`.

## Important Mismatch

Flutter currently does not call the backend food conflict endpoint. That means:

- No conflict history is saved from the mobile UI.
- Backend and Flutter rule maps can drift over time.
- Any future improvement must be made in both places unless the app switches to backend detection.

## Current Limits

- Medicine list is in-memory, so conflict checks only use the current runtime list.
- Conflict rules are simple static heuristics.
- The feature is not a medical authority and should remain framed as "potential conflicts."
- There is no history UI.

## Suggested Next Steps

- Switch Flutter conflict detection to `POST /food/conflicts`.
- Keep a lightweight local fallback if backend is unavailable.
- Add conflict history screen using `GET /food/conflicts/history`.
- Move food and medication rules into one shared backend source.
- Add disclaimers and encourage clinician/pharmacist confirmation for serious medication decisions.

