import Foundation

extension APIService {
    enum DeviceRegistrationError: Error, LocalizedError {
        case endpointAlreadyExists(endpointArn: String)
        
        var errorDescription: String? {
            switch self {
            case .endpointAlreadyExists:
                return "Device already registered with a different account"
            }
        }
    }
    
    func updateExistingDeviceEndpoint(endpointArn: String, token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("/users/me/update-endpoint")
        var request = createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        
        // Create the request body with endpoint ARN and token
        let parameters = ["endpoint_arn": endpointArn, "token": token]
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(APIError.unauthorized))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(APIError.requestFailed(statusCode: httpResponse.statusCode)))
                return
            }
            
            completion(.success(()))
        }
        task.resume()
    }
}
