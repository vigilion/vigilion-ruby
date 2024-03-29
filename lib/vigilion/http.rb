module Vigilion
  class HTTP
    attr_accessor :url, :options, :method

    def initialize
      validate_access_keys
      @conn = ::Faraday.new(url: Configuration.server_url) do |c|
        c.request :multipart
        c.request :json
        c.response :json, content_type: /\bjson$/
        if Configuration.debug
          c.response :detailed_logger, Configuration.logger
        end
        c.adapter ::Faraday.default_adapter
        c.headers = {
          'X-Api-Key' => Configuration.access_key_id,
          'User-Agent' => "Vigilion #{Vigilion::VERSION} (#{RUBY_PLATFORM}, Ruby #{RUBY_VERSION})"
        }
      end
    end

    def scan_url(key, url, options = {})
      url_to_scan = if Configuration.do_not_unencode
        url
      else
        Addressable::URI.unescape(url)
      end
      send scan: options.merge({ key: key, url: url_to_scan })
    end

    def scan_path(key, path, options = {})
      send scan: options.merge({ key: key, file: Faraday::UploadIO.new(path, 'application') })
    end

    def get(uuid)
      response = @conn.get "/scans/#{uuid}"
      response.body
    end

    def validate
      response = @conn.get "/projects/validate"
      process_response("", response)
    end

    def self.digest(body)
      Digest::MD5.hexdigest("#{body}#{Vigilion::Configuration.secret_access_key}")
    end

  private

    HOW_TO_CONFIGURE = <<-MESSAGE
To configure the access keys add a Vigilion.configure block during the application start up.
If you are using vigilion-rails, execute `rails g vigilion:install` to create an initializer.
By default the initializer uses environment variables so make sure they are present.
If you don't know your access keys, go to https://www.vigilion.com and get them!
MESSAGE

    INVALID_CREDENTIALS = <<-MESSAGE
The provided credentials are not valid.
Visit https://www.vigilion.com to get the access keys of your project.
MESSAGE

    def send(request)
      response = @conn.post "/scans", request
      process_response(request, response)
    end

    def process_response(request, response)
      raise Vigilion::Error.new(INVALID_CREDENTIALS) if response.status == 401
      raise Vigilion::Error.new("Payment required: #{response.body['error']}") if response.status == 402
      unless response.success?
        raise Vigilion::Error.new("Invalid scanning request: #{request}. Status: #{response.status}. Response: #{response.body}")
      end
      response.body
    end

    def validate_access_keys
      raise Vigilion::Error.new("Configuration.access_key_id is not present\n#{HOW_TO_CONFIGURE}") unless Configuration.access_key_id
      raise Vigilion::Error.new("Configuration.secret_access_key is not present\n#{HOW_TO_CONFIGURE}") unless Configuration.secret_access_key
    end
  end
end
