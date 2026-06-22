import { useEffect, useRef, useState } from 'react';
import { Users, Clock, Hospital, Star } from 'lucide-react';

const stats = [
  { icon: Users, value: '10,000+', label: 'Patients Served', color: 'text-sky-500', bg: 'bg-sky-50' },
  { icon: Clock, value: '45 min', label: 'Avg Wait Time Saved', color: 'text-emerald-500', bg: 'bg-emerald-50' },
  { icon: Hospital, value: '50+', label: 'Clinics Onboarded', color: 'text-violet-500', bg: 'bg-violet-50' },
  { icon: Star, value: '4.8★', label: 'App Rating', color: 'text-amber-500', bg: 'bg-amber-50' },
];

export default function Stats() {
  const ref = useRef(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setVisible(true); },
      { threshold: 0.2 }
    );
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);

  return (
    <section id="stats" ref={ref} className="py-20 bg-gradient-to-b from-slate-50 to-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-14">
          <span className="text-sky-500 font-semibold text-sm uppercase tracking-wider">By The Numbers</span>
          <h2 className="text-3xl md:text-4xl font-bold text-gray-900 mt-2">
            Trusted by Patients & Doctors Across India
          </h2>
        </div>

        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
          {stats.map((s, i) => (
            <div
              key={s.label}
              className={`${s.bg} rounded-2xl p-6 text-center card-hover border border-white shadow-sm
                transition-all duration-500 ${visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'}`}
              style={{ transitionDelay: `${i * 100}ms` }}
            >
              <div className={`w-12 h-12 rounded-xl ${s.bg} border-2 border-white shadow-md flex items-center justify-center mx-auto mb-4`}>
                <s.icon size={22} className={s.color} />
              </div>
              <div className={`text-3xl font-extrabold ${s.color} mb-1`}>{s.value}</div>
              <div className="text-gray-600 text-sm font-medium">{s.label}</div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
