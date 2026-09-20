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
      original_capture(*args)
    end
  end
end

class FakePortal
  attr_accessor :remote, :fail_upload
  attr_reader :calls, :app, :group

  def initialize
    @app = OpenStruct.new(id: 'app', name: 'Trinket')
    @group = OpenStruct.new(id: 'group', name: 'Internal')
    @calls = []
    @remote = []
    @assigned = false
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
end

class FixtureDeployment < TrinketTestFlight::Deployment
  attr_accessor :dirty, :fail_gate, :changed_commit
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
    resumed.execute
    assert(resumed.commands.empty?)
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
