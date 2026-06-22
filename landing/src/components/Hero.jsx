import { ArrowDown, Star, CheckCircle } from 'lucide-react';

export default function Hero() {
  return (
    <section className="hero-gradient min-h-screen flex items-center relative overflow-hidden">
      {/* Background circles */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-96 h-96 bg-sky-500/20 rounded-full blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-96 h-96 bg-cyan-400/15 rounded-full blur-3xl" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-sky-600/10 rounded-full blur-3xl" />
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-16 relative z-10">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left Content */}
          <div>
            <div className="inline-flex items-center gap-2 bg-sky-500/20 border border-sky-400/30 rounded-full px-4 py-1.5 mb-6">
              <Star size={14} className="text-sky-400 fill-sky-400" />
              <span className="text-sky-300 text-sm font-medium">India's Smartest Clinic Queue System</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white leading-tight mb-6">
              No More{' '}
              <span className="text-gradient">Long Waits</span>{' '}
              at the Clinic
            </h1>

            <p className="text-lg text-slate-300 leading-relaxed mb-8 max-w-lg">
              QLess lets patients join the queue from their phone, track real-time wait times,
              and get notified when it's their turn — so they arrive just in time.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 mb-10">
              <a
                href="#download"
                className="flex items-center justify-center gap-3 bg-white text-gray-900 font-bold px-6 py-4 rounded-2xl hover:bg-gray-100 transition-all hover:-translate-y-0.5 shadow-xl"
              >
                <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Play Store" className="h-6" />
                <div className="text-left">
                  <div className="text-xs text-gray-500">Get it on</div>
                  <div className="text-sm font-bold">Google Play</div>
                </div>
              </a>
              <a
                href="#download"
                className="flex items-center justify-center gap-3 bg-sky-500 text-white font-bold px-6 py-4 rounded-2xl hover:bg-sky-600 transition-all hover:-translate-y-0.5 shadow-xl border border-sky-400"
              >
                <svg className="w-7 h-7" viewBox="0 0 814 1000" fill="currentColor">
                  <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.8 8 279.7 8 160C8 67.7 62.4 10.1 145.1 10.1c57.8 0 100.5 37.8 145.8 37.8 43.1 0 91.9-39.5 162.7-39.5 62.2 0 115.2 39.1 148.8 100.4zm-188.4-90.5c-28.4 34.5-76 61.9-123.6 61.9-5.2 0-10.3-.3-15.5-1 1.3-51.7 27.2-99.7 57.8-131.1 33.6-35.5 87.4-64 134.4-66.1 1.3 53.2-17.9 102.8-53.1 136.3z"/>
                </svg>
                <div className="text-left">
                  <div className="text-xs text-sky-200">Download on the</div>
                  <div className="text-sm font-bold">App Store</div>
                </div>
              </a>
            </div>

            <div className="flex flex-wrap gap-6">
              {[
                'Free to Download',
                'Works Offline',
                'Family Profiles',
              ].map((item) => (
                <div key={item} className="flex items-center gap-2 text-slate-300 text-sm">
                  <CheckCircle size={16} className="text-sky-400" />
                  {item}
                </div>
              ))}
            </div>
          </div>

          {/* Right - Phone Mockup */}
          <div className="flex justify-center lg:justify-end">
            <div className="relative">
              {/* Glow */}
              <div className="absolute inset-0 bg-sky-400/30 blur-3xl rounded-full scale-75" />

              {/* Phone */}
              <div className="relative w-64 h-[520px] bg-gray-900 rounded-[40px] border-4 border-gray-700 shadow-2xl overflow-hidden">
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-28 h-7 bg-gray-900 rounded-b-2xl z-10" />
                <div className="w-full h-full bg-gradient-to-b from-sky-900 to-slate-900 flex flex-col items-center justify-center px-4 text-center">
                  <div className="w-16 h-16 bg-sky-500/20 rounded-2xl flex items-center justify-center mb-4 border border-sky-400/30">
                    <span className="text-3xl">🏥</span>
                  </div>
                  <div className="text-white font-bold text-lg mb-1">Your Queue Token</div>
                  <div className="text-sky-400 font-black text-6xl mb-3">A-07</div>
                  <div className="text-slate-400 text-sm mb-4">Current: A-04</div>
                  <div className="w-full bg-sky-900 rounded-xl p-3 border border-sky-800">
                    <div className="text-sky-300 text-xs mb-1">Estimated Wait</div>
                    <div className="text-white font-bold text-xl">~12 mins</div>
                  </div>
                  <div className="mt-4 flex gap-2">
                    <span className="bg-green-500/20 text-green-400 text-xs px-3 py-1 rounded-full border border-green-500/30">Live</span>
                    <span className="bg-sky-500/20 text-sky-400 text-xs px-3 py-1 rounded-full border border-sky-500/30">Notified</span>
                  </div>
                </div>
              </div>

              {/* Floating cards */}
              <div className="absolute -left-12 top-20 bg-white rounded-2xl p-3 shadow-xl flex items-center gap-2 text-xs font-medium text-gray-700">
                <span className="text-green-500 text-lg">✓</span>
                Token Booked!
              </div>
              <div className="absolute -right-8 bottom-24 bg-white rounded-2xl p-3 shadow-xl flex items-center gap-2 text-xs font-medium text-gray-700">
                <span className="text-sky-500 text-lg">🔔</span>
                Your turn in 2 min
              </div>
            </div>
          </div>
        </div>

        {/* Scroll indicator */}
        <div className="flex justify-center mt-16">
          <a href="#stats" className="flex flex-col items-center gap-2 text-slate-400 hover:text-sky-400 transition-colors animate-bounce">
            <span className="text-xs">Scroll to explore</span>
            <ArrowDown size={18} />
          </a>
        </div>
      </div>
    </section>
  );
}
