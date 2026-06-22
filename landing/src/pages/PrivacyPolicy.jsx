import { Link } from 'react-router-dom';
import { ArrowLeft, Shield } from 'lucide-react';

export default function PrivacyPolicy() {
  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-4xl mx-auto px-4 py-12">
        <Link to="/" className="inline-flex items-center gap-2 text-sky-500 font-medium hover:text-sky-600 mb-8 transition-colors">
          <ArrowLeft size={16} /> Back to Home
        </Link>

        <div className="bg-white rounded-3xl shadow-sm border border-gray-100 p-8 md:p-12">
          <div className="flex items-center gap-4 mb-8">
            <div className="w-12 h-12 bg-sky-100 rounded-2xl flex items-center justify-center">
              <Shield size={24} className="text-sky-500" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Privacy Policy</h1>
              <p className="text-gray-500 text-sm mt-1">Last updated: June 2025</p>
            </div>
          </div>

          <div className="prose prose-gray max-w-none space-y-8 text-gray-700">
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">1. Information We Collect</h2>
              <p className="text-sm leading-relaxed">
                QLess collects the following information when you use our app:
              </p>
              <ul className="list-disc list-inside text-sm space-y-1 mt-2 text-gray-600">
                <li>Name, phone number, and email address for registration</li>
                <li>Family member details you add to your profile</li>
                <li>Clinic visits and appointment history</li>
                <li>Device information and push notification tokens (FCM)</li>
                <li>Location data (only when accessing nearby clinic feature)</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">2. How We Use Your Information</h2>
              <ul className="list-disc list-inside text-sm space-y-1 text-gray-600">
                <li>To manage your clinic queue tokens and appointments</li>
                <li>To send push notifications about your queue status</li>
                <li>To provide digital prescriptions from your doctor</li>
                <li>To improve app performance and user experience</li>
                <li>To communicate important service updates</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">3. Data Sharing</h2>
              <p className="text-sm leading-relaxed text-gray-600">
                We do not sell or rent your personal data to third parties. We only share data with:
              </p>
              <ul className="list-disc list-inside text-sm space-y-1 mt-2 text-gray-600">
                <li>The clinic/doctor you are booking an appointment with</li>
                <li>Firebase (Google) for push notifications</li>
                <li>Our hosting infrastructure providers</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">4. Data Security</h2>
              <p className="text-sm leading-relaxed text-gray-600">
                We use industry-standard encryption (HTTPS/TLS) for all data in transit.
                Sensitive data like prescription information is stored encrypted at rest.
                We do not store passwords in plain text.
              </p>
            </section>

            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">5. Your Rights</h2>
              <ul className="list-disc list-inside text-sm space-y-1 text-gray-600">
                <li>Access: You can view all your data within the app</li>
                <li>Delete: You can delete your account at any time (see our Delete Account page)</li>
                <li>Export: Contact us to request a copy of your data</li>
                <li>Opt-out: You can disable notifications in app settings</li>
              </ul>
            </section>

            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">6. Contact Us</h2>
              <p className="text-sm leading-relaxed text-gray-600">
                For privacy concerns, email us at{' '}
                <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">
                  support@vengurlatech.com
                </a>
              </p>
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
