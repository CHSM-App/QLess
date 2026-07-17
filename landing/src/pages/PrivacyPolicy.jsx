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

          <div className="prose prose-gray max-w-none space-y-10 text-gray-700 text-sm leading-relaxed">

            {/* Section 01 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">1. Key Terms Used in This Policy</h2>
              <p className="mb-3">
                For the purposes of this Privacy Policy, the following terms shall have the meanings set out below. These definitions align with the Digital Personal Data Protection Act, 2023 ("DPDP Act") and the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011 ("SPI Rules").
              </p>
              <ul className="list-disc list-inside space-y-2 text-gray-600">
                <li><strong>"Company" / "We" / "Us" / "Our"</strong> — Vengurla Tech Private Limited, a company incorporated under the Companies Act, 2013, having its registered office at Vengurla, Sindhudurg, Maharashtra, India, operating the QLess platform.</li>
                <li><strong>"Platform" / "Services"</strong> — The QLess mobile application (Android), associated APIs, and any related services provided by the Company.</li>
                <li><strong>"User" / "You"</strong> — Any individual who accesses or uses the Platform, including Patients, Doctors, and Clinic Administrators.</li>
                <li><strong>"Patient"</strong> — A User who registers to seek medical consultation, book appointments, or join queues through the Platform.</li>
                <li><strong>"Doctor" / "Practitioner"</strong> — A registered medical professional who uses the Platform to manage appointments, schedules, and patient queues.</li>
                <li><strong>"Personal Data"</strong> — Any data about an individual who is identifiable by or in relation to such data, as defined under the DPDP Act, 2023.</li>
                <li><strong>"Sensitive Personal Data or Information" (SPDI)</strong> — Information as defined under Rule 3 of the SPI Rules, including passwords, financial information, physical/physiological/mental health conditions, medical records and history, biometric information, and any details relating thereto.</li>
                <li><strong>"Data Fiduciary"</strong> — Vengurla Tech Private Limited, as the entity that alone or in conjunction with others determines the purpose and means of processing Personal Data.</li>
                <li><strong>"Data Principal"</strong> — The individual to whom the Personal Data relates — i.e., you, the User.</li>
                <li><strong>"Consent Manager"</strong> — A registered entity, as may be designated under the DPDP Act, 2023, through whom a Data Principal may give, manage, review, and withdraw consent.</li>
              </ul>
            </section>

            {/* Section 02 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">2. Who We Are & What This Policy Covers</h2>
              <div className="bg-sky-50 border border-sky-200 rounded-xl p-4 mb-4 text-sky-800 text-sm">
                This Privacy Policy applies to all Users of the QLess mobile application, including registered Doctors and Patients. By using the Services, you confirm your unconditional acceptance of this Privacy Policy.
              </div>
              <p className="mb-3">
                QLess is a product of <strong>Vengurla Tech Private Limited</strong> ("Company"), a digital healthcare platform that connects Patients with verified medical professionals for appointment booking, queue management, and consultations. This Privacy Policy is published in compliance with:
              </p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>The <strong>Information Technology Act, 2000</strong> and rules thereunder</li>
                <li>The <strong>Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011</strong> ("SPI Rules")</li>
                <li>The <strong>Digital Personal Data Protection Act, 2023</strong> ("DPDP Act")</li>
                <li>The <strong>Indian Medical Council (Professional Conduct, Etiquette and Ethics) Regulations, 2002</strong>, as applicable to Practitioners</li>
              </ul>
              <p className="text-gray-600 uppercase text-xs font-medium mb-4">
                BY CONFIRMING THAT YOU ARE BOUND BY THIS PRIVACY POLICY (BY THE MEANS PROVIDED WITHIN THE APPLICATION), BY USING THE SERVICES OR BY OTHERWISE GIVING US YOUR INFORMATION, YOU AGREE TO THE PRACTICES AND POLICIES OUTLINED IN THIS PRIVACY POLICY AND YOU HEREBY CONSENT TO OUR COLLECTION, USE, AND SHARING OF YOUR INFORMATION AS DESCRIBED IN THIS PRIVACY POLICY. WE RESERVE THE RIGHT TO CHANGE, MODIFY, ADD OR DELETE PORTIONS OF THE TERMS OF THIS PRIVACY POLICY AT OUR SOLE DISCRETION AND AT ANY TIME.
              </p>
              <h3 className="font-semibold text-gray-800 mb-2">Scope</h3>
              <p className="mb-2">This policy covers:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>The QLess mobile application (Android)</li>
                <li>All communications between you and QLess, including via email, SMS, telephone, or in-app messaging</li>
                <li>Data collected from Doctors, Patients, and any other Users of the Platform</li>
                <li>Data processed by third-party service providers acting on our behalf</li>
              </ul>
              <h3 className="font-semibold text-gray-800 mb-2">If You Use Services on Behalf of Another</h3>
              <p className="text-gray-600 uppercase text-xs font-medium">
                IF YOU USE THE SERVICES ON BEHALF OF SOMEONE ELSE (SUCH AS YOUR CHILD OR A DEPENDENT) OR AN ENTITY (SUCH AS YOUR EMPLOYER), YOU REPRESENT THAT YOU ARE AUTHORISED BY SUCH INDIVIDUAL OR ENTITY TO (I) ACCEPT THIS PRIVACY POLICY ON SUCH INDIVIDUAL'S OR ENTITY'S BEHALF, AND (II) CONSENT ON BEHALF OF SUCH INDIVIDUAL OR ENTITY TO OUR COLLECTION, USE AND DISCLOSURE OF SUCH INDIVIDUAL'S OR ENTITY'S INFORMATION AS DESCRIBED IN THIS PRIVACY POLICY.
              </p>
            </section>

            {/* Section 03 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">3. Categories of Personal Data Collected</h2>
              <p className="mb-4">
                We collect Personal Data only to the extent necessary for the purposes described in this Policy. You hereby consent to the collection of such information by the Company. The collection occurs (a) directly from you when you provide it voluntarily, (b) automatically through your use of the Platform, and (c) from third parties as described below.
              </p>

              <h3 className="font-semibold text-gray-800 mb-2">A. Information You Provide Directly</h3>
              <div className="overflow-x-auto mb-4">
                <table className="w-full text-xs border border-gray-200 rounded-lg overflow-hidden">
                  <thead className="bg-gray-50 text-gray-700">
                    <tr>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Category</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Specific Data Points</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Who</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Mandatory?</th>
                    </tr>
                  </thead>
                  <tbody className="text-gray-600">
                    <tr className="border-b border-gray-100"><td className="p-3">Identity</td><td className="p-3">Full name, gender, profile photograph</td><td className="p-3">All Users</td><td className="p-3">Yes</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Contact</td><td className="p-3">Mobile number, email address</td><td className="p-3">All Users</td><td className="p-3">Yes (mobile mandatory)</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Health / Medical</td><td className="p-3">Symptoms, medical history, current medications, allergies, blood group, appointment notes</td><td className="p-3">Patients</td><td className="p-3">Optional (patient-controlled)</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Professional Credentials</td><td className="p-3">Medical registration number, qualification, specialization, years of experience</td><td className="p-3">Doctors</td><td className="p-3">Yes</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Clinic Details</td><td className="p-3">Clinic name, address, GPS coordinates, contact number, email, website, consultation fee</td><td className="p-3">Doctors</td><td className="p-3">Yes</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Schedule & Availability</td><td className="p-3">Working days, time slots, booking mode, slot duration, queue lead time, max queue length</td><td className="p-3">Doctors</td><td className="p-3">Yes</td></tr>
                    <tr><td className="p-3">Appointment Records</td><td className="p-3">Booking history, queue position, visit dates, status (completed/cancelled)</td><td className="p-3">All Users</td><td className="p-3">Generated automatically</td></tr>
                  </tbody>
                </table>
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">B. Information Collected Automatically</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Device type, model, manufacturer, operating system version, and application version</li>
                <li>Internet Protocol (IP) address of the User's device or proxy server</li>
                <li>Approximate location derived from IP address (city/region level only)</li>
                <li>Precise GPS location — only when you actively use the map feature and grant explicit location permission</li>
                <li>Firebase Cloud Messaging (FCM) push notification token for appointment alerts and queue updates</li>
                <li>Login timestamps, session duration, and session frequency</li>
                <li>Type of web browser or mobile browser used</li>
                <li>URL of the page from which you accessed the Platform (referrer URL)</li>
                <li>Crash reports and technical diagnostics to diagnose and fix application errors</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">C. Information From Third Parties</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Credential verification data from the Medical Council of India or State Medical Councils, for verifying Doctor registration numbers</li>
                <li>OTP delivery confirmation metadata from telecom service providers</li>
                <li>Anonymised aggregated analytics from Firebase (Google) to understand platform usage patterns</li>
              </ul>

              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-4 text-amber-800 text-sm">
                We do not collect payment card numbers, CVV codes, or bank account credentials. If payment features are introduced in future versions, all processing will be handled exclusively by PCI-DSS Level 1 certified payment gateways. We will update this Policy before any such introduction.
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">D. Consequence of Non-Provision</h3>
              <p className="text-gray-600">
                Where the provision of certain Personal Data is mandatory for the delivery of a particular Service, your refusal to provide such data may result in the Company being unable to provide that specific Service to you. We will clearly indicate which fields are mandatory at the point of collection.
              </p>
            </section>

            {/* Section 04 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">4. Special Category: Health & Sensitive Information</h2>
              <div className="bg-red-50 border border-red-200 rounded-xl p-4 mb-4 text-red-800 text-sm">
                Health and medical information constitutes Sensitive Personal Data or Information (SPDI) under Rule 3 of the SPI Rules, 2011 and Special Category Personal Data under the DPDP Act, 2023. The Company applies heightened standards of protection to all such data.
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">What Constitutes SPDI on This Platform</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Medical history, diagnoses, and treatment records shared by Patients</li>
                <li>Symptoms and health notes entered during appointment booking</li>
                <li>Prescriptions or clinical notes attached by Doctors to appointment records</li>
                <li>Blood group and known allergies or medical conditions</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Heightened Protections Applied to SPDI</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Express prior written consent is obtained before collection of SPDI, separate from general terms acceptance</li>
                <li>SPDI is never transferred to any third party without your explicit consent, except as required by law or court order</li>
                <li>SPDI is encrypted both in transit (TLS 1.3) and at rest (AES-256) at all times</li>
                <li>Access to SPDI within the Company is restricted on a strict need-to-know basis enforced by role-based access controls</li>
                <li>SPDI shared between Patient and Doctor is accessible only to the specific Doctor with whom you have booked an appointment — it is not visible to other Doctors on the Platform</li>
                <li>We do not use SPDI for profiling, advertising, or any secondary commercial purpose whatsoever</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Withdrawal of Consent for SPDI</h3>
              <p className="text-gray-600">
                You may withdraw consent for the collection and use of your SPDI at any time by contacting us at <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a>. Upon withdrawal, we will cease further collection; however, information already lawfully collected and processed prior to withdrawal may be retained for the minimum period required by law.
              </p>
            </section>

            {/* Section 05 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">5. How We Use Your Personal Data</h2>
              <p className="mb-4">
                The Company uses Personal Data only for the specific, lawful purposes described below. We will never sell your Personal Data to any third party, advertiser, or data broker. After a period of time, de-identified or anonymised data may be retained and used solely for aggregate analytics to improve healthcare delivery.
              </p>

              <h3 className="font-semibold text-gray-800 mb-2">A. Core Service Delivery</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Creating, authenticating, and managing your User account</li>
                <li>Connecting Patients with verified Doctors for appointment booking and live queue management</li>
                <li>Processing appointment bookings, cancellations, rescheduling, and status updates</li>
                <li>Displaying real-time queue position, estimated wait times, and Doctor availability</li>
                <li>Facilitating in-app communication between Doctor and Patient within the scope of a booked appointment</li>
                <li>Displaying clinic location, map coordinates, and navigation assistance</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">B. Verification, Safety & Compliance</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Verifying Doctor credentials against medical council registries to ensure only licensed practitioners are listed</li>
                <li>Sending One-Time Passwords (OTPs) to authenticate User identity at login and for sensitive operations</li>
                <li>Detecting, investigating, and preventing fraudulent, abusive, or illegal activity on the Platform</li>
                <li>Enforcing our Terms of Use and this Privacy Policy</li>
                <li>Complying with applicable Indian laws, regulations, and lawful orders of government authorities</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">C. Communications</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Sending push notifications (via FCM) for appointment confirmations, reminders, cancellations, and queue position updates</li>
                <li>Sending SMS alerts for time-sensitive appointment changes — only if your mobile number is not registered with the DNCR (Do Not Call Registry), unless you provide express, clear, and unambiguous written consent</li>
                <li>Responding to your support inquiries, grievances, and feedback</li>
                <li>Sending service-related email communications; marketing communications only with your prior opt-in consent</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">D. Platform Improvement</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Analysing application performance, diagnosing bugs, and monitoring system health</li>
                <li>Understanding aggregate usage patterns to improve features and user experience</li>
                <li>Conducting anonymised, aggregate research to identify trends in healthcare access and queue management</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">E. Legal Basis for Each Processing Purpose</h3>
              <div className="overflow-x-auto">
                <table className="w-full text-xs border border-gray-200 rounded-lg overflow-hidden">
                  <thead className="bg-gray-50 text-gray-700">
                    <tr>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Purpose</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Legal Basis</th>
                    </tr>
                  </thead>
                  <tbody className="text-gray-600">
                    <tr className="border-b border-gray-100"><td className="p-3">Account creation & service delivery</td><td className="p-3">Performance of contract (Terms of Use)</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Health data / SPDI collection</td><td className="p-3">Express prior written consent</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Location access (GPS)</td><td className="p-3">Express prior consent via OS-level permission</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Push notifications</td><td className="p-3">Consent (app-level permission grant)</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Fraud detection & security</td><td className="p-3">Legitimate interest of the Company</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Marketing communications</td><td className="p-3">Opt-in consent</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Legal compliance & disclosures</td><td className="p-3">Legal obligation under applicable Indian law</td></tr>
                    <tr><td className="p-3">Anonymised analytics</td><td className="p-3">Legitimate interest (no re-identification possible)</td></tr>
                  </tbody>
                </table>
              </div>
            </section>

            {/* Section 06 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">6. When and With Whom We Share Your Data</h2>
              <div className="bg-sky-50 border border-sky-200 rounded-xl p-4 mb-4 text-sky-800 text-sm">
                We do not sell, rent, or trade your Personal Data. Sharing occurs only in the limited circumstances below, and in every case with appropriate contractual safeguards or legal authority.
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">A. Between Patients and Doctors (Platform-Mediated)</h3>
              <p className="text-gray-600 mb-2">When a Patient books an appointment with a Doctor, the following limited data is shared to facilitate that consultation:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-2">
                <li><strong>Patient → Doctor:</strong> Name, mobile number, and any health notes or symptoms the Patient voluntarily adds to the booking</li>
                <li><strong>Doctor → Patient:</strong> Name, photo, specialization, qualification, clinic name, address, schedule, and consultation fee</li>
              </ul>
              <p className="text-gray-600 mb-4">This sharing is strictly limited to the specific appointment relationship. A Doctor cannot access the medical records of a Patient who has not booked an appointment with that Doctor.</p>

              <h3 className="font-semibold text-gray-800 mb-2">B. Service Providers (Data Processors)</h3>
              <p className="text-gray-600 mb-3">The Company engages carefully vetted third-party processors under written Data Processing Agreements that require them to maintain confidentiality and implement appropriate security measures. Current processors include:</p>
              <div className="overflow-x-auto mb-4">
                <table className="w-full text-xs border border-gray-200 rounded-lg overflow-hidden">
                  <thead className="bg-gray-50 text-gray-700">
                    <tr>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Processor</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Purpose</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Data Shared</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Location</th>
                    </tr>
                  </thead>
                  <tbody className="text-gray-600">
                    <tr className="border-b border-gray-100"><td className="p-3">Firebase (Google LLC)</td><td className="p-3">Push notification delivery, crash analytics</td><td className="p-3">FCM device token, anonymised event data</td><td className="p-3">USA / Global</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Telecom providers (BSNL, Jio, Airtel, etc.)</td><td className="p-3">OTP SMS delivery</td><td className="p-3">Mobile number only</td><td className="p-3">India</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Cloud infrastructure provider</td><td className="p-3">Server hosting and encrypted database storage</td><td className="p-3">All Platform data (encrypted)</td><td className="p-3">India</td></tr>
                    <tr><td className="p-3">Google Maps Platform</td><td className="p-3">Clinic location display, map-based location picker</td><td className="p-3">Location coordinates (when map feature used)</td><td className="p-3">USA / Global</td></tr>
                  </tbody>
                </table>
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">C. Legal Disclosures</h3>
              <p className="text-gray-600 mb-2">The Company may disclose your Personal Data without your consent when required or permitted to do so by applicable law, including in the following circumstances:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>In response to a court order, subpoena, or lawful request from a government or regulatory authority</li>
                <li>To protect the rights, property, or safety of the Company, our Users, or the general public</li>
                <li>To enforce our Terms of Use or this Privacy Policy</li>
                <li>In connection with the investigation of a breach or potential breach of any agreement or law</li>
              </ul>
              <p className="text-gray-600 mb-4">The Company may also transfer User-generated information to its affiliates or governmental authorities in such manner as permitted or required by applicable Indian law, and you hereby consent to such transfer.</p>

              <h3 className="font-semibold text-gray-800 mb-2">D. Transfer of Sensitive Personal Data</h3>
              <p className="text-gray-600 mb-4">In accordance with Rule 7 of the SPI Rules, 2011, the Company shall not transfer SPDI to any body corporate or person in India or outside India unless: (i) the receiving entity ensures the same level of data protection as required under the SPI Rules, and (ii) such transfer is necessary for the performance of a lawful contract, or the User has consented to such transfer.</p>

              <h3 className="font-semibold text-gray-800 mb-2">E. Business Transfers</h3>
              <p className="text-gray-600 mb-4">In the event of a merger, acquisition, restructuring, or sale of all or a material portion of the Company's assets, your Personal Data may be transferred to the successor entity. The Company will provide prior notice via in-app notification and email (where available), and will give you a reasonable opportunity to request deletion of your account before any such transfer becomes effective.</p>

              <h3 className="font-semibold text-gray-800 mb-2">F. Aggregated, Anonymised Data</h3>
              <p className="text-gray-600">The Company may share anonymised, aggregated statistical information (from which no individual can be identified) with research institutions, public health bodies, or the public, for the purpose of improving healthcare accessibility and outcomes in India.</p>
            </section>

            {/* Section 07 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">7. How We Store and Protect Your Data</h2>

              <h3 className="font-semibold text-gray-800 mb-2">Data Location</h3>
              <p className="text-gray-600 mb-4">All Personal Data and SPDI is stored on secure servers located within India. Anonymised analytics data processed by Firebase may reside on Google's global infrastructure. In all such cross-border processing, the Company ensures that equivalent data protection safeguards are maintained, as required by the DPDP Act, 2023 and the SPI Rules.</p>

              <h3 className="font-semibold text-gray-800 mb-2">Technical Security Measures</h3>
              <ul className="list-disc list-inside space-y-2 text-gray-600 mb-4">
                <li><strong>Encryption in Transit:</strong> All data transmitted between User devices and Company servers is protected using TLS 1.3 (HTTPS). Unencrypted connections are refused.</li>
                <li><strong>Encryption at Rest:</strong> All Personal Data and SPDI stored in Company databases is encrypted using AES-256 bit encryption. Only authorised systems with the correct decryption keys can access this data.</li>
                <li><strong>OTP-Based Authentication:</strong> User accounts are protected by mobile number OTP verification. No password-based login is used, eliminating password-related vulnerabilities.</li>
                <li><strong>Role-Based Access Control (RBAC):</strong> Internal access to Personal Data is strictly limited to authorised personnel based on their functional role. No employee has blanket access to all User data.</li>
                <li><strong>Access Zones:</strong> Systems are configured to restrict data access from unauthorised IP ranges or geographic locations.</li>
                <li><strong>Database Separation:</strong> Doctor data and Patient data are stored in logically separated database schemas to prevent cross-contamination of access.</li>
                <li><strong>Regular Security Audits:</strong> The Company conducts periodic security assessments, penetration testing, and vulnerability scanning of its systems and infrastructure.</li>
                <li><strong>Backup & Recovery:</strong> Data is backed up and versioned at regular intervals. Point-in-time recovery capabilities are maintained.</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Organisational Security Measures</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>All employees and contractors with access to Personal Data are bound by confidentiality obligations</li>
                <li>Security awareness training is provided to all personnel handling User data</li>
                <li>Third-party processors are contractually obligated to maintain equivalent security standards</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Data Breach Response</h3>
              <p className="text-gray-600 mb-2">The Company maintains a documented Incident Response Plan. In the event of a confirmed personal data breach that is likely to cause harm to any Data Principal:</p>
              <ol className="list-decimal list-inside space-y-1 text-gray-600 mb-4">
                <li>Affected Users will be notified within 72 hours of the Company becoming aware of the breach</li>
                <li>The Data Protection Board of India will be notified as required under the DPDP Act, 2023</li>
                <li>Notifications will describe the nature of the breach, categories of data affected, likely consequences, and steps taken to address it</li>
              </ol>

              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-amber-800 text-sm">
                Despite our best efforts, no method of electronic transmission or storage is 100% secure. The Company cannot guarantee the absolute security of your data. You are responsible for keeping your OTP confidential and not sharing it with any third party, including anyone claiming to be a Company representative.
              </div>
            </section>

            {/* Section 08 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">8. Rights You Have Over Your Personal Data</h2>
              <p className="mb-4">
                Under the Digital Personal Data Protection Act, 2023, the IT Act, 2000, and the SPI Rules, you are entitled to the following rights with respect to your Personal Data held by the Company:
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-6">
                {[
                  { title: 'Right to Access & Information', desc: 'Request a summary of your Personal Data we process, the identities of all Data Fiduciaries we share it with, and the purposes of such sharing.' },
                  { title: 'Right to Correction', desc: 'Require us to correct inaccurate, incomplete, or misleading Personal Data we hold about you.' },
                  { title: 'Right to Erasure', desc: 'Request deletion of your Personal Data, subject to legal retention obligations. Exercising this right may result in termination of your account.' },
                  { title: 'Right to Data Portability', desc: 'Receive a copy of your Personal Data in a structured, commonly used, machine-readable format.' },
                  { title: 'Right to Grievance Redressal', desc: 'File a complaint with the Company\'s Grievance Officer. If unsatisfied, escalate to the Data Protection Board of India.' },
                  { title: 'Right to Withdraw Consent', desc: 'Withdraw consent at any time. Withdrawal will not affect the lawfulness of processing based on consent prior to its withdrawal.' },
                  { title: 'Right of Nominee', desc: 'Nominate another individual to exercise data rights on your behalf in the event of your death or incapacity, as per the DPDP Act, 2023.' },
                  { title: 'Right Against Automated Decisions', desc: 'We do not use your Personal Data to make solely automated decisions (including profiling) that produce legal or similarly significant effects on you.' },
                ].map((right) => (
                  <div key={right.title} className="bg-gray-50 border border-gray-200 rounded-xl p-4">
                    <p className="font-semibold text-gray-800 text-xs mb-1">{right.title}</p>
                    <p className="text-gray-600 text-xs">{right.desc}</p>
                  </div>
                ))}
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">How to Exercise Your Rights</h3>
              <p className="text-gray-600 mb-2">You may exercise most rights directly within the QLess application under <strong>Settings → Account → Privacy</strong>. For requests requiring the Company's direct involvement:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Email: <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a> (Subject: "Data Rights Request — [Your Name]")</li>
                <li>The Company will acknowledge receipt within 7 business days and fulfil the request within 30 days</li>
                <li>Identity verification may be required before processing any data rights request</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Grievance Contact</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600">
                <li>Email: <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a></li>
                <li>Address: Vengurla Tech Private Limited, Vengurla, Sindhudurg, Maharashtra — 416 516, India</li>
                <li>Acknowledgement: Within 48 hours of receipt</li>
                <li>Resolution: Within 30 days of receipt</li>
              </ul>
              <p className="text-gray-600 mt-3">If you are dissatisfied with the resolution provided by the Grievance Officer, you may escalate your complaint to the Data Protection Board of India established under Section 18 of the DPDP Act, 2023.</p>
            </section>

            {/* Section 09 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">9. How We Obtain, Manage & Honour Consent</h2>
              <div className="bg-sky-50 border border-sky-200 rounded-xl p-4 mb-4 text-sky-800 text-sm">
                The Company collects or uses any Personal or Sensitive Personal Data belonging to you only after receiving appropriate and clear consent from you. No consent is permanent — any consent given can be revoked at any time.
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">Consent for Personal Data</h3>
              <p className="text-gray-600 mb-4">By registering for an account and accepting this Privacy Policy, you consent to the collection and use of your Personal Data for the purposes set out in this Policy. This consent is given freely and may be withdrawn at any time.</p>

              <h3 className="font-semibold text-gray-800 mb-2">Consent for Sensitive Personal Data (SPDI)</h3>
              <p className="text-gray-600 mb-2">Prior to collecting any health-related SPDI, the Company will present a separate, explicit consent notice that:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Identifies the specific SPDI being collected</li>
                <li>States the purpose of collection</li>
                <li>Names the persons who may have access to the SPDI</li>
                <li>Provides the option to review the information being collected</li>
                <li>Includes a clear mechanism to grant or deny consent</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Consent for Communications</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li><strong>Push notifications:</strong> Granted at the OS level when you first install the app. You may revoke via your device settings at any time.</li>
                <li><strong>SMS communications:</strong> The Company will not send SMS to numbers registered with the DNCR (Do Not Call Registry) without your express written consent.</li>
                <li><strong>Marketing emails:</strong> Only sent with prior opt-in consent. An unsubscribe link is included in every marketing communication.</li>
              </ul>

              <h3 className="font-semibold text-gray-800 mb-2">Revoking Consent</h3>
              <p className="text-gray-600 mb-2">You may revoke any consent previously granted by:</p>
              <ul className="list-disc list-inside space-y-1 text-gray-600 mb-4">
                <li>Using the privacy controls within the QLess app (Settings → Account → Privacy)</li>
                <li>Emailing us at <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a> with the subject "Consent Withdrawal — [Your Name]"</li>
                <li>Revoking OS-level permissions (location, notifications) through your device settings</li>
              </ul>
              <p className="text-gray-600 mb-4">Upon receiving a valid revocation request, the Company will cease the relevant processing as soon as reasonably practicable. Revocation will not affect the lawfulness of processing that occurred prior to the withdrawal.</p>

              <h3 className="font-semibold text-gray-800 mb-2">Consent of Minors</h3>
              <p className="text-gray-600">The Platform is not directed at persons under 18 years of age. For Patients who are minors, a parent or legal guardian must provide consent on their behalf. By providing data for a minor, the guardian confirms they have the legal authority to do so.</p>
            </section>

            {/* Section 10 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">10. Policy Regarding Persons Under 18 Years of Age</h2>
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-4 text-amber-800 text-sm">
                QLess is not directed at children under 18 years of age and does not knowingly collect Personal Data from children without verified parental or guardian consent, as required under Section 9 of the DPDP Act, 2023.
              </div>
              <p className="text-gray-600 mb-2">Where a child under 18 requires access to healthcare services through the Platform, a parent or legal guardian must:</p>
              <ol className="list-decimal list-inside space-y-1 text-gray-600 mb-4">
                <li>Create and maintain the account on the child's behalf using their own (guardian's) verified mobile number</li>
                <li>Provide consent to this Privacy Policy on the child's behalf</li>
                <li>Take full responsibility for all data submitted on behalf of the child</li>
              </ol>
              <p className="text-gray-600">The Company will not process data of a child for the purpose of tracking, behavioural monitoring, or targeted advertising. If the Company becomes aware that Personal Data of a child has been collected without appropriate guardian consent, it will take immediate steps to delete that data. To report such a concern, contact us at <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a>.</p>
            </section>

            {/* Section 11 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">11. How Long We Retain Your Personal Data</h2>
              <p className="mb-4">The Company shall not retain Personal Data for a period longer than is necessary for the purpose for which it was collected or as required under applicable Indian law.</p>
              <div className="overflow-x-auto mb-4">
                <table className="w-full text-xs border border-gray-200 rounded-lg overflow-hidden">
                  <thead className="bg-gray-50 text-gray-700">
                    <tr>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Data Category</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Retention Period</th>
                      <th className="text-left p-3 font-semibold border-b border-gray-200">Legal / Regulatory Basis</th>
                    </tr>
                  </thead>
                  <tbody className="text-gray-600">
                    <tr className="border-b border-gray-100"><td className="p-3">Account & profile information</td><td className="p-3">Duration of active account + 3 years post-closure</td><td className="p-3">IT Act, 2000; DPDP Act, 2023</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Medical records & appointment history</td><td className="p-3">7 years from last appointment date</td><td className="p-3">MCI Ethics Regulations, 2002; Clinical Establishments Act</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Doctor registration & credential documents</td><td className="p-3">Duration of registration + 5 years post-deregistration</td><td className="p-3">Indian Medical Council Act, 1956</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">App usage logs & analytics</td><td className="p-3">13 months (rolling window)</td><td className="p-3">Operational necessity</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">Support & grievance correspondence</td><td className="p-3">3 years from resolution date</td><td className="p-3">Limitation Act, 1963</td></tr>
                    <tr className="border-b border-gray-100"><td className="p-3">OTP / authentication logs</td><td className="p-3">90 days</td><td className="p-3">Security audit purposes</td></tr>
                    <tr><td className="p-3">Anonymised & aggregated analytics</td><td className="p-3">Indefinite (no re-identification possible)</td><td className="p-3">Legitimate interest (public health research)</td></tr>
                  </tbody>
                </table>
              </div>

              <h3 className="font-semibold text-gray-800 mb-2">Account Deletion</h3>
              <p className="text-gray-600 mb-4">When you delete your account, the Company will anonymise or permanently delete your Personal Data within 30 calendar days from the date of deletion request, except for categories of data that must be retained under the periods specified above. You will receive a confirmation email upon completion of deletion.</p>

              <h3 className="font-semibold text-gray-800 mb-2">Post-Retention Disposal</h3>
              <p className="text-gray-600">Upon expiry of the applicable retention period, Personal Data will be securely deleted, anonymised beyond re-identification, or archived in a manner that prevents further processing, in accordance with industry-standard secure disposal procedures.</p>
            </section>

            {/* Section 12 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">12. Links to External Platforms and Services</h2>
              <p className="text-gray-600 mb-4">
                The Platform may display or link to third-party websites, embedded maps, and external services (for example, Google Maps for clinic location display). These third parties operate independently and have their own privacy policies. The Company does not exercise control over such third-party sites and accepts no responsibility or liability for their privacy practices, data collection, or content.
              </p>
              <p className="text-gray-600 mb-4">The Company does not make any representations concerning the privacy practices or policies of such third parties or terms of use of such websites. The inclusion of any such link or integration does not imply endorsement by the Company.</p>
              <h3 className="font-semibold text-gray-800 mb-2">Key Third-Party Privacy Policies</h3>
              <ul className="list-disc list-inside space-y-1 text-gray-600">
                <li>Google / Firebase: policies.google.com/privacy</li>
                <li>Google Maps Platform: cloud.google.com/maps-platform/terms</li>
              </ul>
              <p className="text-gray-600 mt-3">We encourage you to review the privacy policies of any third-party service you interact with through the Platform before providing them with any personal information.</p>
            </section>

            {/* Section 13 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">13. How We Handle Updates to This Privacy Policy</h2>
              <p className="text-gray-600 mb-4">
                The Company reserves the right to amend, update, or replace any part of this Privacy Policy at its sole discretion and at any time, including to reflect changes in applicable law, Platform features, or data processing practices.
              </p>
              <h3 className="font-semibold text-gray-800 mb-2">Notification of Changes</h3>
              <ol className="list-decimal list-inside space-y-2 text-gray-600 mb-4">
                <li>The revised policy will be posted within the application and on our website with an updated "Last Updated" date</li>
                <li>For material changes — particularly those that affect your rights, the categories of data collected, or the purposes of processing — the Company will provide in-app notification and, where your email is available, an email notice at least 15 days prior to the change taking effect</li>
                <li>For changes that significantly alter your rights or obligations, the Company will require your re-acknowledgement of the updated Policy before you may continue to use the Services</li>
              </ol>
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-amber-800 text-sm">
                Your continued use of the QLess Platform after any changes to this Privacy Policy are posted shall constitute your acceptance of those changes. If you do not agree to the revised Policy, you must cease using the Services and may request deletion of your account.
              </div>
            </section>

            {/* Section 14 */}
            <section>
              <h2 className="text-xl font-bold text-gray-900 mb-3">14. Contact & Grievance Redressal</h2>
              <p className="text-gray-600 mb-4">
                For any questions, concerns, access requests, correction requests, deletion requests, or complaints regarding this Privacy Policy or the processing of your Personal Data, please contact us through any of the following channels. The Company is committed to resolving all genuine privacy concerns promptly and fairly.
              </p>
              <div className="bg-gray-50 border border-gray-200 rounded-xl p-6">
                <p className="font-semibold text-gray-800 mb-1">Vengurla Tech Private Limited — Privacy & Grievance</p>
                <p className="text-gray-500 text-xs mb-4">Acknowledgement within 48 hrs · Resolution within 30 days</p>
                <ul className="space-y-2 text-sm text-gray-600">
                  <li><strong>Email:</strong> <a href="mailto:support@vengurlatech.com" className="text-sky-500 hover:underline">support@vengurlatech.com</a></li>
                  <li><strong>Address:</strong> Vengurla Tech Private Limited, Vengurla, Sindhudurg, Maharashtra — 416 516, India</li>
                  <li><strong>Escalation:</strong> Data Protection Board of India (dpboard.gov.in)</li>
                </ul>
              </div>
              <p className="text-gray-600 mt-4">
                If you are not satisfied with the resolution provided by the Company's Grievance Officer within 30 days, you have the right to file a complaint with the Data Protection Board of India constituted under Section 18 of the Digital Personal Data Protection Act, 2023.
              </p>
            </section>

          </div>
        </div>
      </div>
    </div>
  );
}
