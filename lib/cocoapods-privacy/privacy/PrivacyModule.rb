require 'cocoapods-privacy/command'
require 'cocoapods-core/specification/dsl/attribute_support'
require 'cocoapods-core/specification/dsl/attribute'
require 'xcodeproj'

module PrivacyModule

  public

  # 处理工程
  def self.load_project(folds,exclude_folds)
    project_path = PrivacyUtils.project_path()
    resources_folder_path = File.join(File.basename(project_path, File.extname(project_path)),'Resources')
    privacy_file_path = File.join(resources_folder_path,PrivacyUtils.privacy_name)
    # 如果隐私文件不存在，创建隐私协议模版
    unless File.exist?(privacy_file_path) 
      PrivacyUtils.create_privacy_if_empty(privacy_file_path)
    end
    
    # 如果没有隐私文件，那么新建一个添加到工程中
    # 打开 Xcode 项目，在Resources 下创建
    project = Xcodeproj::Project.open(File.basename(project_path))
    main_group = project.main_group
    resources_group = main_group.find_subpath('Resources',false)
    if resources_group.nil?
      resources_group = main_group.new_group('Resources',resources_folder_path)
    end

    # 如果不存在引用，创建新的引入xcode引用
    if resources_group.find_file_by_path(PrivacyUtils.privacy_name).nil?
      privacy_file_ref = resources_group.new_reference(PrivacyUtils.privacy_name,:group)
      privacy_file_ref.last_known_file_type = 'text.xml'
      target = project.targets.first
      resources_build_phase = target.resources_build_phase
      resources_build_phase.add_file_reference(privacy_file_ref) # 将文件引用添加到 resources 构建阶段中
      # target.add_file_references([privacy_file_ref]) # 将文件引用添加到 target 中
      # resources_group.new_file(privacy_file_path)
    end
    
    project.save

    # 开始检索api,并返回json 字符串数据
    PrivacyLog.clean_result_log()
    json_data = PrivacyHunter.search_pricacy_apis(folds,exclude_folds)

    # 将数据写入隐私清单文件
    PrivacyHunter.write_to_privacy(json_data,privacy_file_path)
    PrivacyLog.result_log_tip()
  end

  # 处理组件
  def self.load_module(podspec_file_path)
    specManager = BB::BBSpecManager.new(KSpecTypePrivacy)
    puts "👇👇👇👇👇👇 Start analysis component privacy 👇👇👇👇👇👇"
    PrivacyLog.clean_result_log()
    privacy_hash = specManager.check(podspec_file_path)
    privacy_hash.each do |privacy_file_path, hash|
      PrivacyLog.write_to_result_log("#{privacy_file_path}: \n")
      source_files = hash[KSource_Files_Key]
      exclude_files = hash[KExclude_Files_Key]
      data = PrivacyHunter.search_pricacy_apis(source_files,exclude_files)
      PrivacyHunter.write_to_privacy(data,privacy_file_path) unless data.empty?
    end
    PrivacyLog.result_log_tip()
    puts "👆👆👆👆👆👆 End analysis component privacy 👆👆👆👆👆👆"
  end



end
