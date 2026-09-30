import Foundation

class SecurityScopedResourceManager {
    static let shared = SecurityScopedResourceManager()
    private var openResources: [URL: Data] = [:]
    
    private init() {}
    
    func startAccessing(bookmark: Data) -> URL? {
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if url.startAccessingSecurityScopedResource() {
                openResources[url] = bookmark
                return url
            } else {
                print("Failed to start accessing security-scoped resource: \(url)")
                return nil
            }
        } catch {
            print("Failed to resolve security-scoped bookmark: \(error)")
            return nil
        }
    }
    
    func stopAccessing(url: URL) {
        if openResources.keys.contains(url) {
            url.stopAccessingSecurityScopedResource()
            openResources.removeValue(forKey: url)
        }
    }

    /// Flutter 侧消费完 pending 文件后统一释放安全作用域，避免访问计数累积泄漏。
    func stopAccessingAll() {
        for url in openResources.keys {
            url.stopAccessingSecurityScopedResource()
        }
        openResources.removeAll()
    }
}
