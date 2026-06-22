import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Trash2, AlertTriangle, CheckCircle } from 'lucide-react';

export default function DeleteAccount() {
  const [step, setStep] = useState(1);
  const [agreed, setAgreed] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [form, setForm] = useState({ phone: '', reason: '' });

  const consequences = [
    'Your account and profile will be permanently deleted',
    'All your booking history and tokens will be removed',
    'Your prescriptions will no longer be accessible',
    'Family member profiles linked to your account will be deleted',
    'This action cannot be undone',
  ];

  const reasons = [
    'I no longer use the app',
    'Privacy concerns',
    'Switching to another service',
    'App is not working properly',
    'Other',
  ];

  const handleSubmit = (e) => {
    e.preventDefault();
    setSubmitted(true);
  };

  if (submitted) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div className="bg-white rounded-3xl p-10 max-w-md w-full text-center shadow-sm border border-gray-100">
          <div className="w-16 h-16 bg-green-100 rounded-2xl flex items-center justify-center mx-auto mb-5">
            <CheckCircle size={32} className="text-green-500" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-3">Request Received</h2>
          <p className="text-gray-600 text-sm leading-relaxed mb-6">
            We've received your account deletion request. Your account will be permanently deleted within{' '}
            <strong>7 business days</strong>. You'll receive a confirmation email at your registered address.
          </p>
          <p className="text-sm text-gray-500 mb-8">
            If you change your mind, simply log in to the app within 7 days to cancel the deletion.
          </p>
          <Link to="/" className="inline-flex items-center gap-2 bg-sky-500 text-white font-semibold px-6 py-3 rounded-xl hover:bg-sky-600 transition-colors">
            Return to Home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-12">
        <Link to="/" className="inline-flex items-center gap-2 text-sky-500 font-medium hover:text-sky-600 mb-8 transition-colors">
          <ArrowLeft size={16} /> Back to Home
        </Link>

        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 p-8">
          <div className="flex items-center gap-4 mb-8">
            <div className="w-12 h-12 bg-red-100 rounded-2xl flex items-center justify-center">
              <Trash2 size={24} className="text-red-500" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Delete Account</h1>
              <p className="text-gray-500 text-sm">This action is permanent and cannot be reversed</p>
            </div>
          </div>

          {/* Steps indicator */}
          <div className="flex items-center gap-3 mb-8">
            {[1, 2].map((s) => (
              <div key={s} className="flex items-center gap-2">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${step >= s ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-400'}`}>
                  {s}
                </div>
                {s < 2 && <div className={`w-12 h-0.5 ${step > s ? 'bg-red-300' : 'bg-gray-100'}`} />}
              </div>
            ))}
            <div className="ml-2 text-sm text-gray-500">{step === 1 ? 'Review consequences' : 'Submit request'}</div>
          </div>

          {step === 1 && (
            <div>
              <div className="bg-red-50 border border-red-100 rounded-2xl p-5 mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <AlertTriangle size={18} className="text-red-500" />
                  <h3 className="font-semibold text-red-700 text-sm">What will be deleted:</h3>
                </div>
                <ul className="space-y-2">
                  {consequences.map((c) => (
                    <li key={c} className="flex items-start gap-2 text-sm text-red-700">
                      <span className="mt-0.5 text-red-400 flex-shrink-0">✕</span>
                      {c}
                    </li>
                  ))}
                </ul>
              </div>

              <label className="flex items-start gap-3 cursor-pointer mb-8">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => setAgreed(e.target.checked)}
                  className="mt-1 w-4 h-4 accent-red-500"
                />
                <span className="text-sm text-gray-700">
                  I understand that deleting my account is permanent and all my data will be lost.
                </span>
              </label>

              <div className="flex gap-3">
                <Link to="/" className="flex-1 text-center border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors">
                  Cancel
                </Link>
                <button
                  onClick={() => setStep(2)}
                  disabled={!agreed}
                  className="flex-1 bg-red-500 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors"
                >
                  Continue
                </button>
              </div>
            </div>
          )}

          {step === 2 && (
            <form onSubmit={handleSubmit}>
              <div className="space-y-5 mb-8">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Registered Phone Number *
                  </label>
                  <input
                    type="tel"
                    required
                    placeholder="+91 98765 43210"
                    value={form.phone}
                    onChange={(e) => setForm({ ...form, phone: e.target.value })}
                    className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Reason for deleting (optional)
                  </label>
                  <select
                    value={form.reason}
                    onChange={(e) => setForm({ ...form, reason: e.target.value })}
                    className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                  >
                    <option value="">Select a reason...</option>
                    {reasons.map((r) => <option key={r} value={r}>{r}</option>)}
                  </select>
                </div>
              </div>

              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={() => setStep(1)}
                  className="flex-1 border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Back
                </button>
                <button
                  type="submit"
                  className="flex-1 bg-red-500 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors flex items-center justify-center gap-2"
                >
                  <Trash2 size={16} />
                  Delete My Account
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
