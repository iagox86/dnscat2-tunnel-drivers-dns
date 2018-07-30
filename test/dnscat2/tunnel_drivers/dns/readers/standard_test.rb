# Encoding: ASCII-8BIT

require 'test_helper'

require 'nesser'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/readers/standard'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Readers
        class StandardTest < ::Test::Unit::TestCase
          def setup
            @reader = Standard.new(tags: ['abc'], domains: ['test.com', 'test2.com'])
          end

          def test_unrecognized
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: 'hello.this.com', type: 1, cls: 1))
            assert_nil(data)
            assert_nil(tag)
            assert_nil(domain)

            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '.com', type: 1, cls: 1))
            assert_nil(data)
            assert_nil(tag)
            assert_nil(domain)

            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: 'com', type: 1, cls: 1))
            assert_nil(data)
            assert_nil(tag)
            assert_nil(domain)

            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '', type: 1, cls: 1))
            assert_nil(data)
            assert_nil(tag)
            assert_nil(domain)
          end

          def test_known_domain
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '414141.test.com', type: 1, cls: 1))
            assert_equal('AAA', data)
            assert_equal(nil, tag)
            assert_equal('test.com', domain)
          end

          def test_other_known_domain
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '41414142.test2.com', type: 1, cls: 1))
            assert_equal('AAAB', data)
            assert_equal(nil, tag)
            assert_equal('test2.com', domain)
          end

          def test_known_tag
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: 'abc.414141', type: 1, cls: 1))
            assert_equal('AAA', data)
            assert_equal('abc', tag)
            assert_equal(nil, domain)
          end

          def test_case_insensitive_tag
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: 'aBc.414141', type: 1, cls: 1))
            assert_equal('AAA', data)
            assert_equal('abc', tag)
            assert_equal(nil, domain)
          end

          def test_case_insensitive_domain
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '414141.tESt.com', type: 1, cls: 1))
            assert_equal('AAA', data)
            assert_equal(nil, tag)
            assert_equal('test.com', domain)
          end

          def test_domain_has_priority
            reader = Standard.new(tags: ['414141'], domains: ['434343'])
            data, tag, domain = reader.read_data(question: Nesser::Question.new(name: '414141.424242.434343', type: 1, cls: 1))
            assert_equal('AAABBB', data)
            assert_equal(nil, tag)
            assert_equal('434343', domain)
          end

          def test_no_data
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '.test.com', type: 1, cls: 1))
            assert_equal('', data)
            assert_nil(tag)
            assert_equal('test.com', domain)

            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: 'test.com', type: 1, cls: 1))
            assert_equal('', data)
            assert_nil(tag)
            assert_equal('test.com', domain)
          end

          def test_base32
            reader = Standard.new(tags: ['abc'], domains: ['test.com', 'test2.com'], encoder: Encoders::Base32)
            data, tag, domain = reader.read_data(question: Nesser::Question.new(name: 'ifaucqi.test.com', type: 1, cls: 1))
            assert_equal('AAAA', data)
            assert_nil(tag)
            assert_equal('test.com', domain)
          end

          def test_weird_periods
            data, tag, domain = @reader.read_data(question: Nesser::Question.new(name: '4.141.test.com', type: 1, cls: 1))
            assert_equal('AA', data)
            assert_nil(tag)
            assert_equal('test.com', domain)
          end
        end
      end
    end
  end
end
