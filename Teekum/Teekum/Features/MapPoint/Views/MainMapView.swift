// xcode: set sdk=iOS

//
//  MainMapView.swift
//  
//
//  Created by Adiat Rahman on 05/11/26.
//

import SwiftUI
import MapKit

public struct MainMapView: View {
//    @State private var viewModel = MapPointViewModel()
    
    public var body: some View {
        ZStack(){
            Map()  
        }
    }
    
}

#Preview {
    MainMapView()
}
