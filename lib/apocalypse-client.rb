require "yaml"
require 'rubygems'
require 'net/http'
require 'json'
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
    def self.host_file; "#{File.dirname(__FILE__)}/../host.yml"; end
    def self.cron_job_command
      "* * * * * root PATH=$PATH:/sbin:/usr/sbin /usr/bin/env apocalypse-reporter report > /dev/null"
    end
    def self.cron_job_file
      "/etc/cron.d/apocalyse"
    end
    def properties
      Yaml.load(self.class.host_file) if File.exists?(filename)
    end
    ## Commands

    # Report metrics
    def report(options)
      

			request       = Net::HTTP::Post.new("/api/metrics/#{options[:hostid]}", initheader = {'Content-Type' =>'application/json'})
		  request.body  = gather_metrics.to_json
      response      = Net::HTTP.new(options[:server], options[:port]).start {|http| http.request(request) }
      puts "Response #{response.code} #{response.message}: #{response.body}"
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
        'network' => network_metrics
      }
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
  end
end
