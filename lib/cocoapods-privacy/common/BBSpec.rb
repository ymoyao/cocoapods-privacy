require 'cocoapods-privacy/command'

KSpecTypePrivacy = 'bb_privacy'
KSpecTypeConfuse = 'bb_confuse' 


KSource_Files_Key = 'source_files' #不存在单数 source_file
KExclude_Files_Key = 'exclude_files' #不存在单数 exclude_file
KResource_Bundle_Key = 'resource_bundle' #resource_bundle 和 resource_bundles 这两个参数本质上是一样的，resource_bundle 也能指向多个参数

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
  attr_accessor :name, :alias_name, :full_name, :parent, :rows, :sources_files, :exclude_files, :type, :privacy_file, :confuse_file

  def initialize(name,alias_name,full_name,type)
    @rows = []
    @name = name
    @alias_name = alias_name
    @full_name = full_name
    @type = type
    @privacy_file = "Pod/Privacy/#{full_name}/PrivacyInfo.xcprivacy"
    confuse_file_name = @full_name.tr('.','_')
    @confuse_file = "Pod/Confuse/#{full_name}/#{confuse_file_name}_Confuse"
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

  # 单独属性转成spec字符串，方便解析
  def assemble_single_property_to_complex(property_name)
    property_name += "s" if property_name == KResource_Bundle_Key #检测到单数resource_bundle,直接转成复数，功能一致
    property_name
  end

  def privacy_handle(podspec_file_path)
    @rows.each_with_index do |line, index|
      if !line || line.is_a?(BBSpec) || !line.key || line.key.empty? 
        next
      end
       
      if !line.is_comment && line.key.include?("." + KResource_Bundle_Key)
        @has_resource_bundle = true
      elsif !line.is_comment && line.key.include?("." + KSource_Files_Key)
        @source_files_index = index
      end
    end
    create_file_if_need(podspec_file_path)
    modify_resource_bundle_if_need(podspec_file_path)
  end

  # 对应Spec新增隐私文件
  def create_file_if_need(podspec_file_path)
    if @source_files_index
      if is_handle_privacy
        PrivacyUtils.create_privacy_if_empty(File.join(File.dirname(podspec_file_path), @privacy_file))
      elsif is_handle_confuse
        ConfuseUtils.create_confuse_if_empty(File.join(File.dirname(podspec_file_path), "#{@confuse_file}.h"))
        ConfuseUtils.create_confuse_if_empty(File.join(File.dirname(podspec_file_path), "#{@confuse_file}.swift"))
      end
    end
  end

  def is_handle_privacy
    @type.include?(KSpecTypePrivacy)
  end

  def is_handle_confuse
    @type.include?(KSpecTypeConfuse)
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

          property_name_complex = assemble_single_property_to_complex(property_name)
          spec_str = "Pod::Spec.new do |s|; s.#{property_name_complex} = #{code}; end;"
          RubyVM::InstructionSequence.compile(spec_str)
          spec = eval(spec_str)
          property_value = spec.attributes_hash[property_name_complex]
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
    array = fetch_string_or_array_files(podspec_file_path,line)
  
    files = array.map do |file_path|
      File.join(File.dirname(podspec_file_path), file_path.strip)
    end
    files
  end

  def fetch_string_or_array_files(podspec_file_path,line)
    value = line.value
    if value.is_a?(String) && !value.empty?
      array = [value]
    elsif value.is_a?(Array)
      array = value
    else
      array = []
    end
    array
  end

  # 把新增的隐私文件 映射给 podspec  && 解析 sources_files && 解析 exclude_files
  def modify_resource_bundle_if_need(podspec_file_path)
    if @source_files_index

      # 这里处理所有多行参数的解析，目前处理 source_files\exclude_files\resource_bundle 这三种
      propertys_mul_line_hash = {}
      propertys_mul_line_hash[KSource_Files_Key] = false
      propertys_mul_line_hash[KExclude_Files_Key] = false
      propertys_mul_line_hash[KResource_Bundle_Key] = false 

      property_value_hash = fetch_mul_line_property(propertys_mul_line_hash)
      property_value_hash.each do |property, line|
        if property == KSource_Files_Key                 #处理 source_files
          @sources_files = handle_string_or_array_files(podspec_file_path,line)
          # puts "originSource = #{sources_files}"
          if is_handle_confuse
            source_array = fetch_string_or_array_files(podspec_file_path,line)
            source_array.push("#{@confuse_file}.{h,swift}")
            line.value = source_array.uniq
            line.content = "#{line.key}= #{line.value}"
          end
        elsif property == KExclude_Files_Key             #处理 exclude_files
          @exclude_files = handle_string_or_array_files(podspec_file_path,line)
        elsif property == KResource_Bundle_Key           #处理 原有resource_bundle 合并隐私清单文件映射
          # 仅在隐私清单时才去解析 resource_bundle
          privacy_resource_bundle = { "#{full_name}.privacy" => @privacy_file }
          if is_handle_privacy
            if @has_resource_bundle
              merged_resource_bundle = line.value.merge(privacy_resource_bundle)
              @resource_bundle = merged_resource_bundle
              line.value = merged_resource_bundle
              line.content = "#{line.key}= #{line.value}"
            else # 如果原先没有resource_bundle，需要单独加一行resource_bundle
              space = PrivacyUtils.count_spaces_before_first_character(rows[@source_files_index].content)
              line = "#{alias_name}.resource_bundle = #{privacy_resource_bundle}"
              line = PrivacyUtils.add_spaces_to_string(line,space)
              row = BBRow.new(line)
              @rows.insert(@source_files_index+1, row)
            end
          end
        end
      end
    end
  end
end

