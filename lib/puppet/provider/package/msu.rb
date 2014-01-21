require 'puppet/provider/package'
require 'win32ole'
require 'win32/registry'

Puppet::Type.type(:package).provide :msu, :parent => Puppet::Provider::Package do
    desc "msu package provider for windows"

    confine :operatingsystem => :windows

    has_feature :installable, :uninstallable

    commands :wsua => 'C:/Windows/Sysnative/wusa.exe'

    def print
        notice("${name} ${source}")
    end

    def install
        # wsua.exe /quiet /norestart <msu file>
        args =  @resource[:source], '/quiet', '/norestart'

        wsua(*args)
    end

    def uninstall
        # wsua.exe /quiet /norestart /uninstall <msu file or kb>
        args = '/uninstall', '/kb'

        if @resource[:name].downcase.start_with? 'kb'
            args << @resource[:name]
        else
            raise Puppet::Error, 'name should start with kb'
        end

        args.push '/quiet', '/norestart'

        wsua(*args)
    end

    def query
        res = self.class.query_wmi(@resource[:name])
        res.first.properties unless res.nil? or res.empty?
    end

    def self.instances 
        query_wmi
    end

    # WMI method <- preferred way
    def self.query_wmi(id = nil)
        packages = []

        wmi = WIN32OLE.connect('winmgmts://')

        if id
            query = "select * from win32_quickfixengineering where HotFixID = '#{id}'"
        else
            query = 'select * from win32_quickfixengineering'
        end

        hotfixes = wmi.ExecQuery(query)

        hotfixes.each do |hotfix|
            packages << new({ :name => hotfix.HotFixID.downcase, :ensure => :present, :provider => self.name  })
        end

        packages
    end

    # Registry method
    def self.query_registry
        packages = []

        key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
        access = Win32::Registry::KEY_READ | 0x100

        Win32::Registry::HKEY_LOCAL_MACHINE.open(key, access) do |reg|
            reg.each_key do |k|
                reg.open(k, access) do |subkey|
                    k.split('~')[0].split('_').each do |p|
                        if p.downcase.start_with? 'kb'
                            packages << new({ :name => p.downcase, :ensure => :present, :provider => self.name  })
                            break
                        end
                    end
                end
            end
        end

        packages
    end
end
