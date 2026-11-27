require 'spec_helper'

describe Locomotive::Coal::Resources::Concerns::Request do

  # not lvh.me: a host on 127.0.0.1 never goes through a proxy
  let(:resource) do
    Class.new(Locomotive::Coal::Resources::Base) do
      def ping(raw = false); get('things', {}, raw); end
    end.new(URI('http://engine.example:4000/locomotive/api'), { email: 'fake' })
  end

  let(:url) { 'http://engine.example:4000/locomotive/api/things.json' }
  let(:ok)  { { status: 200, body: '["ok"]', headers: { 'Content-Type' => 'application/json' } } }

  before { allow($stdout).to receive(:puts) } # the retries warn on stdout

  it 'retries after a timeout' do
    stub_request(:get, url).to_timeout.then.to_return(ok)
    expect(resource.ping).to eq ['ok']
  end

  it 'gives up after 5 retries' do
    stub_request(:get, url).to_timeout
    expect { resource.ping }.to raise_error Locomotive::Coal::TimeoutError, /Timeout|expired/i
    expect(a_request(:get, url)).to have_been_made.times(6)
  end

  describe 'a proxy from the environment' do

    around do |example|
      saved = ENV.to_h.slice('http_proxy', 'no_proxy')
      ENV['http_proxy'] = 'http://proxy.example:8080'
      example.run
    ensure
      %w(http_proxy no_proxy).each { |key| ENV[key] = saved[key] }
    end

    before { stub_request(:get, url).to_return(ok) }

    it 'is used' do
      expect(resource.ping(true).env.request.proxy.uri.host).to eq 'proxy.example'
    end

    it 'is skipped for a host in no_proxy' do
      ENV['no_proxy'] = 'example'
      expect(resource.ping(true).env.request.proxy).to be_nil
    end

  end

end
