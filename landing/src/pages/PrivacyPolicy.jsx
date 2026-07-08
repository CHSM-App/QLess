import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Activity, ArrowLeft, ShieldCheck, BookOpen, Info, Database, HeartPulse,
  Target, Share2, Lock, UserCheck, FileCheck, Baby, Clock, Link2,
  RefreshCw, Mail, ChevronRight,
} from 'lucide-react';

const SECTIONS = [
  { id: 'definitions',  n: '01', icon: BookOpen,    title: 'Definitions' },
  { id: 'overview',     n: '02', icon: Info,        title: 'Overview & Applicability' },
  { id: 'collect',      n: '03', icon: Database,     title: 'Information We Collect' },
  { id: 'sensitive',    n: '04', icon: HeartPulse,  title: 'Sensitive Personal Data' },
  { id: 'purposes',     n: '05', icon: Target,      title: 'Purposes of Processing' },
  { id: 'sharing',      n: '06', icon: Share2,      title: 'Disclosure & Sharing' },
  { id: 'security',     n: '07', icon: Lock,        title: 'Data Storage & Security' },
  { id: 'rights',       n: '08', icon: UserCheck,   title: 'Your Rights' },
  { id: 'consent',      n: '09', icon: FileCheck,   title: 'Consent & Its Management' },
  { id: 'children',     n: '10', icon: Baby,        title: "Children's Privacy" },
  { id: 'retention',    n: '11', icon: Clock,       title: 'Data Retention' },
  { id: 'deletion-request', n: '11A', icon: FileCheck, title: 'How to Request Data Deletion' },
  { id: 'thirdparty',   n: '12', icon: Link2,       title: 'Third-Party Links & Services' },
  { id: 'changes',      n: '13', icon: RefreshCw,   title: 'Changes to This Policy' },
  { id: 'contact',      n: '14', icon: Mail,        title: 'Contact & Grievance Redressal' },
];

function Th({ children }) {
  return <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wide px-4 py-3 border-b border-gray-200">{children}</th>;
}
function Td({ children, strong }) {
  return <td className={`text-sm px-4 py-3 border-b border-gray-100 align-top ${strong ? 'font-semibold text-gray-800' : 'text-gray-600'}`}>{children}</td>;
}

function Section({ id, n, icon: Icon, title, children }) {
  return (
    <section id={id} className="scroll-mt-28 bg-white rounded-3xl shadow-sm border border-gray-100 p-7 md:p-10">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-11 h-11 rounded-2xl bg-sky-50 flex items-center justify-center flex-shrink-0">
          <Icon size={20} className="text-sky-500" />
        </div>
        <div>
          <span className="text-xs font-bold tracking-widest text-sky-400">{n}</span>
          <h2 className="text-xl md:text-2xl font-bold text-gray-900 leading-tight">{title}</h2>
        </div>
      </div>
      <div className="space-y-4 text-sm leading-relaxed text-gray-600">{children}</div>
    </section>
  );
}

function List({ items }) {
  return (
    <ul className="space-y-2">
      {items.map((it, i) => (
        <li key={i} className="flex items-start gap-2.5">
          <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-sky-400 flex-shrink-0" />
          <span>{it}</span>
        </li>
      ))}
    </ul>
  );
}

export default function PrivacyPolicy() {
  const [active, setActive] = useState('definitions');

  useEffect(() => {
    window.scrollTo(0, 0);
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => { if (e.isIntersecting) setActive(e.target.id); });
      },
      { rootMargin: '-30% 0px -60% 0px' }
    );
    SECTIONS.forEach((s) => {
      const el = document.getElementById(s.id);
      if (el) observer.observe(el);
    });
    return () => observer.disconnect();
  }, []);

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Top bar */}
      <div className="bg-slate-900 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
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
      <div className="relative overflow-hidden bg-gradient-to-br from-slate-900 to-slate-800 px-6 py-16 text-center">
        <div className="absolute inset-0 pointer-events-none opacity-[0.15]" style={{
          backgroundImage: 'radial-gradient(circle at 80% 30%, #38bdf8 0%, transparent 45%), radial-gradient(circle at 15% 80%, #22d3ee 0%, transparent 40%)',
        }} />
        <div className="relative">
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full text-xs font-semibold mb-5 bg-sky-500/15 text-sky-300">
            <ShieldCheck size={12} />
            Data Protection &amp; Privacy
          </div>
          <h1 className="text-4xl md:text-5xl font-extrabold text-white mb-4">Privacy Policy</h1>
          <p className="text-white/50 max-w-xl mx-auto text-sm leading-relaxed mb-7">
            How Vengurla Tech Private Limited collects, uses, and protects your personal and health
            information across the QLess platform.
          </p>
          <div className="flex flex-wrap justify-center gap-2 text-xs">
            {[
              ['Effective Date', 'July 8, 2026'],
              ['Version', '2.0'],
              ['Jurisdiction', 'India (DPDP Act, 2023 & IT Act, 2000)'],
            ].map(([label, val]) => (
              <span key={label} className="px-3 py-1.5 rounded-full bg-white/10 text-white/70 border border-white/10">
                <span className="text-white/40">{label}:</span> <span className="font-semibold text-white/90">{val}</span>
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 md:px-6 py-12 grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-8">
        {/* Sidebar TOC */}
        <aside className="hidden lg:block">
          <div className="sticky top-8 bg-white rounded-2xl border border-gray-100 shadow-sm p-4">
            <p className="text-xs font-bold text-gray-400 uppercase tracking-wide px-2 mb-2">On this page</p>
            <nav className="space-y-0.5">
              {SECTIONS.map((s) => (
                <a
                  key={s.id}
                  href={`#${s.id}`}
                  className={`flex items-center gap-2 text-sm px-2.5 py-2 rounded-xl transition-colors ${
                    active === s.id ? 'bg-sky-50 text-sky-600 font-semibold' : 'text-gray-500 hover:bg-gray-50 hover:text-gray-800'
                  }`}
                >
                  <span className="text-[10px] font-bold w-5 text-gray-300">{s.n}</span>
                  {s.title}
                </a>
              ))}
            </nav>
          </div>
        </aside>

        {/* Mobile TOC */}
        <div className="lg:hidden -mx-4 px-4 overflow-x-auto">
          <div className="flex gap-2 pb-2 w-max">
            {SECTIONS.map((s) => (
              <a
                key={s.id}
                href={`#${s.id}`}
                className="flex items-center gap-1 text-xs font-medium px-3 py-1.5 rounded-full bg-white border border-gray-200 text-gray-600 whitespace-nowrap"
              >
                {s.title} <ChevronRight size={12} />
              </a>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="space-y-6">
          <p className="text-sm leading-relaxed text-gray-600 bg-white rounded-3xl shadow-sm border border-gray-100 p-7 md:p-10">
            <strong className="text-gray-900">IMPORTANT — please read carefully.</strong> By downloading,
            installing, accessing, or using the QLess application or any associated service, you confirm that
            you have read, understood, and agree to be bound by this Privacy Policy. QLess is a digital
            healthcare platform operated by <strong className="text-gray-900">Vengurla Tech Private Limited</strong>{' '}
            ("Company", "we", "us") that connects Patients with verified Doctors and clinics for appointment
            booking, live queue management, and digital prescriptions.
          </p>

          <Section id="definitions" n="01" icon={BookOpen} title="Definitions">
            <p>These definitions align with the Digital Personal Data Protection Act, 2023 ("DPDP Act") and the IT (SPDI) Rules, 2011.</p>
            <div className="grid sm:grid-cols-2 gap-3 mt-2">
              {[
                ['Company / We / Us', 'Vengurla Tech Private Limited, operating the QLess platform.'],
                ['Platform / Services', 'The QLess mobile application, associated APIs, and related services.'],
                ['User / You', 'Any individual using the Platform — Patients, Doctors, or Clinic staff.'],
                ['Patient', 'A User who books appointments or joins queues for medical consultation.'],
                ['Doctor / Practitioner', 'A registered medical professional managing appointments and queues via QLess.'],
                ['Personal Data', 'Any data relating to an identifiable individual, as defined under the DPDP Act.'],
                ['Sensitive Personal Data (SPDI)', 'Health records, medical history, and similar data under Rule 3 of the SPI Rules.'],
                ['Data Fiduciary', 'Vengurla Tech Private Limited, which determines the purpose and means of processing.'],
                ['Data Principal', 'The individual to whom the Personal Data relates — i.e., you.'],
              ].map(([t, d]) => (
                <div key={t} className="rounded-xl bg-gray-50 border border-gray-100 p-3.5">
                  <p className="text-xs font-bold text-gray-800 mb-1">{t}</p>
                  <p className="text-xs text-gray-500 leading-relaxed">{d}</p>
                </div>
              ))}
            </div>
          </Section>

          <Section id="overview" n="02" icon={Info} title="Overview & Applicability">
            <p>
              This Privacy Policy applies to all Users of the QLess mobile application, including registered
              Doctors, Clinic/receptionist staff, and Patients. It is published in compliance with the
              Information Technology Act, 2000, the IT (SPDI) Rules, 2011, and the Digital Personal Data
              Protection Act, 2023.
            </p>
            <p><strong className="text-gray-800">Scope</strong> — this policy covers the QLess mobile app, all
              communications with you (email, WhatsApp OTP, in-app messaging), data collected from every role
              on the Platform, and data processed by third-party service providers on our behalf.</p>
            <p><strong className="text-gray-800">Booking on behalf of another</strong> — if you add a family
              member profile or otherwise use the Services on someone else's behalf, you confirm you are
              authorised to consent to this policy and to our processing of that person's data on their behalf.</p>
          </Section>

          <Section id="collect" n="03" icon={Database} title="Information We Collect">
            <p><strong className="text-gray-800">A. Information you provide directly</strong></p>
            <div className="overflow-x-auto rounded-xl border border-gray-100">
              <table className="w-full border-collapse">
                <thead><tr><Th>Category</Th><Th>Specific Data Points</Th><Th>Who</Th><Th>Mandatory?</Th></tr></thead>
                <tbody>
                  <tr><Td strong>Identity</Td><Td>Full name, gender, date of birth, profile photograph</Td><Td>All Users</Td><Td>Yes</Td></tr>
                  <tr><Td strong>Contact</Td><Td>Mobile number, email address</Td><Td>All Users</Td><Td>Mobile mandatory</Td></tr>
                  <tr><Td strong>Health / Medical</Td><Td>Symptoms, medical history, blood group, allergies, appointment notes, prescriptions</Td><Td>Patients</Td><Td>Optional, patient-controlled</Td></tr>
                  <tr><Td strong>Family Members</Td><Td>Name, relation, and demographic details of dependents added to your account</Td><Td>Patients</Td><Td>Optional</Td></tr>
                  <tr><Td strong>Professional Credentials</Td><Td>Registration number, qualification, specialization, experience</Td><Td>Doctors</Td><Td>Yes</Td></tr>
                  <tr><Td strong>Clinic Details</Td><Td>Clinic name, address, GPS coordinates, contact info, consultation fee</Td><Td>Doctors</Td><Td>Yes</Td></tr>
                  <tr><Td strong>Appointment Records</Td><Td>Booking history, queue position, visit dates, status</Td><Td>All Users</Td><Td>Generated automatically</Td></tr>
                </tbody>
              </table>
            </div>
            <p className="pt-2"><strong className="text-gray-800">B. Information collected automatically</strong></p>
            <List items={[
              'Device type, model, operating system, and app version',
              'Firebase Cloud Messaging (FCM) push notification token, used for real-time queue and appointment alerts',
              'Precise GPS location — only when you actively use the "nearby doctors" search or map-based clinic picker, and only after you grant location permission',
              'Login timestamps and session activity',
              'Crash and diagnostic logs used to fix application errors',
            ]} />
            <p className="pt-2"><strong className="text-gray-800">C. Information from third parties</strong></p>
            <List items={[
              'OTP delivery confirmation from our WhatsApp Business messaging provider (used for login instead of passwords)',
              'Credential verification data used to confirm a Doctor\'s medical registration, where applicable',
            ]} />
            <p className="pt-2">
              We do not collect payment card numbers, UPI IDs, or bank account details — QLess does not
              currently process payments in-app. If payment features are introduced, this Policy will be
              updated beforehand. Where provision of mandatory data is refused, we may be unable to deliver
              the corresponding Service.
            </p>
          </Section>

          <Section id="sensitive" n="04" icon={HeartPulse} title="Sensitive Personal Data">
            <p>
              Health and medical information constitutes Sensitive Personal Data or Information (SPDI) under
              Rule 3 of the SPI Rules, 2011, and Special Category Personal Data under the DPDP Act, 2023. We
              apply heightened protection to:
            </p>
            <List items={[
              'Medical history, diagnoses, and treatment notes shared by Patients',
              'Symptoms entered during appointment booking',
              'Digital prescriptions and clinical notes attached by Doctors',
              'Blood group and known allergies or medical conditions',
            ]} />
            <p><strong className="text-gray-800">Heightened protections</strong></p>
            <List items={[
              'SPDI is encrypted both in transit and at rest',
              'SPDI shared between a Patient and Doctor is accessible only to the specific Doctor with whom an appointment has been booked — it is never visible to other Doctors on the Platform',
              'We do not use SPDI for profiling, advertising, or any secondary commercial purpose',
              'You may withdraw consent for SPDI collection at any time by contacting us — see Section 09',
            ]} />
          </Section>

          <Section id="purposes" n="05" icon={Target} title="Purposes of Processing">
            <p>We use Personal Data only for the specific purposes below, and never sell it to third parties, advertisers, or data brokers.</p>
            <p><strong className="text-gray-800">Core service delivery</strong></p>
            <List items={[
              'Creating and authenticating your account via mobile number and one-time password (QLess does not use passwords)',
              'Connecting Patients with verified Doctors for appointment booking and live, real-time queue management',
              'Processing bookings, cancellations, reschedules, and status updates',
              'Displaying real-time queue position, estimated wait times, and Doctor availability',
              'Showing nearby clinics, map location, and directions when you use location-based search',
              'Letting Doctors and clinic/receptionist staff view the queue, patient history, and prescriptions for patients who have booked with them',
              'Maintaining an offline, on-device copy of your recent appointments and queue data so the app keeps working on a poor connection, syncing automatically once you\'re back online',
            ]} />
            <p><strong className="text-gray-800">Communications</strong></p>
            <List items={[
              'Sending push notifications (via FCM) for appointment confirmations, reminders, cancellations, and queue updates',
              'Sending WhatsApp OTP messages to authenticate your identity at login and for sensitive account actions',
              'Responding to your support inquiries and grievances',
            ]} />
            <p><strong className="text-gray-800">Platform improvement</strong></p>
            <List items={[
              'Analysing app performance, diagnosing crashes, and monitoring system health',
              'Understanding aggregate, anonymised usage patterns to improve features',
            ]} />
          </Section>

          <Section id="sharing" n="06" icon={Share2} title="Disclosure & Sharing">
            <p>We do not sell, rent, or trade your Personal Data. Sharing happens only in the circumstances below.</p>
            <p><strong className="text-gray-800">Between Patients and Doctors</strong></p>
            <List items={[
              'Patient → Doctor: name, mobile number, and any health notes/symptoms you voluntarily add to a booking',
              'Doctor → Patient: name, photo, specialization, qualification, clinic name, address, schedule, and consultation fee',
              'A Doctor cannot access records of a Patient who has not booked an appointment with them',
            ]} />
            <p className="pt-1"><strong className="text-gray-800">Service providers</strong></p>
            <div className="overflow-x-auto rounded-xl border border-gray-100">
              <table className="w-full border-collapse">
                <thead><tr><Th>Processor</Th><Th>Purpose</Th><Th>Data Shared</Th><Th>Location</Th></tr></thead>
                <tbody>
                  <tr><Td strong>Firebase (Google LLC)</Td><Td>Push notification delivery</Td><Td>FCM device token</Td><Td>USA / Global</Td></tr>
                  <tr><Td strong>WhatsApp Business API provider</Td><Td>OTP delivery</Td><Td>Mobile number only</Td><Td>India</Td></tr>
                  <tr><Td strong>Cloud infrastructure provider</Td><Td>Server hosting, encrypted database storage</Td><Td>All Platform data (encrypted)</Td><Td>India</Td></tr>
                  <tr><Td strong>Google Maps Platform</Td><Td>Clinic location display, map-based picker</Td><Td>Location coordinates (when map feature used)</Td><Td>USA / Global</Td></tr>
                </tbody>
              </table>
            </div>
            <p className="pt-2"><strong className="text-gray-800">Legal disclosures</strong> — we may disclose data without consent when required by a court order, lawful government request, to protect the safety of Users or the public, or to enforce our Terms of Use.</p>
            <p><strong className="text-gray-800">Business transfers</strong> — in a merger, acquisition, or asset sale, your data may transfer to the successor entity; we will notify you in-app and by email beforehand and give you the option to request deletion.</p>
          </Section>

          <Section id="security" n="07" icon={Lock} title="Data Storage & Security">
            <p><strong className="text-gray-800">Data location</strong> — Personal Data is stored on secure servers located within India. Anonymised analytics processed via Firebase may reside on Google's global infrastructure.</p>
            <p><strong className="text-gray-800">Technical measures</strong></p>
            <List items={[
              'Encryption in transit — all traffic between the app and our servers uses HTTPS/TLS',
              'Encryption at rest — sensitive data, including prescriptions and health notes, is encrypted in our databases',
              'OTP-based authentication — accounts are protected by mobile OTP verification; no password-based login is used, removing password-related risk',
              'Role-based access control — Doctors and receptionists only see data for patients who have booked with their clinic; no employee has blanket access to all User data',
              'Database separation — Doctor and Patient data are logically separated to prevent cross-contamination of access',
              'Regular security reviews of our systems and infrastructure',
            ]} />
            <p>No method of electronic transmission or storage is 100% secure. You are responsible for keeping your OTP confidential and never sharing it with anyone, including anyone claiming to represent QLess.</p>
          </Section>

          <Section id="rights" n="08" icon={UserCheck} title="Your Rights">
            <div className="grid sm:grid-cols-2 gap-3">
              {[
                ['Access', 'View your profile, appointments, family member profiles, and prescriptions within the app.'],
                ['Correction', 'Update inaccurate or outdated profile details directly in the app at any time.'],
                ['Erasure', 'Request deletion of your account, bookings, prescriptions, and linked family profiles at any time — in-app via Profile → Delete Account → Confirm deletion, or by emailing support@vengurlatech.com with the subject "Data Deletion Request". Requests are processed within 30 calendar days of identity verification (see Section 11A).'],
                ['Data Portability', 'Contact us to request a copy of your data in a structured, machine-readable format.'],
                ['Grievance Redressal', 'File a complaint with us; escalate to the Data Protection Board of India if unresolved.'],
                ['Withdraw Consent', 'Withdraw consent for any processing at any time — see Section 09.'],
              ].map(([t, d]) => (
                <div key={t} className="rounded-xl bg-gray-50 border border-gray-100 p-3.5">
                  <p className="text-xs font-bold text-gray-800 mb-1">{t}</p>
                  <p className="text-xs text-gray-500 leading-relaxed">{d}</p>
                </div>
              ))}
            </div>
            <p className="pt-2">
              Most rights can be exercised directly in the app under <strong className="text-gray-800">Profile → Settings</strong>.
              For requests requiring our direct involvement, email{' '}
              <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a>{' '}
              with the subject "Data Rights Request". We acknowledge requests within 48 hours and resolve them
              within 30 days; identity verification may be required first.
            </p>
          </Section>

          <Section id="consent" n="09" icon={FileCheck} title="Consent & Its Management">
            <p>We collect or use Personal Data — and especially Sensitive Personal Data — only after receiving your clear consent. No consent is permanent; it can be withdrawn at any time.</p>
            <List items={[
              'Personal Data — by registering and accepting this Policy, you consent to processing for the purposes described above.',
              'Sensitive health data — collected only where you or your Doctor choose to record it as part of a consultation.',
              'Push notifications — granted at the OS level when you install the app; revoke anytime via device settings.',
              'WhatsApp OTP messages — used solely for login/verification, not marketing.',
            ]} />
            <p><strong className="text-gray-800">Revoking consent</strong> — email us at{' '}
              <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a>{' '}
              with subject "Consent Withdrawal", or revoke OS-level permissions (location, notifications) through
              your device settings. Revocation does not affect the lawfulness of processing that occurred before it.
            </p>
          </Section>

          <Section id="children" n="10" icon={Baby} title="Children's Privacy">
            <p>
              QLess is not directed at individuals under 18 and does not knowingly collect Personal Data from
              children without verified parental or guardian consent.
            </p>
            <p>Where a minor needs to book appointments, a parent or legal guardian must:</p>
            <List items={[
              "Create and maintain the account on the child's behalf using the guardian's own verified mobile number",
              'Provide consent to this Privacy Policy on the child\'s behalf',
              'Take full responsibility for all data submitted for the child',
            ]} />
            <p>We do not process a child's data for tracking, behavioural monitoring, or targeted advertising. If we become aware that a child's data was collected without guardian consent, we will delete it promptly.</p>
          </Section>

          <Section id="retention" n="11" icon={Clock} title="Data Retention">
            <p>
              We retain personal data only for as long as necessary to provide our Services, comply with our
              legal and regulatory obligations, resolve disputes, prevent fraud and abuse, and enforce our
              agreements. Once none of these purposes apply, the data is securely deleted or permanently
              anonymised so that it can no longer be linked back to you.
            </p>
            <p>Beyond this general principle, Personal Data is retained only as long as necessary for the purpose it was collected, or as required by Indian law.</p>
            <div className="overflow-x-auto rounded-xl border border-gray-100">
              <table className="w-full border-collapse">
                <thead><tr><Th>Data Category</Th><Th>Retention Period</Th></tr></thead>
                <tbody>
                  <tr><Td strong>Account & profile information</Td><Td>Duration of active account + 3 years post-closure</Td></tr>
                  <tr><Td strong>Medical records & prescriptions</Td><Td>7 years from the last appointment date</Td></tr>
                  <tr><Td strong>Doctor registration & credentials</Td><Td>Duration of registration + 5 years post-deregistration</Td></tr>
                  <tr><Td strong>App usage & diagnostic logs</Td><Td>13 months (rolling window)</Td></tr>
                  <tr><Td strong>Support & grievance correspondence</Td><Td>3 years from resolution date</Td></tr>
                  <tr><Td strong>OTP / authentication logs</Td><Td>90 days</Td></tr>
                </tbody>
              </table>
            </div>
            <p className="pt-2">
              When you delete your account, we permanently delete or anonymise your Personal Data within{' '}
              <strong className="text-gray-800">30 calendar days</strong> of the request, except where longer
              retention of medical records or other categories above is legally required.
            </p>
          </Section>

          <Section id="deletion-request" n="11A" icon={FileCheck} title="How to Request Data Deletion">
            <p>
              You may request deletion of your personal data at any time. We offer two ways to submit a
              deletion request:
            </p>
            <div className="grid sm:grid-cols-2 gap-3">
              <div className="rounded-xl bg-gray-50 border border-gray-100 p-4">
                <p className="text-xs font-bold text-gray-800 mb-1">In-App Deletion</p>
                <p className="text-xs text-gray-500 leading-relaxed">
                  Go to <strong className="text-gray-700">Profile → Delete Account → Confirm deletion</strong>.
                  This is the fastest way to initiate deletion and does not require contacting support.
                </p>
              </div>
              <div className="rounded-xl bg-gray-50 border border-gray-100 p-4">
                <p className="text-xs font-bold text-gray-800 mb-1">Email Deletion Request</p>
                <p className="text-xs text-gray-500 leading-relaxed">
                  Email{' '}
                  <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a>{' '}
                  with the subject <strong className="text-gray-700">"Data Deletion Request"</strong>, including
                  your registered mobile number or email address so we can verify your identity.
                </p>
              </div>
            </div>
            <p className="pt-2">
              Deletion requests are processed and your Personal Data is permanently deleted or anonymised
              within <strong className="text-gray-800">30 calendar days</strong> of the request, after
              identity verification, except where retention is required by applicable law (see the retention
              periods in Section 11 above — for example, medical records required to be retained under
              healthcare regulations). You will receive a confirmation once deletion is complete.
            </p>
          </Section>

          <Section id="thirdparty" n="12" icon={Link2} title="Third-Party Links & Services">
            <p>
              The Platform may embed or link to third-party services — for example, Google Maps for clinic
              location display. These third parties operate independently under their own privacy policies,
              and we do not control or accept responsibility for their data practices.
            </p>
            <List items={[
              <>Google / Firebase: <a href="https://policies.google.com/privacy" target="_blank" rel="noreferrer" className="text-sky-500 hover:underline">policies.google.com/privacy</a></>,
              <>Google Maps Platform: <a href="https://cloud.google.com/maps-platform/terms" target="_blank" rel="noreferrer" className="text-sky-500 hover:underline">cloud.google.com/maps-platform/terms</a></>,
            ]} />
          </Section>

          <Section id="changes" n="13" icon={RefreshCw} title="Changes to This Policy">
            <p>
              We may update this Policy as QLess evolves — to reflect new features, legal requirements, or
              processing practices. The revised policy will be posted in the app and on our website with an
              updated "Effective Date" above.
            </p>
            <p>
              For material changes — particularly those affecting your rights, the categories of data
              collected, or the purposes of processing — we will provide in-app notice and, where your email
              is available, an email notice at least 15 days before the change takes effect. Continued use of
              QLess after changes take effect constitutes acceptance of the revised Policy.
            </p>
          </Section>

          <Section id="contact" n="14" icon={Mail} title="Contact & Grievance Redressal">
            <p>
              For questions, access requests, corrections, deletion requests, or complaints regarding this
              Policy or our processing of your Personal Data, reach out to us — we're committed to resolving
              genuine privacy concerns promptly and fairly.
            </p>
            <div className="grid sm:grid-cols-2 gap-3 pt-1">
              <div className="rounded-xl bg-gray-50 border border-gray-100 p-4">
                <p className="text-xs font-bold text-gray-800 mb-1">Email</p>
                <a href="mailto:support@vengurlatech.com" className="text-sm text-sky-500 hover:underline">support@vengurlatech.com</a>
                <p className="text-xs text-gray-400 mt-1">Acknowledged within 48 hours &middot; Resolved within 30 days</p>
              </div>
              <div className="rounded-xl bg-gray-50 border border-gray-100 p-4">
                <p className="text-xs font-bold text-gray-800 mb-1">Registered Address</p>
                <p className="text-sm text-gray-600">Vengurla Tech Private Limited<br />Vengurla, Sindhudurg, Maharashtra — 416 516, India</p>
              </div>
            </div>
            <p className="pt-2">
              If you're not satisfied with our resolution, you may escalate your complaint to the{' '}
              <strong className="text-gray-800">Data Protection Board of India</strong>, established under
              Section 18 of the Digital Personal Data Protection Act, 2023.
            </p>
          </Section>

          {/* Footer nav */}
          <div className="flex flex-wrap justify-center gap-6 pt-4 pb-4 text-xs text-gray-400">
            <Link to="/" className="hover:text-gray-700 transition-colors">Home</Link>
            <Link to="/help-center" className="hover:text-gray-700 transition-colors">Help Center</Link>
            <Link to="/delete-account" className="hover:text-gray-700 transition-colors">Delete Account</Link>
            <a href="mailto:support@vengurlatech.com" className="hover:text-gray-700 transition-colors">Contact Us</a>
          </div>
          <p className="text-center text-xs text-gray-300 pb-8">
            &copy; 2026 Vengurla Tech Private Limited. All rights reserved.
          </p>
        </div>
      </div>
    </div>
  );
}
