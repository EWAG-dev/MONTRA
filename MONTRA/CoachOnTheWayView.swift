import SwiftUI
import MapKit

// MARK: - Coach tracking simulation

/// Simulates the coach's current position and ETA.
/// Real GPS would replace the computed coords with a live endpoint
/// (e.g. GET /api/sessions/:id/coach-location).
struct CoachTrack {
    let coachCoordinate: CLLocationCoordinate2D
    let homeCoordinate: CLLocationCoordinate2D
    let routePoints: [CLLocationCoordinate2D]
    let etaMinutes: Int
    let distanceMiles: Double
    let region: MKCoordinateRegion

    /// Produces a deterministic simulated track from a session.
    /// Direction and distance vary by trainer ID to look distinct per-coach.
    static func simulate(trainerName: String, etaMinutes: Int) -> CoachTrack {
        // Boston-area home (stand-in until user's real address is stored)
        let home = CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)

        // Derive a pseudo-random bearing from the trainer name so each coach
        // approaches from a different direction.
        let seed = trainerName.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let bearingDeg = Double(seed % 360)
        let bearingRad = bearingDeg * .pi / 180

        // Distance = ETA × 15 mph average city speed
        let distMiles = Double(etaMinutes) * 15.0 / 60.0
        let distDegLat = distMiles / 69.0
        let distDegLon = distMiles / (69.0 * cos(home.latitude * .pi / 180))

        let coachLat = home.latitude  + distDegLat * cos(bearingRad)
        let coachLon = home.longitude + distDegLon * sin(bearingRad)
        let coach = CLLocationCoordinate2D(latitude: coachLat, longitude: coachLon)

        // Route: coach → slight curve midpoint → home (makes the line look less artificial)
        let midLat = (coach.latitude + home.latitude)  / 2 + distDegLat * 0.08
        let midLon = (coach.longitude + home.longitude) / 2 - distDegLon * 0.06
        let mid = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

        // Region that comfortably fits both endpoints with padding
        let span = MKCoordinateSpan(
            latitudeDelta: abs(coachLat - home.latitude) * 2.6 + 0.02,
            longitudeDelta: abs(coachLon - home.longitude) * 2.6 + 0.02
        )
        let center = CLLocationCoordinate2D(
            latitude:  (coach.latitude  + home.latitude)  / 2,
            longitude: (coach.longitude + home.longitude) / 2
        )

        return CoachTrack(
            coachCoordinate: coach,
            homeCoordinate: home,
            routePoints: [coach, mid, home],
            etaMinutes: etaMinutes,
            distanceMiles: distMiles,
            region: MKCoordinateRegion(center: center, span: span)
        )
    }
}

// MARK: - Full tracking sheet

struct CoachOnTheWayView: View {
    let session: SessionItem
    let initialETA: Int

    @State private var etaMinutes: Int
    @State private var track: CoachTrack
    @Environment(\.dismiss) private var dismiss

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init(session: SessionItem, initialETA: Int) {
        self.session = session
        self.initialETA = initialETA
        let eta = max(1, initialETA)
        _etaMinutes = State(initialValue: eta)
        _track = State(initialValue: CoachTrack.simulate(trainerName: session.trainer, etaMinutes: eta))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)

                // Header
                HStack(spacing: 8) {
                    PulsingDot(color: .green)
                    Text("COACH ON THE WAY")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.green)
                        .kerning(1.5)
                    Text("🚗")
                        .font(.system(size: 14))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)

                // Coach info row
                HStack(spacing: 14) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#1C1C1E"))
                            .frame(width: 56, height: 56)
                        Text(String(session.trainer.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.white)
                        Circle()
                            .stroke(Color.montraOrange, lineWidth: 2)
                            .frame(width: 56, height: 56)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.trainer)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Heading to you")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text("\(etaMinutes) min away")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.1))

                // Map
                mapView
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(Rectangle())

                Divider().background(Color.white.opacity(0.1))

                // Stats strip
                statsStrip

                Spacer()
            }
        }
        .onReceive(timer) { _ in
            if etaMinutes > 1 {
                etaMinutes -= 1
                track = CoachTrack.simulate(trainerName: session.trainer, etaMinutes: etaMinutes)
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(initialPosition: .region(track.region)) {
            // Route polyline
            MapPolyline(coordinates: track.routePoints)
                .stroke(
                    .orange,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [])
                )

            // Home pin
            Annotation("Home", coordinate: track.homeCoordinate, anchor: .center) {
                ZStack {
                    Circle()
                        .fill(Color.montraOrange)
                        .frame(width: 38, height: 38)
                        .shadow(color: .orange.opacity(0.5), radius: 8)
                    Image(systemName: "house.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            // Coach pin
            Annotation(session.trainer, coordinate: track.coachCoordinate, anchor: .center) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 42, height: 42)
                        .shadow(color: .black.opacity(0.3), radius: 6)
                    Image(systemName: "car.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .mapStyle(.standard(emphasis: .muted))
        .mapControlVisibility(.hidden)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "clock",
                value: "\(etaMinutes) MIN",
                label: "ETA"
            )
            stripDivider
            statCell(
                icon: nil,
                value: String(format: "%.1f MI", track.distanceMiles),
                label: "DISTANCE"
            )
            stripDivider
            statCell(
                icon: nil,
                value: "YOUR COACH",
                label: session.trainer
            )
        }
        .padding(.vertical, 18)
        .background(Color(hex: "#111111"))
    }

    private func statCell(icon: String?, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
                Text(value)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .kerning(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 36)
    }
}

// MARK: - Pulsing green dot

struct PulsingDot: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1.6 : 1.0)
                .opacity(pulse ? 0 : 0.8)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Home screen pill

/// Compact Uber-style pill shown on the Dashboard when the coach is en route.
struct CoachOnTheWayPill: View {
    let trainerName: String
    let etaMinutes: Int
    let action: () -> Void

    private var firstName: String {
        trainerName.components(separatedBy: " ").first ?? trainerName
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                PulsingDot(color: .green)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Coach \(firstName) is on the way")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Tap to track · \(etaMinutes) min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.green)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("\(etaMinutes) min")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.black)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.green)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#111827"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: Color.green.opacity(0.18), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
