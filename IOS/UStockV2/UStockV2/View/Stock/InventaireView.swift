import SwiftUI

struct InventaireView: View {
    @StateObject private var stockViewModel = StockViewModel()
    @State private var isRefreshing = false
    @State private var selectedProduct: Produit?
    @State private var showProductDetail = false
    @State private var showNotificationSettings = false
    @State private var expiringProductsCount = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "C1DDF9").edgesIgnoringSafeArea(.all)
                
                VStack {
                    // 🔹 En-tête avec titre et boutons
                    headerView
                    
                    // 🔹 Badge de notification d'expiration
                    if expiringProductsCount > 0 {
                        expirationBanner
                    }

                    // 🔹 Carrousel des produits qui expirent bientôt
                    CarrouselProduitsBientotPerimes(produits: stockViewModel.stocks)
                        .padding(.vertical, 10)

                    // 🔹 Liste des produits avec pull-to-refresh
                    ScrollView {
                        // Pull-to-refresh control
                        PullToRefresh(coordinateSpaceName: "pullToRefresh", onRefresh: refreshData)
                        
                        if stockViewModel.isLoading && stockViewModel.stocks.isEmpty {
                            ProgressView("Chargement des produits...")
                                .padding()
                        } else if stockViewModel.stocks.isEmpty {
                            VStack {
                                Text("Aucun produit dans votre inventaire")
                                    .font(.headline)
                                    .padding()
                                Text("Utilisez le scanner pour ajouter des produits")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(stockViewModel.stocks) { produit in
                                    ProduitRowView(produit: produit)
                                        .foregroundColor(Color(.black))
                                        .onTapGesture {
                                            selectedProduct = produit
                                            showProductDetail = true
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .coordinateSpace(name: "pullToRefresh")

                    Spacer() // Ceci pousse tout le contenu vers le haut

                    // Barre de navigation
                    navigationBar
                }
            }
            .onAppear {
                // Charger les produits quand la vue apparaît
                stockViewModel.fetchStocks()
                
                // Demander les autorisations de notification si ce n'est pas fait
                checkNotificationPermissions()
                
                // Calculer le nombre de produits qui expirent
                updateExpiringProductsCount()
            }
            .onReceive(stockViewModel.$stocks) { stocks in
                // Utiliser onReceive au lieu de onChange pour éviter le problème Equatable
                updateExpiringProductsCount()
            }
            .alert(stockViewModel.errorMessage ?? "Erreur", isPresented: $stockViewModel.showErrorAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Succès", isPresented: $stockViewModel.showSuccessMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(stockViewModel.successMessage ?? "Opération réussie")
            }
            // Navigation vers les détails du produit
            .sheet(isPresented: $showProductDetail) {
                if let product = selectedProduct {
                    ProductDetailView(produit: product)
                }
            }
            // Navigation vers les paramètres de notification
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            // Observer les taps sur notifications
            .onReceive(NotificationCenter.default.publisher(for: .didTapNotificationForProduct)) { notification in
                if let product = notification.userInfo?["product"] as? Produit {
                    selectedProduct = product
                    showProductDetail = true
                }
            }
        }
    }
    
    // MARK: - Composants de vue
    
    private var headerView: some View {
        HStack {
            Text("INVENTAIRE")
                .font(.custom("ChauPhilomeneOne-Regular", size: 32))
                .fontWeight(.bold)
                .padding(.leading, 20)
                .foregroundColor(Color(.black))
            
            Spacer()
            
            // Bouton notifications
            Button(action: {
                showNotificationSettings = true
            }) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(notificationButtonColor)
                    
                    // Badge de notification
                    if expiringProductsCount > 0 {
                        Text("\(expiringProductsCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .padding(.trailing, 10)
            
            // Bouton paramètres
            Button(action: {
                // Action pour les paramètres généraux
            }) {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(Color(.black))
            }
            .padding(.trailing, 20)
        }
        .padding(.top, 20)
    }
    
    private var expirationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(expiringProductsCount) produit\(expiringProductsCount > 1 ? "s" : "") expire\(expiringProductsCount > 1 ? "nt" : "") bientôt")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("Consultez vos notifications pour plus de détails")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Voir") {
                showNotificationSettings = true
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: expiringProductsCount)
    }
    
    private var navigationBar: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                NavigationLink(destination: InventaireView()) {
                    VStack(spacing: 0) {
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 30))
                        Text("Inventaire")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
                NavigationLink(destination: Text("Liste")) {
                    VStack(spacing: 0) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 30))
                        Text("Liste")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
                // Espace pour le bouton Scanner qui va "flotter" au-dessus
                Spacer()
                Spacer()
                NavigationLink(destination: ProfileView()) {
                    VStack(spacing: 0) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                        Text("Profil")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
                NavigationLink(destination: StatsView()) {
                    VStack(spacing: 0) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 30))
                        Text("Statistiques")
                            .font(.system(size: 12))
                    }
                }
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
            .background(Color.white)
            .foregroundColor(Color.black)
            .shadow(radius: 1, y: -1)
            .edgesIgnoringSafeArea(.bottom)
        }
        .overlay(
            // Bouton Scanner flottant
            NavigationLink(destination: BarcodeScannerView()) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "156585"))
                        .frame(width: 65, height: 65)
                        .shadow(radius: 2, y: 1)
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
            .offset(y: -25),
            alignment: .center
        )
    }
    
    // MARK: - Propriétés calculées
    
    private var notificationButtonColor: Color {
        switch NotificationManager.shared.authorizationStatus {
        case .authorized:
            return expiringProductsCount > 0 ? .orange : Color(hex: "156585")
        case .denied:
            return .red
        case .notDetermined:
            return .gray
        default:
            return .gray
        }
    }
    
    // MARK: - Fonctions
    
    private func refreshData() {
        isRefreshing = true
        stockViewModel.fetchStocks()
        
        // Mettre à jour les notifications après le rafraîchissement
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isRefreshing = false
            stockViewModel.forceUpdateNotifications()
        }
    }
    
    private func updateExpiringProductsCount() {
        let newCount = stockViewModel.getExpiringProductsCount(days: 3)
        
        // Utiliser withAnimation pour animer le changement
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            expiringProductsCount = newCount
        }
    }
    
    private func checkNotificationPermissions() {
        NotificationManager.shared.checkAuthorizationStatus()
        
        // Si les notifications ne sont pas configurées, proposer de les activer
        if NotificationManager.shared.authorizationStatus == .notDetermined {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // Afficher une suggestion discrète après 2 secondes
                // Cette logique peut être déplacée vers une vue dédiée si nécessaire
            }
        }
    }
}

#Preview {
    InventaireView()
}
