require 'puppet'
require 'yaml'

begin
    require 'rubygems'
rescue LoadError => e
    Puppet.err "You need `rubygems` to send reports to Sentry"
end

begin
    require 'raven'
rescue LoadError => e
    Puppet.err "You need the `sentry-raven` gem installed on the puppetmaster to send reports to Sentry"
end

Puppet::Reports.register_report(:sentry) do
    desc = 'Puppet reporter designed to send failed runs to a sentry server'

    config_file = File.join([File.dirname(Puppet.settings[:config]), "sentry.yaml"])
    unless File.exist?(config_file)
      raise(Puppet::ParseError, "Sentry report config file #{config_file} missing or not readable")
    end

    DSN = YAML.load_file(config_file)['sentry']['dsn'] rescue nil

    # Check the config contains what we need
    unless DSN
      raise(Puppet::ParseError, "Sentry did not contain a dsn")
    end

    # Process an event
    def process

        # We only care if the run failed
        if self.status != 'failed'
            return
        end

        if self.respond_to?(:host)
            @host = self.host
        end

        if self.respond_to?(:kind)
            @kind = self.kind
        end
        if self.respond_to?(:puppet_version)
          @puppet_version = self.puppet_version
        end

        if self.respond_to?(:status)
          @status = self.status
        end

        # Configure raven
        Raven.configure do |config|
            config.dsn = DSN
        end

        # Get the important looking stuff to sentry
        self.logs.each do |log|
            if log.level.to_s == 'err'
                Raven.captureMessage(log.message, {
                  :server_name => @host,
                  :tags => {
                    'status'      => @status,
                    'version'     => @puppet_version,
                    'kind'        => @kind,
                  },
                  :extra => {
                    'source' => log.source,
                    'line'   => log.line,
                    'file'   => log.file,
                  },
                })
            end
        end
    end
end
