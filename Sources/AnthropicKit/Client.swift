import Foundation

public final class AnthropicClient {
    
    let host: URL
    let token: String
    
    public init(token: String) {
        self.host = URL(string: "https://api.anthropic.com/v1")!
        self.token = token
    }
    
    // Chats
    
    public func chat(_ payload: ChatRequest) async throws -> ChatResponse {
        var body = payload
        body.stream = nil
        
        var req = makeRequest(path: "messages", method: "POST")
        req.httpBody = try JSONEncoder().encode(body)
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(ChatResponse.self, from: data)
    }
    
    public func chatStream(_ payload: ChatRequest) -> AsyncThrowingStream<ChatResponse, Error> {
        var body = payload
        body.stream = true
        return makeAsyncRequest(path: "messages", method: "POST", body: body)
    }
    
    // Models
    
    public func models() async throws -> ModelListResponse {
        .init(
            models: [
                "claude-2.1",
                "claude-instant-1.2",
            ]
        )
    }
    
    // Private
    
    private func makeRequest(path: String, method: String) -> URLRequest {
        var req = URLRequest(url: host.appending(path: path))
        req.httpMethod = method
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("messages-2023-12-15", forHTTPHeaderField: "anthropic-beta")
        req.setValue(token, forHTTPHeaderField: "x-api-key")
        return req
    }
    
    private func makeAsyncRequest<Body: Codable, Response: Codable>(path: String, method: String, body: Body) -> AsyncThrowingStream<Response, Error> {
        var request = makeRequest(path: path, method: method)
        request.httpBody = try? JSONEncoder().encode(body)
        
        return AsyncThrowingStream { continuation in
            let session = StreamingSession<Response>(urlRequest: request)
            session.onReceiveContent = {_, object in
                continuation.yield(object)
            }
            session.onProcessingError = {_, error in
                continuation.finish(throwing: error)
            }
            session.onComplete = { object, error in
                continuation.finish(throwing: error)
            }
            session.perform()
        }
    }
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateInt = try container.decode(Int.self)
            return Date(timeIntervalSince1970: TimeInterval(dateInt))
        }
        return decoder
    }
}
