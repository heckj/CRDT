//
//  ContentView.swift
//  CRDTExample
//
//  Created by Joseph Heck on 8/24/22.
//

import SwiftUI

struct ContentView: View {
    private var @StateObject: foo
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
