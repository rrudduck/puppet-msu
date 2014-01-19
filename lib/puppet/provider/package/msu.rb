require 'puppet/provider/package'
require 'win32ole'

Puppet::Type.type(:package).provide :msu, :parent => Puppet::Provider::Package do
    desc "MSU package provider for windows"
    confine :operatingsystem => :windows
    has_feature :installable, :uninstallable
    commands :wsua => 'C:/Windows/Sysnative/wsua.exe'

    def print
        notice("${name} ${path}")
    end

    def install
        # wsua.exe /quiet /norestart <msu file>
        args = '/quiet', '/norestart', @resource[:path]

        wsua(*args)
    end

    def uninstall
        # wsua.exe /quiet /norestart /uninstall <msu file or kb>
        args = '/quiet', '/norestart', '/uninstall'
        
        if @resource[:name].downcase.start_with? 'kb'
            args << '/kb' << @resource[:name]
        else
            args << @resource[:path]
        end

        wsua(*args)
    end

    def query
        self.class.instances.each do |p|
            return p.properties if @resource[:name] == p.name
        end

        nil
    end

    def self.instances    

        packages = []

        begin
            wmi = WIN32OLE.connect('winmgmts://')

            hotfixes = wmi.ExecQuery('select * from win32_quickfixengineering')

            for hotfix in hotfixes do
                packages << new({ :name => hotfix.HotFixID, :ensure => :present, :provider => self.name  })
            end
            
        rescue Puppet::ExecutionFailure
            return nil
        end

        packages
    end

end
