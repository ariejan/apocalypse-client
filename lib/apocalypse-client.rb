require "yaml"
require 'rubygems'
require 'net/http'
require 'json'
require 'apocalypse-client/version'
require 'apocalypse-client/response'
require 'apocalypse-client/install'

class Hash
  #
  # Create a hash from an array of keys and corresponding values.
  def self.zip(keys, values, default=nil, &block)
    hsh = block_given? ? Hash.new(&block) : Hash.new(default)
    keys.zip(values) { |k,v| hsh[k]=v }
    hsh
  end
end

module Apocalypse
  class Client
    def self.host_file;     "#{File.dirname(__FILE__)}/../host.yml"; end
    def self.cron_job_file; "/etc/cron.d/apocalyse"; end    
    def self.rvm?;          !`which rvm`.chomp.empty? end        
    
    def self.cron_job_command
      return rvm? \
        ? " * * * * * root PATH=$PATH:/sbin:/usr/sbin rvm use $RUBY_VERSION ; /usr/local/bin/rvm exec apocalypse-client report > /dev/null" \
        : "* * * * * root PATH=$PATH:/sbin:/usr/sbin /usr/bin/env apocalypse-client report > /dev/null"
    end

    # Report metrics
    def report(options)
      request       = Net::HTTP::Post.new("/api/metrics/#{properties[:hostname]}", initheader = {'Content-Type' =>'application/json'})
      request.body  = metric_string #gather_metrics.to_json
      Net::HTTP.start(properties[:server_address], properties[:port]) do |http|
        request.basic_auth(properties[:username], properties[:password])
        response              = http.request(request)
        
        Apocalyse::Client::Response.parse!(response)
      end
    end
    
    def metric_string
      return <<-EOF
      {"memory":{"total":"524464","free":"29544"},"network":[{"eth0":{"netmask":"255.255.255.0","ipv6scope":"Link","hwaddr":"00:16:3e:02:a9:32","broadcast":"80.255.251.255","mtu":"1500","ipv6addr":"fe80::216:3eff:fe02:a932/64","ipv4address":"80.255.251.182","metric":"1","gateway":"80.255.251.254","txbytes":"1753238576","rxbytes":"4251217317","encapsulation":"Ethernet"}}],"swap":{"total":"1048568","free":"640752"},"cpu":{"cores":"1","loadavg":["1.66","0.14","0.14","2/122","5199"]},"blockdevices":[{"sda1":{"usage":null,"size":null,"tps":"0.35","available":null,"wps":"0.99","mount":null,"used":null,"rps":"1.72"}},{"sda2":{"usage":"30%","size":"29529M","tps":"5.40","available":"19741M","wps":"17.55","mount":"/","used":"8289M","rps":"16.16"}},{"sda3":{"usage":"97%","size":"29529M","tps":"5.40","available":"19741M","wps":"17.55","mount":"/home","used":"8289M","rps":"16.16"}}], "client": {"version": "0.0.2"}}
      EOF
    end    

    # Check if all local deps are available
    def check(options)
      errors = []
      [
        ["/usr/bin/iostat",   "sysstat"]
      ].each do |filename, package|
        errors << "Cannot find `#{filename}`. Please run `apt-get install #{package}` to resolve this." if !File.exists?(filename)
      end

      if errors.empty?
        puts "Everything seems to be in place. You're good to go."
      else
        errors.each { |error| puts errors }
      end
    end

    def update(options)
      installation = Apocalyse::Client::Install.new
      installation.update!
    end

    def now(options)
      install(options)
    end

    def install(options)
      installation = Apocalyse::Client::Install.new
      installation.install!
    end

    # Gather metrics
    def gather_metrics
      {
        'cpu' => {
          'cores' => cpu_cores.strip,
          'loadavg' => cpu_loadavg
        },
        'memory' => memory_metrics,
        'swap' => swap_metrics,
        'blockdevices' => blockdevice_metrics,
        'network' => network_metrics,
        'client'  => client_information
      }
    end

    def client_information
      { 'version' => Apocalypse::Client::VERSION }
    end

    # Returns the number of CPU Cores for this system
    def cpu_cores
      `cat /proc/cpuinfo | grep bogomips | wc -l`.strip
    end

    # Gather load average data
    def cpu_loadavg
      `cat /proc/loadavg`.split
    end

    def blockdevice_metrics
      columns = ["tps", "rps", "wps", "size", "used", "available", "usage", "mount"]

      io_data = `/usr/bin/env iostat -dk | tail -n+4`.split("\n").map { |line| line.split[0...-2] }
      usage_data = `df -l --block-size=M | grep -i ^/dev/[sh]`.split("\n").map { |line| line.split }

      io_data.collect do |device_data|
        device_name = device_data.shift
        device_usage = usage_data.select { |x| x[0].include? device_name }.flatten

        unless device_usage.empty?
          device_data += device_usage[1..-1]
        end

        { device_name => Hash.zip(columns, device_data) }
      end
    end

    def memory_metrics
      {
        'free' => `cat /proc/meminfo | grep MemFree | awk '{print $2}'`.strip,
        'total' => `cat /proc/meminfo | grep MemTotal | awk '{print $2}'`.strip
      }
    end

    def swap_metrics
      {
        'free' => `cat /proc/meminfo | grep SwapFree | awk '{print $2}'`.strip,
        'total' => `cat /proc/meminfo | grep SwapTotal | awk '{print $2}'`.strip
      }
    end

    def network_metrics
      devices = `/usr/bin/env ifconfig | egrep 'Link encap' | grep -v 'lo' | awk '{print $1}'`.split

      devices.collect do |device_name|
        { device_name => {
          'hwaddr' => `/usr/bin/env ifconfig #{device_name} | egrep -o 'HWaddr \([0-9a-fA-F]\{2\}\:*\){6}' | awk '{print $2}'`.strip,
          'mtu' => `/usr/bin/env ifconfig #{device_name} | egrep -o MTU\:[0-9]+ | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'metric' => `/usr/bin/env ifconfig #{device_name} | egrep -o Metric\:[0-9]+ | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'encapsulation' => `/usr/bin/env ifconfig #{device_name} | egrep -o 'Link encap\:[a-zA-Z]+' | cut -d":" -f2`.strip,
          'rxbytes' => `/usr/bin/env ifconfig #{device_name} | grep bytes | awk '/RX/ {print $2}' | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'txbytes' => `/usr/bin/env ifconfig #{device_name} | grep bytes | awk '/TX/ {print $6}' | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'ipv4address' => `/usr/bin/env ifconfig #{device_name} | egrep -o 'inet addr\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tr -s ':' ' ' | awk '{print $3}'`.strip,
          'broadcast' => `/usr/bin/env ifconfig #{device_name} | egrep -o Bcast\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'netmask' => `/usr/bin/env ifconfig #{device_name} | egrep -o Mask\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} | tr -s ':' ' ' | awk '{print $2}'`.strip,
          'gateway' => `netstat -rn | grep ^0.0.0.0 | grep UG | grep #{device_name} | awk '{print $2}' | head -n1`.strip,
          'ipv6addr' => `/usr/bin/env ifconfig #{device_name} | egrep -o 'inet6 addr\:\ \([a-fA-F0-9]\{1,4}\:\{1,2\}[a-fA-F0-9]\{1,4}\:\{1,2\}\)+[A-Fa-f0-9\/^\ ]+' | awk '{print $3}'`.strip,
          'ipv6scope' => `/usr/bin/env ifconfig #{device_name} | egrep -o Scope\:[a-zA-Z]+ | cut -d":" -f2`.strip
        }}
      end
    end
    
    private
      def properties
        throw Exception.new("Host file not found. Please run `apocalyse-client now`") unless File.exists?(self.class.host_file)
        @properties ||= ::YAML.load(File.open(self.class.host_file))
      end
  end
end
