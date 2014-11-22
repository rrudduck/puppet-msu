require 'puppet/provider/package'
require 'puppet/util/windows'
require 'win32ole' if Puppet.features.microsoft_windows?

# MSU Provider for the Package Resource
# http://support.microsoft.com/kb/934307

Puppet::Type.type(:package).provide :msu, :parent => Puppet::Provider::Package do
    desc "msu package provider for windows"

    confine :operatingsystem => :windows

    has_feature :installable, :uninstallable

    self::ERROR_SUCCESS                  = 0
    self::ERROR_SUCCESS_REBOOT_INITIATED = 1641
    self::ERROR_SUCCESS_REBOOT_REQUIRED  = 3010
    self::WSUA                           = "#{Facter['system32'].value}/wusa.exe"

    def install
        # wsua.exe /quiet /norestart <msu file>
        args =  @resource[:source], '/quiet', '/norestart'

        exec(args)
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

        exec(args)
    end

    def exec(args)
        command = [self.class::WSUA, args].flatten.compact.join(' ')

        output = execute(command, :failonfail => false, :combine => true)

        check_result(output)
    end

    def check_result(output)
        operation = resource[:ensure] == :absent ? 'uninstall' : 'install'

        # Hack for error: undefined method `exitstatus' for "":String
        # Possibly something to do with wusa or puppet exec
        hr = output.respond_to?(:exitstatus) ? output.exitstatus : 0

        case hr
            when self.class::ERROR_SUCCESS
                # do nothing
            when self.class::ERROR_SUCCESS_REBOOT_INITIATED
                warning("The package #{operation}ed successfully and the system is rebooting now.")
            when self.class::ERROR_SUCCESS_REBOOT_REQUIRED
                warning("The package #{operation}ed successfully, but the system must be rebooted.")
            else
                raise Puppet::Util::Windows::Error.new("Failed to #{operation}", hr)
        end
    end

    def query
        res = self.class.query_wmi(@resource[:name])
        
        res.first.properties unless res.nil? or res.empty?
    end

    def self.instances 
        query_wmi
    end

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
end
