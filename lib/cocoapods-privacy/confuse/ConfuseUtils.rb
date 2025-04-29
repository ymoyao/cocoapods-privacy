require 'digest'
require 'cocoapods-privacy/command'

module ConfuseUtils

    def self.confuse_name
        "bb_c_o_f_u_s_e.h"
    end

    def self.confuse_pch_name
        "bb_pre_head_cf.pch"
    end

    def self.confuse_folder
        "Confuse"
    end

    # xcode工程地址
    def self.project_path
      matching_files = Dir[File.join(Pathname.pwd, '*.xcodeproj')].uniq
      puts "matching_files = #{matching_files}"
      matching_files.first
    end

        # xcode工程地址
    def self.project_name
        projectPath = project_path
        File.basename(projectPath, File.extname(projectPath))
    end

    # xcode工程主代码目录
    def self.project_code_fold
        File.join(Pathname.pwd,project_name)
    end

    def self.cache_privacy_fold
        Common::Config.instance.cache_privacy_fold
    end
      
      # config.json 文件
    def self.cache_config_file
        Common::Config.instance.cache_config_file
    end

    # 创建默认混淆文件
    def self.create_confuse_if_empty(file_path,file_content = nil)    
     isCreate = create_file_and_fold_if_no_exit(file_path,file_content)
     if isCreate
       puts "【混淆】（初始化）存放地址 => #{file_path}"
     end
   end

   def self.confuse_content(defines = nil,name = confuse_name) 
    defines_content = defines.nil? ? '' : defines

    # 文件内容
    <<~EOS
    #ifndef #{name.tr('.', '_').upcase}
    #define #{name.tr('.', '_').upcase}
    #{defines_content}
    #endif
    EOS
   end


   def self.confuse_pch_content() 
    # 文件内容
    <<~EOS
    #ifndef #{confuse_pch_name.tr('.', '_').upcase}
    #define #{confuse_pch_name.tr('.', '_').upcase}
    #import "#{confuse_name}"
    #endif
    EOS
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

end