import { User, Stethoscope, ClipboardList } from 'lucide-react';

const audiences = [
  {
    icon: User,
    title: 'Patients',
    emoji: '🧑‍⚕️',
    color: 'from-sky-500 to-cyan-400',
    bg: 'bg-gradient-to-br from-sky-50 to-cyan-50',
    border: 'border-sky-200',
    badge: 'For You',
    badgeColor: 'bg-sky-100 text-sky-700',
    points: [
      'Skip physical queues',
      'Real-time wait updates',
      'Manage family members',
      'Digital prescriptions',
      'Push alerts for your turn',
    ],
  },
  {
    icon: Stethoscope,
    title: 'Doctors',
    emoji: '👨‍⚕️',
    color: 'from-violet-500 to-purple-400',
    bg: 'bg-gradient-to-br from-violet-50 to-purple-50',
    border: 'border-violet-200',
    badge: 'For You',
    badgeColor: 'bg-violet-100 text-violet-700',
    points: [
      'Live patient queue view',
      'Issue digital prescriptions',
      'Reduce no-shows',
      'Consult history access',
      'Reduce waiting room chaos',
    ],
  },
  {
    icon: ClipboardList,
    title: 'Receptionists',
    emoji: '💼',
    color: 'from-emerald-500 to-teal-400',
    bg: 'bg-gradient-to-br from-emerald-50 to-teal-50',
    border: 'border-emerald-200',
    badge: 'For You',
    badgeColor: 'bg-emerald-100 text-emerald-700',
    points: [
      'Queue management dashboard',
      'Walk-in patient registration',
      'Offline mode support',
      'Token assignment control',
      'Appointment scheduling',
    ],
  },
];

export default function ForWhom() {
  return (
    <section id="for-whom" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="text-sky-500 font-semibold text-sm uppercase tracking-wider">Built For Everyone</span>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mt-2 mb-4">
            QLess Works for the Whole Clinic
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto">
            Whether you're a patient, doctor, or receptionist — QLess is designed around your workflow.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8">
          {audiences.map((a) => (
            <div
              key={a.title}
              className={`${a.bg} ${a.border} border-2 rounded-3xl p-8 card-hover relative overflow-hidden`}
            >
              <div className="absolute top-0 right-0 w-32 h-32 opacity-5">
                <div className={`w-full h-full bg-gradient-to-br ${a.color} rounded-full`} />
              </div>

              <div className="flex items-center justify-between mb-6">
                <div className={`w-14 h-14 bg-gradient-to-br ${a.color} rounded-2xl flex items-center justify-center shadow-lg`}>
                  <span className="text-2xl">{a.emoji}</span>
                </div>
                <span className={`text-xs font-bold px-3 py-1 rounded-full ${a.badgeColor}`}>{a.badge}</span>
              </div>

              <h3 className="text-2xl font-bold text-gray-900 mb-5">{a.title}</h3>

              <ul className="space-y-3">
                {a.points.map((p) => (
                  <li key={p} className="flex items-center gap-3 text-gray-700 text-sm">
                    <div className={`w-5 h-5 bg-gradient-to-br ${a.color} rounded-full flex items-center justify-center flex-shrink-0`}>
                      <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
                        <path d="M1 4L3.5 6.5L9 1" stroke="white" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    </div>
                    {p}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
