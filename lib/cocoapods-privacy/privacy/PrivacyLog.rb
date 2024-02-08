require 'cocoapods-privacy/command'

module PrivacyLog

    # 提示log 存放地址
    def self.result_log_tip()
        puts "详细log请查看 #{PrivacyUtils.cache_log_file} 文件"
    end

    # 写入结果log 文件
    def self.write_to_result_log(log)
        log_file_path = PrivacyUtils.cache_log_file
        is_create = PrivacyUtils.create_file_and_fold_if_no_exit(log_file_path,log)
        unless is_create
            File.open(log_file_path, "a") do |file|
            file << log
            end
        end
    end

    # 清除结果log文件
    def self.clean_result_log()
        File.open(PrivacyUtils.cache_log_file, "w") do |file|
            # 写入空字符串，清空文件内容
            file.write("")
        end
    end
end