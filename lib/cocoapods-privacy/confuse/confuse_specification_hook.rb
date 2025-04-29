
require 'cocoapods-core/specification/root_attribute_accessors'
require 'cocoapods-privacy/command'

module Pod
    # The Specification provides a DSL to describe a Pod. A pod is defined as a
    # library originating from a source. A specification can support detailed
    # attributes for modules of code  through subspecs.
    #
    # Usually it is stored in files with `podspec` extension.
    #
    class Specification

        # 是否为需要检索组件
        def confuse_is_need_search_module
            unless File.exist?(ConfuseUtils.cache_config_file)
                raise Informative, "无配置文件，run `pod confuse config config_file` 进行配置"
            end

            #查找source(可能是subspec)
            git_source = recursive_git_source(self)
            unless git_source
                return false
            end

            # 如果指定了--all 参数，那么忽略黑名单白名单，全部检索
            return true if Pod::Config.instance.is_confuse_all

            # 判断域名白名单 和 黑名单，确保该组件是自己的组件，第三方sdk不做检索
            config = Common::Config.instance     

            ## 规则：
            # 1、白名单/黑名单是通过组件podspec 中 source 字段的值来匹配，包含关键词即为命中，所有可以是git关键的域名，也可以是完整的git链接
            # 2、白名单：当白名单为空数组时：默认为全部组件都为白名单！！！； 当白名单不为空时，仅检索白名单数组内的组件
            git_source_whitelisted = config.source_white_list.empty? ? true : config.source_white_list.any? { |item| git_source.include?(item) }

            ## 3、黑名单：在白名单基础上，需要排除的组件
            git_source_blacklisted = config.source_black_list.any? { |item| git_source.include?(item) }
            ## 4、最终检索的范围：白名单 - 黑名单
            git_source_whitelisted && !git_source_blacklisted
        end

        private
        def recursive_git_source(spec)
            return nil unless spec
            if spec.source && spec.source.key?(:git)
                spec.source[:git]
            elsif spec.source && spec.source.key?(:http)
                # 如果 Git 源地址不存在，尝试获取 HTTP 源地址
                spec.source[:http]
            else
                recursive_git_source(spec.instance_variable_get(:@parent))
            end
        end
    end
end