//
//  ContentView.swift
//  MapKitTutorial
//
//  Created by Ioannis Pechlivanis on 27.02.25.
//

import SwiftUI
import MapKit
import Observation

struct ContentView: View {
    
    @State private var vm = MapViewModel()
    
    var body: some View {
        NavigationStack {
            Map(position: $vm.cameraPosition) {
                
                Marker("My Home", coordinate: .home)
                
                UserAnnotation()
                
                if let currentPlace = vm.currentPlace {
                    Annotation(currentPlace.name ?? "", coordinate: currentPlace.location?.coordinate ?? .home) {
                        Image(systemName: "mappin")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .padding(4)
                            .background(.mint, in: .circle)
                            .contextMenu {
                                Button("Get Direction") {
                                    Task {
                                        await vm.calculateRoute(destination: currentPlace.location?.coordinate ?? .home)
                                    }
                                }
                                Button("Look Around Scene") {
                                    Task {
                                        await vm.getLookAroundScene(from: currentPlace.location?.coordinate ?? .home)
                                        guard let _ = vm.lookAroundScene else { return }
                                        vm.isShowingLookAroundScene = true
                                    }
                                }
                            }
                    }
                }
                
                if let route = vm.route {
                    MapPolyline(route.polyline)
                        .stroke(.mint, lineWidth: 8)
                }
                
                Annotation("Allianz Arena", coordinate: .allianzArena) {
                    Image("bayern")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .background(.gray, in: .rect(cornerRadius: 10))
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapUserLocationButton()
                MapPitchToggle()
                MapScaleView()
            }
            .searchable(text: $vm.searchText)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onSubmit(of: .search) {
                vm.getCoordinates(for: vm.searchText)
            }
            .onAppear {
                vm.locationManager.requestWhenInUseAuthorization()
            }
            .lookAroundViewer(isPresented: $vm.isShowingLookAroundScene, initialScene: vm.lookAroundScene)
        }
    }
}

@Observable
class MapViewModel {
    var searchText: String = ""
    
    var currentPlace: CLPlacemark?
    
    var cameraPosition: MapCameraPosition = .region(.init(center: .home, latitudinalMeters: 1000, longitudinalMeters: 1000))
    
    var locationManager = CLLocationManager()
    
    var route: MKRoute?
    
    var lookAroundScene: MKLookAroundScene?
    var isShowingLookAroundScene = false
    
    
    init() {
        Task {
            await setUserLocation()
        }
    }
    
    func getLookAroundScene(from coordinate: CLLocationCoordinate2D) async {
        do {
            self.lookAroundScene = try await MKLookAroundSceneRequest(coordinate: coordinate).scene
        } catch {
            print(error.localizedDescription)
        }
    }

    
    func getCoordinates(for locationName: String) {
        Task {
            guard let placemark = try? await CLGeocoder().geocodeAddressString(locationName).first else {
                return
            }
            
            self.currentPlace = placemark
            
            guard let location = placemark.location else {
                print("No Location")
                return
            }
            
            self.cameraPosition = .region(.init(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000))
            
        }
    }
    
    private func getUserLocation() async -> CLLocationCoordinate2D? {
        let updates = CLLocationUpdate.liveUpdates()
        do {
            let update = try await updates.first() { $0.location?.coordinate != nil }
            return update?.location?.coordinate
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func setUserLocation() async {
        let updates = CLLocationUpdate.liveUpdates()
        
        do {
            let update = try await updates.first() { $0.location?.coordinate != nil }
            guard let userLocation = update?.location?.coordinate else { return }
            self.cameraPosition = .region(.init(center: userLocation, latitudinalMeters: 1000, longitudinalMeters: 1000))
        } catch {
            print("error getting user location")
            return
        }
    }
    
    func calculateRoute(destination: CLLocationCoordinate2D) async {
        let directionRequest = MKDirections.Request()
        
        guard let userLocation = await getUserLocation() else { return }
                
        directionRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        directionRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        directionRequest.transportType = .automobile
        
        Task {
            let directions = MKDirections(request: directionRequest)
            let response = try? await directions.calculate()
            self.route = response?.routes.first
        }
    }
    
    
    
}

extension CLLocationCoordinate2D {
    static var home = CLLocationCoordinate2D(latitude: 51.4410628, longitude: 7.3402022)
    static var allianzArena = CLLocationCoordinate2D(latitude: 48.2187901, longitude: 11.6236227)
}

#Preview {
    ContentView()
}
