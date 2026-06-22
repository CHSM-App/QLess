import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, HelpCircle, ChevronDown, ChevronUp, Search } from 'lucide-react';

const faqs = [
  {
    category: 'Getting Started',
    questions: [
      {
        q: 'How do I download QLess?',
        a: 'QLess is available on Google Play Store (Android) and Apple App Store (iOS). Search for "QLess" and tap Install.',
      },
      {
        q: 'Is QLess free to use?',
        a: 'Yes! QLess is completely free for patients. Download and register at no cost.',
      },
      {
        q: 'How do I register?',
        a: 'Open the app, tap "Register", enter your name and mobile number. You\'ll receive an OTP for verification. Once verified, your account is ready!',
      },
    ],
  },
  {
    category: 'Queue & Appointments',
    questions: [
      {
        q: 'How do I book a token?',
        a: 'Open the app → Select clinic → Choose doctor → Tap "Get Token". Your token number will appear instantly with an estimated wait time.',
      },
      {
        q: 'Can I book for a family member?',
        a: 'Yes! Go to Profile → Family Members → Add Member. Fill in their details. When booking a token, select the family member from the dropdown.',
      },
      {
        q: 'How will I know when my turn is near?',
        a: 'QLess sends you a push notification approximately 5 minutes before your turn. Make sure notifications are enabled for the app.',
      },
      {
        q: 'Can I cancel my token?',
        a: 'Yes. Go to My Tokens → Select the token → Tap Cancel. Please cancel at least 10 minutes before your slot so the clinic can adjust.',
      },
    ],
  },
  {
    category: 'Prescriptions',
    questions: [
      {
        q: 'Where can I see my prescription?',
        a: 'After your consultation, your doctor will issue a digital prescription. Go to My Visits → Select the visit → View Prescription.',
      },
      {
        q: 'Can I download my prescription?',
        a: 'Yes, you can download prescriptions as PDF from the app.',
      },
    ],
  },
  {
    category: 'Technical Issues',
    questions: [
      {
        q: 'I\'m not receiving notifications. What should I do?',
        a: 'Check: 1) Notifications are enabled for QLess in phone settings. 2) You have internet connectivity. 3) Try logging out and back in to refresh the notification token.',
      },
      {
        q: 'The app is showing wrong queue number. What to do?',
        a: 'Pull down to refresh the screen. If the issue persists, close and reopen the app. Contact the clinic reception to verify.',
      },
    ],
  },
];

function FAQItem({ q, a }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border border-gray-100 rounded-xl overflow-hidden">
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center justify-between p-4 text-left hover:bg-gray-50 transition-colors"
      >
        <span className="font-medium text-gray-900 text-sm pr-4">{q}</span>
        {open ? <ChevronUp size={16} className="text-sky-500 flex-shrink-0" /> : <ChevronDown size={16} className="text-gray-400 flex-shrink-0" />}
      </button>
      {open && (
        <div className="px-4 pb-4 text-gray-600 text-sm leading-relaxed border-t border-gray-50">
          <div className="pt-3">{a}</div>
        </div>
      )}
    </div>
  );
}

export default function HelpCenter() {
  const [search, setSearch] = useState('');

  const filtered = faqs.map((cat) => ({
    ...cat,
    questions: cat.questions.filter(
      (item) =>
        !search ||
        item.q.toLowerCase().includes(search.toLowerCase()) ||
        item.a.toLowerCase().includes(search.toLowerCase())
    ),
  })).filter((cat) => cat.questions.length > 0);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-gradient-to-b from-sky-600 to-sky-500 py-16">
        <div className="max-w-4xl mx-auto px-4">
          <Link to="/" className="inline-flex items-center gap-2 text-sky-200 font-medium hover:text-white mb-6 transition-colors">
            <ArrowLeft size={16} /> Back to Home
          </Link>
          <div className="flex items-center gap-3 mb-4">
            <HelpCircle size={32} className="text-white" />
            <h1 className="text-3xl font-bold text-white">Help Center</h1>
          </div>
          <p className="text-sky-100 mb-8">Find answers to common questions about QLess</p>

          <div className="relative">
            <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Search your question..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-12 pr-4 py-4 rounded-2xl text-gray-900 text-sm outline-none shadow-xl focus:ring-2 focus:ring-sky-300"
            />
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 py-12">
        {filtered.length === 0 ? (
          <div className="text-center py-16 text-gray-500">
            <HelpCircle size={40} className="mx-auto mb-3 text-gray-300" />
            <p>No results found for "{search}"</p>
            <p className="text-sm mt-2">Try different keywords or contact us below.</p>
          </div>
        ) : (
          <div className="space-y-10">
            {filtered.map((cat) => (
              <div key={cat.category}>
                <h2 className="text-lg font-bold text-gray-900 mb-4">{cat.category}</h2>
                <div className="space-y-2">
                  {cat.questions.map((item) => (
                    <FAQItem key={item.q} {...item} />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Contact Support */}
        <div className="mt-16 bg-sky-50 border border-sky-100 rounded-3xl p-8 text-center">
          <h3 className="text-xl font-bold text-gray-900 mb-2">Still need help?</h3>
          <p className="text-gray-600 text-sm mb-6">Our support team is here for you</p>
          <a
            href="mailto:support@vengurlatech.com"
            className="inline-flex items-center gap-2 bg-sky-500 text-white font-semibold px-6 py-3 rounded-xl hover:bg-sky-600 transition-colors"
          >
            Email Support
          </a>
        </div>
      </div>
    </div>
  );
}
