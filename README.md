# Dnscat2::Tunneldrivers::Dns

This is a "tunnel driver" for dnscat2 (specifically, dnscat2-core).

A tunnel driver is a "driver" that sits between dnscat2 and the Internet.
Despite the project's name, a dnscat2 driver can use any protocol - TCP, UDP,
ICMP, HTTPS, etc.

This driver, in particular, implements dnscat2's namesake protocol: DNS. It
implements encoding and decoding to a number of record types, and in two
different formats: hex and base32.

This README should be considered the authoritative source for the dnscat2
DNS tunnel protocol, superseding others.

## Protocol

The basic concept is: this starts a DNS server on port 53, using the
[Nesser](https://github.com/iagox86/nesser) library. Data enters via a DNS
request, encoded into the requested name. The data is decoded and send to a
"sink", which returns the data that is to be sent out (if any). The outgoing
data is encoded as whatever record type was requested (or any of them if ANY
was the requested type), and returned.

In order to do all that, we're going to have to cover an awful lot of ground!
So let's look at those generally in order.

This protocol is essentially layer 2 - it's simply data on the wire. There are
no guarantees that data will arrive, will be acknowledged, or won't be
duplicated (DNS lovvvvves duplicating data). If guarantees are needed - which
is generally the case - a higher level protocol is required (which is where
[dnscat2-core](https://github.com/iagox86/dnscat2-core) comes into play).

### Incoming requests

When a request is made, data is encoded directly into the name. The scheme is
generally decided in advance and agreed on for the client and server, but it can
also be requested specifically by the client instead (see the encoding section
below for more information).

A request containing the data `AAAA` will be encoded as `41414141` in hex, or
`ifaucqi` in base32. From here on we'll use hex, since it's easier to convert
mentally.

This request needs to be identified as a dnscat2 request, so we don't
waste a ton of time and effort trying to decode random traffic. It is done by
either prepending a `tag`, such as `abc.41414141`, or appending a domain, such
as `41414141.example.org`.

Traditionally, dnscat2 has done this by using the domain provided on the
commandline, or, if none was, by prepending the tag `dnscat`. This will likely
continue.

The client MUST either prepend a `tag` or append a `domain`. The server MUST
attempt to parse any request with a known `tag` or `domain`.

The DNS protocol does not allow any "subdomain" (such as `a` in `a.example.org`)
to be longer than 63 bytes, so it's necessary to break it into multiple chunks.
The protocol is agnostic as to how many dots are in the name and where they are.
As such, `4.1.4.1.example.org` is functionally identical to `41.41.example.org`,
`414.1.example.com`, and `4141.example.com`.

The client can choose how to place the dots for either efficiency (63-byte
subdomains) or stealth (normal-length subdomains). It does not matter.

### Sink

The sink is a programming concept rather than a protocol one, so I don't want
to expound on it here (check out the Usage section below).

Essentially, *something* takes the data that comes in, does something with it,
and returns data to send out.

The takeaway to remember here is that DNS is a request-response protocol. In
order for the server to send data to the client, data (even if it's a blank
packet) has to come in.

### Outgoing responses

Outgoing responses are encoded into the record type that was requested by the
client. The currently supported types are `A`, `AAAA`, `CNAME`, `NS`, `MX`, and
`TXT`. If the request is for `ANY`, it's up to the server which type to use (in
general, it's nice to randomize it).

How the data is actually encoded actually depends on the record type. Since the
encoding for the record type varies a little bit, we'll look at them
individually.

#### `TXT` records

A `TXT` record is pretty much free-form: you specify binary data in whatever
format or structure you want. But, there's a problem: some libraries don't
handle NUL bytes (`\x00`) very well (I'm looking at you, Windows!). As a result,
if we want to be compatible with OS resolvers (we do), we unfortunately have
to encode the data.

As a result, data that is returned in a `TXT` record is encoded in the same format
as the incoming data (hex or base32) and stuffed into a `TXT` record that is
returned.

#### `CNAME` and `NS` records

A `CNAME` and `NS` record are essentially the same: a name is simply returned.
The data is encoded into a name in the exact same way as the name in the
request: encoded into a domain that either starts with the tag or ends with the
domain. Like encoding the request, periods can be inserted anywhere, and you
can add as much data as the protocol allows, or as little data as you like.

#### `MX` record

An `MX` record is essentially the same as `CNAME`/`NS` - the name is encoded
into the `exchange` field as a typical name (with tag or domain). The `MX`
record type also defined a `preference` field, which can have any random value
(the client MUST ignore it). I randomize it between `[10, 20, 30, 40, 50]`,
because those are realistic values.

#### `A` and `AAAA` records

We finally come to the hardest record types: `A` and `AAAA`.

These are tricky, because multiple records are required (unless you want to send
three bytes at a time). I found out the hard way that DNS servers on the
Internet can re-arrange the records, so each record MUST be indexed. On the
plus side, encoding is not necessary, so data is sent as pure binary.

First, each record in the field starts with a sequence number. The actual
numbers aren't too important, just that each record has a higher number than
the previous (so `1, 2, 3, 4, ...` is as valid as `1, 15, 20, 33, 100, 101,
...`).

Second, the second value is the total length (in bytes) of the data being
transferred.

Finally, the last addresses is padded out with whatever value you like to make
up a full address (I use `\xFF`).

After that, the data is encoded (byte by byte) into addresses: either IPv4 or
IPv6 addresses.

Let's look at encoding `"ABCDEFGHI"` in IPv4:
* `0.9.65.66` - `0` is the sequence number, and `9` is the length. `65` and `66`
  are the first two bytes of data
* `1.67.68.69` - `1` is the sequence number, followed by three bytes of data
* `2.70.71.72` - `2` is the sequence number, followed by more data
* `3.73.255.255` - `3` is the sequence number, `73` is the last byte of data,
  and `255.255` are padding

Now let's encode the full alphabet - `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` - as IPv6:
* `001a:4142:4344:4546:4748:494a:4b4c:4d4e` - The sequence number is `00` (keep
  in mind that leading zeroes aren't normally printed), `1a` is the length, and
  the remainder of the address is data
* `14f:5051:5253:5455:5657:5859:5aff:ffff` - The sequence number is `11`, the
  values from `4f` to `5a` are data, and the `ff:ffff` at the end is padding.

Keep in mind that when you see these values on the wire, they may be in a
different order! Hence, the sequence numbers.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'dnscat2-tunneldrivers-dns'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install dnscat2-tunneldrivers-dns

## Usage

It can be imported using:

    require 'tunnel-drivers-dns'

And initialized as:

    driver = Dnscat2::TunnelDrivers::DNS::Driver.new(
      tags:
      domains:
      sink:
      host:
      port:
      encoder:
    )

Started with:

    driver.start()

Stopped (optionally) with:

    driver.stop()

Or the program can simply terminate. Additionally, if you need the program to 
wait until it's finished, you can use

    driver.join()

TODO: Meaning of the parameters, sink

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/iagox86/dnscat2-tunneldrivers-dns
