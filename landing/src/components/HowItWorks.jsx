import { Download, QrCode, BellRing } from 'lucide-react';

const steps = [
  {
    icon: Download,
    step: '01',
    title: 'Download & Register',
    desc: 'Install QLess from Play Store or App Store. Sign up in under 60 seconds — no paperwork needed.',
    color: 'bg-sky-500',
    line: true,
  },
  {
    icon: QrCode,
    step: '02',
    title: 'Book Your Token',
    desc: 'Select your clinic and doctor, choose a slot or join live queue. Your token is confirmed instantly.',
    color: 'bg-violet-500',
    line: true,
  },
  {
    icon: BellRing,
    step: '03',
    title: 'Get Notified & Arrive',
    desc: "QLess sends you a push notification 5 minutes before your turn. Walk in — no waiting in line.",
    color: 'bg-emerald-500',
    line: false,
  },
];

export default function HowItWorks() {
  return (
    <section id="how-it-works" className="py-24 bg-gradient-to-b from-slate-900 to-sky-950 relative overflow-hidden">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 right-0 w-80 h-80 bg-sky-500/10 rounded-full blur-3xl" />
        <div className="absolute bottom-0 left-0 w-80 h-80 bg-violet-500/10 rounded-full blur-3xl" />
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 relative z-10">
        <div className="text-center mb-16">
          <span className="text-sky-400 font-semibold text-sm uppercase tracking-wider">Simple Process</span>
          <h2 className="text-3xl md:text-4xl font-bold text-white mt-2 mb-4">
            Get Started in 3 Easy Steps
          </h2>
          <p className="text-slate-400 max-w-xl mx-auto">
            No complicated setup. No learning curve. Just download and you're ready to skip the queue.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8 relative">
          {/* Connecting line on desktop */}
          <div className="hidden md:block absolute top-16 left-1/3 right-1/3 h-0.5 bg-gradient-to-r from-sky-500 via-violet-500 to-emerald-500" />

          {steps.map((s) => (
            <div key={s.step} className="text-center group">
              <div className="relative inline-block mb-6">
                <div className={`w-16 h-16 ${s.color} rounded-2xl flex items-center justify-center mx-auto shadow-lg group-hover:scale-110 transition-transform duration-300`}>
                  <s.icon size={28} className="text-white" />
                </div>
                <div className="absolute -top-2 -right-2 w-7 h-7 bg-white rounded-full flex items-center justify-center shadow-md">
                  <span className="text-xs font-black text-gray-800">{s.step}</span>
                </div>
              </div>
              <h3 className="text-xl font-bold text-white mb-3">{s.title}</h3>
              <p className="text-slate-400 text-sm leading-relaxed max-w-xs mx-auto">{s.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
