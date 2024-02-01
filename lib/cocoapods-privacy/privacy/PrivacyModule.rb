require 'cocoapods-privacy/command'
require 'cocoapods-core/specification/dsl/attribute_support'
require 'cocoapods-core/specification/dsl/attribute'
require 'xcodeproj'

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
  attr_accessor :name, :alias_name, :full_name, :parent, :rows, :privacy_sources, :privacy_file

  def initialize(name,alias_name,full_name)
    @rows = []
    @privacy_sources = nil
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
    source_files_index = 1
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || !line.key || line.key.empty? 
        next
      end
       
      if !line.is_comment && line.key.include?(".resource_bundle")
        @has_resource_bundle = true
      elsif !line.is_comment && line.key.include?(".source_files")
        spec = eval("Pod::Spec.new do |s|; s.source_files = #{line.value}; end;")
        if spec && !spec.attributes_hash['source_files'].nil?
          source_files_value = spec.attributes_hash['source_files']
          if source_files_value.is_a?(String) && !source_files_value.empty?
            source_files_array = [source_files_value]
          elsif source_files_value.is_a?(Array)
            # 如果已经是数组，直接使用
            source_files_array = source_files_value
          else
            # 其他情况，默认为空数组
            source_files_array = []
          end
        
          source_files_index = index
          @privacy_sources = source_files_array.map do |file_path|
            File.join(File.dirname(podspec_file_path), file_path.strip)
          end
        end
      end
    end
    create_privacy_file_if_need(podspec_file_path)
    modify_privacy_resource_bundle_if_need(source_files_index)
  end

  # 对应Spec新增隐私文件
  def create_privacy_file_if_need(podspec_file_path)
    if @privacy_sources
      PrivacyUtils.create_privacy_if_empty(File.join(File.dirname(podspec_file_path), @privacy_file))
    end
  end

  # 把新增的隐私文件 映射给 podspec
  def modify_privacy_resource_bundle_if_need(source_files_index)
    if @privacy_sources
      privacy_resource_bundle = { "#{full_name}.privacy" => @privacy_file }
      if @has_resource_bundle
        @rows.each_with_index do |line, index|
          if !line || line.is_a?(BBSpec) || !line.key || line.key.empty? 
            next
          end

          if !line.is_comment && line.key.include?(".resource_bundle")
            origin_resource_bundle = eval(line.value)
            merged_resource_bundle = origin_resource_bundle.merge(privacy_resource_bundle)

            @resource_bundle = merged_resource_bundle
            line.value = merged_resource_bundle
            line.content = "#{line.key}= #{line.value}"
          end
        end
      else
        space = PrivacyUtils.count_spaces_before_first_character(rows[source_files_index].content)
        line = "#{alias_name}.resource_bundle = #{privacy_resource_bundle}"
        line = PrivacyUtils.add_spaces_to_string(line,space)
        row = BBRow.new(line)
        @rows.insert(source_files_index+1, row)
      end
    end
  end
end


module PrivacyModule

  public

  # 处理工程
  def self.load_project(folds)
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
    resources_group = PrivacyUtils.find_group_by_path(main_group,resources_folder_path)
    if resources_group.nil?
      resources_group = main_group.new_group('Resources',resources_folder_path)
    end

    # 如果不存在引用，创建新的引入xcode引用
    if resources_group.find_file_by_path(PrivacyUtils.privacy_name).nil?
      resources_group.new_reference(PrivacyUtils.privacy_name)
      # resources_group.new_file(privacy_file_path)
    end
    
    project.save

    # 开始检索api,并返回json 字符串数据
    json_data = PrivacyHunter.search_pricacy_apis(folds)

    # 将数据写入隐私清单文件
    PrivacyHunter.write_to_privacy(json_data,privacy_file_path)
  end

  # 处理组件
  def self.load_module(podspec_file_path)
    privacy_hash = PrivacyModule.check(podspec_file_path)
    privacy_hash.each do |privacy_file_path, source_files|
      data = PrivacyHunter.search_pricacy_apis(source_files)
      PrivacyHunter.write_to_privacy(data,privacy_file_path) unless data.empty?
    end
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
    filtered_rows = rows.select { |row| row.is_a?(BBSpec) }
    filtered_rows.each do |spec|
      privacy_hash[File.join(File.dirname(podspec_file_path),spec.privacy_file)] = spec.privacy_sources
      privacy_hash.merge!(fetch_privacy_hash(spec.rows,podspec_file_path))
    end
    privacy_hash
  end

end
