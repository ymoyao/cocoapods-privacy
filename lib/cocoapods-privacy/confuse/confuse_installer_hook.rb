require 'active_support/core_ext/string/inflections'
require 'fileutils'
require 'cocoapods/podfile'
require 'cocoapods-privacy/command'

module Pod
  # The Installer is responsible of taking a Podfile and transform it in the
  # Pods libraries. It also integrates the user project so the Pods
  # libraries can be used out of the box.
  #
  # The Installer is capable of doing incremental updates to an existing Pod
  # installation.
  #
  # The Installer gets the information that it needs mainly from 3 files:
  #
  #   - Podfile: The specification written by the user that contains
  #     information about targets and Pods.
  #   - Podfile.lock: Contains information about the pods that were previously
  #     installed and in concert with the Podfile provides information about
  #     which specific version of a Pod should be installed. This file is
  #     ignored in update mode.
  #   - Manifest.lock: A file contained in the Pods folder that keeps track of
  #     the pods installed in the local machine. This files is used once the
  #     exact versions of the Pods has been computed to detect if that version
  #     is already installed. This file is not intended to be kept under source
  #     control and is a copy of the Podfile.lock.
  #
  # The Installer is designed to work in environments where the Podfile folder
  # is under source control and environments where it is not. The rest of the
  # files, like the user project and the workspace are assumed to be under
  # source control.
  #
    class Installer
        autoload :Analyzer,                     'cocoapods/installer/analyzer'
        autoload :InstallationOptions,          'cocoapods/installer/installation_options'
        autoload :PostInstallHooksContext,      'cocoapods/installer/post_install_hooks_context'
        autoload :PreInstallHooksContext,       'cocoapods/installer/pre_install_hooks_context'
        autoload :BaseInstallHooksContext,      'cocoapods/installer/base_install_hooks_context'
        autoload :PostIntegrateHooksContext,    'cocoapods/installer/post_integrate_hooks_context'
        autoload :PreIntegrateHooksContext,     'cocoapods/installer/pre_integrate_hooks_context'
        autoload :SourceProviderHooksContext,   'cocoapods/installer/source_provider_hooks_context'
        autoload :PodfileValidator,             'cocoapods/installer/podfile_validator'
        autoload :PodSourceDownloader,          'cocoapods/installer/pod_source_downloader'
        autoload :PodSourceInstaller,           'cocoapods/installer/pod_source_installer'
        autoload :PodSourcePreparer,            'cocoapods/installer/pod_source_preparer'
        autoload :UserProjectIntegrator,        'cocoapods/installer/user_project_integrator'
        autoload :Xcode,                        'cocoapods/installer/xcode'
        autoload :SandboxHeaderPathsInstaller,  'cocoapods/installer/sandbox_header_paths_installer'
        autoload :SandboxDirCleaner,            'cocoapods/installer/sandbox_dir_cleaner'
        autoload :ProjectCache,                 'cocoapods/installer/project_cache/project_cache'
        autoload :TargetUUIDGenerator,          'cocoapods/installer/target_uuid_generator'
        

        # 保hook post_install 方法
        alias_method :bb_original_run_podfile_post_install_hook, :run_podfile_post_install_hook
        def run_podfile_post_install_hook
          bb_original_run_podfile_post_install_hook
          confuse_pattern = Pod::Config.instance.confuse_pattern
          # return if confuse_pattern.nil? || confuse_pattern.empty?   

          case confuse_pattern
          when "enable"
            enable_confuse()
          when "disable"
            disable_confuse()
          else
            #读取工程plistinfo 中的ISConfuse 配置
            project_path = ConfuseUtils.project_path()
            project = Xcodeproj::Project.open(File.basename(project_path))
            target = project.targets.first
            plist_path = target.resolved_build_setting('INFOPLIST_FILE', resolve_against: target).first.last

            if project_path.nil? || plist_path.nil? || project_path.empty? || plist_path.empty?
              return
            end

            plist_path = File.join(File.dirname(project_path), plist_path)
            plist = Plist.parse_xml(plist_path)
            puts plist_path
  
            unless plist.nil?
              is_confuse = plist['ISConfuse']
              if is_confuse.nil?
                puts "None key for ISConfuse"
                # 没有 --confuse 命令和 Info 配置, 不处理
              elsif is_confuse == true
                enable_confuse()
              elsif is_confuse == false
                disable_confuse()
              else
                puts "Invalid value for ISConfuse"
              end
            end    
          end 
        end

        def enable_confuse
          puts "[混淆]标识添加"
          self.pod_target_subprojects.each do |p|
            p.targets.each do |target|
              target.build_configurations.each do |config|
        
                # 获取关联的 xcconfig 文件
                xcconfig_path = config.base_configuration_reference.real_path
                xcconfig = File.read(xcconfig_path)
                # puts "xcconfig = #{xcconfig}"

                # 处理 GCC_PREPROCESSOR_DEFINITIONS，确保不重复添加
                unless xcconfig.include?('BB_Confuse_Enable_Flag=1')
                  # 先查找 GCC_PREPROCESSOR_DEFINITIONS 部分，插入新的宏定义
                  if xcconfig.include?('GCC_PREPROCESSOR_DEFINITIONS')
                    xcconfig.gsub!(/GCC_PREPROCESSOR_DEFINITIONS\s*=\s*(.*?)(\n|$)/) do |match|
                      "#{match.gsub("\n", "")} BB_Confuse_Enable_Flag=1\n"
                    end
                  else
                    # 如果没有找到该行，直接追加到文件末尾
                    xcconfig << "\nGCC_PREPROCESSOR_DEFINITIONS = ${inherited} BB_Confuse_Enable_Flag=1\n"
                  end
                end

                # 处理 OTHER_SWIFT_FLAGS，确保不重复添加
                unless xcconfig.include?('-D BB_Confuse_Enable_Flag')
                  # 先查找 OTHER_SWIFT_FLAGS 部分，插入新的编译条件
                  if xcconfig.include?('OTHER_SWIFT_FLAGS')
                    xcconfig.gsub!(/nOTHER_SWIFT_FLAGS\s*=\s*(.*?)(\n|$)/) do |match|
                      "#{match.gsub("\n", "")} -D BB_Confuse_Enable_Flag\n"
                    end
                  else
                    # 如果没有找到该行，直接追加到文件末尾
                    xcconfig << "\nOTHER_SWIFT_FLAGS = ${inherited} -D BB_Confuse_Enable_Flag\n"
                  end
                end
                          
                File.write(xcconfig_path, xcconfig)
              end
            end
          end
        end

        def disable_confuse
          puts "[混淆]标识移除"
          self.pod_target_subprojects.each do |p|
            p.targets.each do |target|
              target.build_configurations.each do |config|
                # 获取关联的 xcconfig 文件
                xcconfig_path = config.base_configuration_reference.real_path
                xcconfig = File.read(xcconfig_path)

                # 移除 GCC_PREPROCESSOR_DEFINITIONS 中的 BB_Confuse_Enable_Flag=1
                if xcconfig.include?('BB_Confuse_Enable_Flag=1')
                  xcconfig.gsub!(/BB_Confuse_Enable_Flag=1/, '$(inherited)')
                end
          
                # 移除 OTHER_SWIFT_FLAGS 中的 -D BB_Confuse_Enable_Flag
                if xcconfig.include?('-D BB_Confuse_Enable_Flag')
                  xcconfig.gsub!(/-D BB_Confuse_Enable_Flag/, '$(inherited)')
                end
          
                # 保存修改后的 xcconfig 文件
                File.write(xcconfig_path, xcconfig)
              end
            end
          end
        end


        # private 
        # def get_subprojects(project)
        #   # 获取项目中所有文件引用（PBXFileReference）
        #   file_refs = project.objects.select { |obj| obj.isa == 'PBXFileReference' }
          
        #   # 筛选出以 .xcodeproj 结尾的引用路径
        #   subproject_refs = file_refs.select do |ref|
        #     ref.path.to_s.end_with?('.xcodeproj')
        #   end
        
        #   # 转换为实际 Project 对象（需加载）
        #   subproject_refs.map do |ref|
        #     subproject_path = File.expand_path(ref.path, project.project_dir)
        #     Xcodeproj::Project.open(subproject_path)
        #   end
        # end
  #   def confuse_handle(custom_folds)

  #     lib.pod_target_subprojects.flat_map { |p| p.targets }.each do |target|
  #       target.build_configurations.each do |config|
  #         # 为 Objective-C 添加宏定义
  #         current_oc_defs = config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] || ['$(inherited)']
  #         new_oc_defs = current_oc_defs + ['BB_Confuse_Enable_Flag=1']
  #         config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = new_oc_defs.uniq
          
  #         # 为 Swift 添加编译条件
  #         current_swift_flags = config.build_settings['OTHER_SWIFT_FLAGS'] || ['$(inherited)']
  #         new_swift_flags = current_swift_flags + ['-D BB_Confuse_Enable_Flag']
  #         config.build_settings['OTHER_SWIFT_FLAGS'] = new_swift_flags.uniq
  #       end
  #     end


  #     puts "👇👇👇👇👇👇 Start analysis project confuse 👇👇👇👇👇👇"
  #     # 过滤出自身组件 && 自身没有隐私协议文件的spec
  #     modules = @analysis_result.specifications.select { 
  #       |obj| obj.confuse_is_need_search_module
  #     }
      
  #     # 存储本地调试组件
  #     development_folds = []
  #     exclude_folds = []

  #     # 获取组件所在工程的pods 目录
  #     pod_folds = modules.map{ |spec|
  #       name = spec.name.split('/').first

  #       fold = File.join(@sandbox.root,name)
  #       podspec_file_path_develop = validate_development_pods(name)
  #       # 先验证是否是指向本地的组件（发现有的情况下 组件指向本地Pods 下依旧还是会有该组件，所以这里先判断本地的）
  #       if podspec_file_path_develop
  #         podspec_fold_path = File.dirname(podspec_file_path_develop)
  #         source_files = spec.attributes_hash['source_files']
  #         exclude_files = spec.attributes_hash['exclude_files']
  #         if source_files && !source_files.empty?
  #           if source_files.is_a?(String) && !source_files.empty?
  #             development_folds << File.join(podspec_fold_path,source_files)
  #           elsif source_files.is_a?(Array)
  #             source_files.each do |file|
  #               development_folds << File.join(podspec_fold_path,file)
  #             end
  #           end

  #           # 处理exclude_files 排除文件夹
  #           if exclude_files && !exclude_files.empty?
  #             if exclude_files.is_a?(String) && !exclude_files.empty?
  #               exclude_folds << File.join(podspec_fold_path,exclude_files)
  #             elsif exclude_files.is_a?(Array)
  #               exclude_files.each do |file|
  #                 exclude_folds << File.join(podspec_fold_path,file)
  #               end
  #             end
  #           end
  #         end
  #         nil
  #       elsif Dir.exist?(fold)
  #         formatter_search_fold(fold) 
  #       end
  #     }.compact
    

  #     pod_folds += development_folds # 拼接本地调试和远端的pod目录 
  #     pod_folds += [formatter_search_fold(ConfuseUtils.project_code_fold)].compact # 拼接工程同名主目录
  #     pod_folds += custom_folds || [] # 拼接外部传入的自定义目录
  #     pod_folds = pod_folds.uniq # 去重

  #     if pod_folds.empty?
  #       puts "无组件或工程目录, 请检查工程"
  #     else
  #       # 处理工程混淆
  #       ConfuseModule.load_project(pod_folds,exclude_folds.uniq,self)
  #     end
  #     puts "👆👆👆👆👆👆 End analysis project confuse 👆👆👆👆👆👆"
  #   end

  #   private
  #   def formatter_search_fold(fold)
  #     File.join(fold,"**","*.{m,c,swift,mm,h,hap,hpp,cpp}") 
  #   end

  #   def validate_development_pods(name)
  #     result = nil
  #     development_pods = @sandbox.development_pods
  #     if name && !name.empty? && development_pods && !development_pods.empty?
  #       podspec_file_path = development_pods[name]
  #       if podspec_file_path && !podspec_file_path.empty? 
  #         result = podspec_file_path
  #       end
  #     end
  #     result
  #   end
  end
end

# module Pod
#   module CustomPlugin
#     class << self
#       def activate
#         # 注册 post_install 钩子
#         HooksManager.register('post_install', 'custom_plugin') do |installer_context|
#                     puts "Custom Plugin post_install hook triggered!"

#         end
#       end
#     end
#   end
# end

# # 激活插件
# Pod::CustomPlugin.activate