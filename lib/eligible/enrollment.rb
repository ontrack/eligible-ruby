module Eligible
  class Enrollment < APIResource

    class << self

      def get(params, api_key=nil)
        response, api_key = Eligible.request(:get, "/enrollment_npis/#{params[:enrollment_npi_id]}.json", api_key, params)
        Util.convert_to_eligible_object(response, api_key)
      end

      def post(params, api_key=nil)
        response, api_key = Eligible.request(:post, "/enrollment_npis.json", api_key, params)
        Util.convert_to_eligible_object(response, api_key)
      end

      def update(params, api_key=nil)
        response, api_key = Eligible.request(:put, "/enrollment_npis/#{params[:enrollment_npi_id]}.json", api_key, params)
        Util.convert_to_eligible_object(response, api_key)
      end

      def download_received_pdf(params, api_key=nil)
        response, api_key = Eligible.request(:get, "/enrollment_npis/#{params[:enrollment_npi_id]}/received_pdf/download", api_key, params.merge(
          _api_base: "https://gds.eligibleapi.com/v1.5",
          format: "x12",
        ))
        response
      end

      def create_original_signature_pdf(params, api_key=nil)
        response, api_key = Eligible.request(:post, "/enrollment_npis/#{params[:enrollment_npi_id]}/original_signature_pdf", api_key, params.merge(
          _api_base: "https://gds.eligibleapi.com/v1.5",
          _no_json_payload: true,
        ))
        Util.convert_to_eligible_object(response, api_key)
      end
    end

    def enrollment_npis
      values.first[:enrollment_npis]
    end

  end
end
