module Pod
  class Command
    class Privacy < Command

      def initialize(argv)
        super
      end

      def run
        if PrivacyUtils.isMainProject
          puts "检测到#{PrivacyUtils.project_path || ""}工程文件， 请使用 pod privacy install 对工程进行隐私清单创建和自动检索"
        elsif PrivacyUtils.podspec_file_path
          puts "检测到#{PrivacyUtils.podspec_file_path || ""} 组件， 请使用 pod privacy spec 对组件进行隐私清单创建和自动检索"
        else
          puts "未检测到工程或podspec 文件， 请切换到工程或podspec文件目录下再次执行命令"
        end
      end      
    end
  end
end
