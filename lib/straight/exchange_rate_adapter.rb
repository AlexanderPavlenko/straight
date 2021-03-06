module Straight
  module ExchangeRate

    class Adapter

      include Singleton

      class FetchingFailed       < StraightError; end
      class CurrencyNotSupported < StraightError; end

      def initialize(rates_expire_in: 1800)
        @rates_expire_in = rates_expire_in # in seconds
      end

      def convert_from_currency(amount_in_currency, btc_denomination: :satoshi, currency: 'USD')
        btc_amount = amount_in_currency.to_f/rate_for(currency)
        Satoshi.new(btc_amount, from_unit: :btc, to_unit: btc_denomination).to_unit
      end

      def convert_to_currency(amount, btc_denomination: :satoshi, currency: 'USD')
        amount_in_btc = Satoshi.new(amount.to_f, from_unit: btc_denomination).to_btc
        amount_in_btc*rate_for(currency)
      end

      def fetch_rates!
        raise "FETCH_URL is not defined!" unless self.class::FETCH_URL
        uri = URI.parse(self.class::FETCH_URL)
        begin
          @rates            = JSON.parse(uri.read(read_timeout: 4))
          @rates_updated_at = Time.now
        rescue OpenURI::HTTPError => e
          raise FetchingFailed
        end
      end

      def rate_for(currency_code)
        if !@rates_updated_at || (Time.now - @rates_updated_at) > @rates_expire_in
          fetch_rates!
        end
        nil # this should be changed in descendant classes
      end

      # This method will get value we are interested in from hash and
      # prevent failing with 'undefined method [] for Nil' if at some point hash doesn't have such key value pair
      def get_rate_value_from_hash(rates_hash, *keys)
        keys.inject(rates_hash) do |intermediate, key|
          if intermediate.respond_to?(:[])
            intermediate[key]
          else
            raise CurrencyNotSupported 
          end
        end
      end

      # We dont want to have false positive rate, because nil.to_f is 0.0
      # This method checks that rate value is not nil
      def rate_to_f(rate)
        rate ? rate.to_f : raise(CurrencyNotSupported)
      end

    end

  end
end
