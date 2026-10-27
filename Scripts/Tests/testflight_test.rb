require_relative '../internal/testflight'
require 'tmpdir'
require 'ostruct'
require 'stringio'

module TrinketTestFlight
  class << self
    alias original_capture capture
    def capture(*args)
      return 'Xcode fixture' if args == ['xcodebuild', '-version']
      return '' if args[0, 3] == ['plutil', '-convert', 'xml1']
      return original_capture({ 'DEVELOPER_DIR' => nil }, *args) if args.first == 'git'
      original_capture(*args)
    end
  end
end

class FakePortal
  attr_accessor :remote, :fail_upload, :symbols
  attr_reader :calls, :app, :group

  def initialize
    @app = OpenStruct.new(id: 'app', name: 'Trinket')
    @group = OpenStruct.new(id: 'group', name: 'Internal')
    @calls = []
    @remote = []
    @assigned = false
    @symbols = true
  end

  def builds(_version)
    remote
  end

  def find_build(_version, number)
    remote.find { |build| build.version.to_s == number.to_s }
  end

  def upload(_ipa, receipt)
    @calls << :upload
    raise 'Connection lost' if fail_upload
    remote << self.class.build(receipt['build'])
  end

  def self.build(number, processing = 'VALID', state = 'IN_BETA_TESTING')
    OpenStruct.new(id: "apple-#{number}", version: number.to_s, processing_state: processing,
      expired: false, uploaded_date: Time.now.utc.iso8601,
      build_beta_detail: OpenStruct.new(internal_build_state: state))
  end

  def distribute(_build, _notes)
    @calls << :distribute
    @assigned = true
  end

  def assigned?(_build)
    @assigned
  end

  def symbol_status(_build, _bundle_id)
    symbols
  end
end

class FixtureDeployment < TrinketTestFlight::Deployment
  attr_accessor :dirty, :fail_gate, :fail_ci, :changed_commit
  attr_reader :commands

  def initialize(*args)
    super
    @commands = []
  end

  def clean_commit
    raise TrinketTestFlight::Failure, 'dirty' if dirty
    changed_commit || 'commit-sha'
  end

  def command(label, env, *args)
    @commands << [label, env, args]
    raise TrinketTestFlight::Failure, 'gate failed' if fail_gate
    raise TrinketTestFlight::Failure, 'CI failed' if fail_ci && label == 'verification-ci'
  end

  def build
    @commands << ['build']
    path = File.join(run_dir, 'Trinket.ipa')
    File.write(path, 'fixture IPA')
    receipt['ipa'] = path
    receipt['ipa_sha256'] = Digest::SHA256.file(path).hexdigest
    receipt['stage'] = 'exported'
    save
  end

  def ensure_symbol_artifacts
    # Archive/IPA fixtures have no native binaries; real validation has Python coverage.
  end
end

def assert(value, message = 'assertion failed')
  raise message unless value
end

def rejects(fragment)
  begin
    yield
  rescue StandardError => error
    assert(error.message.include?(fragment), "Expected #{fragment.inspect}, got #{error.message.inspect}")
    return
  end
  raise "Expected failure: #{fragment}"
end

def fixture
  Dir.mktmpdir do |root|
    ENV['DEVELOPER_DIR'] = '/fixture/Xcode'
    settings = { 'version' => '0.1.0', 'base_build' => 6, 'team' => 'TEAM',
                 'bundle_id' => 'com.example.Trinket', 'cloud_sync' => 'NO', 'containers' => ['iCloud.example'] }
    portal = FakePortal.new
    options = { timeout: 0 }
    factory = ->(extra = {}) { FixtureDeployment.new(root, settings, {}, portal, options.merge(extra)) }
    yield factory.call, portal, factory, settings, root
  end
end

original_stdout = $stdout
$stdout = StringIO.new
begin
  fixture do |deploy, _portal|
    deploy.start
    deploy.build
    retained = File.join(deploy.run_dir, 'retained')
    FileUtils.mkdir_p(retained)
    FileUtils.mv(deploy.receipt.fetch('ipa'), File.join(retained, 'Trinket.ipa'))
    deploy.receipt['symbol_artifacts'] = { 'path' => retained }
    original_archive = File.join(deploy.run_dir, 'Trinket.xcarchive')
    deploy.receipt['archive'] = original_archive
    FileUtils.mkdir_p(File.join(retained, 'Trinket.xcarchive'))
    deploy.validate_ipa_hash
    assert(deploy.artifact_path('ipa', 'Trinket.ipa') == File.join(retained, 'Trinket.ipa'))
    assert(deploy.artifact_path('archive', 'Trinket.xcarchive') == File.join(retained, 'Trinket.xcarchive'))
    File.write(File.join(retained, 'Trinket.ipa'), 'changed')
    rejects('missing or changed') { deploy.validate_ipa_hash }
  end

  fixture do |deploy, _portal|
    deploy.start
    deploy.build
    artifacts = File.join(deploy.run_dir, 'artifacts-fixture')
    FileUtils.mkdir_p(artifacts)
    original = TrinketTestFlight.method(:capture)
    begin
      TrinketTestFlight.define_singleton_method(:capture) do |*args|
        if args.first == 'ditto'
          FileUtils.mkdir_p(File.join(args.last, 'Payload/Trinket.app'))
          ''
        elsif args.first == 'codesign'
          'fixture entitlements'
        else
          original.call(*args)
        end
      end
      deploy.define_singleton_method(:plist) { |_path| {} }
      deploy.define_singleton_method(:validate_export) { |_info, _entitlements| nil }
      deploy.inspect_ipa(artifacts)
      assert(Dir.glob(File.join(artifacts, 'inspection-*')).empty?, 'successful inspection must release its unpacked IPA')
      assert(JSON.parse(File.read(File.join(artifacts, 'inspection.json')))['signature_verified'])
      deploy.define_singleton_method(:validate_export) { |_info, _entitlements| raise 'invalid identity' }
      rejects('invalid identity') { deploy.inspect_ipa(artifacts) }
      assert(Dir.glob(File.join(artifacts, 'inspection-*')).length == 1, 'failed inspection evidence must survive')
    ensure
      TrinketTestFlight.define_singleton_method(:capture, original)
    end
  end

  fixture do |deploy, portal, factory|
    deploy.fail_ci = true
    rejects('CI failed') { deploy.execute }
    assert(deploy.receipt['verification_mode'] == 'beta')
    assert(deploy.receipt['stage'] == 'exported')
    assert(deploy.receipt['focused_verified'])
    assert(!deploy.receipt['verified'])
    assert(portal.calls.empty?, 'an archive cannot authorize upload before CI passes')
    candidate = factory.call
    candidate.changed_commit = 'fixed-test-sha'
    candidate.start
    assert(candidate.receipt['feedback_base_commit'] == 'commit-sha')
    assert(candidate.receipt['verification_base_commit'].nil?, 'an unfinished candidate is not a shipping baseline')
    resumed = factory.call(resume: deploy.run_dir)
    resumed.execute
    assert(resumed.commands.map(&:first) == ['verification-ci'], 'resume must retain focused checks and signed artifacts')
    assert(portal.calls == [:upload, :distribute])
    full = factory.call(full_ui: true)
    full.execute
    assert(full.receipt['verification_mode'] == 'ui')
    assert(full.commands.map(&:first) == ['verification', 'build'])
    assert(full.commands.first.last == ['./Scripts/test-deploy.sh', '--mode', 'ui'])
  end

  Dir.mktmpdir do |root|
    TrinketTestFlight.capture('git', '-C', root, 'init', '--quiet')
    File.write(File.join(root, 'source.txt'), 'committed source')
    TrinketTestFlight.capture('git', '-C', root, 'add', 'source.txt')
    TrinketTestFlight.capture('git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                             '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Fixture')
    deploy = TrinketTestFlight::Deployment.new(root, {}, {}, nil, {})
    assert(deploy.clean_commit.match?(/\A[0-9a-f]{40,64}\z/))
    File.write(File.join(root, 'source.txt'), 'working changes')
    rejects('clean checkout') { deploy.clean_commit }
  end

  fixture do |deploy, portal, _factory, _settings, _root|
    deploy.dirty = true
    rejects('dirty') { deploy.execute }
    assert(portal.calls.empty?)
    assert(deploy.run_dir.nil?)
  end

  fixture do |deploy, portal|
    deploy.fail_gate = true
    rejects('gate failed') { deploy.execute }
    assert(portal.calls.empty?)
    assert(!deploy.receipt['verified'])
  end

  fixture do |deploy, portal, factory|
    portal.remote = [FakePortal.build('9.2'), FakePortal.build(7)]
    deploy.execute
    assert(deploy.receipt['build'] == 10)
    assert(deploy.receipt['cloud_sync'] == 'NO')
    assert(deploy.receipt['stage'] == 'ready')
    assert(deploy.commands.first[1]['TRINKET_ISOLATE'] == '1')
    assert(portal.calls == [:upload, :distribute])
    resume_path = deploy.run_dir
    alternate_case_path = deploy.run_dir.sub('/.DerivedData/testflight/', '/.DerivedData/TestFlight/')
    resume_path = alternate_case_path if File.exist?(alternate_case_path)
    resumed = factory.call(resume: resume_path)
    resumed.dirty = true # Completed artifacts are independent of current source.
    resumed.define_singleton_method(:ensure_symbol_artifacts) { raise 'Legacy archive must not be rebuilt' }
    resumed.execute
    assert(resumed.commands.empty?)
    assert(resumed.receipt['legacy_symbol_retention'].include?('unavailable'))
    assert(portal.calls == [:upload, :distribute])
    portal.remote.clear # Local reservations still prevent reusing 10.
    next_run = factory.call
    next_run.start
    assert(next_run.receipt['build'] == 11)
  end

  fixture do |deploy, portal, factory|
    portal.fail_upload = true
    rejects('Connection lost') { deploy.execute }
    assert(deploy.receipt['stage'] == 'uploading')
    rejects('uncertain') { factory.call(resume: deploy.run_dir).execute }
    assert(portal.calls == [:upload])
    portal.remote << FakePortal.build(deploy.receipt['build'])
    factory.call(resume: deploy.run_dir).execute
    assert(portal.calls == [:upload, :distribute])
  end

  fixture do |deploy, portal, factory|
    portal.symbols = false
    rejects('missing symbols') { deploy.execute }
    assert(portal.calls == [:upload], 'Apple symbol failure must prevent distribution')
    assert(deploy.receipt['apple_symbols']['includes_symbols'] == false)
    portal.symbols = nil
    rejects('not confirmed symbols') { factory.call(resume: deploy.run_dir).execute }
    assert(portal.calls == [:upload], 'unknown symbol state must not trigger another upload')
    portal.symbols = true
    resumed = factory.call(resume: deploy.run_dir)
    resumed.execute
    assert(portal.calls == [:upload, :distribute])
    assert(resumed.receipt['apple_symbols']['includes_symbols'] == true)
  end

  fixture do |_deploy, portal, _factory, settings, root|
    TrinketTestFlight.capture('git', '-C', root, 'init', '--quiet')
    TrinketTestFlight.capture('git', '-C', root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                             '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '-qm', 'Fixture')
    linked = File.join(root, 'linked checkout')
    TrinketTestFlight.capture('git', '-C', root, 'worktree', 'add', '-qb', 'linked', linked)
    legacy = FixtureDeployment.new(linked, settings, {}, portal, { timeout: 0 })
    legacy.start
    assert(legacy.receipt['build'] == 7)
    begin
      ENV['TRINKET_TESTFLIGHT_STATE_ROOT'] = File.join(root, '.DerivedData/testflight')
      failed = FixtureDeployment.new(root, settings, {}, portal, { timeout: 0 })
      failed.fail_gate = true
      rejects('gate failed') { failed.execute }
      assert(failed.receipt['build'] == 8, 'legacy linked-worktree reservation must remain consumed')
      next_run = FixtureDeployment.new(linked, settings, {}, portal, { timeout: 0 })
      next_run.start
      assert(next_run.receipt['build'] == 9, 'failed shared reservation must remain consumed across worktrees')
      assert(File.dirname(next_run.run_dir) == ENV['TRINKET_TESTFLIGHT_STATE_ROOT'])
      resumed = FixtureDeployment.new(linked, settings, {}, portal, { timeout: 0, resume: legacy.run_dir })
      resumed.start
      assert(resumed.receipt['build'] == 7, 'legacy receipts must remain resumable')
      assert(portal.calls.empty?)
    ensure
      ENV.delete('TRINKET_TESTFLIGHT_STATE_ROOT')
    end
  end

  fixture do |deploy, portal, factory|
    deploy.start
    deploy.receipt['verified'] = true
    deploy.build
    File.write(deploy.receipt['ipa'], 'corrupted')
    rejects('IPA is missing or changed') { factory.call(resume: deploy.run_dir).execute }
    assert(portal.calls.empty?)
  end

  fixture do |deploy, portal, factory|
    deploy.start
    deploy.receipt['verified'] = true
    deploy.build
    portal.remote << FakePortal.build(deploy.receipt['build'])
    rejects('already exists') { factory.call(resume: deploy.run_dir).execute }
    assert(portal.calls.empty?)
    changed = factory.call(resume: deploy.run_dir)
    changed.changed_commit = 'different-commit'
    rejects('Source commit or Xcode changed') { changed.execute }
    portal.group.id = 'other-group'
    rejects('app/group differs') { factory.call(resume: deploy.run_dir).execute }
  end

  fixture do |deploy, portal, factory|
    portal.fail_upload = true
    rejects('Connection lost') { deploy.execute }
    build = FakePortal.build(deploy.receipt['build'], 'PROCESSING', 'PROCESSING')
    portal.remote << build
    rejects('uncertain') { factory.call(resume: deploy.run_dir).execute }
    build.processing_state = 'INVALID'
    rejects('Apple rejected') { factory.call(resume: deploy.run_dir).execute }
    build.processing_state = 'VALID'
    build.build_beta_detail.internal_build_state = 'MISSING_EXPORT_COMPLIANCE'
    rejects('Apple requires action') { factory.call(resume: deploy.run_dir).execute }
    build.uploaded_date = (Time.now.utc - 3600).iso8601
    rejects('predates this upload') { factory.call(resume: deploy.run_dir).execute }
    assert(portal.calls == [:upload])
  end

  fixture do |deploy, _portal, factory, settings|
    deploy.start
    info = { 'CFBundleIdentifier' => settings['bundle_id'], 'CFBundleShortVersionString' => '0.1.0',
             'CFBundleVersion' => '7', 'TrinketCloudEnvironment' => 'Production',
             'TrinketCloudSyncEnabled' => 'NO', 'ITSAppUsesNonExemptEncryption' => false }
    entitlements = { 'application-identifier' => "TEAM.#{settings['bundle_id']}",
      'com.apple.developer.team-identifier' => 'TEAM', 'get-task-allow' => false,
      'com.apple.developer.icloud-container-environment' => 'Production', 'aps-environment' => 'production',
      'com.apple.developer.icloud-services' => ['CloudKit'],
      'com.apple.developer.icloud-container-identifiers' => ['iCloud.example'] }
    deploy.validate_export(info, entitlements)
    rejects('CFBundleVersion') { deploy.validate_export(info.merge('CFBundleVersion' => '8'), entitlements) }
    rejects('CFBundleIdentifier') { deploy.validate_export(info.merge('CFBundleIdentifier' => 'wrong'), entitlements) }
    rejects('distribution entitlement') { deploy.validate_export(info, entitlements.merge('get-task-allow' => true)) }
    rejects('CloudKit setting') { deploy.validate_export(info.merge('TrinketCloudSyncEnabled' => 'YES'), entitlements) }
    rejects('missing or invalid') { deploy.validate_export(info.reject { |key, _| key == 'TrinketCloudSyncEnabled' }, entitlements) }
    cloud = factory.call(cloud: 'YES')
    cloud.start
    assert(cloud.receipt['cloud_sync'] == 'YES')
  end

  fixture do |deploy, _portal|
    deploy.start
    deploy.instance_variable_set(:@config, { 'key_filepath' => '/private/key.p8', 'key_id' => 'id', 'issuer_id' => 'issuer' })
    deploy.define_singleton_method(:command) do |label, env, *args|
      @commands << [label, env, args]
      if label == 'export'
        export_dir = args[args.index('-exportPath') + 1]
        FileUtils.mkdir_p(export_dir)
        File.write(File.join(export_dir, 'Trinket.ipa'), 'fixture IPA')
      end
    end
    deploy.define_singleton_method(:inspect_ipa) { |_artifacts| nil }
    TrinketTestFlight::Deployment.instance_method(:build).bind(deploy).call
    archive = deploy.commands.find { |item| item.first == 'archive' }.last
    assert(archive.include?('CURRENT_PROJECT_VERSION=7'))
    cache = archive[archive.index('-derivedDataPath') + 1]
    assert(archive.include?('-IDEBuildLocationStyle=Unique'), 'archive must ignore global custom build locations per process')
    assert(archive.none? { |arg| arg.match?(/\A(?:SYMROOT|OBJROOT|SHARED_PRECOMPS_DIR)=/) },
      'Xcode must own its complete archive arena, including products and dSYMs')
    TrinketTestFlight::Deployment.instance_method(:build).bind(deploy).call
    next_archive = deploy.commands.reverse.find { |item| item.first == 'archive' }.last
    assert(next_archive[next_archive.index('-derivedDataPath') + 1] == cache, 'candidate artifacts must share the compiler cache')
    assert(next_archive[next_archive.index('-archivePath') + 1] != archive[archive.index('-archivePath') + 1],
      'signed candidate archives must remain separate')
    assert(archive.include?('CLOUDKIT_SYNC_ENABLED=NO'))
    assert(archive.include?('-authenticationKeyPath'))
    export = deploy.commands.find { |item| item.first == 'export' }.last
    options = JSON.parse(File.read(export[export.index('-exportOptionsPlist') + 1]))
    assert(options['method'] == 'app-store-connect')
    assert(options['destination'] == 'export')
    assert(options['manageAppVersionAndBuildNumber'] == false)
    assert(options['testFlightInternalTestingOnly'] == false)
    assert(options['iCloudContainerEnvironment'] == 'Production')
    deploy.validate_ipa_hash
  end

  Dir.mktmpdir do |directory|
    directory = File.realpath(directory)
    root = File.join(directory, 'repo')
    FileUtils.mkdir_p(root)
    key = File.join(directory, 'key.p8')
    File.write(key, 'fixture-key', perm: 0o600)
    config = File.join(directory, 'config.json')
    File.write(config, JSON.generate(key_id: 'id', issuer_id: 'issuer', key_filepath: key), perm: 0o600)
    assert(TrinketTestFlight.config(config, root)['key_filepath'] == key)
    File.chmod(0o644, config)
    rejects('Restrict configuration') { TrinketTestFlight.config(config, root) }
    File.chmod(0o600, config)
    File.chmod(0o644, key)
    rejects('Restrict private-key') { TrinketTestFlight.config(config, root) }
    FileUtils.cp(config, File.join(root, 'config.json'))
    rejects('outside the repository') { TrinketTestFlight.config(File.join(root, 'config.json'), root) }
  end
ensure
  $stdout = original_stdout
end
puts 'TestFlight regression scenarios passed'

if ARGV.include?('--fastlane')
  require 'fastlane'
  require 'pilot'
  require 'spaceship'
  require 'openssl'

  # Real token signing and Pilot option validation, with the network boundary replaced.
  group = OpenStruct.new(id: 'group', name: 'Internal', is_internal_group: true)
  app = OpenStruct.new(id: 'app', name: 'Trinket', get_beta_groups: [group])
  Spaceship::ConnectAPI::App.define_singleton_method(:find) { |_bundle| app }
  Pilot::BuildManager.class_eval do
    def upload(options)
      raise 'Review submission enabled' unless options[:submit_beta_review] == false
      raise 'External distribution enabled' unless options[:distribute_external] == false
      raise 'Distribution not separated from transport' unless options[:skip_submission] == true
      raise 'Wrong binary' unless File.read(options[:ipa]) == 'fixture IPA'
      raise 'Missing private-key material' unless options[:api_key][:key].include?('PRIVATE KEY')
    end
  end
  Dir.mktmpdir do |directory|
    key_path = File.join(directory, 'key.p8')
    File.write(key_path, OpenSSL::PKey::EC.generate('prime256v1').private_to_pem)
    config = { 'key_id' => 'fixture-id', 'issuer_id' => 'fixture-issuer',
               'key_filepath' => key_path, 'internal_group_id' => 'group' }
    portal = TrinketTestFlight::Portal.new(config, 'com.example.Trinket')
    assert(Spaceship::ConnectAPI.token.text.split('.').length == 3)
    bundle = Spaceship::ConnectAPI::BuildBundle.new('bundle', { 'bundleId' => 'com.example.Trinket', 'includesSymbols' => true })
    assert(portal.symbol_status(OpenStruct.new(build_bundles: [bundle]), 'com.example.Trinket') == true)
    assert(portal.symbol_status(OpenStruct.new(build_bundles: [bundle]), 'other.app').nil?)
    ipa = File.join(directory, 'Trinket.ipa')
    File.write(ipa, 'fixture IPA')
    portal.upload(ipa, { 'bundle_id' => 'com.example.Trinket', 'version' => '0.1.0', 'build' => 7 })
    group.is_internal_group = false
    rejects('existing internal group') { TrinketTestFlight::Portal.new(config, 'com.example.Trinket') }
    Spaceship::ConnectAPI::App.define_singleton_method(:find) { |_bundle| nil }
    rejects('cannot access the existing app') { TrinketTestFlight::Portal.new(config, 'com.example.Trinket') }
  end
  puts 'Pinned Fastlane adapter scenarios passed'
end
