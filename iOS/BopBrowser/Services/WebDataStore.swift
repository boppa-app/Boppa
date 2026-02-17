import Foundation
import WebKit

class WebDataStore {
    static let shared = WebDataStore()
    
    private let dataStore: WKWebsiteDataStore
    private var cookieObserver: NSObjectProtocol?
    
    private init() {
        self.dataStore = WKWebsiteDataStore.default()
        setupCookieSync()
    }
    
    deinit {
        if let observer = cookieObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
        
    private func setupCookieSync() {
        cookieObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncBidirectionally()
        }
        
        syncBidirectionally()
    }
    
    private func syncBidirectionally() {
        syncFromWKToHTTP()
        syncFromHTTPToWK()
    }
    
    private func syncFromWKToHTTP() {
        dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
    
    private func syncFromHTTPToWK() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        
        for cookie in cookies {
            dataStore.httpCookieStore.setCookie(cookie)
        }
    }
        
    func getDataStore() -> WKWebsiteDataStore {
        return dataStore
    }
    
    func forceSyncCookies(completion: (() -> Void)? = nil) {
        let group = DispatchGroup() 
        group.enter()
        dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            group.leave()
        }

        group.enter()
        if let httpCookies = HTTPCookieStorage.shared.cookies {
            let innerGroup = DispatchGroup()
            for cookie in httpCookies {
                innerGroup.enter()
                self.dataStore.httpCookieStore.setCookie(cookie) {
                    innerGroup.leave()
                }
            }
            innerGroup.notify(queue: .main) {
                group.leave()
            }
        } else {
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    func clearAllCookies(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        
        group.enter()
        dataStore.httpCookieStore.getAllCookies { cookies in
            let innerGroup = DispatchGroup()
            for cookie in cookies {
                innerGroup.enter()
                self.dataStore.httpCookieStore.delete(cookie) {
                    innerGroup.leave()
                }
            }
            innerGroup.notify(queue: .main) {
                group.leave()
            }
        }
        
        group.enter()
        if let httpCookies = HTTPCookieStorage.shared.cookies {
            for cookie in httpCookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        group.leave()
        
        group.notify(queue: .main) {
            completion?()
        }
    }
}