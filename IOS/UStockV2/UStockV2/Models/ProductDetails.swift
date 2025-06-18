import SwiftUI

struct ProductDetails: Equatable {
    let barcode: String
    let brand: String
    let contentSize: String
    let nutriscore: String
    let imageUrl: String
    
    // Implémentation de Equatable
    static func == (lhs: ProductDetails, rhs: ProductDetails) -> Bool {
        return lhs.barcode == rhs.barcode &&
               lhs.brand == rhs.brand &&
               lhs.contentSize == rhs.contentSize &&
               lhs.nutriscore == rhs.nutriscore &&
               lhs.imageUrl == rhs.imageUrl
    }
}

struct Produit: Identifiable, Equatable {
    let id: UUID
    let nom: String
    let peremption: String
    let joursRestants: Int
    let quantite: Int
    let image: String // On gardera ce champ mais il sera vide
    let stockId: Int?
    let productDetails: ProductDetails?
    
    init(id: UUID = UUID(), nom: String, peremption: String, joursRestants: Int, quantite: Int, image: String, stockId: Int? = nil, productDetails: ProductDetails? = nil) {
        self.id = id
        self.nom = nom
        self.peremption = peremption
        self.joursRestants = joursRestants
        self.quantite = quantite
        self.image = image
        self.stockId = stockId
        self.productDetails = productDetails
    }
    
    // Implémentation de Equatable
    static func == (lhs: Produit, rhs: Produit) -> Bool {
        return lhs.id == rhs.id &&
               lhs.nom == rhs.nom &&
               lhs.peremption == rhs.peremption &&
               lhs.joursRestants == rhs.joursRestants &&
               lhs.quantite == rhs.quantite &&
               lhs.image == rhs.image &&
               lhs.stockId == rhs.stockId &&
               lhs.productDetails == rhs.productDetails
    }
}

// MARK: - Extensions utiles

extension Produit {
    // Propriété calculée pour déterminer la couleur selon l'expiration
    var expirationColor: Color {
        switch joursRestants {
        case ...0:
            return .red
        case 1...3:
            return .orange
        case 4...14:
            return .green
        default:
            return .gray
        }
    }
    
    // Propriété calculée pour l'icône d'expiration
    var expirationIcon: String {
        switch joursRestants {
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
    
    // Propriété calculée pour le statut d'expiration
    var expirationStatus: String {
        switch joursRestants {
        case ...0:
            return "Expiré"
        case 1:
            return "Expire demain"
        case 2...3:
            return "Expire dans \(joursRestants) jours"
        case 4...7:
            return "Expire bientôt"
        default:
            return "Encore frais"
        }
    }
    
    // Indique si le produit expire bientôt (dans les 3 jours)
    var expiresBientot: Bool {
        return joursRestants >= 0 && joursRestants <= 3
    }
    
    // Indique si le produit est expiré
    var isExpired: Bool {
        return joursRestants < 0
    }
    
    // Retourne la marque du produit ou "Inconnue" si non disponible
    var brand: String {
        return productDetails?.brand ?? "Inconnue"
    }
    
    // Retourne l'URL de l'image ou nil si non disponible
    var imageURL: URL? {
        guard let imageUrl = productDetails?.imageUrl, !imageUrl.isEmpty else {
            return nil
        }
        return URL(string: imageUrl)
    }
}
