//
//  NotificationManager.swift
//  UStockV2
//
//  Created by Theo RUELLAN on 17/06/2025.
//


import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isSchedulingEnabled = false
    
    // Identifiants pour les différents types de notifications
    private let expirationNotificationPrefix = "expiration_"
    private let dailyCheckIdentifier = "daily_expiration_check"
    
    override init() {
        super.init()
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Autorisation
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Erreur d'autorisation de notification: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                self.authorizationStatus = granted ? .authorized : .denied
                print(granted ? "✅ Notifications autorisées" : "❌ Notifications refusées")
                completion(granted)
                
                if granted {
                    self.scheduleDailyCheck()
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isSchedulingEnabled = settings.authorizationStatus == .authorized
                
                print("📱 Statut des notifications: \(settings.authorizationStatus.rawValue)")
            }
        }
    }
    
    // MARK: - Configuration des catégories
    
    private func setupNotificationCategories() {
        // Actions pour les notifications d'expiration
        let viewAction = UNNotificationAction(
            identifier: "VIEW_PRODUCT",
            title: "Voir le produit",
            options: [.foreground]
        )
        
        let markConsumedAction = UNNotificationAction(
            identifier: "MARK_CONSUMED",
            title: "Marquer comme consommé",
            options: [.destructive]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Rappeler demain",
            options: []
        )
        
        // Catégorie pour les produits qui expirent
        let expirationCategory = UNNotificationCategory(
            identifier: "EXPIRATION_ALERT",
            actions: [viewAction, markConsumedAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([expirationCategory])
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Planification des notifications
    
    func scheduleExpirationNotifications(for products: [Produit]) {
        guard authorizationStatus == .authorized else {
            print("❌ Notifications non autorisées")
            return
        }
        
        // Supprimer les anciennes notifications d'expiration
        clearExpirationNotifications()
        
        let calendar = Calendar.current
        let now = Date()
        
        for product in products {
            // Calculer la date d'expiration
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd-MM-yy"
            
            guard let expirationDate = dateFormatter.date(from: product.peremption) else {
                continue
            }
            
            let daysUntilExpiration = calendar.dateComponents([.day], from: now, to: expirationDate).day ?? 0
            
            // Planifier notifications pour les produits qui expirent dans 1, 2 ou 3 jours
            if daysUntilExpiration > 0 && daysUntilExpiration <= 3 {
                scheduleNotification(for: product, daysUntilExpiration: daysUntilExpiration)
            }
            
            // Notification le jour de l'expiration
            if daysUntilExpiration == 0 {
                scheduleNotification(for: product, daysUntilExpiration: 0)
            }
        }
        
        print("✅ Notifications programmées pour \(products.count) produits")
    }
    
    private func scheduleNotification(for product: Produit, daysUntilExpiration: Int) {
        let content = UNMutableNotificationContent()
        
        // Personnaliser le message selon les jours restants
        switch daysUntilExpiration {
        case 0:
            content.title = "⚠️ Produit expiré aujourd'hui"
            content.body = "\(product.nom) expire aujourd'hui ! Quantité: \(product.quantite)"
            content.sound = UNNotificationSound.default
        case 1:
            content.title = "🔴 Expire demain"
            content.body = "\(product.nom) expire dans 1 jour. Quantité: \(product.quantite)"
            content.sound = UNNotificationSound.default
        case 2:
            content.title = "🟠 Expire bientôt"
            content.body = "\(product.nom) expire dans 2 jours. Quantité: \(product.quantite)"
            content.sound = UNNotificationSound.default
        case 3:
            content.title = "🟡 Attention expiration"
            content.body = "\(product.nom) expire dans 3 jours. Quantité: \(product.quantite)"
            content.sound = UNNotificationSound.default
        default:
            return
        }
        
        content.categoryIdentifier = "EXPIRATION_ALERT"
        content.badge = 1
        
        // Ajouter des données utilisateur pour identifier le produit
        content.userInfo = [
            "productId": product.id.uuidString,
            "stockId": product.stockId ?? 0,
            "productName": product.nom,
            "daysUntilExpiration": daysUntilExpiration
        ]
        
        // Programmer pour le matin (9h)
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let identifier = "\(expirationNotificationPrefix)\(product.id.uuidString)_\(daysUntilExpiration)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Erreur lors de la programmation de la notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification programmée pour \(product.nom) (\(daysUntilExpiration) jours)")
            }
        }
    }
    
    // MARK: - Vérification quotidienne
    
    func scheduleDailyCheck() {
        let content = UNMutableNotificationContent()
        content.title = "Vérification quotidienne"
        content.body = "Mise à jour des notifications d'expiration"
        content.sound = nil // Silencieuse
        content.userInfo = ["type": "daily_check"]
        
        // Tous les jours à 8h
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailyCheckIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Erreur programmation vérification quotidienne: \(error.localizedDescription)")
            } else {
                print("✅ Vérification quotidienne programmée")
            }
        }
    }
    
    // MARK: - Gestion des notifications immédiates
    
    func sendImmediateNotification(for product: Produit, customMessage: String? = nil) {
        guard authorizationStatus == .authorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔔 UStock"
        content.body = customMessage ?? "\(product.nom) nécessite votre attention"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "EXPIRATION_ALERT"
        
        content.userInfo = [
            "productId": product.id.uuidString,
            "stockId": product.stockId ?? 0,
            "productName": product.nom,
            "immediate": true
        ]
        
        let identifier = "immediate_\(product.id.uuidString)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Erreur notification immédiate: \(error.localizedDescription)")
            } else {
                print("✅ Notification immédiate envoyée pour \(product.nom)")
            }
        }
    }
    
    // MARK: - Nettoyage
    
    func clearExpirationNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let expirationIdentifiers = requests
                .filter { $0.identifier.starts(with: self.expirationNotificationPrefix) }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: expirationIdentifiers)
            print("🧹 \(expirationIdentifiers.count) notifications d'expiration supprimées")
        }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
        print("🧹 Toutes les notifications supprimées")
    }
    
    // MARK: - Statistiques
    
    func getPendingNotificationsCount(completion: @escaping (Int) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests.count)
            }
        }
    }
    
    // MARK: - Paramètres
    
    func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Gestion des notifications quand l'app est au premier plan
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Vérification quotidienne silencieuse
        if notification.request.content.userInfo["type"] as? String == "daily_check" {
            // Déclencher la mise à jour des notifications
            DispatchQueue.main.async {
                // Ici on pourrait déclencher une mise à jour des stocks
                NotificationCenter.default.post(name: .shouldUpdateExpirationNotifications, object: nil)
            }
            completionHandler([]) // Pas d'affichage
            return
        }
        
        // Afficher les autres notifications même quand l'app est ouverte
        completionHandler([.alert, .sound, .badge])
    }
    
    // Gestion des actions sur les notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_PRODUCT":
            // Naviguer vers le détail du produit
            if let productIdString = userInfo["productId"] as? String,
               let productId = UUID(uuidString: productIdString) {
                NotificationCenter.default.post(
                    name: .shouldNavigateToProduct,
                    object: nil,
                    userInfo: ["productId": productId]
                )
            }
            
        case "MARK_CONSUMED":
            // Marquer comme consommé
            if let stockId = userInfo["stockId"] as? Int {
                NotificationCenter.default.post(
                    name: .shouldMarkProductConsumed,
                    object: nil,
                    userInfo: ["stockId": stockId]
                )
            }
            
        case "SNOOZE":
            // Reporter la notification
            if let productName = userInfo["productName"] as? String {
                scheduleSnoozeNotification(productName: productName, userInfo: userInfo)
            }
            
        case UNNotificationDefaultActionIdentifier:
            // Tap sur la notification sans action spécifique
            if let productIdString = userInfo["productId"] as? String,
               let productId = UUID(uuidString: productIdString) {
                NotificationCenter.default.post(
                    name: .shouldNavigateToProduct,
                    object: nil,
                    userInfo: ["productId": productId]
                )
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func scheduleSnoozeNotification(productName: String, userInfo: [AnyHashable: Any]) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Rappel"
        content.body = "N'oubliez pas: \(productName) expire bientôt"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "EXPIRATION_ALERT"
        content.userInfo = userInfo
        
        // Programmer pour demain à la même heure
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let identifier = "snooze_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Extensions pour NotificationCenter

extension Notification.Name {
    static let shouldUpdateExpirationNotifications = Notification.Name("shouldUpdateExpirationNotifications")
    static let shouldNavigateToProduct = Notification.Name("shouldNavigateToProduct")
    static let shouldMarkProductConsumed = Notification.Name("shouldMarkProductConsumed")
}