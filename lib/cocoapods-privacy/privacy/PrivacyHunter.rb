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

    # source_files = ARGV[0]#传入source文件路径，如有多个使用 “,” 逗号分割
    # privacyInfo_file = ARGV[1]#传入目标 PrivacyInfo.xcprivacy

    def self.search_pricacy_apis(source_folders)
      # #读取源文件，也就是搜索目标文件
      # source_folders = source_files.split(",")
      #模版数据源plist文件
      template_plist_file = fetch_template_plist_file()

      # 读取并解析 数据源 plist 文件
      json_str = `plutil -convert json -o - "#{template_plist_file}"`.chomp
      map = JSON.parse(json_str)
      arr = map[KTypes]

      #解析并按照API模版查询指定文件夹
      privacyArr = []
      arr.each do |value|
        privacyDict = {}
        type = value[KType]
        reasons = []
        apis = value[KAPI]
        apis.each do |s_key, s_value|
            if search_files(source_folders, s_key)
                s_vlaue_split = s_value.split(',')
                reasons += s_vlaue_split
            end
        end
        
        #按照隐私清单拼接数据
        reasons = reasons.uniq
        if !reasons.empty?
            privacyDict[KType] = type
            privacyDict[KReasons] = reasons
            privacyArr.push(privacyDict)
        end
        # puts "type: #{type}"
        # puts "reasons: #{reasons.uniq}"

      end

      # 打印出搜索结果
      puts privacyArr

      # 转换成 JSON 字符串
      json_data = privacyArr.to_json
    end


    def self.write_to_privacy(json_data,privacy_path)
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
      remote_file_time = remoteFileTime?(template_url)

      # 判断本地文件的最后修改时间是否与远端文件一致，如果一致则不进行下载
      if File.exist?(local_file_path) && file_identical?(local_file_path, remote_file_time)
      else
        # 使用 curl 下载文件
        system("curl -o #{local_file_path} #{template_url}")
        puts "隐私清单模版文件已更新到: #{local_file_path}"

        # 同步远程文件时间到本地文件
        syncFileTime?(local_file_path,remote_file_time)
      end
      
      local_file_path
    end

    # 获取远程文件更新时间
    def self.remoteFileTime?(remote_url)
      uri = URI.parse(remote_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      response = http.request_head(uri.path)

      response['Last-Modified']
    end

    # 判断本地文件的最后修改时间与远端文件的最后修改时间是否一致
    def self.file_identical?(local_file_path, remote_file_time) 
      remote_file_time && Time.parse(remote_file_time) == File.mtime(local_file_path)
    end

    # 同步远程文件时间到本地文件
    def self.syncFileTime?(local_file_path, remote_file_time)
      File.utime(File.atime(local_file_path), Time.parse(remote_file_time), local_file_path)
    end

    # 文件是否包含内容
    def self.contains_keyword?(file_path, keyword)
      File.read(file_path).include? keyword
    end

    #搜索所有子文件夹
    def self.search_files(folder_paths, keyword)

      # 获取文件夹下所有文件（包括子文件夹）
      all_files = []
      folder_paths.each do |folder|
        allowed_extensions = ['m', 'c', 'swift', 'mm', 'hap', 'cpp']
        pattern = File.join(folder, '**', '*.{'+allowed_extensions.join(',')+'}')
        all_files += Dir.glob(pattern, File::FNM_DOTMATCH).reject { |file| File.directory?(file) }
      end
      # 遍历文件进行检索
      all_files.uniq.each_with_index do |file_path, index|
        if contains_keyword?(file_path, keyword)
          puts "File #{file_path} contains the keyword '#{keyword}'."
          return true
        end
      end
      return false
    end
end

