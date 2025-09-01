import Foundation

// This extension adds debug logging to APIService
extension APIService {
    // Add debug logging for enrollment code API calls
    func debugCreateEnrollmentCode(coparentFirstName: String? = nil, coparentLastName: String? = nil, coparentEmail: String? = nil, coparentPhone: String? = nil, completion: @escaping (Result<EnrollmentCodeResponse, Error>) -> Void) {
        print("📱 Calling createEnrollmentCode API...")
        print("📱 With coparent info: firstName=\(coparentFirstName ?? "nil"), lastName=\(coparentLastName ?? "nil"), email=\(coparentEmail ?? "nil"), phone=\(coparentPhone ?? "nil")")
        
        createEnrollmentCode(
            coparentFirstName: coparentFirstName,
            coparentLastName: coparentLastName,
            coparentEmail: coparentEmail,
            coparentPhone: coparentPhone
        ) { result in
            switch result {
            case .success(let response):
                print("📱 createEnrollmentCode API success: \(response)")
                print("📱 Response details: success=\(response.success), message=\(response.message ?? "nil"), code=\(response.enrollmentCode ?? "nil"), familyId=\(response.familyId ?? "nil")")
                completion(.success(response))
            case .failure(let error):
                print("📱 createEnrollmentCode API error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// Extension to make EnrollmentCodeResponse printable
extension EnrollmentCodeResponse: CustomStringConvertible {
    var description: String {
        return "EnrollmentCodeResponse(success: \(success), message: \(message ?? "nil"), enrollmentCode: \(enrollmentCode ?? "nil"), familyId: \(familyId ?? "nil"))"
    }
}
