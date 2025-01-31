//
//  MediaNetworkRemote.swift
//  SwiftyPress
//
//  Created by Basem Emara on 2019-05-17.
//  Copyright © 2019 Zamzam Inc. All rights reserved.
//

import Foundation

public struct MediaNetworkRemote: MediaRemote, Loggable {
    private let apiSession: APISessionType
    
    public init(apiSession: APISessionType) {
        self.apiSession = apiSession
    }
}

public extension MediaNetworkRemote {
    
    func fetch(id: Int, completion: @escaping (Result<MediaType, DataError>) -> Void) {
        apiSession.request(APIRouter.readMedia(id: id)) {
            // Handle errors
            guard case .success = $0 else {
                // Handle no existing data
                if $0.error?.statusCode == 404 {
                    completion(.failure(.nonExistent))
                    return
                }
                
                self.Log(error: "An error occured while fetching the media: \(String(describing: $0.error)).")
                completion(.failure(DataError(from: $0.error)))
                return
            }
            
            // Ensure available
            guard case .success(let value) = $0 else {
                completion(.failure(.nonExistent))
                return
            }
            
            DispatchQueue.transform.async {
                do {
                    // Type used for decoding the server payload
                    struct ServerResponse: Decodable {
                        let media: Media
                    }
                    
                    // Parse response data
                    let payload = try JSONDecoder.default.decode(ServerResponse.self, from: value.data)
                    
                    DispatchQueue.main.async {
                        completion(.success(payload.media))
                    }
                } catch {
                    self.Log(error: "An error occured while parsing the media: \(error).")
                    DispatchQueue.main.async { completion(.failure(.parseFailure(error))) }
                    return
                }
            }
        }
    }
}
