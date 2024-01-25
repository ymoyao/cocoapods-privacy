
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

        # 是否为宝宝巴士组件
        def is_bb_module
            #查找source(可能是subspec)
             git_source = recursive_git_source(self)

            # 域名为babybus服务器，且非镜像同步，则判断为自身服务器
            git_source ? (git_source.include?("git.babybus.co") && !git_source.include?("GitMirrors")) : false
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

        # 测试代码
        # alias_method :origin_hash,:hash
        # def hash
        #     puts "模块：#{module_name}  #{is_bb_module() ? '是' : '不是'}宝宝巴士组件"
        #     origin_hash()
        # end
    end
end

# module Pod
#     class Specification
#         module DSL
#             module RootAttributesAccessors
#                 def is_bb_module
#                     source[:git].include?("git.babybus.co")
#                 end
#             end
#         end
#     end
# end