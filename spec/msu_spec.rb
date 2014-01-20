require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:msu)

describe provider do 

	before(:each) do
	    @resource = Puppet::Type.type(:package).new(
	      :name     => "msu",
	      :ensure   => :present,
	      :provider => :msu
	    )

	    @provider = provider.new(@resource)

	    provider.stubs(:healthcheck)
	end

	it 'should have an install method' do
		@provider.should respond_to(:install)
	end

	it 'should have an uninstall method' do
		@provider.should respond_to(:uninstall)
	end

	context "parameter :source" do
		it 'should default to nil' do
			@resource[:source].should be_nil
		end

		it 'should accept c:\install\package.msu' do
			@resource[:source] = 'c:\install\package.msu'
		end
	end

	describe 'when installing' do
		it 'should use source' do
			@resource[:source] = 'c:\install\package.msu'
			@resource[:ensure] = :present
			@provider.expects(:wsua).with '/quiet', '/norestart', 'c:\install\package.msu'
			@provider.install
		end
	end

	describe 'when uninstalling' do
		it 'should uninstall correctly if provided a kb number' do
			@resource[:name] = 'kb1234'
			@resource[:ensure] = :absent
			@provider.expects(:wsua).with '/quiet', '/norestart', '/uninstall', '/kb', 'kb1234'
			@provider.uninstall
		end

		it 'should throw if not provided a kb number' do
			@resource[:name] = 'k1234'
			@resource[:ensure] = :absent
			expect { @provider.uninstall }.to raise_error
		end
	end

	describe 'when fetching installed list' do
		it 'should return all installed packages' do
			packages = provider.instances
			packages.should_not be_empty
		end
	end
end