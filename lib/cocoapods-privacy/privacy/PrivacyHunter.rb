require 'json'
require 'cocoapods-privacy/command'

##
#  功能介绍：
#  1、检测本地隐私协议清单模版是否最新，如果不存在或不是最新，那么下载远端隐私协议模版
#  2、使用模版对相关文件夹进行检索
#  3、检索到的内容转换成隐私协议格式写入 隐私清单文件 PrivacyInfo.xcprivacy
##
module PrivacyHunter

    KTypes = "NSPrivacyAccessedAPITypes"
    KType = "NSPrivacyAccessedAPIType"
    KReasons = "NSPrivacyAccessedAPITypeReasons"
    KAPI = "NSPrivacyAccessedAPI"

    def self.formatter_privacy_template()
      #模版数据源plist文件
      template_plist_file = fetch_template_plist_file()

      # 读取并解析 数据源 plist 文件
      json_str = `plutil -convert json -o - "#{template_plist_file}"`.chomp
      map = JSON.parse(json_str)
      type_datas = map[KTypes]

      apis = {}
      keyword_type_map = {} #{systemUptime:NSPrivacyAccessedAPICategorySystemBootTime,mach_absolute_time:NSPrivacyAccessedAPICategorySystemBootTime .....}
      type_datas.each do |value|
        type = value[KType]
        apis_inner = value[KAPI]
        apis_inner.each do |keyword, reason|
          keyword_type_map[keyword] = type
        end
        apis = apis.merge(apis_inner)
      end
      [apis,keyword_type_map]
    end

    def self.search_pricacy_apis(source_folders,exclude_folders=[])
      apis,keyword_type_map = formatter_privacy_template()

      # 优化写法，一次循环完成所有查询
      datas = []
      apis_found = search_files(source_folders, exclude_folders, apis)
      unless apis_found.empty?
        apis_found.each do |keyword,reason|
          reasons = reason.split(',')
          type = keyword_type_map[keyword]
          
          # 如果有数据 给data增加reasons
          datas.map! do |data|
            if data[KType] == type
              data[KReasons] += reasons
              data[KReasons] = data[KReasons].uniq
            end
            data
          end

          # 如果没数据，新建data
          unless datas.any? { |data| data[KType] == type }
            data = {}
            data[KType] = type
            data[KReasons] ||= []
            data[KReasons] += reasons
            data[KReasons] = data[KReasons].uniq
            datas.push(data)
          end
        end
      end

      # 打印出搜索结果
      puts datas

      # 转换成 JSON 字符串
      json_data = datas.to_json
    end


    def self.write_to_privacy(json_data,privacy_path)

      # 如果指定了--query 参数，那么不进行写入操作，仅用来查询
      return if Pod::Config.instance.is_query

      # 转换 JSON 为 plist 格式
      plist_data = `echo '#{json_data}' | plutil -convert xml1 - -o -`

      # 创建临时文件
      temp_plist = File.join(PrivacyUtils.cache_privacy_fold,"#{PrivacyUtils.to_md5(privacy_path)}.plist")
      File.write(temp_plist, plist_data)

      # 获取原先文件中的 NSPrivacyAccessedAPITypes 数据
      origin_privacy_data = `/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' '#{privacy_path}' 2>/dev/null`
      new_privacy_data = `/usr/libexec/PlistBuddy -c 'Print' '#{temp_plist}'`

      # 检查新数据和原先数据是否一致
      if origin_privacy_data.strip == new_privacy_data.strip
        puts "#{privacy_path} 数据一致，无需插入。"
      else
        unless origin_privacy_data.strip.empty?
          # 删除 :NSPrivacyAccessedAPITypes 键
          system("/usr/libexec/PlistBuddy -c 'Delete :NSPrivacyAccessedAPITypes' '#{privacy_path}'")
        end

        # 添加 :NSPrivacyAccessedAPITypes 键并设置为数组
        system("/usr/libexec/PlistBuddy -c 'Add :NSPrivacyAccessedAPITypes array' '#{privacy_path}'")

        # 合并 JSON 数据到隐私文件
        system("/usr/libexec/PlistBuddy -c 'Merge #{temp_plist} :NSPrivacyAccessedAPITypes' '#{privacy_path}'")

        puts "NSPrivacyAccessedAPITypes 数据已插入。"
      end

      # 删除临时文件
      File.delete(temp_plist)
    end


    private

    def self.fetch_template_plist_file

      unless File.exist?(PrivacyUtils.cache_config_file)
        raise Pod::Informative, "无配置文件，run `pod privacy config config_file' 进行配置"
      end
  
      template_url = Privacy::Config.instance.api_template_url
      unless template_url && !template_url.empty?
        raise Pod::Informative, "配置文件中无 `api.template.url` 配置，请补全后再更新配置 `pod privacy config config_file` "
      end

      # 目标文件路径
      local_file_path = File.join(PrivacyUtils.cache_privacy_fold, 'NSPrivacyAccessedAPITypes.plist')
      
      # 获取远程文件更新时间
      remote_file_time,etag = remoteFile?(template_url)

      # 判断本地文件的最后修改时间是否与远端文件一致，如果一致则不进行下载
      if File.exist?(local_file_path) && file_identical?(local_file_path, remote_file_time,etag)
      else
        # 使用 curl 下载文件
        system("curl -o #{local_file_path} #{template_url}")
        puts "隐私清单模版文件已更新到: #{local_file_path}"

        # 同步远程文件标识（时间或者etag）
        syncFile?(local_file_path,remote_file_time,etag)
      end
      
      local_file_path
    end

    # 获取远程文件更新时间
    def self.remoteFile?(remote_url)
      uri = URI.parse(remote_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      response = http.request_head(uri.path)

      last_modified = response['Last-Modified']
      etag = response['ETag']

      [last_modified,etag]
    end

    # 判断本地文件的最后修改时间与远端文件的最后修改时间是否一致
    def self.file_identical?(local_file_path, remote_file_time, etag) 
      if remote_file_time
        remote_file_time && Time.parse(remote_file_time) == File.mtime(local_file_path)
      elsif etag
        File.exist?(File.join(PrivacyUtils.cache_privacy_etag_fold,etag))
      else
        false
      end
    end


    # 同步文件标识
    def self.syncFile?(local_file_path, remote_file_time, etag)
      if remote_file_time
        syncFileTime?(local_file_path,remote_file_time)
      elsif etag
        PrivacyUtils.create_file_and_fold_if_no_exit(File.join(PrivacyUtils.cache_privacy_etag_fold,etag))
      end
    end

    # 同步远程文件时间到本地文件
    def self.syncFileTime?(local_file_path, remote_file_time)
      File.utime(File.atime(local_file_path), Time.parse(remote_file_time), local_file_path)
    end



    #💡💡💡以下是 invalid byte sequence in UTF-8 错误复现 的数据代码
    # File.write("/Users/xxx/.cache/cocoapods-privacy/privacy/file.txt", "vandflyver \xC5rhus \n
    
    # \n

    # \\n

    # vandflyver 
    # \xC5rhus
    # ")
    # 文件是否包含内容
    def self.contains_apis?(file_path, apis)

      #使用UTF-8 读取，无法读取的会被默认处理，修复 https://github.com/ymoyao/cocoapods-privacy/issues/7 
      file_content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, undef: :replace)

      #核心文件检查段落注释 /* */
      file_extension = File.extname(file_path).downcase
      need_check_paragraph_comment = ['.m', '.c', '.swift', '.mm', '.h', '.hap', '.hpp', '.cpp'].include?(file_extension)

      if need_check_paragraph_comment 
        # 计算段注释 /**/
        apis_found = contains_apis_ignore_all_comment(file_content.lines,apis)
      else
        # 计算单独行注释 //
        apis_found = contains_apis_ignore_line_comment(file_content.lines,apis)
      end
      apis_found
    end

    def self.contains_apis_ignore_line_comment(lines,apis) 
      apis_found = {}
      # 初始化状态机，表示不在注释块内
      in_block_comment_count = 0  
      in_block_comment = false
      lines.each do |line|

        line_scrub = line.scrub("")
        next if line_scrub.strip.empty? #忽略空行
        next if line_scrub.strip.start_with?('//') #忽略单行

        apis.each do |keyword, value|
          if line_scrub.include?(keyword)
            apis_found[keyword] = value
          end
        end
      end

      apis_found
    end
    
    def self.contains_apis_ignore_all_comment(lines,apis) 
      apis_found = {}

      # 段注释和单行注释标志
      in_block_comment = false
      in_line_comment = false

      # 是否可以触发注释标识，当为true 时可以触发 /*段注释 或者 //单行注释
      can_trigger_comments_flag = true

      # 统计计数器
      count_comments = 0

      lines.each do |line|

        line_scrub = line.scrub("")
        next if line_scrub.strip.empty? #忽略空行
        next if line_scrub.strip.start_with?('//') && !in_block_comment  #忽略单行

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
            # 检测到 can_trigger_comments_flag 为true,且 // 时，说明触发了段注释之后的单行注释 ==》 /**///abcd
            elsif chars[index + 1] == '/' && can_trigger_comments_flag 
                in_line_comment = true
                in_block_comment = false
                can_trigger_comments_flag = true
                break            
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
          apis.each do |keyword, value|
            if line_scrub.include?(keyword)
              apis_found[keyword] = value
            end
          end
        end

        #每行结束时，重置行标识
        in_line_comment = false
      end
      apis_found
    end


    #搜索所有子文件夹
    def self.search_files(folder_paths, exclude_folders, apis)
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
      apis_found = {}
      all_files.each_with_index do |file_path, index|
        api_contains = contains_apis?(file_path, apis)
        apis_found = apis_found.merge(api_contains) unless Pod::Config.instance.is_query # 如果指定了--query 参数，那么不进行写入操作，仅用来查询
        
        unless api_contains.empty? 
          log = "File #{file_path} contains the keyword '#{api_contains.keys}'.\n" 
          PrivacyLog.write_to_result_log(log)
        end
      end
      PrivacyLog.write_to_result_log("\n") if !apis_found.empty?
      apis_found
    end
end

