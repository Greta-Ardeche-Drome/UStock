import SwiftUI
import Combine

// Structure pour parser les données du produit
struct ProductDTO: Codable {
    let id: Int
    let barcode: String
    let product_name: String
    let brand: String?
    let content_size: String?
    let nutriscore: String?
    let image_url: String?
}

// Structure pour parser les données du stock
struct StockDTO: Codable, Identifiable {
    let id: Int
    let quantity: Int
    let expiration_date: String
    let product: ProductDTO
}

class StockViewModel: ObservableObject {
    @Published var stocks: [Produit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showErrorAlert = false
    @Published var showSuccessMessage = false
    @Published var successMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Token d'authentification
    var authToken: String?
    
    init() {
        // Récupérer le token depuis UserDefaults
        self.authToken = UserDefaults.standard.string(forKey: "authToken")
        print("Token récupéré dans StockViewModel : \(String(describing: authToken))")
        
        // Observer les notifications de mise à jour des notifications d'expiration
        NotificationCenter.default.publisher(for: .shouldUpdateExpirationNotifications)
            .sink { [weak self] _ in
                self?.updateExpirationNotifications()
            }
            .store(in: &cancellables)
        
        // Observer les actions depuis les notifications
        NotificationCenter.default.publisher(for: .shouldNavigateToProduct)
            .sink { [weak self] notification in
                if let productId = notification.userInfo?["productId"] as? UUID {
                    self?.handleNavigateToProduct(productId: productId)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .shouldMarkProductConsumed)
            .sink { [weak self] notification in
                if let stockId = notification.userInfo?["stockId"] as? Int {
                    self?.handleMarkProductConsumed(stockId: stockId)
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchStocks() {
        guard let token = authToken else {
            self.errorMessage = "Vous devez être connecté pour accéder à cette fonctionnalité"
            self.showErrorAlert = true
            return
        }
        
        isLoading = true
        
        let url = URL(string: "https://api.ustock.pro:8443/stocks/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        print("🔄 Récupération des stocks avec token: \(token)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Erreur réseau : \(error.localizedDescription)")
                    self.errorMessage = "Erreur lors de la récupération des produits: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Pas de réponse HTTP")
                    self.errorMessage = "Pas de réponse du serveur"
                    self.showErrorAlert = true
                    return
                }
                
                guard let data = data else {
                    print("❌ Données vides")
                    self.errorMessage = "Aucune donnée reçue"
                    self.showErrorAlert = true
                    return
                }
                
                // Log des données brutes
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📦 Données reçues: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        let decoder = JSONDecoder()
                        let stocksDTO = try decoder.decode([StockDTO].self, from: data)
                        
                        print("✅ \(stocksDTO.count) produits dans le stock")
                        
                        let produits = stocksDTO.map { stockDTO -> Produit in
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd"
                            
                            // Calculer les jours restants
                            let expirationDate = dateFormatter.date(from: stockDTO.expiration_date) ?? Date()
                            let joursRestants = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                            
                            // Formater la date pour l'affichage
                            dateFormatter.dateFormat = "dd-MM-yy"
                            let formattedDate = dateFormatter.string(from: expirationDate)
                            
                            return Produit(
                                nom: stockDTO.product.product_name,
                                peremption: formattedDate,
                                joursRestants: joursRestants,
                                quantite: stockDTO.quantity,
                                image: "",  // Champ vide car nous utilisons directement l'URL d'image
                                stockId: stockDTO.id,
                                productDetails: ProductDetails(
                                    barcode: stockDTO.product.barcode,
                                    brand: stockDTO.product.brand ?? "",
                                    contentSize: stockDTO.product.content_size ?? "",
                                    nutriscore: stockDTO.product.nutriscore ?? "",
                                    imageUrl: stockDTO.product.image_url ?? ""
                                )
                            )
                        }
                        
                        self.stocks = produits
                        
                        // 🔔 Mettre à jour les notifications d'expiration après avoir récupéré les stocks
                        self.updateExpirationNotifications()
                        
                    } catch {
                        print("❌ Erreur décodage JSON : \(error)")
                        self.errorMessage = "Erreur lors de la récupération des produits: \(error.localizedDescription)"
                        self.showErrorAlert = true
                    }
                } else {
                    print("❌ Mauvais code HTTP: \(httpResponse.statusCode)")
                    self.errorMessage = "Erreur serveur: \(httpResponse.statusCode)"
                    self.showErrorAlert = true
                }
            }
        }.resume()
    }
    
    // Nouvelle méthode pour supprimer un produit
    func deleteProduct(stockId: Int, completion: @escaping (Bool) -> Void) {
        guard let token = authToken else {
            self.errorMessage = "Vous devez être connecté pour supprimer un produit"
            self.showErrorAlert = true
            completion(false)
            return
        }
        
        isLoading = true
        
        let url = URL(string: "https://api.ustock.pro:8443/stocks/\(stockId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        print("🗑️ Suppression du produit avec stockId: \(stockId)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Erreur réseau : \(error.localizedDescription)")
                    self.errorMessage = "Erreur lors de la suppression du produit: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Pas de réponse HTTP")
                    self.errorMessage = "Pas de réponse du serveur"
                    self.showErrorAlert = true
                    completion(false)
                    return
                }
                
                // Log du statut
                print("🔄 Statut de la réponse: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Si la suppression est réussie, on rafraîchit la liste des stocks
                    print("✅ Produit supprimé avec succès!")
                    
                    // Retirer le produit de la liste locale
                    if let index = self.stocks.firstIndex(where: { $0.stockId == stockId }) {
                        self.stocks.remove(at: index)
                    }
                    
                    // 🔔 Mettre à jour les notifications après suppression
                    self.updateExpirationNotifications()
                    
                    self.successMessage = "Produit supprimé avec succès"
                    self.showSuccessMessage = true
                    completion(true)
                } else {
                    print("❌ Échec de la suppression, code HTTP: \(httpResponse.statusCode)")
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📦 Réponse d'erreur: \(responseString)")
                    }
                    
                    self.errorMessage = "Erreur lors de la suppression: Code \(httpResponse.statusCode)"
                    self.showErrorAlert = true
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Gestion des notifications d'expiration
    
    private func updateExpirationNotifications() {
        // Vérifier que les notifications sont autorisées
        guard NotificationManager.shared.authorizationStatus == .authorized else {
            print("📱 Notifications non autorisées, mise à jour ignorée")
            return
        }
        
        // Vérifier les préférences utilisateur
        let enableExpirationAlerts = UserDefaults.standard.bool(forKey: "enableExpirationAlerts")
        guard enableExpirationAlerts else {
            print("📱 Alertes d'expiration désactivées par l'utilisateur")
            return
        }
        
        print("🔔 Mise à jour des notifications d'expiration pour \(stocks.count) produits")
        
        // Filtrer les produits qui expirent dans les 3 prochains jours
        let advanceNoticeDays = UserDefaults.standard.integer(forKey: "advanceNoticeDaysKey")
        let maxDays = advanceNoticeDays > 0 ? advanceNoticeDays : 3
        
        let expiringProducts = stocks.filter { product in
            product.joursRestants >= 0 && product.joursRestants <= maxDays
        }
        
        print("🔔 \(expiringProducts.count) produits expirent dans les \(maxDays) prochains jours")
        
        // Programmer les notifications
        NotificationManager.shared.scheduleExpirationNotifications(for: expiringProducts)
        
        // Envoyer une notification immédiate pour les produits qui expirent aujourd'hui
        let expiringToday = stocks.filter { $0.joursRestants == 0 }
        for product in expiringToday {
            NotificationManager.shared.sendImmediateNotification(
                for: product,
                customMessage: "⚠️ \(product.nom) expire aujourd'hui ! Pensez à le consommer."
            )
        }
    }
    
    // MARK: - Gestion des actions depuis les notifications
    
    private func handleNavigateToProduct(productId: UUID) {
        print("🔔 Navigation vers le produit: \(productId)")
        
        // Trouver le produit dans la liste
        if let product = stocks.first(where: { $0.id == productId }) {
            // Poster une notification pour que la vue puisse naviguer
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .didTapNotificationForProduct,
                    object: nil,
                    userInfo: ["product": product]
                )
            }
        }
    }
    
    private func handleMarkProductConsumed(stockId: Int) {
        print("🔔 Marquer comme consommé le produit avec stockId: \(stockId)")
        
        // Trouver le produit
        guard let product = stocks.first(where: { $0.stockId == stockId }) else {
            print("❌ Produit non trouvé pour stockId: \(stockId)")
            return
        }
        
        // Marquer comme consommé via ProductConsumptionService
        ProductConsumptionService.shared.markProductStatus(
            stockId: stockId,
            quantity: 1, // Par défaut, on marque 1 unité comme consommée
            status: .consumed
        ) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Produit marqué comme consommé depuis la notification")
                    
                    // Mettre à jour la liste locale
                    if let index = self?.stocks.firstIndex(where: { $0.stockId == stockId }) {
                        if self?.stocks[index].quantite == 1 {
                            // Si c'était la dernière unité, supprimer le produit
                            self?.stocks.remove(at: index)
                        } else {
                            // Sinon, diminuer la quantité
                            self?.stocks[index] = Produit(
                                id: product.id,
                                nom: product.nom,
                                peremption: product.peremption,
                                joursRestants: product.joursRestants,
                                quantite: product.quantite - 1,
                                image: product.image,
                                stockId: product.stockId,
                                productDetails: product.productDetails
                            )
                        }
                    }
                    
                    // Mettre à jour les notifications
                    self?.updateExpirationNotifications()
                    
                    // Afficher un message de succès
                    self?.successMessage = "Produit marqué comme consommé"
                    self?.showSuccessMessage = true
                    
                    // Envoyer une notification de confirmation
                    NotificationManager.shared.sendImmediateNotification(
                        for: product,
                        customMessage: "✅ \(product.nom) a été marqué comme consommé avec succès !"
                    )
                } else {
                    print("❌ Échec du marquage depuis la notification")
                    self?.errorMessage = "Erreur lors du marquage du produit"
                    self?.showErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Méthodes publiques pour les notifications
    
    func forceUpdateNotifications() {
        updateExpirationNotifications()
    }
    
    func getExpiringProductsCount(days: Int = 3) -> Int {
        return stocks.filter { $0.joursRestants >= 0 && $0.joursRestants <= days }.count
    }
    
    func getExpiringProducts(days: Int = 3) -> [Produit] {
        return stocks.filter { $0.joursRestants >= 0 && $0.joursRestants <= days }
    }
}

// MARK: - Extensions pour NotificationCenter

extension Notification.Name {
    static let didTapNotificationForProduct = Notification.Name("didTapNotificationForProduct")
}
