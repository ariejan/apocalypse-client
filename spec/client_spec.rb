require 'spec_helper'


describe Apocalypse::Client do
  before(:each) do
    @reporter = Apocalypse::Client.new
  end

  describe "cpu cores" do
    it "should return the correct number of cores" do
      @reporter.should_receive(:`).with("cat /proc/cpuinfo | grep bogomips | wc -l").and_return("4")
      @reporter.cpu_cores.should eql("4")
    end
  end

  describe "cpu loadavg" do
    it "should return the correct loadavg values" do
      @reporter.should_receive(:`).with("cat /proc/loadavg").and_return("0.89 0.92 1.12 1/124 28786")
      @reporter.cpu_loadavg.should eql(["0.89", "0.92", "1.12", "1/124", "28786"])
    end
  end

  describe "memory" do
    it "should gather free and used memory" do
      @reporter.should_receive(:`).with("cat /proc/meminfo | grep MemFree | awk '{print $2}'").and_return("998452")
      @reporter.should_receive(:`).with("cat /proc/meminfo | grep MemTotal | awk '{print $2}'").and_return("7864548")

      memory_metrics = @reporter.memory_metrics
      memory_metrics["free"].should eql("998452")
      memory_metrics["total"].should eql("7864548")
    end
  end

  describe "swap" do
    it "should gather free and used swap" do
      @reporter.should_receive(:`).with("cat /proc/meminfo | grep SwapFree | awk '{print $2}'").and_return("934452")
      @reporter.should_receive(:`).with("cat /proc/meminfo | grep SwapTotal | awk '{print $2}'").and_return("15728632")

      swap_metrics = @reporter.swap_metrics
      swap_metrics["free"].should eql("934452")
      swap_metrics["total"].should eql("15728632")
    end
  end

  describe "networking" do
    it "should get network metrics" do
      {
        "/usr/bin/env ifconfig | egrep 'Link encap' | grep -v 'lo' | awk '{print $1}'" => "eth0",
        "/usr/bin/env ifconfig eth0 | egrep -o 'HWaddr \([0-9a-fA-F]\{2\}\:*\){6}' | awk '{print $2}'" => "bc:de:12:ba:38:b3",
        "/usr/bin/env ifconfig eth0 | egrep -o MTU\:[0-9]+ | tr -s ':' ' ' | awk '{print $2}'" => "1500",
        "/usr/bin/env ifconfig eth0 | egrep -o Metric\:[0-9]+ | tr -s ':' ' ' | awk '{print $2}'" => "1",
        "/usr/bin/env ifconfig eth0 | egrep -o 'Link encap\:[a-zA-Z]+' | cut -d\":\" -f2" => "Ethernet",
        "/usr/bin/env ifconfig eth0 | grep bytes | awk '/RX/ {print $2}' | tr -s ':' ' ' | awk '{print $2}'" => "384735745",
        "/usr/bin/env ifconfig eth0 | grep bytes | awk '/TX/ {print $6}' | tr -s ':' ' ' | awk '{print $2}'" => "3575372573",
        "/usr/bin/env ifconfig eth0 | egrep -o 'inet addr\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | tr -s ':' ' ' | awk '{print $3}'" => "10.187.234.18",
        "/usr/bin/env ifconfig eth0 | egrep -o Bcast\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} | tr -s ':' ' ' | awk '{print $2}'" => "10.187.234.254",
        "/usr/bin/env ifconfig eth0 | egrep -o Mask\:[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} | tr -s ':' ' ' | awk '{print $2}'" => "255.0.0.0",
        "netstat -rn | grep ^0.0.0.0 | grep UG | grep eth0 | awk '{print $2}' | head -n1" => "10.187.234.1",
        "/usr/bin/env ifconfig eth0 | egrep -o 'inet6 addr\:\ \([a-fA-F0-9]\{1,4}\:\{1,2\}[a-fA-F0-9]\{1,4}\:\{1,2\}\)+[A-Fa-f0-9\/^\ ]+' | awk '{print $3}'" => "fe80::1031:3cff:fe00:bde1/64",
        "/usr/bin/env ifconfig eth0 | egrep -o Scope\:[a-zA-Z]+ | cut -d\":\" -f2" => "Link"
      }.each do |command, result|
        @reporter.should_receive(:`).with(command).and_return(result)
      end

      network_metrics = @reporter.network_metrics.first["eth0"]

      network_metrics["hwaddr"].should eql("bc:de:12:ba:38:b3")
      network_metrics["mtu"].should eql("1500")
      network_metrics["metric"].should eql("1")
      network_metrics["encapsulation"].should eql("Ethernet")
      network_metrics["rxbytes"].should eql("384735745")
      network_metrics["txbytes"].should eql("3575372573")
      network_metrics["ipv4address"].should eql("10.187.234.18")
      network_metrics["broadcast"].should eql("10.187.234.254")
      network_metrics["netmask"].should eql("255.0.0.0")
      network_metrics["gateway"].should eql("10.187.234.1")
      network_metrics["ipv6addr"].should eql("fe80::1031:3cff:fe00:bde1/64")
      network_metrics["ipv6scope"].should eql("Link")
    end
  end

  describe "block devices" do
    it "should gather the correct block device info" do
      iostat = <<-EOF
sda1              0.21         1.95         2.35     157872     189884
sda2              5.74        18.53        22.08    1496597    1783516

EOF

      df = <<-EOF
/dev/sda2               29529M     7506M    20524M  27% /
EOF

      @reporter.should_receive(:`).with("/usr/bin/env iostat -dk | tail -n+4").and_return(iostat)
      @reporter.should_receive(:`).with("df -l --block-size=M | grep -i ^/dev/[sh]").and_return(df)

      result = @reporter.blockdevice_metrics

      result.size.should eql(2)

      # sda1
      sda1 = result.select{ |a| a.keys.include?("sda1") }.first["sda1"]

      sda1["tps"].should eql("0.21")
      sda1["rps"].should eql("1.95")
      sda1["wps"].should eql("2.35")
      sda1["size"].should be_nil
      sda1["usage"].should be_nil
      sda1["used"].should be_nil
      sda1["available"].should be_nil
      sda1["mount"].should be_nil

      # sda2
      sda2 = result.select{ |a| a.keys.include?("sda2") }.first["sda2"]

      sda2["tps"].should eql("5.74")
      sda2["rps"].should eql("18.53")
      sda2["wps"].should eql("22.08")
      sda2["size"].should eql("29529M")
      sda2["usage"].should eql("27%")
      sda2["used"].should eql("7506M")
      sda2["available"].should eql("20524M")
      sda2["mount"].should eql("/")
    end
  end
  
  describe "Client information" do
    it "should return the current version of this client." do
      @reporter.client_information.should eql({ 'version' => Apocalypse::Client::VERSION })
    end
  end  
end
