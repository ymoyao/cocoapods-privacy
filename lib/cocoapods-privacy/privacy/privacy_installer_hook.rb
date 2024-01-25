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

    alias_method :privacy_origin_install!, :install!
        def install!
        privacy_origin_install!()
 
        if !(Pod::Config.instance.bb_is_privacy || !Pod::Config.instance.bb_privacy_folds.empty?)
          return
        end

        # 过滤出宝宝巴士自身组件 && 自身没有隐私协议文件的spec
        bb_modules = @analysis_result.specifications.select { 
          |obj| obj.is_bb_module && !obj.has_privacy
        }
        
        # 存储本地调试组件
        bb_development_folds = []

        # 获取组件所在工程的pods 目录
        bb_pod_folds = bb_modules.map{ |spec|
            name = spec.name.split('/').first
            fold = File.join(@sandbox.root,name)
            if Dir.exist?(fold)
              fold
            else
              development_pods = @sandbox.development_pods
              if name && development_pods
                podspec_file_path = development_pods[name]
                if podspec_file_path && !podspec_file_path.empty? 
                  podspec_fold_path = File.dirname(podspec_file_path)
                  source_files = spec.attributes_hash['source_files']
                  if source_files && !source_files.empty?
                    source_files.each do |file|
                      bb_development_folds << File.join(podspec_fold_path,file)
                    end
                  end
                end
              end
              nil
            end
        }.compact
       
        # 拼接本地调试和远端的pod目录 (并去重)
        bb_pod_folds += bb_development_folds
        bb_pod_folds << PrivacyUtils.project_code_fold
        bb_pod_folds = bb_pod_folds.uniq

        # 在工程 在对应位置创建隐私文件
        privacy_path = PrivacyModule.load(true).first

        # 开始检索api,并返回json 字符串数据
        json_data = PrivacyHunter.search_pricacy_apis(bb_pod_folds)

        # 将数据写入隐私清单文件
        PrivacyHunter.write_to_privacy(json_data,privacy_path)
    end

  end
end