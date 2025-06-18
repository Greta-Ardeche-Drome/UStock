import SwiftUI

struct ProductDetailView: View {
    let produit: Produit
    @State private var quantity: Int
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showDeleteSuccess = false
    
    // Pour le popup de sélection de quantité
    @State private var showQuantityPopup = false
    @State private var selectedAction: String = ""  // "consumed" ou "wasted"
    @State private var popupQuantity: Int = 1
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    // ViewModel pour gérer les interactions avec l'API
    @StateObject private var stockViewModel = StockViewModel()
    
    // États pour les notifications
    @State private var showNotificationOptions = false
    @State private var notificationSent = false
    
    // Initialisation avec la quantité actuelle du produit
    init(produit: Produit) {
        self.produit = produit
        _quantity = State(initialValue: produit.quantite)
    }
    
    var body: some View {
        ZStack {
            // Fond d'écran bleu clair
            Color(hex: "C1DDF9").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // Image du produit
                productImageView
                
                // Titre et marque
                VStack(spacing: 5) {
                    Text(produit.nom)
                        .font(.custom("ChauPhilomeneOne-Regular", size: 34))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    Text("Marque : \(produitBrand)")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 10)
                
                // Indicateur Nutriscore
                nutriScoreView
                    .padding(.vertical, 10)
                
                // Badge d'expiration avec couleur dynamique
                expirationBadge
                
                // Contrôle de quantité
                quantityControlView
                    .padding(.top, 20)
                
                // Section notifications
                notificationSection
                
                Spacer()
                
                // Boutons d'action
                VStack(spacing: 15) {
                    // Boutons Jeté/Consommé
                    HStack(spacing: 0) {
                        Button(action: {
                            showDiscardPopup()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.title3)
                                Text("JETÉ")
                                    .font(.custom("ChauPhilomeneOne-Regular", size: 22))
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.black)
                        }
                        
                        Button(action: {
                            showConsumePopup()
                        }) {
                            HStack {
                                Image(systemName: "fork.knife")
                                    .font(.title3)
                                Text("CONSOMMÉ")
                                    .font(.custom("ChauPhilomeneOne-Regular", size: 22))
                                    .fontWeight(.bold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.black)
                        }
                    }
                    .cornerRadius(30)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                    
                    // Bouton Suppression
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 5)
                            }
                            
                            Text("SUPPRESSION")
                                .font(.custom("ChauPhilomeneOne-Regular", size: 22))
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .shadow(radius: 3)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Détails du produit")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Supprimer le produit", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                deleteProduct()
            }
        } message: {
            Text("Voulez-vous vraiment supprimer ce produit de votre inventaire ?")
        }
        .alert("Produit supprimé", isPresented: $showDeleteSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Le produit a été retiré de votre inventaire avec succès.")
        }
        .alert("Erreur", isPresented: $stockViewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stockViewModel.errorMessage ?? "Une erreur est survenue")
        }
        .sheet(isPresented: $showQuantityPopup) {
            quantityPopupView
        }
        .actionSheet(isPresented: $showNotificationOptions) {
            notificationActionSheet
        }
    }
    
    // MARK: - Composants de vue
    
    // Vue pour l'image du produit
    private var productImageView: some View {
        Group {
            if let productDetails = produit.productDetails,
               !productDetails.imageUrl.isEmpty,
               let url = URL(string: productDetails.imageUrl) {
                
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 150, height: 150)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                    case .failure:
                        defaultProductImage
                    @unknown default:
                        defaultProductImage
                    }
                }
            } else {
                defaultProductImage
            }
        }
        .padding(.top, 20)
    }
    
    // Image par défaut si aucune image n'est disponible
    private var defaultProductImage: some View {
        Image(systemName: "photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 150)
            .foregroundColor(.gray)
    }
    
    // Badge d'expiration avec couleur selon l'urgence
    private var expirationBadge: some View {
        HStack {
            Image(systemName: expirationIcon)
                .font(.title3)
                .foregroundColor(expirationColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Expiration")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Le \(produit.peremption)")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(expirationStatus)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(expirationColor)
            }
            
            Spacer()
        }
        .padding()
        .background(expirationColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(expirationColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // Section notifications
    private var notificationSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "156585"))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button("Options") {
                    showNotificationOptions = true
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "156585").opacity(0.2))
                .foregroundColor(Color(hex: "156585"))
                .cornerRadius(8)
            }
            
            // Message de confirmation de notification envoyée
            if notificationSent {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Notification de test envoyée !")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                .padding(.top, 5)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // Indicateur Nutri-Score
    private var nutriScoreView: some View {
        HStack(spacing: 0) {
            ForEach(["A", "B", "C", "D", "E"], id: \.self) { score in
                let isSelected = if let details = produit.productDetails,
                                  !details.nutriscore.isEmpty {
                                    details.nutriscore.uppercased() == score
                                  } else {
                                    false
                                  }
                
                let color: Color = {
                    switch score {
                    case "A": return Color(hex: "4A8E38")
                    case "B": return Color(hex: "85BB2F")
                    case "C": return Color(hex: "FFCC00")
                    case "D": return Color(hex: "EF8200")
                    case "E": return Color(hex: "E63E11")
                    default: return .gray
                    }
                }()
                
                ZStack {
                    Rectangle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                    
                    Text(score)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }
                .overlay(
                    isSelected ?
                        Triangle()
                            .fill(color)
                            .frame(width: 20, height: 10)
                            .offset(y: -30)
                        : nil
                )
            }
        }
        .cornerRadius(8)
    }
    
    // Contrôle de quantité
    private var quantityControlView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.white.opacity(0.7))
                .shadow(radius: 3)
            
            HStack(spacing: 30) {
                Text("Quantité:")
                    .font(.custom("ChauPhilomeneOne-Regular", size: 26))
                    .foregroundColor(.black)
                
                Button(action: {
                    if quantity > 1 {
                        quantity -= 1
                    }
                }) {
                    Text("-")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Text("\(quantity)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                    .frame(minWidth: 40)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    if quantity < produit.quantite {
                        quantity += 1
                    }
                }) {
                    Text("+")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .frame(height: 70)
        .padding(.horizontal, 40)
    }
    
    // Popup de sélection de quantité
    private var quantityPopupView: some View {
        ZStack {
            Color(hex: "C1DDF9").edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text(selectedAction == "consumed" ? "Quantité consommée" : "Quantité jetée")
                    .font(.custom("ChauPhilomeneOne-Regular", size: 28))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.top, 50)
                
                HStack(spacing: 40) {
                    Button(action: {
                        if popupQuantity > 1 {
                            popupQuantity -= 1
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "689FA7"))
                                .frame(width: 70, height: 70)
                            
                            Text("-")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text("\(popupQuantity)")
                        .font(.system(size: 60, weight: .bold))
                        .frame(minWidth: 80)
                        .foregroundColor(.black)
                    
                    Button(action: {
                        if popupQuantity < produit.quantite {
                            popupQuantity += 1
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "689FA7"))
                                .frame(width: 70, height: 70)
                            
                            Text("+")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.vertical, 30)
                
                Text("Disponible: \(produit.quantite)")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
                
                HStack(spacing: 20) {
                    Button(action: {
                        showQuantityPopup = false
                    }) {
                        Text("Annuler")
                            .font(.system(size: 22, weight: .medium))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.black)
                            .cornerRadius(20)
                    }
                    
                    Button(action: {
                        showQuantityPopup = false
                        processAction()
                    }) {
                        Text("Confirmer")
                            .font(.system(size: 22, weight: .medium))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "689FA7"))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 30)
        }
        .presentationDetents([.medium])
        .presentationBackground(Color(hex: "C1DDF9"))
        .presentationCornerRadius(25)
    }
    
    // Action sheet pour les notifications
    private var notificationActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Options de notification"),
            message: Text("Choisissez une action pour ce produit"),
            buttons: [
                .default(Text("Envoyer notification de test")) {
                    sendTestNotification()
                },
                .default(Text("Programmer rappel personnalisé")) {
                    scheduleCustomReminder()
                },
                .default(Text("Paramètres notifications")) {
                    // Ouvrir les paramètres de notification
                    NotificationManager.shared.openNotificationSettings()
                },
                .cancel(Text("Annuler"))
            ]
        )
    }
    
    // MARK: - Propriétés calculées
    
    private var produitBrand: String {
        return produit.productDetails?.brand ?? "Inconnue"
    }
    
    private var expirationColor: Color {
        switch produit.joursRestants {
        case ...0:
            return .red
        case 1...3:
            return .orange
        case 4...7:
            return .yellow
        default:
            return .green
        }
    }
    
    private var expirationIcon: String {
        switch produit.joursRestants {
        case ...0:
            return "exclamationmark.triangle.fill"
        case 1...3:
            return "clock.fill"
        case 4...7:
            return "clock"
        default:
            return "checkmark.circle.fill"
        }
    }
    
    private var expirationStatus: String {
        switch produit.joursRestants {
        case ...0:
            return "Expiré"
        case 1:
            return "Expire demain"
        case 2...3:
            return "Expire dans \(produit.joursRestants) jours"
        case 4...7:
            return "Expire bientôt"
        default:
            return "Encore frais"
        }
    }
    
    private var notificationStatusText: String {
        switch NotificationManager.shared.authorizationStatus {
        case .authorized:
            return produit.joursRestants <= 3 ? "Notifications actives" : "Aucune alerte prévue"
        case .denied:
            return "Notifications désactivées"
        case .notDetermined:
            return "Notifications non configurées"
        default:
            return "Statut inconnu"
        }
    }
    
    // MARK: - Méthodes
    
    private func showDiscardPopup() {
        selectedAction = "wasted"
        popupQuantity = 1
        showQuantityPopup = true
    }

    private func showConsumePopup() {
        selectedAction = "consumed"
        popupQuantity = 1
        showQuantityPopup = true
    }

    private func processAction() {
        guard let stockId = produit.stockId else {
            errorMessage = "Erreur: identifiant de stock manquant"
            showErrorAlert = true
            return
        }
        
        if popupQuantity > produit.quantite {
            errorMessage = "Erreur: Vous ne pouvez pas sélectionner plus de produits que disponibles"
            showErrorAlert = true
            return
        }
        
        let status: ProductStatus = selectedAction == "consumed" ? .consumed : .wasted
        let finalQuantity = popupQuantity
        
        dismiss()
        
        ProductConsumptionService.shared.markProductStatus(
            stockId: stockId,
            quantity: finalQuantity,
            status: status
        ) { success in
            if success {
                print("✅ Produit marqué comme \(status.rawValue): \(finalQuantity) unités")
                
                // Envoyer une notification de confirmation
                DispatchQueue.main.async {
                    let message = status == .consumed ?
                        "✅ \(finalQuantity) unité\(finalQuantity > 1 ? "s" : "") de \(self.produit.nom) marquée\(finalQuantity > 1 ? "s" : "") comme consommée\(finalQuantity > 1 ? "s" : "")" :
                        "🗑️ \(finalQuantity) unité\(finalQuantity > 1 ? "s" : "") de \(self.produit.nom) marquée\(finalQuantity > 1 ? "s" : "") comme jetée\(finalQuantity > 1 ? "s" : "")"
                    
                    NotificationManager.shared.sendImmediateNotification(
                        for: self.produit,
                        customMessage: message
                    )
                }
            } else {
                print("❌ Erreur lors du marquage du produit")
            }
        }
    }
    
    private func deleteProduct() {
        guard let stockId = produit.stockId else {
            print("❌ Impossible de supprimer : stockId manquant")
            return
        }
        
        isDeleting = true
        
        stockViewModel.deleteProduct(stockId: stockId) { success in
            isDeleting = false
            
            if success {
                print("✅ Suppression réussie !")
                showDeleteSuccess = true
            }
        }
    }
    
    private func sendTestNotification() {
        NotificationManager.shared.sendImmediateNotification(
            for: produit,
            customMessage: "🧪 Notification de test pour \(produit.nom) - Expire dans \(produit.joursRestants) jour\(produit.joursRestants > 1 ? "s" : "")"
        )
        
        notificationSent = true
        
        // Masquer le message après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                notificationSent = false
            }
        }
    }
    
    private func scheduleCustomReminder() {
        // Ici on pourrait implémenter une interface pour programmer un rappel personnalisé
        // Pour l'instant, on programme un rappel dans 1 heure
        let content = UNMutableNotificationContent()
        content.title = "Rappel personnalisé"
        content.body = "N'oubliez pas de vérifier \(produit.nom)"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false) // 1 heure
        let request = UNNotificationRequest(
            identifier: "custom_reminder_\(produit.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if error == nil {
                    self.notificationSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            self.notificationSent = false
                        }
                    }
                }
            }
        }
    }
}

// Forme de triangle pour l'indicateur de Nutri-Score
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
