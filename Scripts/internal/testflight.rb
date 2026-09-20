#!/usr/bin/env ruby
# Local deployment orchestration. Fastlane owns Apple authentication and transport.
require 'json'
require 'yaml'
require 'open3'
require 'optparse'
require 'fileutils'
require 'digest'
require 'securerandom'
require 'time'

module TrinketTestFlight
  class Failure < StandardError; end
  class Pending < Failure; end

  def self.capture(*args)
    output, error, status = Open3.capture3(*args)
    raise Failure, "#{args.first} failed: #{error.strip}" unless status.success?
    output.strip
  end

  def self.project(root)
    spec = YAML.safe_load(File.read(File.join(root, 'project.yml')))
    settings = spec.fetch('settings').fetch('base')
    target = spec.fetch('targets').fetch('Trinket')
    {
      'version' => settings.fetch('MARKETING_VERSION').to_s,
      'base_build' => Integer(settings.fetch('CURRENT_PROJECT_VERSION')),
      'team' => settings.fetch('DEVELOPMENT_TEAM'),
      'cloud_sync' => settings.fetch('CLOUDKIT_SYNC_ENABLED'),
      'bundle_id' => target.fetch('settings').fetch('base').fetch('PRODUCT_BUNDLE_IDENTIFIER'),
      'containers' => target.fetch('entitlements').fetch('properties').fetch('com.apple.developer.icloud-container-identifiers')
    }
  end

  def self.config(path, root)
    path = File.realpath(File.expand_path(path))
    raise Failure, 'Store TestFlight configuration outside the repository.' if path.start_with?(root + '/')
    raise Failure, "Restrict configuration permissions: chmod 600 #{path}" unless (File.stat(path).mode & 0o077).zero?
    data = JSON.parse(File.read(path))
    %w[key_id issuer_id key_filepath].each do |key|
      raise Failure, "Missing #{key} in #{path}. See Docs/Platform/Release.md." if data[key].to_s.empty?
    end
    key = File.realpath(File.expand_path(data.fetch('key_filepath')))
    raise Failure, 'Store the Apple private key outside the repository.' if key.start_with?(root + '/')
    raise Failure, "Restrict private-key permissions: chmod 600 #{key}" unless (File.stat(key).mode & 0o077).zero?
    data.merge('key_filepath' => key)
  rescue Errno::ENOENT
    raise Failure, 'Missing local configuration or API key. See Docs/Platform/Release.md#one-time-testflight-setup.'
  end

  class Portal
    attr_reader :app, :group

    def initialize(config, bundle_id)
      require 'fastlane'
      require 'pilot'
      require 'spaceship'
      @key = { key_id: config.fetch('key_id'), issuer_id: config.fetch('issuer_id'),
               key: File.binread(config.fetch('key_filepath')), duration: 1200, in_house: false }
      Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**@key)
      @app = Spaceship::ConnectAPI::App.find(bundle_id)
      raise Failure, "API key cannot access the existing app #{bundle_id}. Check the key's role and team." unless @app
      groups = @app.get_beta_groups
      @group = groups.find { |candidate| candidate.id == config['internal_group_id'] && candidate.is_internal_group }
      unless @group
        choices = groups.select(&:is_internal_group).map { |candidate| "#{candidate.name}: #{candidate.id}" }
        raise Failure, "Set internal_group_id to an existing internal group in the local config. Available groups:\n#{choices.join("\n")}"
      end
    end

    def builds(version)
      Spaceship::ConnectAPI::Build.all(app_id: app.id, version: version, platform: 'IOS', limit: 200)
    end

    def find_build(version, number)
      found = Spaceship::ConnectAPI::Build.all(app_id: app.id, version: version,
                                             build_number: number.to_s, platform: 'IOS')
      raise Failure, 'Apple returned multiple matching builds; inspect App Store Connect.' if found.length > 1
      found.first
    end

    def upload(ipa, receipt)
      options = FastlaneCore::Configuration.create(Pilot::Options.available_options, {
        api_key: @key, ipa: ipa, apple_id: app.id, app_identifier: receipt.fetch('bundle_id'),
        app_platform: 'ios', app_version: receipt.fetch('version'), build_number: receipt.fetch('build').to_s,
        skip_waiting_for_build_processing: true, skip_submission: true,
        distribute_external: false, submit_beta_review: false
      })
      Pilot::BuildManager.new.upload(options)
    end

    def distribute(build, notes)
      localization = build.get_beta_build_localizations.find { |item| item.locale == 'en-US' }
      if localization
        Spaceship::ConnectAPI.patch_beta_build_localizations(localization_id: localization.id, attributes: { whatsNew: notes })
      else
        Spaceship::ConnectAPI.post_beta_build_localizations(build_id: build.id, attributes: { locale: 'en-US', whatsNew: notes })
      end
      build.add_beta_groups(beta_groups: [group]) unless assigned?(build)
    end

    def assigned?(build)
      group.fetch_builds.any? { |candidate| candidate.id == build.id }
    end
  end

  class Deployment
    attr_reader :receipt, :run_dir

    def initialize(root, settings, config, portal, options)
      @root, @settings, @config, @portal, @options = File.realpath(root), settings, config, portal, options
    end

    def clean_commit
      status = TrinketTestFlight.capture('git', '-C', @root, 'status', '--porcelain', '--untracked-files=all')
      raise Failure, 'TestFlight requires a clean checkout. Resolve in-flight work with its owner; this command never commits or stashes.' unless status.empty?
      TrinketTestFlight.capture('git', '-C', @root, 'rev-parse', 'HEAD')
    end

    def save
      path = File.join(@run_dir, 'receipt.json')
      File.write(path + '.tmp', JSON.pretty_generate(@receipt) + "\n", perm: 0o600)
      File.rename(path + '.tmp', path)
    end

    def start
      if @options[:resume]
        @run_dir = File.realpath(@options[:resume])
        expected_root = File.realpath(File.join(@root, '.DerivedData/testflight')) + '/'
        raise Failure, 'Resume requires a run directory under this checkout’s .DerivedData/testflight/.' unless @run_dir.start_with?(expected_root)
        @receipt = JSON.parse(File.read(File.join(@run_dir, 'receipt.json')))
        raise Failure, 'Unsupported deployment receipt.' unless @receipt['schema'] == 1
        %w[bundle_id team].each do |field|
          raise Failure, "Resume #{field} does not match this project." unless @receipt[field] == @settings[field]
        end
        unless @receipt['app_id'] == @portal.app.id && @receipt['group_id'] == @portal.group.id
          raise Failure, 'Resume app/group differs from local configuration; restore the original configuration.'
        end
      else
        commit = clean_commit
        builds = @portal.builds(@settings.fetch('version')).map(&:version)
        previous = Dir.glob(File.join(@root, '.DerivedData/testflight/*/receipt.json')).map do |path|
          JSON.parse(File.read(path))
        end.select { |item| item['bundle_id'] == @settings['bundle_id'] && item['version'] == @settings['version'] }
        numbers = builds + previous.map { |item| item.fetch('build').to_s } + [@settings.fetch('base_build').to_s]
        unless numbers.all? { |number| number.match?(/\A\d+(?:\.\d+){0,2}\z/) }
          raise Failure, 'Unrecognized Apple build number; inspect App Store Connect before allocating a build.'
        end
        number = numbers.map { |value| value.split('.').first.to_i }.max + 1
        @run_dir = File.join(@root, '.DerivedData/testflight', "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{number}-#{SecureRandom.hex(3)}")
        FileUtils.mkdir_p(@run_dir, mode: 0o700)
        @receipt = @settings.merge('schema' => 1, 'commit' => commit, 'build' => number,
          'app_id' => @portal.app.id, 'group_id' => @portal.group.id,
          'cloud_sync' => @options[:cloud] || @settings.fetch('cloud_sync'),
          'developer_dir' => ENV.fetch('DEVELOPER_DIR'), 'xcode' => TrinketTestFlight.capture('xcodebuild', '-version'),
          'stage' => 'created', 'created_at' => Time.now.utc.iso8601)
        @receipt['notes'] = @options[:notes] ? File.read(@options[:notes]) : "Trinket #{@receipt['version']} (#{number}). Source: #{commit[0, 12]}."
        raise Failure, 'TestFlight notes must contain 1–4000 characters.' unless (1..4000).cover?(@receipt['notes'].length)
        save
      end
      @receipt['command_logs'] ||= []
      @receipt['command_logs'] << ENV['TRINKET_TESTFLIGHT_COMMAND_LOG'] if ENV['TRINKET_TESTFLIGHT_COMMAND_LOG']
      save
      puts "Deployment #{@receipt['version']} (#{@receipt['build']}) — #{@receipt['commit']}"
      puts "Receipt and logs: #{@run_dir}"
    end

    def execute
      start
      if %w[uploading uploaded ready].include?(@receipt['stage'])
        reconcile
        return
      end
      unless clean_commit == @receipt.fetch('commit') &&
             TrinketTestFlight.capture('xcodebuild', '-version') == @receipt.fetch('xcode') &&
             ENV.fetch('DEVELOPER_DIR') == @receipt.fetch('developer_dir')
        raise Failure, 'Source commit or Xcode changed. Start a new deployment; this run cannot rebuild different inputs.'
      end
      unless @receipt['verified']
        command('verification', { 'TRINKET_ISOLATE' => '1', 'SKIP_GENERATE' => nil }, './Scripts/test-deploy.sh')
        raise Failure, 'Source changed during verification; start again from a clean checkout.' unless clean_commit == @receipt['commit']
        @receipt['verified'] = true
        save
      end
      build unless @receipt['stage'] == 'exported'
      validate_ipa_hash
      raise Failure, 'Build number already exists on Apple. Start a new deployment to allocate another number.' if @portal.find_build(@receipt['version'], @receipt['build'])
      raise Failure, 'Source changed before upload.' unless clean_commit == @receipt['commit']
      @receipt['stage'] = 'uploading'
      @receipt['upload_started_at'] = Time.now.utc.iso8601
      save # An interrupted upload must reconcile with Apple before any retry.
      @portal.upload(@receipt.fetch('ipa'), @receipt)
      @receipt['stage'] = 'uploaded'
      save
      reconcile
    end

    def command(label, env, *args)
      log = File.join(@run_dir, "#{label}.log")
      puts "#{label}: #{log}"
      File.open(log, 'a', 0o600) do |file|
        Open3.popen2e(env, *args, chdir: @root) do |input, output, waiter|
          input.close
          output.each_line { |line| file.write(line); $stdout.write(line) }
          raise Failure, "#{label} failed. See #{log} and Docs/Platform/Release.md#testflight-troubleshooting." unless waiter.value.success?
        end
      end
    end

    def build
      artifacts = File.join(@run_dir, "artifacts-#{SecureRandom.hex(3)}")
      FileUtils.mkdir_p(artifacts)
      archive = File.join(artifacts, 'Trinket.xcarchive')
      export_dir = File.join(artifacts, 'export')
      auth = ['-allowProvisioningUpdates', '-authenticationKeyPath', @config.fetch('key_filepath'),
              '-authenticationKeyID', @config.fetch('key_id'), '-authenticationKeyIssuerID', @config.fetch('issuer_id')]
      command('archive', {}, 'xcodebuild', '-project', 'Trinket.xcodeproj', '-scheme', 'Trinket',
        '-configuration', 'Release', '-destination', 'generic/platform=iOS', '-archivePath', archive,
        '-derivedDataPath', File.join(artifacts, 'DerivedData'), '-disableAutomaticPackageResolution',
        '-resultBundlePath', File.join(artifacts, 'archive.xcresult'), *auth,
        "CURRENT_PROJECT_VERSION=#{@receipt.fetch('build')}", "MARKETING_VERSION=#{@receipt.fetch('version')}",
        "DEVELOPMENT_TEAM=#{@receipt.fetch('team')}", 'CODE_SIGN_STYLE=Automatic',
        "CLOUDKIT_SYNC_ENABLED=#{@receipt.fetch('cloud_sync')}", 'archive')
      export_options = File.join(artifacts, 'ExportOptions.plist')
      File.write(export_options, JSON.generate({ method: 'app-store-connect', destination: 'export',
        signingStyle: 'automatic', teamID: @receipt.fetch('team'), manageAppVersionAndBuildNumber: false,
        testFlightInternalTestingOnly: false, iCloudContainerEnvironment: 'Production', uploadSymbols: true }))
      TrinketTestFlight.capture('plutil', '-convert', 'xml1', export_options)
      command('export', {}, 'xcodebuild', '-exportArchive', '-archivePath', archive,
        '-exportPath', export_dir, '-exportOptionsPlist', export_options, *auth)
      ipas = Dir.glob(File.join(export_dir, '*.ipa'))
      raise Failure, 'Export must produce exactly one IPA.' unless ipas.length == 1
      @receipt['ipa'] = ipas.first
      @receipt['archive'] = archive
      inspect_ipa(artifacts)
      @receipt['ipa_sha256'] = Digest::SHA256.file(ipas.first).hexdigest
      @receipt['stage'] = 'exported'
      save
    end

    def plist(path)
      JSON.parse(TrinketTestFlight.capture('plutil', '-convert', 'json', '-o', '-', path))
    end

    def inspect_ipa(artifacts)
      unpacked = File.join(artifacts, 'inspection')
      TrinketTestFlight.capture('ditto', '-x', '-k', @receipt.fetch('ipa'), unpacked)
      apps = Dir.glob(File.join(unpacked, 'Payload/*.app'))
      raise Failure, 'IPA must contain exactly one application.' unless apps.length == 1
      app = apps.first
      TrinketTestFlight.capture('codesign', '--verify', '--deep', '--strict', app)
      info = plist(File.join(app, 'Info.plist'))
      entitlements = TrinketTestFlight.capture('codesign', '-d', '--entitlements', ':-', app)
      signed_path = File.join(artifacts, 'signed-entitlements.plist')
      File.write(signed_path, entitlements)
      validate_export(info, plist(signed_path))
      puts "Verified exported identity, version, signature, Production entitlements, and cloud sync=#{@receipt['cloud_sync']}."
    end

    def validate_export(info, entitlements)
      expected = { 'CFBundleIdentifier' => @receipt.fetch('bundle_id'),
                   'CFBundleShortVersionString' => @receipt.fetch('version'),
                   'CFBundleVersion' => @receipt.fetch('build').to_s,
                   'TrinketCloudEnvironment' => 'Production' }
      expected.each do |key, value|
        raise Failure, "Exported #{key} is #{info[key].inspect}, expected #{value.inspect}." unless info[key] == value
      end
      unless [true, false, 'YES', 'NO'].include?(info['TrinketCloudSyncEnabled'])
        raise Failure, 'Exported CloudKit setting is missing or invalid.'
      end
      enabled = [true, 'YES'].include?(info['TrinketCloudSyncEnabled'])
      raise Failure, 'Exported CloudKit setting differs from the requested build.' unless enabled == (@receipt['cloud_sync'] == 'YES')
      raise Failure, 'Export-compliance declaration changed; review it before deploying.' unless info['ITSAppUsesNonExemptEncryption'] == false
      signed = {
        'application-identifier' => "#{@receipt['team']}.#{@receipt['bundle_id']}",
        'com.apple.developer.team-identifier' => @receipt['team'],
        'com.apple.developer.icloud-container-environment' => 'Production',
        'aps-environment' => 'production', 'get-task-allow' => false,
        'com.apple.developer.icloud-container-identifiers' => @receipt['containers'],
        'com.apple.developer.icloud-services' => ['CloudKit']
      }
      signed.each do |key, value|
        raise Failure, "Unexpected distribution entitlement #{key}: #{entitlements[key].inspect}." unless entitlements[key] == value
      end
    end

    def validate_ipa_hash
      path = @receipt.fetch('ipa')
      unless File.file?(path) && Digest::SHA256.file(path).hexdigest == @receipt.fetch('ipa_sha256')
        raise Failure, 'Retained IPA is missing or changed; do not upload it. Start a new deployment.'
      end
    end

    def reconcile
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @options.fetch(:timeout)
      loop do
        build = @portal.find_build(@receipt['version'], @receipt['build'])
        if build
          if @receipt['apple_build_id'] && @receipt['apple_build_id'] != build.id
            raise Failure, 'Apple build identity changed; inspect App Store Connect.'
          end
          if Time.parse(build.uploaded_date) < Time.parse(@receipt.fetch('upload_started_at')) - 300
            raise Failure, 'Matching Apple build predates this upload; possible build-number collision.'
          end
          @receipt['apple_build_id'] = build.id
          save
          raise Failure, "Apple rejected the build (#{build.processing_state}). Inspect App Store Connect; a new binary needs a new deployment." if %w[FAILED INVALID].include?(build.processing_state)
          raise Failure, 'This TestFlight build has expired; start a new deployment.' if build.expired
          state = build.build_beta_detail && build.build_beta_detail.internal_build_state
          if %w[MISSING_EXPORT_COMPLIANCE IN_EXPORT_COMPLIANCE_REVIEW PROCESSING_EXCEPTION].include?(state)
            raise Failure, "Apple requires action: #{state}. Resolve in App Store Connect, then resume this run."
          end
          if build.processing_state == 'VALID' && %w[READY_FOR_BETA_TESTING IN_BETA_TESTING].include?(state)
            unless @receipt['distribution_requested']
              @portal.distribute(build, @receipt.fetch('notes'))
              @receipt['distribution_requested'] = true
              save
            end
            if @portal.assigned?(build) && state == 'IN_BETA_TESTING'
              @receipt['stage'] = 'ready'
              save
              puts "READY: Trinket #{@receipt['version']} (#{@receipt['build']}); commit #{@receipt['commit']}; group #{@portal.group.name}"
              puts "https://appstoreconnect.apple.com/apps/#{@receipt['app_id']}/testflight/ios/#{build.id}"
              return
            end
          end
          puts "Apple: #{build.processing_state}; internal testing: #{state || 'pending'}"
        else
          puts 'Waiting for the exact uploaded build to appear in App Store Connect…'
        end
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          message = @receipt['stage'] == 'uploading' ? 'Upload outcome remains uncertain; no automatic re-upload.' : 'Uploaded, pending Apple processing/distribution.'
          raise Pending, "#{message} Resume with ./Scripts/testflight.sh --resume #{@run_dir}"
        end
        sleep 30
      end
    end
  end

  def self.main(argv)
    options = { timeout: 1800 }
    modes = []
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: ./Scripts/testflight.sh [--doctor | --dry-run | --resume RUN] [options]'
      opts.on('--doctor', 'Read-only local and Apple access checks; no signing/build/upload') { modes << :doctor }
      opts.on('--dry-run', 'Offline preview; no installs, writes, Apple calls, or build') { modes << :dry_run }
      opts.on('--resume RUN', 'Continue retained deployment; never blindly re-upload') { |value| options[:resume] = File.expand_path(value); modes << :resume }
      opts.on('--config FILE', 'Local JSON (default ~/.config/trinket/testflight.json)') { |value| options[:config] = value }
      opts.on('--notes FILE', 'UTF-8 What to Test notes, at most 4000 characters') { |value| options[:notes] = File.expand_path(value) }
      opts.on('--cloud-sync YES|NO', %w[YES NO], 'Explicit override; YES requires CloudKit readiness gates') { |value| options[:cloud] = value }
      opts.on('--timeout SECONDS', Integer, 'Processing/distribution timeout (default 1800)') { |value| options[:timeout] = value }
      opts.on('-h', '--help') { puts opts; return 0 }
    end
    parser.parse!(argv)
    raise Failure, 'Choose one mode and pass no positional arguments.' unless modes.length <= 1 && argv.empty?
    raise Failure, '--timeout must be positive.' unless options[:timeout].positive?
    raise Failure, '--resume uses the original notes and CloudKit setting.' if options[:resume] && (options[:notes] || options[:cloud])
    root = File.realpath(File.join(__dir__, '../..'))
    settings = project(root)
    if modes.include?(:dry_run)
      puts "Would deploy #{settings['bundle_id']} version #{settings['version']} to internal TestFlight."
      puts "Cloud sync: #{options[:cloud] || settings['cloud_sync']}; build number: next above Apple/local reservations."
      puts 'Require clean checkout → API/signing preflight → isolated full deploy gate → signed Release archive/export → upload → wait → internal group.'
      puts 'No commit, tag, push, marketing-version bump, external distribution, or App Review submission.'
      return 0
    end
    ENV['DEVELOPER_DIR'] = File.realpath(ENV['DEVELOPER_DIR'] || capture('xcode-select', '-p'))
    ENV.delete('SDKROOT')
    puts capture('xcodebuild', '-version')
    puts "iOS SDK: #{capture('xcrun', '--sdk', 'iphoneos', '--show-sdk-version')}"
    configuration = config(options[:config] || File.join(Dir.home, '.config/trinket/testflight.json'), root)
    portal = Portal.new(configuration, settings.fetch('bundle_id'))
    if modes.include?(:doctor)
      puts "Apple access OK: #{portal.app.name}; internal group: #{portal.group.name}."
      puts capture('security', 'find-identity', '-v', '-p', 'codesigning')
      puts 'Signing identities above are informational; a signed export proves distribution permissions. Doctor does not provision certificates or profiles.'
      dirty = capture('git', '-C', root, 'status', '--porcelain', '--untracked-files=all')
      raise Failure, 'Apple access is ready, but deployment requires a clean checkout.' unless dirty.empty?
      return 0
    end
    deployment = Deployment.new(root, settings, configuration, portal, options)
    deployment.execute
    0
  rescue Pending => error
    warn error.message
    2
  rescue StandardError => error
    warn "TestFlight stopped: #{error.message}"
    if deployment && deployment.run_dir
      warn "Retained run: #{deployment.run_dir}. Use --resume to continue; see Docs/Platform/Release.md#testflight-troubleshooting."
    end
    1
  end
end

exit TrinketTestFlight.main(ARGV) if $PROGRAM_NAME == __FILE__
