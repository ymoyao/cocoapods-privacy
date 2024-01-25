require 'cocoapods-privacy/command'

module Pod
    class Config
        attr_accessor :bb_privacy_folds
        attr_accessor :bb_is_privacy
    end
end

module Pod
    class Command
      class Install < Command
        class << self
          alias_method :origin_options, :options
          def options
            [
            ['--bb-privacy', '使用该参数，会自动生成并更新PrivacyInfo.xcprivacy'],
            ['--bb-privacy-folds=folds', '指定文件夹检索，多个文件夹使用逗号","分割'],
            ['--bb-privacy-whitelist=白名单', '白名单api类型 如：DDA9.1，多个类型使用逗号","分割'],
            ['--bb-privacy-blacklist=黑名单', '黑名单api类型 如：DDA9.1，多个类型使用逗号","分割'],
            ].concat(origin_options)
          end
        end
  
        alias_method :privacy_origin_initialize, :initialize
        def initialize(argv)
          privacy_folds = argv.option('bb-privacy-folds', '').split(',')
          is_privacy = argv.flag?('bb-privacy',false)
          privacy_origin_initialize(argv)
          instance = Pod::Config.instance
          instance.bb_privacy_folds = privacy_folds
          instance.bb_is_privacy = is_privacy
        end
      end
    end
end