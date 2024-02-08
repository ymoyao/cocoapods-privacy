require 'digest'

module PrivacyUtils

    def self.privacy_name
      'PrivacyInfo.xcprivacy'
    end
    
    # 通过是否包含podspec 来判断是否为主工程
    def self.isMainProject
      !(podspec_file_path && !podspec_file_path.empty?)
    end

    # 查找podspec
    def self.podspec_file_path
      base_path = Pathname.pwd
      matching_files = Dir.glob(File.join(base_path, '*.podspec'))
      matching_files.first
    end

    # xcode工程地址
    def self.project_path
      matching_files = Dir[File.join(Pathname.pwd, '*.xcodeproj')].uniq
      matching_files.first
    end

    # xcode工程主代码目录
    def self.project_code_fold
      projectPath = project_path
      File.join(Pathname.pwd,File.basename(projectPath, File.extname(projectPath)))
    end

    # 使用正则表达式匹配第一个字符前的空格数量
    def self.count_spaces_before_first_character(str)
      match = str.match(/\A\s*/)
      match ? match[0].length : 0
    end

    # 使用字符串乘法添加指定数量的空格
    def self.add_spaces_to_string(str, num_spaces)
      spaces = ' ' * num_spaces
      "#{spaces}#{str}"
    end

    def self.to_md5(string)
      md5 = Digest::MD5.new
      md5.update(string)
      md5.hexdigest
    end

    def self.cache_privacy_fold
      # 本地缓存目录
      cache_directory = File.expand_path('~/.cache')
      
      # 目标文件夹路径
      target_directory = File.join(cache_directory, 'cocoapods-privacy', 'privacy')

      # 如果文件夹不存在，则创建
      FileUtils.mkdir_p(target_directory) unless Dir.exist?(target_directory)

      target_directory
    end

    # etag 文件夹
    def self.cache_privacy_etag_fold
      File.join(cache_privacy_fold,'etag')
    end
    
    # config.json 文件
    def self.cache_config_file
      config_file = File.join(cache_privacy_fold, 'config.json')
    end

    # config.json 文件
    def self.cache_log_file
      config_file = File.join(cache_privacy_fold, 'privacy.log')
    end

    # 创建默认隐私协议文件
    def self.create_privacy_if_empty(file_path) 
      # 文件内容
     file_content = <<~EOS
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0">
     <dict>
       <key>NSPrivacyTracking</key>
       <false/>
       <key>NSPrivacyTrackingDomains</key>
       <array/>
       <key>NSPrivacyCollectedDataTypes</key>
       <array/>
       <key>NSPrivacyAccessedAPITypes</key>
       <array/>
     </dict>
     </plist>     
     EOS
   
     isCreate = create_file_and_fold_if_no_exit(file_path,file_content)
     if isCreate
       puts "【隐私清单】（初始化）存放地址 => #{file_path}"
     end
   end
   
   # 创建文件，并写入默认值，文件路径不存在会自动创建
   def self.create_file_and_fold_if_no_exit(file_path,file_content = nil)
     folder_path = File.dirname(file_path)
     FileUtils.mkdir_p(folder_path) unless File.directory?(folder_path)
   
     # 创建文件（如果不存在/或为空）
     if !File.exist?(file_path) || File.zero?(file_path)
       File.open(file_path, 'w') do |file|
         file.write(file_content)
       end
       return true
     end 
     return false
   end

   # 查询group 中是否有执行路径的子group
   def self.find_group_by_path(group,path)
     result = nil
     sub_group = group.children
     if sub_group && !sub_group.empty?
       sub_group.each do |item|
         if item.path == path
           result = item
           break
         end
       end
     end
     result
   end

end