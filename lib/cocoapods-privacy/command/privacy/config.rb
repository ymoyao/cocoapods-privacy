require 'cocoapods-privacy/command'

module Pod
    class Command
      class Privacy < Command
        class Config < Privacy
            self.summary = '初始化隐私清单配置'
  
            self.description = <<-DESC
                初始化隐私清单配置，包含必须的隐私api模版，和source 黑白名单等，配置文件格式详细见 #{"https://github.com/ymoyao/cocoapods-privacy"}
            DESC
      
            def initialize(argv)
                @config = argv.shift_argument
                super
            end
        
            def validate!
                super
                help! 'A config url is required.' unless @config
                raise Informative, "配置文件格式不是 JSON，请检查配置#{@config}" unless @config.end_with?(".json")                
            end

            def run
              load_config_file()
            end

            def load_config_file
              # 检查 @config 是远程 URL 还是本地文件路径
              if @config.start_with?('http')
                download_remote_config
              else
                copy_local_config
              end
            end
            
            def download_remote_config
              # 配置文件目录
              cache_config_file = PrivacyUtils.cache_config_file

              # 开始下载
              system("curl -o #{cache_config_file} #{@config}")

              if File.exist?(cache_config_file)
                puts "配置文件已下载到: #{cache_config_file}"
              else
                raise Informative, "配置文件下载出错，请检查下载地址#{@config}"
              end
            end
            
            def copy_local_config
              # 配置文件目录
              cache_config_file = PrivacyUtils.cache_config_file
            
              # 复制本地文件
              FileUtils.cp(@config, cache_config_file)
            
              puts "配置文件已复制到: #{cache_config_file}"
            end
        end
      end
    end
  end
  