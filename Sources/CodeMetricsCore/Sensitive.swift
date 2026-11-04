import Foundation

/// Файлы с секретами и чувствительной конфигурацией. Они не читаются никогда и не отключаются настройками:
/// проверка выполняется по имени, до открытия файла, и не зависит от того, поддерживается ли расширение.
public enum SensitiveFiles {
    private static let exactNames: Set<String> = [
        ".npmrc", ".yarnrc", ".yarnrc.yml", ".netrc", ".pypirc", ".htpasswd", ".pgpass", ".dockercfg",
        "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "kubeconfig", "wrangler.toml.secret",
    ]
    private static let suffixes = [
        ".pem", ".key", ".p12", ".pfx", ".jks", ".keystore", ".crt", ".cer", ".secret", ".secrets", ".tfvars", ".tfstate",
    ]
    private static let prefixes = ["credentials", "secrets", "secret.", "service-account", "serviceaccount", "client_secret", ".dev.vars"]

    public static func matches(fileName: String) -> Bool {
        let n = fileName.lowercased()
        if n == ".env" || n.hasPrefix(".env.") || n.hasSuffix(".env") { return true }
        if exactNames.contains(n) { return true }
        if suffixes.contains(where: n.hasSuffix) { return true }
        if prefixes.contains(where: n.hasPrefix) { return true }
        // *serviceaccount*.json, *-secrets.json и т.п.
        if n.hasSuffix(".json") || n.hasSuffix(".yaml") || n.hasSuffix(".yml") {
            return ["serviceaccount", "service-account", "service_account", "secret", "credential", "private-key", "private_key"].contains { n.contains($0) }
        }
        return false
    }
}
