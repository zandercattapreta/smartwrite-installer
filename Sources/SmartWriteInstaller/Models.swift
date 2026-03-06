import Foundation

// MARK: - Models

struct Plugin: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let repoUrl: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case repoUrl = "repo_url"
    }
}

struct ObsidianVault: Identifiable, Hashable {
    let id: UUID = UUID()
    let path: String
    
    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

struct ObsidianConfig: Codable {
    let vaults: [String: VaultInfo]
    
    struct VaultInfo: Codable {
        let path: String
    }
}

// MARK: - Installation Status

enum InstallationStatus: Equatable {
    case idle
    case discovering
    case installing(current: Int, total: Int, message: String)
    case completed(success: Int, failed: Int)
    case failed(String)
}
