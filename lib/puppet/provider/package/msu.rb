require 'puppet/provider/package'
require 'win32ole'
require 'win32/registry'

Puppet::Type.type(:package).provide :msu, :parent => Puppet::Provider::Package do
    desc "msu package provider for windows"

    confine :operatingsystem => :windows

    has_feature :installable, :uninstallable

    commands :wsua => 'C:/Windows/Sysnative/wsua.exe'

    def print
        notice("${name} ${source}")
    end

    def install
        # wsua.exe /quiet /norestart <msu file>
        args = '/quiet', '/norestart', @resource[:source]

        wsua(*args)
    end

    def uninstall
        # wsua.exe /quiet /norestart /uninstall <msu file or kb>
        args = '/quiet', '/norestart', '/uninstall', '/kb'

        if @resource[:name].downcase.start_with? 'kb'
            args << @resource[:name]
        else
            raise Puppet::Error, 'name should start with kb'
        end

        wsua(*args)
    end

    def query
        self.class.instances.each do |p|
            return p.properties if @resource[:name].downcase == p.name.downcase
        end
        nil
    end

    def self.instances    
        query_registry
    end

    # This is probably the safer method, but it is quite a bit slower
    def self.query_wmi
        packages = []

        wmi = WIN32OLE.connect('winmgmts://')

        hotfixes = wmi.ExecQuery('select * from win32_quickfixengineering')

        hotfixes.each do |hotfix|
            packages << new({ :name => hotfix.HotFixID.downcase, :ensure => :present, :provider => self.name  })
        end
    end

    # Faster method, although a bit more work that using wmi (and possibly could miss a package)
    def self.query_registry
        packages = []

        key = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
        access = Win32::Registry::KEY_READ | 0x100

        Win32::Registry::HKEY_LOCAL_MACHINE.open(key, access) do |reg|
            reg.each_key do |k|
                reg.open(k, access) do |subkey|
                    if subkey['InstallClient'] == 'WindowsUpdateAgent'
                        k.split('~')[0].split('_').each do |p|
                            if p.downcase.start_with? 'kb'
                                packages << new({ :name => p, :ensure => :present, :provider => self.name  })
                                break
                            end
                        end
                    end
                end
            end
        end

        packages
    end
end
