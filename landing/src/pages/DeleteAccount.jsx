import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Trash2, AlertTriangle, CheckCircle, Loader2 } from 'lucide-react';

const API_BASE = '';

const ROLES = [
  { id: 2, label: 'Patient' },
  { id: 1, label: 'Doctor' },
  { id: 3, label: 'Receptionist' },
];

const REASONS = [
  'I no longer use the app',
  'Privacy concerns',
  'Switching to another service',
  'App is not working properly',
  'Other',
];

const CONSEQUENCES = [
  'Your account and profile will be permanently deleted',
  'All your booking history and tokens will be removed',
  'Your prescriptions will no longer be accessible',
  'Family member profiles linked to your account will be deleted',
  'This action cannot be undone',
];

export default function DeleteAccount() {
  const [step, setStep]       = useState(1);
  const [agreed, setAgreed]   = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');
  const [submitted, setSubmitted] = useState(false);

  const [phone, setPhone]     = useState('');
  const [roleId, setRoleId]   = useState(2);
  const [otp, setOtp]         = useState('');
  const [reason, setReason]   = useState('');

  const clearError = () => setError('');

  // ── Step 2: Send OTP ──────────────────────────────────────────────
  const handleSendOtp = async (e) => {
    e.preventDefault();
    clearError();
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/login/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mobile_no: phone }),
      });
      const data = await res.json();
      if (!res.ok || data.status === 0) {
        setError(data.message || 'Failed to send OTP');
        return;
      }
      setStep(3);
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // ── Step 3: Verify OTP ────────────────────────────────────────────
  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    clearError();
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/login/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mobile_no: phone, otp }),
      });
      const data = await res.json();
      if (!res.ok || data.status === 0) {
        setError(data.message || 'Invalid OTP');
        return;
      }
      setStep(4);
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // ── Step 4: Submit deletion request ──────────────────────────────
  const handleSubmit = async (e) => {
    e.preventDefault();
    clearError();
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE}/delete-account/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, role_id: roleId, reason: reason || null }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        setError(data.message || 'Failed to submit request');
        return;
      }
      setSubmitted(true);
    } catch {
      setError('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  // ── Success screen ────────────────────────────────────────────────
  if (submitted) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div className="bg-white rounded-3xl p-10 max-w-md w-full text-center shadow-sm border border-gray-100">
          <div className="w-16 h-16 bg-green-100 rounded-2xl flex items-center justify-center mx-auto mb-5">
            <CheckCircle size={32} className="text-green-500" />
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-3">Request Received</h2>
          <p className="text-gray-600 text-sm leading-relaxed mb-6">
            We've received your account deletion request. Your account and all associated
            data will be permanently deleted within <strong>30 days</strong>.
          </p>
          <p className="text-sm text-gray-500 mb-8">
            If you change your mind, contact us at{' '}
            <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">
              support@vengurlatech.com
            </a>{' '}
            within 7 days.
          </p>
          <Link
            to="/"
            className="inline-flex items-center gap-2 bg-sky-500 text-white font-semibold px-6 py-3 rounded-xl hover:bg-sky-600 transition-colors"
          >
            Return to Home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-2xl mx-auto px-4 py-12">
        <Link
          to="/"
          className="inline-flex items-center gap-2 text-sky-500 font-medium hover:text-sky-600 mb-8 transition-colors"
        >
          <ArrowLeft size={16} /> Back to Home
        </Link>

        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 p-8">
          {/* Header */}
          <div className="flex items-center gap-4 mb-8">
            <div className="w-12 h-12 bg-red-100 rounded-2xl flex items-center justify-center">
              <Trash2 size={24} className="text-red-500" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Delete Account</h1>
              <p className="text-gray-500 text-sm">This action is permanent and cannot be reversed</p>
            </div>
          </div>

          {/* Step indicator */}
          <div className="flex items-center gap-3 mb-8">
            {[1, 2, 3, 4].map((s) => (
              <div key={s} className="flex items-center gap-2">
                <div
                  className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                    step >= s ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-400'
                  }`}
                >
                  {s}
                </div>
                {s < 4 && (
                  <div className={`w-8 h-0.5 ${step > s ? 'bg-red-300' : 'bg-gray-100'}`} />
                )}
              </div>
            ))}
            <span className="ml-2 text-xs text-gray-500">
              {step === 1 && 'Review'}
              {step === 2 && 'Phone'}
              {step === 3 && 'Verify OTP'}
              {step === 4 && 'Confirm'}
            </span>
          </div>

          {/* Error */}
          {error && (
            <div className="bg-red-50 border border-red-100 text-red-700 text-sm rounded-xl px-4 py-3 mb-5">
              {error}
            </div>
          )}

          {/* ── Step 1: Consequences ── */}
          {step === 1 && (
            <div>
              <div className="bg-red-50 border border-red-100 rounded-2xl p-5 mb-6">
                <div className="flex items-center gap-2 mb-4">
                  <AlertTriangle size={18} className="text-red-500" />
                  <h3 className="font-semibold text-red-700 text-sm">What will be deleted:</h3>
                </div>
                <ul className="space-y-2">
                  {CONSEQUENCES.map((c) => (
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
                <Link
                  to="/"
                  className="flex-1 text-center border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </Link>
                <button
                  onClick={() => { clearError(); setStep(2); }}
                  disabled={!agreed}
                  className="flex-1 bg-red-500 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors"
                >
                  Continue
                </button>
              </div>
            </div>
          )}

          {/* ── Step 2: Phone + Role ── */}
          {step === 2 && (
            <form onSubmit={handleSendOtp} className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Account Type *
                </label>
                <select
                  value={roleId}
                  onChange={(e) => setRoleId(Number(e.target.value))}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                >
                  {ROLES.map((r) => (
                    <option key={r.id} value={r.id}>{r.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Registered Phone Number *
                </label>
                <input
                  type="tel"
                  required
                  placeholder="98765 43210"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                />
                <p className="text-xs text-gray-400 mt-1">Enter the number registered in QLess</p>
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => { clearError(); setStep(1); }}
                  className="flex-1 border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Back
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 bg-red-500 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors flex items-center justify-center gap-2"
                >
                  {loading ? <Loader2 size={16} className="animate-spin" /> : 'Send OTP'}
                </button>
              </div>
            </form>
          )}

          {/* ── Step 3: OTP verify ── */}
          {step === 3 && (
            <form onSubmit={handleVerifyOtp} className="space-y-5">
              <p className="text-sm text-gray-600">
                OTP sent to <strong>+91 {phone}</strong> via WhatsApp.
              </p>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Enter OTP *
                </label>
                <input
                  type="text"
                  required
                  maxLength={6}
                  placeholder="6-digit OTP"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100 tracking-widest text-center text-lg"
                />
              </div>

              <p className="text-xs text-gray-400">
                Didn't receive?{' '}
                <button
                  type="button"
                  onClick={() => { setOtp(''); setStep(2); clearError(); }}
                  className="text-sky-500 hover:underline"
                >
                  Resend OTP
                </button>
              </p>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => { clearError(); setStep(2); }}
                  className="flex-1 border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Back
                </button>
                <button
                  type="submit"
                  disabled={loading || otp.length < 6}
                  className="flex-1 bg-red-500 disabled:bg-gray-200 disabled:text-gray-400 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors flex items-center justify-center gap-2"
                >
                  {loading ? <Loader2 size={16} className="animate-spin" /> : 'Verify OTP'}
                </button>
              </div>
            </form>
          )}

          {/* ── Step 4: Reason + final confirm ── */}
          {step === 4 && (
            <form onSubmit={handleSubmit} className="space-y-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Reason for deleting (optional)
                </label>
                <select
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100"
                >
                  <option value="">Select a reason...</option>
                  {REASONS.map((r) => <option key={r} value={r}>{r}</option>)}
                </select>
              </div>

              <div className="bg-red-50 border border-red-100 rounded-xl p-4 text-sm text-red-700">
                <strong>Final confirmation:</strong> Deleting account for +91 {phone}.
                This cannot be undone.
              </div>

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => { clearError(); setStep(3); }}
                  className="flex-1 border border-gray-200 text-gray-700 font-semibold py-3 rounded-xl hover:bg-gray-50 transition-colors"
                >
                  Back
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 bg-red-500 text-white font-semibold py-3 rounded-xl hover:bg-red-600 transition-colors flex items-center justify-center gap-2"
                >
                  {loading
                    ? <Loader2 size={16} className="animate-spin" />
                    : <><Trash2 size={16} /> Delete My Account</>
                  }
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
