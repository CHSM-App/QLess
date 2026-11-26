// Set test environment before any modules load. dotenv never overrides a
// variable that is already set, so these beat the real values in backend/.env.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET_KEY = 'test-jwt-secret-key-at-least-32-chars!!';
process.env.DB_SERVER = 'localhost';
process.env.DB_USER = 'test';
process.env.DB_PASSWORD = 'test';
process.env.DB_NAME = 'test';
process.env.CORS_ORIGINS = 'http://localhost:3000';
process.env.PUBLIC_BASE_URL = 'http://localhost:3000';
process.env.DEMO_ENABLED = 'true'; // suites use the demo numbers
process.env.DEMO_OTP = '123456';
// Never send real WhatsApp OTPs or push notifications from a test run.
process.env.WHATSAPP_API_TOKEN = '';
process.env.OTP_TO_CONSOLE = ''; // a dev's .env may print OTPs instead
process.env.GOOGLE_APPLICATION_CREDENTIALS = '';

// No real database: every route talks to the scripted mock in helpers/db.js.
jest.mock('../src/db', () => require('./helpers/db').mockDb);

// Firebase: one shared fake so suites can assert on what was sent.
jest.mock('../src/fcm', () => {
  const messaging = {
    send: jest.fn(() => Promise.resolve('fake-message-id')),
    sendEachForMulticast: jest.fn(() => Promise.resolve({ successCount: 0, failureCount: 0, responses: [] })),
  };
  return { messaging: () => messaging };
});

// doctor/insert.js schedules daily cron jobs at require time; real timers
// would keep Jest from exiting.
jest.mock('node-cron', () => ({ schedule: jest.fn() }));

// Route suites fire the same endpoint many times.
jest.mock('../src/middleware/rateLimit', () => require('./helpers/noRateLimit'));
