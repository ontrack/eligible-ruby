module Eligible
  class Payment < APIResource

    class << self

      def get(params, api_key=nil)        
        puts "/claims/#{params[:reference_id]}/payment_status.json"
        response, api_key = Eligible.request(:get, "/claims/#{params[:reference_id]}/payment_status.json", api_key, params)
        Util.convert_to_eligible_object(response, api_key)
      end

    end
  end
end