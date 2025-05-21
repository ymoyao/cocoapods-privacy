require 'json'
require 'cocoapods-privacy/command'
require 'securerandom'
require 'active_support/core_ext/module/attribute_accessors'

##
#  功能介绍：
#  1、检索到的混淆内容转换成加密议格式写入 混淆文件
##
module Confuse
  class Hunter

      # 类变量，用于缓存版本号
      def initialize(version)
        @version = version
      end

      def search_need_confuse_apis(source_folders,exclude_folders=[])
        apis_define_map, swift_extension_funcBody_map = search_files(source_folders, exclude_folders)
        return apis_define_map, swift_extension_funcBody_map
      end

      def insert_encrypted_apis_to_confuse_header(apis_define_map,confuse_header_path,flag = "")
          # 存储已生成的随机字符串以确保唯一性
          generated_strings = {}

          # 生成 #define 语句
          defines = apis_define_map.map { |key, value|
            "   #define #{key} #{value}"
          }.join("\n")

          confuse_header_content = ConfuseUtils.confuse_content(defines,File.basename(confuse_header_path))
          puts "混淆(宏):\n 文件:#{confuse_header_path}\n 内容👇:\n#{confuse_header_content}"

          # 保存文件
          File.write(confuse_header_path, confuse_header_content)
      end

      def insert_encrypted_apis_to_confuse_swift(swift_extension_funcBody_map,swift_confuse_file_path,flag = "")
        # 存储已生成的随机字符串以确保唯一性
        generated_strings = {}

        # 生成 #define 语句
        funcs = swift_extension_funcBody_map.map { |key, values|
          func = "public extension #{key} {\n" + values.map { |value|
            value.split("\n").map { |line| "  #{line}" }.join("\n")  # 每行前加四个空格
          }.join("\n\n") + "\n}"
        }.join("\n\n")
        confuse_func_content = funcs
        puts "混淆(扩展):\n 文件:#{swift_confuse_file_path}\n 内容👇:\n#{confuse_func_content}"

        # # 保存文件
        File.write(swift_confuse_file_path, confuse_func_content)
      end

      private

      #  # 获取podspec的版本号，如果有缓存则返回缓存值
      # def self.get_version(podspec_file_path)
      #   # 如果已经缓存了版本号，直接返回缓存
      #   return @cached_version if @cached_version

      #   # 读取podspec文件
      #   podspec = Pod::Specification.from_file(podspec_file_path)
      #   version = podspec.version.to_s
      #   version = version.gsub('.', '_')  # Replace dots with underscores

      #   # 缓存版本号
      #   @cached_version = version
        
      #   return version
      # end

      def extend_version(str)
        return "#{str}_V#{@version}"
      end

      #💡💡💡以下是 invalid byte sequence in UTF-8 错误复现 的数据代码
      # File.write("/Users/xxx/.cache/cocoapods-privacy/privacy/file.txt", "vandflyver \xC5rhus \n
      
      # \n

      # \\n

      # vandflyver 
      # \xC5rhus
      # ")
      # 文件是否包含内容
      def extract_annotated_attributes?(file_path)

        #使用UTF-8 读取，无法读取的会被默认处理，修复 https://github.com/ymoyao/cocoapods-privacy/issues/7 
        file_content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace)

        #核心文件检查段落注释 /* */
        file_extension = File.extname(file_path).downcase
        need_check_paragraph_comment = ['.m', '.c', '.swift', '.mm', '.h', '.hap', '.hpp', '.cpp'].include?(file_extension)

        apis_define_map, swift_extension_funcBody_map = contains_apis_ignore_all_comment(file_content.lines,file_path)
        return apis_define_map, swift_extension_funcBody_map
      end

      def contains_apis_ignore_all_comment(lines,file_path) 
        apis_define_map = {}
        swift_extension_funcBody_map = {}

        #oc 暴露给swift 的扩展名称
        swift_extension = []

        # 段注释和单行注释标志
        in_block_comment = false
        in_line_comment = false

        # 是否可以触发注释标识，当为true 时可以触发 /*段注释 或者 //单行注释
        can_trigger_comments_flag = true

        # 统计计数器
        count_comments = 0
        modified = false

        last_line_scrub = ""
        need_delete_line_map = {} #{删除行下标:行内容line}
        encrypted_lines = lines.map.with_index do |line, line_index|

          line_scrub = line.scrub("")
          if line_scrub.strip.empty? #忽略空行
            next line
          end
          if line_scrub.strip.start_with?('//') && !in_block_comment  #忽略注释 // 和 /**/
            next line
          end

          chars = line_scrub.chars
          index = 0
          while index < chars.size
            char = chars[index]

            if char == '/'
              if chars[index + 1] == '*'
                # 检测到 /* 且can_trigger_comments_flag标识为true时，判定为进入 段注释
                if can_trigger_comments_flag 
                  in_line_comment = false #重置行标识
                  in_block_comment = true #标记正在段注释中
                  can_trigger_comments_flag = false #回收头部重置标识
                end

                #段注释每次 遇到 /* 都累加1
                if in_block_comment
                  count_comments += 1
                end

                #跳过当前 /* 两个字符
                index += 2
                next       
              end
            # 检测到段注释的end 标识 */
            elsif in_block_comment && char == '*' && chars[index + 1] == '/'

              #段注释每次 遇到 */ 都累减1
              count_comments -= 1

              #当/* */ 配对时，说明当前段注释结束了
              if count_comments == 0
                in_line_comment = false
                in_block_comment = false 
                can_trigger_comments_flag = true
              end

              #跳过当前 */ 两个字符
              index += 2
              next
            end

            # 其他情况，前进一个字符
            index += 1
          end

          if !in_block_comment && !in_line_comment

              ###----- 处理oc ------
              #### 检测BBConfuseOCToSwift("xxxx") 用来处理oc函数混淆暴露给swift
              line_scrub.scan(/^BBConfuseOCToSwift\(\"(.*?)\"\)/) do |match|
                  literals = match.first.split(',').map(&:strip)
                  unless literals.empty?
                    swift_extension = literals
                  end
              end

              ### 检测BBConfuseOCClass("xxxx") 用来处理oc 类混淆
              line_scrub.gsub!(/^BBConfuseOCClass\(\"(.*?)\"\)/) do |match|
                modified = true #开启编辑
                original_api = $1
                new_api = encrypted_api([original_api]).first
                puts "asasd = #{new_api} "
                "BBConfuseOCClass(\"#{new_api}\")"
              end


              #### 检测BBConfuseOCClass("xxxx") 用来处理oc 类混淆
              # line_scrub.scan(/^BBConfuseOCClass\(\"(.*?)\"\)/) do |match|
              #   puts "match = #{match}"
              #     apis = [match.first]
              #      puts "apis = #{apis}"
              #     new_parts = encrypted_api(apis)
              #     apis.each_with_index do |seg, index| 
              #       apis_define_map[seg.strip] = new_parts[index]
              #     end
              # end

              # @property (nonatomic, assign) BOOL coldLaunch BBConfuseOCProperty;
              #### 检测@protperty(xxxx)mmm *nnn BBConfuseOCProperty 用来处理oc 属性混淆
              line_scrub.scan(/^@property\s*\((.*?)\)\s*(\w+)\s*([\*&]?)\s*(\w+)\s*BBConfuseOCProperty/) do |match|
                puts "BBConfuseOCProperty = #{match}"
                is_nullable = match.first.include?("nullable") || match.first.include?("weak")
                return_type = match.second + match[2]
                property_name = match[3]
                apis = [property_name]
                new_parts = encrypted_api(apis)
         
                if !swift_extension.empty? && return_type && !return_type.empty?
                  swift_return_type = ConfuseUtils.convert_oc_type_to_swift(return_type)
                  swift_property_body = SwiftCallAssembly.assemblyProperty(property_name,new_parts.first,swift_return_type,is_nullable)

                  swift_extension.each do |extension|
                    swift_extension_funcBody_map[extension] ||= []
                    swift_extension_funcBody_map[extension].push(swift_property_body)
                  end
                end

                apis.each_with_index do |seg, index| 
                    apis_define_map[seg.strip] = new_parts[index]
                end
              end

              #### BBConfuseOCFunc 用来处理oc 函数混淆
              # ^	匹配行首	+ (BOOL)
              # [-+]	匹配 + 或 - 符号（ObjC 方法声明开头）	+
              # \s*	匹配 0 个或多个空白字符	空格
              # \([\w\s\*]+\)	匹配一对圆括号里的类型声明，含字母、空格、* 指针符	(BOOL) / (NSString *)
              # \s*	匹配 0 个或多个空白字符	空格
              # (\w+)	捕获组 1：匹配方法名（只匹配到冒号前）	uxxx_BB_Confuse_BBMUserCenter
              # \s*	匹配 0 个或多个空白字符	空格
              # (.*?)	捕获组 2：匹配“方法声明后到 __attribute__ 前的所有内容”，但用非贪婪方式，遇到 __attribute__ 就停	:(NSString *)name tip:(BOOL)ret
              # \s*__attribute__\(\(annotate\(	匹配固定字符串 __att
              regular = ConfuseUtils.oc_func_regular(line_scrub,false)
              if regular
                regular = /#{regular}\s*BBConfuseOCFunc/
                line_scrub.scan(regular) do |match|
                  apis = [match.second]
                  new_parts = encrypted_api(apis)
                  funcStr = match.first.sub(';','').sub(/BBConfuseOCFunc.*/, '')
                  is_nullable, return_type, swift_method_declaration ,params = ObjCMethodAPIConverter.convert(funcStr)

                  if !swift_extension.empty? && swift_method_declaration && !swift_method_declaration.empty?
                    swift_func_body = SwiftCallAssembly.assembly(new_parts.first, swift_method_declaration, params, is_nullable, return_type)

                    swift_extension.each do |extension|
                      swift_extension_funcBody_map[extension] ||= []
                      swift_extension_funcBody_map[extension].push(swift_func_body)
                    end
                  end

                  apis.each_with_index do |seg, index| 
                    apis_define_map[seg.strip] = new_parts[index]
                  end
                end
              end

              ###----- 处理swift 类 ------
              #正则解析:
              #1、@BBConfuseMixObjcClass\("	匹配 @BBConfuseMixObjcClass(" 这一部分	@BBConfuseMixObjcClass("MyClass"
              #2、([a-zA-Z][a-zA-Z0-9]*)	第一个参数：匹配 " 之后的 首字母必须是字母，后面可跟 字母或数字	"MyClass"
              #3、(?:,\s*"([a-zA-Z][a-zA-Z0-9]*)")?	第二个参数（可选）：如果有，匹配 , "SecondParam"	, "SecondParam"（可选）
              #4、\)	匹配 ") 结束 @BBConfuseMixObjcClass(...) 部分	")
              #5、(?:.*?@objc\((\S+)\))?	可选的 @objc(...)：如果存在，则匹配 @objc(...) 并提取内容	@objc(MyObjCName)（可选）
              #6、.*?class ([a-zA-Z0-9]+)	类名：匹配 class 关键字后面的类名	class MyClass
              #混淆之前的类解析(存在 @objc(xxx) 别名情况 ) 比如 @BBConfuseMixObjcClass("test") @objc(xxxx) public class abc : NSObject {
              confuse_class_pre_literal = "@BBConfuseMixObjcClass"
              line_scrub.gsub!(/#{confuse_class_pre_literal}\("([a-zA-Z][a-zA-Z0-9]*)"(?:,\s*"([a-zA-Z][a-zA-Z0-9]*)")?\)(?:.*?@objc\((\S+)\))?.*?class ([a-zA-Z0-9]+)/) do |match|
                #match = @BBConfuseMixObjcClass("test") @objc(xxxx) public class abc
                #S1 = test
                #S2 = xxxx
                #S3 = abc
                modified = true
                # puts "检测到混淆类标记 = #{match}"
                # puts "$1 = #{$1} $2 = #{$2} $3 = #{$3} $4 = #{$4}"
                origin_swift_class_name = $1
                origin_objc_class_name = $2 || ""
                current_objc_class_name = $3 || ""
                current_swift_class_name = $4
                is_to_objc = match.include?("@objc")

                encrypted_class_name = encrypted_api([origin_swift_class_name]).first
                confuse_literals = "#{confuse_class_pre_literal}"
                unless origin_objc_class_name.empty?
                  confuse_literals += "(\"#{origin_swift_class_name}\",\"#{origin_objc_class_name}\")"
                else
                  confuse_literals += "(\"#{origin_swift_class_name}\")"
                end

                class_literals = match
                .gsub(confuse_literals, "")
                .gsub(/@objc\([^)]*\)|@objc\s+/, "")
                .gsub(current_swift_class_name, encrypted_class_name)

                #检查上一行是否已经有public typealias origin_class_name = encrypted_class_name, 有的话先标记删除
                swift_typealias = "public typealias #{origin_swift_class_name}"
                if last_line_scrub.delete(" ").include?(swift_typealias.delete(" "))
                  need_delete_line_map[line_index - 1] = last_line_scrub
                end

                #有包含@objc 暴露给oc 才有宏定义的必要
                if is_to_objc
                  #添加origin_class_name 和 encrypted_class_name 给字典, 后续插入到宏定义中
                  apis_define_map[origin_swift_class_name] = encrypted_class_name unless origin_swift_class_name.empty?
                  apis_define_map[origin_objc_class_name] = encrypted_class_name unless origin_objc_class_name.empty?
                end

                objc_literals = is_to_objc ? " @objc(#{encrypted_class_name.strip}) " : " "
                retult = "#{swift_typealias.strip} = #{encrypted_class_name.strip}\n#{confuse_literals.strip}#{objc_literals}#{class_literals.strip}"
                retult
              end

              ###----- 处理swift 函数 ------
              confuse_func_pre_literal = "#BBConfuseMixObjcFunc"
              if line_scrub.strip.start_with?(confuse_func_pre_literal)
                #BBConfuseMixObjc("#selector(abcdefg(in:sencName:))"); asdasagwtrqwetr
      
                #selector(.*?)\)
                #解析带参数的
                # | 部分 | 作用 | 举例 |
                # |:-------------------------|:------------------------------------------------|:---------------------------------|
                # | `#{confuse_func_pre_literal}\(` | 匹配你之前定义好的前缀字串（比如 `confuseMethod(`）和一个 `(` | `confuseMethod(` |
                # | `(?:#selector\((.*?)\)\))?` | **非捕获组**，匹配 `#selector(XXX)`，括号内的 `XXX` 放进 `捕获组1` | `#selector(someMethod)` |
                # | `(?:"([^"]*:[^"]*)")?` | **可选**，匹配 `:"xxx:xxx"` 格式的字符串，放进 `捕获组2` | `"abc:def"` |
                # | `\);` | 匹配 `);` |
                # | `(?:.*?@objc\((\S+)\))?` | **非捕获组**，可选，匹配 `@objc(XXX)`，把 `XXX` 放进 `捕获组3` | `@objc(mySelector)` |
                # | `(?:.*?@objc\s*)?` | **非捕获组**，可选，匹配剩下一个 `@objc` 没括号的情况 | `@objc` |

                line_scrub.gsub!(/#{confuse_func_pre_literal}\((?:#selector\((.*?)\)\))?(?:"([^"]*:[^"]*)")?\);(?:.*?@objc\((\S+)\))?(?:.*?@objc\s*)?/) do |match|
                  modified = true
                  selector_match = $1
                  str_match = $2
                  # puts "检测到混淆函数标记(带参数) = #{match};$1 = #{$1} $2 = #{$2} $3 = #{$3}"
                  is_selector = selector_match && !selector_match.empty?
                  if is_selector
                    apis = handleObjcInsert(match,selector_match,line)
                  else
                    apis = str_match.split(':').map(&:strip)
                  end
                  result,apis_define_map_temp = encrypted_and_combination_api(apis,match)
                  apis_define_map = apis_define_map.merge(apis_define_map_temp)
                  result
                end

                #解析不带参数的
                # | 部分 | 作用 | 举例 |
                # |:-------------------------------|:--------------------------------------------------|:--------------------------|
                # | `#{confuse_func_pre_literal}\(` | 匹配你的宏/方法名前缀 + `(`，比如 `confuseMethod(` | `confuseMethod(` |
                # | `(?:#selector\(([^\(]+)\))?` | **非捕获组**，可选。匹配 `#selector(...)` 里的内容，放进 `捕获组1`，这里用 `([^\(]+)` 匹配**非左括号字符**，直到遇到 `)` | `#selector(doSomething)` → `doSomething` |
                # | `(?:"([^":]+)")?` | **可选**，匹配 `"xxx"`，但里面不能有 `:` 或 `"`，放进 `捕获组2`。注意这版里不再要求冒号存在，单纯匹配一段字符串 | `"helloWorld"` |
                # | `\);` | 匹配 `);` 结尾 |
                # | `(?:.*?@objc\((\S+)\))?` | **非捕获组**，可选。匹配 `@objc(XXX)`，把 `XXX` 放进 `捕获组3`。`(\S+)` 匹配非空白连续字符 | `@objc(doSomethingElse)` |
                # | `(?:.*?@objc\s*)?` | **非捕获组**，可选。匹配剩下没括号的 `@objc` | `@objc` |
                line_scrub.gsub!(/#{confuse_func_pre_literal}\((?:#selector\(([^\(]+)\))?(?:"([^":]+)")?\);(?:.*?@objc\((\S+)\))?(?:.*?@objc\s*)?/) do |match|
                  modified = true
                  selector_match = $1
                  str_match = $2
                  # puts "检测到混淆函数标记(无参数) = #{match};$1 = #{$1} $2 = #{$2} $3 = #{$3}"
                  is_selector = selector_match && !selector_match.empty?
                  apis = []
                  if is_selector
                    apis = handleObjcInsert(match,selector_match,line)
                  else
                    apis = str_match.split(':').map(&:strip) if str_match
                  end
                  result,apis_define_map_temp = encrypted_and_combination_api(apis,match)
                  apis_define_map = apis_define_map.merge(apis_define_map_temp)
                  result
                end
              end
              # puts "line_scrub = #{line_scrub}"
          end

          #每行结束时，重置行标识
          in_line_comment = false
          last_line_scrub = line_scrub
          line_scrub
        end
        # 写回修改后的文件
        if modified
          encrypted_lines = encrypted_lines.each_with_index.reject { |_, index| need_delete_line_map.keys.include?(index) }.map(&:first)

          File.write(file_path, encrypted_lines.join)
          # puts "已混淆文件：#{file_path}"
          # File.open('/Users/masterfly/Desktop/babybusGit/common/SafetyProtection/Pod/Classes/ReplaceMe.swift', 'w') do |file|
          #   # 逐行写入 rows
          #   lines.each do |row|
          #       file.puts(row)
          #       puts "插入：#{row}"
          #   end
          # end
          puts "已混淆文件：#{file_path}"
        end
        return apis_define_map, swift_extension_funcBody_map
      end


      def handleObjcInsert(match, suffix,line)

        #match = #BBConfuseMixObjcFunc(#selector(swiftTestPar(in:sencName:))); @objc(blbbYmRPLbOb:etMLJynbSjJy:)
        #suffix = swiftTestPar(in:sencName:

        #第一步, 使用;分割,获取关键信息  #BBConfuseMixObjcFunc(#selector(swiftTestPar(in:sencName:)))
        literals = match.split(';').map(&:strip)
        confuse_literals = literals.first
        func_literals = literals[1]

        #“swiftTestPar(in:sencName:” --》 [“swiftTestPar,“in:sencName:”]
        sepFunc = suffix.split('(').map(&:strip)

        funcName = sepFunc
        paramSplit = []
        if sepFunc.length > 0
          #““swiftTestPar”
          funcName = sepFunc.first

          #in:sencName:
          params = sepFunc[1]

          #in:sencName: --> ["in","sencName"]
          if params
            paramSplit = params.split(':')

            #特殊情况处理 
            #首个参数为 _ 则个参数返回空
            # 其他参数使用With + 参数首字符大写
            paramSplit = paramSplit.map.with_index do |seg, index|
              if index == 0 && seg == "_"
                ""
              elsif index == 0
                "With#{seg.capitalize}"
              else
                seg
              end
            end

            funcName = funcName + paramSplit.first
            paramSplit.slice!(0)
          end
        end

        apis = [funcName] + paramSplit
        return apis
      end

      def encrypted_and_combination_api(apis,match)
        new_parts = encrypted_api(apis)

        # 构建新注解内容
        new_annotation = "#{new_parts.join(':')}"
        if match.include?(":")
          new_annotation = "#{new_annotation}:"
        end

        apis_define_map = {}
        # 将未混淆的 API 名称及其对应的混淆字符串添加到字典中
        # apis.each_with_index do |seg, index|
        #   apis_define_map[seg.strip] = new_parts[index]
        # end

        #仅混淆函数名称, 参数可能太过简单,宏定义有风险
        apis_define_map[apis.first] = new_parts.first if apis && !apis.empty?

        result = match.gsub(";","").gsub(/@objc\([^)]*\)|@objc\s+/, "")  # 删除分号 和多余的 @objc           
        result = "#{result.strip}; @objc(#{new_annotation})"  # 添加新的注解
        # puts "result = #{result}"
        return result, apis_define_map
      end


      #搜索所有子文件夹
      def search_files(folder_paths, exclude_folders)
        # 获取文件夹下所有文件（包括子文件夹）
        all_files = []
        folder_paths.each do |folder|
          # 不再做额外格式过滤，避免和podspec中source_files 自带的格式冲突
          # allowed_extensions = ['m', 'c', 'swift', 'mm', 'hap', 'cpp']
          # pattern = File.join(folder, '**', '*.{'+allowed_extensions.join(',')+'}')
          # all_files += Dir.glob(pattern, File::FNM_DOTMATCH).reject { |file| File.directory?(file) }

          # 使用 Dir.glob 方法直接获取符合条件的文件路径
          files_in_folder = Dir.glob(folder, File::FNM_DOTMATCH)
          
          # 过滤掉目录路径，只保留文件路径，并将其添加到 all_files 数组中
          all_files += files_in_folder.reject { |file| File.directory?(file) }
        end

        # 获取需要排除的文件
        exclude_files = []
        exclude_folders.each do |folder|
          files_in_folder = Dir.glob(folder, File::FNM_DOTMATCH)
          exclude_files += files_in_folder.reject { |file| File.directory?(file) }
        end

        # 剔除掉需要排除的文件
        all_files = all_files.uniq - exclude_files.uniq

        # 遍历文件进行检索
        $apis_define_map = {}
        $swift_extension_funcBody_map = {}

        all_files.each_with_index do |file_path, index|
          api_dict, funcBody_map = extract_annotated_attributes?(file_path)
          $apis_define_map.merge!(api_dict)
          funcBody_map.each do |key, value|
            if $swift_extension_funcBody_map.key?(key)
              # 如果 key 存在于 $swift_extension_funcBody_map 中，合并并去重
              $swift_extension_funcBody_map[key] = (Array($swift_extension_funcBody_map[key]) + Array(value)).uniq
            else
              # 如果 key 不存在，直接添加
              $swift_extension_funcBody_map[key] = value
            end
          end
        end

        # 用 apis_define_map 中对应的 value，更新 swift_extension_funcBody_map 中相同 key 的 key, 避免AClass同时定义了类混淆且暴露给swift, swift 扩展使用原先未混淆的类的问题
        # update_func_body_map_keys!($apis_define_map, $swift_extension_funcBody_map)

        return $apis_define_map, $swift_extension_funcBody_map
      end

      # 用 apis_define_map 中对应的 value，更新 swift_extension_funcBody_map 中相同 key 的 key, 避免AClass同时定义了类混淆且暴露给swift, swift 扩展使用原先未混淆的类的问题
      def update_func_body_map_keys!(apis_define_map, swift_extension_funcBody_map)
        new_map = {}

        swift_extension_funcBody_map.each do |key, value|
          if apis_define_map.has_key?(key)
            confuse_value = apis_define_map[key]
            new_key = confuse_value
            new_map[new_key] = value
          else
            new_map[key] = value
          end
        end

        swift_extension_funcBody_map.replace(new_map)
      end


      def encrypted_api(apis)
          encrypted_api = ""
          # 生成 #define 语句
          defines = apis.map do |api|
            if $apis_define_map.key?(api)
              encrypted_api = $apis_define_map[api]
            else
              encrypted_api = generate_safe_api_key()
            end
          end
          defines
      end

      def generate_safe_api_key
        #需要排除这些连接词,如果有这些连接词,那么转swift时函数会被分割
        forbidden_words = %w[
          With In On To At As Of By For After Before During Alongside Under Through
        ]
      
        loop do
          encrypted_api = SecureRandom.alphanumeric(24)
          encrypted_api = encrypted_api.strip
          encrypted_api = encrypted_api.gsub(/\d/, 'b')
          encrypted_api = encrypted_api.sub(/^./, encrypted_api[0].downcase)
          encrypted_api = extend_version(encrypted_api)
      
          # 检查是否包含禁用词
          contains_forbidden = forbidden_words.any? { |word| encrypted_api.include?(word) }
      
          # 一直循环直到不包含关键词
          return encrypted_api unless contains_forbidden
        end
      end
  end
end
