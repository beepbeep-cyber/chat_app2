# Firestore Indexes Required

## Private Chat Filter Index

**Collection:** `users/{userId}/chatHistory`

**Fields to index:**
1. `isPrivate` (Ascending)
2. `timeStamp` (Descending)

### How to create:

**Option 1: Automatic (Recommended)**
1. Run the app
2. Try to view recent chats
3. Firebase will show error with direct link to create index
4. Click the link and Firebase Console will auto-generate the index

**Option 2: Manual**
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Go to Firestore Database → Indexes
4. Click "Create Index"
5. Collection ID: `chatHistory`
6. Add fields:
   - Field: `isPrivate`, Order: Ascending
   - Field: `timeStamp`, Order: Descending
7. Query scope: Collection group
8. Click "Create"

### Index Creation JSON:
```json
{
  "collectionGroup": "chatHistory",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "isPrivate",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "timeStamp",
      "order": "DESCENDING"
    }
  ]
}
```

**Note:** Index creation takes 5-10 minutes. App will work normally after index is ready.
