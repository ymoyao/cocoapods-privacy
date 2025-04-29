require 'cocoapods-privacy/command'

module BB
    class BBSpecManager
        def initialize(type)
            @type = type
        end


        def check(podspec_file_path)
            # Step 1: 读取podspec
            lines = read_podspec(podspec_file_path)
            
            # Step 2: 逐行解析并转位BBRow 模型
            rows = parse_row(lines)

            # Step 3.1:如果Row 是属于Spec 内，那么聚拢成BBSpec，
            # Step 3.2:BBSpec 内使用数组存储其Spec 内的行
            # Step 3.3 在合适位置给每个有效的spec都创建一个 隐私模版，并修改其podspec 引用
            combin_sepcs_and_rows = combin_sepc_if_need(rows,podspec_file_path)

            # Step 4: 展开修改后的Spec,重新转换成 BBRow
            rows = unfold_sepc_if_need(combin_sepcs_and_rows)

            # Step 5: 打开隐私模版，并修改其podspec文件，并逐行写入
            File.open(podspec_file_path, 'w') do |file|
            # 逐行写入 rows
            rows.each do |row|
                file.puts(row.content)
            end
            end

        
            # Step 6: 获取privacy 相关信息，传递给后续处理
            hash = fetch_hash(combin_sepcs_and_rows,podspec_file_path).compact
            filtered_hash = hash.reject { |_, value| value.empty? }
            filtered_hash
        end


        def read_podspec(file_path)
            # puts "read_podspec = #{file_path}"
            File.readlines(file_path)
        end
        
        def parse_row(lines)
            rows = []  
            code_stack = [] #栈，用来排除if end 等对spec 的干扰
        
            lines.each do |line|
            content = line.strip
            is_comment = content.start_with?('#')
            is_spec_start = !is_comment && (content.include?('Pod::Spec.new') || content.include?('.subspec'))
            is_if = !is_comment && content.start_with?('if')  
            is_end = !is_comment && content.start_with?('end')
        
            # 排除if end 对spec_end 的干扰
            code_stack.push('spec') if is_spec_start 
            code_stack.push('if') if is_if 
            stack_last = code_stack.last 
            is_spec_end = is_end && stack_last && stack_last == 'spec'
            is_if_end = is_end && stack_last && stack_last == 'if'
            code_stack.pop if is_spec_end || is_if_end
        
            row = BBRow.new(line, is_comment, is_spec_start, is_spec_end)
            rows << row
            end
            rows
        end
        
        # 数据格式：
        # [
        #   BBRow
        #   BBRow
        #   BBSpec
        #     rows
        #         [
        #            BBRow
        #            BBSpec 
        #            BBRow
        #            BBRow
        #         ] 
        #   BBRow
        #   ......  
        # ]
        # 合并Row -> Spec（会存在部分行不在Spec中：Spec new 之前的注释）
        def combin_sepc_if_need(rows,podspec_file_path) 
            spec_stack = []
            result_rows = []
            default_name = File.basename(podspec_file_path, File.extname(podspec_file_path))
        
            rows.each do |row|
            if row.is_spec_start 
                # 获取父spec
                parent_spec = spec_stack.last 
        
                # 创建 spec
                name = row.content.split("'")[1]&.strip || default_name
                alias_name = row.content.split("|")[1]&.strip
                full_name = parent_spec ? parent_spec.uniq_full_name_in_parent(name) : name
        
                spec = BBSpec.new(name,alias_name,full_name,@type)
                spec.rows << row
                spec.parent = parent_spec
        
                # 当存在 spec 时，存储在 spec.rows 中；不存在时，直接存储在外层
                (parent_spec ? parent_spec.rows : result_rows ) << spec
        
                # spec 入栈
                spec_stack.push(spec)
            elsif row.is_spec_end
                # 当前 spec 的 rows 加入当前行
                spec_stack.last&.rows << row
        
                #执行隐私协议修改
                spec_stack.last.privacy_handle(podspec_file_path)
        
                # spec 出栈
                spec_stack.pop
            else
                # 当存在 spec 时，存储在 spec.rows 中；不存在时，直接存储在外层
                (spec_stack.empty? ? result_rows : spec_stack.last.rows) << row
            end
            end
        
            result_rows
        end
        
        # 把所有的spec中的rows 全部展开，拼接成一级数组【BBRow】
        def unfold_sepc_if_need(rows)
            result_rows = []
            rows.each do |row|
            if row.is_a?(BBSpec) 
                result_rows += unfold_sepc_if_need(row.rows)
            else
                result_rows << row
            end
            end
            result_rows
        end
        
        
        def fetch_hash(rows,podspec_file_path)
            hash = {}
            specs = rows.select { |row| row.is_a?(BBSpec) }
            specs.each do |spec|
                value = spec.sources_files ? {KSource_Files_Key => spec.sources_files,KExclude_Files_Key => spec.exclude_files || []} : {}
                if is_handle_privacy
                    hash[File.join(File.dirname(podspec_file_path),spec.privacy_file)] = value
                elsif is_handle_confuse
                    hash[File.join(File.dirname(podspec_file_path),spec.confuse_file)] = value
                end
                hash.merge!(fetch_hash(spec.rows,podspec_file_path))
            end
            hash
        end

        def is_handle_privacy
            @type.include?(KSpecTypePrivacy)
          end
        
        def is_handle_confuse
            @type.include?(KSpecTypeConfuse)
        end
    end
end