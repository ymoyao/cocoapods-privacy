require 'cocoapods-privacy/command'
require 'cocoapods-core/specification/dsl/attribute_support'
require 'cocoapods-core/specification/dsl/attribute'
require 'xcodeproj'

KSource_Files_Key = '.source_files'
KExclude_Files_Key = '.exclude_files'
KResource_Bundle_Key = '.resource_bundle'

class BBRow
  attr_accessor  :content, :is_comment, :is_spec_start, :is_spec_end, :key, :value

  def initialize(content, is_comment=false, is_spec_start=false, is_spec_end=false)
    @content = content
    @is_comment = is_comment
    @is_spec_start = is_spec_start
    @is_spec_end = is_spec_end

    parse_key_value
  end

  def parse_key_value
    # 在这里添加提取 key 和 value 的逻辑
    if @content.include?('=')
      key_value_split = @content.split('=')
      @key = key_value_split[0]
      @value = key_value_split[1..-1].join('=')
    else
      @key = nil
      @value = nil
    end
  end
end

class BBSpec
  attr_accessor :name, :alias_name, :full_name, :parent, :rows, :privacy_sources_files, :privacy_exclude_files, :privacy_file

  def initialize(name,alias_name,full_name)
    @rows = []
    @name = name
    @alias_name = alias_name
    @full_name = full_name
    @privacy_file = "Pod/Privacy/#{full_name}/PrivacyInfo.xcprivacy"
  end


  def uniq_full_name_in_parent(name)
    names = []
    @rows.each_with_index do |line, index|
      if line && line.is_a?(BBSpec)  
        names << line.name
      end
    end

    #判断names 中是否包含 name，如果包含，那么给name 添加一个 “.diff” 后缀，一直到names 中没有包含name为止
    while names.include?(name)
      name = "#{name}.diff"
    end

    "#{@full_name}.#{name}"
  end

  def privacy_handle(podspec_file_path)
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || !line.key || line.key.empty? 
        next
      end
       
      if !line.is_comment && line.key.include?(KResource_Bundle_Key)
        @has_resource_bundle = true
      elsif !line.is_comment && line.key.include?(KSource_Files_Key)
        @source_files_index = index
      end
    end
    create_privacy_file_if_need(podspec_file_path)
    modify_privacy_resource_bundle_if_need(podspec_file_path)
  end

  # 对应Spec新增隐私文件
  def create_privacy_file_if_need(podspec_file_path)
    if @source_files_index
      PrivacyUtils.create_privacy_if_empty(File.join(File.dirname(podspec_file_path), @privacy_file))
    end
  end

  # 这里处理所有多行参数的解析，目前处理 source_files\exclude_files\resource_bundle 这三种
  # 输入格式 ['.source_files':false,'.exclude_files':true......] => true 代表会根据获取的重置属性，需要把多行多余的进行删除
  # 返回格式 {'.source_files':BBRow,......}
  def fetch_mul_line_property(propertys_mul_line_hash)
    property_hash = {}
    line_processing = nil
    property_config_processing = nil
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || line.is_comment
        next
      end

      property_find = propertys_mul_line_hash.find { |key, _| line.key && line.key.include?(key) } #查找不到返回nil 查到返回数组，key， value 分别在第一和第二个参数
      if property_find
        property_config_processing = property_find 
      end

      if property_config_processing
        begin
          property_name = property_config_processing.first
          is_replace_line = property_config_processing.second
          if line_processing
            code = "#{line_processing.value}#{line.content}"
          else
            code = "#{line.value}"
          end

          # 清除 content 和 value, 后面会把所有的content 组装起来，多余的内容要清除，避免重复
          if is_replace_line
            line.content = ''
            line.value = nil
          end

          RubyVM::InstructionSequence.compile(code)
          property_value = eval(code)
        rescue SyntaxError, StandardError => e
          unless line_processing
            line_processing = line
          end
          line_processing.value = code if line_processing #存储当前残缺的value,和后面完整的进行拼接
          next
        end

        final_line = (line_processing ? line_processing : line)
        final_line.value = property_value
        property_hash[property_name] = final_line
        line_processing = nil
        property_config_processing = nil
      end
    end

    property_hash
  end

  # 处理字符串或者数组，使其全都转为数组，并转成实际文件夹地址
  def handle_string_or_array_files(podspec_file_path,line)
    value = line.value
    if value.is_a?(String) && !value.empty?
      array = [value]
    elsif value.is_a?(Array)
      array = value
    else
      array = []
    end
  
    files = array.map do |file_path|
      File.join(File.dirname(podspec_file_path), file_path.strip)
    end
    files
  end

  # 把新增的隐私文件 映射给 podspec  && 解析 privacy_sources_files && 解析 privacy_exclude_files
  def modify_privacy_resource_bundle_if_need(podspec_file_path)
    if @source_files_index
      privacy_resource_bundle = { "#{full_name}.privacy" => @privacy_file }

      # 这里处理所有多行参数的解析，目前处理 source_files\exclude_files\resource_bundle 这三种
      propertys_mul_line_hash = {}
      propertys_mul_line_hash[KSource_Files_Key] = false
      propertys_mul_line_hash[KExclude_Files_Key] = false
      if @has_resource_bundle
        propertys_mul_line_hash[KResource_Bundle_Key] = true #需要根据生成的重置属性
      else # 如果原先没有resource_bundle，需要单独加一行resource_bundle
        space = PrivacyUtils.count_spaces_before_first_character(rows[@source_files_index].content)
        line = "#{alias_name}.resource_bundle = #{privacy_resource_bundle}"
        line = PrivacyUtils.add_spaces_to_string(line,space)
        row = BBRow.new(line)
        @rows.insert(@source_files_index+1, row)
      end
      property_value_hash = fetch_mul_line_property(propertys_mul_line_hash)
      property_value_hash.each do |property, line|
        if property == KSource_Files_Key                 #处理 source_files
          @privacy_sources_files = handle_string_or_array_files(podspec_file_path,line)
        elsif property == KExclude_Files_Key             #处理 exclude_files
          @privacy_exclude_files = handle_string_or_array_files(podspec_file_path,line)
        elsif property == KResource_Bundle_Key           #处理 原有resource_bundle 合并隐私清单文件映射
          merged_resource_bundle = line.value.merge(privacy_resource_bundle)
          @resource_bundle = merged_resource_bundle
          line.value = merged_resource_bundle
          line.content = "#{line.key}= #{line.value}"
        end
      end
    end
  end
end


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
    puts "👇👇👇👇👇👇 Start analysis component privacy 👇👇👇👇👇👇"
    PrivacyLog.clean_result_log()
    privacy_hash = PrivacyModule.check(podspec_file_path)
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

  def self.check(podspec_file_path)
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
      privacy_hash = fetch_privacy_hash(combin_sepcs_and_rows,podspec_file_path).compact
      filtered_privacy_hash = privacy_hash.reject { |_, value| value.empty? }
      filtered_privacy_hash
  end

  private
  def self.read_podspec(file_path)
    File.readlines(file_path)
  end
  
  def self.parse_row(lines)
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
  def self.combin_sepc_if_need(rows,podspec_file_path) 
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

        spec = BBSpec.new(name,alias_name,full_name)
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
  def self.unfold_sepc_if_need(rows)
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


  def self.fetch_privacy_hash(rows,podspec_file_path)
    privacy_hash = {}
    specs = rows.select { |row| row.is_a?(BBSpec) }
    specs.each do |spec|
      value = spec.privacy_sources_files ? {KSource_Files_Key => spec.privacy_sources_files,KExclude_Files_Key => spec.privacy_exclude_files || []} : {}
      privacy_hash[File.join(File.dirname(podspec_file_path),spec.privacy_file)] = value
      privacy_hash.merge!(fetch_privacy_hash(spec.rows,podspec_file_path))
    end
    privacy_hash
  end

end
