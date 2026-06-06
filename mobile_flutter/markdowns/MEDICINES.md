# Medicines

## Scope

The medicines screen lets users view, add, and delete medicines. It also passes medicine names into chat context and the food conflict checker.

## Files

| Purpose | File |
| --- | --- |
| Medicines screen | `mobile_flutter/lib/pages/medicines_page.dart` |
| Shared medicine names | `mobile_flutter/lib/core/medicine_store.dart` |
| Food conflict navigation | `mobile_flutter/lib/pages/food_conflict_page.dart` |
| Chat context usage | `mobile_flutter/lib/pages/chat_page.dart` |

## Current Behavior

- The screen starts with a hardcoded medicine list:
  - Paracetamol
  - Vitamin D
  - Aspirin
  - Metformin
  - Amoxicillin
- Users can add a medicine through a modal bottom sheet.
- Users can delete a medicine from the visible list.
- The list is compact by default and can expand with `View More`.
- A CTA opens the food-medication conflict screen.

## Data Model

The screen uses a local private `_Medicine` model with:

- `id`
- `name`
- `dosage`
- `frequency`
- `time`

This model is currently UI-local only.

## Shared Store

`MedicineStore.instance.names` is synchronized from the current list.

This shared list is used by:

- `ChatPage`, which sends `medicineNames` to `/health/assistant`.
- `FoodConflictPage`, which receives medicine names through navigation.

## Current Limits

- Medicines are not persisted in Supabase.
- Medicines reset to the hardcoded defaults after app restart.
- Add/delete actions affect only local runtime state.
- There is no edit medicine flow.
- Reminder creation is separate; medicine rows do not directly create reminder rows.

## Suggested Next Steps

- Add a Supabase `medicines` table and load medicines by `user_id`.
- Replace hardcoded defaults with empty or seeded user-specific data.
- Add edit support for dosage, frequency, and time.
- Connect medicine rows to reminder creation.
- Keep `MedicineStore` as a cached view of persisted medicines, or replace it with a repository/service.

