import SwiftUI

struct TrainerAgreementView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("trainer.agreementSigned") private var agreementSigned = false
    @State private var hasScrolledToBottom = false
    @State private var agreed = false

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("MONTRA")
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.8)
                        .foregroundColor(.montraOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.montraOrange.opacity(0.12))
                        .clipShape(Capsule())

                    Text("Coach Provider Agreement")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.montraTextPrimary)

                    Text("Please read the full agreement before continuing. Scroll to the bottom to enable the accept button.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 64)
                .padding(.bottom, 20)

                // Scrollable agreement
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        agreementContent
                        // Sentinel at the bottom to detect full scroll
                        Color.clear
                            .frame(height: 1)
                            .onAppear { hasScrolledToBottom = true }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .background(Color.white.opacity(0.03))

                // Footer
                VStack(spacing: 12) {
                    if hasScrolledToBottom {
                        Button {
                            agreed.toggle()
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(agreed ? Color.montraOrange : Color.white.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                    if agreed {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.montraOrange)
                                    }
                                }
                                Text("I have read and agree to the Independent Coach Provider Agreement")
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Scroll to the bottom to continue")
                            .font(.system(size: 12))
                            .foregroundColor(.montraTextSecondary)
                    }

                    Button {
                        guard agreed else { return }
                        agreementSigned = true
                        if let uid = auth.user?.uid {
                            UserDefaults.standard.set(true, forKey: "trainer.agreementSigned.\(uid)")
                        }
                        Task { await saveAgreementToBackend() }
                    } label: {
                        Text(agreed ? "Accept & Continue" : hasScrolledToBottom ? "Check the box above to continue" : "Read the full agreement to continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(agreed ? .black : .montraTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(agreed ? Color.montraOrange : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .animation(.easeInOut(duration: 0.2), value: agreed)
                    }
                    .disabled(!agreed)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
                .background(Color.montraBackground)
            }
        }
    }

    // MARK: - Agreement Content

    @ViewBuilder
    private var agreementContent: some View {
        agreementSection("MONTRA INDEPENDENT COACH PROVIDER AGREEMENT", body: "This Independent Coach Provider Agreement is entered into between Elite Home Fitness Solution LLC, doing business as MONTRA (\"Company\"), and the independent wellness professional, trainer, coach, instructor, or service provider (\"Provider\") accessing or utilizing the MONTRA platform.\n\nBy registering for, accessing, or providing services through the MONTRA platform, you acknowledge that you have read, understood, and agreed to the terms of this Agreement.")

        agreementSection("1. Platform Overview", body: "MONTRA is a technology-enabled wellness marketplace platform that connects clients seeking wellness and fitness-related services with independent Providers. MONTRA provides scheduling infrastructure, payment processing, client acquisition systems, AI-powered matching tools, marketplace operations, communication systems, trust & safety systems, and operational infrastructure.\n\nMONTRA is not a gym employer model. Providers utilize the Platform independently while operating their own businesses.")

        agreementSection("2. Independent Contractor Relationship", body: "Provider is an independent contractor and not an employee of MONTRA. Nothing in this Agreement creates an employment, partnership, joint venture, agency, franchise, or fiduciary relationship.\n\nProvider is solely responsible for the manner and means by which services are performed and is free to perform services for other businesses. Provider controls their own business operations, schedules, pricing, availability, and service methods.\n\nMONTRA does not guarantee any minimum amount of business, earnings, or bookings. Provider is solely responsible for taxes, withholdings, insurance, licensing, certifications, and business compliance.")

        agreementSection("3. Provider Eligibility", body: "To participate on the Platform, Provider must be at least 18 years old, possess valid identification, maintain any required certifications or licenses, maintain active professional liability insurance, comply with all applicable laws and regulations, and provide accurate account information.\n\nMONTRA reserves the right to approve or deny applications, request documentation, suspend or terminate access, and conduct verification procedures.")

        agreementSection("4. Insurance Requirements", body: "Provider must maintain active professional liability insurance coverage with minimum limits of $1,000,000 per occurrence. Provider agrees to maintain insurance throughout Platform participation, provide proof of coverage upon request, and notify MONTRA of lapses, cancellations, or material changes.\n\nFailure to maintain required insurance may result in suspension or removal from the Platform.")

        agreementSection("5. Provider Control & Flexibility", body: "Provider independently controls pricing, schedules, availability, geographic service radius, coaching style, and service methods. Provider may work for competitors, operate independent businesses, and maintain independent clientele. Nothing in this Agreement shall restrict lawful independent business activities except as specifically outlined herein.")

        agreementSection("6. Platform Bookings & Availability", body: "When Provider marks time slots as available through the Platform, those time slots become immediately bookable by Clients. Once a Client books a session and payment is processed, Provider agrees to fulfill the booked session professionally and on time. Publicly available time slots constitute booking commitments.")

        agreementSection("7. Provider Cancellations & No-Shows", body: "Provider agrees to maintain reliable scheduling practices. Repeated avoidable cancellations, no-shows, or fulfillment failures may result in reduced Platform visibility, quality score reductions, temporary suspension, permanent removal, or financial penalties.\n\nMONTRA may retain up to 50% of associated fees in situations involving Provider cancellation, no-show events, misconduct, or violation of Platform standards.")

        agreementSection("8. Payments & Payouts", body: "MONTRA processes payments from Clients through the Platform. Standard payout timing is approximately 3–5 business days after successful Client billing and completed services, on weekly payout cycles.\n\nProvider is solely responsible for taxes, reporting obligations, bookkeeping, accounting, and business expenses. MONTRA does not provide tax advice.")

        agreementSection("9. Platform Fees", body: "Provider acknowledges that MONTRA may retain marketplace service fees, commissions, operational fees, processing fees, or other platform-related compensation. Fee structures may vary based on Provider tier, service category, marketplace promotions, or negotiated arrangements. MONTRA reserves the right to modify fee structures upon reasonable notice.")

        agreementSection("10. Platform Standards & Professionalism", body: "Provider agrees to arrive on time, communicate professionally, maintain respectful conduct, provide safe coaching environments, maintain appropriate appearance and professionalism, respect Client privacy, and comply with Platform trust & safety standards.\n\nProvider shall not engage in harassment, discrimination, fraud, misrepresentation of qualifications, or misuse of Platform systems.")

        agreementSection("11. Client Relationships & Platform Non-Circumvention", body: "Provider agrees not to solicit off-platform payments for Platform-generated Clients, intentionally circumvent Platform fees, redirect Platform Clients away from the Platform, or misuse Client information obtained through the Platform.\n\nMONTRA invests significant resources into client acquisition, technology infrastructure, marketing, and operational systems. MONTRA reserves the right to investigate suspected circumvention activity.")

        agreementSection("12. Intellectual Property", body: "All MONTRA branding, software, systems, workflows, graphics, designs, trademarks, operational systems, and Platform technology remain the exclusive property of MONTRA. Provider grants MONTRA a limited license to use Provider name, profile information, photos, videos, ratings, reviews, and service descriptions for Platform marketing and operational purposes.")

        agreementSection("13. Confidentiality", body: "Provider agrees to maintain confidentiality regarding Client information, Platform systems, operational procedures, business information, proprietary technology, and internal policies. Provider shall not disclose confidential information except as required by law.")

        agreementSection("14. Trust & Safety Compliance", body: "Provider agrees to comply with all MONTRA trust & safety policies. MONTRA may utilize identity verification, background checks, GPS session verification, AI quality monitoring, behavioral monitoring systems, and safety reporting systems.")

        agreementSection("15. Disclaimers", body: "MONTRA makes no guarantees regarding earnings, client volume, booking frequency, business success, market demand, or Platform availability. The Platform is provided \"AS IS\" and \"AS AVAILABLE.\" MONTRA disclaims all warranties to the fullest extent permitted by law.")

        agreementSection("16. Limitation of Liability", body: "To the fullest extent permitted by law, MONTRA shall not be liable for indirect damages, lost profits, loss of business opportunities, disputes between users, personal injury, property damage, Provider conduct claims, or service interruptions. MONTRA's maximum liability shall not exceed the total amount paid to Provider during the 12 months preceding the claim.")

        agreementSection("17. Indemnification", body: "Provider agrees to defend, indemnify, and hold harmless MONTRA and its affiliates, officers, directors, employees, contractors, and agents from claims arising out of Provider services, Provider conduct, legal violations, injuries or damages, breach of this Agreement, negligence or misconduct, tax obligations, or insurance failures.")

        agreementSection("18. Suspension & Termination", body: "MONTRA reserves the right to suspend accounts, remove Providers, limit Platform access, investigate conduct, restrict visibility, or terminate participation at its sole discretion. Grounds include repeated cancellations, no-shows, safety concerns, fraud, misconduct, policy violations, circumvention activity, failure to maintain insurance, or unprofessional behavior.")

        agreementSection("19. Dispute Resolution & Arbitration", body: "The parties agree to first attempt to resolve disputes informally. If unresolved, disputes shall be resolved through binding arbitration in the Commonwealth of Massachusetts. Provider waives jury trial rights, class action participation, and consolidated proceedings except where prohibited by law.")

        agreementSection("20–23. Governing Law, Modifications & Entire Agreement", body: "This Agreement shall be governed by the laws of the Commonwealth of Massachusetts. MONTRA reserves the right to modify this Agreement at any time. Continued use of the Platform following updates constitutes acceptance of revised terms.\n\nThis Agreement constitutes the complete agreement between the parties regarding Provider participation on the Platform.\n\nElite Home Fitness Solution LLC · 745 Atlantic Ave · Boston, Massachusetts")
    }

    // Persist agreement acceptance to the backend so it survives reinstalls/new devices.
    private func saveAgreementToBackend() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-profile/agreement-signed") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    private func agreementSection(_ heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(.montraTextPrimary)
                .textCase(.uppercase)
                .kerning(0.4)
            Text(body)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            Divider().background(Color.white.opacity(0.06))
        }
    }
}

#Preview {
    TrainerAgreementView()
        .environmentObject(AuthManager())
}
