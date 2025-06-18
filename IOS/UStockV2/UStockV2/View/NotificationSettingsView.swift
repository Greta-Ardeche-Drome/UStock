//
//  NotificationSettingsView.swift
//  UStockV2
//
//  Created by Theo RUELLAN on 17/06/2025.
//


import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var pendingNotificationsCount = 0
    @State private var showingPermissionAlert = false
    @State private var notificationTime = Date()
    @State private var enableDailyReminders = true
    @State private var enableExpirationAlerts = true
    @State private var advanceNoticeDays = 3
    
    // Clés UserDefaults pour les préférences
    private let notificationTimeKey = "notificationTime"
    private let enableDailyRemindersKey = "enableDailyReminders"
    private let enableExpirationAlertsKey = "enableExpirationAlerts"
    private let advanceNoticeDaysKey = "advanceNoticeDays"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "C1DDF9").edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // En-tête avec statut
                        headerSection
                        
                        if notificationManager.authorizationStatus == .authorized {
                            // Paramètres des notifications
                            settingsSection
                            
                            // Statistiques
                            statisticsSection
                            
                            // Actions de test et nettoyage
                            actionsSection
                        } else {
                            // Section d'activation
                            activationSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadPreferences()
                updatePendingCount()
                notificationManager.checkAuthorizationStatus()
            }
            .alert("Autorisation requise", isPresented: $showingPermissionAlert) {
                Button("Paramètres") {
                    notificationManager.openNotificationSettings()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Pour recevoir des notifications, veuillez autoriser les notifications dans les paramètres de l'application.")
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            // Icône et titre
            Image(systemName: "bell.fill")
                .font(.system(size: 50))
                .foregroundColor(statusColor)
                .padding(.top, 20)
            
            Text("Notifications d'expiration")
                .font(.custom("ChauPhilomeneOne-Regular", size: 24))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            // Badge de statut
            statusBadge
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(20)
        .shadow(radius: 3)
    }
    
    private var statusBadge: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.2))
        .cornerRadius(20)
    }
    
    private var activationSection: some View {
        VStack(spacing: 20) {
            Text("Activez les notifications pour être alerté des produits qui expirent bientôt")
                .font(.body)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                requestNotificationPermission()
            }) {
                HStack {
                    Image(systemName: "bell.badge")
                        .font(.title3)
                    
                    Text("ACTIVER LES NOTIFICATIONS")
                        .font(.custom("ChauPhilomeneOne-Regular", size: 18))
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: "22C55E"))
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(radius: 3)
            }
            
            // Avantages des notifications
            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "clock", text: "Alertes 3 jours avant expiration")
                benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Réduction du gaspillage alimentaire")
                benefitRow(icon: "checkmark.shield", text: "Gestion optimisée de votre stock")
            }
            .padding()
            .background(Color.white.opacity(0.6))
            .cornerRadius(15)
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(20)
        .shadow(radius: 3)
    }
    
    private var settingsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Paramètres", icon: "gear")
            
            VStack(spacing: 0) {
                // Alertes d'expiration
                SettingRow(
                    icon: "exclamationmark.triangle",
                    title: "Alertes d'expiration",
                    subtitle: "Recevoir des notifications pour les produits qui expirent",
                    color: Color(hex: "F59E0B")
                ) {
                    Toggle("", isOn: $enableExpirationAlerts)
                        .onChange(of: enableExpirationAlerts) { _, newValue in
                            savePreference(key: enableExpirationAlertsKey, value: newValue)
                            if newValue {
                                scheduleNotificationsIfNeeded()
                            }
                        }
                }
                
                Divider().padding(.leading, 60)
                
                // Nombre de jours d'avance
                SettingRow(
                    icon: "calendar",
                    title: "Préavis",
                    subtitle: "Alerter \(advanceNoticeDays) jour\(advanceNoticeDays > 1 ? "s" : "") avant expiration",
                    color: Color(hex: "3B82F6")
                ) {
                    Picker("Jours", selection: $advanceNoticeDays) {
                        ForEach(1...7, id: \.self) { day in
                            Text("\(day) jour\(day > 1 ? "s" : "")")
                                .tag(day)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: advanceNoticeDays) { _, newValue in
                        savePreference(key: advanceNoticeDaysKey, value: newValue)
                        scheduleNotificationsIfNeeded()
                    }
                }
                
                Divider().padding(.leading, 60)
                
                // Heure des notifications
                SettingRow(
                    icon: "clock",
                    title: "Heure des notifications",
                    subtitle: "Recevoir les alertes à \(formattedTime)",
                    color: Color(hex: "8B5CF6")
                ) {
                    DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: notificationTime) { _, newValue in
                            savePreference(key: notificationTimeKey, value: newValue)
                            scheduleNotificationsIfNeeded()
                        }
                }
                
                Divider().padding(.leading, 60)
                
                // Rappels quotidiens
                SettingRow(
                    icon: "repeat",
                    title: "Vérification quotidienne",
                    subtitle: "Mettre à jour automatiquement les notifications",
                    color: Color(hex: "10B981")
                ) {
                    Toggle("", isOn: $enableDailyReminders)
                        .onChange(of: enableDailyReminders) { _, newValue in
                            savePreference(key: enableDailyRemindersKey, value: newValue)
                            if newValue {
                                notificationManager.scheduleDailyCheck()
                            }
                        }
                }
            }
            .background(Color.white.opacity(0.8))
            .cornerRadius(15)
        }
    }
    
    private var statisticsSection: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Statistiques", icon: "chart.bar")
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Notifications en attente",
                    value: "\(pendingNotificationsCount)",
                    icon: "bell.badge",
                    color: Color(hex: "F59E0B")
                )
                
                StatCard(
                    title: "Statut",
                    value: statusText,
                    icon: "checkmark.circle",
                    color: statusColor
                )
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(15)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 15) {
            SectionHeader(title: "Actions", icon: "wrench.and.screwdriver")
            
            VStack(spacing: 12) {
                // Test de notification
                ActionButton(
                    title: "Tester les notifications",
                    subtitle: "Envoyer une notification de test",
                    icon: "paperplane",
                    color: Color(hex: "3B82F6")
                ) {
                    sendTestNotification()
                }
                
                // Programmer les notifications maintenant
                ActionButton(
                    title: "Actualiser les notifications",
                    subtitle: "Reprogrammer toutes les notifications",
                    icon: "arrow.clockwise",
                    color: Color(hex: "10B981")
                ) {
                    scheduleNotificationsIfNeeded()
                }
                
                // Supprimer toutes les notifications
                ActionButton(
                    title: "Effacer toutes les notifications",
                    subtitle: "Supprimer toutes les notifications en attente",
                    icon: "trash",
                    color: Color(hex: "EF4444")
                ) {
                    clearAllNotifications()
                }
            }
            .padding()
            .background(Color.white.opacity(0.8))
            .cornerRadius(15)
        }
    }
    
    // MARK: - Composants Helper
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "22C55E"))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.black)
            
            Spacer()
        }
    }
    
    // MARK: - Propriétés calculées
    
    private var statusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return Color(hex: "22C55E")
        case .denied:
            return Color(hex: "EF4444")
        case .notDetermined:
            return Color(hex: "F59E0B")
        case .provisional:
            return Color(hex: "3B82F6")
        case .ephemeral:
            return Color(hex: "8B5CF6")
        @unknown default:
            return Color.gray
        }
    }
    
    private var statusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Activées"
        case .denied:
            return "Refusées"
        case .notDetermined:
            return "Non configurées"
        case .provisional:
            return "Provisoires"
        case .ephemeral:
            return "Éphémères"
        @unknown default:
            return "Inconnu"
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: notificationTime)
    }
    
    // MARK: - Actions
    
    private func requestNotificationPermission() {
        notificationManager.requestAuthorization { granted in
            if granted {
                scheduleNotificationsIfNeeded()
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    private func scheduleNotificationsIfNeeded() {
        guard enableExpirationAlerts else { return }
        
        // Ici, on devrait récupérer les produits depuis le StockViewModel
        // Pour l'instant, on poste une notification pour déclencher la mise à jour
        NotificationCenter.default.post(name: .shouldUpdateExpirationNotifications, object: nil)
    }
    
    private func sendTestNotification() {
        let testProduct = Produit(
            nom: "Produit de test",
            peremption: formatDate(Date().addingTimeInterval(2 * 24 * 60 * 60)), // Dans 2 jours
            joursRestants: 2,
            quantite: 1,
            image: "🧪"
        )
        
        notificationManager.sendImmediateNotification(
            for: testProduct,
            customMessage: "Ceci est une notification de test pour vérifier que tout fonctionne correctement !"
        )
    }
    
    private func clearAllNotifications() {
        notificationManager.clearAllNotifications()
        updatePendingCount()
    }
    
    private func updatePendingCount() {
        notificationManager.getPendingNotificationsCount { count in
            pendingNotificationsCount = count
        }
    }
    
    // MARK: - Gestion des préférences
    
    private func loadPreferences() {
        if let savedTime = UserDefaults.standard.object(forKey: notificationTimeKey) as? Date {
            notificationTime = savedTime
        } else {
            // Heure par défaut: 9h00
            notificationTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        }
        
        enableDailyReminders = UserDefaults.standard.bool(forKey: enableDailyRemindersKey)
        enableExpirationAlerts = UserDefaults.standard.bool(forKey: enableExpirationAlertsKey)
        advanceNoticeDays = UserDefaults.standard.integer(forKey: advanceNoticeDaysKey)
        
        // Valeurs par défaut
        if advanceNoticeDays == 0 {
            advanceNoticeDays = 3
        }
    }
    
    private func savePreference<T>(key: String, value: T) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yy"
        return formatter.string(from: date)
    }
}

// MARK: - Composants Supporting

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "156585"))
            
            Text(title)
                .font(.custom("ChauPhilomeneOne-Regular", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let content: Content
    
    init(icon: String, title: String, subtitle: String, color: Color, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            content
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotificationSettingsView()
}