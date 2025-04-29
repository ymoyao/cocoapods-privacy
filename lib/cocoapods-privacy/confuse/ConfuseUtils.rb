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

  def self.oc_func_regular(str,isCapture = false)
    if str =~ /^[-+]\s*\(.*?\)/ #为函数
      num = match_nesting_parentheses_first(str)
      if isBlockReturn(str) === true #block 返回参数函数
        if num > 1
          regular = oc_block_regular(num - 1,isCapture)
          regular = /(^[-+]#{regular}(\w+)\s*(.+))/
          return regular
        end
      else
        regular = oc_normal_regular(num - 1,isCapture)
        regular = /(^[-+]#{regular}(\w+)\s*(.+))/
        return regular
      end
    end
    return nil
  end

  def self.match_nesting_parentheses_first(str)
    stack = []
    count = 0
    
    str.each_char.with_index do |char, idx|
      if char == '('
        stack.push(idx)  # 记录左括号的位置
      elsif char == ')'
        count += 1
        stack.pop  # 弹出左括号位置
        if stack.empty?
          return count
        end
      end
    end
    0  # 如果没有匹配到指定数量的括号对，返回 nil
  end

  def self.isBlockReturn(str)
    if str =~ /^[-+]\s*\(([^)]*\^.+?)\)/      #block 返回参数函数
        return true
    else
        return false
    end
  end

  def self.oc_block_regular(num,isCapture = false)
    if isCapture == false
      "\\s*\\((?:[^\\)]+\\)){#{num}}.*?\\)\\s*"
    else
      "\\s*\\(((?:[^\\)]+\\)){#{num}}.*?)\\)\\s*"
    end
  end

  def self.oc_normal_regular(num,isCapture = false)
    if isCapture == false
      "\\s*\\(.*?\\)\\s*"
    else
      "\\s*\\((.*?)\\)\\s*"
    end
  end

end