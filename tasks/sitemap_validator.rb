class SitemapValidator

  #See https://www.sitemaps.org/protocol.html

  def self.run_validator( config, report_dir )
    Log.logger.info( 'Validating Sitemaps' )
    url_responses = {}
    sitemap_responses = {}
    headers = build_headers( config )

    sitemaps_to_process = config.sitemap_urls.clone
    process_sitemaps( sitemaps_to_process, headers, url_responses, sitemap_responses, config )
    apply_validations( config, sitemap_responses, url_responses, report_dir )
  end

  def self.build_headers( config )
    headers = {}
    #https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent
    headers['User-Agent'] = config.user_agent_for_requests
    headers
  end

  def self.process_sitemaps( sitemaps_to_process, headers, url_responses, sitemap_responses, config )
    processed_sitemaps = []
    loop do
      sitemap_url = sitemaps_to_process.pop
      processs_sitemap( sitemap_url, headers, sitemaps_to_process, processed_sitemaps, url_responses, sitemap_responses )
      unless sitemaps_to_process.empty?
        sleep config.delay_between_requests_in_seconds
      end
      break if sitemaps_to_process.empty?
    end
    Log.logger.info("Processed sitemaps\n#{hash_to_string(sitemap_responses)}")
    Log.logger.info("Located urls\n#{hash_to_string(url_responses)}")
  end

  def self.hash_to_string( contents )
    contents_as_string = ''
    contents.each do |k, v|
      contents_as_string << "#{k} -> #{v}\n"
    end
    contents_as_string
  end

  def self.processs_sitemap( sitemap_url, headers, sitemaps_to_process, processed_sitemaps, url_responses, sitemap_responses )
    sitemap_content = get_sitemap_content( sitemap_url, headers, sitemap_responses )
    processed_sitemaps << sitemap_url
    unless sitemap_content.nil?

      begin
        Log.logger.debug( "Sitemap sitemap_url=#{sitemap_url} contains\n#{sitemap_content}" )
        as_xml_doc = REXML::Document.new(sitemap_content)
        if validates_against_schema?( sitemap_url, sitemap_responses, sitemap_content )
          as_xml_doc.elements.each('sitemapindex/sitemap/loc') do |location_element|
            sitemaps_to_process << location_element.text
          end
          collect_url_node( as_xml_doc, 'sitemapindex/urlset/url', url_responses )
          collect_url_node( as_xml_doc, 'urlset/url', url_responses )
        end
      rescue => erd
        Log.logger.error( "Error: sitemap_url=#{sitemap_url} contents could not be parsed as xml")
        sitemap_responses[sitemap_url] = 'Xml Parse Failure'
      end

    end
  end

  def self.collect_url_node( as_xml_doc, path_to_collect,url_responses)
    as_xml_doc.elements.each(path_to_collect) do |url_element|
      url_data = { :url => nil, :priority => nil, :changefreq => nil }.extend(Methodize)
      url_element.children.each do |child_element|
        if 'loc'.eql?( child_element.name )
          url_data.url = child_element.text
        elsif 'priority'.eql?( child_element.name )
          url_data.priority = child_element.text
        elsif 'changefreq'.eql?( child_element.name )
          url_data.changefreq = child_element.text
        end
      end
      url_responses[url_data.url] = url_data
    end
  end

  def self.get_sitemap_content( sitemap_url, headers, sitemap_responses )
    begin
      agent = Mechanize.new do |a|
        a.agent.verify_mode = OpenSSL::SSL::VERIFY_NONE   #disabled SSL check
        a.agent.gzip_enabled = false
      end
      page = agent.get( sitemap_url, nil, nil, headers )
      if 200.eql?( page.code.to_i )
        Log.logger.info( "Got contents for sitemap_url=#{sitemap_url}")
        sitemap_responses[sitemap_url] = 200
        page.body
      else
        Log.logger.error( "Error: Could not GET sitemap_url=#{sitemap_url} response code=#{page.code}")
        sitemap_responses[sitemap_url] = page.code.to_i
       nil
      end
    rescue Mechanize::ResponseCodeError => ex
      Log.logger.error( "Error: Could not GET sitemap_url=#{sitemap_url} error=#{ex.message}")
      sitemap_responses[sitemap_url] = 'Failed'
      nil
    end
  end


  def self.validates_against_schema?( sitemap_url, sitemap_responses, xml )
    schema_contents = nil

    #Rather than have this as code we could move this to config
    if xml.include?( '<sitemapindex' ) || xml.include?( 'siteindex.xsd' )
      schema_contents = File.read( "#{File.dirname(__FILE__)}/../schemas/siteindex.xsd" )
    elsif xml.include?( 'xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"' )
      schema_contents = File.read( "#{File.dirname(__FILE__)}/../schemas/sitemap.xsd" )
    end

    if schema_contents.nil?
      Log.logger.error( "Error: Sitemap #{sitemap_url} cannot be validated, please configure the correct schema" )
    else
      xsd = Nokogiri::XML::Schema( schema_contents )
      as_xml_doc = Nokogiri::XML(xml)
      begin
        has_errors = false
        xsd.validate(as_xml_doc).each do |error|
          has_errors = true
          Log.logger.error( "Error: Sitemap #{sitemap_url} contains error=#{error.message}" )
        end
        return !has_errors
      rescue
        Log.logger.error( "Error: Sitemap #{sitemap_url} failed schema validation" )
        sitemap_responses[sitemap_url] = 'Failed schema validation'
        false
      end

    end
  end

  def self.apply_validations( config, sitemap_responses, url_responses, report_dir )
    errors = []
    sitemap_responses.each do |sitemap_url, sitemap_response|
      unless 200.eql?( sitemap_response )
        errors << "Error: Expected sitemap url #{sitemap_url} to return a 200 response but got #{sitemap_response}"
      end
    end

    unless config.optional.nil?
      unless config.optional.validations.nil?
        v = config.optional.validations

        unless v.should_locate_num_sitemaps.nil?
          unless sitemap_responses.size.eql?( v.should_locate_num_sitemaps )
            message = "Error: Expected num sitemaps to be #{v.should_locate_num_sitemaps} but it was #sitemap_responses.size}"
            Log.logger.error( message )
            errors << message
          end
        end

        unless v.should_locate_these_sitemaps.nil?
          v.should_locate_these_sitemaps.each do |sitemap_url|
            unless sitemap_responses.has_key?( sitemap_url )
              message = "Error: Expected sitemap responses to include a sitemap url #{sitemap_url}"
              Log.logger.error( message )
              errors << message
            end
          end
        end

        unless v.should_contain_these_urls.nil?
          v.should_contain_these_urls.each do |url_validation|
            url = url_validation.url
            if url_responses.has_key?( url )
              unless url_validation.changefreq.eql?( url_responses[ url ].changefreq )
                message = "Error: Expected url #{url} to have changefreq #{url_responses[ url ].changefreq}"
                Log.logger.error( message )
                errors << message
              end
              unless url_validation.priority.to_s.eql?( url_responses[ url ].priority )
                message = "Error: Expected url #{url} to have priority #{url_responses[ url ].priority}"
                Log.logger.error( message )
                errors << message
              end

            else
              message = "Error: Expected url #{url_validation.url} to have been collected"
              Log.logger.error( message )
              errors << message
            end

          end
        end

      end
    end

    Report.emit_reports( errors, sitemap_responses, url_responses, report_dir )
  end

end