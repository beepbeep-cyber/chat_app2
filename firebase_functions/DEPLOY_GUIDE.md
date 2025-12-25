# Firebase Cloud Functions Deployment Guide

## Prerequisites

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize project (if not already):
   ```bash
   firebase init functions
   ```

## Deploy Functions

```bash
cd firebase_functions
npm install
firebase deploy --only functions
```

## Functions Included

### 1. autoDeleteMessages
- **Trigger**: Runs every 5 minutes (scheduled)
- **Purpose**: Automatically deletes messages older than the configured duration
- **How it works**:
  - Queries all chatrooms with `autoDeleteEnabled: true`
  - Deletes messages where `timeStamp < now - autoDeleteDuration`
  - Updates `lastMessage` in chatroom after deletion

### 2. sendChatNotification
- **Trigger**: When new message is created in `chatroom/{id}/chats/{messageId}`
- **Purpose**: Sends push notification to recipient
- **Features**:
  - Shows encrypted message indicator for E2EE messages
  - Shows appropriate icon for different message types (image, voice, file, location)

### 3. cleanupUserData
- **Trigger**: When user account is deleted
- **Purpose**: Cleans up user data (user document, chat history)

## Testing Locally

```bash
firebase emulators:start --only functions
```

## View Logs

```bash
firebase functions:log
```

## Firestore Structure Required

```
chatroom/{chatRoomId}
  - autoDeleteEnabled: boolean
  - autoDeleteDuration: number (minutes)
  - lastMessage: string
  - type: string

chatroom/{chatRoomId}/chats/{messageId}
  - message: string
  - sendBy: string
  - senderUid: string
  - timeStamp: timestamp
  - type: string
  - encrypted: boolean

users/{userId}
  - fcmToken: string
  - name: string
```

## Billing Note

⚠️ Scheduled functions require Firebase Blaze (pay-as-you-go) plan.
The free Spark plan does not support scheduled functions.

## Troubleshooting

### Function not triggering
- Check Firebase Console > Functions for errors
- Ensure Blaze plan is enabled for scheduled functions

### Notifications not sending
- Verify FCM token is saved correctly in user document
- Check if recipient has notifications enabled

### Auto-delete not working
- Verify `autoDeleteEnabled` and `autoDeleteDuration` fields exist
- Check timestamp format in messages (should be Firestore Timestamp)
