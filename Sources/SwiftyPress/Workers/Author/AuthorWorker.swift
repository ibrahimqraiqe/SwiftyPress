//
//  AuthorsStoreInterfaces.swift
//  SwiftPress
//
//  Created by Basem Emara on 2018-05-29.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

public struct AuthorWorker: AuthorWorkerType, Loggable {
    private let store: AuthorStore
    private let remote: AuthorRemote?
    
    public init(store: AuthorStore, remote: AuthorRemote?) {
        self.store = store
        self.remote = remote
    }
}

public extension AuthorWorker {
    
    func fetch(id: Int, completion: @escaping (Result<AuthorType, DataError>) -> Void) {
        store.fetch(id: id) {
            guard let remote = self.remote else {
                completion($0)
                return
            }
            
            // Retrieve missing cache data from cloud if applicable
            if case .nonExistent? = $0.error {
                remote.fetch(id: id) {
                    guard case .success(let value) = $0 else {
                        completion($0)
                        return
                    }
                    
                    self.store.createOrUpdate(value, completion: completion)
                }
                
                return
            }
            
            // Immediately return local response
            completion($0)
            
            guard case .success(let cacheElement) = $0 else { return }
            
            // Sync remote updates to cache if applicable
            remote.fetch(id: id) {
                // Validate if any updates occurred and return
                guard case .success(let element) = $0,
                    element.modifiedAt > cacheElement.modifiedAt else {
                        return
                }
                
                // Update local storage with updated data
                self.store.createOrUpdate(element) {
                    guard case .success = $0 else {
                        self.Log(error: "Could not save updated author locally from remote storage: \(String(describing: $0.error))")
                        return
                    }
                    
                    // Callback handler again if updated
                    completion($0)
                }
            }
        }
    }
}
