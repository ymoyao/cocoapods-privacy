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


    # 直接执行 pod privacy 时调用
    def privacy_analysis(custom_folds)
      prepare
      resolve_dependencies
      clean_sandbox

      privacy_handle(custom_folds)
    end

    # hook pod install 命令
    alias_method :privacy_origin_install!, :install!
        def install!
        privacy_origin_install!()
 
        if !(Pod::Config.instance.is_privacy || (Pod::Config.instance.privacy_folds && !Pod::Config.instance.privacy_folds.empty?))
          return
        end

        privacy_handle(Pod::Config.instance.privacy_folds)
    end


    def privacy_handle(custom_folds)

      puts "👇👇👇👇👇👇 Start analysis project privacy 👇👇👇👇👇👇"
      # 过滤出自身组件 && 自身没有隐私协议文件的spec
      modules = @analysis_result.specifications.select { 
        |obj| obj.is_need_search_module && !obj.has_privacy
      }
      
      # 存储本地调试组件
      development_folds = []
      exclude_folds = []

      # 获取组件所在工程的pods 目录
      pod_folds = modules.map{ |spec|
        name = spec.name.split('/').first

        fold = File.join(@sandbox.root,name)
        podspec_file_path_develop = validate_development_pods(name)
        # 先验证是否是指向本地的组件（发现有的情况下 组件指向本地Pods 下依旧还是会有该组件，所以这里先判断本地的）
        if podspec_file_path_develop
          podspec_fold_path = File.dirname(podspec_file_path_develop)
          source_files = spec.attributes_hash['source_files']
          exclude_files = spec.attributes_hash['exclude_files']
          if source_files && !source_files.empty?
            if source_files.is_a?(String) && !source_files.empty?
              development_folds << File.join(podspec_fold_path,source_files)
            elsif source_files.is_a?(Array)
              source_files.each do |file|
                development_folds << File.join(podspec_fold_path,file)
              end
            end

            # 处理exclude_files 排除文件夹
            if exclude_files && !exclude_files.empty?
              if exclude_files.is_a?(String) && !exclude_files.empty?
                exclude_folds << File.join(podspec_fold_path,exclude_files)
              elsif exclude_files.is_a?(Array)
                exclude_files.each do |file|
                  exclude_folds << File.join(podspec_fold_path,file)
                end
              end
            end
          end
          nil
        elsif Dir.exist?(fold)
          formatter_search_fold(fold) 
        end
      }.compact
    
      
      pod_folds += development_folds # 拼接本地调试和远端的pod目录 
      pod_folds += [formatter_search_fold(PrivacyUtils.project_code_fold)].compact # 拼接工程同名主目录
      pod_folds += custom_folds || [] # 拼接外部传入的自定义目录
      pod_folds = pod_folds.uniq # 去重

      if pod_folds.empty?
        puts "无组件或工程目录, 请检查工程"
      else
        # 处理工程隐私协议
        PrivacyModule.load_project(pod_folds,exclude_folds.uniq)
      end
      puts "👆👆👆👆👆👆 End analysis project privacy 👆👆👆👆👆👆"
    end

    private
    def formatter_search_fold(fold)
      File.join(fold,"**","*.{m,c,swift,mm,hap,hpp,cpp}") 
    end

    def validate_development_pods(name)
      result = nil
      development_pods = @sandbox.development_pods
      if name && !name.empty? && development_pods && !development_pods.empty?
        podspec_file_path = development_pods[name]
        if podspec_file_path && !podspec_file_path.empty? 
          result = podspec_file_path
        end
      end
      result
    end
  end
end