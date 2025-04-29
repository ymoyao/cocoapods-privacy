require 'cocoapods-privacy/command'
#### 以下是隐私协议部分 #### 
module Pod
    class Config
        attr_accessor :privacy_folds
        attr_accessor :is_privacy
        attr_accessor :is_query
        attr_accessor :is_all
    end
end

module Pod
    class Command
      class Install < Command
        class << self
          alias_method :origin_options, :options
          def options
            [
            ['--privacy', '使用该参数，会自动生成并更新PrivacyInfo.xcprivacy'],
            ['--privacy-folds=folds', '指定文件夹检索，多个文件夹使用逗号","分割'],
            ['--privacy-query', '仅查询隐私api，不做写入'],
            ['--privacy-all', '忽略黑名单和白名单限制，查询工程所有组件'],
            ].concat(origin_options)
          end
        end
  
        alias_method :privacy_origin_initialize, :initialize
        def initialize(argv)
          privacy_folds = argv.option('privacy-folds', '').split(',')
          is_query = argv.flag?('privacy-query',false)
          is_all = argv.flag?('privacy-all',false)
          is_privacy = argv.flag?('privacy',false)
          privacy_origin_initialize(argv)
          instance = Pod::Config.instance
          instance.privacy_folds = privacy_folds
          instance.is_privacy = is_privacy
          instance.is_query = is_query
          instance.is_all = is_all
        end
      end
    end
end

#### 以下是混淆部分 #### 
module Pod
  class Config
      attr_accessor :confuse_pattern
  end
end

module Pod
  class Command
    class Install < Command
      class << self
        alias_method :confuse_origin_options, :options
        def options
          [
          ['--confuse=enable', '使用该参数，开启工程混淆'],
          ['--confuse=disable', '使用该参数，移除工程混淆配置'],
          # ['--confuse-folds=folds', '指定额外文件夹检索，多个文件夹使用逗号","分割'],
          # ['--confuse-all', '忽略黑名单和白名单限制，查询工程所有组件'],
          ].concat(origin_options)
        end
      end

      alias_method :confuse_origin_initialize, :initialize
      def initialize(argv)
        confuse_pattern = argv.option('confuse', '') #混淆模式
        confuse_origin_initialize(argv)
        instance = Pod::Config.instance
        instance.confuse_pattern = confuse_pattern
      end
    end
  end
end