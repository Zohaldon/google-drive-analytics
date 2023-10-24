# frozen_string_literal: true

require 'time'
require 'jwt'
require 'faraday'
require 'json'
require 'openssl'

module GoogleAuthenticator
  class Authenticator
    SCOPES = [
      'https://www.googleapis.com/auth/drive.metadata.readonly',
      'https://www.googleapis.com/auth/admin.directory.user.readonly'
    ].freeze

    def authenticate(issuer, subject)
      conn = Faraday.new(
        url: 'https://oauth2.googleapis.com',
        params: {
          grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          assertion: signed_jwt_token(issuer, subject)
        },
        headers: { 'Content-Type' => 'application/json' }
      )

      response = conn.post('/token')
      response.status == 200 ? JSON.parse(response.body)['access_token'] : log_error(subject, response.body)
    end

    private

    def header
      {
        alg: 'RS256',
        typ: 'JWT'
      }
    end

    def claimset(issuer, subject)
      time_now = Time.now.to_i
      time_to_expiry = time_now + 3600

      {
        iss: issuer,
        sub: subject,
        scope: SCOPES.join(' '),
        aud: 'https://oauth2.googleapis.com/token',
        exp: time_to_expiry,
        iat: time_now
      }
    end

    def rsa_private_key
      raw_private_key = File.read('./rsa_private_key.pem')
      OpenSSL::PKey::RSA.new(raw_private_key)
    end

    def signed_jwt_token(issuer, subject)
      JWT.encode(claimset(issuer, subject), rsa_private_key, 'RS256', header)
    end

    def log_error(subject, response)
      File.open('./error.log', 'a') do |f|
        f.write("Error: #{subject} - #{response}\n")
      end

      nil
    end
  end

  def self.access_token(issuer, subject)
    google_authenticator = Authenticator.new
    google_authenticator.authenticate(issuer, subject)
  end
end
