# Reminders

## Scope

The reminders feature stores user reminders in Supabase and schedules local Android notifications.

## Files

| Purpose | File |
| --- | --- |
| Reminders screen | `mobile_flutter/lib/pages/reminders_page.dart` |
| Notification scheduling | `mobile_flutter/lib/services/notification_service.dart` |
| Notification tap routing | `mobile_flutter/lib/app/app.dart` |
| App initialization | `mobile_flutter/lib/main.dart` |

## Current Behavior

- Reminders load from the Supabase `reminders` table for the current user.
- Users can add, toggle, and delete reminders.
- Enabled reminders are scheduled locally as daily notifications.
- Notification permission and exact alarm permission are requested on Android.
- Tapping a reminder notification moves the bottom navigation shell to the Reminders tab.

## Reminder Fields Used

The Flutter loader supports multiple schema names:

- ID: `id`
- Title: `title` or `name`
- Medicine name: `med_name`, `medicine_name`, or fallback to title
- Dosage: `dosage`, `medicine_dosage`, or `as prescribed`
- Time: `time`, `reminder_time`, or `09:00 AM`
- Enabled: `enabled` or `is_enabled`

This fallback behavior helps with schema drift, but the database should eventually settle on one shape.

## Notification Scheduling

`NotificationService.scheduleReminder` parses the reminder time and schedules a daily Android notification.

Supported time formats:

- `09:00 AM`
- `9:00 PM`
- `21:00`

The timezone is currently fixed to `Asia/Kolkata`.

## Add Flow

1. User opens the add reminder sheet.
2. Flutter creates a draft reminder.
3. The reminder is inserted into Supabase.
4. The saved row is mapped back into `_Reminder`.
5. A local notification is scheduled.
6. A confirmation notification is shown.

## Toggle Flow

1. User toggles the reminder.
2. Local state updates immediately.
3. If enabled, local notification is scheduled.
4. If disabled, local notification is canceled.
5. Supabase enabled status is updated.

## Delete Flow

1. Local notification is canceled.
2. Reminder is removed from local state.
3. Supabase row is deleted by `id` and `user_id`.

## Current Limits

- Time parsing is string-based; no native time picker persistence type is used.
- The app supports schema fallback because the final reminder table shape appears unsettled.
- Notification timezone is fixed rather than user/device-derived.
- Recurrence is daily only.
- Failed Supabase sync after local toggle/delete can leave local and remote state temporarily inconsistent.

## Suggested Next Steps

- Standardize the Supabase `reminders` schema.
- Use a proper time picker and store a normalized time value.
- Add edit reminder support.
- Consider device timezone instead of hardcoded `Asia/Kolkata`.
- Add retry or refresh behavior after failed remote sync.

