class SitemapValidator

  #See https://www.sitemaps.org/protocol.html

  def self.run_validator( config, report_dir )
    Log.logger.info( "Validating Sitemaps")
    collected_urls = []
    sitemap_responses = {}
    headers = build_headers( config )

    sitemaps_to_process = config.sitemap_urls.clone
    process_sitemaps( sitemaps_to_process, headers, collected_urls, sitemap_responses, config )

    Log.logger.info("Located urls\n#{collected_urls.join("\n")}")

    #todo apply the additional business logic concerns see optional.validations
    #puts sitemap_responses.to_json
    #puts collected_urls.to_json
  end

  def self.build_headers( config )
    headers = {}
    #https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent
    headers['User-Agent'] = config.user_agent_for_requests
    headers
  end

  def self.process_sitemaps( sitemaps_to_process, headers, collected_urls, sitemap_responses, config )
    processed_sitemaps = []
    loop do
      sitemap_url = sitemaps_to_process.pop
      processs_sitemap( sitemap_url, headers, sitemaps_to_process, processed_sitemaps, collected_urls, sitemap_responses )
      unless sitemaps_to_process.empty?
        sleep config.delay_between_requests_in_seconds
      end
      break if sitemaps_to_process.empty?
    end
  end

  def self.processs_sitemap( sitemap_url, headers, sitemaps_to_process, processed_sitemaps, collected_urls, sitemap_responses )
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

          as_xml_doc.elements.each('sitemapindex/urlset/url/loc') do |location_element|
            collected_urls << location_element.text
          end

          as_xml_doc.elements.each('urlset/url/loc') do |location_element|
            collected_urls << location_element.text
          end
        end
      rescue => ex
        Log.logger.error( "Error: sitemap_url=#{sitemap_url} contents could not be parsed as xml")
      end

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
        #valid = xsd.valid?(as_xml_doc)
        has_errors = false
        xsd.validate(as_xml_doc).each do |error|
          has_errors = true
          Log.logger.error( "Error: Sitemap #{sitemap_url} contains error=#{error.message}" )
        end
        return !has_errors
      rescue => ex
        Log.logger.error( "Error: Sitemap #{sitemap_url} failed schema validation" )
        sitemap_responses[sitemap_url] = 'Failed schema validation'
        false
      end

    end
  end

end