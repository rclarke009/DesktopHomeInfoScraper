//
//  StormCatalogListView.swift
//  DesktopHomeInfoScraper
//
//  List of catalog storms; add, edit, delete. Opens StormCatalogEditView for add/edit.
//

import SwiftUI
import CoreData

struct StormCatalogListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var catalogStorms: [CatalogStorm] = []
    @State private var showingAddStorm = false
    @State private var stormToEdit: CatalogStorm?
    @State private var stormToDelete: CatalogStorm?
    @State private var showingDeleteConfirmation = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationView {
            List {
                ForEach(catalogStorms, id: \.objectID) { storm in
                    StormCatalogRowView(storm: storm, dateFormatter: dateFormatter)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            stormToEdit = storm
                        }
                        .contextMenu {
                            Button("Edit", action: { stormToEdit = storm })
                            Button("Delete", role: .destructive, action: {
                                stormToDelete = storm
                                showingDeleteConfirmation = true
                            })
                        }
                }
            }
            .navigationTitle("Storm Catalog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: { dismiss() })
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddStorm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                reloadStorms()
            }
            .sheet(isPresented: $showingAddStorm) {
                StormCatalogEditView(mode: .add, storm: nil, onDismiss: {
                    showingAddStorm = false
                    reloadStorms()
                })
                .frame(width: 620, height: 500)
                .presentationDetents([.large])
                .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: Binding(
                get: { stormToEdit != nil },
                set: { if !$0 { stormToEdit = nil } }
            )) {
                if let storm = stormToEdit {
                    StormCatalogEditView(mode: .edit, storm: storm, onDismiss: {
                        stormToEdit = nil
                        reloadStorms()
                    })
                    .frame(width: 620, height: 500)
                    .presentationDetents([.large])
                    .environment(\.managedObjectContext, viewContext)
                }
            }
            .alert("Delete storm?", isPresented: $showingDeleteConfirmation, presenting: stormToDelete) { storm in
                Button("Cancel", role: .cancel) {
                    stormToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let s = stormToDelete {
                        StormCatalogService.deleteCatalogStorm(s, context: viewContext)
                        stormToDelete = nil
                        reloadStorms()
                    }
                }
            } message: { storm in
                Text("This will remove \"\(storm.name ?? "")\" and all its images from the catalog.")
            }
        }
    }

    private func reloadStorms() {
        catalogStorms = StormCatalogService.fetchAllCatalogStorms(context: viewContext)
    }
}

struct StormCatalogRowView: View {
    let storm: CatalogStorm
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            if let primary = StormCatalogService.primaryImage(for: storm),
               let nsImage = StormCatalogService.loadImage(for: primary) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipped()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(storm.name ?? "Unnamed")
                    .font(.headline)
                Text(dateFormatter.string(from: storm.stormDate ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let count = storm.images?.count, count > 0 {
                    Text("\(count) image\(count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

