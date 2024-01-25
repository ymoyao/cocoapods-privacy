require 'cocoapods-privacy/command'

module Privacy
    class Config
        
        def initialize()
            config_content = File.read(PrivacyUtils.cache_config_file)
            @json = JSON.parse(config_content)
        end

        def api_template_url
            return @json['api.template.url'] || ""
        end

        def source_black_list
            return @json['source.black.list'] || []
        end

        def source_white_list
            return @json['source.white.list'] || []
        end

        def self.instance
            @instance ||= new
        end
      
    end
end