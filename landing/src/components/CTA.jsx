export default function CTA() {
  return (
    <section id="download" className="py-24 relative overflow-hidden">
      <div className="absolute inset-0 hero-gradient" />
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/4 w-64 h-64 bg-sky-400/20 rounded-full blur-3xl" />
        <div className="absolute bottom-0 right-1/4 w-64 h-64 bg-cyan-400/20 rounded-full blur-3xl" />
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center relative z-10">
        <div className="text-6xl mb-6">🏥</div>
        <h2 className="text-4xl md:text-5xl font-extrabold text-white mb-6 leading-tight">
          Ready to Skip the Queue?
        </h2>
        <p className="text-lg text-slate-300 mb-10 max-w-xl mx-auto">
          Join thousands of patients who've already made clinic visits stress-free.
          Download QLess for free today.
        </p>

        <div className="flex flex-col sm:flex-row gap-4 justify-center mb-12">
          <a
            href="#"
            className="flex items-center justify-center gap-3 bg-white text-gray-900 font-bold px-7 py-4 rounded-2xl hover:bg-gray-100 transition-all hover:-translate-y-1 shadow-2xl"
          >
            <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" alt="Play Store" className="h-7" />
            <div className="text-left">
              <div className="text-xs text-gray-500">Get it on</div>
              <div className="text-base font-bold">Google Play</div>
            </div>
          </a>
          <a
            href="#"
            className="flex items-center justify-center gap-3 bg-sky-500 border-2 border-sky-400 text-white font-bold px-7 py-4 rounded-2xl hover:bg-sky-600 transition-all hover:-translate-y-1 shadow-2xl"
          >
            <svg className="w-8 h-8" viewBox="0 0 814 1000" fill="currentColor">
              <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-57.8-155.5-127.4C46 405.8 8 279.7 8 160C8 67.7 62.4 10.1 145.1 10.1c57.8 0 100.5 37.8 145.8 37.8 43.1 0 91.9-39.5 162.7-39.5 62.2 0 115.2 39.1 148.8 100.4zm-188.4-90.5c-28.4 34.5-76 61.9-123.6 61.9-5.2 0-10.3-.3-15.5-1 1.3-51.7 27.2-99.7 57.8-131.1 33.6-35.5 87.4-64 134.4-66.1 1.3 53.2-17.9 102.8-53.1 136.3z"/>
            </svg>
            <div className="text-left">
              <div className="text-xs text-sky-200">Download on the</div>
              <div className="text-base font-bold">App Store</div>
            </div>
          </a>
        </div>

        <div className="flex flex-wrap justify-center gap-6">
          {['Free Download', 'No Credit Card', 'Works on Android & iOS'].map((item) => (
            <div key={item} className="flex items-center gap-2 text-slate-300 text-sm">
              <div className="w-4 h-4 rounded-full bg-sky-400 flex items-center justify-center">
                <svg width="8" height="6" viewBox="0 0 8 6" fill="none">
                  <path d="M1 3L3 5L7 1" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </div>
              {item}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
