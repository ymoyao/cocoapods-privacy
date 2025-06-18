require 'cocoapods-privacy/command'
require 'cocoapods-core/specification/dsl/attribute_support'
require 'cocoapods-core/specification/dsl/attribute'
require 'xcodeproj'
require 'plist'
require 'yaml'
require 'base64'

module ConfuseModule

  public

  # 处理组件
  def self.load_module(podspec_file_path)
    # puts "podspec_file_path = #{podspec_file_path}"
    specManager = BB::BBSpecManager.new(KSpecTypeConfuse)
    puts "👇👇👇👇👇👇 Start analysis component confuse 👇👇👇👇👇👇"
    confuse_hash = specManager.check(podspec_file_path)
    confuse_hash.each do |confuse_file_path, hash|
      source_files = hash[KSource_Files_Key]
      exclude_files = hash[KExclude_Files_Key]
      # puts "source_files = #{source_files}"
      # puts "exclude_files = #{exclude_files}"
      # puts "confuse_file_path = #{confuse_file_path}"
      podspec = Pod::Specification.from_file(podspec_file_path)
      version =  podspec.version.to_s.gsub('.', '_')  # Replace dots with underscores
      name = Base64.encode64(podspec.name.to_s)
      mix_version = version + "_" + name

      hunter = Confuse::Hunter.new(mix_version)
      apis_define_map, swift_extension_funcBody_map = hunter.search_need_confuse_apis(source_files,exclude_files)  
      # puts "swift_extension_funcBody_map = #{swift_extension_funcBody_map}"

      oc_confuse_file_path = "#{confuse_file_path}.h"
      swift_confuse_file_path = "#{confuse_file_path}.swift"
      hunter.insert_encrypted_apis_to_confuse_header(apis_define_map,oc_confuse_file_path)
      hunter.insert_encrypted_apis_to_confuse_swift(swift_extension_funcBody_map,swift_confuse_file_path)
    end
    puts "👆👆👆👆👆👆 End analysis component confuse 👆👆👆👆👆👆"
  end

  # # 处理工程
  # def self.load_project(folds,exclude_folds,installer)
  #   project_path = ConfuseUtils.project_path()
  #   confuse_folder_path = File.join(File.basename(project_path, File.extname(project_path)),ConfuseUtils.confuse_folder)
  #   confuse_file_path = File.join(confuse_folder_path,ConfuseUtils.confuse_name)

  #   #创建混淆头文件
  #   # 如果混淆头文件不存在，创建混淆文件
  #   unless File.exist?(confuse_file_path) 
  #       puts "#{confuse_file_path}"
  #       ConfuseUtils.create_confuse_if_empty(confuse_file_path)
  #   end
    
  #   # 打开 Xcode 项目，在Confuse下 创建
  #   project = Xcodeproj::Project.open(File.basename(project_path))
  #   main_group = project.main_group
  #   resources_group = main_group.find_subpath('Confuse',false)
  #   if resources_group.nil?
  #     resources_group = main_group.new_group('Confuse',confuse_folder_path)
  #   end

  #   target = project.targets.first
  #   resources_build_phase = target.resources_build_phase
  #   # 如果不存在引用，创建新的引入xcode引用
  #   if resources_group.find_file_by_path(ConfuseUtils.confuse_name).nil?
  #       confuse_file_ref = resources_group.new_reference(ConfuseUtils.confuse_name,:group)
  #       confuse_file_ref.last_known_file_type = 'sourcecode.objc.h'
  #       resources_build_phase.add_file_reference(confuse_file_ref) # 将文件引用添加到 resources 构建阶段中
  #   end

  #   confuse_pch_file_path = ""
  #   # 遍历项目的所有 targets，添加或修改 PCH 文件的设置
  #   project.targets.each do |target|
  #       target.build_configurations.each do |config|
  #           # 获取当前的 Prefix Header 设置
  #           current_pch = config.build_settings['GCC_PREFIX_HEADER']
        
  #           puts "name = #{target.name}"

  #           # 如果当前没有设置 PCH 文件，则添加新的设置
  #           if current_pch.nil? || current_pch.empty?
  #               # 如果混淆PCH不存在，创建混淆文件
  #               confuse_pch_file_path = File.join(confuse_folder_path,ConfuseUtils.confuse_pch_name)
  #               unless File.exist?(confuse_pch_file_path) 
  #                   puts "confuse_pch_file_path = #{confuse_pch_file_path}"
  #                   ConfuseUtils.create_confuse_if_empty(confuse_pch_file_path,ConfuseUtils.confuse_pch_content)
  #               end

  #               #pch 添加到xcode 索引
  #               if resources_group.find_file_by_path(ConfuseUtils.confuse_pch_name).nil?
  #                   confuse_pch_file_ref = resources_group.new_reference(ConfuseUtils.confuse_pch_name,:group)
  #                   confuse_pch_file_ref.last_known_file_type = 'sourcecode.objc.h'
  #                   resources_build_phase.add_file_reference(confuse_pch_file_ref) # 将文件引用添加到 resources 构建阶段中
  #                   puts "confuse_pch_file_ref = #{confuse_pch_file_ref}"
  #               end

  #               # pch 路径添加到build setting 
  #               config.build_settings['GCC_PREFIX_HEADER'] = "$(SRCROOT)/#{ConfuseUtils.project_name}/#{ConfuseUtils.confuse_folder}/#{ConfuseUtils.confuse_pch_name}"
  #           else

  #               pch_file_name = File.basename(current_pch)
  #               confuse_pch_file_path = Dir.glob("**/#{pch_file_name}").first

  #               # 如果 PCH 文件已设置，检查并修改文件内容
  #               if File.exist?(confuse_pch_file_path)
  #                 file_content = File.read(confuse_pch_file_path)

  #                 # 检查是否已包含 
  #                 unless file_content.include?("#{ConfuseUtils.confuse_name}")
  #                   # 找到最后一个 #endif，插入新的 import 语句
  #                   last_ifdef_index = file_content.rindex('#endif')

  #                   if last_ifdef_index
  #                     inser_content = "\n//混淆需要的头文件,不能删除\n#import \"#{ConfuseUtils.confuse_name}\"\n"
  #                     puts "检测到已存在pch#{confuse_pch_file_path}, 直接在现在pch 文件中插入混淆头部文件 #{inser_content}"
  #                     file_content.insert(last_ifdef_index,inser_content)
  #                     File.write(confuse_pch_file_path, file_content)
  #                   end
  #                 end
  #               end
  #           end
  #       end
  #   end

  #   version = "" #内部使用随机字符串,不需要版本
  #   # #获取工程版本号,用来做动态混淆,每个确保每个版本都不一致
  #   # plist_path = target.resolved_build_setting('INFOPLIST_FILE', resolve_against: target).first
  #   # plist_path = File.join(File.dirname(project_path), plist_path)
  #   # plist = Plist.parse_xml(plist_path)
  #   # unless plist.nil?
  #   #     version = plist['CFBundleShortVersionString']
  #   # end
    
  #   project.save


  #   # installer.pod_target_subprojects.flat_map { |p| p.targets }.each do |target|
  #   #   target.build_configurations.each do |config|
  #   #        puts "name2 = #{target.name}"
  #   #        config.build_settings['GCC_PREFIX_HEADER'] = "$(SRCROOT)/#{ConfuseUtils.project_name}/#{ConfuseUtils.confuse_folder}/#{ConfuseUtils.confuse_pch_name}"
  #   #   end
  #   # end

  #   # 开始检索api,并返回json 字符串数据
  #   hunter =  ConfuseHunter.new("")
  #   apis = hunter.search_need_confuse_apis(folds,exclude_folds)

  #   # 将数据写入混淆文件
  #   hunter.insert_encrypted_apis_to_confuse_header(apis,confuse_file_path,version)
  # end
end