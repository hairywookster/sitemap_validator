# sitemap_validator
A simple sitemap validator

## Introduction
A frequent task when maintaining web sites is to validate that the sitemap(s) are functioning correctly.
Sitemaps can be either be
* self contained
* reference other sitemaps

This tool provides a simple way to validate the contents of the root sitemap and referenced sitemaps contain valid structure according the xml schema definition.
It also provides a way to specify extra checks that should be ran to confirm the contents of the sitemaps are as expected.

## Limitations
You should always review your sitemaps on Google Search Console to identify issues this tool may not locate.
This tool does not support every sitemap xsd format. But its trivial to extend to support new ones (i.e video , news, etc) 

## Installation
- Install rvm (assuming your on a flavor of linux) (otherwise see windows alternative) 
- Install Ruby 2.3+
- Optionally setup your .rvmrc and gem sandbox 
- gem install bundler
- bundle install

## Configuration
Rather than depending on an arcane and ever growing set of command line variables, lets keep things simple and use a 
single input of a json configuration file.

Storing the configuration as json gives us several advantages.
- It is easy to validate
- It is human readable
- It can be easily compared with other configurations
- It is easy to extend  

The config will support mandatory and optional settings as follows.
````json
{
  "log_level": "info",
  "sitemap_urls": [ "https://bbc.co.uk/sitemap.xml" , "https://www.bbc.com/sitemap.xml"],
  "user_agent_for_requests": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.139 Safari/537.36",
  "delay_between_requests_in_seconds": 0.5
}
````

### General notes
Note the [ ] notation indicates the tool expects zero or more string values.

### log_level (mandatory)
The log_level can be set to one of the following
- debug
- info
- warn
- error
- fatal

### sitemap_urls (mandatory)
The sitemap_urls array must contain at least one fully qualified url to start with, but can be (n) fully qualified urls.

### user_agent_for_requests (mandatory)
The user_agent_for_requests string must be set to a user agent of your choosing that will be sent on all requests.
If you find you need to request your pages with a list of user agents, you should create a separate config file per 
user agent.

### delay_between_requests_in_seconds (mandatory)
The delay_between_requests_in_seconds must be set to a positive float >= 0 (i.e. 0.1 is 100 milliseconds, 1 is 1 second) 
and will be used to set the time between each request.

## Validating your config
Config files can be validated easily, to run the validation simply run
````
rake validate_config["<path to the config file>"]
````

## Running the sitemap validator
Once your happy that your config is valid and your sitemaps are configured you can run the validator in anger.
The process will find and follow sitemapindex/sitemap/loc (other sitemaps) and collate all sitemapindex/urlset/url/loc.

To run the process run this command
````
run_validator["<path to the config file>", "<path to output report folder>"]
````

## Output
The tool generates 3 outputs
A simple console summary of the result
A detailed json file of the result - for consumption by other tools
A detailed html file of the result - for easy viewing

## Licence
Software is released under the [MIT License](LICENSE).
