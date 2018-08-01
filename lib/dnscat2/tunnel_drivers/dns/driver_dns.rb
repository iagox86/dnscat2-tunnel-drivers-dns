# Encoding: ASCII-8BIT

##
# driver_dns.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
#
# A dnscat2 "driver" is simply something that will send and receive data.
# Outgoing and incoming data are literally just packets of bytes, with a
# particular maximum length. I call this a "transport protocol".
#
# This is strictly "layer 2" style - there is no de-duplication or delivery
# guarantees at this level. That's expected to be handled by the dnscat2
# protocol.
#
# I have documented this like crazy in README.md, so you best check that out!
##

require 'nesser'
require 'singlogger'
require 'socket'

require 'dnscat2/tunnel_drivers/dns/readers/standard'

require 'dnscat2/tunnel_drivers/dns/builders/a'
require 'dnscat2/tunnel_drivers/dns/builders/aaaa'
require 'dnscat2/tunnel_drivers/dns/builders/cname'
require 'dnscat2/tunnel_drivers/dns/builders/mx'
require 'dnscat2/tunnel_drivers/dns/builders/ns'
require 'dnscat2/tunnel_drivers/dns/builders/txt'

require 'dnscat2/tunnel_drivers/dns/encoders/encoders'

require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      ##
      # The main class for this library - see README.md for full usage
      # documentation!
      ##
      class Driver
        # A simple map of all the "builders" we support
        BUILDERS = {
          ::Nesser::TYPE_A     => Builders::A,
          ::Nesser::TYPE_AAAA  => Builders::AAAA,
          ::Nesser::TYPE_CNAME => Builders::CNAME,
          ::Nesser::TYPE_MX    => Builders::MX,
          ::Nesser::TYPE_NS    => Builders::NS,
          ::Nesser::TYPE_TXT   => Builders::TXT,
        }.freeze

        # Just for testing, probably
        attr_reader :passthrough

        ##
        # Take a question, unpack it, pass it to the sink, get the data back,
        # and encode the message into a series of resource records.
        ##
        private
        def _handle_question(question:)
          # We need to be able to set the question_type separate from
          # question.type in TYPE_ANY situations
          question_type = question.type
          # Handle the ANY type
          if question.type == ::Nesser::TYPE_ANY
            # We need the key so we can build the return packet later
            # (We exclude AAAA because not all OSes support it (I'm looking at
            # you, Windows!)
            question_type = BUILDERS.keys.reject { |k| k == ::Nesser::TYPE_AAAA }.sample
            builder = BUILDERS[question_type]
            @l.debug('TunnelDrivers::DNS ANY request!')
          else
            # Make sure the incoming message is a known type
            builder = BUILDERS[question.type]
            if builder.nil?
              raise(Exception, "Received a DNS packet of unknown type: #{question.type}")
            end
          end

          # We only have one reader right now, so use it
          reader = Readers::Standard.new

          # Try and parse via domain(s)
          incoming_data = nil
          extra = nil
          @domains.each do |d|
            incoming_data = reader.try_domain(name: question.name, domain: d[:domain], encoder: d[:encoder])
            if incoming_data
              extra = d
              break
            end
          end

          # If the domain thing didn't work out, try to find a tag
          if incoming_data.nil?
            @tags.each do |t|
              incoming_data = reader.try_tag(name: question.name, tag: t[:tag], encoder: t[:encoder])
              if incoming_data
                extra = t
                break
              end
            end
          end

          if incoming_data.nil?
            @l.debug("TunnelDrivers::DNS question probably wasn't for us!")
            return nil
          end

          # Initialize a builder with the infos we got (we need this now so we
          # can determine the maximum length)
          builder = builder.new(tag: extra[:tag], domain: extra[:domain], encoder: extra[:encoder])

          # Exchange data with the sink
          outgoing_data = extra[:sink].feed(data: incoming_data, max_length: builder.max_length)

          # Handle a nil return cleanly
          outgoing_data ||= ''

          # Make sure the sink didn't mess with us
          if outgoing_data.length > builder.max_length
            raise(Exception, "The sink returned too much data: #{outgoing_data.length}, max_length was #{builder.max_length}")
          end

          # Encode it into one or more resource records
          rrs = builder.build(data: outgoing_data)

          # Stuff each resource record into an Answer object
          return rrs.map do |rr|
            Nesser::Answer.new(
              name: question.name,
              type: question_type,
              cls:  question.cls,
              ttl:  3600, # TTL doesn't really matter
              rr:   rr,
            )
          end
        end

        ##
        # Unpack and sanity check a transaction. This is also where all
        # exceptions are handled.
        ##
        private
        def _handle_transaction(transaction:)
          @l.debug('TunnelDrivers::DNS Received a message!')

          request = transaction.request
          if request.questions.length != 1
            raise(Exception, "Incoming DNS request had a weird number of questions (expected: 1, it had: #{request.questions.length})")
          end

          question = request.questions[0]
          @l.debug("TunnelDrivers::DNS Question = #{question}")

          answers = _handle_question(question: question)
          @l.debug("TunnelDrivers::DNS Answers = #{answers || 'n/a'}")
          if !answers || answers.empty?
            if @passthrough
              @l.debug("Sending transaction upstream to #{@passthrough[:host]}:#{@passthrough[:port]}")
              transaction.passthrough!(host: @passthrough[:host], port: @passthrough[:port])
            else
              @l.debug('Responding with NXDomain')
              transaction.error!(Nesser::RCODE_NAME_ERROR)
            end
            return
          end

          transaction.answer!(answers)

        # A minor exception
        rescue Exception => e # rubocop:disable Lint/RescueException
          @l.error("TunnelDrivers::DNS An error occurred processing the DNS request: #{e}")
          transaction.error!(Nesser::RCODE_SERVER_FAILURE)

        # A BAD exception! We don't want these to ever happen! We still want to
        # catch this, though, because we NEVER want to kill the service.
        rescue ::Exception => e # rubocop:disable Lint/RescueException
          @l.fatal("TunnelDrivers::DNS A serious error occurred processing the DNS request: #{e}")
          e.backtrace.each do |bt|
            @l.debug(bt.to_s)
          end
          transaction.error!(Nesser::RCODE_SERVER_FAILURE)
        end

        ##
        # Create an instance of the tunnel driver.
        #
        # host: The ip address to listen on
        # port: The port to listen on
        # passthrough: Set to an `ip` or `ip`:`port` to do passthrough for
        #   unknown domain names
        ##
        public
        def initialize(host: '0.0.0.0', port: 53, passthrough: nil)
          @l = SingLogger.instance
          @l.debug("TunnelDrivers::DNS New instance! host = #{host}, port = #{port}, passthrough: #{passthrough}")

          @host     = host
          @port     = port

          # Convert passthrough from `host` or `host:port` to the two separate
          # values
          if passthrough
            passthrough = passthrough.split(/:/, 2)
            port = passthrough[1].to_i

            @passthrough = {
              host: passthrough[0],
              port: port.zero? ? 53 : port,
            }
          end

          # Create the socket and start the listener
          begin
            @s = ::UDPSocket.new
            @nesser = ::Nesser::Nesser.new(s: @s, logger: @l, host: @host, port: @port) do |transaction|
              _handle_transaction(transaction: transaction)
            end
          rescue ::StandardError => e
            raise(Exception, "Error starting the DNS server: #{e}")
          end

          # Create tags and domains lists
          @tags    = []
          @domains = []
        end

        ##
        # Kill the listener thread.
        ##
        public
        def kill
          if @nesser.nil?
            raise(Exception, "DNS tunnel isn't running!")
          end

          @nesser.stop
          @nesser = nil
          @s.close
        end

        public
        def add_domain(domain:, sink:, encoder:)
          # Sanity check the domain
          @domains.map { |d| d[:domain] }.each do |d|
            if d.end_with?('.' + domain) || domain.end_with?('.' + d)
              raise(Exception, "Domain conflicts with a domain that's already enabled! #{domain} :: #{d}")
            end
          end

          @domains << {
            domain:  domain,
            sink:    sink,
            encoder: Encoders.get_by_name(encoder),
          }
        end

        public
        def remove_domain(domain:)
          @domains = @domains.reject do |d|
            d[:domain] == domain
          end
        end

        ##
        # Add a tag-based listener.
        ##
        public
        def add_tag(tag:, sink:, encoder:)
          # Sanity check the tag
          @tags.map { |t| t[:tag] }.each do |t|
            if t.start_with?(tag + '.') || tag.start_with?(t + '.')
              raise(Exception, "Tag conflicts with a tag that's already enabled! #{tag} :: #{t}")
            end
          end

          @tags << {
            tag:     tag,
            sink:    sink,
            encoder: Encoders.get_by_name(encoder),
          }
        end

        public
        def remove_tag(tag:)
          @tags = @tags.reject do |t|
            t[:tag] == tag
          end
        end

        ##
        # Convenience function to add a domain, a tag, or both at the same time
        ##
        public
        def add_sink(domain: nil, tag: nil, **args)
          if domain
            add_domain(domain: domain, **args)
          end

          if tag
            add_tag(tag: tag, **args)
          end
        end

        ##
        # Convenience function to add multiple domains, tags, or both at the
        # same time
        ##
        public
        def add_sinks(domains: [], tags: [], **args)
          domains.each { |d| add_domain(domain: d, **args) }
          tags.each { |t| add_tag(tag: t, **args) }
        end

        ##
        # Returns when the service stops (or never).
        ##
        public
        def wait
          unless @nesser
            return
          end
          @nesser.wait
        end
      end
    end
  end
end
