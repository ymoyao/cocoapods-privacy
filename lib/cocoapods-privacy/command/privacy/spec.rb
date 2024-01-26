module Pod
    class Command
      class Privacy < Command
        class Spec < Privacy
            self.summary = '根据 podspec 创建对应隐私清单文件'

            self.description = <<-DESC
                根据podspec 创建对应隐私清单文件，并自动修改podspec文件，以映射对应隐私清单文件。
            DESC
    
            self.arguments = [
                CLAide::Argument.new('podspec_file', false, true),
            ]
    
            def initialize(argv)
                @podspec_file = argv.arguments!.first
                super
            end

            def validate!
                @podspec_file =  @podspec_file ?  @podspec_file : PrivacyUtils.podspec_file_path
                unless @podspec_file && !@podspec_file.empty?
                  raise Informative, 'no podspec file were found, please run pod privacy podspec_file_path'   
                end
            end
    
            def run
                PrivacyModule.load_module(@podspec_file)
            end
        end
      end
    end
  end
  