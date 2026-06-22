import { Star, Quote } from 'lucide-react';

const testimonials = [
  {
    name: 'Sunita Patil',
    role: 'Patient, Pune',
    avatar: '🧕',
    rating: 5,
    text: 'QLess saved me over an hour of waiting! I book my token from home and arrive at the clinic exactly on time. Truly the best app for clinic visits.',
  },
  {
    name: 'Dr. Rajesh Kulkarni',
    role: 'General Physician, Nashik',
    avatar: '👨‍⚕️',
    rating: 5,
    text: 'My waiting room is no longer chaotic. Patients arrive on time, and I can focus on consultations rather than crowd management.',
  },
  {
    name: 'Priya Deshmukh',
    role: 'Receptionist, Mumbai',
    avatar: '💁‍♀️',
    rating: 5,
    text: 'Managing the queue has become so easy with QLess. Walk-in patients can also be added instantly. The best app for clinic receptionists!',
  },
];

export default function Testimonials() {
  return (
    <section className="py-24 bg-gradient-to-b from-slate-50 to-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-16">
          <span className="text-sky-500 font-semibold text-sm uppercase tracking-wider">Real Stories</span>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mt-2">
            Patients & Doctors Love QLess
          </h2>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {testimonials.map((t) => (
            <div key={t.name} className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 card-hover">
              <div className="flex items-start justify-between mb-4">
                <div className="flex gap-0.5">
                  {Array.from({ length: t.rating }).map((_, i) => (
                    <Star key={i} size={14} className="text-amber-400 fill-amber-400" />
                  ))}
                </div>
                <Quote size={28} className="text-sky-100" />
              </div>
              <p className="text-gray-600 text-sm leading-relaxed mb-6 italic">"{t.text}"</p>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-sky-50 rounded-full flex items-center justify-center text-xl">
                  {t.avatar}
                </div>
                <div>
                  <div className="font-semibold text-gray-900 text-sm">{t.name}</div>
                  <div className="text-gray-500 text-xs">{t.role}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
