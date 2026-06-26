import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Activity, ArrowLeft, AlertTriangle, Phone, KeyRound, FileText, CheckCircle, XCircle, Loader2 } from 'lucide-react';

const API_BASE = '';

const ROLES = [
  { id: 2, label: 'Patient' },
  { id: 1, label: 'Doctor' },
  { id: 3, label: 'Receptionist' },
];

const CONSEQUENCES = [
  'Your account and profile will be permanently deleted',
  'All your booking history and tokens will be removed',
  'Your prescriptions will no longer be accessible',
  'Family member profiles linked to your account will be deleted',
  'This action cannot be undone after the 30-day grace period',
];

// ── Helpers ──────────────────────────────────────────────────────────────────

async function apiPost(path, body) {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  let data = null;
  try { data = raw ? JSON.parse(raw) : null; } catch (_) { data = null; }
  if (!res.ok) throw new Error(data?.message || data?.error || 'Something went wrong.');
  if (!data || typeof data !== 'object') throw new Error('Something went wrong.');
  return data;
}

// ── Step indicator ────────────────────────────────────────────────────────────

function StepDot({ n, active, done }) {
  return (
    <div
      className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all
        ${done ? 'bg-sky-500 text-white' : active ? 'bg-sky-500 text-white ring-4 ring-sky-100' : 'bg-gray-100 text-gray-400'}`}
    >
      {done ? '✓' : n}
    </div>
  );
}

function Steps({ current }) {
  const labels = ['Phone', 'Verify OTP', 'Confirm'];
  return (
    <div className="flex items-center gap-0 mb-8">
      {labels.map((label, i) => (
        <React.Fragment key={i}>
          <div className="flex flex-col items-center gap-1 flex-shrink-0">
            <StepDot n={i + 1} active={current === i} done={current > i} />
            <span className={`text-xs font-medium ${current >= i ? 'text-gray-700' : 'text-gray-400'}`}>
              {label}
            </span>
          </div>
          {i < labels.length - 1 && (
            <div className={`flex-1 h-0.5 mx-2 mb-4 ${current > i ? 'bg-sky-400' : 'bg-gray-100'}`} />
          )}
        </React.Fragment>
      ))}
    </div>
  );
}

// ── Main component ────────────────────────────────────────────────────────────

export default function DeleteAccount() {
  const [step, setStep]       = useState(0);  // 0=phone, 1=otp, 2=confirm, 3=done
  const [phone, setPhone]     = useState('');
  const [roleId, setRoleId]   = useState(2);
  const [otp, setOtp]         = useState('');
  const [reason, setReason]   = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState('');
  const [scheduled, setScheduled] = useState(null);

  // Cancel flow state
  const [showCancel, setShowCancel]         = useState(false);
  const [cancelPhone, setCancelPhone]       = useState('');
  const [cancelRoleId, setCancelRoleId]     = useState(2);
  const [cancelOtp, setCancelOtp]           = useState('');
  const [cancelStep, setCancelStep]         = useState(0); // 0=phone, 1=otp
  const [cancelLoading, setCancelLoading]   = useState(false);
  const [cancelError, setCancelError]       = useState('');
  const [cancelSuccess, setCancelSuccess]   = useState(false);

  useEffect(() => { window.scrollTo(0, 0); }, []);

  const clearError = () => setError('');

  // ── Step 0 → send OTP ──────────────────────────────────────────────────────

  async function handleSendOtp(e) {
    e.preventDefault();
    clearError();
    if (!/^\d{10}$/.test(phone)) { setError('Enter a valid 10-digit phone number.'); return; }
    setLoading(true);
    try {
      await apiPost('/delete-account/request', { phone, role_id: roleId });
      setStep(1);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  // ── Step 1 → validate OTP format, move to confirm ─────────────────────────

  function handleOtpNext(e) {
    e.preventDefault();
    clearError();
    if (!/^\d{6}$/.test(otp)) { setError('OTP must be exactly 6 digits.'); return; }
    setStep(2);
  }

  // ── Step 2 → confirm deletion ──────────────────────────────────────────────

  async function handleConfirm(e) {
    e.preventDefault();
    clearError();
    setLoading(true);
    try {
      const data = await apiPost('/delete-account/confirm', {
        phone, role_id: roleId, otp, reason: reason.trim() || undefined,
      });
      setScheduled(new Date(data.scheduled_for));
      setStep(3);
    } catch (err) {
      if (err.message.toLowerCase().includes('otp')) {
        setStep(1);
        setOtp('');
      }
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  // ── Cancel flow ────────────────────────────────────────────────────────────

  async function handleCancelSendOtp(e) {
    e.preventDefault();
    setCancelError('');
    if (!/^\d{10}$/.test(cancelPhone)) { setCancelError('Enter a valid 10-digit phone number.'); return; }
    setCancelLoading(true);
    try {
      await apiPost('/delete-account/request', { phone: cancelPhone, role_id: cancelRoleId });
      setCancelStep(1);
    } catch (err) {
      setCancelError(err.message);
    } finally {
      setCancelLoading(false);
    }
  }

  async function handleCancelConfirm(e) {
    e.preventDefault();
    setCancelError('');
    if (!/^\d{6}$/.test(cancelOtp)) { setCancelError('OTP must be exactly 6 digits.'); return; }
    setCancelLoading(true);
    try {
      await apiPost('/delete-account/cancel', { phone: cancelPhone, role_id: cancelRoleId, otp: cancelOtp });
      setCancelSuccess(true);
    } catch (err) {
      setCancelError(err.message);
    } finally {
      setCancelLoading(false);
    }
  }

  // ── Shared styles ─────────────────────────────────────────────────────────

  const inputCls = 'w-full border border-gray-200 rounded-xl px-4 py-3 text-sm outline-none focus:border-sky-400 focus:ring-2 focus:ring-sky-100 bg-white text-gray-800 placeholder-gray-400 transition-all';

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-gray-50">

      {/* Top bar */}
      <div className="bg-slate-900 px-6 py-4">
        <div className="max-w-4xl mx-auto flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <div className="w-8 h-8 bg-gradient-to-br from-sky-500 to-cyan-400 rounded-lg flex items-center justify-center">
              <Activity size={16} className="text-white" />
            </div>
            <span className="text-lg font-bold text-white">Q<span className="text-sky-400">Less</span></span>
          </Link>
          <Link to="/" className="flex items-center gap-2 text-sm text-white/50 hover:text-white transition-colors">
            <ArrowLeft size={15} />
            Back to Home
          </Link>
        </div>
      </div>

      {/* Hero */}
      <div className="px-6 py-14 text-center bg-gradient-to-br from-slate-900 to-slate-800">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-xs font-semibold mb-5 bg-red-500/15 text-red-300">
          <AlertTriangle size={11} />
          Permanent Action
        </div>
        <h1 className="text-4xl font-extrabold text-white mb-3">Delete Account</h1>
        <p className="text-white/45 max-w-sm mx-auto text-sm leading-relaxed">
          Permanently delete your QLess account and all associated data.
          This action cannot be undone after the 30-day grace period.
        </p>
      </div>

      <div className="max-w-xl mx-auto px-6 py-12">

        {/* ── Done state ───────────────────────────────────────────────────── */}
        {step === 3 && (
          <div className="rounded-2xl p-8 text-center border border-gray-100 bg-white shadow-sm">
            <div className="w-14 h-14 rounded-full flex items-center justify-center mx-auto mb-4 bg-red-50">
              <CheckCircle size={28} className="text-red-500" />
            </div>
            <h2 className="font-bold text-gray-900 text-xl mb-2">Request Received</h2>
            <p className="text-sm text-gray-500 leading-relaxed mb-2">
              Your account is scheduled for permanent deletion on:
            </p>
            <p className="font-bold text-gray-900 text-lg mb-5">
              {scheduled ? scheduled.toDateString() : '—'}
            </p>
            <div className="rounded-xl p-4 text-left text-sm text-gray-600 leading-relaxed mb-6 bg-sky-50 border border-sky-100">
              <strong className="text-gray-900">Changed your mind?</strong> You can cancel this request
              any time before the scheduled date using the cancellation form below.
            </div>
            <Link
              to="/"
              className="inline-block text-xs font-bold px-5 py-2.5 rounded-xl text-white bg-sky-500 hover:bg-sky-600 transition-colors"
            >
              Back to Home
            </Link>
          </div>
        )}

        {/* ── Multi-step deletion form ─────────────────────────────────────── */}
        {step < 3 && (
          <div className="rounded-2xl border border-gray-100 bg-white shadow-sm overflow-hidden">

            {/* Warning banner */}
            <div className="px-6 py-4 flex items-start gap-3 bg-red-50 border-b border-red-100">
              <AlertTriangle size={18} className="flex-shrink-0 mt-0.5 text-red-500" />
              <p className="text-xs text-gray-600 leading-relaxed">
                <strong className="text-red-600">All data will be permanently deleted</strong> — bookings,
                tokens, prescriptions, and family profiles. You have 30 days to cancel after submitting.
              </p>
            </div>

            <div className="p-6">
              <Steps current={step} />

              {error && (
                <div className="flex items-center gap-2 rounded-xl px-4 py-3 mb-5 text-sm bg-red-50 text-red-700 border border-red-100">
                  <XCircle size={15} className="flex-shrink-0" />
                  {error}
                </div>
              )}

              {/* Step 0 — Phone + Role */}
              {step === 0 && (
                <form onSubmit={handleSendOtp} className="space-y-4">
                  <div>
                    <label className="block text-xs font-semibold text-gray-600 mb-1.5">Account Type</label>
                    <select
                      value={roleId}
                      onChange={(e) => setRoleId(Number(e.target.value))}
                      className={inputCls}
                    >
                      {ROLES.map((r) => <option key={r.id} value={r.id}>{r.label}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs font-semibold text-gray-600 mb-1.5">Registered Phone Number</label>
                    <div className="relative">
                      <Phone size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                      <input
                        type="tel"
                        inputMode="numeric"
                        maxLength={10}
                        placeholder="10-digit mobile number"
                        value={phone}
                        onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                        className={`${inputCls} pl-10`}
                        required
                      />
                    </div>
                    <p className="text-xs text-gray-400 mt-1.5">We'll send a one-time code to this number via WhatsApp.</p>
                  </div>

                  {/* Consequences */}
                  <div className="rounded-xl p-4 bg-red-50 border border-red-100 text-xs text-red-700 space-y-1.5">
                    {CONSEQUENCES.map((c) => (
                      <div key={c} className="flex items-start gap-2">
                        <span className="text-red-400 flex-shrink-0 mt-0.5">✕</span>
                        {c}
                      </div>
                    ))}
                  </div>

                  <button
                    type="submit"
                    disabled={loading || phone.length !== 10}
                    className="w-full py-3 rounded-xl text-sm font-bold text-white flex items-center justify-center gap-2 bg-red-500 hover:bg-red-600 disabled:bg-gray-200 disabled:text-gray-400 transition-colors"
                  >
                    {loading && <Loader2 size={15} className="animate-spin" />}
                    {loading ? 'Sending OTP…' : 'Send Verification Code'}
                  </button>
                </form>
              )}

              {/* Step 1 — OTP */}
              {step === 1 && (
                <form onSubmit={handleOtpNext} className="space-y-4">
                  <div>
                    <label className="block text-xs font-semibold text-gray-600 mb-1.5">
                      Enter the 6-digit code sent to +91 {phone}
                    </label>
                    <div className="relative">
                      <KeyRound size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                      <input
                        type="tel"
                        inputMode="numeric"
                        maxLength={6}
                        placeholder="6-digit OTP"
                        value={otp}
                        onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                        className={`${inputCls} pl-10 tracking-widest text-center font-mono text-lg`}
                        autoFocus
                        required
                      />
                    </div>
                    <p className="text-xs text-gray-400 mt-1.5">
                      The code expires in 10 minutes.{' '}
                      <button
                        type="button"
                        className="text-sky-500 font-semibold hover:underline"
                        onClick={() => { setOtp(''); setStep(0); clearError(); }}
                      >
                        Change number
                      </button>
                    </p>
                  </div>
                  <button
                    type="submit"
                    disabled={otp.length !== 6}
                    className="w-full py-3 rounded-xl text-sm font-bold text-white bg-red-500 hover:bg-red-600 disabled:bg-gray-200 disabled:text-gray-400 transition-colors"
                  >
                    Continue
                  </button>
                </form>
              )}

              {/* Step 2 — Final confirmation */}
              {step === 2 && (
                <form onSubmit={handleConfirm} className="space-y-5">
                  <div className="rounded-xl p-4 text-sm leading-relaxed bg-red-50 border border-red-100">
                    <p className="font-semibold text-red-700 mb-1">You are about to delete:</p>
                    <ul className="text-gray-600 space-y-0.5 list-disc list-inside text-xs">
                      {CONSEQUENCES.map((c) => <li key={c}>{c}</li>)}
                    </ul>
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-gray-600 mb-1.5">
                      Reason for leaving <span className="font-normal text-gray-400">(optional)</span>
                    </label>
                    <div className="relative">
                      <FileText size={15} className="absolute left-3.5 top-3.5 text-gray-400 pointer-events-none" />
                      <textarea
                        rows={3}
                        placeholder="Help us improve QLess…"
                        value={reason}
                        onChange={(e) => setReason(e.target.value.slice(0, 500))}
                        className={`${inputCls} pl-10 resize-none`}
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full py-3 rounded-xl text-sm font-bold text-white flex items-center justify-center gap-2 bg-red-500 hover:bg-red-600 disabled:bg-red-300 transition-colors"
                  >
                    {loading && <Loader2 size={15} className="animate-spin" />}
                    {loading ? 'Submitting…' : 'Yes, Delete My Account'}
                  </button>
                  <button
                    type="button"
                    className="w-full py-2.5 rounded-xl text-sm font-semibold border border-gray-200 text-gray-500 hover:border-gray-300 transition-colors bg-white"
                    onClick={() => { setStep(0); setOtp(''); setPhone(''); clearError(); }}
                  >
                    Cancel — Keep My Account
                  </button>
                </form>
              )}
            </div>
          </div>
        )}

        {/* ── Cancel existing request ──────────────────────────────────────── */}
        <div className="mt-10">
          <button
            type="button"
            className="text-sm font-semibold w-full text-center text-sky-500 hover:text-sky-600 transition-colors"
            onClick={() => { setShowCancel((v) => !v); setCancelError(''); setCancelSuccess(false); }}
          >
            {showCancel ? 'Hide cancellation form ▲' : 'Already submitted a request? Cancel it here ▼'}
          </button>

          {showCancel && (
            <div className="mt-4 rounded-2xl border border-gray-100 bg-white shadow-sm overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100">
                <h3 className="font-bold text-gray-900 text-sm">Cancel Deletion Request</h3>
                <p className="text-xs text-gray-400 mt-0.5">Verify your identity to cancel the pending request.</p>
              </div>
              <div className="p-6">
                {cancelSuccess ? (
                  <div className="flex items-center gap-3 text-sm text-sky-600">
                    <CheckCircle size={18} />
                    <span className="font-semibold">Your deletion request has been cancelled. Your account is safe.</span>
                  </div>
                ) : (
                  <>
                    {cancelError && (
                      <div className="flex items-center gap-2 rounded-xl px-4 py-3 mb-4 text-sm bg-red-50 text-red-700 border border-red-100">
                        <XCircle size={15} className="flex-shrink-0" />
                        {cancelError}
                      </div>
                    )}

                    {cancelStep === 0 && (
                      <form onSubmit={handleCancelSendOtp} className="space-y-4">
                        <div>
                          <label className="block text-xs font-semibold text-gray-600 mb-1.5">Account Type</label>
                          <select
                            value={cancelRoleId}
                            onChange={(e) => setCancelRoleId(Number(e.target.value))}
                            className={inputCls}
                          >
                            {ROLES.map((r) => <option key={r.id} value={r.id}>{r.label}</option>)}
                          </select>
                        </div>
                        <div className="relative">
                          <Phone size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                          <input
                            type="tel"
                            inputMode="numeric"
                            maxLength={10}
                            placeholder="Registered phone number"
                            value={cancelPhone}
                            onChange={(e) => setCancelPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                            className={`${inputCls} pl-10`}
                          />
                        </div>
                        <button
                          type="submit"
                          disabled={cancelLoading || cancelPhone.length !== 10}
                          className="w-full py-3 rounded-xl text-sm font-bold text-white flex items-center justify-center gap-2 bg-sky-500 hover:bg-sky-600 disabled:bg-gray-200 disabled:text-gray-400 transition-colors"
                        >
                          {cancelLoading && <Loader2 size={15} className="animate-spin" />}
                          {cancelLoading ? 'Sending OTP…' : 'Send Verification Code'}
                        </button>
                      </form>
                    )}

                    {cancelStep === 1 && (
                      <form onSubmit={handleCancelConfirm} className="space-y-4">
                        <div className="relative">
                          <KeyRound size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                          <input
                            type="tel"
                            inputMode="numeric"
                            maxLength={6}
                            placeholder="6-digit OTP"
                            value={cancelOtp}
                            onChange={(e) => setCancelOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                            className={`${inputCls} pl-10 tracking-widest text-center font-mono text-lg`}
                            autoFocus
                          />
                        </div>
                        <button
                          type="submit"
                          disabled={cancelLoading || cancelOtp.length !== 6}
                          className="w-full py-3 rounded-xl text-sm font-bold text-white flex items-center justify-center gap-2 bg-sky-500 hover:bg-sky-600 disabled:bg-gray-200 disabled:text-gray-400 transition-colors"
                        >
                          {cancelLoading && <Loader2 size={15} className="animate-spin" />}
                          {cancelLoading ? 'Cancelling…' : 'Cancel My Deletion Request'}
                        </button>
                      </form>
                    )}
                  </>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer nav */}
        <div className="flex flex-wrap justify-center gap-6 mt-12 pt-8 border-t border-gray-200 text-xs text-gray-400">
          <Link to="/" className="hover:text-gray-700 transition-colors">Home</Link>
          <Link to="/help-center" className="hover:text-gray-700 transition-colors">Help Center</Link>
          <Link to="/privacy-policy" className="hover:text-gray-700 transition-colors">Privacy Policy</Link>
          <a href="mailto:support@vengurlatech.com" className="hover:text-gray-700 transition-colors">Contact</a>
        </div>
      </div>
    </div>
  );
}
