
require 'cocoapods-core/specification/root_attribute_accessors'

module Pod
    # The Specification provides a DSL to describe a Pod. A pod is defined as a
    # library originating from a source. A specification can support detailed
    # attributes for modules of code  through subspecs.
    #
    # Usually it is stored in files with `podspec` extension.
    #
    class Specification

        # 是否含有隐私协议文件
        def has_privacy
            resource_bundle = attributes_hash['resource_bundles']
            resource_bundle && resource_bundle.to_s.include?('PrivacyInfo.xcprivacy')
        end

        # 是否为需要检索组件
        def is_need_search_module
            unless File.exist?(PrivacyUtils.cache_config_file)
                raise Informative, "无配置文件，run `pod privacy config config_file` 进行配置"
            end

            #查找source(可能是subspec)
            git_source = recursive_git_source(self)
            unless git_source
                return false
            end

            # 如果指定了--all 参数，那么忽略黑名单白名单，全部检索
            return true if Pod::Config.instance.is_all

            # 判断域名白名单 和 黑名单，确保该组件是自己的组件，第三方sdk不做检索
            config = Privacy::Config.instance          
            git_source_whitelisted = config.source_white_list.any? { |item| git_source.include?(item) }
            git_source_blacklisted = config.source_black_list.any? { |item| git_source.include?(item) }
            git_source_whitelisted && !git_source_blacklisted
        end

        # 返回resource_bundles
        def bb_resource_bundles
          hash_value['resource_bundles']
        end

        private
        def recursive_git_source(spec)
            return nil unless spec
            if spec.source && spec.source.key?(:git)
                spec.source[:git]
            else
                recursive_git_source(spec.instance_variable_get(:@parent))
            end
        end
    end
end