require 'cgi'
require 'set'
require 'rubygems'
require 'openssl'
require 'net/https'

require 'rest_client'
require 'multi_json'

require 'eligible/version'
require 'eligible/util'
require 'eligible/json'
require 'eligible/eligible_object'
require 'eligible/api_resource'
require 'eligible/demographic'
require 'eligible/claim'
require 'eligible/enrollment'
require 'eligible/coverage'
require 'eligible/payment'
require 'eligible/x12'
require 'eligible/medicare'
require 'eligible/ticket'

# Errors
require 'eligible/errors/eligible_error'
require 'eligible/errors/api_connection_error'
require 'eligible/errors/authentication_error'
require 'eligible/errors/api_error'
require 'eligible/errors/invalid_request_error'

module Eligible
  @@api_key = nil
  @@test = false
  @@api_base = 'https://gds.eligibleapi.com/v1.1'
  @@api_version = 1.1

  def self.api_url(url='')
    @@api_base + url.to_s
  end

  def self.api_key
    @@api_key
  end

  def self.api_key=(api_key)
    @@api_key = api_key
  end

  def self.api_base
    @@api_base
  end

  def self.api_base=(api_base)
    @@api_base = api_base
  end

  def self.test
    @@test ? 'true' : 'false'
  end

  def self.test=(is_test)
    @@test = is_test
  end

  def self.api_version=(version)
    @@api_version = version
  end

  def self.api_version
    @@api_version
  end

  def self.request(method, url, api_key, params={}, headers={})
    api_key ||= @@api_key
    test = self.test
    api_key = params[:api_key] if params.has_key?(:api_key)
    test = params[:test] if params.has_key?(:test)

    raise AuthenticationError.new('No API key provided. (HINT: set your API key using "Eligible.api_key = <API-KEY>".') unless api_key

    lang_version = "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE})"
    ua = {
      :bindings_version => Eligible::VERSION,
      :lang => 'ruby',
      :lang_version => lang_version,
      :platform => RUBY_PLATFORM,
      :publisher => 'eligible',
      :uname => uname
    }

    # GET requests, parameters on the query string
    # POST requests, parameters as json in the body
    url = if _api_base = params.delete(:_api_base)
      "#{_api_base}#{url}"
    else
      self.api_url(url)
    end

    case method.to_s.downcase.to_sym
      when :get, :head
        url += "?api_key=#{api_key}"
        if params && params.count > 0
          query_string = Util.flatten_params(params).collect { |key, value| "#{key}=#{Util.url_encode(value)}" }.join('&')
          url += "&#{query_string}"
        end
        url +="&test=#{test}"
        payload = nil
      else
        params.merge!({ 'api_key' => api_key, 'test' => test })

        payload = if _no_json_payload = params.delete(:_no_json_payload)
          params
        else
          Eligible::JSON.dump(params)
        end
    end

    begin
      headers = { :x_eligible_client_user_agent => Eligible::JSON.dump(ua) }.merge(headers)
    rescue => e
      headers = {
        :x_eligible_client_raw_user_agent => ua.inspect,
        :error => "#{e} (#{e.class})"
      }.merge(headers)
    end

    headers = {
      :user_agent => "Eligible/v1 RubyBindings/#{Eligible::VERSION}",
      :authorization => "Bearer #{api_key}",
      :content_type => 'application/x-www-form-urlencoded'
    }.merge(headers)

    headers[:eligible_version] = self.api_version if self.api_version

    opts = {
      :method => method,
      :url => url,
      :headers => headers,
      :open_timeout => 30,
      :payload => payload,
      :timeout => 80
    }

    begin
      response = execute_request(opts)

    rescue SocketError => e
      self.handle_restclient_error(e)
    rescue NoMethodError => e
      # Work around RestClient bug
      if e.message =~ /\WRequestFailed\W/
        e = APIConnectionError.new('Unexpected HTTP response code')
        self.handle_restclient_error(e)
      else
        raise
      end
    rescue RestClient::ExceptionWithResponse => e
      if rcode = e.http_code and rbody = e.http_body
        self.handle_api_error(rcode, rbody)
      else
        self.handle_restclient_error(e)
      end
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      self.handle_restclient_error(e)
    end

    rbody = response.body
    rcode = response.code
    begin
      # Would use :symbolize_names => true, but apparently there is
      # some library out there that makes symbolize_names not work.
      resp = if params[:format] && params[:format].downcase == 'x12' || url[-4..-1].downcase == '/x12'
               rbody
             else
               Eligible::JSON.load(rbody)
             end
    rescue MultiJson::DecodeError
      raise APIError.new("Invalid response object from API: #{rbody.inspect} (HTTP response code was #{rcode})", rcode, rbody)
    end

    resp = Util.symbolize_names(resp)
    [resp, api_key]
  end

  private

  def self.uname
    @@uname ||= RUBY_PLATFORM =~ /linux|darwin/i ? `uname -a 2>/dev/null`.strip : nil
  end

  def self.execute_request(opts)
    RestClient::Request.execute(opts)
  end

  def self.handle_api_error(rcode, rbody)
    begin
      error_obj = Eligible::JSON.load(rbody)
      error_obj = Util.symbolize_names(error_obj)
      error = error_obj[:error] or raise EligibleError.new # escape from parsing
    rescue MultiJson::DecodeError, EligibleError
      raise APIError.new("Invalid response object from API: #{rbody.inspect} (HTTP response code was #{rcode})", rcode, rbody)
    end

    case rcode
      when 400, 404 then
        raise invalid_request_error(error, rcode, rbody, error_obj)
      when 401
        raise authentication_error(error, rcode, rbody, error_obj)
      else
        raise api_error(error, rcode, rbody, error_obj)
    end
  end

  def self.invalid_request_error(error, rcode, rbody, error_obj)
    InvalidRequestError.new(error, rcode, rbody, error_obj)
  end

  def self.authentication_error(error, rcode, rbody, error_obj)
    AuthenticationError.new(error[0][:message], rcode, rbody, error_obj)
  end

  def self.api_error(error, rcode, rbody, error_obj)
    APIError.new(error[0][:message], rcode, rbody, error_obj)
  end

  def self.handle_restclient_error(e)
    case e
      when RestClient::ServerBrokeConnection, RestClient::RequestTimeout
        message = "Could not connect to Eligible (#{@@api_base}).  Please check your internet connection and try again."
      when RestClient::SSLCertificateNotVerified
        message = "Could not verify Eligible's SSL certificate."
      when SocketError
        message = 'Unexpected error communicating when trying to connect to Eligible.'
      else
        message = 'Unexpected error communicating with Eligible. If this problem persists, let us know at support@eligible.com.'
    end
    message += "\n\n(Network error: #{e.message})"
    raise APIConnectionError.new(message)
  end

end
