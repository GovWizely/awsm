load_path = File.expand_path('..', __FILE__)
$:.unshift load_path unless $:.include?(load_path)

require 'active_support'
require 'active_support/core_ext'
require 'active_support/logger'
require 'yaml'

require 'aws-sdk'
require 'yaml'

require 'awsm/action'
require 'awsm/config'
require 'awsm/cli'

module Awsm
  def self.root
    @root ||= Pathname.new File.expand_path('../../', __FILE__)
  end

  def self.manage(action_file_path, environment)
    config = load_config action_file_path, environment

    begin
      authenticate config.root, environment, config.variables_hash[:region]
      config.actions.each(&:execute)
    ensure
      logger.info "*** Variables: ***\n#{config.variables_hash.to_yaml}"
      config
    end
  end

  def self.load_config(action_file_path, environment)
    action_file = Pathname.new action_file_path
    action_file = Pathname(Dir.pwd).join(action_file_path) if action_file.relative?
    logger.info "Config: #{action_file}"

    variables_file = Pathname.new action_file.to_s.sub(/\.json\z/i, '_variables.yml')

    Awsm::Config.new action_file.parent, environment, variables_file.read, action_file.read
  end

  def self.authenticate(project_dir, environment, region)
    Aws.config.update region: region,
                      credentials: load_credentials(project_dir, environment)
    logger.info "Region: #{region}"
  end

  def self.load_credentials(project_dir, environment)
    yaml_str = YAML.load project_dir.join('credentials.yml').read
    credentials_hash = HashWithIndifferentAccess.new(yaml_str)[environment]
    Aws::Credentials.new credentials_hash[:access_key_id],
                         credentials_hash[:secret_access_key]
  end

  def self.logger
    @logger ||= begin
      logger_file = ::File.new(root.join('log/awsm.log'), 'a+')
      logger_file.sync = true
      logger_instance = Logger.new logger_file
      console_logger = ActiveSupport::Logger.new STDOUT
      logger_instance.extend ActiveSupport::Logger.broadcast(console_logger)
      logger_instance.level = ::Logger::INFO
      logger_instance
    end
  end
end
