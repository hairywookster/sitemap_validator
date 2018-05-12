class Log

  def self.init_logger( log_level )
    @logger = Logger.new(STDOUT)
    @logger.datetime_format = "%H:%M:%S"
    @logger.level = LOGGING_LEVELS[log_level.to_sym]
  end

  def self.logger
    @logger
  end

  def self.valid_log_levels
    LOGGING_LEVELS
  end

private

  LOGGING_LEVELS = {
      :debug => Logger::DEBUG,
      :info  => Logger::INFO,
      :warn  => Logger::WARN,
      :error => Logger::ERROR,
      :fatal => Logger::FATAL
  }.freeze

end