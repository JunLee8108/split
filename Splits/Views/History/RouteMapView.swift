//
//  RouteMapView.swift
//  Splits
//
//  경로를 구간 색으로 나눠 그린다. 달리기는 Run, 회복은 Rest.
//

import CoreLocation
import MapKit
import SwiftUI

/// 같은 스텝에 속한 연속 점 묶음. 경계 점은 양쪽에 다 넣어 선이 끊기지 않게 한다.
nonisolated struct RouteSegment: Identifiable {
    let id: Int
    let kind: StepKind
    let coordinates: [CLLocationCoordinate2D]

    static func build(from route: [RoutePoint], kinds: [Int: StepKind]) -> [RouteSegment] {
        var result: [RouteSegment] = []
        var current: [CLLocationCoordinate2D] = []
        var currentStep: Int?

        for point in route {
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            if let step = currentStep, step != point.stepIndex {
                current.append(coordinate)
                result.append(RouteSegment(id: result.count, kind: kinds[step] ?? .run, coordinates: current))
                current = []
            }
            currentStep = point.stepIndex
            current.append(coordinate)
        }
        if let step = currentStep, current.count >= 2 {
            result.append(RouteSegment(id: result.count, kind: kinds[step] ?? .run, coordinates: current))
        }
        return result
    }
}

nonisolated enum RouteGeometry {
    /// 경로 전체가 들어가는 영역. 여백 30%, 최소 폭 500m 정도.
    static func region(for route: [RoutePoint]) -> MKCoordinateRegion? {
        guard let first = route.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in route {
            minLat = min(minLat, point.latitude); maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude); maxLon = max(maxLon, point.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.3, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.3, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

struct RouteMapView: View {
    let route: [RoutePoint]
    let kinds: [Int: StepKind]
    var interactive = true

    private var segments: [RouteSegment] { RouteSegment.build(from: route, kinds: kinds) }

    var body: some View {
        if let region = RouteGeometry.region(for: route) {
            Map(
                initialPosition: .region(region),
                interactionModes: interactive ? [.pan, .zoom] : []
            ) {
                ForEach(segments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.kind.tint, lineWidth: 4)
                }
                if let start = route.first {
                    Annotation("출발", coordinate: CLLocationCoordinate2D(latitude: start.latitude, longitude: start.longitude)) {
                        Circle()
                            .fill(.white)
                            .stroke(Color.primary, lineWidth: 2)
                            .frame(width: 10, height: 10)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(interactive ? .automatic : .hidden)
        } else {
            ContentUnavailableView("경로가 없어요", systemImage: "map", description: Text("GPS 점이 기록되지 않은 세션입니다."))
        }
    }
}

/// 목록 행에 쓰는 가벼운 경로 스케치. 지도를 띄우지 않고 선만 그린다.
struct RouteSketch: View {
    let route: [RoutePoint]
    let kinds: [Int: StepKind]

    var body: some View {
        Canvas { context, size in
            guard route.count >= 2 else { return }
            let lats = route.map(\.latitude)
            let lons = route.map(\.longitude)
            guard let minLat = lats.min(), let maxLat = lats.max(),
                  let minLon = lons.min(), let maxLon = lons.max() else { return }

            // 위도 1도와 경도 1도의 실제 길이가 다르다. 경도를 cos(위도)로 줄인다.
            let scaleLon = cos((minLat + maxLat) / 2 * .pi / 180)
            let width = max((maxLon - minLon) * scaleLon, 1e-6)
            let height = max(maxLat - minLat, 1e-6)
            let inset: CGFloat = 3
            let scale = min((size.width - inset * 2) / width, (size.height - inset * 2) / height)
            let drawnWidth = width * scale
            let drawnHeight = height * scale
            let originX = (size.width - drawnWidth) / 2
            let originY = (size.height - drawnHeight) / 2

            func point(latitude: Double, longitude: Double) -> CGPoint {
                CGPoint(
                    x: originX + (longitude - minLon) * scaleLon * scale,
                    y: originY + (maxLat - latitude) * scale
                )
            }

            for segment in RouteSegment.build(from: route, kinds: kinds) {
                var path = Path()
                let points = segment.coordinates.map { point(latitude: $0.latitude, longitude: $0.longitude) }
                guard let first = points.first else { continue }
                path.move(to: first)
                for p in points.dropFirst() { path.addLine(to: p) }
                context.stroke(path, with: .color(segment.kind.tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
