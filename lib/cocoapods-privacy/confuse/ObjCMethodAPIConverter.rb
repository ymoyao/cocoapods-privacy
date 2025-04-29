
module Confuse
  class ObjCMethodAPIConverter
      # Regular expression to match Objective-C method declarations
      # def initialize
        @regex = /^[+-]\s*\(\s*([\w\s*]+)\s*\**\s*\)\s*(.+)/
        @param_regex = /(\w+):\s*\(([^:]+)\)(\w+)/x
      # end
    
      # Convert an Objective-C method declaration to a Swift method declaration
      def self.convert(objc_method_declaration)
        # puts "objc_method_declaration = #{objc_method_declaration}"
        # Skip methods containing blocks
    #    return nil if objc_method_declaration.include?("^")
    
        is_static = objc_method_declaration.start_with?("+")
        preFuncDes = is_static ? "static " : ""
    
    
        # Match the method declaration using the regex
        matches = objc_method_declaration.match(@regex)
        return nil,nil unless matches

        # Extract components from the matched regex groups
        return_type = matches[1] || "Void"
        param_section = matches[2] || ""
        method_name = matches[2]
        # puts  "return_type = #{return_type}"
        # puts  "param_section = #{param_section}"
        # puts "method_name = #{method_name}"

        # Convert return type to Swift equivalent
        return_type = convert_oc_type_to_swift(return_type)
    
        # Extract parameters from the method declaration
        params = extract_parameters(param_section)
        method_name = extract_methodName(param_section,method_name)
        # puts "params = #{params}"
    
        # Construct the Swift method declaration
        swift_method_declaration = "#{preFuncDes}public func #{method_name}(#{params.join(', ')})"
        swift_method_declaration += " -> #{return_type}" unless return_type == "Void"
        
        return swift_method_declaration, extract_parameter_names(param_section)
      end
    
      private
    
      # Convert the Objective-C return type to a Swift type
      def self.convert_oc_type_to_swift(return_type)
        # 去除类型末尾的指针符号和周围空格，生成基础类型名
        # base_type = return_type.gsub(/\s*\*+$/, '').strip
        base_type = return_type.gsub(/(\w+)\s*\*+\z/, '\1').strip
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
        when "id"                          then "Any"
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
          if return_type.match(/^\s*(?:void|.+?)\s*\(\^\)/)
            convert_block_to_closure(return_type)
          # 处理其他指针类型（去掉指针符号后返回基础类型名）
          elsif return_type.include?('*')
            base_type
          else
            # 默认保留原类型
            return_type
          end
        end
      end
    
      # Extract parameters from the parameter section
      def self.extract_parameters(param_section)
        params = []
        param_section.scan(@param_regex).each_with_index do |param_info, index|
        #  puts "param_info = #{param_info}"
          param_define, param_type, param_name = param_info
          param_type = convert_oc_type_to_swift(param_type.strip)
          if index == 0
            params << "#{param_name}: #{param_type}"
          else
            params << "#{param_define}: #{param_type}"
          end
        end
        params
      end
      
      def self.extract_parameter_names(param_section)
        names = []
        param_section.scan(@param_regex).each_with_index do |param_info, index|
          param_define, param_type, param_name = param_info
          if index == 0
            names << param_name
          else
            names << param_define
          end
        end
        names
      end
      
      
      def self.extract_methodName(param_section, defalut_method_name)
        method_name = defalut_method_name
        param_section.scan(@param_regex).each_with_index do |param_info, index|
          param_define, param_type, param_name = param_info
          if index == 0
              method_name = param_define
              break
          end
        end
        method_name.strip
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
end
  