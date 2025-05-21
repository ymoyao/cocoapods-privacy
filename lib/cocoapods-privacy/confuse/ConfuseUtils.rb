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

  # Convert the Objective-C return type to a Swift type
  def self.convert_oc_type_to_swift(return_type)
    # 去除类型额外的修饰
    is_nullable = (return_type =~ /\b(__nullable|nullable|_Nullable)\b/)
    clean_type = return_type.gsub(/\b(__nullable|nullable|_Nullable|__nonnull|nonnull|_Nonnull)\b/, '').strip
    # 去除类型末尾的指针符号和周围空格，生成基础类型名
    base_type = clean_type.gsub(/(\w+)\s*\*+\z/, '\1').strip
       
    # base_type = return_type
    # puts  "base_type = #{return_type}"

    case base_type
    # Foundation 基础类型
    when "NSString"                    then "String"
    when "NSMutableString"             then "String" # Swift 中 String 是值类型
    when "NSArray"                     then "Array<Any>"
    when "NSMutableArray"              then "Array<Any>"
    when "NSSet"                       then "Set<Any>"
    when "NSMutableSet"                then "Set<Any>"
    when "NSDictionary"                then "Dictionary<AnyHashable, Any>"
    when "NSMutableDictionary"         then "Dictionary<AnyHashable, Any>"
    when "NSError"                     then "Error?"
    when "NSURL"                       then "URL"
    when "NSData"                      then "Data"
    when "NSNumber"                    then "NSNumber" # 特殊处理需要结合实际数值类型
    when "NSDate"                      then "Date"
    
    # 基础数值类型
    when "NSInteger"                   then "Int"
    when "NSUInteger"                  then "UInt"
    when "CGFloat"                     then "CGFloat"
    when "CGPoint"                     then "CGPoint"
    when "CGRect"                      then "CGRect"
    when "CGSize"                      then "CGSize"
    when "BOOL"                        then "Bool"
    when "Boolean"                     then "Bool"
    when "double"                      then "Double"
    when "float"                       then "Float"
    when "long"                        then "Int"
    when "long long"                   then "Int64"


    # 特殊类型
    when "id"                          then "AnyObject"
    when "Class"                       then "AnyClass"
    when "SEL"                         then "Selector"
    when "Protocol"                    then "Protocol"
    when "instancetype"                then "Self"
    when "void"                        then "Void"
  
    # # # 函数指针/Block 类型（需二次处理）
    # when /void\s*\(\^\)/               then convert_block_to_closure(return_type)
    # when /(.+?)\s*\(\^\)/              then convert_block_to_closure(return_type)
    
    # # 指针类型保留原始表示
    # when /(.+?\s*\*+)/                 then return_type
    
    else
      # # 处理Block类型
      if clean_type.match(/^\s*(?:void|.+?)\s*\(\^\)/)
        convert_block_to_closure(clean_type)
      # 处理自定义的block
      elsif clean_type =~ /(.*?[B|b]lock$)/
        if is_nullable
          "#{clean_type}?"
        else
          "@escaping #{clean_type}"
        end
      # 处理其他指针类型（去掉指针符号后返回基础类型名）
      elsif clean_type.include?('*')
        base_type
      else
        # 默认保留原类型
        clean_type
      end
    end
  end

  #  # 测试用例
  #  puts convert_block_to_closure('void (^)()')                # 输出: () -> Void
  #  puts convert_block_to_closure('NSInteger (^)(BOOL)')       # 输出: (Bool) -> Int
  #  puts convert_block_to_closure('NSString *(^)(NSInteger)')  # 输出: (Int) -> String?
  #  puts convert_block_to_closure('void (^)(NSInteger, BOOL)') # 输出: (Int, Bool) -> Void
  def self.convert_block_to_closure(block_signature)
    # 正则表达式解释：
    # ^([\w\s\*]+)\s*\(\^\)\s*(?:\((.*?)\))?\s*$
    # 1. ([\w\s\*]+): 捕获返回值类型（如 void、NSInteger、NSString * 等）。
    # 2. \(\^\): 匹配 '^' 表示这是一个 block。
    # 3. (?:\((.*?)\))? : 可选地捕获参数列表（括号中的内容）。
    if block_signature =~ /^([\w\s\*]+)\s*\(\^\)\s*(?:\((.*?)\))?\s*$/
      return_type = $1.strip
      params = $2 ? $2.split(',').map(&:strip) : []
      
      # 转换返回值类型
      swift_return_type = convert_oc_type_to_swift(return_type)

      # 转换参数类型
      swift_params = params.map do |param|
        param_parts = param.split(' ')
        param_type =convert_oc_type_to_swift(param_parts.first)
        "#{param_type}"
      end.join(", ").gsub("Void","")

      # 构造最终的 Swift 闭包类型
      result = "@escaping (#{swift_params}) -> #{swift_return_type}"
    else
      raise ArgumentError, "Invalid block signature: #{block_signature}"
    end
  end

end