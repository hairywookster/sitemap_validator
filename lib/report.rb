class Report


  def self.emit_reports( errors, sitemap_responses, url_responses, results_folder )
    Log.logger.info( "Sitemap validation completed, generating reports" )
    emit_console_report( errors, sitemap_responses, url_responses )
    emit_json_report( results_folder, errors, sitemap_responses, url_responses )
    emit_html_report( results_folder, errors, sitemap_responses, url_responses )
  end


  def self.emit_console_report( errors, sitemap_responses, url_responses )
    color = errors.empty? ? :green : :light_magenta
    Log.logger.info( '-----------------------------------------------'.colorize(color) )
    Log.logger.info( 'Summary'.colorize(color) )
    Log.logger.info( '-----------------------------------------------'.colorize(color) )
    Log.logger.info( "Processed sitemaps        = #{sitemap_responses.size}".colorize(color) )
    Log.logger.info( "Collected urls            = #{url_responses.size}".colorize(color) )
    Log.logger.info( '' )
    if errors.empty?
      Log.logger.info( "Success - everything is good".colorize(color) )
    else
      Log.logger.info( "Errors detected         = #{errors.size}".colorize(color) )
    end
  end

  def self.emit_json_report( results_folder, errors, sitemap_responses, url_responses )
    result = {
        :sitemaps => sitemap_responses,
        :urls => url_responses,
        :errors => errors
    }
    File.open("#{results_folder}/results.json", "w") do |f|
      f.puts( JSON.pretty_generate( result ) )
    end
  end

  def self.emit_html_report( results_folder, errors, sitemap_responses, url_responses )
    random_failure_word = 'borked'   #todo random wordage
    #note all the values passed into this method are used via the binding object when the template gets rendered
    File.open("#{results_folder}/results.html", "w") do |file|
      file.puts ERB.new(File.read("#{File.dirname(__FILE__)}/html_report_template.html.erb")).result( binding )
    end
  end

end