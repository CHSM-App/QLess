import { Activity, Mail, Phone, MapPin } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function Footer() {
  return (
    <footer className="bg-slate-900 text-slate-400">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <div className="grid md:grid-cols-4 gap-10 mb-12">
          {/* Brand */}
          <div className="md:col-span-1">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-9 h-9 bg-gradient-to-br from-sky-500 to-cyan-400 rounded-xl flex items-center justify-center">
                <Activity size={18} className="text-white" />
              </div>
              <span className="text-xl font-bold text-white">Q<span className="text-sky-400">Less</span></span>
            </div>
            <p className="text-sm leading-relaxed mb-5">
              Making clinic visits stress-free for patients, doctors, and receptionists across India.
            </p>
            <div className="flex gap-3">
              {['𝕏', 'in', 'f', '▶'].map((icon, i) => (
                <a key={i} href="#" className="w-9 h-9 bg-slate-800 hover:bg-sky-500 text-slate-400 hover:text-white rounded-lg flex items-center justify-center text-sm font-bold transition-colors">
                  {icon}
                </a>
              ))}
            </div>
          </div>

          {/* Product */}
          <div>
            <h4 className="text-white font-semibold mb-4 text-sm uppercase tracking-wider">Product</h4>
            <ul className="space-y-2.5 text-sm">
              {['Features', 'How It Works', 'For Patients', 'For Doctors', 'For Clinics'].map((l) => (
                <li key={l}>
                  <a href="#features" className="hover:text-sky-400 transition-colors">{l}</a>
                </li>
              ))}
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="text-white font-semibold mb-4 text-sm uppercase tracking-wider">Company</h4>
            <ul className="space-y-2.5 text-sm">
              <li><Link to="/privacy-policy" className="hover:text-sky-400 transition-colors">Privacy Policy</Link></li>
              <li><Link to="/help-center" className="hover:text-sky-400 transition-colors">Help Center</Link></li>
              <li><Link to="/delete-account" className="hover:text-sky-400 transition-colors">Delete Account</Link></li>
              <li><a href="#" className="hover:text-sky-400 transition-colors">Terms of Service</a></li>
              <li><a href="#" className="hover:text-sky-400 transition-colors">About Us</a></li>
            </ul>
          </div>

          {/* Contact */}
          <div>
            <h4 className="text-white font-semibold mb-4 text-sm uppercase tracking-wider">Contact</h4>
            <ul className="space-y-3 text-sm">
              <li className="flex items-center gap-2">
                <Mail size={14} className="text-sky-400 flex-shrink-0" />
                <a href="mailto:support@vengurlatech.com" className="hover:text-sky-400 transition-colors">support@vengurlatech.com</a>
              </li>
              <li className="flex items-center gap-2">
                <Phone size={14} className="text-sky-400 flex-shrink-0" />
                <span>+91 9422229951</span>
              </li>
              <li className="flex items-start gap-2">
                <MapPin size={14} className="text-sky-400 flex-shrink-0 mt-0.5" />
                <span>Vengurla Tech, Maharashtra, India</span>
              </li>
            </ul>
          </div>
        </div>

        <div className="border-t border-slate-800 pt-8 flex flex-col md:flex-row items-center justify-between gap-4 text-sm">
          <p>© {new Date().getFullYear()} QLess by VengUrlaTech. All rights reserved.</p>
          <p className="text-slate-600">Made with ❤️ in Maharashtra, India</p>
        </div>
      </div>
    </footer>
  );
}
