require 'cocoapods-privacy/command'
require 'digest'

module Common
    class Config        
        def initialize()
            load_config_content_if_exist()
        end
        
        def api_template_url
            load_config_content_if_exist()
            return @json['api.template.url'] || ""
        end

        def source_black_list
            load_config_content_if_exist()
            return @json['source.black.list'] || []
        end

        def source_white_list
            load_config_content_if_exist()
            return @json['source.white.list'] || []
        end

        def self.instance
            @instance ||= new
        end

        def cache_privacy_fold
            # 本地缓存目录
            cache_directory = File.expand_path('~/.cache')
            
            # 目标文件夹路径
            target_directory = File.join(cache_directory, 'cocoapods-privacy', 'privacy')
        
            # 如果文件夹不存在，则创建
            FileUtils.mkdir_p(target_directory) unless Dir.exist?(target_directory)
        
            target_directory
        end
    
        # etag 文件夹
        def cache_privacy_etag_fold
            File.join(cache_privacy_fold,'etag')
        end
        
        # config.json 文件
        def cache_config_file
            File.join(cache_privacy_fold, 'config.json')
        end
    
        # config.json 文件
        def cache_log_file
             File.join(cache_privacy_fold, 'privacy.log')
        end

        private
        def load_config_content_if_exist
            unless @json 
                if File.exist?(cache_config_file)
                    config_content = File.read(cache_config_file)
                    @json = JSON.parse(config_content)
                end
            end
        end
              
      
    end
end