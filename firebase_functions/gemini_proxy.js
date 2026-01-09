/**
 * Firebase Cloud Function - Gemini API Proxy
 * 
 * Features:
 * - Smart key rotation with 50+ keys support
 * - Rate limiting per user (prevent abuse)
 * - Response caching (reduce API calls)
 * - Error handling and fallback
 * - Usage analytics
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// API Keys Pool (load from Firestore for easy management)
let API_KEYS_POOL = [];
let currentKeyIndex = 0;
let keyUsageCount = {}; // Track usage per key

// Rate limiting config
const RATE_LIMIT_PER_USER = 20; // 20 requests per minute per user
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute

/**
 * Load API keys from Firestore
 */
async function loadApiKeys() {
  try {
    const doc = await db.collection('config').doc('gemini_api_keys').get();
    if (doc.exists) {
      API_KEYS_POOL = doc.data().keys || [];
      console.log(`✅ Loaded ${API_KEYS_POOL.length} API keys`);
      
      // Initialize usage counters
      API_KEYS_POOL.forEach((key, index) => {
        if (!keyUsageCount[index]) {
          keyUsageCount[index] = { count: 0, resetAt: Date.now() + 60000 };
        }
      });
    }
  } catch (error) {
    console.error('❌ Failed to load API keys:', error);
  }
}

/**
 * Get next available API key (smart rotation)
 */
function getNextApiKey() {
  if (API_KEYS_POOL.length === 0) {
    throw new Error('No API keys available');
  }

  const now = Date.now();
  let attempts = 0;
  const maxAttempts = API_KEYS_POOL.length;

  while (attempts < maxAttempts) {
    const keyIndex = currentKeyIndex;
    const keyStats = keyUsageCount[keyIndex];

    // Reset counter if window passed
    if (keyStats.resetAt < now) {
      keyStats.count = 0;
      keyStats.resetAt = now + 60000;
    }

    // Check if key is available (under 14 requests/min - leave buffer)
    if (keyStats.count < 14) {
      keyStats.count++;
      return { key: API_KEYS_POOL[keyIndex], index: keyIndex };
    }

    // Try next key
    currentKeyIndex = (currentKeyIndex + 1) % API_KEYS_POOL.length;
    attempts++;
  }

  throw new Error('All API keys are rate limited');
}

/**
 * Check rate limit for user
 */
async function checkUserRateLimit(userId) {
  const userRef = db.collection('api_rate_limits').doc(userId);
  const doc = await userRef.get();
  const now = Date.now();

  if (!doc.exists) {
    // First request
    await userRef.set({
      requests: [now],
      windowStart: now
    });
    return true;
  }

  const data = doc.data();
  let requests = data.requests || [];

  // Remove old requests outside window
  requests = requests.filter(timestamp => timestamp > now - RATE_LIMIT_WINDOW);

  // Check limit
  if (requests.length >= RATE_LIMIT_PER_USER) {
    return false; // Rate limited
  }

  // Add new request
  requests.push(now);
  await userRef.update({ requests });
  
  return true;
}

/**
 * Check cache for response
 */
async function checkCache(messageHash) {
  const cacheRef = db.collection('gemini_cache').doc(messageHash);
  const doc = await cacheRef.get();
  
  if (doc.exists) {
    const data = doc.data();
    // Cache valid for 24 hours
    if (data.timestamp > Date.now() - 24 * 60 * 60 * 1000) {
      console.log('✅ Cache hit:', messageHash);
      return data.response;
    }
  }
  
  return null;
}

/**
 * Save response to cache
 */
async function saveToCache(messageHash, response) {
  await db.collection('gemini_cache').doc(messageHash).set({
    response,
    timestamp: Date.now()
  });
}

/**
 * Main Cloud Function
 */
exports.geminiProxy = functions.https.onCall(async (data, context) => {
  try {
    // Authenticate user
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const { message, conversationHistory = [] } = data;

    if (!message || typeof message !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Message is required');
    }

    // Check user rate limit
    const allowed = await checkUserRateLimit(userId);
    if (!allowed) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Rate limit exceeded. Please wait before sending more messages.'
      );
    }

    // Load keys if not loaded
    if (API_KEYS_POOL.length === 0) {
      await loadApiKeys();
    }

    // Check cache (hash message for simple queries)
    const crypto = require('crypto');
    const messageHash = crypto.createHash('md5').update(message.toLowerCase()).digest('hex');
    
    if (conversationHistory.length === 0) {
      const cachedResponse = await checkCache(messageHash);
      if (cachedResponse) {
        return { response: cachedResponse, cached: true };
      }
    }

    // Get API key
    const { key: apiKey, index: keyIndex } = getNextApiKey();

    // Build request
    const contents = [
      ...conversationHistory.map(msg => ({
        role: msg.role === 'user' ? 'user' : 'model',
        parts: [{ text: msg.content }]
      })),
      {
        role: 'user',
        parts: [{ text: message }]
      }
    ];

    // Call Gemini API
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      {
        contents,
        generationConfig: {
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 1024
        }
      },
      {
        timeout: 30000,
        headers: { 'Content-Type': 'application/json' }
      }
    );

    const aiResponse = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!aiResponse) {
      throw new Error('Empty response from Gemini API');
    }

    // Save to cache (only for simple queries)
    if (conversationHistory.length === 0) {
      await saveToCache(messageHash, aiResponse);
    }

    // Log usage for analytics
    await db.collection('gemini_usage_logs').add({
      userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      messageLength: message.length,
      responseLength: aiResponse.length,
      keyIndex,
      cached: false
    });

    console.log(`✅ Request processed for user ${userId} with key ${keyIndex}`);

    return {
      response: aiResponse,
      cached: false
    };

  } catch (error) {
    console.error('❌ Error in geminiProxy:', error);

    if (error.response?.status === 429) {
      // Mark key as rate limited and retry
      console.log('⏰ Key rate limited, rotating...');
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Service temporarily busy. Please try again in a moment.'
      );
    }

    if (error.code) {
      throw error; // Re-throw HttpsError
    }

    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Scheduled function to reload keys every hour
 */
exports.reloadApiKeys = functions.pubsub.schedule('every 60 minutes').onRun(async () => {
  await loadApiKeys();
  console.log('🔄 API keys reloaded');
});

/**
 * Admin function to add/remove keys
 */
exports.manageApiKeys = functions.https.onCall(async (data, context) => {
  // Check admin permissions
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const { action, keys } = data;

  if (action === 'set') {
    await db.collection('config').doc('gemini_api_keys').set({ keys });
    await loadApiKeys();
    return { success: true, keysCount: keys.length };
  }

  if (action === 'get') {
    return { keys: API_KEYS_POOL };
  }

  throw new functions.https.HttpsError('invalid-argument', 'Invalid action');
});
