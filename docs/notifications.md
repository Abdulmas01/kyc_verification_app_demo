# Notifications

This document describes how notifications are modeled and how CTA actions are resolved in the app.

## Overview
- Notifications are fetched from the backend `/v1/notifications` endpoint.
- Each notification can optionally include typed `data` and `metadata`.
- CTA (call-to-action) buttons are shown only when:
  - A label is resolved by the CTA policy, and
  - A valid action can be resolved for the notification.

## Payload Models
Notification DTO fields are mapped into the following models:
- `NotificationModel`
- `NotificationDataModel`
- `NotificationMetadataModel`

Key typed fields:
- `data.entityId` and `data.refId` are used to route to entity screens.
- `data.transactionRef` is used for payment/receipt linking.
- `metadata.custom` can carry future extensions without breaking parsing.

## CTA Resolution
CTA is split into three steps:
1. `NotificationCtaPolicy` decides the button label.
2. `NotificationActionValidator` checks if the notification is actionable.
3. `NotificationActionResolver` returns the actual action closure.

If a route is not available yet, the app shows a “coming soon” toast.

## Routing Strategy
Current routing behavior:
- Booking- and payment-related notifications route to the Bookings tab (placeholder).
- KYC notifications route to the KYC intro flow.
- Chat, wallet, and review routes show a “coming soon” toast until screens are available.

To add or update routes, edit:
- `lib/core/features/notifications/domain/notification_actions/notification_action_closures.dart`
- `lib/core/features/notifications/domain/notification_actions/notification_action_resolver.dart`
