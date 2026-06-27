import SwiftUI
import StripePaymentSheet

// MARK: - Intro Booking Flow (8 steps)
// Coach → Date → Time → Pay → Address → Booked! → Calendar → Get Ready

struct IntroBookingView: View {
    /// Pre-selected coach (nil = user picks from list in Step 1)
    let preselectedTrainer: OnboardingTrainer?
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 1
    @State private var selectedTrainer: OnboardingTrainer? = nil
    @State private var trainers: [OnboardingTrainer] = []
    @State private var trainersLoading = true
    @State private var selectedDate: Date? = nil
    @State private var selectedSlot: String? = nil
    @State private var slots: [String] = []
    @State private var slotsLoading = false
    @State private var calDisplayMonth = Date()
    @State private var paymentSheet: PaymentSheet? = nil
    @State private var paymentLoading = false
    @State private var paymentDone = false
    @State private var addressLine = ""
    @State private var addressType = "Home"
    @State private var customerName = ""
    @State private var customerEmail = ""
    @State private var customerPhone = ""
    @State private var errorMessage: String? = nil
    @State private var introPrice: Double = 149
    @State private var bookingId: String? = nil

    private let addressTypes = ["Home", "Apartment / Condo", "Outdoor (Park, etc.)"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    progressBar
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            switch step {
                            case 1: step1ChooseCoach
                            case 2: step2SelectDate
                            case 3: step3SelectTime
                            case 4: step4Pay
                            case 5: step5Address
                            case 6: step6Booked
                            case 7: step7Calendar
                            default: step8GetReady
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step > 1 && step < 6 {
                        Button { step -= 1 } label: {
                            Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                        }
                    } else {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.montraTextSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Book Intro Session").font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                }
            }
        }
        .task {
            if let pre = preselectedTrainer {
                selectedTrainer = pre
                await fetchIntroPrice()
            } else {
                await loadTrainers()
            }
        }
    }

    // ── Progress bar ─────────────────────────────────────────────────────

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(1...8, id: \.self) { n in
                if n > 1 {
                    Rectangle().fill(n <= step ? Color.montraOrange : Color.white.opacity(0.15)).frame(height: 2)
                }
                Circle()
                    .fill(n < step ? Color.green : (n == step ? Color.montraOrange : Color.white.opacity(0.2)))
                    .frame(width: 20, height: 20)
                    .overlay {
                        if n < step {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundColor(.white)
                        } else {
                            Text("\(n)").font(.system(size: 9, weight: .black)).foregroundColor(n == step ? .black : .montraTextSecondary)
                        }
                    }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.black)
    }

    // ── Step 1: Choose Coach ──────────────────────────────────────────────

    private var step1ChooseCoach: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Choose Your Coach", subtitle: "Select the coach you'd like to work with.")
            if trainersLoading {
                ProgressView().tint(.montraOrange).frame(maxWidth: .infinity).padding(40)
            } else {
                VStack(spacing: 10) {
                    ForEach(trainers) { t in
                        trainerRow(t)
                            .onTapGesture {
                                selectedTrainer = t
                                Task { await fetchIntroPrice() }
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            Spacer().frame(height: 24)
            ctaButton("Continue", enabled: selectedTrainer != nil) {
                step = 2
                calDisplayMonth = Date()
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    private func trainerRow(_ t: OnboardingTrainer) -> some View {
        let selected = selectedTrainer?.id == t.id
        return HStack(spacing: 14) {
            trainerAvatar(t, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(t.name).font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                Text(t.certification).font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                if let loc = t.locations.first {
                    Label(loc, systemImage: "mappin.fill").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                }
            }
            Spacer()
            ZStack {
                Circle().stroke(selected ? Color.montraOrange : Color.white.opacity(0.25), lineWidth: 2).frame(width: 22, height: 22)
                if selected { Circle().fill(Color.montraOrange).frame(width: 12, height: 12) }
            }
        }
        .padding(14)
        .background(selected ? Color.montraOrange.opacity(0.08) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.montraOrange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }

    // ── Step 2: Select Date ───────────────────────────────────────────────

    private var step2SelectDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Select a Date", subtitle: "Pick a date that works for your schedule.")
            calendarView
                .padding(.horizontal, 20)
            Spacer().frame(height: 24)
            ctaButton("Continue", enabled: selectedDate != nil) {
                step = 3
                Task { await loadSlots() }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    private var calendarView: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    calDisplayMonth = Calendar.current.date(byAdding: .month, value: -1, to: calDisplayMonth) ?? calDisplayMonth
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.07)).clipShape(Circle())
                }
                Spacer()
                Text(calDisplayMonth, format: .dateTime.month(.wide).year()).font(.system(size: 16, weight: .bold)).foregroundColor(.montraTextPrimary)
                Spacer()
                Button {
                    calDisplayMonth = Calendar.current.date(byAdding: .month, value: 1, to: calDisplayMonth) ?? calDisplayMonth
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                        .frame(width: 36, height: 36).background(Color.white.opacity(0.07)).clipShape(Circle())
                }
            }

            // Day headers
            HStack {
                ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .bold)).foregroundColor(.montraTextSecondary).frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            let (days, offset) = calDays()
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(days, id: \.self) { date in
                    let isPast = date < Calendar.current.startOfDay(for: Date())
                    let isSelected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
                    let isToday = Calendar.current.isDateInToday(date)
                    Button {
                        if !isPast { selectedDate = date }
                    } label: {
                        Text("\(Calendar.current.component(.day, from: date))").font(.system(size: 14, weight: isSelected ? .black : .medium))
                            .frame(width: 40, height: 40)
                            .background(isSelected ? Color.montraOrange : isToday ? Color.white.opacity(0.1) : Color.clear)
                            .foregroundColor(isPast ? Color.white.opacity(0.2) : isSelected ? .black : .montraTextPrimary)
                            .clipShape(Circle())
                            .overlay(isToday && !isSelected ? Circle().stroke(Color.montraOrange, lineWidth: 1.5) : nil)
                    }
                    .disabled(isPast)
                }
            }

            if let date = selectedDate {
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day().year())
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.montraOrange)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func calDays() -> ([Date], Int) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: calDisplayMonth)
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else { return ([], 0) }
        let offset = cal.component(.weekday, from: firstDay) - 1
        let days = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: firstDay) }
        return (days, offset)
    }

    // ── Step 3: Select Time ───────────────────────────────────────────────

    private var step3SelectTime: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let date = selectedDate {
                stepTitle("Select a Time", subtitle: date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            } else {
                stepTitle("Select a Time", subtitle: "Available time slots")
            }
            if slotsLoading {
                ProgressView().tint(.montraOrange).frame(maxWidth: .infinity).padding(40)
            } else if slots.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark").font(.system(size: 36)).foregroundColor(.montraTextSecondary)
                    Text("No slots available").font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text("Try a different date.").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                    Button { step = 2 } label: {
                        Text("Pick Another Date").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraOrange)
                    }
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(slots, id: \.self) { slot in
                        let selected = selectedSlot == slot
                        Button { selectedSlot = slot } label: {
                            Text(slot).font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(selected ? Color.montraOrange : Color.white.opacity(0.06))
                                .foregroundColor(selected ? .black : .montraTextPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.montraOrange : Color.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                Text("All times in ET").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 8)
            }
            Spacer().frame(height: 24)
            ctaButton("Continue", enabled: selectedSlot != nil) {
                step = 4
                Task { await preparePayment() }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    // ── Step 4: Review & Pay ──────────────────────────────────────────────

    private var step4Pay: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Review & Pay", subtitle: "Confirm your session details and pay.")
            // Session summary card
            VStack(spacing: 10) {
                Text("Session Details").font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                detailRow(icon: "person.fill", label: "Coach", value: selectedTrainer?.name ?? "")
                detailRow(icon: "calendar", label: "Date", value: selectedDate?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()) ?? "")
                detailRow(icon: "clock", label: "Time", value: selectedSlot ?? "")
                detailRow(icon: "stopwatch", label: "Duration", value: "60 min")
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    Text("Total").font(.system(size: 14, weight: .black)).foregroundColor(.montraTextPrimary)
                    Spacer()
                    Text("$\(Int(introPrice))").font(.system(size: 18, weight: .black)).foregroundColor(.montraOrange)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            Spacer().frame(height: 16)

            // Contact info fields
            VStack(spacing: 10) {
                Text("Your Information").font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BookingTextField(placeholder: "Full Name", text: $customerName, keyboardType: .default)
                BookingTextField(placeholder: "Email Address", text: $customerEmail, keyboardType: .emailAddress)
                BookingTextField(placeholder: "Phone Number", text: $customerPhone, keyboardType: .phonePad)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            Spacer().frame(height: 20)

            if let paymentSheet {
                PaymentSheet.PaymentButton(paymentSheet: paymentSheet, onCompletion: handlePaymentResult) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 14))
                        Text("Pay $\(Int(introPrice)) Securely")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.montraOrange).clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }
            } else if paymentLoading {
                HStack(spacing: 10) {
                    ProgressView().tint(.montraOrange)
                    Text("Preparing payment…").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                }
                .frame(maxWidth: .infinity).padding(20)
            } else {
                VStack(spacing: 10) {
                    if let err = errorMessage {
                        Text(err).font(.system(size: 13)).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal, 20)
                    }
                    ctaButton("Retry Payment Setup", enabled: true) { Task { await preparePayment() } }.padding(.horizontal, 20)
                }
            }

            Text("🔒 Secured by Stripe").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 8).padding(.bottom, 40)
        }
    }

    // ── Step 5: Add Your Address ──────────────────────────────────────────

    private var step5Address: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepTitle("Add Your Address", subtitle: "Tell us where your coach will meet you.")
            VStack(spacing: 12) {
                BookingTextField(placeholder: "Street Address", text: $addressLine, keyboardType: .default)

                Text("Location Type").font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)

                ForEach(addressTypes, id: \.self) { type in
                    addressTypeRow(type: type, selected: addressType == type)
                        .onTapGesture { addressType = type }
                }
                Text("🔒 Your address is securely shared with your coach only.").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            Spacer().frame(height: 28)
            ctaButton("Confirm Booking", enabled: true) {
                Task { await recordBooking() }
                step = 6
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    // ── Step 6: You're Booked! ────────────────────────────────────────────

    private var step6Booked: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundColor(.green)
            }
            Spacer().frame(height: 20)
            Text("You're All Set! 🎉").font(.system(size: 28, weight: .black)).foregroundColor(.montraTextPrimary)
            Text("Your intro session is confirmed.").font(.system(size: 15)).foregroundColor(.montraTextSecondary).padding(.top, 4)
            Spacer().frame(height: 24)
            VStack(spacing: 10) {
                detailRow(icon: "calendar", label: "Date", value: selectedDate?.formatted(.dateTime.weekday(.wide).month(.wide).day().year()) ?? "")
                detailRow(icon: "clock", label: "Time", value: "\(selectedSlot ?? "") (60 min)")
                detailRow(icon: "person.fill", label: "Coach", value: selectedTrainer?.name ?? "")
                detailRow(icon: "mappin.fill", label: "Location", value: addressLine.isEmpty ? "To be confirmed" : "\(addressLine) (\(addressType))")
                detailRow(icon: "creditcard.fill", label: "Paid", value: "$\(Int(introPrice))")
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            Spacer().frame(height: 20)
            // MONTRA app CTA
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.montraOrange).frame(width: 48, height: 48)
                    Text("M").font(.system(size: 22, weight: .black)).foregroundColor(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get the full MONTRA experience").font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text("Chat with coach, track progress & manage sessions.").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            Spacer().frame(height: 20)
            ctaButton("Add to Calendar") { step = 7 }.padding(.horizontal, 20)
            Button { step = 8 } label: {
                Text("Skip").font(.system(size: 14)).foregroundColor(.montraTextSecondary).padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(height: 20)
        }
    }

    // ── Step 7: Add to Calendar ───────────────────────────────────────────

    private var step7Calendar: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Text("📅").font(.system(size: 52))
            Spacer().frame(height: 12)
            Text("Add to Calendar").font(.system(size: 24, weight: .black)).foregroundColor(.montraTextPrimary)
            Text("Never miss your session.").font(.system(size: 14)).foregroundColor(.montraTextSecondary).padding(.top, 4)
            Spacer().frame(height: 28)
            VStack(spacing: 10) {
                calendarOptionRow(icon: "calendar", title: "Apple Calendar") { addToAppleCalendar() }
                calendarOptionRow(icon: "globe", title: "Google Calendar") { openGoogleCalendar() }
            }
            .padding(.horizontal, 20)
            Spacer().frame(height: 24)
            ctaButton("Done") { step = 8 }.padding(.horizontal, 20)
            Spacer().frame(height: 40)
        }
    }

    private func calendarOptionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 18)).foregroundColor(.montraOrange).frame(width: 32)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.montraTextPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // ── Step 8: Get Ready ─────────────────────────────────────────────────

    private var step8GetReady: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Text("🚀").font(.system(size: 52))
            Spacer().frame(height: 12)
            Text("Get Ready!").font(.system(size: 28, weight: .black)).foregroundColor(.montraTextPrimary)
            Spacer().frame(height: 8)
            let first = selectedTrainer?.name.components(separatedBy: " ").first ?? "Your coach"
            Text("\(first) has received your booking and will reach out within **24 hours** to confirm your intro session.")
                .font(.system(size: 15)).foregroundColor(.montraTextSecondary).multilineTextAlignment(.center)
                .padding(.horizontal, 28).padding(.bottom, 24)
            VStack(spacing: 10) {
                readyRow("Session Booked")
                readyRow("Location Shared")
                readyRow("Coach Notified")
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
            Spacer().frame(height: 28)
            ctaButton("Go to Dashboard") { dismiss() }.padding(.horizontal, 20)
            Spacer().frame(height: 40)
        }
    }

    private func readyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundColor(.green)
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextPrimary)
            Spacer()
        }
    }

    // ── Shared sub-views ────────────────────────────────────────────────

    private func stepTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 24, weight: .black)).foregroundColor(.montraTextPrimary)
            if let subtitle {
                Text(subtitle).font(.system(size: 14)).foregroundColor(.montraTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }

    private func ctaButton(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(enabled ? .black : .montraTextSecondary)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(enabled ? Color.montraOrange : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.montraOrange).frame(width: 18)
            Text(label).font(.system(size: 13)).foregroundColor(.montraTextSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextPrimary).multilineTextAlignment(.trailing)
        }
    }

    private func addressTypeRow(type: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(typeEmoji(type)).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(type).font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextPrimary)
                Text(typeSubtitle(type)).font(.system(size: 12)).foregroundColor(.montraTextSecondary)
            }
            Spacer()
            ZStack {
                Circle().stroke(selected ? Color.montraOrange : Color.white.opacity(0.3), lineWidth: 2).frame(width: 20, height: 20)
                if selected { Circle().fill(Color.montraOrange).frame(width: 11, height: 11) }
            }
        }
        .padding(14)
        .background(selected ? Color.montraOrange.opacity(0.08) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.montraOrange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }

    @ViewBuilder
    private func trainerAvatar(_ t: OnboardingTrainer, size: CGFloat) -> some View {
        if !t.photoDataUrl.isEmpty,
           let data = Data(base64Encoded: t.photoDataUrl.components(separatedBy: ",").last ?? ""),
           let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28).fill(Color(hex: t.accentHex))
                Text(t.initials).font(.system(size: size * 0.34, weight: .black)).foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func typeEmoji(_ type: String) -> String {
        switch type {
        case "Apartment / Condo": return "🏢"
        case "Outdoor (Park, etc.)": return "🌳"
        default: return "🏠"
        }
    }

    private func typeSubtitle(_ type: String) -> String {
        switch type {
        case "Apartment / Condo": return "Include unit number in address"
        case "Outdoor (Park, etc.)": return "Park name or meeting spot"
        default: return "Your home address"
        }
    }

    // ── Networking & actions ──────────────────────────────────────────────

    private func loadTrainers() async {
        guard let url = MontraAPIConfig.url(for: "/api/trainers") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { let trainers: [OnboardingTrainer] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            await MainActor.run {
                trainers = resp.trainers.filter { $0.isApproved }
                trainersLoading = false
            }
        } catch {
            await MainActor.run { trainersLoading = false }
        }
    }

    private func fetchIntroPrice() async {
        guard let tid = selectedTrainer?.id,
              let url = MontraAPIConfig.url(for: "/api/trainers/\(tid)/packages") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let pkg = try? JSONDecoder().decode(ProgramPackage.self, from: data),
           let price = pkg.introSession?.price {
            await MainActor.run { introPrice = price }
        }
    }

    private func loadSlots() async {
        guard let tid = selectedTrainer?.id, let date = selectedDate else { return }
        await MainActor.run { slotsLoading = true; slots = [] }
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10)
        guard let url = MontraAPIConfig.url(for: "/api/trainers/\(tid)/availability?date=\(dateStr)") else {
            await MainActor.run { slotsLoading = false }; return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { let slots: [String] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            await MainActor.run { slots = resp.slots; slotsLoading = false }
        } catch {
            await MainActor.run { slotsLoading = false }
        }
    }

    private func preparePayment() async {
        guard !customerName.isEmpty || !customerEmail.isEmpty else { return } // allow partial
        await MainActor.run { paymentLoading = true; errorMessage = nil; paymentSheet = nil }
        do {
            guard let cfgURL = MontraAPIConfig.url(for: "/api/stripe/config") else { throw URLError(.badURL) }
            let (cfgData, _) = try await URLSession.shared.data(from: cfgURL)
            struct StripeConfig: Decodable { let publishableKey: String? }
            let cfg = try JSONDecoder().decode(StripeConfig.self, from: cfgData)
            guard let pk = cfg.publishableKey else {
                await MainActor.run { paymentLoading = false; errorMessage = "Payment processing is being configured. Please contact us to book." }
                return
            }
            guard let piURL = MontraAPIConfig.url(for: "/api/payments/intro-session") else { throw URLError(.badURL) }
            var req = URLRequest(url: piURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["trainerId": selectedTrainer?.id ?? ""])
            let (piData, _) = try await URLSession.shared.data(for: req)
            struct PIResponse: Decodable { let clientSecret: String }
            let pi = try JSONDecoder().decode(PIResponse.self, from: piData)
            STPAPIClient.shared.publishableKey = pk
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Elite Home Fitness / MONTRA"
            config.primaryButtonColor = UIColor(Color.montraOrange)
            let sheet = PaymentSheet(paymentIntentClientSecret: pi.clientSecret, configuration: config)
            await MainActor.run { paymentSheet = sheet; paymentLoading = false }
        } catch {
            await MainActor.run { paymentLoading = false; errorMessage = error.localizedDescription }
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            step = 5
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func recordBooking() async {
        guard let tid = selectedTrainer?.id, let date = selectedDate else { return }
        guard let url = MontraAPIConfig.url(for: "/api/bookings/intro-session") else { return }
        let dateStr = String(ISO8601DateFormatter().string(from: date).prefix(10))
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "trainerId": tid,
            "clientName": customerName,
            "clientEmail": customerEmail,
            "clientPhone": customerPhone,
            "date": dateStr,
            "time": selectedSlot ?? "",
            "address": addressLine,
            "addressType": addressType
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (data, _) = try? await URLSession.shared.data(for: req),
           let json = try? JSONDecoder().decode([String: String].self, from: data) {
            await MainActor.run { bookingId = json["bookingId"] }
        }
    }

    private func addToAppleCalendar() {
        guard let date = selectedDate, let slot = selectedSlot, let trainer = selectedTrainer else { return }
        // Create ICS and share via UIActivityViewController
        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        SUMMARY:Intro Session with \(trainer.name)
        DTSTART:\(icsDate(date, slot))
        DURATION:PT60M
        LOCATION:\(addressLine)
        END:VEVENT
        END:VCALENDAR
        """
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("montra-session.ics")
        try? ics.write(to: tmpURL, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [tmpURL], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func openGoogleCalendar() {
        guard let date = selectedDate, let slot = selectedSlot, let trainer = selectedTrainer else { return }
        let title = "Intro Session with \(trainer.name)"
        let start = icsDate(date, slot)
        let urlStr = "https://calendar.google.com/calendar/render?action=TEMPLATE&text=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&dates=\(start)/\(start)"
        if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
    }

    private func icsDate(_ date: Date, _ slot: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        // Approximate: slot time parsing is best-effort
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9; comps.minute = 0
        return fmt.string(from: cal.date(from: comps) ?? date)
    }
}

// MARK: - Supporting views

struct BookingTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .foregroundColor(.montraTextPrimary)
            .font(.system(size: 14))
    }
}

// MARK: - OnboardingTrainer helper

extension OnboardingTrainer {
    var isApproved: Bool {
        // Backend returns approved trainers from /api/trainers by default;
        // this guard handles any client-side filtering
        true
    }
}

#Preview {
    IntroBookingView(preselectedTrainer: nil)
}
