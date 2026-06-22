import { Smartphone, Bell, Clock, Users, ShieldCheck, BarChart2, Search, CalendarCheck, Printer } from 'lucide-react';

const features = [
  {
    icon: Smartphone,
    title: 'Virtual Queue Booking',
    desc: 'Book your clinic token instantly from your phone. No physical waiting required.',
    color: 'from-sky-400 to-sky-600',
    bg: 'bg-sky-50',
    border: 'border-sky-100',
  },
  {
    icon: Bell,
    title: 'Real-Time Notifications',
    desc: 'Get push alerts when your turn is approaching — arrive at the clinic exactly on time.',
    color: 'from-violet-400 to-violet-600',
    bg: 'bg-violet-50',
    border: 'border-violet-100',
  },
  {
    icon: Clock,
    title: 'Live Wait Time Tracker',
    desc: 'See live queue status and estimated wait times updated every minute.',
    color: 'from-emerald-400 to-emerald-600',
    bg: 'bg-emerald-50',
    border: 'border-emerald-100',
  },
  {
    icon: Search,
    title: 'Find & Book Doctors',
    desc: 'Search and explore doctors near you by specialty or clinic. Book appointments directly from the app.',
    color: 'from-indigo-400 to-indigo-600',
    bg: 'bg-indigo-50',
    border: 'border-indigo-100',
  },
  {
    icon: Users,
    title: 'Family Member Profiles',
    desc: 'Manage health visits for your entire family — parents, spouse, kids — from one account.',
    color: 'from-amber-400 to-amber-600',
    bg: 'bg-amber-50',
    border: 'border-amber-100',
  },
  {
    icon: ShieldCheck,
    title: 'Digital Prescriptions',
    desc: 'View, download, and print your prescriptions digitally after every consultation.',
    color: 'from-rose-400 to-rose-600',
    bg: 'bg-rose-50',
    border: 'border-rose-100',
  },
  {
    icon: CalendarCheck,
    title: 'Doctor Availability & Leave',
    desc: 'Doctors can manage their availability schedule and mark leave days — patients always see accurate slots.',
    color: 'from-teal-400 to-teal-600',
    bg: 'bg-teal-50',
    border: 'border-teal-100',
  },
  {
    icon: Printer,
    title: 'Print Prescriptions',
    desc: 'Print or share prescriptions as a PDF directly from the app — no handwritten slips needed.',
    color: 'from-orange-400 to-orange-600',
    bg: 'bg-orange-50',
    border: 'border-orange-100',
  },
  {
    icon: BarChart2,
    title: 'Receptionist Dashboard',
    desc: 'Receptionists get a live dashboard to manage walk-in patients, queue tokens, and appointments — even offline.',
    color: 'from-cyan-400 to-cyan-600',
    bg: 'bg-cyan-50',
    border: 'border-cyan-100',
  },
];

export default function Features() {
  return (
    <section id="features" className="py-24 bg-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="text-sky-500 font-semibold text-sm uppercase tracking-wider">Why QLess?</span>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mt-2 mb-4">
            Everything You Need for Stress-Free Clinic Visits
          </h2>
          <p className="text-gray-500 max-w-2xl mx-auto text-lg">
            From booking to prescription — QLess handles your entire clinic journey, digitally.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f) => (
            <div
              key={f.title}
              className={`${f.bg} ${f.border} border rounded-2xl p-6 card-hover group`}
            >
              <div className={`w-12 h-12 bg-gradient-to-br ${f.color} rounded-xl flex items-center justify-center mb-5 shadow-md group-hover:scale-110 transition-transform`}>
                <f.icon size={22} className="text-white" />
              </div>
              <h3 className="text-lg font-bold text-gray-900 mb-2">{f.title}</h3>
              <p className="text-gray-600 text-sm leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
