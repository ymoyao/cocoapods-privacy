require 'cocoapods-privacy/command'

module Pod
    class Config
        attr_accessor :privacy_folds
        attr_accessor :is_privacy
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
            ].concat(origin_options)
          end
        end
  
        alias_method :privacy_origin_initialize, :initialize
        def initialize(argv)
          privacy_folds = argv.option('privacy-folds', '').split(',')
          is_privacy = argv.flag?('privacy',false)
          privacy_origin_initialize(argv)
          instance = Pod::Config.instance
          instance.privacy_folds = privacy_folds
          instance.is_privacy = is_privacy
        end
      end
    end
end