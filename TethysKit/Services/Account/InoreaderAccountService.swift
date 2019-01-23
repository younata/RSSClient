import Result
import CBGPromise
import FutureHTTP

struct InoreaderAccountService: AccountService {
    let clientId: String
    let clientSecret: String
    let credentialService: CredentialService
    let httpClient: HTTPClient
    let dateOracle: () -> Date

    func accounts() -> Future<[Result<Account, TethysError>]> {
        return self.credentialService.credentials().map { result in
            switch result {
            case .success(let credentials):
                return Promise<Result<Account, TethysError>>.when(credentials.map(self.userInfo))
            case .failure(let error):
                return Promise<Result<Account, TethysError>>.resolved([.failure(error)])
            }
        }
    }

    func authenticate(code: String) -> Future<Result<Account, TethysError>> {
        guard let url = URL(string: "https://www.inoreader.com/oauth2/token") else {
            return Promise<Result<Account, TethysError>>.resolved(.failure(.unknown))
        }
        let request = URLRequest(
            url: url,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            method: .post(formData(contents: [
                "code": code,
                "redirect_uri": "https://tethys.younata.com/oauth",
                "client_id": self.clientId,
                "client_secret": self.clientSecret,
                "scope": "",
                "grant_type": "authorization_code"
            ]))
        )
        return self.httpClient.request(request).map { result -> Result<Credential, TethysError> in
            switch result {
            case .failure(let error):
                return .failure(.network(url, error.tethys))
            case .success(let response):
                if let error = response.tethysError {
                    return .failure(.network(url, error))
                }

                let decoder = JSONDecoder()
                let credentialResponse: OAuthTokenResponse
                do {
                    credentialResponse = try decoder.decode(OAuthTokenResponse.self, from: response.body)
                } catch let error {
                    dump(error)
                    return .failure(.network(url, .badResponse))
                }
                return .success(Credential(
                    access: credentialResponse.access_token,
                    expiration: self.dateOracle().addingTimeInterval(credentialResponse.expires_in),
                    refresh: credentialResponse.refresh_token,
                    accountId: "",
                    accountType: .inoreader
                ))
            }
        }.map { credentialResult in
            switch credentialResult {
            case .failure(let error):
                return Promise<Result<Account, TethysError>>.resolved(.failure(error))
            case .success(let tempCredential):
                return self.userInfo(credential: tempCredential).map { accountResult in
                    accountResult.mapFuture { account in
                        let credential = Credential(
                            access: tempCredential.access,
                            expiration: tempCredential.expiration,
                            refresh: tempCredential.refresh,
                            accountId: account.id,
                            accountType: tempCredential.accountType
                        )
                        return self.credentialService.store(credential: credential)
                            .map { storeResult -> Result<Account, TethysError> in
                                switch storeResult {
                                case .failure(let error):
                                    return .failure(error)
                                case .success:
                                    return .success(account)
                                }
                        }
                    }
                }
            }
        }
    }

    private func userInfo(credential: Credential) -> Future<Result<Account, TethysError>> {
        guard let url = URL(string: "https://www.inoreader.com/reader/api/0/user-info") else {
            return Promise<Result<Account, TethysError>>.resolved(.failure(.unknown))
        }
        var request = URLRequest(url: url)
        request.addValue(credential.authorization(), forHTTPHeaderField: "Authorization")
        return self.httpClient.request(request).map { result -> Result<Account, TethysError> in
            switch result {
            case .failure(let error):
                return .failure(.network(url, error.tethys))
            case .success(let response):
                if let error = response.tethysError {
                    return .failure(.network(url, error))
                }

                let decoder = JSONDecoder()
                let accountResponse: AccountServiceResponse
                do {
                    accountResponse = try decoder.decode(AccountServiceResponse.self, from: response.body)
                } catch let error {
                    dump(error)
                    return .failure(.network(url, .badResponse))
                }

                return .success(Account(
                    kind: .inoreader,
                    username: accountResponse.userName,
                    id: accountResponse.userId
                ))
            }
        }
    }
}

private struct AccountServiceResponse: Decodable {
    let userId: String
    let userName: String
}

struct OAuthTokenResponse: Decodable {
    let access_token: String
    let expires_in: TimeInterval
    let refresh_token: String
}
