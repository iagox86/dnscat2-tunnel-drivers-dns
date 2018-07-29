# Encoding: ASCII-8BIT
##
# name_helper.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'
require 'singlogger'
require 'thread'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class NameHelper
          ENCODERS = [
            Encoders::Hex,
            Encoders::Base32,
          ]

          ##
          # tag: The text that goes in front of the name
          # domain: The text that goes after the name
          # max_subdomain_length: The maximum length of a sub-domain name (like
          #  the 'www' of 'www.google.com') - 63 is a safe bet
          # encoder: An encoder that implements encode() and decode() functions
          #  (probably from the encoders/ folder)
          # extra_bytes: Extra bytes that need to be reserved as part of the
          #  record (for example, MX packets need 2 extra bytes for the
          #  `preference` field).
          public
          def initialize(tag:, domain:, max_subdomain_length: 63, encoder: Encoders::Hex, extra_bytes:)
            @l = SingLogger.instance()
            @tag = tag == '' ? nil : tag
            @domain = domain == '' ? nil : domain

            if(!tag.nil? && (tag.length > 252))
              raise(Exception, "tag length is not sane")
            end
            if(!domain.nil? && (domain.length > 252))
              raise(Exception, "domain length is not sane")
            end

            if(max_subdomain_length < 1 || max_subdomain_length > 63)
              raise(Exception, "max_subdomain_length is not sane")
            end
            @max_subdomain_length = max_subdomain_length

            if(ENCODERS.index(encoder).nil?)
              raise(Exception, "Invalid encoder: #{encoder}")
            end
            @encoder = encoder

            @extra_bytes = extra_bytes
          end

          private
          def _number_of_segments(sub_length:, available:)
            # Each subdomain is actually one byte longer, because of the length
            # prefix. Round up because we can't have a partial byte.
            return (available.to_f / (sub_length + 1)).ceil
          end

          ##
          # The maximum length of data that can be encoded, including pre- or
          # appending tags and domain names.
          ##
          public
          def max_length()
            # Start with the max resource record length
            max_total_length = MAX_RR_LENGTH

            # Remove the 'extra' bytes (ie, the length, preference, etc fields)
            max_total_length -= @extra_bytes

            # Remove the final NUL terminator
            max_total_length -= 1

            # Remove the length of the tag and/or domain from the packet (including their periods)
            if(@tag)
              max_total_length = max_total_length - @tag.length - 1
            end
            if(@domain)
              max_total_length = max_total_length - @domain.length - 1
            end

            # Use this number to calculate the number of periods
            max_total_length -= _number_of_segments(sub_length: @max_subdomain_length, available: max_total_length)

            # Reduce it to the ratio of data that our encoder gives us
            return (max_total_length / @encoder::RATIO).floor
          end

          ##
          # data: The data to encode; no more than `max_length()` bytes may be passed
          #
          # Returns a resource record of the correct type.
          ##
          public
          def encode_name(data:)
            @l.debug("TunnelDrivers::DNS::NameHelper Encoding #{data.length} bytes of data")

            if(data.length > max_length())
              raise(Exception, "Tried to encode too much data")
            end

            name = @encoder.encode(data: data).chars.each_slice(@max_subdomain_length).map(&:join).join(".")

            # Add the @tag or @domain
            if(@tag)
              name = "#{@tag}.#{name}"
            end
            if(@domain)
              name = "#{name}.#{@domain}"
            end

            # Always double check that we aren't too big for a DNS packet
            if(name.length > MAX_RR_LENGTH)
              raise(Exception, "Tried to encode a name that's too long for the protocol (#{name.length} bytes)")
            end

            return name
          end
        end
      end
    end
  end
end
