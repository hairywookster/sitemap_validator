class ConfigValidator

  def self.init_config( config_file )
    config = ConfigValidator.validate_config_file( config_file )
    Log.init_logger config.log_level
    config
  end

  def self.validate_config_file( config_file )
    Log.init_logger 'debug'
    Log.logger.info "Validating config held inside #{File.expand_path(config_file)}"

    collected_errors = []
    begin
      file_contents = File.read( config_file )
      json_obj      = JSON.parse( file_contents ).extend(Methodize)
      json_obj.to_json   #round trip check

      validate_log_level( json_obj, collected_errors )
      validate_sitemap_urls( json_obj, collected_errors )
      validate_user_agent_for_requests( json_obj, collected_errors )
      validate_delay_between_requests_in_seconds( json_obj, collected_errors )
      validate_optional_validations( json_obj, collected_errors )

      if collected_errors.empty?
        Log.logger.info "Success: #{config_file} is valid"
      else
        Log.logger.info "Error: config is invalid"
        Log.logger.info collected_errors.join("\n")
      end
      json_obj
    rescue Exception => erd
      Log.logger.error "Error: config is invalid, it was not valid json, if in doubt google jsonlint :)"
      Log.logger.error "#{erd.to_s}\n#{erd.backtrace.join("\n")}"
      nil  #todo raise an error
    end
  end


  def self.validate_log_level( json_obj, collected_errors )
    unless Log.valid_log_levels.include?( json_obj.log_level.to_sym )
      collected_errors << "Logging level in config file as key log_level=#{json_obj.log_level} is invalid, it must be one of #{Log.valid_log_levels.map {|x,y| x}.join(",")}"
    end
  end

  def self.validate_user_agent_for_requests( json_obj, collected_errors )
    if json_obj.user_agent_for_requests.blank?
      collected_errors << "User agent for requests in config file as key user_agent_for_requests=#{json_obj.user_agent_for_requests} is invalid, it must contain a non blank string"
    end
  end

  def self.validate_delay_between_requests_in_seconds( json_obj, collected_errors )
    unless json_obj.delay_between_requests_in_seconds.is_a?( Float ) && json_obj.delay_between_requests_in_seconds >= 0
      collected_errors << "Delay between requests in milliseconds in config file as key delay_between_requests_in_seconds=#{json_obj.delay_between_requests_in_seconds} is invalid, it must be set to a positive float"
    end
  end

  def self.validate_sitemap_urls( json_obj, collected_errors )
    validate_url_references( json_obj.sitemap_urls, collected_errors, 'sitemap_urls' )
  end

  def self.validate_url_references( urls_to_validate, collected_errors, config_field_name )
    unless urls_to_validate.empty?
      urls_to_validate.each do |url_to_validate|
        if url_to_validate.blank?
          collected_errors << "Url in key #{config_field_name} url=#{url_to_validate} is invalid, it must not be blank"
        elsif !( url_to_validate.start_with?( 'http://' ) || url_to_validate.start_with?( 'https://' ) )
          collected_errors << "Url in key #{config_field_name} url=#{url_to_validate} is invalid, it should be a fully qualified domain starting with http:// or https://"
        end
      end
    end
  end

  VALID_CHANGE_REQUENCIES = ['always', 'hourly', 'daily', 'weekly', 'monthly', 'yearly', 'never']
  def self.validate_optional_validations( json_obj, collected_errors )
    unless json_obj.optional.nil?
      unless json_obj.optional.validations.nil?
        v = json_obj.optional.validations
        if !v.should_locate_num_sitemaps.nil? && !v.should_locate_num_sitemaps.is_a?( Integer )
          collected_errors << "should_locate_num_sitemaps is invalid, it should be an integer value"
        end
        validate_url_references( v.should_locate_these_sitemaps, collected_errors, 'should_locate_these_sitemaps' )
        unless v.should_contain_these_urls.nil?
          v.should_contain_these_urls.each do |url_validation|
            #{ "url": "https://play.iwin.com/welcome/browser", "changefreq": "daily", "priority": "1.0" }

            if url_validation.url.blank?
              collected_errors << "Url in validation should_contain_these_urls is invalid, it must not be blank, see entry #{url_validation}"
            elsif !( url_validation.url.start_with?( 'http://' ) || url_validation.url.start_with?( 'https://' ) )
              collected_errors << "Url in validation should_contain_these_urls is invalid, it should be a fully qualified domain starting with http:// or https://, see entry #{url_validation}"
            end

            if url_validation.changefreq.blank?
              collected_errors << "Change frequency in validation should_contain_these_urls is invalid, it must not be blank, see entry #{url_validation}"
            elsif !VALID_CHANGE_REQUENCIES.include?( url_validation.changefreq )
              collected_errors << "Change frequency in validation should_contain_these_urls is invalid, it should be one of #{VALID_CHANGE_REQUENCIES}, see entry #{url_validation}"
            end

            if url_validation.priority.blank?
              collected_errors << "Priority in validation should_contain_these_urls is invalid, it must not be blank, see entry #{url_validation}"
            elsif !url_validation.priority.is_a? Float
              collected_errors << "Priority in validation should_contain_these_urls is invalid, it must be a float, see entry #{url_validation}"
            elsif url_validation.priority < 0 || url_validation.priority > 1
              collected_errors << "Priority in validation should_contain_these_urls is invalid, it must be a float within range 0.0 and 1.0, see entry #{url_validation}"
            end
          end
        end
      end
    end
  end

end