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
			@provider.expects(:exec).with 'c:\install\package.msu', '/quiet', '/norestart',
			@provider.install
		end
	end

	describe 'when uninstalling' do
		it 'should uninstall correctly if provided a kb number' do
			@resource[:name] = 'kb1234'
			@resource[:ensure] = :absent
			@provider.expects(:exec).with '/uninstall', '/kb', 'kb1234', '/quiet', '/norestart', 
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

	describe 'on my system' do
		it 'should return KB2506143 is installed' do
			packages = provider.instances
			packages.select! do |x|
				x.name == 'kb2506143'
			end
			packages.should_not be_empty
		end

		it 'should return KB1234 is not installed' do
			packages = provider.instances
			packages.select! do |x|
				x.name == 'KB1234'
			end
			packages.should be_empty
		end
	end	
end