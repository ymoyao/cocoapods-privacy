module Pod
  class Command
    # This is an example of a cocoapods plugin adding a top-level subcommand
    # to the 'pod' command.
    #
    # You can also create subcommands of existing or new commands. Say you
    # wanted to add a subcommand to `list` to show newly deprecated pods,
    # (e.g. `pod list deprecated`), there are a few things that would need
    # to change.
    #
    # - move this file to `lib/pod/command/list/deprecated.rb` and update
    #   the class to exist in the the Pod::Command::List namespace
    # - change this class to extend from `List` instead of `Command`. This
    #   tells the plugin system that it is a subcommand of `list`.
    # - edit `lib/cocoapods_plugins.rb` to require this file
    #
    # @todo Create a PR to add your plugin to CocoaPods/cocoapods.org
    #       in the `plugins.json` file, once your plugin is released.
    #
    class Privacy < Command
      self.summary = '隐私清单'

      self.description = <<-DESC
        1、生成默认的隐私清单文件 2、检索代码生成隐私api定义（不包括隐私权限）
      DESC

      self.arguments = [
        CLAide::Argument.new('folds', false, true),
      ]

      def initialize(argv)
        @folds = argv.arguments!
        super
      end

      def run
        if PrivacyUtils.isMainProject()
          # 单独执行install 分析步骤
          installer = installer_for_config
          installer.repo_update = false
          installer.update = false
          installer.deployment = false
          installer.clean_install = false
          installer.privacy_analysis()
        else
          PrivacyModule.load_module()
        end
      end
    end
  end
end
