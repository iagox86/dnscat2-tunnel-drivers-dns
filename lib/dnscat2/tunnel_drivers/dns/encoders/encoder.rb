# Encoding: ASCII-8BIT
##
# encoder.rb
# Created March, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'dnscat2/tunnel_drivers/dns/exception'
require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        class Encoder
          ENCODERS = [
            Encoders::Base32,
            Encoders::Hex
          ]

          public
          def initialize(default:, secondary:nil)
            if(ENCODERS.index(default).nil?)
              raise(Exception, "Unknown encoder type: #{default}")
            end

            # Switch back to default if they don't specify a secondary
            secondary = secondary || default
            if(ENCODERS.index(secondary).nil?)
              raise(Exception, "Unknown encoder type: #{secondary}")
            end

            @default = default
            @secondary = secondary
          end

          public
          def decode(data:)
            # Switch the encoder to secondary if the data contains a hyphen
            encoder = @default
            if(!data.index('-').nil?)
              encoder = @secondary

              # Remove hyphens
              data = data.gsub(/-/, '')
            end

            return encoder.decode(data: data), encoder
          end

          public
          def encode(data:, encoder:)
            return encoder.encode(data: data)
          end

          public
          def decode_encode(data:)
            decoded, encoder = decode(data: data)

            new_data = yield(decoded)

            return encoder.encode(data: new_data)
          end
        end
      end
    end
  end
end
