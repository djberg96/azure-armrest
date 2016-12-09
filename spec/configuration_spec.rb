########################################################################
# configuration_spec.rb
#
# Specs for the Azure::Armrest::Configuration class.
########################################################################
require 'spec_helper'
require 'timecop'

describe Azure::Armrest::Configuration do
  let(:options) do
    {
      :client_id       => 'cid' + Time.now.to_f.to_s,
      :client_key      => 'ckey',
      :tenant_id       => 'tid',
      :subscription_id => 'sid'
    }
  end

  subject { described_class.new(options) }

  let(:log)            { 'azure-armrest.log' }
  let(:proxy)          { 'http://www.somewebsiteyyyyzzzz.com/bogusproxy' }
  let(:singleton)      { Azure::Armrest::Configuration }
  let(:token_response) { '{"expires_in":"3599","access_token":"eyJ0eXAiOiJKV1Q"}' }

  before { setup_params }
  after  { File.delete(log) if File.exist?(log) }

  context 'constructor' do
    it 'requires a single argument' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'requires a client_id' do
      options.delete(:client_id)
      expect { described_class.new(options) }.to raise_error(ArgumentError)
    end

    it 'requires a client_key' do
      options.delete(:client_key)
      expect { described_class.new(options) }.to raise_error(ArgumentError)
    end

    it 'does not require a subscription_id' do
      options.delete(:subscription_id)
      expect { described_class.new(options) }.to_not raise_error(ArgumentError)
    end

    it 'requires token and token_expiration together' do
      options[:token] = 'token_string'
      expect { described_class.new(options) }.to raise_error(ArgumentError)

      options[:token_expiration] = Time.now.utc + 1.month
      expect(described_class.new(options).token).to eq('token_string')
    end
  end

  context 'instances' do
    context 'regular methods' do
      it 'defines a subscription_id= method' do
        expect(subject).to respond_to(:subscription_id=)
      end

      it 'defines a subscriptions method' do
        expect(subject).to respond_to(:subscriptions)
      end
    end

    context 'accessors' do
      it 'defines an api_version accessor' do
        expect(subject.api_version).to eql('2015-01-01')
        subject.api_version = '2016-01-01'
        expect(subject.api_version).to eql('2016-01-01')
      end

      it 'defines a resource_group accessor' do
        expect(subject.resource_group).to be_nil
        subject.resource_group = 'agroup'
        expect(subject.resource_group).to eql('agroup')
      end

      it 'defines a content_type accessor' do
        expect(subject.content_type).to eql('application/json')
        subject.content_type = 'application/text'
        expect(subject.content_type).to eql('application/text')
      end

      it 'defines a grant_type accessor' do
        expect(subject.grant_type).to eql('client_credentials')
        subject.grant_type = 'other_credentials'
        expect(subject.grant_type).to eql('other_credentials')
      end

      it 'defines an accept accessor' do
        expect(subject.accept).to eql('application/json')
        subject.accept = 'application/text'
        expect(subject.accept).to eql('application/text')
      end

      it 'defines a client_id accessor' do
        expect(subject.client_id).to eql(options[:client_id])
        subject.client_id = 'new_id'
        expect(subject.client_id).to eql('new_id')
      end

      it 'defines a client_key accessor' do
        expect(subject.client_key).to eql(options[:client_key])
        subject.client_key = 'new_key'
        expect(subject.client_key).to eql('new_key')
      end

      it 'defines a tenant_id accessor' do
        expect(subject.tenant_id).to eql(options[:tenant_id])
        subject.tenant_id = 'new_id'
        expect(subject.tenant_id).to eql('new_id')
      end

      it 'defines a subscription_id accessor' do
        allow(subject).to receive(:validate_subscription).and_return(true)
        expect(subject.subscription_id).to eql(options[:subscription_id])
        subject.subscription_id = 'new_id'
        expect(subject.subscription_id).to eql('new_id')
      end

      it 'defines a max_threads accessor' do
        expect(subject.max_threads).to eql(10)
        subject.max_threads = 8
        expect(subject.max_threads).to eql(8)
      end
    end

    context 'max_threads' do
      it 'defaults to 1 thread if the VCR singleton is defined' do
        class VCR; end
        expect(subject.max_threads).to eql(1)
      end
    end

    context 'http proxy' do
      before do
        allow(ENV).to receive(:[]).with('http_proxy').and_return(proxy)
      end

      it 'uses the http_proxy environment variable for the proxy value if set' do
        expect(subject.proxy).to eq(proxy)
      end

      it 'accepts a URI object for a proxy' do
        options['proxy'] = URI.parse(proxy)
        expect(subject.proxy).to eq(proxy)
      end
    end

    context 'providers' do
      it 'defines a providers method that returns the expected value' do
        expect(subject.providers).to eql(@providers_response)
      end

      it 'supports provider and service api version query' do
        expect(subject.provider_default_api_version('microsoft.compute', 'services')).to eql('2016-03-25')
        expect(subject.provider_default_api_version('Microsoft.Compute', 'operations')).to eql('2016-03-25')
        expect(subject.provider_default_api_version('microsoft.storage', 'Stuff')).to eql('2016-03-25')
      end
    end

    context 'tokens' do
      it 'defines a set_token method which takes a token string an token expiration time' do
        time = Time.now.utc + 1000
        expect(subject.set_token('xxx', time)).to eql(['xxx', time])
        expect(subject.token).to eql('xxx')
        expect(subject.token_expiration).to eql(time)
      end

      it 'raises an error if the token expiration is invalid in set_token' do
        expect { subject.set_token('xxx', Time.now.utc - 100) }.to raise_error(ArgumentError)
      end

      context 'token generation' do
        it 'caches the token to be reused for the same client' do
          token = "Bearer eyJ0eXAiOiJKV1Q"
          expect(RestClient::Request).to receive(:execute).exactly(1).times.and_return(token_response)
          expect(subject.token).to eql(token)
        end

        it 'generates different tokens for different clients' do
          expect(RestClient::Request).to receive(:execute).exactly(2).times.and_return(token_response)
          subject.token
          described_class.new(options.merge(:client_id => 'cid2')).token
        end

        it 'regenerates the token if the old token expires' do
          expect(RestClient::Request).to receive(:execute).exactly(2).times.and_return(token_response)
          subject.token
          Timecop.freeze(Time.now.utc + 3600) { subject.token }
        end
      end
    end

    context 'subscription validation' do
      it 'raises an error if the subscription is invalid' do
        allow_any_instance_of(Azure::Armrest::Configuration).to receive(:validate_subscription).and_raise(ArgumentError)
        expect { Azure::Armrest::Configuration.new(options) }.to raise_error(ArgumentError)
      end
    end
  end

  context 'singletons' do
    before do
      Azure::Armrest::Configuration.clear_caches
    end

    context 'cache_token' do
      before do
        subject.set_token('test_token', Time.now.utc + 1.month)
        described_class.cache_token(subject)
      end

      let(:config_copy) { described_class.new(options) }

      it 'caches and retrieves token through configuration object' do
        retrieved_token, retrieved_expiration = described_class.retrieve_token(config_copy)

        expect(retrieved_token).to eql(subject.token)
        expect(retrieved_expiration).to eql(subject.token_expiration)
      end

      it 'allows to clear caches' do
        described_class.clear_caches

        retrieved_token, retrieved_expiration = described_class.retrieve_token(config_copy)

        expect(retrieved_token).to be_nil
        expect(retrieved_expiration).to be_nil
      end
    end

    context 'logging' do
      it 'accepts a file name for a log' do
        described_class.log = log
        expect(described_class.log).to eq(log)
      end

      it 'accepts a file handle for a log' do
        File.open(log, 'w+') do |fh|
          described_class.log = fh
          expect(described_class.log).to eq(fh)
        end
      end
    end
  end
end
